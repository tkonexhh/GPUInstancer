
#ifndef TOON_OUTLINE_INCLUDED
#define TOON_OUTLINE_INCLUDED

// ---------------------------------------------------------------
// 实际用到的数据 现在合并到对应的主Pass数据CBUFFER中
// #include "ToonCommon.hlsl"
// Input
// CBUFFER_START(UnityPerMaterial)
//     float4  _MainTex_ST;

//     half    _OutlineWidth;
//     float4  _OutlineMask_ST;
//     half4   _OutlineColor;
//     half4   _FadeDist;
//     half    _Offset_Z;

//     // _F_OUTLINECOLORS_ON
//     // half4   _OutlineColor0;
//     // half4   _OutlineColor1;
//     // half4   _OutlineColor2;
//     // half4   _OutlineColor3;
//     // half4   _OutlineColor4;
//     // half4   _OutlineColor5;
//     // half4   _OutlineColor6;
//     // half4   _OutlineColor7;

//     // -------------------------------------------------------------
//     #include "ToonInput/ToonInputDye.hlsl"
//     #include "ToonInput/ToonInputClip.hlsl"

// CBUFFER_END

// -----------------------------------------------------------------
// TEXTURE2D(_MainTex);        SAMPLER(sampler_MainTex);
// TEXTURE2D(_OutlineMask);    SAMPLER(sampler_OutlineMask);
// TEXTURE2D(_AreaMask);       SAMPLER(sampler_AreaMask);

// #include "ToonInput/ToonInputDyeTex.hlsl"
// #include "ToonInput/ToonInputClipTex.hlsl"

// ---------------------------------------------------------------







// 因为主Pass中需要_OutlineMask调试用 所以固定提取到主Pass中
// TEXTURE2D(_OutlineMask);    SAMPLER(sampler_OutlineMask);

// -----------------------------------------------------------------


