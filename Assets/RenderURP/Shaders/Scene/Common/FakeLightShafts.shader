
Shader "Inutan/URP/Scene/Common/FakeLightShafts 假光束面片"
{
	Properties
	{
		_Intensity("强度", Range(0, 255)) = 1
		[HDR]_ShaftColor("颜色", Color) = (1,1,1,1)
		[Tex]_MainTex("蒙板贴图", 2D) = "white" {}
		_NoiseDirection("XY: 噪声方向", Vector) = (0.05,0,0,0)
		_Noise_Scale("噪声密度", float) = 8.96
		_Noise_UpdateSpeed("噪声速度", Range(0, 10)) = 1
        [Range] _FadeOutDist("衰减范围", float) = (20,100,0,1000)
		_FadeOutSlope("衰减曲线斜率 (越小越陡峭)", Range(1.1, 3)) = 1.5
		[Toggle_Switch] _UseSlopeFade("视角垂直法线方向衰减", float) = 1
	}

	SubShader
	{
		Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Transparent" }
		
		Pass
		{
			Name "LightShafts"
			
			Blend One One
			ZWrite Off
			Cull Off

			HLSLPROGRAM
			#pragma target 3.0

            #pragma shader_feature_local _USESLOPEFADE_ON
			#pragma multi_compile_instancing

			#pragma vertex VertexLightShafts
			#pragma fragment FragLightShafts

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

			struct Attributes
			{
				float4 positionOS 	: POSITION;
			    float3 normalOS     : NORMAL;
				float2 texcoord 	: TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct Varyings
			{
				float2 uv 				: TEXCOORD0;
				float3 color			: TEXCOORD1;
				float4 positionCS 		: SV_POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			CBUFFER_START(UnityPerMaterial)
				half 	_Intensity;
				half4 	_ShaftColor;
				float4 	_MainTex_ST;
				float2 	_NoiseDirection;
				half 	_Noise_UpdateSpeed;
				half 	_Noise_Scale;
				float2  _FadeOutDist;
				float	_FadeOutSlope;
			CBUFFER_END
			//
			TEXTURE2D(_MainTex);
			SAMPLER(sampler_MainTex);


			// ------------------------------------------------------------------------------------------------------------
			// Amplify版本噪声 TODO 
			float3 mod2D289(float3 x) { return x - floor(x * ( 1.0 / 289.0 )) * 289.0; }
			float2 mod2D289(float2 x) { return x - floor(x * ( 1.0 / 289.0 )) * 289.0; }
			float3 permute (float3 x) { return mod2D289((x * 34.0 + 1.0) * x); }
			float snoise(float2 v)
			{
				const float4 C = float4(0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439);
				float2 i = floor(v + dot(v, C.yy));
				float2 x0 = v - i + dot(i, C.xx);
				float2 i1;
				i1 = (x0.x > x0.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
				float4 x12 = x0.xyxy + C.xxzz;
				x12.xy -= i1;
				i = mod2D289(i);
				float3 p = permute(permute(i.y + float3(0.0, i1.y, 1.0)) + i.x + float3(0.0, i1.x, 1.0));
				float3 m = max(0.5 - float3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
				m = m * m;
				m = m * m;
				float3 x = 2.0 * frac(p * C.www) - 1.0;
				float3 h = abs(x) - 0.5;
				float3 ox = floor(x + 0.5);
				float3 a0 = x - ox;
				m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
				float3 g;
				g.x = a0.x * x0.x + h.x * x0.y;
				g.yz = a0.yz * x12.xz + h.yz * x12.yw;
				return 130.0 * dot(m, g);
			}
			
			float2 voronoihash(float2 p)
			{
				p = float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3)));
				return frac(sin(p) *43758.5453);
			}
			
			float voronoi(float2 v, float time)
			{
				float2 n = floor(v);
				float2 f = frac(v);
				float F1 = 8.0;
				float F2 = 8.0;

				UNITY_UNROLL
				for ( int j = -1; j <= 1; j++ )
				{
					UNITY_UNROLL
					for ( int i = -1; i <= 1; i++ )
					{
						float2 g = float2(i, j);
						float2 o = voronoihash(n + g);
						o = (sin(time + o * 6.2831) * 0.5 + 0.5); float2 r = f - g - o;
						float d = 0.5 * dot(r, r);
						if(d < F1) 
						{
							F2 = F1;
							F1 = d;
						} 
						else if(d < F2) 
						{
							F2 = d;
						}
					}
				}
				return (F2 + F1) * 0.5;
			}
			
			struct Gradient
			{
				int type;
				int colorsLength;
				int alphasLength;
				float4 colors[8];
				float2 alphas[8];
			};

			Gradient CreateGradient(int type, int colorsLength, int alphasLength,
				float4 colors0, float4 colors1, float4 colors2, float4 colors3, float4 colors4, float4 colors5, float4 colors6, float4 colors7,
				float2 alphas0, float2 alphas1, float2 alphas2, float2 alphas3, float2 alphas4, float2 alphas5, float2 alphas6, float2 alphas7)
			{
				Gradient output =
				{
					type, colorsLength, alphasLength,
					{colors0, colors1, colors2, colors3, colors4, colors5, colors6, colors7},
					{alphas0, alphas1, alphas2, alphas3, alphas4, alphas5, alphas6, alphas7}
				};
				return output;
			}

			float4 SampleGradient(Gradient gradient, float time)
			{
				float3 color = gradient.colors[0].rgb;
				UNITY_UNROLL
				for (int c = 1; c < 8; c++)
				{
					float colorPos = saturate((time - gradient.colors[c-1].w) / (gradient.colors[c].w - gradient.colors[c-1].w)) * step(c, gradient.colorsLength-1);
					color = lerp(color, gradient.colors[c].rgb, lerp(colorPos, step(0.01, colorPos), gradient.type));
				}

				float alpha = gradient.alphas[0].x;
				UNITY_UNROLL
				for (int a = 1; a < 8; a++)
				{
					float alphaPos = saturate((time - gradient.alphas[a-1].y) / (gradient.alphas[a].y - gradient.alphas[a-1].y)) * step(a, gradient.alphasLength-1);
					alpha = lerp(alpha, gradient.alphas[a].x, lerp(alphaPos, step(0.01, alphaPos), gradient.type));
				}
				return float4(color, alpha);
			}
			

			// ------------------------------------------------------------------------------------------------------------
			Varyings VertexLightShafts(Attributes input)
			{
				Varyings output = (Varyings)0;

				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);

    			output.uv = input.texcoord;

				VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
			    output.positionCS = vertexInput.positionCS;
				
				float dist = length(vertexInput.positionVS);

				float nfadeout = smoothstep(_FadeOutDist.x / _FadeOutSlope, _FadeOutDist.x, dist);
				nfadeout *= smoothstep(_FadeOutDist.y, _FadeOutDist.y / _FadeOutSlope, dist);
		
				output.color = nfadeout;

				#if _USESLOPEFADE_ON
					float3 normalWS = TransformObjectToWorldNormal(input.normalOS);	
					float3 viewDirWS = GetWorldSpaceNormalizeViewDir(vertexInput.positionWS);
					float slopeFadeout = saturate(abs(dot(normalWS, viewDirWS)));
					output.color *= slopeFadeout;
				#endif


				return output;
			}

			half4 FragLightShafts(Varyings input) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(input);

    			float2 uv = TRANSFORM_TEX(input.uv, _MainTex);

    			half3 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv).rgb;

				float noiseTime = _Time.y * _Noise_UpdateSpeed;
				float2 noiseDirection = (noiseTime * _NoiseDirection + input.uv) *_Noise_Scale;

				float perlin = snoise(noiseDirection) * 0.5 + 0.5;
				
				float voro = voronoi(noiseDirection, noiseTime);
				float noise = dot(perlin, voro);

				Gradient gradient = CreateGradient(0, 2, 2,
				float4(1, 1, 1, 0.5117723), float4(0, 0, 0, 0.9676509), 0, 0, 0, 0, 0, 0, 
				float2(1, 0), 				float2(1, 1), 				0, 0, 0, 0, 0, 0);
				
				float3 gradientColor = SampleGradient(gradient, saturate(uv.y)).rgb;

				color *= _ShaftColor * 0.02 * _Intensity * noise * gradientColor * input.color;
			
				return half4(color, 1);
			}

			ENDHLSL
		}
	}

    CustomEditor "Scarecrow.SimpleShaderGUI"
}
