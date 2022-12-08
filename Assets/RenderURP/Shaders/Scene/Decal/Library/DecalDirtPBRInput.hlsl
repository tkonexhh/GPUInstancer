#ifndef DECALDIRTPBR_INPUT_INCLUDED
#define DECALDIRTPBR_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ParallaxMapping.hlsl"
// DBuffer.hlsl里面有SurfaceData.hlsl, 定义了SurfaceData结构体
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"

#define _NORMALMAP
#define _OCCLUSIONMAP
#ifdef _F_EMISSION_ON
    #define _EMISSION
#endif
// 为了不触发ssao = SampleAmbientOcclusion(normalizedScreenSpaceUV);
#define _SURFACE_TYPE_TRANSPARENT

CBUFFER_START(UnityPerMaterial)
    float4      	_MainTex_ST;
    half4   		_Color;
    half            _Metallic;
    half            _Smoothness;
    half            _BumpScale;
    half            _OcclusionStrength;

    // #if _F_DISSOLVE_ON
    float4      _DissolveTex_ST;
    half        _DissolveInvert;
    half        _DissolveSpread;
    half 		_DissolveThreshold;
    half        _DissolveEdgeWidth;
    half4       _DissolveEdgeColor;

    half        _DissolveChannel;
    // #endif

    #if _F_EMISSION_ON
        half3 		_EmissionColor;
    #endif
CBUFFER_END

#if _F_DISSOLVE_ON
    TEXTURE2D(_DissolveTex);			SAMPLER(sampler_DissolveTex);
#endif

#if _F_EMISSION_ON
    TEXTURE2D(_EmissionTex);			SAMPLER(sampler_EmissionTex);
#endif

TEXTURE2D(_MainTex);					SAMPLER(sampler_MainTex);
// 为了兼容材质的debug模式，需要mipinfo
// Lit材质的mipinfo为_BaseMap_MipInfo，定义在Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl里面
float4          _MainTex_TexelSize;
float4          _MainTex_MipInfo;
TEXTURE2D(_MetallicGlossMap);           SAMPLER(sampler_MetallicGlossMap);
TEXTURE2D(_BumpMap);                    SAMPLER(sampler_BumpMap);
TEXTURE2D(_OcclusionMap);               SAMPLER(sampler_OcclusionMap);
TEXTURE2D_X_FLOAT(_CameraDepthTexture); SAMPLER(sampler_CameraDepthTexture);

// -------------------------------------------------------------------------

// -------------------------------------------------------------------------
half4 SampleAlbedo(float2 uv)
{
    return half4(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv));
}

half Alpha(half albedoAlpha, half4 color, half cutoff)
{
    half alpha = albedoAlpha * color.a;

    #if defined(_ALPHATEST_ON)
        clip(alpha - cutoff);
    #endif

    return alpha;
}

#define SAMPLE_METALLICSPECULAR(uv) SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, uv)

// 简化，只使用金属流程
half4 SampleMetallicSpecGloss(float2 uv)
{
    half4 specGloss;
    specGloss = half4(SAMPLE_METALLICSPECULAR(uv));
    specGloss.rgb *= _Metallic;
    specGloss.a = _Smoothness;
    return specGloss;
}

half3 SampleNormal(float2 uv, half scale = half(1.0))
{
#ifdef _NORMALMAP
    half4 n = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uv);
    #if BUMP_SCALE_NOT_SUPPORTED
        return UnpackNormal(n);
    #else
        return UnpackNormalScale(n, scale);
    #endif
#else
    return half3(0.0h, 0.0h, 1.0h);
#endif
}

half SampleOcclusion(float2 uv)
{
    #ifdef _OCCLUSIONMAP
        // TODO: Controls things like these by exposing SHADER_QUALITY levels (low, medium, high)
        #if defined(SHADER_API_GLES)
            return SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
        #else
            half occ = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
            return LerpWhiteTo(occ, _OcclusionStrength);
        #endif
    #else
        return half(1.0);
    #endif
}

half3 SampleEmission(float2 uv)
{
#ifndef _EMISSION
    return 0;
#else
    half4 emissionTex = SAMPLE_TEXTURE2D(_EmissionTex, sampler_EmissionTex, uv);
    return emissionTex.rgb * emissionTex.a * _EmissionColor.rgb;
#endif
}


// --------------------------------------------------------------------------------------------

inline void InitializeStandardLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)
{
    half4 albedo = SampleAlbedo(uv);
    outSurfaceData.alpha = Alpha(albedo.a, _Color, 0);
    outSurfaceData.albedo = albedo.rgb * _Color.rgb;

    half4 specGloss = SampleMetallicSpecGloss(uv);
    outSurfaceData.metallic = specGloss.r;
    outSurfaceData.specular = half3(0.0, 0.0, 0.0);
    outSurfaceData.smoothness = specGloss.a;

    outSurfaceData.normalTS = SampleNormal(uv, _BumpScale);
    outSurfaceData.occlusion = SampleOcclusion(uv);
    outSurfaceData.emission = SampleEmission(uv);


    outSurfaceData.clearCoatMask       = half(0.0);
    outSurfaceData.clearCoatSmoothness = half(0.0);
}

#endif