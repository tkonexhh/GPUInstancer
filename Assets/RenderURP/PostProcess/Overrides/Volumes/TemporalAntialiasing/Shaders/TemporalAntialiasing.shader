

Shader "Hidden/Inutan/URP/PostProcessing/TemporalAntialiasing"
{
    HLSLINCLUDE
        #include "TemporalAntialiasing.hlsl"
    ENDHLSL

    SubShader
    {
        Tags{ "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        ZTest Always ZWrite Off Cull Off

        Pass
        {
            Name "TemporalAntialiasing"

            HLSLPROGRAM
                #pragma multi_compile_local_fragment LOW_QUALITY HIGH_QUALITY MEDIUM_QUALITY
                #pragma multi_compile_local_fragment _ _USEMOTIONVECTOR
                #pragma multi_compile_local_fragment _ _USETONEMAPPING
                #pragma multi_compile_local_fragment _ _USEBICUBIC5TAP

                #pragma vertex VertTemporal
                #pragma fragment FragTemporal
            ENDHLSL
        }
    }
}
