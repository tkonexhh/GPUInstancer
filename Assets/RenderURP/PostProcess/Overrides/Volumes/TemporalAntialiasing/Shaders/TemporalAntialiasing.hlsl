#ifndef TEMPORAL_ANTIALIASING_INCLUDED
#define TEMPORAL_ANTIALIASING_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"

#if MEDIUM_QUALITY
    #define YCOCG                   1
    #define NEIGHBOUROOD_VARIANCE   1
    #define HISTORY_CLIP_AABB       1
    #define WIDE_NEIGHBOURHOOD      0
    #define SHARPEN_FILTER          0
#elif HIGH_QUALITY
    #define YCOCG                   1
    #define NEIGHBOUROOD_VARIANCE   1
    #define HISTORY_CLIP_AABB       1
    #define WIDE_NEIGHBOURHOOD      1
    #define SHARPEN_FILTER          1
#else // LOW_QUALITY
    #define YCOCG                   0
    #define NEIGHBOUROOD_VARIANCE   0
    #define HISTORY_CLIP_AABB       0
    #define WIDE_NEIGHBOURHOOD      0
    #define SHARPEN_FILTER          0
#endif

// ------------------------------------------------------------------------------------
#define CLAMP_MAX       65472.0 // HALF_MAX minus one (2 - 2^-9) * 2^15

TEXTURE2D(_SourceTex);
TEXTURE2D(_HistoryTexture);
TEXTURE2D_FLOAT(_MotionVectorTexture);

float4 _SourceTex_TexelSize;
float4 _CameraDepthTexture_TexelSize;
float4 _HistoryTexture_TexelSize;

float4x4 _PrevViewProjectionMatrix;
float2   _Jitter;
float4   _Params1;
float4   _Params2;
#define _SharpenStrength                _Params1.x
#define _AntiFlickerIntensity           _Params1.y
#define _ContrastForMaxAntiFlicker      _Params1.z
#define _SharpenHistoryStrength         _Params1.w
#define _SharpenBlend                   _Params2.x
#define _StationaryBlend                _Params2.y
#define _MotionBlend                    _Params2.z

#if defined(UNITY_REVERSED_Z)
    #define COMPARE_DEPTH(a, b) step(b, a)
#else
    #define COMPARE_DEPTH(a, b) step(a, b)
#endif

#define SMALL_NEIGHBOURHOOD_SIZE 4 
#define NEIGHBOUR_COUNT ((WIDE_NEIGHBOURHOOD == 0) ? SMALL_NEIGHBOURHOOD_SIZE : 8)

struct NeighbourhoodSamples
{
    #if WIDE_NEIGHBOURHOOD
        float3 neighbours[8];
    #else
        float3 neighbours[4];
    #endif

    float3 central;
    float3 minNeighbour;
    float3 maxNeighbour;
    float3 avgNeighbour;
};

// ---------------------------------------------------

float3 Min3Float3(float3 a, float3 b, float3 c)
{
    return float3(Min3(a.x, b.x, c.x),
        Min3(a.y, b.y, c.y),
        Min3(a.z, b.z, c.z));
}

float3 Max3Float3(float3 a, float3 b, float3 c)
{
    return float3(Max3(a.x, b.x, c.x),
        Max3(a.y, b.y, c.y),
        Max3(a.z, b.z, c.z));
}

float3 ConvertToWorkingSpace(float3 color)
{
    #if YCOCG
        return RGBToYCoCg(color);
    #else
        return color;
    #endif
}

float3 ConvertToOutputSpace(float3 color)
{
    #if YCOCG
        return YCoCgToRGB(color);
    #else
        return color;
    #endif
}

float GetLuma(float3 color)
{
    #if YCOCG
        // We work in YCoCg hence the luminance is in the first channel.
        return color.x;
    #else
        return Luminance(color);
    #endif
}

float PerceptualWeight(float3 c)
{
    #if _USETONEMAPPING
        return rcp(GetLuma(c) + 1.0);
    #else
        return 1;
    #endif
}

float PerceptualInvWeight(float3 c)
{
    #if _USETONEMAPPING
        return rcp(1.0 - GetLuma(c));
    #else
        return 1;
    #endif
}
// ------------------------------------------------------------------------------------

