#ifndef LENS_FLARES_INCLUDED
#define LENS_FLARES_INCLUDED

// https://www.froyok.fr/blog/2021-09-ue4-custom-lens-flare/

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"

TEXTURE2D(_SourceTex);
float4  _SourceTex_TexelSize;

TEXTURE2D(_PrefilterTex);
float4  _PrefilterTex_TexelSize;

float4  _Params1;
float4  _Params2;
float4  _Params3;

#define _Intensity          _Params1.x
#define _ThresholdLevel     _Params1.yz
#define _ThresholdRange     _Params1.w

#define _GhostIntensity     _Params2.x
#define _GhostScale         _Params2.yzw

#define _HaloIntensity      _Params3.x
#define _HaloWidth          _Params3.y
#define _HaloMask           _Params3.z
#define _HaloCompression    _Params3.w

static const float2 CenterPoint     = float2(0.5f, 0.5f);
static const float  ChromaticShift  = -0.15f;

// ----------------------------------------------------------------------------

float DiscMask(float2 uv)
{
	float x = saturate(1.0f - dot(uv, uv));
	return x * x;
}

float2 FisheyeUV(float2 uv, float compression, float zoom)
{
    float2 negPosUV = (2.0f * uv - 1.0f);

    float scale = compression * atan(1.0f / compression);
    float radiusDistance = length(negPosUV) * scale;
    float radiusDirection = compression * tan(radiusDistance / compression) * zoom;
    float phi = atan2(negPosUV.y, negPosUV.x);

    float2 newUV = float2(radiusDirection * cos(phi) + 1.0,
                          radiusDirection * sin(phi) + 1.0);
    newUV = newUV / 2.0;

    return newUV;
}

void GetChromaticShiftUV(float2 uv, inout float2 uvr, inout float2 uvb)
{
    uvr = (uv - CenterPoint) * (1.0f + ChromaticShift) + CenterPoint;
    uvb = (uv - CenterPoint) * (1.0f - ChromaticShift) + CenterPoint;
}
// ----------------------------------------------------------------------------
half4 FragPrefilter(Varyings input) : SV_Target
{
    float2 uv = input.uv;
    half3 finalColor;

    half3 color = 0;
    // 4 central samples
    float2 centerUV_1 = uv + _SourceTex_TexelSize.xy * float2(-1.0f, 1.0f);
    float2 centerUV_2 = uv + _SourceTex_TexelSize.xy * float2( 1.0f, 1.0f);
    float2 centerUV_3 = uv + _SourceTex_TexelSize.xy * float2(-1.0f,-1.0f);
    float2 centerUV_4 = uv + _SourceTex_TexelSize.xy * float2( 1.0f,-1.0f);

    color += SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, centerUV_1 ).rgb;
    color += SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, centerUV_2 ).rgb;
    color += SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, centerUV_3 ).rgb;
    color += SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, centerUV_4 ).rgb;

    finalColor = (color / 4.0f) * 0.5f;

    // 3 row samples
    color = 0;

    float2 rowUV_1 = uv + _SourceTex_TexelSize.xy * float2(-2.0f, 2.0f);
    float2 rowUV_2 = uv + _SourceTex_TexelSize.xy * float2( 0.0f, 2.0f);
    float2 rowUV_3 = uv + _SourceTex_TexelSize.xy * float2( 2.0f, 2.0f);

    float2 rowUV_4 = uv + _SourceTex_TexelSize.xy * float2(-2.0f, 0.0f);
    float2 rowUV_5 = uv + _SourceTex_TexelSize.xy * float2( 0.0f, 0.0f);
    float2 rowUV_6 = uv + _SourceTex_TexelSize.xy * float2( 2.0f, 0.0f);

    float2 rowUV_7 = uv + _SourceTex_TexelSize.xy * float2(-2.0f,-2.0f);
    float2 rowUV_8 = uv + _SourceTex_TexelSize.xy * float2( 0.0f,-2.0f);
    float2 rowUV_9 = uv + _SourceTex_TexelSize.xy * float2( 2.0f,-2.0f);

    color += SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, rowUV_1).rgb;
    color += SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, rowUV_2).rgb;
    color += SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, rowUV_3).rgb;

    color += SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, rowUV_4).rgb;
    color += SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, rowUV_5).rgb;
    color += SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, rowUV_6).rgb;

    color += SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, rowUV_7).rgb;
    color += SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, rowUV_8).rgb;
    color += SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, rowUV_9).rgb;

    finalColor += (color / 9.0f) * 0.5f;

    // TODO 低质量情况这一步下采样可以不做模糊
    // finalColor = SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, uv).rgb;

    // threshold
    float luminance = dot(finalColor.rgb, 1);
    luminance = step(luminance, _ThresholdLevel.y) * luminance;
    float thresholdScale = saturate((luminance - _ThresholdLevel.x) / _ThresholdRange);

    finalColor *= thresholdScale;

    return float4(finalColor, 1);
}

