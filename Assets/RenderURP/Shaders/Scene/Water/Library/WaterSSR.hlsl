#ifndef WATER_SSR_INCLUDED
#define WATER_SSR_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

TEXTURE2D_X_FLOAT(_CameraDepthTexture);
SAMPLER(sampler_CameraDepthTexture);

float UVJitter(in float2 uv)
{
	return frac((52.9829189 * frac(dot(uv, float2(0.06711056, 0.00583715)))));
}

#ifndef BUILTIN_TARGET_API
	inline float4 ComputeGrabScreenPos (float4 pos) 
	{
		#if UNITY_UV_STARTS_AT_TOP
			float scale = -1.0;
		#else
			float scale = 1.0;
		#endif
		float4 o = pos * 0.5f;
		o.xy = float2(o.x, o.y * scale) + o.w;
		o.zw = pos.zw;
		return o;
	}
#endif

void SSRRayConvert(float3 positionWS, out float4 clipPos, out float3 screenPos, out float2 grabPos)
{
	clipPos = TransformWorldToHClip(positionWS);
	float k = ((1.0) / (clipPos.w));

	screenPos.xy = ComputeScreenPos(clipPos).xy * k;
	screenPos.z = k;

	grabPos = ComputeGrabScreenPos(clipPos).xy * k;
}

float3 SSRRayMarch(float3 positionCS, float3 positionWS, float3 reflectVector, float step, float count)
{
	float4 startClipPos;
	float3 startScreenPos;
	float2 startGrabPos;

	SSRRayConvert(positionWS, startClipPos, startScreenPos, startGrabPos);

	float4 endClipPos;
	float3 endScreenPos;
	float2 endGrabPos;

	SSRRayConvert(positionWS + reflectVector, endClipPos, endScreenPos, endGrabPos);

	if (((endClipPos.w) < (startClipPos.w)))
	{
		return float3(0, 0, 0);
	}

	float3 screenDir = endScreenPos - startScreenPos;
	float2 grabDir = endGrabPos - startGrabPos;

	float screenDirX = abs(screenDir.x);
	float screenDirY = abs(screenDir.y);

	float dirMultiplier = lerp( 1 / (_ScreenParams.y * screenDirY), 1 / (_ScreenParams.x * screenDirX), screenDirX > screenDirY ) * step;

	screenDir *= dirMultiplier;
	grabDir *= dirMultiplier;

	half lastRayDepth = startClipPos.w;

	half sampleCount = 1 + UVJitter(positionCS) * 0.1;

	float lastDeltaDepth = 0;

	// TODO
	#if defined (SHADER_API_OPENGL) || defined (SHADER_API_D3D11) || defined (SHADER_API_D3D12)
		UNITY_LOOP
	#else
		[unroll(1)]
	#endif
	for(int i = 0; i < count; i++)
	{
		float3 screenMarchUVZ = startScreenPos + screenDir * sampleCount;

		if((screenMarchUVZ.x <= 0) || (screenMarchUVZ.x >= 1) || (screenMarchUVZ.y <= 0) || (screenMarchUVZ.y >= 1))
		{
			break;
		}

    	float rawDepth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, screenMarchUVZ.xy);
	    float sceneDepth = (unity_OrthoParams.w == 0) ? LinearEyeDepth(rawDepth, _ZBufferParams) : LinearDepthToEyeDepth(rawDepth);

		half rayDepth = 1.0 / screenMarchUVZ.z;
		half deltaDepth = rayDepth - sceneDepth;

		if((deltaDepth > 0) && (sceneDepth > startClipPos.w) && (deltaDepth < (abs(rayDepth - lastRayDepth) * 2)))
		{
			float samplePercent = saturate(lastDeltaDepth / (lastDeltaDepth - deltaDepth));
			samplePercent = lerp(samplePercent, 1, rayDepth >= _ProjectionParams.z);
			float hitSampleCount = lerp(sampleCount-1, sampleCount, samplePercent);
			return float3(startGrabPos + grabDir * hitSampleCount, 1);
		}

		lastRayDepth = rayDepth;
		sampleCount += 1;

		lastDeltaDepth = deltaDepth;
	}

	float4 farClipPos;
	float3 farScreenPos;
	float2 farGrabPos;

	SSRRayConvert(positionWS + reflectVector * 100000, farClipPos, farScreenPos, farGrabPos);

	if((farScreenPos.x > 0) && (farScreenPos.x < 1) && (farScreenPos.y > 0) && (farScreenPos.y < 1))
	{
		float rawFarDepth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, farScreenPos.xy);
	    float farDepth = (unity_OrthoParams.w == 0) ? LinearEyeDepth(rawFarDepth, _ZBufferParams) : LinearDepthToEyeDepth(rawFarDepth);

		if(farDepth > startClipPos.w)
		{
			return float3(farGrabPos, 1);
		}
	}

	return float3(0, 0, 0);
}

float3 GetSSRUVZ(float NdotV, float2 suv, float3 positionCS, float3 positionWS, float3 reflectVector, float step, float count)
{
	float2 screenUV = suv * 2 - 1;
	screenUV *= screenUV;

	half ssrWeight = saturate(1 - dot(screenUV, screenUV));

	half NoV = NdotV * 2.5;
	ssrWeight *= (1 - NoV * NoV);

	if (ssrWeight > 0.005)
	{
		float3 uvz = SSRRayMarch(positionCS, positionWS, reflectVector, step, count);
		uvz.z *= ssrWeight;
		return uvz;
	}

	return float3(0, 0, 0);
}

// ------------------------------------------------------------------------------------
// 相机平面反射 TODO 掠射角有漏颜色 否则可以替代下面两个
// TEXTURE2D(_MirrorReflectionMap);                  SAMPLER(sampler_MirrorReflectionMap);
// float2 puv = GetPlanarReflectionNormalUV(normalWS, viewDirWS);
// float4 mirror_refl = SAMPLE_TEXTURE2D(_MirrorReflectionMap, sampler_MirrorReflectionMap, puv);
// mirror_refl.rgb = lerp(mirror_refl.rgb, ssrFinal.rgb, mirror_refl.a);
	
half3 NormalLocalToEye(half3 normal)
{
	normal.xz = (mul((float3x3)UNITY_MATRIX_V, half3(normal.x, 0, normal.z))).xz;
	return normal;
}

float2 GetPlanarReflectionNormalUV(float3 N, float3 V)
{
	float3 view_n = normalize(NormalLocalToEye(N));
	float3 view_dir = mul((float3x3)UNITY_MATRIX_V, V);
	float3 refl_ray = normalize(reflect(-view_dir, view_n));
	float4 screen_pos = mul(unity_CameraProjection, float4(refl_ray, 1));
	screen_pos.xy /= screen_pos.w;
	float2 uv = float2(screen_pos.x * 0.5 + 0.5, -screen_pos.y * 0.5 + 0.5);
	return uv;
}


#endif