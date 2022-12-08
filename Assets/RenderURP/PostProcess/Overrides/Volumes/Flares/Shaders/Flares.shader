

Shader "Hidden/Inutan/URP/PostProcessing/Flares"
{
    HLSLINCLUDE
        #include "Flares.hlsl"
    ENDHLSL

    SubShader
    {
        Tags{ "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        ZTest Always ZWrite Off Cull Off

        Pass
        {
            HLSLPROGRAM
                #pragma multi_compile_local_fragment _ CALCULATE_IN_GAMMASPACE

                #pragma vertex FullscreenVert
                #pragma fragment FragFlares
            ENDHLSL
        }
    }
}