// 找到邻近深度最小的点的uv作为MotionVector的uv
// Front most neighbourhood velocity ([Karis 2014])
float2 GetClosestFragment(float depth, float2 uv)
{
    float2 k = _CameraDepthTexture_TexelSize.xy;

    // 只用了斜角 tl tr bl br 节省性能
    float3 tl = float3(-1, -1, SampleSceneDepth(uv - k));
    float3 tr = float3( 1, -1, SampleSceneDepth(uv + float2( k.x, -k.y)));
    float3 mc = float3( 0,  0, depth);
    float3 bl = float3(-1,  1, SampleSceneDepth(uv + float2(-k.x,  k.y)));
    float3 br = float3( 1,  1, SampleSceneDepth(uv + k));
    // float3 tc = float3( 0, -1, SampleSceneDepth(uv + float2( 0,   -k.y)));
    // float3 ml = float3(-1,  0, SampleSceneDepth(uv + float2(-k.x,  0)));
    // float3 mr = float3( 1,  0, SampleSceneDepth(uv + float2( k.x,  0)));
    // float3 bc = float3( 0,  1, SampleSceneDepth(uv + float2( 0,    k.y)));

    float3 rmin = mc;
    rmin = lerp(rmin, tl, COMPARE_DEPTH(tl.z, rmin.z));
    rmin = lerp(rmin, tr, COMPARE_DEPTH(tr.z, rmin.z));
    rmin = lerp(rmin, bl, COMPARE_DEPTH(bl.z, rmin.z));
    rmin = lerp(rmin, br, COMPARE_DEPTH(br.z, rmin.z));
    // rmin = lerp(rmin, tc, COMPARE_DEPTH(tc.z, rmin.z));
    // rmin = lerp(rmin, ml, COMPARE_DEPTH(ml.z, rmin.z));
    // rmin = lerp(rmin, mr, COMPARE_DEPTH(mr.z, rmin.z));
    // rmin = lerp(rmin, bc, COMPARE_DEPTH(bc.z, rmin.z));

    return uv + rmin.xy * k;
}

// 没有MotionVector 只处理摄像机运动的偏移
float2 GetReprojection(float depth, float2 uv)
{
    #if UNITY_REVERSED_Z
        depth = 1.0 - depth;
    #endif

    depth = 2.0 * depth - 1.0;
    // 深度还原世界坐标 TODO 这里unity_CameraInvProjection需要传递
    float3 viewPos = ComputeViewSpacePosition(uv, depth, unity_CameraInvProjection);
    float4 worldPos = float4(mul(unity_CameraToWorld, float4(viewPos, 1.0)).xyz, 1.0);

    // 利用上一帧VP矩阵 找到当前坐标在上一帧的uv
    float4 prevClipPos = mul(_PrevViewProjectionMatrix, worldPos);
    float2 prevPosCS = prevClipPos.xy / prevClipPos.w;
    return prevPosCS * 0.5 + 0.5;
}


