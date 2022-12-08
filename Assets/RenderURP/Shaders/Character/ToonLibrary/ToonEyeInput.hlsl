
#ifndef TOON_EYE_INPUT_INCLUDED
#define TOON_EYE_INPUT_INCLUDED

#include "ToonCommon.hlsl"

// -------------------------------------------------------------
CBUFFER_START(UnityPerMaterial)
    float4  _MainTex_ST;
    half    _SpecularPower;

    // 光照
    half4   _BrightColor;
    half4   _DarkColor;
    half    _Shift_01;
    half    _Gradient_01;
    half    _LightIntensityLimit;

    // _F_EYE_UVANIM_ON
    half4   _UVAnimDistortOffset;
    half    _UVAnimDistortIntensity;
    half    _UVAnimSpeed;
    half    _UVAnimIntensity;

 // -------------------------------------------------------------
    #include "ToonInput/ToonInputEyeAnim.hlsl"
CBUFFER_END

// --------------------------------------------------------------
TEXTURE2D(_MainTex);        SAMPLER(sampler_MainTex);

// --------------------------------------------------------------
#include "ToonInput/ToonInputGlobalSettings.hlsl"

#endif