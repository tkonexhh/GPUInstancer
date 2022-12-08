#ifndef TERRAINBLENDWET_INPUT_INCLUDED
#define TERRAINBLENDWET_INPUT_INCLUDED

#if _USENORMALMAP_ON || _F_PUDDLE_ON
    #define _NORMALMAP 1
#endif
#if _USEPARALLAX_0_ON || _USEPARALLAX_1_ON || _USEPARALLAX_2_ON || _USEPARALLAX_3_ON
    #define _PARALLAXMAP 1
#endif

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ParallaxMapping.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"
#include "TerrainCommon.hlsl"

CBUFFER_START(UnityPerMaterial)
    float   _BlendWeight;
    float4  _Control_0_ST;

    float4  _Splat_0_ST;
    half4   _SplatColor_0;
    float4  _Normal_0_ST;
    half    _NormalScale_0;
    half    _Metallic_0;
    half    _Smoothness_0;
    float4  _PropMap_0_ST;
    half    _OcclusionStrength_0;
    half    _Parallax_0;

    float4  _Splat_1_ST;
    half4   _SplatColor_1;
    float4  _Normal_1_ST;
    half    _NormalScale_1;
    half    _Metallic_1;
    half    _Smoothness_1;
    float4  _PropMap_1_ST;
    half    _OcclusionStrength_1;
    half    _Parallax_1;

    float4  _Splat_2_ST;
    half4   _SplatColor_2;
    float4  _Normal_2_ST;
    half    _NormalScale_2;
    half    _Metallic_2;
    half    _Smoothness_2;
    float4  _PropMap_2_ST;
    half    _OcclusionStrength_2;
    half    _Parallax_2;

    float4  _Splat_3_ST;
    half4   _SplatColor_3;
    float4  _Normal_3_ST;
    half    _NormalScale_3;
    half    _Metallic_3;
    half    _Smoothness_3;
    float4  _PropMap_3_ST;
    half    _OcclusionStrength_3;
    half    _Parallax_3;
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
TEXTURE2D(_Control_0);              SAMPLER(sampler_Control_0);

TEXTURE2D(_Splat_0);                SAMPLER(sampler_Splat_0);
TEXTURE2D(_Normal_0);               SAMPLER(sampler_Normal_0);
TEXTURE2D(_PropMap_0);              SAMPLER(sampler_PropMap_0);

TEXTURE2D(_Splat_1);
TEXTURE2D(_Normal_1);
TEXTURE2D(_PropMap_1);              SAMPLER(sampler_PropMap_1);

TEXTURE2D(_Splat_2);
TEXTURE2D(_Normal_2);
TEXTURE2D(_PropMap_2);              SAMPLER(sampler_PropMap_2);

TEXTURE2D(_Splat_3);
TEXTURE2D(_Normal_3);
TEXTURE2D(_PropMap_3);              SAMPLER(sampler_PropMap_3);
// ---------------------------------------
TEXTURE2D(_PuddleTex);              SAMPLER(sampler_PuddleTex);
TEXTURE2D(_PuddleMask);             SAMPLER(sampler_PuddleMask);

TEXTURE2D(_PuddleNormalMap);        SAMPLER(sampler_PuddleNormalMap);

TEXTURE2D(_RippleNormalMap);        SAMPLER(sampler_RippleNormalMap);
TEXTURECUBE(_PuddleReflectCubemap); SAMPLER(sampler_PuddleReflectCubemap);
TEXTURE2D(_RainDotGradientTex);     SAMPLER(sampler_RainDotGradientTex);

// ---------------------------------------

struct splat_uv
{
    float4 uv01;
    float4 uv23;
};

splat_uv GetSplatUV(float2 i_tex)
{
    splat_uv uvs;
    uvs.uv01.xy = TRANSFORM_TEX(i_tex, _Splat_0);
    uvs.uv01.zw = TRANSFORM_TEX(i_tex, _Splat_1);
    uvs.uv23.xy = TRANSFORM_TEX(i_tex, _Splat_2);
    uvs.uv23.zw = TRANSFORM_TEX(i_tex, _Splat_3);

    return uvs;
}

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

