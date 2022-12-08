#ifndef WATERAQUARIUM_CORE_INCLUDED
#define WATERAQUARIUM_CORE_INCLUDED

#include "WaterPass.hlsl"

void GetFadeInfo(Varyings input, float2 screenUV, half3 viewDirWS,
				inout float sceneZ, inout float fade, inout float thickness,
				inout float3 ro, inout float3 rd)
{
	// sceneZ 为了避免深度拷贝的切换过程 不包含水缸内部的深度
    // MARK 异形水缸和水面mesh波动部分无法处理
	float rawDepth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV);
    sceneZ = (unity_OrthoParams.w == 0) ? LinearEyeDepth(rawDepth, _ZBufferParams) : LinearDepthToEyeDepth(rawDepth);

    // fade
    float thisZ = input.positionNDC.w; // LinearEyeDepth(input.positionNDC.z / input.positionNDC.w, _ZBufferParams);
    
	// 射线起点 模型空间摄像机位置 TransformWorldToObject(_WorldSpaceCameraPos.xyz)
	// 这里只需要水缸表面之内的部分
	ro = TransformWorldToObject(input.positionWS.xyz);
	
	// 射线方向 模型空间视角方向
	rd = -TransformWorldToObjectDir(viewDirWS);
	// 模型空间 交点
	float2 tNF = boxIntersection(ro, rd, _WaterSize.xyz * 0.5);
	// 视角方向 厚度
	thickness = tNF.y - tNF.x;

	// 模型空间 水缸内部面坐标
	float3 farPositionOS = ro + rd * tNF.y;
	// 转到 View空间获取Z 和深度统一
	float farZ = -TransformWorldToView(TransformObjectToWorld(farPositionOS)).z;

	// 	
	sceneZ = min(sceneZ, farZ);
	// thisZ 表面点深度 也可以用tNF.x计算获得，但是就无法包含mesh波动部分
	fade = sceneZ - thisZ; 
}


half GetSideUpMask(Varyings input)
{
	half sideUpMask = step(0.5, dot(input.normalWS, input.upWS));
	return sideUpMask;
}

void ConfigOuterInfo(Varyings input, 
			inout half3 viewDirWS, inout Light mainLight, inout half3 normalWS, inout half sideUpMask,
			inout float2 screenUV, inout float sceneZ, inout float fade, inout float thickness,
			inout float3 ro, inout float3 rd)
{
	// V
    viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);

    // light
    mainLight = GetLight(input);
	
    // 法线
    half3x3 tangentToWorld = GetTangentToWorld(input);
    half3 normalTS;
    GetNormal(input.uv, tangentToWorld, _NormalTiling, _NormalScale, normalTS, normalWS);

	// 高光
	sideUpMask = GetSideUpMask(input);
	normalWS = lerp(input.normalWS, normalWS, sideUpMask);

    // screen uv
    screenUV = GetScreenUV(input.positionNDC);
	
	GetFadeInfo(input, screenUV, viewDirWS, sceneZ, fade, thickness, ro, rd);
}

// 间接光镜面反射
half3 GetReflectColor(half3 viewDirWS, half3 normalWS, float3 positionWS)
{
    half3 reflectVector = normalize(reflect(-viewDirWS, normalWS));

    // 反射探针部分
	half3 reflectColor = GetReflectionUnity(reflectVector, positionWS);
	// reflectColor *= _ReflectionStrength;

    return reflectColor;
}

half3 GetSpecularColor(Varyings input, half3 viewDirWS, half3 normalWS, 
                    Light mainLight, float sideUpMask)
{
	// 间接光镜面反射
	half3 inDirectSpecularColor = GetReflectColor(viewDirWS, normalWS, input.positionWS);

	// 侧面不显示
	inDirectSpecularColor = lerp(0, inDirectSpecularColor, sideUpMask);

	// 高光
	half3 directSpecularColor = GetWaterSpecular(normalWS, viewDirWS, mainLight.direction, mainLight.color, 
					_SpecularRoughness, _SpecularColor, _SpecularIntensity);

    // indirect + direct
    half3 specularColor = inDirectSpecularColor + directSpecularColor * mainLight.shadowAttenuation;

    return specularColor;
}

half3 GetDiffuseColor(half3 grabColor, half3 normalWS, Light mainLight, float fade, half isMulti, 
			inout float turbidityMask, inout float transparentMask)
{
	// 和grabColor相关的 乘法和加法部分分离（grabColor只是占位便于理解用）
	half isAdd = 1 - isMulti;

	turbidityMask = LinearToExp(fade, rcp(_Turbidity));
	transparentMask = LinearToExp(fade, rcp(_Transparent));

	// 环境漫反射和阴影
	half3 baseColor = SampleSH(normalWS) + 
					saturate(dot(normalWS, mainLight.direction)) * 
					lerp(0, mainLight.color, _DiffuseLightIntensity) * 
					lerp(1 - _ShadowIntensity, 1, mainLight.shadowAttenuation);

	// diffuse
	half3 diffuseColor = lerp((baseColor * _TurbidityColor.rgb) * isAdd, grabColor * isMulti, turbidityMask);
	diffuseColor *= _WaterColor.rgb * transparentMask;

    return diffuseColor;
}