// From Filmic SMAA presentation[Jimenez 2016]
// A bit more verbose that it needs to be, but makes it a bit better at latency hiding
float3 HistoryBicubic5Tap(float2 UV, float sharpening)
{
    float2 samplePos = UV * _HistoryTexture_TexelSize.zw;
    float2 tc1 = floor(samplePos - 0.5) + 0.5;
    float2 f = samplePos - tc1;
    float2 f2 = f * f;
    float2 f3 = f * f2;

    const float c = sharpening;

    float2 w0 = -c         * f3 +  2.0 * c         * f2 - c * f;
    float2 w1 =  (2.0 - c) * f3 - (3.0 - c)        * f2          + 1.0;
    float2 w2 = -(2.0 - c) * f3 + (3.0 - 2.0 * c)  * f2 + c * f;
    float2 w3 = c          * f3 - c                * f2;

    float2 w12  = w1 + w2;
    float2 tc0  = _HistoryTexture_TexelSize.xy   * (tc1 - 1.0);
    float2 tc3  = _HistoryTexture_TexelSize.xy   * (tc1 + 2.0);
    float2 tc12 = _HistoryTexture_TexelSize.xy   * (tc1 + w2 / w12);

    float3 s0 = SAMPLE_TEXTURE2D(_HistoryTexture, sampler_LinearClamp, float2(tc12.x, tc0.y )).rgb;
    float3 s1 = SAMPLE_TEXTURE2D(_HistoryTexture, sampler_LinearClamp, float2(tc0.x , tc12.y)).rgb;
    float3 s2 = SAMPLE_TEXTURE2D(_HistoryTexture, sampler_LinearClamp, float2(tc12.x, tc12.y)).rgb;
    float3 s3 = SAMPLE_TEXTURE2D(_HistoryTexture, sampler_LinearClamp, float2(tc3.x , tc0.y )).rgb;
    float3 s4 = SAMPLE_TEXTURE2D(_HistoryTexture, sampler_LinearClamp, float2(tc12.x, tc3.y )).rgb;

    float cw0 = (w12.x *  w0.y);
    float cw1 = (w0.x  * w12.y);
    float cw2 = (w12.x * w12.y);
    float cw3 = (w3.x  * w12.y);
    float cw4 = (w12.x *  w3.y);

    // ANTI_RINGING
    float3 min = Min3Float3(s0, s1, s2);
    min = Min3Float3(min, s3, s4);

    float3 max = Max3Float3(s0, s1, s2);
    max = Max3Float3(max, s3, s4);

    //
    s0 *= cw0;
    s1 *= cw1;
    s2 *= cw2;
    s3 *= cw3;
    s4 *= cw4;

    float3 historyFiltered = s0 + s1 + s2 + s3 + s4;
    float weightSum = cw0 + cw1 + cw2 + cw3 + cw4;

    float3 filteredVal = historyFiltered * rcp(weightSum);

    // ANTI_RINGING
    // This sortof neighbourhood clamping seems to work to avoid the appearance of overly dark outlines in case
    // sharpening of history is too strong.
    return clamp(filteredVal, min, max);
}

float3 GetFilteredHistory(float2 uv)
{
    #if _USEBICUBIC5TAP
        float3 history = HistoryBicubic5Tap(uv, _SharpenHistoryStrength);
    #else
        // Bilinear凑活下 没必要Bicubic
        float3 history = SAMPLE_TEXTURE2D(_HistoryTexture, sampler_LinearClamp, uv).rgb;
    #endif

    history = clamp(history, 0, CLAMP_MAX);
    return ConvertToWorkingSpace(history);
}

float3 GetSourceTexture(float2 uv)
{
    float3 color = SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, uv).rgb;
    color = clamp(color, 0, CLAMP_MAX);
    return ConvertToWorkingSpace(color);
}

void ConvertNeighboursToPerceptualSpace(inout NeighbourhoodSamples samples)
{
    samples.neighbours[0] *= PerceptualWeight(samples.neighbours[0]);
    samples.neighbours[1] *= PerceptualWeight(samples.neighbours[1]);
    samples.neighbours[2] *= PerceptualWeight(samples.neighbours[2]);
    samples.neighbours[3] *= PerceptualWeight(samples.neighbours[3]);
    #if WIDE_NEIGHBOURHOOD
        samples.neighbours[4] *= PerceptualWeight(samples.neighbours[4]);
        samples.neighbours[5] *= PerceptualWeight(samples.neighbours[5]);
        samples.neighbours[6] *= PerceptualWeight(samples.neighbours[6]);
        samples.neighbours[7] *= PerceptualWeight(samples.neighbours[7]);
    #endif
    samples.central *= PerceptualWeight(samples.central);
}

