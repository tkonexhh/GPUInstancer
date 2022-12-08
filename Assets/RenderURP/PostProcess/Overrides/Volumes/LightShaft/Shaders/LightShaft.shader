

Shader "Hidden/Inutan/URP/PostProcessing/LightShaft"
{
    HLSLINCLUDE
        #include "LightShaft.hlsl"
    ENDHLSL

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}
		ZTest Always ZWrite Off Cull Off

        Pass
        {
            HLSLPROGRAM
                #pragma multi_compile_local _ DEBUG_PREFILTER DEBUG_LIGHTSHAFTONLY

                #pragma vertex FullscreenVert
                #pragma fragment FragPrefilter
            ENDHLSL
        }

        Pass
        {
            HLSLPROGRAM
                #pragma multi_compile_local QUALITY_LOW QUALITY_MEDIUM QUALITY_HIGH

                #pragma vertex FullscreenVert
                #pragma fragment FragRadialBlur
            ENDHLSL
        }

        Pass
        {
            HLSLPROGRAM
                #pragma multi_compile_local _ DEBUG_PREFILTER DEBUG_LIGHTSHAFTONLY

                #pragma vertex FullscreenVert
                #pragma fragment FragComposite
            ENDHLSL
        }
    }
}
