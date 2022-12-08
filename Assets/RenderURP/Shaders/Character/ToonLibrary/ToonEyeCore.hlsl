
#ifndef TOON_EYE_CORE_INCLUDED
#define TOON_EYE_CORE_INCLUDED

// ----------------------------------------------------------------
struct Attributes
{
    float4 positionOS       : POSITION;
    float2 texcoord0        : TEXCOORD0;
#if defined(_F_EYE_LIGHTING_ON)
    float3 normalOS         : NORMAL;
#endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2  uv0                     : TEXCOORD0;
    float3  positionWS              : TEXCOORD1;

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    float4  shadowCoord             : TEXCOORD2;
#endif

#if defined(_F_EYE_LIGHTING_ON)
    float3  normalWS                : TEXCOORD3;
#endif
    float4  positionCS              : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

// ----------------------------------------------------------------
// 函数部分
#include "ToonFunc/ToonFuncLight.hlsl"
#include "ToonFunc/ToonFuncEyeAnim.hlsl"
// ----------------------------------------------------------------
#if _F_EYE_UVANIM_ON
    void CalculateUVAnim(inout float2 uv)
    {
        half speed = _UVAnimSpeed * 100;
        float distort = length((uv.xy - _UVAnimDistortOffset.x) * _UVAnimDistortOffset.y);
        uv.y += sin( (_Time.y + distort) * speed ) * distort * _UVAnimDistortIntensity;
        uv.y += sin( _Time.y * speed ) * _UVAnimIntensity;
    }
#endif

#endif // TOON_EYE_CORE_INCLUDED