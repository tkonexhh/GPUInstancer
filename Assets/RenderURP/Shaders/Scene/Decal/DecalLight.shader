
Shader "Inutan/URP/Scene/Decal/DecalLight 贴花光照"
{
	Properties
	{
        [Tex(_Color)] _MainTex("基础贴图", 2D) = "white" {}
        [HideInInspector] _Color("颜色", Color) = (1, 1, 1, 1)
        [Gamma]_Intensity("亮度", Range(1, 20)) = 10
	}

	SubShader
	{
		Tags {"RenderType" = "Transparent" "Queue" = "Transparent+100" "RenderPipeline" = "UniversalPipeline"}

		Pass
		{
            Name "DecalLight"
			Tags{"LightMode" = "AfterTransparentPass"}

            Blend DstColor OneMinusSrcAlpha

			HLSLPROGRAM
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

			//--------------------------------------
            struct Attributes
			{
				float4 positionOS 	: POSITION;
			};

			struct Varyings
			{
				float4 positionNDC 	: TEXCOORD1;
				float3 rayVS 		: TEXCOORD2;
				float4 positionCS 	: SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
			};

  			CBUFFER_START(UnityPerMaterial)
                half4   _Color;
                half    _Intensity;
            CBUFFER_END

			TEXTURE2D(_MainTex);					SAMPLER(sampler_MainTex);
			TEXTURE2D_X_FLOAT(_CameraDepthTexture); SAMPLER(sampler_CameraDepthTexture);

			// -----------------------------------------------------------------------------
            // Vertex
            Varyings vert (Attributes input)
			{
				Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

                output.positionCS = vertexInput.positionCS;
				output.positionNDC = vertexInput.positionNDC;
			    output.rayVS = TransformWorldToView(TransformObjectToWorld(input.positionOS.xyz)) * float3(-1, -1, 1);

				return output;
			}

			// -----------------------------------------------------------------------------
            // Fragment
            half4 frag(Varyings input) : SV_Target
			{
				float2 screenUV = input.positionNDC.xy * rcp(input.positionNDC.w);

				float rawDepth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV).r;
    			float sceneZ = (unity_OrthoParams.w == 0) ? LinearEyeDepth(rawDepth, _ZBufferParams) : LinearDepthToEyeDepth(rawDepth);
				float3 surfacePositionVS = input.rayVS * sceneZ / input.rayVS.z;

				float4 surfacePositionWS = mul(unity_CameraToWorld, float4(surfacePositionVS, 1));
				float3 surfacePositionOS = TransformWorldToObject(surfacePositionWS.xyz);

				// 剔除掉在立方体外面的内容
				clip(float3(0.5, 0.5, 0.5) - abs(surfacePositionOS));

				// 使用物体空间坐标的xy坐标作为采样uv 方便进行形变调整
				float2 uv = surfacePositionOS.xy + 0.5;
				half4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
				// 这两种混合方式都可以
                // float4(color) 						-> SrcColor · DstColor + DstColor · OneMinusSrcAlpha
                // float4(color.rgb + (1 - color.a), 1) -> DstColor Zero

                color.rgb *= _Color.rgb * _Intensity;
				return color;
			}
			ENDHLSL
		}
	}
    CustomEditor "Scarecrow.SimpleShaderGUI"
}