inline void InitializeTerrainBlendSurfaceData(float3 viewDirTS, float2 uv, out SurfaceData outSurfaceData)
{
    // 控制通道图
    float4 splat_control = SAMPLE_TEXTURE2D(_Control_0, sampler_Control_0, uv);
    // tilling后uv
    splat_uv uvs = GetSplatUV(uv);
     // 视差偏移后uv
    #if _USEPARALLAX_0_ON
        uvs.uv01.xy = ParallaxMapping_Terrain(uvs.uv01.xy, viewDirTS, TEXTURE2D_ARGS(_Splat_0, sampler_Splat_0), _Parallax_0);
    #endif
    #if _USEPARALLAX_1_ON
        uvs.uv01.zw = ParallaxMapping_Terrain(uvs.uv01.zw, viewDirTS, TEXTURE2D_ARGS(_Splat_1, sampler_Splat_0), _Parallax_1);
    #endif
    #if _USEPARALLAX_2_ON
        uvs.uv23.xy = ParallaxMapping_Terrain(uvs.uv23.xy, viewDirTS, TEXTURE2D_ARGS(_Splat_2, sampler_Splat_0), _Parallax_2);
    #endif
    #if _USEPARALLAX_3_ON
        uvs.uv23.zw = ParallaxMapping_Terrain(uvs.uv23.zw, viewDirTS, TEXTURE2D_ARGS(_Splat_3, sampler_Splat_0), _Parallax_3);
    #endif
    // 基础贴图
    float4 layer0 = SAMPLE_TEXTURE2D(_Splat_0, sampler_Splat_0, uvs.uv01.xy);
    float4 layer1 = SAMPLE_TEXTURE2D(_Splat_1, sampler_Splat_0, uvs.uv01.zw);
    float4 layer2 = SAMPLE_TEXTURE2D(_Splat_2, sampler_Splat_0, uvs.uv23.xy);
    float4 layer3 = SAMPLE_TEXTURE2D(_Splat_3, sampler_Splat_0, uvs.uv23.zw);

    // A通道高度混合, 对通道图进行计算
    half4 blend;
    blend.r = layer0.a * splat_control.r;
    blend.g = layer1.a * splat_control.g;
    blend.b = layer2.a * splat_control.b;
    blend.a = layer3.a * splat_control.a;
        
    half ma = max(blend.r, max(blend.g, max(blend.b, blend.a)));
    blend = max(blend - ma + _BlendWeight , 0) * splat_control;
    blend /= blend.r + blend.g + blend.b + blend.a + 1e-7f;

    // 通道图对基础图进行混合
    half3   albedo  = blend.r * _SplatColor_0 * layer0.rgb;
            albedo += blend.g * _SplatColor_1 * layer1.rgb;
            albedo += blend.b * _SplatColor_2 * layer2.rgb;
            albedo += blend.a * _SplatColor_3 * layer3.rgb;

     // 金属度
    half metallic = dot(blend, float4(_Metallic_0, _Metallic_1, _Metallic_2, _Metallic_3));

    // 属性图( G:AO B:光滑度 )
    float4 prop0 = 1, prop1 = 1, prop2 = 1, prop3 = 1;

    #if _USESMOOTHNESS_0_ON || _USEOCCLUSION_0_ON
        prop0 = SAMPLE_TEXTURE2D(_PropMap_0, sampler_PropMap_0, uvs.uv01.xy);
    #endif
    #if _USESMOOTHNESS_1_ON || _USEOCCLUSION_1_ON
        prop1 = SAMPLE_TEXTURE2D(_PropMap_1, sampler_PropMap_1, uvs.uv01.zw);
    #endif
    #if _USESMOOTHNESS_2_ON || _USEOCCLUSION_2_ON
        prop2 = SAMPLE_TEXTURE2D(_PropMap_2, sampler_PropMap_2, uvs.uv23.xy);
    #endif
    #if _USESMOOTHNESS_3_ON || _USEOCCLUSION_3_ON
        prop3 = SAMPLE_TEXTURE2D(_PropMap_3, sampler_PropMap_3, uvs.uv23.zw);
    #endif
    // 光滑度
    half smoothness  = blend.r * _Smoothness_0 * prop0.b;
         smoothness += blend.g * _Smoothness_1 * prop1.b;
         smoothness += blend.b * _Smoothness_2 * prop2.b;
         smoothness += blend.a * _Smoothness_3 * prop3.b;

    // AO
    half occ0 = 1, occ1 = 1, occ2 = 1, occ3 = 1;
    #if _USEOCCLUSION_0_ON
        occ0 = LerpWhiteTo (prop0.g, _OcclusionStrength_0);
    #endif
    #if _USEOCCLUSION_1_ON
        occ1 = LerpWhiteTo (prop1.g, _OcclusionStrength_1);
    #endif
    #if _USEOCCLUSION_2_ON
        occ2 = LerpWhiteTo (prop2.g, _OcclusionStrength_2);
    #endif
    #if _USEOCCLUSION_3_ON
        occ3 = LerpWhiteTo (prop3.g, _OcclusionStrength_3);
    #endif

    half occlusion  = blend.r * occ0;
         occlusion += blend.g * occ1;
         occlusion += blend.b * occ2;
         occlusion += blend.a * occ3;

    // normal
    #ifdef _NORMALMAP
        float3  normalTangent  = blend.r * UnpackNormalScale(SAMPLE_TEXTURE2D(_Normal_0, sampler_Normal_0, uvs.uv01.xy), _NormalScale_0);
                normalTangent += blend.g * UnpackNormalScale(SAMPLE_TEXTURE2D(_Normal_1, sampler_Normal_0, uvs.uv01.zw), _NormalScale_1);
                normalTangent += blend.b * UnpackNormalScale(SAMPLE_TEXTURE2D(_Normal_2, sampler_Normal_0, uvs.uv23.xy), _NormalScale_2);
                normalTangent += blend.a * UnpackNormalScale(SAMPLE_TEXTURE2D(_Normal_3, sampler_Normal_0, uvs.uv23.zw), _NormalScale_3);
    #else 
        float3  normalTangent = float3(0, 0, 1);
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


#endif // TERRAINBLENDWET_INPUT_INCLUDED
