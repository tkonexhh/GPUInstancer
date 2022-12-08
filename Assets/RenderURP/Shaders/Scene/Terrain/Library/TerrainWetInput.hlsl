#ifndef TERRAINWET_INPUT_INCLUDED
#define TERRAINWET_INPUT_INCLUDED

#define _NORMALMAP 1
#if _USEPARALLAX_0_ON
    #define _PARALLAXMAP 1
#endif

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ParallaxMapping.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"
#include "TerrainCommon.hlsl"

CBUFFER_START(UnityPerMaterial)
    float4  _Splat_0_ST;
    half4   _SplatColor_0;
    float4  _Normal_0_ST;
    half    _NormalScale_0;
    half    _Metallic_0;
    half    _Smoothness_0;
    float4  _PropMap_0_ST;
    half    _OcclusionStrength_0;
    half    _Parallax_0;

    // ---------------------------------------
    float4  _PuddleTex_ST;
    half4   _PuddleColor;
    half    _PuddleMetallic;
    half    _PuddleSmoothness;

    float4  _PuddleMask_ST;
    half    _PuddleMaskIntensity;
    half    _PuddleMaskContrast;
    half    _PuddleMaskSpread;

    float4  _PuddleNormalMap_ST;
    half    _PuddleNormalIntensity_1;
    half    _PuddleNormalSpeed_1;
    half    _PuddleNormalRotation_1;
    half    _PuddleNormalTiling_1;
    half    _PuddleNormalIntensity_2;
    half    _PuddleNormalSpeed_2;
    half    _PuddleNormalRotation_2;
    half    _PuddleNormalTiling_2;

    float4  _RippleColRowSpeedStart;
    float4  _RippleNormalMap_ST;
    half    _RippleNormalTiling;
    half    _RippleNormalIntensity_1;
    half    _RippleNormalIntensity_2;
    half    _RippleNormalScale_2;
    half    _RippleNormalRotation_2;
    float2  _RippleNormalOffset_2;

    half4   _PuddleReflectColor;
    half    _PuddleReflectIntensity;
    half    _PuddleReflectBlur;

    half4   _RainDotGradientTex_ST;
    half    _RainDotIntensity;
    half    _RainDotTiling;
    half    _RainDotSpeed;
    half    _RainDotSize;
CBUFFER_END
// ---------------------------------------
TEXTURE2D(_Splat_0);                SAMPLER(sampler_Splat_0);
TEXTURE2D(_Normal_0);               SAMPLER(sampler_Normal_0);
TEXTURE2D(_PropMap_0);              SAMPLER(sampler_PropMap_0);

// ---------------------------------------
TEXTURE2D(_PuddleTex);              SAMPLER(sampler_PuddleTex);
TEXTURE2D(_PuddleMask);             SAMPLER(sampler_PuddleMask);

TEXTURE2D(_PuddleNormalMap);        SAMPLER(sampler_PuddleNormalMap);

TEXTURE2D(_RippleNormalMap);        SAMPLER(sampler_RippleNormalMap);
TEXTURECUBE(_PuddleReflectCubemap); SAMPLER(sampler_PuddleReflectCubemap);
TEXTURE2D(_RainDotGradientTex);     SAMPLER(sampler_RainDotGradientTex);

// ---------------------------------------

float GetParallaxMapHeight(TEXTURE2D_PARAM(heightMap, sampler_heightMap), float2 uv)
{
    // URP g通道 改到a通道
	return SAMPLE_TEXTURE2D(heightMap, sampler_heightMap, uv).a;
}