// -----------------------------------------------------------------
// Core
struct Attributes
{
    float4 positionOS       : POSITION;
    float3 normalOS         : NORMAL;
    float4 tangentOS        : TANGENT;
    float2 texcoord         : TEXCOORD0;
    float4 color            : COLOR;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv               : TEXCOORD0;
    float4 color            : TEXCOORD1;
    float4 positionCS       : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

// ----------------------------------------------------------------
// 函数部分
#include "ToonFunc/ToonFuncClip.hlsl"


// ----------------------------------------------------------------
// Pass
float3 GetNormalOSFromVertexColor(float4 vertexColor, float3 normalOS, float4 tangentOS)
{
    #if _OUTLINETYPE_VERTEXCOLOR
        half3 normalTS = (vertexColor.xyz * 2) - 1;

        float sgn = tangentOS.w * GetOddNegativeScale();
        float3 bitangent = sgn * cross(normalOS.xyz, tangentOS.xyz);
        half3x3 tangentToObject = half3x3(tangentOS.xyz, bitangent.xyz, normalOS.xyz);
        // 注意这里矩阵是右乘
        normalOS = mul(normalTS, tangentToObject);
    #endif

    return normalOS;
}

half GetOutlineWidth(float2 uv)
{
    // 描边蒙板，可以考虑换顶点色控制
    half4 outlineMask = SAMPLE_TEXTURE2D_LOD(_OutlineMask, sampler_OutlineMask, TRANSFORM_TEX(uv, _OutlineMask), 0);
    half width = _OutlineWidth * outlineMask.r;

    float FOV = atan(1.0f / unity_CameraProjection._m11 ) * 2.0 * (180 / PI) * 0.05;
    float distFromCamera = IsPerspectiveProjection() ?  length(TransformWorldToObject(GetCurrentViewPosition())) : 1;
    width *= smoothstep( _FadeDist.y, _FadeDist.x, FOV * distFromCamera);

    return width;
}

float4 CalculateOutlineInClipSpace(float4 positionOS, float3 normalOS, half width)
{
    // 屏幕空间相对保持宽度
    #if _AUTOWIDTH_ON
        // https://www.videopoetics.com/tutorials/pixel-perfect-outline-shaders-unity/
        float4 positionCS = TransformObjectToHClip(positionOS.xyz);
        half3 normalCS = TransformWorldToHClipDir(TransformObjectToWorldNormal(normalOS, false));
        float2 offset = normalize(normalCS.xy) * rcp(_ScreenParams.xy) * width * positionCS.w * 2;
        positionCS.xy += offset;
    #else
        // 顶点沿法线方向外移
        float4 positionCS = TransformObjectToHClip(positionOS.xyz + normalOS * width * 0.001);
    #endif

    // clip空间沿camera的z方向偏移
    float4 cameraPosCS = TransformWorldToHClip(_WorldSpaceCameraPos.xyz);
    #if defined(UNITY_REVERSED_Z)
        _Offset_Z *= -0.01;
    #else
        _Offset_Z *= 0.01;
    #endif
    positionCS.z += _Offset_Z * cameraPosCS.z;

    return positionCS;
}

// 计算主光强度造成的描边颜色缩放
half GetMainLightIntensity()
{
    Light mainLight = GetMainLight();
    // 和forwardPass一样的限制亮度
    half3 mainLightColor = min(mainLight.color, _LightIntensityLimit * saturate(mainLight.color));
    // 只要灰度
    return dot(mainLightColor.rgb, float3(0.3, 0.6, 0.1));
}

half3 GetOutlineColor(float2 uv, half3 mainTex)
{
    half3 outlineColor = _OutlineColor.rgb;

    int id, idNear;
    half fade;

    #if _F_DYE_ON// || _F_OUTLINECOLORS_ON
        // 区域ID颜色
        half3 areaMask = SAMPLE_TEXTURE2D(_AreaMask, sampler_AreaMask, TRANSFORM_TEX(uv, _MainTex)).rgb;
        CalculateDyeColorId(areaMask, id, idNear, fade);
    #endif

    // 染色描边测试
    #if _F_DYE_ON
        // TODO 染色区域颜色列表 外部传入
        const half3 colorList[8] = {
            lerp(mainTex, _DyeColor0.rgb, _F_DyeColor0),
            lerp(mainTex, _DyeColor1.rgb, _F_DyeColor1),
            lerp(mainTex, _DyeColor2.rgb, _F_DyeColor2),
            lerp(mainTex, _DyeColor3.rgb, _F_DyeColor3),
            lerp(mainTex, _DyeColor4.rgb, _F_DyeColor4),
            lerp(mainTex, _DyeColor5.rgb, _F_DyeColor5),
            lerp(mainTex, _DyeColor6.rgb, _F_DyeColor6),
            lerp(mainTex, _DyeColor7.rgb, _F_DyeColor7)
        };

        half3 dyeColor = lerp(colorList[id], colorList[idNear], fade);

        half3 originHSV = RgbToHsv(dyeColor);

        // 色相需要旋转
        float hue = originHSV.x + _DyeOutlineHue / 360;
        originHSV.x = RotateHue(hue, 0, 1);
        originHSV.y = saturate(originHSV.y * _DyeOutlineSat);
        originHSV.z = saturate(originHSV.z * _DyeOutlineLum);
        // 固有色明度接近0时 描边明度需要反转
        originHSV.z = abs(originHSV.z - _DyeOutlineThreshold);

        outlineColor = HsvToRgb(originHSV);
    // #elif _F_OUTLINECOLORS_ON
    //     outlineColor += (id == 0) * _OutlineColor0;
    //     outlineColor += (id == 1) * _OutlineColor1;
    //     outlineColor += (id == 2) * _OutlineColor2;
    //     outlineColor += (id == 3) * _OutlineColor3;
    //     outlineColor += (id == 4) * _OutlineColor4;
    //     outlineColor += (id == 5) * _OutlineColor5;
    //     outlineColor += (id == 6) * _OutlineColor6;
    //     outlineColor += (id == 7) * _OutlineColor7;
    #endif

    // 使用主光源的灰度进行强度控制
    outlineColor *= GetMainLightIntensity();

    return outlineColor;
}

// -----------------------------------------------------------
// Vertex
Varyings ToonOutlineVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);

    output.uv = input.texcoord;
    output.color = input.color;

    // 平滑法线存在顶点色中
    float3 normalOS = GetNormalOSFromVertexColor(input.color, input.normalOS, input.tangentOS);

    half width = GetOutlineWidth(input.texcoord);
    output.positionCS = CalculateOutlineInClipSpace(input.positionOS, normalOS, width);

    return output;
}

// -----------------------------------------------------------
// Fragment
half4 ToonOutlineFragment(Varyings input) : SV_TARGET
{
    UNITY_SETUP_INSTANCE_ID(input);

    #ifdef _F_OUTLINE_ON
    #else
        discard;
    #endif

    half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, TRANSFORM_TEX(input.uv, _MainTex));

    CheckClip(mainTex.a, input.uv);

    half3 outlineColor = GetOutlineColor(input.uv, mainTex.rgb);

    ApplyGlobalSettings_Exposure(outlineColor);

    return half4(outlineColor, 1);
}

#endif
