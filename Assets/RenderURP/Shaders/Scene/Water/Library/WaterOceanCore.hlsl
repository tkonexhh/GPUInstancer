#ifndef WATEROCEAN_CORE_INCLUDED
#define WATEROCEAN_CORE_INCLUDED

#include "WaterPass.hlsl"
#include "WaterSSR.hlsl"


void GetFadeInfo(Varyings input, float2 screenUV, half3 viewDirWS,
				inout float sceneZ, inout float fade, inout float fadeShallow)
{
	// sceneZ
	float rawDepth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV);
    sceneZ = (unity_OrthoParams.w == 0) ? LinearEyeDepth(rawDepth, _ZBufferParams) : LinearDepthToEyeDepth(rawDepth);
    // fade
    float thisZ = input.positionNDC.w; // LinearEyeDepth(input.positionNDC.z / input.positionNDC.w, _ZBufferParams);
	fade = sceneZ - thisZ;
	// 浅水渐变
	float depthFix = saturate(0.3 + dot(viewDirWS, float3(0, 1, 0)));
	fadeShallow = saturate(1 - LinearToExp(fade * depthFix, _FadeShallow));
}

// 间接光镜面反射
half3 GetReflectColor(half3 viewDirWS, half3 normalWS, float3 positionWS, float4 positionCS, float2 screenUV)
{
    // 默认颜色
	half3 reflectColor = _ReflectionFixColor.rgb;

    half3 reflectVector = normalize(reflect(-viewDirWS, normalWS));

    // 反射探针部分
	#if _USEREFLECTIONPROBE_ON
    	reflectColor = GetReflectionUnity(reflectVector, positionWS);
		reflectColor *= _ReflectionStrength;
	#endif

    // TODO 相机方案 SSPR方案
	#if _USESSR_ON
        float NdotV = saturate(dot(normalWS, viewDirWS));
		float3 uvz = GetSSRUVZ(NdotV, screenUV, positionCS, positionWS, reflectVector, _SSRStep, _SSRMaxCount);

        half3 grabColor = GetGrabColor(uvz.xy).rgb;

		half3 ssrColor = lerp(half3(0, 0, 0), grabColor, uvz.z > 0);
		half4 ssrFinal = half4(ssrColor, uvz.z);

		reflectColor = lerp(lerp(reflectColor, ssrFinal.rgb, ssrFinal.a), ssrFinal, ssrFinal.a > 0.99);
	#endif

    return reflectColor;
}

half3 GetSpecularColor(Varyings input, half3 viewDirWS, half3 normalWS, float2 screenUV,
                    half3x3 tangentToWorld, Light mainLight, half3 grabColor, float fadeShallow,
					float viewDist, float mip)
{
    // 间接光镜面反射
    half3 inDirectSpecularColor = GetReflectColor(viewDirWS, normalWS, input.positionWS, input.positionCS, screenUV);

    // 高光法线缩放独立
    half3 normalTS_Spec, normalWS_Spec;
	GetNormal(input.uv, tangentToWorld, _NormalTiling, _SpecularNormalScale, mip, normalTS_Spec, normalWS_Spec);

    // 直接光镜面反射
	half specularRoughness = lerp(_SpecularRoughness, _SpecularDist, viewDist);
    half3 directSpecularColor = GetWaterSpecularOcean(normalWS_Spec, viewDirWS, mainLight.direction, mainLight.color,
                         specularRoughness, _SpecularColor.rgb, _SpecularIntensity, _SpecularPower);

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

	// 浅水特殊的渐变
	half3 absorbedColor = pow(clamp(_WaterColorShallow.rgb, 0.1, 0.95), 5 * fade / _FadeShallow);
	absorbedColor = lerp(pow(_WaterColorShallow.rgb, 15.0) * 0.05, grabColor, absorbedColor);
	// 两者过度
	diffuseColor = lerp(absorbedColor, diffuseColor, _FadeShallowSp * 0.9 + 0.1);

    return diffuseColor;
}