float2 ParallaxRaymarching(float2 uv, float2 viewDir, TEXTURE2D_PARAM(heightMap, sampler_heightMap), half height) 
{
    #if !defined(PARALLAX_RAYMARCHING_STEPS)
        #define PARALLAX_RAYMARCHING_STEPS 10
    #endif
	float2 uvOffset = 0;
	float stepSize = 1.0 / PARALLAX_RAYMARCHING_STEPS;
	float2 uvDelta = viewDir * (stepSize * height);

	float stepHeight = 1;
	float surfaceHeight = GetParallaxMapHeight(TEXTURE2D_ARGS(heightMap, sampler_heightMap), uv);

	float2 prevUVOffset = uvOffset;
	float prevStepHeight = stepHeight;
	float prevSurfaceHeight = surfaceHeight;

    for (int i = 1; i < PARALLAX_RAYMARCHING_STEPS && stepHeight > surfaceHeight; i++) {
        prevUVOffset = uvOffset;
		prevStepHeight = stepHeight;
		prevSurfaceHeight = surfaceHeight;

		uvOffset -= uvDelta;
		stepHeight -= stepSize;
		surfaceHeight = GetParallaxMapHeight(TEXTURE2D_ARGS(heightMap, sampler_heightMap), uv + uvOffset);
	}

    #if !defined(PARALLAX_RAYMARCHING_INTERPOLATE)
        #define PARALLAX_RAYMARCHING_INTERPOLATE 1
    #endif
	#if !defined(PARALLAX_RAYMARCHING_SEARCH_STEPS)
		#define PARALLAX_RAYMARCHING_SEARCH_STEPS 3
	#endif
	#if PARALLAX_RAYMARCHING_SEARCH_STEPS > 0
		for (int i = 0; i < PARALLAX_RAYMARCHING_SEARCH_STEPS; i++) 
        {
            uvDelta *= 0.5;
			stepSize *= 0.5;

            if (stepHeight < surfaceHeight) {
				uvOffset += uvDelta;
				stepHeight += stepSize;
			}
			else {
				uvOffset -= uvDelta;
				stepHeight -= stepSize;
			}
    		surfaceHeight = GetParallaxMapHeight(TEXTURE2D_ARGS(heightMap, sampler_heightMap), uv + uvOffset);
		}
	#elif defined(PARALLAX_RAYMARCHING_INTERPOLATE)
        float prevDifference = prevStepHeight - prevSurfaceHeight;
        float difference = surfaceHeight - stepHeight;
        float t = prevDifference / (prevDifference + difference);
        // uvOffset = lerp(prevUVOffset, uvOffset, t);
        uvOffset = prevUVOffset - uvDelta * t;
    #endif

	return uvOffset;
}

float2 ParallaxMapping_Terrain(float2 uv, half3 viewDir, TEXTURE2D_PARAM(heightMap, sampler_heightMap), half scale)
{
    #if !defined(_PARALLAXMAP)
        return uv;
    #else
        half h = GetParallaxMapHeight(TEXTURE2D_ARGS(heightMap, sampler_heightMap), uv);

        #if _PARALLAXRAYMARCH_ON
            float2 offset = ParallaxRaymarching(uv, viewDir, TEXTURE2D_ARGS(heightMap, sampler_heightMap), scale);
        #else
            float2 offset = ParallaxOffset1Step(h, scale, viewDir);
        #endif

        return uv + offset;
    #endif
}

inline void InitializeTerrainSurfaceData(float3 viewDirTS, float2 uv, out SurfaceData outSurfaceData)
{
    // tilling后uv
    uv = TRANSFORM_TEX(uv, _Splat_0);
     // 视差偏移后uv
    #if _USEPARALLAX_0_ON
        uv = ParallaxMapping_Terrain(uv, viewDirTS, TEXTURE2D_ARGS(_Splat_0, sampler_Splat_0), _Parallax_0);
    #endif
    
    // 基础贴图
    float4 layer0 = SAMPLE_TEXTURE2D(_Splat_0, sampler_Splat_0, uv);

    // 通道图对基础图进行混合
    half3 albedo = _SplatColor_0 * layer0.rgb;

     // 金属度
    half metallic = _Metallic_0;

    // 属性图( G:AO B:光滑度 )
    float4 prop0 = 1;
    #if _USESMOOTHNESS_0_ON || _USEOCCLUSION_0_ON
        prop0 = SAMPLE_TEXTURE2D(_PropMap_0, sampler_PropMap_0, uv);
    #endif
 
    // 光滑度
    half smoothness = _Smoothness_0 * prop0.b;
       
    // AO
    half occlusion = 1;
    #if _USEOCCLUSION_0_ON
        occlusion = LerpWhiteTo (prop0.g, _OcclusionStrength_0);
    #endif
   
    float3 normalTangent = float3(0, 0, 1);
    // normal
    #ifdef _NORMALMAP
        normalTangent = UnpackNormalScale(SAMPLE_TEXTURE2D(_Normal_0, sampler_Normal_0, uv), _NormalScale_0);
    #endif

    outSurfaceData.alpha = half(1.0);
    outSurfaceData.albedo = albedo;
    outSurfaceData.metallic = metallic;
    outSurfaceData.specular = half3(0.0, 0.0, 0.0);
    outSurfaceData.smoothness = smoothness;
    outSurfaceData.normalTS = normalTangent;
    outSurfaceData.occlusion = occlusion;
    outSurfaceData.emission = half(0.0);
    outSurfaceData.clearCoatMask       = half(0.0);
    outSurfaceData.clearCoatSmoothness = half(0.0);
}


#endif // TERRAINWET_INPUT_INCLUDED