void GatherNeighbourhood(float2 uv, float3 centralColor, out NeighbourhoodSamples samples)
{
    float2 k = _SourceTex_TexelSize.xy;

    samples = (NeighbourhoodSamples)0;
    samples.central = centralColor;

    #if WIDE_NEIGHBOURHOOD
        // Plus shape 上下左右 bc mr tc ml 
        samples.neighbours[0] = GetSourceTexture(uv + float2( 0,  1) * k);
        samples.neighbours[1] = GetSourceTexture(uv + float2( 1,  0) * k);
        samples.neighbours[2] = GetSourceTexture(uv + float2( 0, -1) * k);
        samples.neighbours[3] = GetSourceTexture(uv + float2(-1,  0) * k);

        // Cross shape 斜角 bl tr br tl
        samples.neighbours[4] = GetSourceTexture(uv + float2(-1,  1) * k);
        samples.neighbours[5] = GetSourceTexture(uv + float2( 1, -1) * k);
        samples.neighbours[6] = GetSourceTexture(uv + float2( 1,  1) * k);
        samples.neighbours[7] = GetSourceTexture(uv + float2(-1, -1) * k);

    #else // SMALL_NEIGHBOURHOOD_SHAPE == 4
        // Plus shape 上下左右 bc mr tc ml 
        samples.neighbours[0] = GetSourceTexture(uv + float2( 0,  1) * k);
        samples.neighbours[1] = GetSourceTexture(uv + float2( 1,  0) * k);
        samples.neighbours[2] = GetSourceTexture(uv + float2( 0, -1) * k);
        samples.neighbours[3] = GetSourceTexture(uv + float2(-1,  0) * k);
    #endif

    #if _USETONEMAPPING
        ConvertNeighboursToPerceptualSpace(samples);
    #endif
}

float3 FilterCentralColor(NeighbourhoodSamples samples)
{
    // blackman harris filter 省掉
    return samples.central;
}

// msalvi_temporal_supersampling 2016
void VarianceNeighbourhood(inout NeighbourhoodSamples samples, float historyLuma, float colorLuma, float2 antiFlickerParams, float motionVectorLen)
{
    float3 moment1 = 0;
    float3 moment2 = 0;

    UNITY_UNROLL
    for (int i = 0; i < NEIGHBOUR_COUNT; ++i)
    {
        moment1 += samples.neighbours[i];
        moment2 += samples.neighbours[i] * samples.neighbours[i];
    }
    samples.avgNeighbour = moment1 * rcp(NEIGHBOUR_COUNT);

    moment1 += samples.central;
    moment2 += samples.central * samples.central;

    const int sampleCount = NEIGHBOUR_COUNT + 1;
    moment1 *= rcp(sampleCount);
    moment2 *= rcp(sampleCount);

    float3 stdDev = sqrt(abs(moment2 - moment1 * moment1));

    float stDevMultiplier = 1.5;
    // The reasoning behind the anti flicker is that if we have high spatial contrast (high standard deviation)
    // and high temporal contrast, we let the history to be closer to be unclipped. To achieve, the min/max bounds
    // are extended artificially more.
    // float temporalContrast = saturate(abs(colorLuma - historyLuma) / Max3(0.2, colorLuma, historyLuma));

    // const float screenDiag = length(_SourceTex_TexelSize.zw);
    // const float maxFactorScale = 2.25f; // when stationary
    // const float minFactorScale = 0.8f; // when moving more than slightly
    // float localizedAntiFlicker = lerp(antiFlickerParams.x * minFactorScale, antiFlickerParams.x * maxFactorScale, saturate(1.0f - 2.0f * (motionVectorLen * screenDiag)));
    
    // stDevMultiplier += lerp(0.0, localizedAntiFlicker, smoothstep(0.05, antiFlickerParams.y, temporalContrast));
    // TODO 抗闪烁会导致半透物体问题
    samples.minNeighbour = moment1 - stdDev * stDevMultiplier;
    samples.maxNeighbour = moment1 + stdDev * stDevMultiplier;
}

void MinMaxNeighbourhood(inout NeighbourhoodSamples samples)
{
    // We always have at least the first 4 neighbours.
    samples.minNeighbour = Min3Float3(samples.neighbours[0], samples.neighbours[1], samples.neighbours[2]);
    samples.minNeighbour = Min3Float3(samples.minNeighbour, samples.central, samples.neighbours[3]);

    samples.maxNeighbour = Max3Float3(samples.neighbours[0], samples.neighbours[1], samples.neighbours[2]);
    samples.maxNeighbour = Max3Float3(samples.maxNeighbour, samples.central, samples.neighbours[3]);

    #if WIDE_NEIGHBOURHOOD
        samples.minNeighbour = Min3Float3(samples.minNeighbour, samples.neighbours[4], samples.neighbours[5]);
        samples.minNeighbour = Min3Float3(samples.minNeighbour, samples.neighbours[6], samples.neighbours[7]);

        samples.maxNeighbour = Max3Float3(samples.maxNeighbour, samples.neighbours[4], samples.neighbours[5]);
        samples.maxNeighbour = Max3Float3(samples.maxNeighbour, samples.neighbours[6], samples.neighbours[7]);
    #endif

    samples.avgNeighbour = 0;
    UNITY_UNROLL
    for (int i = 0; i < NEIGHBOUR_COUNT; ++i)
    {
        samples.avgNeighbour += samples.neighbours[i];
    }
    samples.avgNeighbour *= rcp(NEIGHBOUR_COUNT);
}

