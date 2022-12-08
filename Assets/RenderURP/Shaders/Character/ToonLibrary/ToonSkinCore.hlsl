
#ifndef TOON_SKIN_CORE_INCLUDED
#define TOON_SKIN_CORE_INCLUDED

// ----------------------------------------------------------------
struct CalculateColors
{
    float3 Albedo;
    float3 ShadeColor;
    float3 FakeSSSColor;
    float3 FresnelColor;
    float3 FresnelShadeColor;
};

struct HeadRotations
{
    float3 rightWS;
    float3 forwardWS;
};

// ----------------------------------------------------------------
struct Attributes
{
    float4 positionOS       : POSITION;
    float3 normalOS         : NORMAL;
    float4 tangentOS        : TANGENT;
    float2 texcoord0        : TEXCOORD0;
    float2 texcoord1        : TEXCOORD1;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4  uvs                     : TEXCOORD0;
    float3  positionWS              : TEXCOORD1;
    half3   normalWS                : TEXCOORD2;

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    float4  shadowCoord             : TEXCOORD3;
#endif

    float3  headDirRightWS          : TEXCOORD4;
    float3  headDirForwardWS        : TEXCOORD5;
    float   faceShadeAverage        : TEXCOORD6;

    float4  positionCS              : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

// ----------------------------------------------------------------
// 函数部分
#include "ToonFunc/ToonFuncFresnel.hlsl"
#include "ToonFunc/ToonFuncLight.hlsl"
#include "ToonFunc/ToonFuncEulerAngles.hlsl"

// ----------------------------------------------------------------
#if _FACE_SHADE_ON
    // 面部SDF阴影
    half GetFaceShade(float2 uv, float3 L, HeadRotations headRotations)
    {
        // 对称复用 但是要采样2次
        half4 leftFace = SAMPLE_TEXTURE2D(_FaceShade, sampler_FaceShade, TRANSFORM_TEX(uv, _FaceShade));
        uv.x = 1 - uv.x;
        half4 rightFace = SAMPLE_TEXTURE2D(_FaceShade, sampler_FaceShade, TRANSFORM_TEX(uv, _FaceShade));

        half2 frontDir = normalize(headRotations.forwardWS.xz);
        half2 rightDir = normalize(headRotations.rightWS.xz);

        // 光源方向xz平面上旋转偏移
        half sinx = sin(_FaceShadeOffset);
        half cosx = cos(_FaceShadeOffset);
        half2x2 rotation = half2x2(cosx, -sinx, sinx, cosx);
        half2 lightDir = normalize(mul(rotation, L.xz));

        half FdotL = dot(frontDir, lightDir);
        #ifdef _FACESHADELINEAR_ON
            FdotL = 1.0 - (acos(FdotL) * 2.0 * INV_PI);
        #endif
        half RdotL = dot(rightDir, lightDir);

        half threshold = 1 - clamp(0, 1, FdotL);
        // 光源在中间时候，留0.01的空当
        half face = (RdotL > 0 ? rightFace.r : leftFace.r) + 0.01;
        half f = fwidth(face);
        half faceShade = smoothstep(-f, f, face - threshold);

        return faceShade;
    }
#endif

half3 GetDiffuseColor(float3 N, float3 L, float4 uvs, half shadowAttenuation, HeadRotations headRotations, CalculateColors Cals, float faceShadeAverage, float isMainLight, inout half outShadowAttenuation)
{
    float diffuse = dot(N, L) * 0.5 + 0.5;

    // 第一层梯度漫反射
    float diffuseShade = smoothstep(_Shift_01, _Shift_01 + _Gradient_01, diffuse);

    // TODO 直接光阴影 先直接加在这里
    #if _USESHADOWMAP_ON
        diffuseShade *= shadowAttenuation;
    #endif

    #if _FACE_SHADE_ON
        float2 uv = uvs.xy;
        #if _FACESHADEUSEUV1_ON
            uv = uvs.zw;
        #endif
        diffuseShade *= lerp(1, GetFaceShade(uv, L, headRotations), isMainLight);
        diffuseShade = lerp(0, diffuseShade, faceShadeAverage);
        // 使用SDF阴影图时不使用遮挡阴影亮度调整，所以这里传出去的shadowAttenuation是1
        // 并且只有mainLight会对这个修改。其他光源只继承mainLight的结果。
        outShadowAttenuation = lerp(outShadowAttenuation, 1, isMainLight);
    #else
        outShadowAttenuation = lerp(outShadowAttenuation, shadowAttenuation, isMainLight);
    #endif

    // 暗部-明部 颜色根据漫反射过度
    half3 diffuseColor = lerp(Cals.ShadeColor.rgb, Cals.Albedo, diffuseShade);

    #if _FAKESSS_ON
        float fakeSSS = smoothstep(_FakeSSSWidth.y, 0, diffuse - _Shift_01);
        fakeSSS *= 1 - smoothstep(0, _FakeSSSWidth.x, -(diffuse - _Shift_01));
        #if _USESHADOWMAP_ON
            fakeSSS *= shadowAttenuation;
        #endif
        // 非布料区域不考虑
        diffuseColor = lerp(diffuseColor, Cals.FakeSSSColor, fakeSSS);
    #endif

    half3 F0 = 0.04;
    diffuseColor *= 1 - F0;

    return diffuseColor;
}

// 间接光
half3 GetIndirectColor(float3 N, float3 V, CalculateColors Cals)
{
    float NdotV = saturate(dot(N, V));
    half roughness = 1;
    half3 F0 = 0.04;

    // specular
    float3 R = reflect(-V, N);
    half3 KS_I = FresnelSchlickRoughness(NdotV, F0, roughness);

    half3 KD_I = 1 - KS_I; // 1 - F0;
    // half3 irradianceSH = SampleSH(N);

    half3 SH1 = SampleSH(half3(0.0,  0.0, 0.0));
    half3 SH2 = SampleSH(half3(0.0, -1.0, 0.0));
    half3 irradianceSH = max(max(SH1, SH2), 0.05);

    half3 diffuseIndirect = irradianceSH * Cals.Albedo * KD_I;// / UNITY_PI;

    //
    half3 indirectColor = diffuseIndirect * _InDirectIntensity;
    //
    indirectColor = max(0, indirectColor);

    return indirectColor;
}

void GetConfigInfo(float2 uv, inout CalculateColors cals)
{
    uv = TRANSFORM_TEX(uv, _MainTex);
    half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);

