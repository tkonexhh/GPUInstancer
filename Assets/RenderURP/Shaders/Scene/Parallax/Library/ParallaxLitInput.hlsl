#ifndef PARALLAXLIT_INPUT_INCLUDED
    #define PARALLAXLIT_INPUT_INCLUDED

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
    //#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ParallaxMapping.hlsl"
    // DBuffer.hlsl里面有SurfaceData.hlsl, 定义了SurfaceData结构体
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"

    #define _NORMALMAP
    #define _OCCLUSIONMAP
    #ifdef _F_EMISSION_ON
        #define _EMISSION 1
    #endif
    // 由于define顺序， _PARALLAXMAP在Input.hlsl和GBufferPass.hlsl都要声明一次
    #ifdef _F_PARALLAX_ON
        #define _PARALLAXMAP 1
    #endif

    CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        float4 _SparklesNoiseMap_ST;
        half _Cutoff;
        half _Parallax;
        half _ParallaxTilling;
        half4 _Color;
        half4 _EmissionColor;
        float _SparklesSpeed;
        half4 _SparklesColor;
        float _SparklesCameraSpeed;
        half _Smoothness;
        half _Metallic;
        half _BumpScale;
        half _OcclusionStrength;
    CBUFFER_END

    #ifdef UNITY_DOTS_INSTANCING_ENABLED
        UNITY_DOTS_INSTANCING_START(MaterialPropertyMetadata)

        UNITY_DOTS_INSTANCED_PROP(float4, _Color)
        UNITY_DOTS_INSTANCED_PROP(float4, _EmissionColor)
        UNITY_DOTS_INSTANCED_PROP(float , _SparklesSpeed)
        UNITY_DOTS_INSTANCED_PROP(float4, _SparklesColor)
        UNITY_DOTS_INSTANCED_PROP(float , _SparklesCameraSpeed)
        UNITY_DOTS_INSTANCED_PROP(float , _Cutoff)
        UNITY_DOTS_INSTANCED_PROP(float , _Parallax)
        UNITY_DOTS_INSTANCED_PROP(float , _ParallaxTilling)
        UNITY_DOTS_INSTANCED_PROP(float , _Smoothness)
        UNITY_DOTS_INSTANCED_PROP(float , _Metallic)
        UNITY_DOTS_INSTANCED_PROP(float , _BumpScale)
        UNITY_DOTS_INSTANCED_PROP(float , _OcclusionStrength)

        UNITY_DOTS_INSTANCING_END(MaterialPropertyMetadata)

        #define _Color                  UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float4 , Metadata_Color)
        #define _EmissionColor          UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float4 , Metadata_EmissionColor)
        #define _SparklesSpeed          UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float  , Metadata_SparklesSpeed)
        #define _SparklesColor          UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float4 , Metadata_SparklesColor)
        #define _SparklesCameraSpeed    UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float  , Metadata_SparklesCameraSpeed)
        #define _Cutoff                 UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float  , Metadata_Cutoff)
        #define _Parallax               UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float  , Metadata_Parallax)
        #define _ParallaxTilling        UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float  , Metadata_ParallaxTilling)
        #define _Smoothness             UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float  , Metadata_Smoothness)
        #define _Metallic               UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float  , Metadata_Metallic)
        #define _BumpScale              UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float  , Metadata_BumpScale)
        #define _OcclusionStrength      UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float  , Metadata_OcclusionStrength)
    #endif

    // 全局参数
    half2 _GLOBAL_CAMERAFADE_PARAMS;

    TEXTURE2D(_MainTex);                SAMPLER(sampler_MainTex);
    TEXTURE2D(_MetallicGlossMap);       SAMPLER(sampler_MetallicGlossMap);
    TEXTURE2D(_BumpMap);                SAMPLER(sampler_BumpMap);
    TEXTURE2D(_ParallaxMap);            SAMPLER(sampler_ParallaxMap);
    TEXTURE2D(_EmissionMap);            SAMPLER(sampler_EmissionMap);
    TEXTURE2D(_OcclusionMap);           SAMPLER(sampler_OcclusionMap);
    #if defined(_F_SPARKLES_ON) && defined(_EMISSION)
        TEXTURE2D(_SparklesNoiseMap);       SAMPLER(sampler_SparklesNoiseMap);
    #endif


    half4 SampleAlbedoAlpha(float2 uv)
    {
        return half4(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv));
    }

    half Alpha(half albedoAlpha, half4 color, half cutoff)
    {
        half alpha = albedoAlpha * color.a;

        #if defined(_USECUTOFF_ON)
            clip(alpha - cutoff);
        #endif

        return alpha;
    }

    #define SAMPLE_METALLICSPECULAR(uv) SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, uv)

    // 简化，只使用金属流程
    half4 SampleMetallicSpecGloss(float2 uv)
    {
        half4 specGloss;
        specGloss = half4(SAMPLE_METALLICSPECULAR(uv));
        specGloss.rgb *= _Metallic;
        specGloss.a = _Smoothness;
        return specGloss;
    }


    half3 SampleNormal(float2 uv, half scale = half(1.0))
    {
        #ifdef _NORMALMAP
            half4 n = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uv);
            #if BUMP_SCALE_NOT_SUPPORTED
                return UnpackNormal(n);
            #else
                return UnpackNormalScale(n, scale);
            #endif
        #else
            return half3(0.0h, 0.0h, 1.0h);
        #endif
    }

    half SampleOcclusion(float2 uv)
    {
        #ifdef _OCCLUSIONMAP
            // TODO: Controls things like these by exposing SHADER_QUALITY levels (low, medium, high)
            #if defined(SHADER_API_GLES)
                return SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
            #else
                half occ = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
                return LerpWhiteTo(occ, _OcclusionStrength);
            #endif
        #else
            return half(1.0);
        #endif
    }

    #ifdef _PARALLAXTYPE_ITERATIONS4
        float2 ParallaxMapping4Iterations(TEXTURE2D_PARAM(heightMap, sampler_heightMap), half3 viewDirTS, half scale, float2 uv)
        {
            half h = SAMPLE_TEXTURE2D(heightMap, sampler_heightMap, uv).r;
            float2 uvTilling = uv * _ParallaxTilling;
            float2 Offset_Iteration1 = ( (h - 1.0) * viewDirTS.xy * _Parallax ) + uvTilling;
            float2 Offset_Iteration2 = ( ( SAMPLE_TEXTURE2D(heightMap, sampler_heightMap, Offset_Iteration1).r - 1 ) * viewDirTS.xy * _Parallax ) + Offset_Iteration1;
            float2 Offset_Iteration3 = ( ( SAMPLE_TEXTURE2D(heightMap, sampler_heightMap, Offset_Iteration2).r - 1 ) * viewDirTS.xy * _Parallax ) + Offset_Iteration2;
            float2 Offset_Iteration4 = ( ( SAMPLE_TEXTURE2D(heightMap, sampler_heightMap, Offset_Iteration3).r - 1 ) * viewDirTS.xy * _Parallax ) + Offset_Iteration3;
            return Offset_Iteration4;
        }
    #endif

    void ApplyPerPixelDisplacement(half3 viewDirTS, inout float2 uv)
    {
        #if defined(_PARALLAXMAP)
            #ifdef _PARALLAXTYPE_URP
                uv += ParallaxMapping(TEXTURE2D_ARGS(_ParallaxMap, sampler_ParallaxMap), viewDirTS, _Parallax, uv);
            #else
                uv = ParallaxMapping4Iterations(TEXTURE2D_ARGS(_ParallaxMap, sampler_ParallaxMap), viewDirTS, _Parallax, uv);
            #endif
        #endif
    }

    half3 SampleEmission(float2 uv)
    {
        #ifndef _EMISSION
            return 0;
        #else
            half4 emissionTex = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, uv);
            half3 emissionResult = emissionTex.rgb * emissionTex.a * _EmissionColor.rgb;
            return emissionResult;
        #endif
    }

    #ifdef _F_SPARKLES_ON
    half3 SampleSparkles(float2 uv, half3 viewDirTS, InputData inputData)
    {
        float2 uvSparklesMap = uv * _SparklesNoiseMap_ST.xy + _SparklesNoiseMap_ST.zw;
        int sampleBias = -1;
        float noise1 = SAMPLE_TEXTURE2D_BIAS(_SparklesNoiseMap, sampler_SparklesNoiseMap, uvSparklesMap + float2 (0.3, _Time.x * _SparklesSpeed) + viewDirTS.xy * _SparklesCameraSpeed, sampleBias).r;
        float noise2 = SAMPLE_TEXTURE2D_BIAS(_SparklesNoiseMap, sampler_SparklesNoiseMap, uvSparklesMap * 1.4 + float2 (_Time.x * _SparklesSpeed, 0.3), sampleBias).r;
        float3 sparkle = pow (noise1 * noise2 * 2, 10.0) * _SparklesColor.rgb;
        return sparkle * saturate(dot(inputData.normalWS, inputData.viewDirectionWS));
    }
    #endif

    inline void InitializeStandardLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)
    {
        half4 albedoAlpha = SampleAlbedoAlpha(uv);
        outSurfaceData.alpha = Alpha(albedoAlpha.a, _Color, _Cutoff);
        outSurfaceData.albedo = albedoAlpha.rgb * _Color.rgb;

        half4 specGloss = SampleMetallicSpecGloss(uv);
        outSurfaceData.metallic = specGloss.r;
        outSurfaceData.specular = half3(0.0, 0.0, 0.0);
        outSurfaceData.smoothness = specGloss.a;

        outSurfaceData.normalTS = SampleNormal(uv, _BumpScale);
        outSurfaceData.occlusion = SampleOcclusion(uv);
        outSurfaceData.emission = SampleEmission(uv);

        outSurfaceData.clearCoatMask       = half(0.0);
        outSurfaceData.clearCoatSmoothness = half(0.0);
    }


#endif