void CalculateCausticsAndFoam(Varyings input, half3 normalWS, float sceneZ, float fade, Light mainLight, 
                            inout float3 finalColor)
{
    #if _F_CAUSTICS_ON || _F_FOAM_ON
		float3 surfacePositionVS = input.rayVS * sceneZ / input.rayVS.z;
		float4 surfacePositionWS = mul(unity_CameraToWorld, float4(surfacePositionVS, 1));

		// 表面深度差
		float depthDiff = input.positionWS.y - surfacePositionWS.y;
	#endif

	// 焦散 改用图片版本
	// https://80.lv/articles/caustic-surface-production-guide/
	#if _F_CAUSTICS_ON
		float2 lightProjection = mainLight.direction.xz * depthDiff / (4.0 * mainLight.direction.y);

		float2 causticsUV = surfacePositionWS.xz + lightProjection;

		half3 causticsColor = GetCausticsColor(causticsUV, normalWS);

		causticsColor = lerp(causticsColor, 0, saturate(1 - LinearToExp(fade, _CausticsRange.x)));
		causticsColor = lerp(0, causticsColor, saturate(1 - LinearToExp(fade, _CausticsRange.y)));

		finalColor *= 1 + causticsColor * exp2(_CausticsIntensity) * _CausticsColor;
	#endif

    // 泡沫
	#if _F_FOAM_ON
		_FoamThreshold *= (1 - depthDiff);
		float2 fuv = input.positionWS.xz;

		half foam = GetFoam(fuv, 0, _FoamTiling, _FoamFeather, _FoamThreshold);

		float2 dd = float2(0.25 * _FoamNormalOffset, 0.0);
		half foam_x = GetFoam(fuv, dd.xy, _FoamTiling, _FoamFeather, _FoamThreshold);
		half foam_z = GetFoam(fuv, dd.yx, _FoamTiling, _FoamFeather, _FoamThreshold);

		float3 N_foam = input.normalWS;
		N_foam.xy -= _FoamNormalIntensity * 10 * half2(foam_x - foam, foam_z - foam);
		N_foam = normalize(N_foam);
		foam *= (dot(N_foam, mainLight.direction) + _FoamNormalWrap)/ (1 + _FoamNormalWrap);

		finalColor += foam * depthDiff * _FoamIntensity;
	#endif
}

// -----------------------------------------------------------
// Fragment
half4 WaterOceanFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);

    // V
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);

    // light / shadow没有使用
    Light mainLight = GetLight(input);

	float viewDist = saturate(length(input.positionWS.xyz - GetCameraPositionWS()) / 300);
	float mip = lerp(0, _SpecularMipmap, viewDist);

    // 法线
    half3x3 tangentToWorld = GetTangentToWorld(input);
    half3 normalTS, normalWS;
    GetNormal(input.uv, tangentToWorld, _NormalTiling, _NormalScale, mip, normalTS, normalWS);

    // screen uv
    float2 screenUV = GetScreenUV(input.positionNDC);

	float sceneZ, fade, fadeShallow;
	GetFadeInfo(input, screenUV, viewDirWS, sceneZ, fade, fadeShallow);
	
	// -----------------------------------------------------------------------------------------

    // grabcolor 用来计算反射 同时 作为下层颜色混合
    half3 grabColor = GetGrabColor(screenUV).rgb;

    // specular
    half3 specularColor = GetSpecularColor(input, viewDirWS, normalWS, screenUV, tangentToWorld, mainLight, grabColor, fadeShallow, viewDist, mip);

    // diffuse
    half3 diffuseColor = GetDiffuseColor(viewDirWS, normalWS, mainLight, grabColor, fadeShallow, fade);

	// fresnel 过度
    half fresnelTerm = GetWaterFresnelTerm(normalWS, viewDirWS, WaterSurfaceF0);
	half3 finalColor = lerp(diffuseColor, specularColor, fresnelTerm);

    // 焦散 和 泡沫
    CalculateCausticsAndFoam(input, normalWS, sceneZ, fade, mainLight, finalColor);

    return half4(finalColor, 1.0);
}

#endif
