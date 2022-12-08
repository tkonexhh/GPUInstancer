
#ifndef TOON_STANDARD_INPUT_INCLUDED
#define TOON_STANDARD_INPUT_INCLUDED

#include "ToonCommon.hlsl"

// -------------------------------------------------------------
CBUFFER_START(UnityPerMaterial)
    float4  _MainTex_ST;
    //
    half    _F_Specular;
    half    _F_Diffuse;

    half4   _BaseColor;
    half4   _ShadeColor_1;
    half    _Shift_01;
    half    _Gradient_01;

    half4   _FakeSSSColor;
    half4   _FakeSSSWidth;

    half4   _SpecularColor;
    half    _SpecularIntensity;

    half    _IndirectAOIntensity;
    half    _InDirectIntensity;
    half    _InDirectSpecularIntensity;

    float3  _MainLightDirection;
    half    _LightIntensityLimit;
    // -------------------------------------------------------------
    // 和头发部分差异的数据
    // _F_DYEENTIRETYFADE_ON

    float4  _NormalTex_ST;
    half    _NormalScale;

    // 头发
    #if _TOON_HAIR_ON
        half4   _DyeEntiretyFadeColor;
        half    _DyeEntiretyFadeInvert;
        half3   _DyeEntiretyFadeData;
        half    _DyeEntiretyFadeShift;
        half    _DyeEntiretyFadeAngle;

        half    _HairDetailsStrength;
        half4   _SpecularHairSNOffset;
        half    _SpecularHairBias;
        half    _SpecularHairPower;
        half    _SpecularHairFlowIntensity;
        half    _SpecularPBRIntensity;
    #else
        half    _Metallic;
        half    _Smoothness;
        half    _SpecularAnisotropic;

        float4  _EmissionTex_ST;
        half4   _EmissionColor;

        // _F_MATCAP_ON
        float4  _MatcapTex_ST;
        half4   _MatcapColor;
        float4  _MatcapMask_ST;
        half    _MatcapMaskLevel;
        half    _MatcapShadowValue;
    #endif

    // -------------------------------------------------------------
    #include "ToonInput/ToonInputDye.hlsl"
    #include "ToonInput/ToonInputClip.hlsl"
    #include "ToonInput/ToonInputFresnel.hlsl"
    #include "ToonInput/ToonInputOutline.hlsl"
CBUFFER_END

// -----------------------------------------------------------------
TEXTURE2D(_MainTex);                    SAMPLER(sampler_MainTex);
TEXTURE2D(_AreaMask);                   SAMPLER(sampler_AreaMask);
TEXTURE2D(_EmissionTex);                SAMPLER(sampler_EmissionTex);
#if _F_MATCAP_ON
    TEXTURE2D(_MatcapTex);              SAMPLER(sampler_MatcapTex);
    TEXTURE2D(_MatcapMask);             SAMPLER(sampler_MatcapMask);
#endif

// -----------------------------------------------------------------
TEXTURE2D(_NormalTex);              SAMPLER(sampler_NormalTex);
// 和头发部分差异的数据
#if _TOON_HAIR_ON
    TEXTURE2D(_HairFlowTex);            SAMPLER(sampler_HairFlowTex);
    TEXTURE2D(_HairTex);                SAMPLER(sampler_HairTex);
    TEXTURE2D(_HairPBRSpecMask);        SAMPLER(sampler_HairPBRSpecMask);
#else
    TEXTURE2D(_MatMask);                SAMPLER(sampler_MatMask);
    TEXTURE2D(_PBRTex);                 SAMPLER(sampler_PBRTex);
    TEXTURECUBE(_MetalReflectCubemap);  SAMPLER(sampler_MetalReflectCubemap);
#endif

// outline
TEXTURE2D(_OutlineMask);            SAMPLER(sampler_OutlineMask);

// --------------------------------------------

#include "ToonInput/ToonInputDyeTex.hlsl"
#include "ToonInput/ToonInputClipTex.hlsl"
#include "ToonInput/ToonInputFresnelTex.hlsl"
#include "ToonInput/ToonInputGlobalSettings.hlsl"
#include "ToonInput/ToonInputCharacterController.hlsl"
// --------------------------------------------
#endif