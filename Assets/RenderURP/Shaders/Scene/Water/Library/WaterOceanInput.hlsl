#ifndef WATEROCEAN_INPUT_INCLUDED
#define WATEROCEAN_INPUT_INCLUDED

#include "WaterCommon.hlsl"

// ----------------------------------------------------------
CBUFFER_START(UnityPerMaterial)
    half    _WaterSpeed;

    half    _NormalScale;
    half    _NormalTiling;
    half4   _WaterColor;
    half4   _WaterColorGrazing;
    half    _FadeShallow;
    half4   _WaterColorShallow;
    half    _FadeShallowSp;

    half    _ReflectionStrength;
    half4   _ReflectionFixColor;
    
    half    _SSRMaxCount;
    half    _SSRStep;

    float3  _LightDirection;
    half    _DiffuseLightIntensity;
    half    _ShadowIntensity;

    half    _SpecularDist;
    half    _SpecularMipmap;
    half    _SpecularRoughness;
    half4   _SpecularColor;
    half    _SpecularIntensity;
    half    _SpecularPower;
    half    _SpecularNormalScale;

    half4   _CausticsColor;
    half    _CausticsIntensity;
    half    _CausticsTiling;
    half    _CausticsSpeed;
    half2   _CausticsRange;
    half    _CausticsDistort;

    half    _FoamIntensity;
    half    _FoamTiling;
    half    _FoamFeather;
    half    _FoamThreshold;
    half    _FoamSpeed;
    half    _FoamNormalIntensity;
    half    _FoamNormalOffset;
    half    _FoamNormalWrap;
CBUFFER_END

TEXTURE2D(_NormalTex);                  SAMPLER(sampler_NormalTex);
TEXTURE2D(_GrabTexture);                SAMPLER(sampler_GrabTexture);
TEXTURE2D(_CausticsTex);                SAMPLER(sampler_CausticsTex);
TEXTURE2D(_FoamTex);                    SAMPLER(sampler_FoamTex);


// ----------------------------------------------------------

void GetNormal(float2 uv, float3x3 tangentToWorld, float normalTiling, float normalScale, half mip,
        inout half3 normalTS, inout half3 normalWS)
{
    uv *= normalTiling;

    float2 uv_a = uv + frac(_Time.y * float2(-0.03, 0) * _WaterSpeed);
    float2 uv_b = uv + frac(_Time.y * float2(0.04, 0.04) * _WaterSpeed);

    half3 normalTS_a = UnpackNormalScale(SAMPLE_TEXTURE2D_LOD(_NormalTex, sampler_NormalTex, uv_a, mip), normalScale);
    half3 normalTS_b = UnpackNormalScale(SAMPLE_TEXTURE2D_LOD(_NormalTex, sampler_NormalTex, uv_b, mip), normalScale);

	normalTS = BlendNormalRNM(normalTS_a, normalTS_b);

    normalWS = NormalizeNormalPerPixel(TransformTangentToWorld(normalTS, tangentToWorld));
}

float2 GetScreenUV(float4 positionNDC)
{
    return positionNDC.xy * rcp(positionNDC.w);
}

half4 GetGrabColor(float2 screenUV)
{
    return SAMPLE_TEXTURE2D(_GrabTexture, sampler_GrabTexture, screenUV);
}

#if _F_CAUSTICS_ON
    half3 GetCausticsColor(float2 uv, half3 normalWS)
    {
        float speed = _Time.y * _CausticsSpeed;

        float2 cuv1 = uv / _CausticsTiling + frac(float2(0.044 * speed + 17.16, -0.169 * speed));
        float2 cuv2 = uv / _CausticsTiling * 1.37 + frac(float2(0.248 * speed, 0.117 * speed));
    
        half2 distort = normalWS.xy * _CausticsDistort;
        half3 c1 = SAMPLE_TEXTURE2D(_CausticsTex, sampler_CausticsTex, cuv1 + distort).rgb;
        half3 c2 = SAMPLE_TEXTURE2D(_CausticsTex, sampler_CausticsTex, cuv2 + distort).rgb;

        half3 causticsColor = min(c1, c2);//0.5 * (c1 + c2);

        return causticsColor;
    }
#endif

#if _F_FOAM_ON
	half GetFoam(float2 uv, float2 offset, half scale, half feather, half threshold)
	{
		uv = (uv + offset) * scale - sin(_Time.y * _FoamSpeed * 2.0) * 0.1;
		half ft = SAMPLE_TEXTURE2D(_FoamTex, sampler_FoamTex, uv).r;

		half result = saturate(1.0 - threshold);
		return smoothstep(result, result + feather, ft);
	}
#endif


#endif // WATEROCEAN_INPUT_INCLUDED