void GetNeighbourhoodCorners(inout NeighbourhoodSamples samples, float historyLuma, float colorLuma, float2 antiFlickerParams, float motionVecLen)
{
    #if NEIGHBOUROOD_VARIANCE
        VarianceNeighbourhood(samples, historyLuma, colorLuma, antiFlickerParams, motionVecLen);
    #else
        MinMaxNeighbourhood(samples);
    #endif
}

// From Playdead's TAA
float3 DirectClipToAABB(float3 history, float3 minimum, float3 maximum)
{
    // note: only clips towards aabb center (but fast!)
    float3 center  = 0.5 * (maximum + minimum);
    float3 extents = 0.5 * (maximum - minimum);

    // This is actually `distance`, however the keyword is reserved
    float3 offset = history - center;
    float3 v_unit = offset.xyz / extents.xyz;
    float3 absUnit = abs(v_unit);
    float maxUnit = Max3(absUnit.x, absUnit.y, absUnit.z);

    if (maxUnit > 1.0)
        return center + (offset / maxUnit);
    else
        return history;
}

// Here the ray referenced goes from history to (filtered) center color
float DistToAABB(float3 color, float3 history, float3 minimum, float3 maximum)
{
    float3 center = 0.5 * (maximum + minimum);
    float3 extents = 0.5 * (maximum - minimum);

    float3 rayDir = color - history;
    float3 rayPos = history - center;

    float3 invDir = rcp(rayDir);
    float3 t0 = (extents - rayPos)  * invDir;
    float3 t1 = -(extents + rayPos) * invDir;

    float AABBIntersection = max(max(min(t0.x, t1.x), min(t0.y, t1.y)), min(t0.z, t1.z));
    return saturate(AABBIntersection);
}

float3 GetClippedHistory(float3 filteredColor, float3 history, float3 minimum, float3 maximum)
{
    #if HISTORY_CLIP_AABB
        return DirectClipToAABB(history, minimum, maximum);
    // #elif HISTORY_CLIP_BLEDN
    //     float historyBlend = DistToAABB(filteredColor, history, minimum, maximum);
    //     return lerp(history, filteredColor, historyBlend);
    #else
        return clamp(history, minimum, maximum);
    #endif
}
  
// TODO: This is not great and sub optimal since it really needs to be in linear and the data is already in perceptive space
// 因为前面已经把值都ToneMapping转换过而且可能变换到了YCoCg空间 这里需要转回来处理 比较浪费 可以考虑预先存储
float3 SharpenColor(NeighbourhoodSamples samples, float3 color, float sharpenStrength)
{
    // TODO 这里的低通滤波部分只是一个均值 锐化效果很一般 如果需要可以换个滤波核
    float3 linearC = color * PerceptualInvWeight(color);
    float3 linearAvg = samples.avgNeighbour * PerceptualInvWeight(samples.avgNeighbour);

    #if YCOCG
        // Rotating back to RGB it leads to better behaviour when sharpening, a better approach needs definitively to be investigated in the future.
        linearC = ConvertToOutputSpace(linearC);
        linearAvg = ConvertToOutputSpace(linearAvg);
        linearC = linearC + (linearC - linearAvg) * sharpenStrength * 3;
        linearC = clamp(linearC, 0, CLAMP_MAX);

        linearC = ConvertToWorkingSpace(linearC);
    #else
        linearC = linearC + (linearC - linearAvg) * sharpenStrength * 3;
        linearC = clamp(linearC, 0, CLAMP_MAX);
    #endif

    float3 outputSharpened = linearC * PerceptualWeight(linearC);
    return outputSharpened;
}

