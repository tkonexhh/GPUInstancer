

Shader "Hidden/Inutan/URP/PostProcessing/BloomUnreal"
{

    HLSLINCLUDE
        #include "BloomUnreal.hlsl"
    ENDHLSL

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}
		ZTest Always ZWrite Off Cull Off

        Pass
        {
            Name "BloomUnreal DownSample"

            HLSLPROGRAM
                #pragma multi_compile _ USE_DOWNSAMPLE_FILTER

                #pragma vertex FullscreenVert
                #pragma fragment FragDownSample
            ENDHLSL
        }

        Pass
        {
            Name "BloomUnreal Prefilter"

            HLSLPROGRAM
                #pragma vertex FullscreenVert
                #pragma fragment FragPrefilter
            ENDHLSL
        }

        Pass
        {
            Name "BloomUnreal Combine"

            HLSLPROGRAM
                #pragma vertex FullscreenVert
                #pragma fragment FragCombine
            ENDHLSL
        }

        Pass
        {
            Name "BloomUnreal Blur"

            HLSLPROGRAM
                #pragma multi_compile _ USE_COMBINE_ADDITIVE

                #pragma vertex FullscreenVert
                #pragma fragment FragBlur
            ENDHLSL
        }

       

    }
}
