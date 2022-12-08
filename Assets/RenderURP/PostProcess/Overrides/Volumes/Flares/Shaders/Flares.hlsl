#ifndef FLARES_INCLUDED
#define FLARES_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"

TEXTURE2D(_SourceTex);

float3 _MainLightUV;
float4 _Color;
float4 _Params1;
float4 _Params2;

#define _Radius             _Params1.x
#define _Gradient           _Params1.y
#define _Power              _Params1.z
#define _Intensity          _Params1.w

#define _UVExtent           _Params2.xy
#define _ScaleX             _Params2.z
#define MAINLIGHT_DISTANCE  _Params2.w

float FallOffFunc(float x, float s, float d)
{
    return abs(x) > d ? s * (-exp(-x * s + d) + 1 + d) : x;
}

float2 FallOffFunc(float2 pos, float2 signXY, float2 d)
{
    return float2(FallOffFunc(pos.x, signXY.x, d.x), FallOffFunc(pos.y, signXY.y, d.y));
}

half4 FragFlares(Varyings input) : SV_Target
{
    float2 uv = input.uv;

    half4 color = SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, uv);

    float aspect = _ScreenParams.x / _ScreenParams.y;

    //
    float3 lightUV = _MainLightUV;
    lightUV.xy = lightUV.xy * 2 - 1;
    
    float isBack = step(0, lightUV.z);
    float2 signXY = sign(lightUV.xy);
    //  /
    // ----
    //   /
    // 反方向uv在下面 没法找到高度延续到上面 因为曲线衰减在个位数的时候就达到了1 所以用10作为最大值匹配就够了
    // 反方向y方向还会反转 所以固定到上面
    signXY = lerp(signXY, float2(-signXY.x, 1), isBack);
    lightUV.xy = lerp(lightUV.xy, signXY.xy * 10, isBack);

    lightUV.xy = FallOffFunc(lightUV.xy, signXY, _UVExtent);

    float2 diffUV = (uv * 2 - 1) - lightUV.xy;
    diffUV.x *= aspect * rcp(_ScaleX);

    float SDF = saturate((length(diffUV) / (_Radius * 10) - 1.0f) / (_Gradient - 1.01f));
    SDF = pow(SDF, _Power);
    
    // 反方向在交接处会跳跃 所以提前衰减掉 MAINLIGHT_DISTANCE 是目前锚定点坐标所在的半径
    SDF = lerp(SDF, saturate(lerp(SDF, 0, lightUV.z * rcp(MAINLIGHT_DISTANCE))), isBack);


    #if CALCULATE_IN_GAMMASPACE
        color.rgb = LinearToSRGB(color.rgb);
    #endif

    color.rgb += SDF * _Color.rgb * _Intensity;

    #if CALCULATE_IN_GAMMASPACE
        color.rgb = SRGBToLinear(color.rgb);
    #endif

    return color;
}

#endif // FLARES_INCLUDED