float HistoryContrast(float motionVectorLength, float historyLuma, float minNeighbourLuma, float maxNeighbourLuma)
{
    float lumaContrast = max(maxNeighbourLuma - minNeighbourLuma, 0) / historyLuma;
    float blendFactor = 1 - lerp(_SharpenBlend, 0.2, saturate(motionVectorLength * 20.0)); //0.125;
    return saturate(blendFactor * rcp(1.0 + lumaContrast));
}

float GetBlendFactor(float motionVectorLength, float colorLuma, float historyLuma, float minNeighbourLuma, float maxNeighbourLuma)
{
    // TODO: Investigate factoring in the speed in this computation.
    return HistoryContrast(motionVectorLength, historyLuma, minNeighbourLuma, maxNeighbourLuma);
}


// ------------------------------------------------------------------------------------

struct VaryingsTemporal
{
    float4 positionCS    : SV_POSITION;
    float4 uv            : TEXCOORD0;
};

VaryingsTemporal VertTemporal(Attributes input)
{
    VaryingsTemporal output;
    UNITY_SETUP_INSTANCE_ID(input);

    output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
    output.uv.xy = input.uv;

    float4 ndc = output.positionCS * 0.5f;
    // 注意这里不要管_ProjectionParams.x
    output.uv.zw = ndc.xy + ndc.w;

    return output;
}

// ------------------------------------------------------------------------------------
float4 FragTemporal(VaryingsTemporal input) : SV_Target
{
    // --------------- Get resampled history ---------------
    float depth = SampleSceneDepth(input.uv.xy);
    #if _USEMOTIONVECTOR 
        float2 closest = GetClosestFragment(depth, input.uv.xy);
        float2 motionVector = SAMPLE_TEXTURE2D(_MotionVectorTexture, sampler_LinearClamp, closest).xy;
        motionVector += _Jitter;
        float2 prevUV = input.uv.xy - motionVector;
    #else
        float2 prevUV = GetReprojection(depth, input.uv.zw);
        float2 motionVector = input.uv.xy - prevUV;
    #endif

    float3 history = GetFilteredHistory(prevUV);
    history *= PerceptualWeight(history);

    // --------------- Gather neigbourhood data --------------- 
    float2 uv = input.uv.xy - _Jitter;

    float3 color = GetSourceTexture(uv);
    
    NeighbourhoodSamples samples;
    GatherNeighbourhood(uv, color, samples);

    // --------------- Filter central sample ---------------
    float3 filteredColor = FilterCentralColor(samples);

    // TODO 边缘还是会溢出
    bool offScreen = any(abs(prevUV * 2 - 1) >= 1.0f);
    if (offScreen)
        history = filteredColor;

    // --------------- Get neighbourhood information and clamp history --------------- 
    float colorLuma = GetLuma(filteredColor);
    float historyLuma = GetLuma(history);

    float motionVectorLength = length(motionVector);
    GetNeighbourhoodCorners(samples, historyLuma, colorLuma, float2(_AntiFlickerIntensity, _ContrastForMaxAntiFlicker), motionVectorLength);
    history = GetClippedHistory(filteredColor, history, samples.minNeighbour, samples.maxNeighbour);

    #if SHARPEN_FILTER
        filteredColor = SharpenColor(samples, filteredColor, _SharpenStrength);
    #endif

    // --------------- Compute blend factor for history ---------------
    // TODO
    // float blendFactor = GetBlendFactor(motionVectorLength, colorLuma, historyLuma, GetLuma(samples.minNeighbour), GetLuma(samples.maxNeighbour));
    // blendFactor = max(blendFactor, 0.03);
    // 还是先用老版本混合系数
    float blendFactor = 1 - clamp(lerp(_StationaryBlend, _MotionBlend, motionVectorLength * 6000), _MotionBlend, _StationaryBlend);

    // --------------- Blend to final value and output ---------------
    float3 finalColor = lerp(history, filteredColor, blendFactor);

    finalColor *= PerceptualInvWeight(finalColor);
    finalColor = ConvertToOutputSpace(finalColor);
    finalColor = clamp(finalColor, 0, CLAMP_MAX);

    return float4(finalColor, blendFactor);
}

#endif // TEMPORAL_ANTIALIASING_INCLUDED