    CalculateColors Cals = {
        mainTex.rgb * _BaseColor.rgb,       // Albedo
        mainTex.rgb * _BaseColor.rgb * _ShadeColor_1.rgb,    // ShadeColor
        _FakeSSSColor.rgb,              // FakeSSSColor
        _FresnelColor.rgb,              // FresnelColor
        _FresnelShadeColor.rgb          // FresnelShadeColor
    };
    cals = Cals;
}


half3 GetSingleDirectColor(Light light, float4 uvs, half3 N, HeadRotations headRotations, CalculateColors Cals, float faceShadeAverage, float isMainLight, inout half outShadowAttenuation)
{
    float3 L = light.direction;

    half lightAttenuation = light.distanceAttenuation * light.shadowAttenuation;

    // --------------------------------------------------------------------
    // 漫反射
    half3 diffuseColor = GetDiffuseColor(N, L, uvs, lightAttenuation, headRotations, Cals, faceShadeAverage, isMainLight, outShadowAttenuation);
    // 调试用
    diffuseColor = lerp(0, diffuseColor, _F_Diffuse);

    // TODO 皮肤高光
    half3 specularColor = 0;

    half3 directColor = (diffuseColor + specularColor) * light.color;
    return directColor;
}

half3 GetDirectColor(Varyings input, half3 N, CalculateColors Cals, inout Light mainLight, inout half outShadowAttenuation)
{
    mainLight = GetMainLight(input);

    HeadRotations headRotations = (HeadRotations)0;
    headRotations.rightWS = input.headDirRightWS.xyz;
    headRotations.forwardWS = input.headDirForwardWS.xyz;

    half3 directColor = GetSingleDirectColor(mainLight, input.uvs, N, headRotations, Cals, input.faceShadeAverage, 1, outShadowAttenuation);

    #if _USEADDITIONALLIGHT_ON && defined(_ADDITIONAL_LIGHTS)
        #if !USE_CLUSTERED_LIGHTING
            for (uint lightIndex = 0u; lightIndex < GetAdditionalLightsCount(); ++lightIndex)
            {
                half shade = 1;
                half shadowAttenuationTemp = 1;
                Light light = GetAdditionalLight(lightIndex, input);
                directColor += GetSingleDirectColor(light, input.uv0, N, headRotations, Cals, input.faceShadeAverage, 0, shadowAttenuationTemp);
            }
        #endif
    #endif

    return directColor;
}


#endif // TOON_SKIN_CORE_INCLUDED