#if _F_CAUSTICS_ON
	half3 GetCaustics(Varyings input, float2 screenUV, float sceneZ, Light mainLight,
				inout half3 causticsMask, inout half3 causticsFinal)
	{
		// rayVS 是当前表面在View空间的坐标
		// 按照这个比例可以根据对应位置深度 还原视角空间坐标 rayVS.xyz / rayVS.z = scenePosVS / sceneZ
		float3 surfacePositionVS = input.rayVS * sceneZ / input.rayVS.z;
		float4 surfacePositionWS = mul(unity_CameraToWorld, float4(surfacePositionVS, 1));
		float3 surfacePositionOS = TransformWorldToObject(surfacePositionWS);
		// ----------------------------------------------------------------------------------------


		// 为了统一性 这里sceneZ已经包含了水缸内壁 需要约束掉
		float3 range = smoothstep(0, max(_CausticsRangeGradient, 0.01), _WaterSize * 0.5 - abs(surfacePositionOS));
		causticsMask = range.x * range.y * range.z;

		#if _CAUSTICSVERTICALMASK_ON
			half3 cameraNormals = SAMPLE_TEXTURE2D_X(_CameraNormalsTexture, sampler_CameraNormalsTexture, screenUV).xyz;
			// 注意 这是Gbuffer中的解析方式 输入是half3
			half3 surfaceNormalWS = normalize(UnpackNormal(cameraNormals));

			causticsMask *= saturate(dot(input.upWS, surfaceNormalWS) + _CausticsVerticalThreshold);
		#endif

		float2 causticsUV = surfacePositionOS.xz;

		#if _CAUSTICSUSEFUNC_ON
			// 函数计算版本
			half3 causticsColor = CalculateCaustics(causticsUV, rcp(_CausticsTiling), _CausticsSpeed, 7);
		#else
			// 贴图版本
			half3 causticsColor = GetCausticsColor(causticsUV);
		#endif

		causticsFinal = causticsColor * causticsMask * exp2(_CausticsIntensity) * _CausticsColor;

		return 1 + causticsFinal;
	}
#endif

half3 GetTransmission(float thickness, float3 lightDir, half3 normalWS, half3 viewDirWS)
{
	// 透射
	half3 halfDir = (lightDir + normalWS);
	float VdotH = pow(saturate(dot(viewDirWS, -halfDir)), _TransmissionPower);
	float transmission = VdotH * LinearToExp(thickness, rcp(1 - _TransmissionScale));

	return transmission * _TransmissionColor.rgb;
}

half3 GetPointVolume(float3 ro, float3 rd)
{
	float pointVolume = SimplePointVolumeLight(ro, rd, _PointVolumePos, _PointVolumeRadius);

	return 1 + pointVolume * _PointVolumeColor * _PointVolumeIntensity;
}

half GetFresnelTerm(half3 normalWS, half3 viewDirWS, half sideUpMask)
{
	half fresnelTerm = GetWaterFresnelTerm(normalWS, viewDirWS, WaterSurfaceF0);
	// 侧面没有环境反射 也不考虑高光 所以fresnel项设为0 否则掠射角会看上去太暗
	fresnelTerm = lerp(0, fresnelTerm, sideUpMask);

	return fresnelTerm;
}

void CalculateShallowFade(half3 grabColor, float fade, half isMulti, inout half3 finalColor)
{
	// 物体交界处过度
	finalColor = lerp(grabColor * isMulti, finalColor, saturate(fade * 8));
}

void CalculatePointVolumeAndCaustics(Varyings input, half3 normalWS, float2 screenUV, Light mainLight,
						float sceneZ, float fade, float3 ro, float3 rd, 
						inout half3 finalColor, inout half3 causticsMask, inout half3 causticsFinal)
{
	// 虚拟点光源体积光
	#if _F_POINTVOLUME_ON
		half3 pointVolumeColor = GetPointVolume(ro, rd);
		finalColor *= pointVolumeColor;
	#endif

	// 焦散
	causticsMask = 0; causticsFinal = 0;
	#if _F_CAUSTICS_ON
		half3 causticsColor = GetCaustics(input, screenUV, sceneZ, mainLight, causticsMask, causticsFinal);
		finalColor *= causticsColor;
	#endif
}

// -----------------------------------------------------------
// Fragment Inner
half4 WaterAquariumInnerFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
 	// V
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);

	input.normalWS *= -1;
	input.tangentWS *= -1;
	input.upWS *= -1;

 	// 法线
    half3x3 tangentToWorld = GetTangentToWorld(input);
    half3 normalTS, normalWS;
    GetNormal(input.uv, tangentToWorld, _NormalTiling, _NormalScale, normalTS, normalWS);

	// 水面蒙板
	half sideUpMask = GetSideUpMask(input);
	normalWS = lerp(input.normalWS, normalWS, sideUpMask);

	// 反射
	half3 reflectColor = GetReflectColor(viewDirWS, normalWS, input.positionWS);

	// fresnel
	half fresnelTerm = GetWaterFresnelTerm(normalWS, viewDirWS, lerp(0, WaterSurfaceF0, sideUpMask));

	// 只有顶部水面有反射
	half4 upReflectColor = half4(reflectColor, fresnelTerm);

	// 侧面颜色
	half4 sideReflectColor = 0.0;
	#if _USEINNERCOLOR_ON
		sideReflectColor = half4(_InnerColor.rgb, _InnerLerp * fresnelTerm);
	#endif

	half4 finalReflectColor = lerp(sideReflectColor, upReflectColor, sideUpMask);

	// SrcAlpha OneMinusSrcAlpha = lerp(grab, reflect, fresnel)
	return finalReflectColor;
}


