
#ifndef WATER_COMMON_INCLUDED
#define WATER_COMMON_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/BRDF.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"

// ----------------------------------------------------------
#define WaterSurfaceF0 0.03

// 高光 BRDF 大体上使用HDRP版本
float DirectBRDFSpecular_HDRP(float NdotH, float NdotL, float NdotV, half perceptualRoughness)
{
    half roughness = max(perceptualRoughness * perceptualRoughness, 0.002);

    float DV = DV_SmithJointGGX(NdotH, abs(NdotL), NdotV, roughness);

    float specularTerm = max(0, DV * PI * NdotL);

    return specularTerm;
}

// UNITY的反射探针
half3 GetReflectionUnity(float3 reflectVector, float3 positionWS)
{
	// 如果有反射探针，可以先依赖下它的box projection
	#ifdef _REFLECTION_PROBE_BOX_PROJECTION
	    reflectVector = BoxProjectedCubemapDirection(reflectVector, positionWS, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
	#endif

    half4 reflection = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectVector, 0);
	
	#if !defined(UNITY_USE_NATIVE_HDR)
		reflection.rgb = DecodeHDREnvironment(reflection, unity_SpecCube0_HDR);
	#endif // UNITY_USE_NATIVE_HDR

	return reflection.rgb;
}

// ---------------------------------------------------------------------------------------
half3 GetWaterSpecular(float3 N, float3 V, float3 L, half3 lightColor,
					float perceptualRoughness, half3 specularColor, float intensity)
{
	float3 H = normalize(L + V);
	float NdotH = saturate(dot(N, H));
	float NdotL = saturate(dot(N, L));
	float NdotV = saturate(dot(N, V));
	
	float specularTerm = DirectBRDFSpecular_HDRP(NdotH, NdotL, NdotV, perceptualRoughness);

	specularTerm = saturate(specularTerm - 1);
	specularTerm *= specularTerm;
	
	half3 specular = saturate(dot(L, half3(0, 1, 0))) * specularColor * (exp(intensity) - 1);
	specular *= specularTerm * lightColor;
	
	return specular;
}


half3 GetWaterSpecularOcean(float3 N, float3 V, float3 L, half3 lightColor, 
					float perceptualRoughness, half3 specularColor, float intensity, float power)
{

	float3 H = SafeNormalize(L + V);
	float NdotH = saturate(dot(N, H));
	float NdotL = saturate(dot(N, L));
	float NdotV = abs(dot(N, V));
	
	float specularTerm = saturate(DirectBRDFSpecular_HDRP(NdotH, NdotL, NdotV, perceptualRoughness));
	specularTerm = pow(specularTerm, power);

	half3 specular = saturate(dot(L, half3(0, 1, 0))) * specularColor * (exp(intensity) - 1);
	specular *= specularTerm * lightColor;

	return specular;
}

// abs处理双面问题
// 使用法线贴图计算效果不好时 可以考虑使用屏幕法线
half GetWaterFresnelTerm(half3 normalWS, half3 viewDirWS, half F0, half power = half(7.0))
{
	return F0 + (1 - F0) * pow(1 - saturate(dot(normalWS, viewDirWS)), power);
}

float LinearToExp(float a, float b)
{
	return exp(- a / max(b, 1e-7f));
}

// https://iquilezles.org/articles/boxfunctions/
float2 boxIntersection(float3 ro, float3 rd, float3 size) 
{
    float3 m = 1.0 / rd;
    float3 n = m * ro;
    float3 k = abs(m) * size;
    float3 t1 = -n - k;
    float3 t2 = -n + k;

    float tN = max( max( t1.x, t1.y ), t1.z );
    float tF = min( min( t2.x, t2.y ), t2.z );
	
    if( tN > tF || tF < 0.0) return -1.0; // no intersection

    return float2(tN, tF);
}

// 解析解点光源体积光
// https://www.iquilezles.org/www/index.htm
float SimplePointVolumeLight(float3 ro, float3 rd, float3 pos, float3 d)
{
	float3 q = ro - pos;
    float b = dot(rd, q);
    float c = dot(q, q);
    float iv = 1.0f / sqrt(c - b * b);
    float l = iv * (atan((d + b) * iv) - atan(b*iv));

	return l;
}

// https://www.shadertoy.com/view/XtKfRG
float CalculateCaustics(float2 uv, float tiling, float speed, float power)
{
	float3x3 m = float3x3(-2,-1,2, 3,-2,1, 1,2,2);
	float3 a = mul(float3(uv * tiling, frac(_Time.y * speed)), m);
	float3 b = mul(a, m) * 0.4;
	float3 c = mul(b, m) * 0.3;

	float ret = min(min(length(0.5 - frac(a)), length(0.5 - frac(b))), length(0.5 - frac(c)));
	ret = pow(ret, power) * 25;

	return ret;
}



#endif