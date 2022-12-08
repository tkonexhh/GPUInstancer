Shader "Inutan/URP/Scene/Sky/Stars"
{
	Properties {}

	SubShader
	{
		Tags
		{
			"Queue"="Background+20"
			"RenderType"="Background"
			"IgnoreProjector"="True"
			"RenderPipeline" = "UniversalPipeline"
		}

		Pass
		{
            Name "Stars"

			ZWrite Off
			Blend One One

			HLSLPROGRAM
			#pragma target 4.0
			//--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

			#pragma vertex StarsVertex
			#pragma fragment StarsFragment

			#include "Library/StarsCore.hlsl"

			ENDHLSL
		}
	}

	Fallback Off
}
