#ifndef _LIGHT_SHAFT_INCLUDED
#define _LIGHT_SHAFT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"

#if QUALITY_LOW
	#define SAMPLE_NUM 20
#elif QUALITY_MEDIUM
	#define SAMPLE_NUM 32
#else // QUALITY_HIGH
	#define SAMPLE_NUM 32
#endif

// ----------------------------------------------------------------------------------------
TEXTURE2D(_SourceTex);
TEXTURE2D(_LightShaftTex);

float3 	_MainLightUV;
half4 	_Color;
float4  _Params;
#define _Intensity  _Params.x
#define _Radius		_Params.y
#define _Density	_Params.z
#define _Threshold	_Params.w 


half4 FragPrefilter(Varyings input) : SV_Target
{
	float2 uv = input.uv;

    half4 color = SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, uv);

	// depth
    float depth = SampleSceneDepth(uv);
	depth = Linear01Depth(depth, _ZBufferParams);
	// TODO 目前用的天空是个mesh 深度不确定 要在sceneview和gameview同时排除比较麻烦 
	half isSky = step(_Threshold, depth);

	// 只需要天空部分明度
	half luminance = Max3(color.r, color.g, color.b) * isSky;

	float2 diffUV = uv - _MainLightUV.xy;
	diffUV.x *= _ScreenParams.x / _ScreenParams.y;

	// 光源附近圆形衰减
	float decay = (1 - saturate(length(diffUV) - _Radius)) * isSky;

	#if DEBUG_PREFILTER
		return decay * luminance;
	#endif

	return half4(decay, luminance, 1, 1);
}

half4 FragRadialBlur(Varyings input) : SV_Target
{
	float2 uv = input.uv;

	float2 diffUV = uv - _MainLightUV.xy;
	diffUV *= _Density * rcp(SAMPLE_NUM);

	half final = 0;

	UNITY_UNROLL
	for (int i = 0; i < SAMPLE_NUM; i++)
	{
		uv -= diffUV;

		// g通道只有第一次模糊是明度阈值
    	half2 color = SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, uv).rg;

		final += color.r * color.g;
	}
	final *= rcp(SAMPLE_NUM);

	return half4(final, 1, 1, 1);
}

half4 FragComposite(Varyings input) : SV_Target
{
	float2 uv = input.uv;

	half3 color = SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, uv).rgb;

	half3 shaftColor = SAMPLE_TEXTURE2D(_LightShaftTex, sampler_LinearClamp, uv).rrr;
	shaftColor = shaftColor * _Color.rgb * _Intensity;

	// TODO HDR range blend mode
	half3 finalColor = color + shaftColor;

	#if DEBUG_LIGHTSHAFTONLY
		return float4(shaftColor, 1);
	#endif

	return half4(finalColor, 1);
}

#endif // _LIGHT_SHAFT_INCLUDED
