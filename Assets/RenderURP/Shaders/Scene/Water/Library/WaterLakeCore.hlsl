#ifndef WATERLAKE_CORE_INCLUDED
#define WATERLAKE_CORE_INCLUDED

#include "WaterPass.hlsl"
#include "WaterSSR.hlsl"

void GetFadeInfo(Varyings input, float2 screenUV, half3 viewDirWS,
				inout float sceneZ, inout float fade, inout float fadeShallow)
{
	// sceneZ
	float rawDepth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV);
    sceneZ = (unity_OrthoParams.w == 0) ? LinearEyeDepth(rawDepth, _ZBufferParams) : LinearDepthToEyeDepth(rawDepth);
    // fade
    float thisZ = input.positionNDC.w;// LinearEyeDepth(input.positionNDC.z / input.positionNDC.w, _ZBufferParams);
	fade = sceneZ - thisZ;
	// 浅水渐变
	float depthFix = saturate(0.3 + dot(viewDirWS, float3(0, 1, 0)));
	fadeShallow = saturate(1 - LinearToExp(fade * depthFix, _FadeShallow));
}

// 间接光镜面反射
half3 GetReflectColor(half3 viewDirWS, half3 normalWS, float3 positionWS, float4 positionCS, float2 screenUV)
{
	// TODO 法线贴图时反射方向计算SSR有问题
    half3 reflectVector = normalize(reflect(-viewDirWS, normalWS));

    // 自定义cubemap反射
	half3 reflectColor = GetReflectionCustom(reflectVector);

    // TODO 相机方案 SSPR方案
	#if _USESSR_ON
        float NdotV = saturate(dot(normalWS, viewDirWS));
		float3 uvz = GetSSRUVZ(NdotV, screenUV, positionCS, positionWS, reflectVector, _SSRStep, _SSRMaxCount);

        half3 grabColor = GetGrabColor(uvz.xy).rgb;

		half3 ssrColor = lerp(half3(0, 0, 0), grabColor, uvz.z > 0);
		half4 ssrFinal = half4(ssrColor, uvz.z);

		reflectColor = lerp(lerp(reflectColor, ssrFinal.rgb, ssrFinal.a), ssrFinal, ssrFinal.a > 0.99);
	#endif

	reflectColor *= _ReflectionStrength;

    return reflectColor;
}

half3 GetSpecularColor(Varyings input, half3 viewDirWS, half3 normalWS, float2 screenUV,
                    half3x3 tangentToWorld, Light mainLight, half3 grabColor, float fadeShallow)
{
    // 间接光镜面反射
    half3 inDirectSpecularColor = GetReflectColor(viewDirWS, normalWS, input.positionWS, input.positionCS, screenUV);

    // 高光法线缩放独立
    half3 normalTS_Spec, normalWS_Spec;
	GetNormal(input.uv, tangentToWorld, _NormalTiling, _SpecularNormalScale, normalTS_Spec, normalWS_Spec);

    // 直接光镜面反射
    half3 directSpecularColor = GetWaterSpecular(normalWS_Spec, viewDirWS, mainLight.direction, mainLight.color,
                         _SpecularRoughness, _SpecularColor.rgb, _SpecularIntensity);

    // indirect + direct
    half3 specularColor = inDirectSpecularColor + directSpecularColor * mainLight.shadowAttenuation;

	// 反射浅水如果不需要渐变 则不需要lerp
	specularColor = lerp(grabColor, specularColor, fadeShallow);

    return specularColor;
}

half3 GetDiffuseColor(half3 viewDirWS, half3 normalWS, Light mainLight, half3 grabColor, float fadeShallow, float fade)
{
    // diffuse
	half3 diffuseColor = SampleSH(normalWS) + 
                        saturate(dot(normalWS, mainLight.direction)) * 
                        lerp(0, mainLight.color, _DiffuseLightIntensity) * 
                        lerp(1 - _ShadowIntensity, 1, mainLight.shadowAttenuation);

	diffuseColor *= lerp(_WaterColorGrazing.rgb, _WaterColor.rgb, abs(viewDirWS.y));
	// 基础的浅水渐变
	diffuseColor = lerp(grabColor, diffuseColor, fadeShallow);

    return diffuseColor;
}


// -----------------------------------------------------------
// Fragment
half4 WaterLakeFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);

    // V
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);

    // light
    Light mainLight = GetLight(input);

    // 法线
    half3x3 tangentToWorld = GetTangentToWorld(input);
    half3 normalTS, normalWS;
    GetNormal(input.uv, tangentToWorld, _NormalTiling, _NormalScale, normalTS, normalWS);

    // screen uv
    float2 screenUV = GetScreenUV(input.positionNDC);

	float sceneZ, fade, fadeShallow;
	GetFadeInfo(input, screenUV, viewDirWS, sceneZ, fade, fadeShallow);

	// -----------------------------------------------------------------------------------------

    // grabcolor 用来计算反射 同时 作为下层颜色混合
    half3 grabColor = GetGrabColor(input.positionNDC, normalTS).rgb;

    // specular
    half3 specularColor = GetSpecularColor(input, viewDirWS, normalWS, screenUV, tangentToWorld, mainLight, grabColor, fadeShallow);

    // diffuse
    half3 diffuseColor = GetDiffuseColor(viewDirWS, normalWS, mainLight, grabColor, fadeShallow, fade);

	// fresnel 过度
    half fresnelTerm = GetWaterFresnelTerm(normalWS, viewDirWS, WaterSurfaceF0);
	half3 finalColor = lerp(diffuseColor, specularColor, fresnelTerm);

    return half4(finalColor, 1.0);
}

#endif
