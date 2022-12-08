
#ifndef TOON_TCP_LEGACY_INPUT_INCLUDED
#define TOON_TCP_LEGACY_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/BRDF.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"

// -----------------------------------------------------------------
CBUFFER_START(UnityPerMaterial)
    float4  _MainTex_ST;
    half4   _Color;
    half    _RampThreshold;
    half    _RampSmoothing;
    half4   _HColor;
    half4   _SColor;

    half    _OutlineWidth;
    half4   _OutlineColorVertex;
CBUFFER_END

// -----------------------------------------------------------------
TEXTURE2D(_MainTex);                    SAMPLER(sampler_MainTex);


// -----------------------------------------------------------------

#endif