#ifndef SKYCLOUD_INPUT_INCLUDED
#define SKYCLOUD_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

// ----------------------------------------------------------
// TODO 因为使用了PropertyBlock URP batch并不过工作
// CBUFFER_START(UnityPerMaterial)
    half        _RayleighMultiplier;
    half        _MieMultiplier;
    // half        _Directionality;
    half        _Contrast;
    half        _Brightness;

    half4       _DaySkyColor;
    half        _SunHaloSize;
    half4       _SunColor;
    half        _SunSize;

    half4       _NightSkyColor;
    half        _MoonHaloSize;
    half4       _MoonHaloColor;
    half4       _MoonColor;
    half        _MoonSize;

    half4       _GroundColor;

    float3      _LocalSunDirection;
    float3      _LocalMoonDirection;

    float4x4    _WorldToMoonMatrix;

    // -----------------------------------------
    half3       _CloudSize;
    half4       _CloudWind;
    half4       _CloudNightColor;
    half4       _CloudDayColor;
    half        _CloudScattering;
    half        _CloudBrightness;
    half        _CloudColoring;
    half        _CloudOpacity;
    half        _CloudCoverage;
    half        _CloudDensity;
    half        _CloudAttenuation;
    half        _CloudSaturation;
    half        _CloudSkyColorIntensity;
    half        _CloudClip;
// CBUFFER_END

TEXTURE2D(_MoonTexture);                  SAMPLER(sampler_MoonTexture);
TEXTURE2D(_CloudTexture);                 SAMPLER(sampler_CloudTexture);

// ----------------------------------------------------------

#define SCATTERING_SAMPLES 2
static const float _kInnerRadius = 1;
static const float _kOuterRadius = 1.025f;
static const float _kCameraHeight = 0.0001f;
static const float _kScaleDepth = 0.25f;
static const float3 _kWavelength_rgb = float3(0.66, 0.57, 0.475);
static const float _kSunBrightness = 40;

#define ROTATION_UV(angle) float2x2(cos(angle), -sin(angle), sin(angle), cos(angle))



#endif // SKYCLOUD_INPUT_INCLUDED
