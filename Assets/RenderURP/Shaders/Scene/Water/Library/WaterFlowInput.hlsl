#ifndef WATERFLOW_INPUT_INCLUDED
#define WATERFLOW_INPUT_INCLUDED

#include "WaterCommon.hlsl"

// ----------------------------------------------------------
CBUFFER_START(UnityPerMaterial)
    half    _UVSpeedX;
    half    _UVSpeedY;
    half    _NormalScale;
    float4  _NormalTex_ST;
    half    _MaskIntensity;
    float4  _MaskTex_ST;
    half    _ReflectionStrength;
    float3  _LightDirection;
    half    _SpecularRoughness;
    half4   _SpecularColor;
    half    _SpecularIntensity;
CBUFFER_END

TEXTURE2D(_NormalTex);                  SAMPLER(sampler_NormalTex);
TEXTURE2D(_MaskTex);                    SAMPLER(sampler_MaskTex);
TEXTURECUBE(_ReflectCubemap);           SAMPLER(sampler_ReflectCubemap);
TEXTURE2D(_GrabTexture);                SAMPLER(sampler_GrabTexture);


// ----------------------------------------------------------

void GetNormal(float2 uv, half3x3 tangentToWorld, inout half3 normalTS, inout half3 normalWS)
{
    float2 normalUV = TRANSFORM_TEX(uv, _NormalTex) + frac(5.0 * _Time.y * half2(_UVSpeedX, _UVSpeedY));
    half4 normalTXS = SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, normalUV);

	normalTS = UnpackNormalScale(normalTXS, _NormalScale);
    normalWS = NormalizeNormalPerPixel(TransformTangentToWorld(normalTS, tangentToWorld));
}

half3 GetReflectionCustom(half3 viewDirWS, half3 normalWS)
{
    half3 reflectVector = normalize(reflect(-viewDirWS, normalWS));
    half4 reflection = SAMPLE_TEXTURECUBE_LOD(_ReflectCubemap, sampler_ReflectCubemap, reflectVector, 0);
    reflection.rgb *= reflection.a * _ReflectionStrength;
	
    return reflection.rgb;
}

half3 GetGrabColor(float4 positionNDC, half3 normalTS)
{
    float2 uv = positionNDC.xy * rcp(positionNDC.w) + normalTS.xy; 
    return SAMPLE_TEXTURE2D(_GrabTexture, sampler_GrabTexture, uv).rgb;
}

half GetMask(float2 uv)
{
    float2 maskUV = TRANSFORM_TEX(uv, _MaskTex) + frac(5.0 * _Time.y * half2(_UVSpeedX, _UVSpeedY));
    half mask = SAMPLE_TEXTURE2D(_MaskTex, sampler_MaskTex, maskUV).r;

    return saturate(mask * _MaskIntensity);
}


#endif // WATERFLOW_INPUT_INCLUDED
