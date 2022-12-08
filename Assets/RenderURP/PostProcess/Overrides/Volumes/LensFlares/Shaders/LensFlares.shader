

Shader "Hidden/Inutan/URP/PostProcessing/LensFlares"
{

    HLSLINCLUDE
        #include "LensFlares.hlsl"
    ENDHLSL

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}
		ZTest Always ZWrite Off Cull Off

        Pass
        {
            Name "LensFlares Prefilter"

            HLSLPROGRAM
                #pragma vertex FullscreenVert
                #pragma fragment FragPrefilter
            ENDHLSL
        }

        Pass
        {
            Name "LensFlares Chromatic"

            HLSLPROGRAM
                #pragma vertex FullscreenVert
                #pragma fragment FragChromatic
            ENDHLSL
        }

        Pass
        {
            Name "LensFlares Ghosts"

            HLSLPROGRAM
                #pragma vertex FullscreenVert
                #pragma fragment FragGhosts
            ENDHLSL
        }

        Pass
        {
            Name "LensFlares Composite"

            HLSLPROGRAM
                #pragma multi_compile_local _ DEBUG_LENSFLARES

                #pragma vertex FullscreenVert
                #pragma fragment FragComposite
            ENDHLSL
        }
    }
}
