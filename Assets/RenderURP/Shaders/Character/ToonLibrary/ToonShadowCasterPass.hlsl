
#ifndef TOON_SHADOW_CASTER_INCLUDED
#define TOON_SHADOW_CASTER_INCLUDED

// -----------------------------------------------------------------------------------
// 实际用到的数据 现在合并到对应的主Pass数据CBUFFER中
// #include "ToonCommon.hlsl"
// #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

// // -------------------------------------------------------------
// // Input
// CBUFFER_START(UnityPerMaterial)
//     float4 _MainTex_ST;

//     // ---------------------------------------------------------
//     #include "ToonInput/ToonInputClip.hlsl"
//     #include "ToonInput/ToonInputEyeAnim.hlsl"

// CBUFFER_END
// // --------------------------------------------
// TEXTURE2D(_MainTex);    SAMPLER(sampler_MainTex);

// #include "ToonInput/ToonInputClipTex.hlsl"
// -----------------------------------------------------------------------------------
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

// --------------------------------------------
float3  _LightDirection;
float3  _LightPosition;

// -------------------------------------------------------------
// Core
struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float2 texcoord     : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv           : TEXCOORD0;
    float4 positionCS   : SV_POSITION;
};

// --------------------------------------------------------------
// 函数部分 如果对应的Input中没有数据 理论上对应的宏也不应该被打开
#include "ToonFunc/ToonFuncClip.hlsl"
#include "ToonFunc/ToonFuncEyeAnim.hlsl"

float4 GetShadowPositionHClip(Attributes input)
{
    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
    float3 normalWS = TransformObjectToWorldNormal(input.normalOS);

    #if _CASTING_PUNCTUAL_LIGHT_SHADOW
        float3 lightDirectionWS = normalize(_LightPosition - positionWS);
    #else
        float3 lightDirectionWS = _LightDirection;
    #endif

    float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));

    #if UNITY_REVERSED_Z
        positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
    #else
        positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
    #endif

    return positionCS;
}

// -------------------------------------------------------------
// Pass
Varyings ToonShadowPassVertex(Attributes input)
{
   
    Varyings output;
    UNITY_SETUP_INSTANCE_ID(input);

    #if _F_EYE_SPECULARANIM_ON
        CalculateEyeSpecularAnim(input.texcoord, input.positionOS);
    #endif

    output.uv = TRANSFORM_TEX(input.texcoord, _MainTex);
    output.positionCS = GetShadowPositionHClip(input);
    return output;
}

half4 ToonShadowPassFragment(Varyings input) : SV_TARGET
{
    #if __RENDERMODE_CUTOUT
        half clipMask = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv).a;
        CheckClip(clipMask, input.uv);
    #endif       

    return 0;
}

#endif