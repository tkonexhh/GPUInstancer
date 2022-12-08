
// Simplex noise的一种实现 来源于Amplify内置的实现 暂用
float3 mod2D289( float3 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
float2 mod2D289( float2 x ) { return x - floor( x * ( 1.0 / 289.0 ) ) * 289.0; }
float3 permute( float3 x ) { return mod2D289( ( ( x * 34.0 ) + 1.0 ) * x ); }
float snoise( float2 v )
{
    const float4 C = float4( 0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439 );
    float2 i = floor( v + dot( v, C.yy ) );
    float2 x0 = v - i + dot( i, C.xx );
    float2 i1;
    i1 = ( x0.x > x0.y ) ? float2( 1.0, 0.0 ) : float2( 0.0, 1.0 );
    float4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    i = mod2D289( i );
    float3 p = permute( permute( i.y + float3( 0.0, i1.y, 1.0 ) ) + i.x + float3( 0.0, i1.x, 1.0 ) );
    float3 m = max( 0.5 - float3( dot( x0, x0 ), dot( x12.xy, x12.xy ), dot( x12.zw, x12.zw ) ), 0.0 );
    m = m * m;
    m = m * m;
    float3 x = 2.0 * frac( p * C.www ) - 1.0;
    float3 h = abs( x ) - 0.5;
    float3 ox = floor( x + 0.5 );
    float3 a0 = x - ox;
    m *= 1.79284291400159 - 0.85373472095314 * ( a0 * a0 + h * h );
    float3 g;
    g.x = a0.x * x0.x + h.x * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot( m, g );
}

float4 CubicSmooth(float4 vData)
{
    return vData * vData * (3.0 - 2.0 * vData);
}
float4 TriangleWave(float4 vData)
{
    return abs((frac(vData + 0.5) * 2.0) - 1.0);
}
float4 TrigApproximate(float4 vData)
{
    return (CubicSmooth(TriangleWave(vData)) - 0.5) * 2.0;
}
float4 TrigApproximateSmooth(float4 vData)
{
    return CubicSmooth(TriangleWave(vData));
}

float VertexWind(float2 uv, float3 tangent,
                float4 winddir, half windpower, float4 windtreecenter,
                inout float4 vertex)
{
    float3 final = vertex.xyz;
    // 没法还原每个面的相对距离，只能是顶点层级的
    float3 offset_pos = vertex.xyz + windtreecenter.xyz;

    // ----------------------------------------------------------------------------
    // 叶片摆动
    // 风力强度对振幅影响 不同部位引入噪声
    float amount = snoise(vertex.xz * _Time.x) * windpower;
    // 叶片局部振幅变化
    float scale = snoise(uv.xy * _Time.x); // frac(v.vertex.xz);

    // 斜下方向相位变化
    float delta = offset_pos.x + offset_pos.y;
    float move = amount * scale * TrigApproximate(_Time.y + delta).x;

    // 调试用
    float debug_vertex = move;

    // 切线方向移动
    final += tangent.xyz * move;
    // ----------------------------------------------------------------------------

    // TODO 叶片不做范围约束 显得更自由点
    float origin = length(final);

    // 主体摇摆
    // 根部向上衰减
    amount = windpower * offset_pos.y * 0.02;
    // +1 偏向一侧
    move = amount * (TrigApproximate(_Time.y * 0.2).x + 1);

    final += winddir.xyz * move;
    // ----------------------------------------------------------------------------

    // 约束在原本顶点位置范围内
    final = normalize(final) * origin;

    // ----------------------------------------------------------------------------

    vertex.xyz = final;

    return debug_vertex;

}

float VertexWindVegetation(half4 vertexColor, half3 normalOS,
                float4 winddir, half branchStrength, half waveStrength, half detailStrength, half detailFrequency,
                inout float4 positionOS)
{
    const half fDetailAmp = 0.1;
    const half fBranchAmp = 0.3;

    // 记录原始顶点偏移
    float origLength = length(positionOS.xyz);

    // TODO 风向统一到世界空间
    float3 windDir = TransformWorldToObjectDir(winddir.xyz);
    windDir = clamp(windDir, -1, 1);

    // TODO 顶点色R通道现在还用在顶点AO上 会冲突
    // 根部定位过度
    half mainBlend = vertexColor.r;
    // 原本需要每个叶片指定相位 没有数据情况下 用模型空间坐标凑活
    half localPhase = positionOS.x + positionOS.y + positionOS.z;

    float3 objectWorldPos = UNITY_MATRIX_M._m03_m13_m23;

    // 增加一些相位差异
    half globalPhase = dot(objectWorldPos, 2);
    half fBranchPhase = globalPhase + localPhase;

    // 预计算两个时间周期
    float3 absObjectWorldPos = abs(objectWorldPos.xyz * 0.125);
    half4 vOscillations = half4(absObjectWorldPos.xz + _SinTime.z * half2(1, 0.7), 1, 1);
    vOscillations = TrigApproximateSmooth(vOscillations);

    half2 fOsc = (vOscillations.xy * vOscillations.xy);
    fOsc = (fOsc + 3.33) * 0.33;

    // ---------------------------------------------------------------------
    // 主体摆动
    half2 blendBranch = branchStrength * windDir.xz * fOsc.x;
    positionOS.xz += blendBranch;

    // ---------------------------------------------------------------------
    // x: 中心波动 y: 整体波动
    float2 vWavesIn = _Time.yy + half2(dot(positionOS.xyz, fBranchPhase), fBranchPhase);
    half4 vWaves = frac(vWavesIn.xxyy * float4(1.975f, 0.793f, 0.375f, 0.193f)) * 2.0f - 1.0f;
    vWaves = TrigApproximateSmooth(vWaves);
    // 高频低频混合
    half2 vWavesSum = vWaves.xz + vWaves.yw;

    // 中心波动因为没有叶片边缘数据 没有使用
    float3 blendWave = waveStrength * windDir * fOsc.y;
    blendWave *= mainBlend * fBranchAmp * vWavesSum.y;

    // 整体波浪扭曲
    positionOS.xyz += blendWave;

    // ---------------------------------------------------------------------
    // 法线方向细节抖动 (对于圆形顶点分布的叶片不适用，会造成法线闪烁，需要修改)
    float tOffset = (mainBlend + localPhase) * 4;
    float tFrequency = detailFrequency * (_Time.y + globalPhase * 8 + localPhase);

    float4 tWaves = tFrequency * float4(1, 0.75, 0.5, 0.25) + tOffset;
    tWaves = TrigApproximateSmooth(tWaves);
    float detailSum = 1 - (tWaves.x + tWaves.y + (tWaves.z * tWaves.w));

    float3 blendDetail = detailStrength * normalOS.xyz * max(1, fOsc.x * 0.2);
    blendDetail *= mainBlend * fDetailAmp * detailSum;

    positionOS.xyz += blendDetail;

    // ---------------------------------------------------------------------
    // 约束在原本顶点位置范围内
    positionOS.xyz = normalize(positionOS.xyz) * origLength;

    float debug_vertex = abs(blendWave.x) + abs(blendDetail.x);

    return debug_vertex;
}