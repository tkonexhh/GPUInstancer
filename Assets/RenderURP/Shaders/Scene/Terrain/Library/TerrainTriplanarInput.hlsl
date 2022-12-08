#ifndef TERRAINTRIPLANAR_INPUT_INCLUDED
#define TERRAINTRIPLANAR_INPUT_INCLUDED

#define _NORMALMAP 1
#define _TANGENT_TO_WORLD 1

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"
#include "TerrainCommon.hlsl"

CBUFFER_START(UnityPerMaterial)
    float4  _MainTex_ST;
    half4   _Color;
    half    _BumpScale;
    half    _Glossiness;
    half    _Metallic;
    half    _GlossMapScale;
    half    _OcclusionStrength;

    half4   _TriplanarColor;
    half    _TriplanarBumpScale;

    half    _TriplanarMetallic;
    float   _TriplanarGlossiness;
    float   _TriplanarGlossMapScale;

    half    _TriplanarOcclusionStrength;

    float   _TriplanarTiling;
    float   _BlendStrength;
    float   _BlendNormalInfluence;
    float   _BlendNormalStrength;
CBUFFER_END

// ---------------------------------------
TEXTURE2D(_MainTex);                     SAMPLER(sampler_MainTex);
TEXTURE2D(_BumpMap);                     SAMPLER(sampler_BumpMap);
TEXTURE2D(_MetallicGlossMap);            SAMPLER(sampler_MetallicGlossMap);
TEXTURE2D(_OcclusionMap);                SAMPLER(sampler_OcclusionMap);

TEXTURE2D(_TriplanarTex);                SAMPLER(sampler_TriplanarTex);
TEXTURE2D(_TriplanarBumpMap);            SAMPLER(sampler_TriplanarBumpMap);
TEXTURE2D(_TriplanarMetallicGlossMap);   SAMPLER(sampler_TriplanarMetallicGlossMap);
TEXTURE2D(_TriplanarOcclusionMap);       SAMPLER(sampler_TriplanarOcclusionMap);

// ---------------------------------------

half3 MetallicGlossOcclusion(float2 uv)
{
    half3 mgo;
    #ifdef _METALLICGLOSSUSE_TEXTURE
        mgo.rg = SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, uv).ra;
        mgo.g *= _GlossMapScale;
    #else
        mgo.r = _Metallic;
        mgo.g = _Glossiness;
    #endif

    half occ = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
    mgo.b = LerpWhiteTo(occ, _OcclusionStrength);

    return mgo;
}

half3 MetallicGlossOcclusionTriplanar(float2 uv)
{
    half3 mgo;
    #ifdef _TRIPLANARMETALLICGLOSSUSE_TEXTURE
        mgo.rg = SAMPLE_TEXTURE2D(_TriplanarMetallicGlossMap, sampler_TriplanarMetallicGlossMap, uv).ra;
        mgo.g *= _TriplanarGlossMapScale;
    #else
        mgo.r = _TriplanarMetallic;
        mgo.g = _TriplanarGlossiness;
    #endif
    
    half occ = SAMPLE_TEXTURE2D(_TriplanarOcclusionMap, sampler_TriplanarOcclusionMap, uv).g;
    mgo.b = LerpWhiteTo(occ, _TriplanarOcclusionStrength);

    return mgo;
}

half2 GetTriplanarWeights(half3 normalWS, half3 normalWSBasic) 
{
    half2 weight = 0;
    weight.x = lerp(normalWS.y, normalWSBasic.y, _BlendNormalInfluence);
    weight.x = saturate(weight.x * _BlendStrength);
    weight.y = saturate(weight.x - _BlendNormalStrength);
	weight.x = weight.x * weight.x * weight.x;

    return weight;
}

inline void InitializeTerrainSurfaceData(float3 positionWS, half3 normalWS, float4 tangentWS, float2 uv, out SurfaceData outSurfaceData)
{
    float3 bitangent = tangentWS.w * cross(normalWS.xyz, tangentWS.xyz);
    half3x3 TBN = half3x3(tangentWS.xyz, bitangent.xyz, normalWS.xyz);

  
    uv = TRANSFORM_TEX(uv, _MainTex);
    float2 uvTop = positionWS.xz * _TriplanarTiling;

    half3 albedoBasic          = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv).rgb * _Color.rgb;
	half3 metalGlossOccBasic   = MetallicGlossOcclusion(uv);
    half3 normalTSBasic        = UnpackNormalScale(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uv), _BumpScale);
    half3 normalWSBasic         = TransformTangentToWorld(normalTSBasic, TBN);
	
    half3 albedoTop        = albedoBasic;
    half3 metalGlossOccTop = metalGlossOccBasic;
    half3 normalWSTop      = normalWSBasic;

    #if _F_TRIPLANAR_ON
        albedoTop           = SAMPLE_TEXTURE2D(_TriplanarTex, sampler_TriplanarTex, uvTop).rgb * _TriplanarColor.rgb;
		metalGlossOccTop    = MetallicGlossOcclusionTriplanar(uvTop);
        half3 normalTSTop   = UnpackNormalScale(SAMPLE_TEXTURE2D(_TriplanarBumpMap, sampler_TriplanarBumpMap, uvTop), _TriplanarBumpScale);

        // https://medium.com/@bgolus/normal-mapping-for-a-triplanar-shader-10bf39dca05a
        half3 n1 = normalWS.xzy;
        half3 n2 = normalTSTop.xyz;
        n1.z += 1.0h;
        n2.xy *= -1.0h;
        normalTSTop = n1 * dot(n1, n2) / n1.z - n2;
        normalTSTop = normalTSTop.xzy;

        normalWSTop = normalTSTop;
	#endif

	half2 weight = GetTriplanarWeights(normalWS, normalWSBasic);

    half3 albedo            = lerp(albedoBasic, albedoTop, weight.x);
	half3 metalGlossOcc     = lerp(metalGlossOccBasic, metalGlossOccTop, weight.x);
    // 实际上已经是世界空间法线
	half3 normalTangent     = lerp(normalWSBasic, normalWSTop, weight.y);

	half metallic = metalGlossOcc.x;
	half smoothness = metalGlossOcc.y;
	half occlusion = metalGlossOcc.z;

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


#endif // TERRAINTRIPLANAR_INPUT_INCLUDED
