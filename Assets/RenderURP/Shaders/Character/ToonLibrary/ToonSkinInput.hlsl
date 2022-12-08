
#ifndef TOON_SKIN_INPUT_INCLUDED
#define TOON_SKIN_INPUT_INCLUDED

#include "ToonCommon.hlsl"

// -------------------------------------------------------------
CBUFFER_START(UnityPerMaterial)
    float4  _MainTex_ST;
    //
    half    _F_Diffuse;

    half4   _BaseColor;
    half4   _ShadeColor_1;
    half    _Shift_01;
    half    _Gradient_01;

    half4   _FakeSSSColor;
    half4   _FakeSSSWidth;

    half    _InDirectIntensity;

    float3  _MainLightDirection;
    half    _LightIntensityLimit;

    // _FACE_SHADE_ON
    float4  _FaceShade_ST;
    half    _FaceShadeOffset;

    // -------------------------------------------------------------
    #include "ToonInput/ToonInputFresnel.hlsl"
    #include "ToonInput/ToonInputOutline.hlsl"
CBUFFER_END

// -----------------------------------------------------------------
TEXTURE2D(_MainTex);            SAMPLER(sampler_MainTex);
#if _FACE_SHADE_ON
    TEXTURE2D(_FaceShade);      SAMPLER(sampler_FaceShade);
#endif

// outline
TEXTURE2D(_OutlineMask);    SAMPLER(sampler_OutlineMask);

// --------------------------------------------
#include "ToonInput/ToonInputFresnelTex.hlsl"
#include "ToonInput/ToonInputGlobalSettings.hlsl"
#include "ToonInput/ToonInputCharacterController.hlsl"
// --------------------------------------------


#endif