Shader "Inutan/URP/Scene/Sky/Cloud"
{
	Properties {}

	SubShader
	{
		Tags
		{
			"Queue"="Geometry-1"
			"RenderType"="Transparent"
			"IgnoreProjector"="True"
			"RenderPipeline" = "UniversalPipeline"
		}

		Pass
		{
            Name "Cloud"
			
			ZWrite Off
			Blend SrcAlpha OneMinusSrcAlpha

			HLSLPROGRAM
			#pragma target 4.0
			//--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

			#pragma vertex CloudVertex
			#pragma fragment CloudFragment

			#include "Library/CloudCore.hlsl"

			ENDHLSL
		}
	}

	Fallback Off
}
