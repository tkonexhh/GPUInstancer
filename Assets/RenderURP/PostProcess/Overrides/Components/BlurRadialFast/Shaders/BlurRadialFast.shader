

Shader "Hidden/Inutan/URP/PostProcessing/BlurRadialFast"
{
    HLSLINCLUDE
        #include "BlurRadialFast.hlsl"
    ENDHLSL

    SubShader
    {
        Tags{ "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        ZTest Always ZWrite Off Cull Off

        Pass
        {
            HLSLPROGRAM
                #pragma vertex FullscreenVert
                #pragma fragment FragBlurRadialFast
            ENDHLSL
        }
    }
}
