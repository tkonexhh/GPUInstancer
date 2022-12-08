

Shader "Inutan/URP/Legacy/Unlit/Transparent Cutout 双面顶点色-效果加强版" 
{
	Properties 
	{
		[Tex]_MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
		_Cutoff ("Alpha Cutoff", Range(0,1)) = 0.5 
	}

	SubShader 
	{
		// TODO Queue是否需要放在Transparent 需要结合SSR 现在是Material面板上修改的Queue=Transparent
		Tags {"Queue"="AlphaTest" "IgnoreProjector"="True" "RenderType"="TransparentCutout" "RenderPipeline" = "UniversalPipeline"}
		LOD 100 

		Cull Off
		
		Pass {  
			ZWrite On
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog
			#pragma multi_compile_instancing
			
			#define _ALPHATEST_ON 1

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

			CBUFFER_START(UnityPerMaterial)
				float4 	_MainTex_ST;
				half 	_Cutoff;
			CBUFFER_END

			TEXTURE2D(_MainTex);	SAMPLER(sampler_MainTex);

			struct Attributes
			{
				float4 positionOS : POSITION;
				float2 uv : TEXCOORD0;
				half4 color : COLOR;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct Varyings
			{
				float2 uv : TEXCOORD0;
				half4 color : COLOR;
				float fogCoord : TEXCOORD1;
				float4 positionCS : SV_POSITION;

				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
							
			Varyings vert(Attributes input)
			{
				Varyings output = (Varyings)0;

				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);

				VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

				output.positionCS = vertexInput.positionCS;
				output.uv = TRANSFORM_TEX(input.uv, _MainTex);
				output.color = input.color;

				#if defined(_FOG_FRAGMENT)
					output.fogCoord = vertexInput.positionVS.z;
				#else
					output.fogCoord = ComputeFogFactor(vertexInput.positionCS.z);
				#endif

				return output;
			}

			half4 frag(Varyings input) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(input);

				half4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
				half4 color = texColor * input.color;

				AlphaDiscard(color.a, _Cutoff);
		
				#if defined(_FOG_FRAGMENT)
					#if (defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2))
						float viewZ = -input.fogCoord;
						float nearToFarZ = max(viewZ - _ProjectionParams.y, 0);
						half fogFactor = ComputeFogFactorZ0ToFar(nearToFarZ);
					#else
						half fogFactor = 0;
					#endif
				#else
					half fogFactor = input.fogCoord;
				#endif

				color.rgb = MixFog(color.rgb, fogFactor);

				return color;
			}
			ENDHLSL
		}
		
		// TODO
		// 原来的第二个Pass是一个无深度检测的AlphaBlend，本意应该是一个AlphaBlend为了节约overdraw，结合第一个Pass模拟一个early-Z的目的
		// 实际上后续的使用者，并没有按照AlphaBlend的效果去作图，URP不支持双Pass，所以先不考虑了，有需求额外提供
	}
    CustomEditor "Scarecrow.SimpleShaderGUI"
}