// -----------------------------------------------------------
// Fragment Outer Multi
half4 WaterAquariumOuterMultiFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);

	half3 viewDirWS, normalWS;
	Light mainLight;
	half sideUpMask;
	float2 screenUV;
	float sceneZ, fade, thickness;
	float3 ro, rd;

	ConfigOuterInfo(input,
			viewDirWS, mainLight, normalWS, sideUpMask, screenUV, sceneZ, fade, thickness, ro, rd);

	// -----------------------------------------------------------------------------------------
	half3 grabColor = 1;
	float turbidityMask, transparentMask;
	// diffuse
	half3 diffuseColor = GetDiffuseColor(grabColor, normalWS, mainLight, fade, 1, turbidityMask, transparentMask);
	// specular
	half3 specularColor = 0;

	// fresnel 使用法线贴图计算效果不好
	half fresnelTerm = GetFresnelTerm(input.normalWS, viewDirWS, sideUpMask);
	half3 finalColor = lerp(diffuseColor, specularColor, fresnelTerm);

	// -----------------------------------------------------------------------------------------
	half3 causticsMask, causticsFinal;
	CalculatePointVolumeAndCaustics(input, normalWS, screenUV, mainLight, sceneZ, fade, ro, rd, 
							finalColor, causticsMask, causticsFinal);
	//
	CalculateShallowFade(grabColor, fade, 1, finalColor);
	
	// Zero SrcColor = grab * finalColor 先计算和下层乘法部分
	return half4(finalColor, 1);
}

// -----------------------------------------------------------
// Fragment Outer Add
half4 WaterAquariumOuterAddFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);

	half3 viewDirWS, normalWS;
	Light mainLight;
	half sideUpMask;
	float2 screenUV;
	float sceneZ, fade, thickness;
	float3 ro, rd;
	
	ConfigOuterInfo(input,
			viewDirWS, mainLight, normalWS, sideUpMask, screenUV, sceneZ, fade, thickness, ro, rd);

	// -----------------------------------------------------------------------------------------
	half3 grabColor = 1;
	float turbidityMask, transparentMask;
	// diffuse
	half3 diffuseColor = GetDiffuseColor(grabColor, normalWS, mainLight, fade, 0, turbidityMask, transparentMask);
	// specular
	half3 specularColor = GetSpecularColor(input, viewDirWS, normalWS, mainLight, sideUpMask);

	// fresnel 使用法线贴图计算效果不好
	half fresnelTerm = GetFresnelTerm(input.normalWS, viewDirWS, sideUpMask);
	half3 finalColor = lerp(diffuseColor, specularColor, fresnelTerm);
	
	// 透射
	#if _F_TRANSMISSION_ON
		// 不考虑法线 效果不好
		half3 transmissionColor = GetTransmission(thickness, mainLight.direction, input.normalWS, viewDirWS);
		finalColor += transmissionColor;
	#endif
	
	// -----------------------------------------------------------------------------------------
	half3 causticsMask, causticsFinal;
	CalculatePointVolumeAndCaustics(input, normalWS, screenUV, mainLight, sceneZ, fade, ro, rd, 
							finalColor, causticsMask, causticsFinal);
	//
	CalculateShallowFade(grabColor, fade, 0, finalColor);

	// -----------------------------------------------------------------------------------------
	half debugAlpha = 0;

	#if _DEBUGSHOWTURBIDITY_ON
		finalColor = turbidityMask;
	#elif _DEBUGSHOWTRANSPARENT_ON
		finalColor = transparentMask;
	#elif _DEBUGSHOWFADE_ON
		finalColor = fade / 100;
	#elif _DEBUGSHOWCAUSTICS_ON
		finalColor = causticsFinal;
	#elif _DEBUGSHOWCAUSTICSMASK_ON
		finalColor = causticsMask;
	#else
		debugAlpha = 1;
	#endif

	// One SrcAlpha = finalColor + grabColor * debugAlpha 
	// debugAlpha 只是为了测试用 默认为1 即存粹的加法混合
	return half4(finalColor, debugAlpha);
}

// -----------------------------------------------------------
// Fragment Final
half4 WaterAquariumFinalFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);

 	// 法线
    half3x3 tangentToWorld = GetTangentToWorld(input);
    half3 normalTS, normalWS;
    GetNormal(input.uv, tangentToWorld, _NormalTiling, _NormalScale, normalTS, normalWS);

	half3 grabColor = GetGrabColor(input.positionNDC, normalTS).rgb;

	return half4(grabColor, 1);
}
#endif
