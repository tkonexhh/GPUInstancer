

Shader "Hidden/Inutan/URP/PostProcessing/ScreenSpaceReflection"
{

    HLSLINCLUDE
        #include "ScreenSpaceReflection.hlsl"
    ENDHLSL

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}
		ZTest Always ZWrite Off Cull Off

        Pass
        {
            Name "ScreenSpaceReflection Test"

            HLSLPROGRAM
                #pragma multi_compile_local _ _OLD_METHOD

                #pragma vertex FullscreenVert
                #pragma fragment FragTest
            ENDHLSL
        }

        Pass
        {
            Name "ScreenSpaceReflection Resolve"

            HLSLPROGRAM
                #pragma vertex FullscreenVert
                #pragma fragment FragResolve
            ENDHLSL
        }

        Pass
        {
            Name "ScreenSpaceReflection Reproject"

            HLSLPROGRAM
                #pragma vertex FullscreenVert
                #pragma fragment FragReproject
            ENDHLSL
        }

        Pass
        {
            Name "ScreenSpaceReflection Composite"

            HLSLPROGRAM
                #pragma multi_compile_local _ DEBUG_SCREEN_SPACE_REFLECTION DEBUG_INDIRECT_SPECULAR

                #pragma vertex FullscreenVert
                #pragma fragment FragComposite
            ENDHLSL
        }

       
    }
}
