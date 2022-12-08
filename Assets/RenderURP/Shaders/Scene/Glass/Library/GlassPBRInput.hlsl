#ifndef GLASSPBR_INPUT_INCLUDED
#define GLASSPBR_INPUT_INCLUDED


#if __RENDERMODE_FADE
    #define _Surface 1
#elif __RENDERMODE_TRANSPARENT
    #if _F_REFLECTION_ON
        #define _Surface 0
    #else
        #define _Surface 1
    #endif
    #define _ALPHAPREMULTIPLY_ON 1
#else
    #define _Surface 0
#endif
#if _METALLICGLOSSUSE_TEXTURE
    #define _METALLICSPECGLOSSMAP 1
#endif
#if !_SPECULARHIGHLIGHTS_ON
    #define _SPECULARHIGHLIGHTS_OFF 1
#endif
#if !_GLOSSYREFLECTIONS_ON
    #define _ENVIRONMENTREFLECTIONS_OFF 1
#endif
#if _USENORMALMAP_ON
    #define _NORMALMAP 1
#endif
#if _USEEMISSIONMAP_ON
    #define _EMISSION 1
#endif
#define _OCCLUSIONMAP 1
#if __RENDERMODE_OPAQUE && _F_INTERIOR_ON
    #define REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR 1
#endif

// 为了不触发ssao = SampleAmbientOcclusion(normalizedScreenSpaceUV);
#define _SURFACE_TYPE_TRANSPARENT

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ParallaxMapping.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"


CBUFFER_START(UnityPerMaterial)
    float4  _MainTex_ST;
    half4   _Color;
    float4  _MetallicGlossMap_ST;
    half    _Glossiness;
    half    _Metallic;
    half    _GlossMapScale;
    float4  _BumpMap_ST;
    half    _BumpScale;
    float4  _EmissionMap_ST;
    half4   _EmissionColor;
    float4  _OcclusionMap_ST;
    half    _OcclusionStrength;

    // -------------------------------
    half    _FresnelStrength;
    half4   _FresnelColor;

    half    _FakeRefSpeed;
    half    _FakeRefIntensity;
    half    _FakeRefPow;
    half    _FakeRefRotation;
    half4   _FakeRefColor;
    half    _FakeRefTwinkle;

    float4  _InteriorTex_ST;
    half    _InteriorXCount;
    half    _InteriorYCount;
    half    _InteriorIndex;
    half    _InteriorDepth;
    half    _InteriorXYScale;
    half    _InteriorWidthRate;
    half4   _InteriorColor;
    half    _InteriorIntensity;

    float4  _InteriorDecalTex_ST;
    half    _InteriorDecalDepth;
    half    _InteriorDecalBumpScale;
    half    _InteriorDecalMetallic;
    half    _InteriorDecalGlossiness;

    // --------------------------------
    half    _RefractionDistort;
CBUFFER_END

// -------------------------------------------------------------------------
TEXTURE2D(_MainTex);                SAMPLER(sampler_MainTex);
// 为了兼容材质的debug模式，需要mipinfo
// Lit材质的mipinfo为_BaseMap_MipInfo，定义在Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl里面
float4  _MainTex_TexelSize;
float4  _MainTex_MipInfo;
TEXTURE2D(_MetallicGlossMap);       SAMPLER(sampler_MetallicGlossMap);
TEXTURE2D(_BumpMap);                SAMPLER(sampler_BumpMap);
TEXTURE2D(_EmissionMap);            SAMPLER(sampler_EmissionMap);
TEXTURE2D(_OcclusionMap);           SAMPLER(sampler_OcclusionMap);

TEXTURECUBE(_ReflectCubemap);       SAMPLER(sampler_ReflectCubemap);
// -------------------------------------------------------------------------
TEXTURE2D(_FakeRefTex);             SAMPLER(sampler_FakeRefTex);

TEXTURE2D(_InteriorTex);            SAMPLER(sampler_InteriorTex);
TEXTURE2D(_InteriorBlurTex);        SAMPLER(sampler_InteriorBlurTex);

// 假室内窗户贴花
TEXTURE2D(_InteriorDecalTex);       SAMPLER(sampler_InteriorDecalTex);
TEXTURE2D(_InteriorDecalBumpMap);   SAMPLER(sampler_InteriorDecalBumpMap);
TEXTURE2D(_InteriorDecalMetalMap);  SAMPLER(sampler_InteriorDecalMetalMap);

#if _F_REFRACTION_ON
    TEXTURE2D(_GrabTexture);                SAMPLER(sampler_GrabTexture);
#endif
// -------------------------------------------------------------------------

half Alpha(half albedoAlpha, half4 color, half cutoff)
{
    half alpha = albedoAlpha * color.a;

    #if defined(_ALPHATEST_ON)
        clip(alpha - cutoff);
    #endif

    return alpha;
}

half4 SampleAlbedo(float2 uv)
{
    return half4(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv));
}


half3 SampleNormal(float2 uv, half scale = half(1.0))
{
    #ifdef _NORMALMAP
        half4 n = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uv);
        // #if BUMP_SCALE_NOT_SUPPORTED
        //     return UnpackNormal(n);
        // #else
            return UnpackNormalScale(n, scale);
        // #endif
    #else
        return half3(0.0h, 0.0h, 1.0h);
    #endif
}

half3 SampleEmission(float2 uv)
{
    #ifndef _EMISSION
        return 0;
    #else
        return SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, uv).rgb * _EmissionColor.rgb;
    #endif
}

// r: metallic a: smoothness URP通道
// 只使用金属流程
half2 SampleMetallicSpecGloss(float2 uv)
{
    half2 specGloss;

    #ifdef _METALLICSPECGLOSSMAP
        specGloss = SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, uv).ra;
        specGloss.g *= _GlossMapScale;
    #else // _METALLICSPECGLOSSMAP
        specGloss.r = _Metallic;
        specGloss.g = _Glossiness;
    #endif

    return specGloss;
}

// g: occlusion URP通道
half SampleOcclusion(float2 uv)
{
    #ifdef _OCCLUSIONMAP
        half occ = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
        return LerpWhiteTo(occ, _OcclusionStrength);
    #else
        return half(1.0 - _OcclusionStrength);
    #endif
}

#if _F_REFRACTION_ON
    half4 GetGrabColor(float4 positionNDC, half3 normalTS)
    {
        float2 screenUV = (positionNDC.xy + normalTS.xy * _RefractionDistort) * rcp(positionNDC.w);
        return SAMPLE_TEXTURE2D(_GrabTexture, sampler_GrabTexture, screenUV);
    }
#endif

// --------------------------------------------------------------------------------------------

inline void InitializeStandardLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)
{
    half4 albedo = SampleAlbedo(uv);
    outSurfaceData.alpha = Alpha(albedo.a, _Color, 0);
    outSurfaceData.albedo = albedo.rgb * _Color.rgb;

    half2 specGloss = SampleMetallicSpecGloss(uv);
    outSurfaceData.metallic = specGloss.r;
    outSurfaceData.specular = half3(0.0, 0.0, 0.0);
    outSurfaceData.smoothness = specGloss.g;

    outSurfaceData.normalTS = SampleNormal(uv, _BumpScale);
    outSurfaceData.occlusion = SampleOcclusion(uv);
    outSurfaceData.emission = SampleEmission(uv);


    outSurfaceData.clearCoatMask       = half(0.0);
    outSurfaceData.clearCoatSmoothness = half(0.0);
}

#endif // GLASSPBR_INPUT_INCLUDED
