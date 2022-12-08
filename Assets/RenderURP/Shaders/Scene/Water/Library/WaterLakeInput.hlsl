#ifndef WATERLAKE_INPUT_INCLUDED
#define WATERLAKE_INPUT_INCLUDED

#include "WaterCommon.hlsl"

// ----------------------------------------------------------
CBUFFER_START(UnityPerMaterial)
    half    _WaterSpeed;
    half    _WaterDistortScale;

    half    _NormalScale;
    half    _NormalTiling;
    half4   _WaterColor;
    half4   _WaterColorGrazing;
    half    _FadeShallow;

    half    _ReflectionStrength;
    
    half    _SSRMaxCount;
    half    _SSRStep;

    float3  _LightDirection;
    half    _DiffuseLightIntensity;
    half    _ShadowIntensity;
        
    half    _SpecularRoughness;
    half4   _SpecularColor;
    half    _SpecularIntensity;
    half    _SpecularNormalScale;
CBUFFER_END

TEXTURE2D(_NormalTex);                  SAMPLER(sampler_NormalTex);
TEXTURECUBE(_ReflectCubemap);           SAMPLER(sampler_ReflectCubemap);
TEXTURE2D(_GrabTexture);                SAMPLER(sampler_GrabTexture);


// ----------------------------------------------------------

void GetNormal(float2 uv, float3x3 tangentToWorld, float normalTiling, float normalScale, 
        inout half3 normalTS, inout half3 normalWS)
{
    uv *= normalTiling;

    float2 uv_a = uv + frac(_Time.y * float2(-0.03, 0) * _WaterSpeed);
    float2 uv_b = uv + frac(_Time.y * float2(0.04, 0.04) * _WaterSpeed);

    half3 normalTS_a = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, uv_a), normalScale);
    half3 normalTS_b = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, uv_b), normalScale);
	normalTS = BlendNormalRNM(normalTS_a, normalTS_b);

    normalWS = NormalizeNormalPerPixel(TransformTangentToWorld(normalTS, tangentToWorld));
}

half3 GetReflectionCustom(half3 reflectVector)
{
    half4 reflection = SAMPLE_TEXTURECUBE_LOD(_ReflectCubemap, sampler_ReflectCubemap, reflectVector, 0);
    reflection.rgb *= reflection.a;
	
    return reflection.rgb;
}

float2 GetScreenUV(float4 positionNDC)
{
    return positionNDC.xy * rcp(positionNDC.w);
}

half4 GetGrabColor(float2 screenUV)
{
    return SAMPLE_TEXTURE2D(_GrabTexture, sampler_GrabTexture, screenUV);
}

half4 GetGrabColor(float4 positionNDC, half3 normalTS)
{
    float2 screenUV = (positionNDC.xy + normalTS.xy * _WaterDistortScale) * rcp(positionNDC.w);
    return GetGrabColor(screenUV);
}

#endif // WATERLAKE_INPUT_INCLUDED
