Shader "Hidden/PostProcessing/Inutan/Bloom"
{
    HLSLINCLUDE
        #pragma multi_compile __ BLOOM BLOOM_LOW
        #pragma multi_compile __ MASKEDBLOOM_MIXED MASKEDBLOOM_MASK MASKEDBLOOM_MASKEDBLOOM MASKEDBLOOM_ORIGINBLOOM

        #include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"
        #include "Packages/com.unity.postprocessing/PostProcessing/Shaders/Colors.hlsl"
        #include "Packages/com.unity.postprocessing/PostProcessing/Shaders/Sampling.hlsl"

        TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
        TEXTURE2D_SAMPLER2D(_BloomTex, sampler_BloomTex);
        TEXTURE2D_SAMPLER2D(_BloomMaskTex, sampler_BloomMaskTex);
        TEXTURE2D_SAMPLER2D(_BloomMasked, sampler_BloomMasked);

        float4 _MainTex_TexelSize;
        float  _SampleScale;
        float4 _ColorIntensity;
        float4 _Threshold; // x: threshold value (linear), y: threshold - knee, z: knee * 2, w: 0.25 / knee
        float4 _Params; // x: clamp, yzw: unused

        float4 _BloomTex_TexelSize;
        half3 _Bloom_Settings; // x: sampleScale, y: intensity
        half3 _Bloom_Color;
        float _MaskedBloomIntensity;

        // static const half3 REL_LUMA = half3(0.2126h, 0.7152h, 0.0722h);
        // #define EPSILON 1.0e-4
        
        // inline half3 LumaScale(half3 color, half scale)
        // {
        //     return color * lerp(0.909, 1.0 / (1.0 + REL_LUMA), scale);
        // }

        // inline half3 LuminanceThreshold(half3 c, half2 threshold, half lumaScale, float a)
        // {		
        //     //brightness is defined by the relative luminance combined with the brightest color part to make it nicer to deal with the shader for artists
        //     //based on unity builtin brightpass thresholding
        //     //if any color part exceeds a value of 10 (builtin HDR max) then clamp it as a normalized vector to keep the color balance
        //     c = clamp(c, 0, normalize(c) * threshold.y);
        //     c = LumaScale(c, lumaScale);
        //     //half brightness = lerp(max(dot(c.r, REL_LUMA.r), max(dot(c.g, REL_LUMA.g), dot(c.b, REL_LUMA.b))), max(c.r, max(c.g, c.b)), REL_LUMA);
        //     //picking just the brightest color part isn´t physically correct at all, but gives nices artistic results
        //     half brightness = max(c.r, max(c.g, c.b));
        //     // brightness = max(brightness, a);
        //     //forcing a hard threshold to only extract really bright parts
        //     half sP = EPSILON;//threshold.x * 0.0 + EPSILON;
        //     return max(0, c * max(pow(clamp(brightness - threshold.x + sP, 0, 2 * sP), 2) / (4 * sP + EPSILON), brightness - threshold.x) / max(brightness, EPSILON));
        // }

        // inline half3 Blooming(half3 color, half blooming)
        // {
        //     return lerp(color.rgb, (color.rgb+sqrt(color.rgb))/2, blooming);
        // }

        half4 _QuadraticThreshold(half4 color, half threshold, half3 curve)
        {
            // half TotalLuminance = dot(color.rgb, float3(0.3, 0.59, 0.11));
	        // half BloomLuminance = TotalLuminance - threshold;
        	// half BloomAmount = saturate(BloomLuminance * 0.5f);

	        // return float4(BloomAmount * color.rgb, 1);

            // float3 c = LuminanceThreshold(color.rgb, float2(threshold, 10), 0, color.a);
            // return float4(c, max(1.1, color.a) - 1.1);

            // Pixel brightness
            half br = Max3(color.r, color.g, color.b);

            // Under-threshold part: quadratic curve
            half rq = clamp(br - curve.x, 0.0, curve.y);
            rq = curve.z * rq * rq;

            // Combine and apply the brightness response curve.
            color *= max(rq, br - threshold) / max(br, EPSILON);

            return color;
        }
        // ----------------------------------------------------------------------------------------
        // Prefilter

        half4 Prefilter(half4 color, float2 uv)
        {
            #if MASKEDBLOOM_MIXED
                half4 mask = SAMPLE_TEXTURE2D(_BloomMaskTex, sampler_BloomMaskTex, uv);
                color *= 1 - mask;
            #endif

            color = min(_Params.x, color); // clamp to max
            color = _QuadraticThreshold(color, _Threshold.x, _Threshold.yzw);
            return color;
        }


        half4 FragPrefilter13(VaryingsDefault i) : SV_Target
        {
            half4 color = DownsampleBox13Tap(TEXTURE2D_PARAM(_MainTex, sampler_MainTex), i.texcoord, UnityStereoAdjustedTexelSize(_MainTex_TexelSize).xy);
            return Prefilter(SafeHDR(color), i.texcoord);
        }

        half4 FragPrefilter4(VaryingsDefault i) : SV_Target
        {
            half4 color = DownsampleBox4Tap(TEXTURE2D_PARAM(_MainTex, sampler_MainTex), i.texcoord, UnityStereoAdjustedTexelSize(_MainTex_TexelSize).xy);
            return Prefilter(SafeHDR(color), i.texcoord);
        }

        // ----------------------------------------------------------------------------------------
        // Downsample

        half4 FragDownsample13(VaryingsDefault i) : SV_Target
        {
            half4 color = DownsampleBox13Tap(TEXTURE2D_PARAM(_MainTex, sampler_MainTex), i.texcoord, UnityStereoAdjustedTexelSize(_MainTex_TexelSize).xy);
            return color;
        }

        half4 FragDownsample4(VaryingsDefault i) : SV_Target
        {
            half4 color = DownsampleBox4Tap(TEXTURE2D_PARAM(_MainTex, sampler_MainTex), i.texcoord, UnityStereoAdjustedTexelSize(_MainTex_TexelSize).xy);
            return color;
        }

        // ----------------------------------------------------------------------------------------
        // Upsample & combine

        half4 Combine(half4 bloom, float2 uv)
        {
            half4 color = SAMPLE_TEXTURE2D(_BloomTex, sampler_BloomTex, uv);
            return bloom + color;
        }

        half4 FragUpsampleTent(VaryingsDefault i) : SV_Target
        {
            half4 bloom = UpsampleTent(TEXTURE2D_PARAM(_MainTex, sampler_MainTex), i.texcoord, UnityStereoAdjustedTexelSize(_MainTex_TexelSize).xy, _SampleScale);
            return Combine(bloom, i.texcoordStereo);
        }

        half4 FragUpsampleBox(VaryingsDefault i) : SV_Target
        {
            half4 bloom = UpsampleBox(TEXTURE2D_PARAM(_MainTex, sampler_MainTex), i.texcoord, UnityStereoAdjustedTexelSize(_MainTex_TexelSize).xy, _SampleScale);
            return Combine(bloom, i.texcoordStereo);
        }


        half4 FragFinal(VaryingsDefault i) : SV_Target
        {
            half4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoordStereo);

            #if BLOOM
                half4 bloom = UpsampleTent(TEXTURE2D_PARAM(_BloomTex, sampler_BloomTex), i.texcoord, 
                _BloomTex_TexelSize.xy, _Bloom_Settings.x);
            #else // if BLOOM_LOW
                half4 bloom = UpsampleBox(TEXTURE2D_PARAM(_BloomTex, sampler_BloomTex), i.texcoord, 
                _BloomTex_TexelSize.xy, _Bloom_Settings.x);
            #endif

            // Additive bloom (artist friendly)
            bloom *= _Bloom_Settings.y;
            color.rgb += bloom.rgb * _Bloom_Color.rgb;

            half4 bloomMasked = SAMPLE_TEXTURE2D(_BloomMasked, sampler_BloomMasked, i.texcoordStereo);
            bloomMasked *= _MaskedBloomIntensity;

            #if MASKEDBLOOM_MIXED
                color += bloomMasked;
            #elif MASKEDBLOOM_MASK
                return SAMPLE_TEXTURE2D(_BloomMaskTex, sampler_BloomMaskTex, i.texcoordStereo);
            #elif MASKEDBLOOM_MASKEDBLOOM
                return bloomMasked;
            #elif MASKEDBLOOM_ORIGINBLOOM
                return bloom;
            #endif

            return color;
        }

        // ----------------------------------------------------------------------------------------
        // Debug overlays

        half4 FragDebugOverlayThreshold(VaryingsDefault i) : SV_Target
        {
            half4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoordStereo);
            return half4(Prefilter(SafeHDR(color), i.texcoord).rgb, 1.0);
        }

        half4 FragDebugOverlayTent(VaryingsDefault i) : SV_Target
        {
            half4 bloom = UpsampleTent(TEXTURE2D_PARAM(_MainTex, sampler_MainTex), i.texcoord, UnityStereoAdjustedTexelSize(_MainTex_TexelSize).xy, _SampleScale);
            return half4(bloom.rgb * _ColorIntensity.w * _ColorIntensity.rgb, 1.0);
        }

        half4 FragDebugOverlayBox(VaryingsDefault i) : SV_Target
        {
            half4 bloom = UpsampleBox(TEXTURE2D_PARAM(_MainTex, sampler_MainTex), i.texcoord, UnityStereoAdjustedTexelSize(_MainTex_TexelSize).xy, _SampleScale);
            return half4(bloom.rgb * _ColorIntensity.w * _ColorIntensity.rgb, 1.0);
        }

    ENDHLSL

    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        // 0: Prefilter 13 taps
        Pass
        {
            HLSLPROGRAM

                #pragma vertex VertDefault
                #pragma fragment FragPrefilter13

            ENDHLSL
        }

        // 1: Prefilter 4 taps
        Pass
        {
            HLSLPROGRAM

                #pragma vertex VertDefault
                #pragma fragment FragPrefilter4

            ENDHLSL
        }

        // 2: Downsample 13 taps
        Pass
        {
            HLSLPROGRAM

                #pragma vertex VertDefault
                #pragma fragment FragDownsample13

            ENDHLSL
        }

        // 3: Downsample 4 taps
        Pass
        {
            HLSLPROGRAM

                #pragma vertex VertDefault
                #pragma fragment FragDownsample4

            ENDHLSL
        }

        // 4: Upsample tent filter
        Pass
        {
            HLSLPROGRAM

                #pragma vertex VertDefault
                #pragma fragment FragUpsampleTent

            ENDHLSL
        }

        // 5: Upsample box filter
        Pass
        {
            HLSLPROGRAM

                #pragma vertex VertDefault
                #pragma fragment FragUpsampleBox

            ENDHLSL
        }

        // 6: Debug overlay (threshold)
        Pass
        {
            HLSLPROGRAM

                #pragma vertex VertDefault
                #pragma fragment FragDebugOverlayThreshold

            ENDHLSL
        }

        // 7: Debug overlay (tent filter)
        Pass
        {
            HLSLPROGRAM

                #pragma vertex VertDefault
                #pragma fragment FragDebugOverlayTent

            ENDHLSL
        }

        // 8: Debug overlay (box filter)
        Pass
        {
            HLSLPROGRAM

                #pragma vertex VertDefault
                #pragma fragment FragDebugOverlayBox

            ENDHLSL
        }
        // 9: final 
        Pass
        {
            Stencil
            {
                Ref 12
                Comp Equal
            }
            HLSLPROGRAM
                #pragma vertex VertDefault
                #pragma fragment FragFinal
            ENDHLSL
        }
    }
}
