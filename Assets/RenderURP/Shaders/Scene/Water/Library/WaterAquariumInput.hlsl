#ifndef WATERAQUARIUM_INPUT_INCLUDED
#define WATERAQUARIUM_INPUT_INCLUDED

#include "WaterCommon.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"

// ----------------------------------------------------------
CBUFFER_START(UnityPerMaterial)
	half 	_NormalScale;
	half 	_NormalTiling;
	half 	_WaterDistortScale;

	half4 	_WaterSize;
	half 	_WaterSpeed;
	half 	_WaveAmplitude;
	float 	_WaveLength;
	float 	_WaveSpeed;
	float 	_WaveDir;

	half4 	_InnerColor;
	half 	_InnerLerp;

	half4 	_WaterColor;
	half 	_Transparent;
	half4 	_TurbidityColor;
	half 	_Turbidity;

	half4 	_TransmissionColor;
	half 	_TransmissionScale;
	half 	_TransmissionPower;

	float3 	_LightDirection;
	half 	_SpecularRoughness;
	half4 	_SpecularColor;
	half 	_SpecularIntensity;

	half	_DiffuseLightIntensity;
	half	_ShadowIntensity;

	float4	_PointVolumePos;
	half4 	_PointVolumeColor;
	half 	_PointVolumeRadius;
	half 	_PointVolumeIntensity;

	half 	_CausticsRangeGradient;
	half 	_CausticsVerticalThreshold;

	half4 	_CausticsColor;
	half 	_CausticsIntensity;
	half 	_CausticsTiling;
	half 	_CausticsSpeed;
CBUFFER_END

TEXTURE2D(_NormalTex);                  		SAMPLER(sampler_NormalTex);
TEXTURE2D(_CausticsTex);                		SAMPLER(sampler_CausticsTex);
TEXTURE2D_X_FLOAT(_CameraNormalsTexture);    	SAMPLER(sampler_CameraNormalsTexture); // _GBuffer2
TEXTURE2D_X_FLOAT(_CameraDepthTexture);			SAMPLER(sampler_CameraDepthTexture);
// 最后扭曲Pass用
TEXTURE2D(_GrabTexture);                		SAMPLER(sampler_GrabTexture);

// ----------------------------------------------------------
static const half 	WaveAmplitude[6] 	= {1.8, 0.8, 0.5, 0.3, 0.1, 0.08};
static const half 	WaveLength[6] 		= {0.541, 0.7, 0.2, 0.3, 0.08, 0.03};
static const half 	WaveSpeed[6] 		= {0.305, 0.5, 0.34, 0.12, 0.74, 0.11};
static const half 	WaveDir[6] 			= {11, 90, 167, 300, 10, 180};



// ----------------------------------------------------------

// https://developer.nvidia.com/gpugems/gpugems/part-i-natural-effects/chapter-1-effective-water-simulation-physical-models
// TODO 没有重新计算法线和切线
float3 GetWaveOffset(int index, float2 pos)
{
	half dir = WaveDir[index] + _WaveDir;
	half amplitude = WaveAmplitude[index] * _WaveAmplitude / 6; // 列表中是衰减振幅，暂时只做一个统一缩放
	half length = WaveLength[index] * _WaveLength;
	half speed = WaveSpeed[index] * _WaveSpeed;

	// 
	float rad = radians(dir % 360);
	float2 D = normalize(float2(sin(rad), cos(rad)));

	float A = amplitude;
	float W = 2 * PI / length; 

	float F = W * dot(D, pos) - _Time.y * sqrt(9.8 * W) * speed;
	float sinF = sin(F);

	#if _WAVETYPE_SINE
		float3 offset = float3(0, A * sinF, 0);

	#elif _WAVETYPE_GERSTNER
		float cosF = cos(F);
		float3 offset = float3(A * D * cosF / W, A * sinF);
		offset.xyz = offset.xzy;

	#endif

	return offset;
}

void CalculateWaves(inout float4 positionOS)
{
	float3 offset = 0;

	float2 pos = positionOS.xz;
	offset += GetWaveOffset(0, pos);
	offset += GetWaveOffset(1, pos);

	#if _WAVENUMS__4 || _WAVENUMS__6
		offset += GetWaveOffset(2, pos);
		offset += GetWaveOffset(3, pos);
	#endif
	#if _WAVENUMS__6
		offset += GetWaveOffset(4, pos);
		offset += GetWaveOffset(5, pos);
	#endif

	positionOS.xyz += offset;
}

// ----------------------------------------------------------
void GetNormal(float2 uv, float3x3 tangentToWorld, float normalTiling, float normalScale, 
        inout half3 normalTS, inout half3 normalWS)
{
    uv *= normalTiling;
    
    float2 uv_a = uv + frac(_Time.y * float2(-0.03, 0) * _WaterSpeed);
    float2 uv_b = uv + frac(_Time.y * float2(0.04, 0.04) * _WaterSpeed);

    half3 normalTS_a = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, uv_a), normalScale);
    half3 normalTS_b = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, uv_b), normalScale);
	normalTS = BlendNormalRNM(normalTS_a, normalTS_b);

    normalWS = NormalizeNormalPerPixel(TransformTangentToWorld(normalTS, tangentToWorld));
}

float2 GetScreenUV(float4 positionNDC)
{
    return positionNDC.xy * rcp(positionNDC.w);
}

half4 GetGrabColor(float2 screenUV)
{
    return SAMPLE_TEXTURE2D(_GrabTexture, sampler_GrabTexture, screenUV);
}

half4 GetGrabColor(float4 positionNDC, half3 normalTS)
{
    float2 screenUV = (positionNDC.xy + normalTS.xy * _WaterDistortScale) * rcp(positionNDC.w);
    return GetGrabColor(screenUV);
}

#if _F_CAUSTICS_ON
    half3 GetCausticsColor(float2 uv)
    {
        float speed = _Time.y * _CausticsSpeed;

        float2 cuv1 = uv / _CausticsTiling + frac(float2(0.044 * speed + 17.16, -0.169 * speed));
        float2 cuv2 = uv / _CausticsTiling * 1.37 + frac(float2(0.248 * speed, 0.117 * speed));
    
        half3 c1 = SAMPLE_TEXTURE2D(_CausticsTex, sampler_CausticsTex, cuv1).rgb;
        half3 c2 = SAMPLE_TEXTURE2D(_CausticsTex, sampler_CausticsTex, cuv2).rgb;

        half3 causticsColor = min(c1, c2);//0.5 * (c1 + c2);

        return causticsColor;
    }
#endif



#endif // WATERAQUARIUM_INPUT_INCLUDED
