
Shader "Inutan/URP/Effect/AODecals/SphereAO"
{
	Properties
	{
		[Foldout(1, 1, 0, 1)] _F_Basic("Basic_Foldout", float) = 1 // 0表示不可以编辑
        _Color("颜色", Color) = (0, 0, 0, 1)
		[Enum_Switch(ours, iq_fast, iq_quality)] _AOType("AO类型", float) = 0
		_Radius("半径", Range(0.01,5)) = 1
		[Vector3(1)]_SpherePos("球心位置", Vector) = (0,0,0,0)
		_Intensity("强度", Range(0, 5)) = 1
		[Toggle_Switch] _DebugShowSphere("(调试用) 显示虚拟球体", float) = 0
		[Foldout_Out(1)] _F_Basic_Out("F_Basic_Out_Foldout", float) = 1
	}

	SubShader
	{
		Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True"}

		Pass
		{
            Name "SphereAO"
			Tags{"LightMode" = "AODecals"}

            // Blend Zero SrcColor
			Blend SrcAlpha OneMinusSrcAlpha
			ZWrite Off

			HLSLPROGRAM
			//──────────────────────────────────────────────────────────────────────────────────────────────────────
            // GPU Instancing
            #pragma multi_compile_instancing

			//──────────────────────────────────────────────────────────────────────────────────────────────────────
			// 定义顶点和片元着色器
            #pragma vertex vert
            #pragma fragment frag

			//──────────────────────────────────────────────────────────────────────────────────────────────────────
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"

			//──────────────────────────────────────────────────────────────────────────────────────────────────────
            // Material Keywords
            #pragma shader_feature_local _DEBUGSHOWSPHERE_ON
			#pragma shader_feature_local _AOTYPE_OURS _AOTYPE_IQ_FAST _AOTYPE_IQ_QUALITY



			//──────────────────────────────────────────────────────────────────────────────────────────────────────
            struct Attributes
			{
				float4 positionOS 	: POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct Varyings
			{
				float4 positionNDC 	: TEXCOORD1;
				float3 rayVS 		: TEXCOORD2;
				float3 spherePosWS  : TEXCOORD3;
			#ifdef _DEBUGSHOWSPHERE_ON
				float3 positionWS   : TEXCOORD4;
			#endif
				float4 positionCS 	: SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			//──────────────────────────────────────────────────────────────────────────────────────────────────────
  			CBUFFER_START(UnityPerMaterial)
                half4   _Color;
				float   _Radius;
				float3  _SpherePos;
				float 	_Intensity;
            CBUFFER_END

			TEXTURE2D_X_FLOAT(_CameraDepthTexture); SAMPLER(sampler_CameraDepthTexture);
			TEXTURE2D_X_HALF(_GBuffer2); 		SamplerState my_point_clamp_sampler;

			//──────────────────────────────────────────────────────────────────────────────────────────────────────
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

			#ifdef _DEBUGSHOWSPHERE_ON
				output.positionWS = vertexInput.positionWS;
			#endif
				output.spherePosWS = TransformObjectToWorld(_SpherePos.xyz);

				return output;
			}

			//──────────────────────────────────────────────────────────────────────────────────────────────────────
			// Sphere occlusion
			float sphOcclusion(float3 pos, float3 nor, float4 sph )
			{
				float3  di = sph.xyz - pos;
				float l  = length(di);
				float nl = dot(nor,di/l);
				float h  = l/sph.w;
				float h2 = h*h;
				float k2 = 1.0 - h2*nl*nl;

				// above/below horizon
				// EXACT: Quilez - https://iquilezles.org/articles/sphereao
				float res = max(0.0,nl)/h2;

				// intersecting horizon
				if( k2 > 0.0 )
				{
					#if _AOTYPE_IQ_QUALITY
						// EXACT : Lagarde/de Rousiers - https://seblagarde.files.wordpress.com/2015/07/course_notes_moving_frostbite_to_pbr_v32.pdf
						res = nl*acos(-nl*sqrt( (h2-1.0)/(1.0-nl*nl) )) - sqrt(k2*(h2-1.0));
						res = res/h2 + atan( sqrt(k2/(h2-1.0)));
						res /= 3.141593;
					#else
						// APPROXIMATED : Quilez - https://iquilezles.org/articles/sphereao
						res = (nl*h+1.0)/h2;
						res = 0.33*res*res;
						// res = pow( clamp(0.5*(nl*h+1.0)/h2,0.0,1.0), 1.5 );
					#endif
				}

				return res;
			}

			//──────────────────────────────────────────────────────────────────────────────────────────────────────
		#ifdef _DEBUGSHOWSPHERE_ON
			float sphIntersect(float3 ro, float3 rd, float4 sph )
			{
				float3 oc = ro - sph.xyz;

				float b = dot( oc, rd );
				float c = dot( oc, oc ) - sph.w*sph.w;
				float h = b*b - c;
				if( h<0.0 ) return -1.0;
				return -b - sqrt( h );
			}
		#endif

			//──────────────────────────────────────────────────────────────────────────────────────────────────────
            // Fragment
            half4 frag(Varyings input) : SV_Target
			{
				float2 screenUV = input.positionNDC.xy * rcp(input.positionNDC.w);

				float rawDepth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV);
    			float sceneZ = (unity_OrthoParams.w == 0) ? LinearEyeDepth(rawDepth, _ZBufferParams) : LinearDepthToEyeDepth(rawDepth);
				float3 surfacePositionVS = input.rayVS * sceneZ / input.rayVS.z;

				float4 surfacePositionWS = mul(unity_CameraToWorld, float4(surfacePositionVS, 1));
				float3 sceneNormalWS = normalize(UnpackNormal(SAMPLE_TEXTURE2D_X_LOD(_GBuffer2, my_point_clamp_sampler, screenUV, 0).rgb));
				// decal部分结束。到这里为止就得到了该像素位置对应的世界空间位置和法线

				// 下面的内容主要思路来自https://www.shadertoy.com/view/4djSDy
				float3 spherePos = input.spherePosWS.xyz;
				float4 sph = float4( spherePos, _Radius * 0.5);

				#if _AOTYPE_IQ_FAST
					float occ = sphOcclusion(surfacePositionWS, sceneNormalWS, sph);
				#elif _AOTYPE_IQ_QUALITY
					float occ = sphOcclusion(surfacePositionWS, sceneNormalWS, sph);
				#else
					// 我们用的算法。IQ的算法会导致球体内部没有AO
					float3 dir1 = surfacePositionWS - spherePos;
					float NdotL = dot(-normalize(dir1), sceneNormalWS) * 0.5 + 0.5;
					float falloff = 1.0 - length(dir1) / (_Radius * 1.4);
					falloff = saturate(falloff);
					float occ = falloff * falloff * NdotL;
					occ *= 2.2;
				#endif

				float finalAlpha = _Color.a * saturate(occ) * _Intensity;

				#ifndef _DEBUGSHOWSPHERE_ON
					return float4(_Color.rgb, finalAlpha);
				#else
					// 显示与AO相对应的球体在空间里。这个跟shadertoy显示物体的算法一致，只是整体转到了世界空间去做。
					float3 V = normalize(GetWorldSpaceNormalizeViewDir(input.positionWS));
					float3 ro = float3(GetCurrentViewPosition());
					float3 rd = -V;
					float t2 = sphIntersect( ro, rd, sph );
					float t = t2;
					float3 pos = ro + t * rd;
					float3 nor = normalize(pos - spherePos);

					if(t2 > 0.00001)
					{
						// 显示的时候可以让场景遮挡
						float sphereDepthVS = -TransformWorldToView(pos).z;
						if(sphereDepthVS < sceneZ)
						{
							float NdotV = saturate(dot(nor, V));
							return float4(NdotV, NdotV, NdotV,1);
						}
						else
						{
							return float4(_Color.rgb, finalAlpha);
						}
					}
					else
					{
						return float4(_Color.rgb, finalAlpha);
					}

				#endif


			}
			ENDHLSL
		}
	}
    CustomEditor "Scarecrow.SimpleShaderGUI"
}