half4 FragChromatic(Varyings input) : SV_Target
{
    float2 uv = input.uv;

    float2 uvr, uvb;
    GetChromaticShiftUV(uv, uvr, uvb);

    half3 finalColor;
    finalColor.r = SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, uvr).r;
    finalColor.g = SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, uv ).g;
    finalColor.b = SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, uvb).b;

    return half4(finalColor, 1);
}

// 只用了三层 Ghost 来描述外围的效果
// static const float _GhostScaleDefault[8] = {-1.5, 2.5, -5.0, 10.0, 0.7, -0.4, -0.2, -0.1};

half4 FragGhosts(Varyings input) : SV_Target
{
    float2 uv = input.uv;
    half4 finalColor = 1;

    float2 screenUV = (uv - CenterPoint) * 2.0;
    float screenborderMask = DiscMask(screenUV * 0.9f);

    // -------------------------------------------------- ghost
    half3 ghostColor = 0;
    [unroll(3)]
    for(int i = 0; i < 3; i++)
    {
        float2 newUV = (uv - 0.5f) * _GhostScale[i];

        // Local mask
        float distanceMask = 1.0f - distance(float2(0.0f, 0.0f), newUV);
        float mask1 = smoothstep(0.5f, 0.9f, distanceMask);
        float mask2 = smoothstep(0.75f, 1.0f, distanceMask) * 0.95f + 0.05f;

        ghostColor += SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, newUV + 0.5f).rgb * mask1 * mask2;
    }

    finalColor.rgb = ghostColor * screenborderMask * _GhostIntensity;

    // -------------------------------------------------- halo
    half3 haloColor = 0;
    float2 fishUV = FisheyeUV(uv, _HaloCompression, 1.0f);

    // Distortion vector
    float2 haloVector = normalize(CenterPoint - uv) * _HaloWidth;

    // Halo mask
    float haloMask = distance(uv, CenterPoint);
    haloMask = saturate(haloMask * 2.0f);
    haloMask = smoothstep(_HaloMask, 1.0f, haloMask);

    // Screen border mask
    screenborderMask = screenborderMask * 0.95 + 0.05; // Scale range

    // Chroma offset
    float2 uvr, uvb;
    GetChromaticShiftUV(fishUV, uvr, uvb);

    // Sampling
    haloColor.r = SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, uvr + haloVector).r;
    haloColor.g = SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, uv  + haloVector).g;
    haloColor.b = SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, uvb + haloVector).b;

    finalColor.rgb += haloColor * screenborderMask * haloMask * _HaloIntensity;

    return finalColor;
}


half4 FragComposite(Varyings input) : SV_Target
{
    float2 uv = input.uv;

    half4 lensFlaresColor = SAMPLE_TEXTURE2D(_PrefilterTex, sampler_LinearClamp, uv) * _Intensity;

    #if DEBUG_LENSFLARES
        return half4(lensFlaresColor.rgb, 1);
    #endif

    half4 sceneColor = SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, uv);
    sceneColor.rgb += lensFlaresColor.rgb;

    return sceneColor;
}




#endif // LENS_FLARES_INCLUDED
