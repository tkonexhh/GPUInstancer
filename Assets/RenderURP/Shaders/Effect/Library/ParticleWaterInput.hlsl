#ifndef PARTICLEWATER_INPUT_INCLUDED
#define PARTICLEWATER_INPUT_INCLUDED

#include "../../Scene/Water/Library/WaterCommon.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

// 不支持SRP batch TODO ParticlesInstancing

half4   _MainColor;

half    _VertexNoiseIntensity;
half    _VertexNoiseFrequency;
half    _VertexNoiseSpeedX;
half    _VertexNoiseSpeedY;

half    _NormalScale;
half    _NormalTiling;
float4  _NormalUVDirection;
half    _NormalUVSpeed;
half    _RefractionDistort;

half    _ReflectionNormalScale;
half    _ReflectionStrength;
half4   _ReflectColor;
half4   _ReflectAddColor;

half    _SpecularRoughness;
half4   _SpecularColor;
half    _SpecularIntensity;

TEXTURE2D(_VertexNoiseTex);                 SAMPLER(sampler_VertexNoiseTex);
TEXTURE2D(_NormalTex);                      SAMPLER(sampler_NormalTex);
TEXTURE2D(_GrabTexture);                    SAMPLER(sampler_GrabTexture);
TEXTURECUBE(_ReflectCubemap);               SAMPLER(sampler_ReflectCubemap);

void CalculateVertexNoise(float2 uv, float4 color, float3 normalOS, inout float4 positionOS)
{
    uv *= _VertexNoiseFrequency;
    uv += (float2(_VertexNoiseSpeedX, _VertexNoiseSpeedY) * _Time.y);

    float4 vertexNoise = SAMPLE_TEXTURE2D_LOD(_VertexNoiseTex, sampler_VertexNoiseTex, uv, 0);

    positionOS.xyz += normalOS * vertexNoise.xyz * _VertexNoiseIntensity * color.a;
}

void GetNormal(float2 uv, float3x3 tangentToWorld, half normalScale, inout half3 normalTS, inout half3 normalWS)
{
    uv *= _NormalTiling;

    float2 uv_a = uv + frac(_Time.y * _NormalUVDirection.xy * _NormalUVSpeed);
    float2 uv_b = uv + frac(_Time.y * _NormalUVDirection.zw * _NormalUVSpeed);

    half3 normalTS_a = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, uv_a), normalScale);
    half3 normalTS_b = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, uv_b), normalScale);

	normalTS = BlendNormalRNM(normalTS_a, normalTS_b);

    normalWS = NormalizeNormalPerPixel(TransformTangentToWorld(normalTS, tangentToWorld));
}

half4 GetGrabColor(float4 positionNDC, half3 normalTS)
{
    float2 screenUV = (positionNDC.xy + normalTS.xy * _RefractionDistort) * rcp(positionNDC.w);
    return SAMPLE_TEXTURE2D(_GrabTexture, sampler_GrabTexture, screenUV);
}

half3 GetReflectionCustom(half3 viewDirWS, half3 normalWS)
{
    half3 reflectVector = normalize(reflect(-viewDirWS, normalWS));
    half4 reflection = SAMPLE_TEXTURECUBE_LOD(_ReflectCubemap, sampler_ReflectCubemap, reflectVector, 0);
    reflection.rgb *= reflection.a * _ReflectionStrength * _ReflectColor.rgb;
	
    return reflection.rgb;
}


#endif // PARTICLEWATER_INPUT_INCLUDED
