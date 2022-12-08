Shader "Inutan/URP/Scene/Sky/Sky"
{
	Properties {}

	SubShader
	{
		Tags
		{
			"Queue"="Background"
			"RenderType"="Background"
			"IgnoreProjector"="True"
			"RenderPipeline" = "UniversalPipeline"
		}

		Pass
		{
            Name "Sky"

			ZWrite On
			Blend One Zero

			HLSLPROGRAM
            #pragma target 4.0
			//--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

			#pragma vertex SkyVertex
			#pragma fragment SkyFragment

			#include "Library/SkyCore.hlsl"
			ENDHLSL
		}
	}

	Fallback Off
}
