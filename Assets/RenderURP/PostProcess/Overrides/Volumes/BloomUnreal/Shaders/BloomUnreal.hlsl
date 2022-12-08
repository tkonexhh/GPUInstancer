#ifndef BLOOM_UNREAL_INCLUDED
#define BLOOM_UNREAL_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"

#define MAXFILTERSAMPLES 32
#define PACKED_MAXFILTERSAMPLES ((MAXFILTERSAMPLES + 1) / 2)


TEXTURE2D(_SourceTex);
TEXTURE2D(_AdditiveTex);
TEXTURE2D(_BloomTex);

float4 _SourceTex_TexelSize;
float4 _BloomTex_TexelSize;

float _Threshold;
float _Intensity;
float _SampleCount;
#define _Packed_SampleCount ((_SampleCount + 1) / 2)

float4 _SampleWeights[MAXFILTERSAMPLES];
float4 _OffsetUVs[PACKED_MAXFILTERSAMPLES];

// Unreal 用的Rec.601明度计算系数
float LuminanceRec601(float3 LinearColor)
{
	return dot(LinearColor, float3(0.3, 0.59, 0.11));
}

float4 FragDownSample(Varyings input) : SV_Target
{
    float2 uv = input.uv;
    float2 k = _SourceTex_TexelSize.xy;

    float4 color;

    #if USE_DOWNSAMPLE_FILTER
        float4 tl = SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, uv + k * float2(-1, -1));
        float4 tr = SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, uv + k * float2( 1, -1));
        float4 bl = SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, uv + k * float2(-1,  1));
        float4 br = SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, uv + k * float2( 1,  1));

        color = (tl + tr + bl + br) * 0.25f;
    #else
        color = SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, uv);
    #endif

    color.rgb = max(0, color.rgb);

	return color;
}

float4 FragPrefilter(Varyings input) : SV_Target
{
    float2 uv = input.uv;

    float3 sceneColor = SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, uv);

	// clamp to avoid artifacts from exceeding fp16 through framebuffer blending of multiple very bright lights
	sceneColor.rgb = min(256 * 256, sceneColor.rgb);

	half totalLuminance = LuminanceRec601(sceneColor);
	half bloomLuminance = totalLuminance - _Threshold;
	half bloomAmount = saturate(bloomLuminance * 0.5f);

	return float4(bloomAmount * sceneColor, 0);
}

float4 FragBlur(Varyings input) : SV_Target
{
    float4 color = 0;

    // TODO 移动端后续要unroll展开 SampleCount得用多pass处理
    // UNITY_UNROLL
	for (int index = 0; index < _SampleCount - 1; index += 2)
	{
		float4 uvuv = input.uv.xyxy + _OffsetUVs[index / 2];
		color += SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, uvuv.xy) * _SampleWeights[index + 0];
		color += SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, uvuv.zw) * _SampleWeights[index + 1];
	}

    // 奇数剩余部分
	// UNITY_FLATTEN
    if (_SampleCount % 2 == 1)
	{
		float2 uv = input.uv + _OffsetUVs[_Packed_SampleCount - 1].xy;
		color += SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, uv) * _SampleWeights[_SampleCount - 1];
	}

    // 模糊后混合部分
    #if USE_COMBINE_ADDITIVE
	    color += SAMPLE_TEXTURE2D(_AdditiveTex, sampler_LinearClamp, input.uv);
    #endif

    return color;
}

float4 FragCombine(Varyings input) : SV_Target
{
    float2 uv = input.uv;
    float4 sceneColor = SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, uv);

    float4 bloomColor = SAMPLE_TEXTURE2D(_BloomTex, sampler_LinearClamp, uv);
    sceneColor.rgb += bloomColor.rgb * _Intensity; 

    return sceneColor;
}



#endif // BLOOM_UNREAL_INCLUDED
