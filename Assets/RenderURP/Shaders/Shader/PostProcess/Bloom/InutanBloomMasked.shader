Shader "Hidden/PostProcessing/Inutan/MaskedBloom"
{
    CGINCLUDE
		#include "UnityCG.cginc"

		sampler2D _MainTex;
		half4 _MainTex_ST;
		uniform half4 _MainTex_TexelSize;

        sampler2D _MaskedBloomUpsampleTex;
		half4 _MaskedBloomUpsampleTex_ST;
		uniform half4 _MaskedBloomUpsampleTex_TexelSize;

		sampler2D _BloomMaskTex;
		half4 _BloomMaskTex_ST;

        float _MaskedBloomThreshold;
        float _MaskedBloomScale;

        struct appdata
        {
            float4 vertex : POSITION;
        };

        float2 GetUV(float2 vertex)
		{
			float2 texcoord = (vertex + 1) * 0.5;

			#if UNITY_UV_STARTS_AT_TOP
				texcoord = texcoord * float2(1.0, -1.0) + float2(0.0, 1.0);
			#endif

			return texcoord;
		}

        float2 Circle(float slices, float index)
        {
            float rad = (3.14159462 * 2.0 * (1.0 / slices)) * (index + 2.0);
            return float2(cos(rad), sin(rad));
        }

	    struct v2f_prefilter
		{
			float4 vertex : SV_POSITION;
			half4 uv01 : TEXCOORD0;
			half4 uv23 : TEXCOORD1;
			half2 uv : TEXCOORD2;
		};			

        struct v2f_15taps
        {
            float4 vertex : SV_POSITION;
            float4 uv01 : TEXCOORD0;
            float4 uv23 : TEXCOORD1;
            float4 uv45 : TEXCOORD2;
            float4 uv67 : TEXCOORD3;
            float4 uv89 : TEXCOORD4;
            float4 uv1011 : TEXCOORD5;
            float4 uv1213 : TEXCOORD6;
            float2 uv1415 : TEXCOORD7;
        };

        v2f_prefilter vertPrefilter(appdata v)
        {
            v2f_prefilter o;

            o.vertex = float4(v.vertex.xy, 0.0, 1.0);
            float2 uv = GetUV(v.vertex.xy);

            o.uv = UnityStereoScreenSpaceUVAdjust(uv, _MainTex_ST);
            o.uv01.xy = UnityStereoScreenSpaceUVAdjust(uv + float2(1.0, 1.0) * _MainTex_TexelSize.xy, _MainTex_ST);
            o.uv01.zw = UnityStereoScreenSpaceUVAdjust(uv + float2(-1.0, 1.0) * _MainTex_TexelSize.xy, _MainTex_ST);
            o.uv23.xy = UnityStereoScreenSpaceUVAdjust(uv + float2(1.0, -1.0) * _MainTex_TexelSize.xy, _MainTex_ST);
            o.uv23.zw = UnityStereoScreenSpaceUVAdjust(uv + float2(-1.0, -1.0) * _MainTex_TexelSize.xy, _MainTex_ST);
            return o;
        }
            

        half4 fragPrefilter (v2f_prefilter i) : SV_Target
        {
            half w = 1.0 / 4.0;
            half3 col = tex2D(_MainTex, i.uv01.xy).rgb * w;
            col += tex2D(_MainTex, i.uv01.zw).rgb * w;
            col += tex2D(_MainTex, i.uv23.xy).rgb * w;
            col += tex2D(_MainTex, i.uv23.zw).rgb * w;

			fixed4 mask = tex2D (_BloomMaskTex, i.uv);
            col = mask.r * max(col - (_MaskedBloomThreshold - mask.a), 0);

            return half4(col, 1.0);
        }


        v2f_15taps vertDownSample(appdata v)
        {
            v2f_15taps o;

            o.vertex = float4(v.vertex.xy, 0.0, 1.0);
            float2 uv = GetUV(v.vertex.xy);

            float2 d = _MainTex_TexelSize.xy * _MaskedBloomScale;

            o.uv01.xy = UnityStereoScreenSpaceUVAdjust(uv, _MainTex_ST);
            o.uv01.zw = UnityStereoScreenSpaceUVAdjust(uv + Circle(14.0, 0.0) * d, _MainTex_ST);
            o.uv23.xy = UnityStereoScreenSpaceUVAdjust(uv + Circle(14.0, 1.0) * d, _MainTex_ST);
            o.uv23.zw = UnityStereoScreenSpaceUVAdjust(uv + Circle(14.0, 2.0) * d, _MainTex_ST);
            o.uv45.xy = UnityStereoScreenSpaceUVAdjust(uv + Circle(14.0, 3.0) * d, _MainTex_ST);
            o.uv45.zw = UnityStereoScreenSpaceUVAdjust(uv + Circle(14.0, 4.0) * d, _MainTex_ST);
            o.uv67.xy = UnityStereoScreenSpaceUVAdjust(uv + Circle(14.0, 5.0) * d, _MainTex_ST);
            o.uv67.zw = UnityStereoScreenSpaceUVAdjust(uv + Circle(14.0, 6.0) * d, _MainTex_ST);
            o.uv89.xy = UnityStereoScreenSpaceUVAdjust(uv + Circle(14.0, 7.0) * d, _MainTex_ST);
            o.uv89.zw = UnityStereoScreenSpaceUVAdjust(uv + Circle(14.0, 8.0) * d, _MainTex_ST);
            o.uv1011.xy = UnityStereoScreenSpaceUVAdjust(uv + Circle(14.0, 9.0) * d, _MainTex_ST);
            o.uv1011.zw = UnityStereoScreenSpaceUVAdjust(uv + Circle(14.0, 10.0) * d, _MainTex_ST);
            o.uv1213.xy = UnityStereoScreenSpaceUVAdjust(uv + Circle(14.0, 11.0) * d, _MainTex_ST);
            o.uv1213.zw = UnityStereoScreenSpaceUVAdjust(uv + Circle(14.0, 12.0) * d, _MainTex_ST);
            o.uv1415.xy = UnityStereoScreenSpaceUVAdjust(uv + Circle(14.0, 13.0) * d, _MainTex_ST);
            
            return o;
        }

        half4 fragDownSample (v2f_15taps i) : SV_Target
        {
            half w = 1.0 / 15.0;
            half3 col = tex2D(_MainTex, i.uv01.xy).rgb * w;
            col += tex2D(_MainTex, i.uv01.zw).rgb * w;
            col += tex2D(_MainTex, i.uv23.xy).rgb * w;
            col += tex2D(_MainTex, i.uv23.zw).rgb * w;
            col += tex2D(_MainTex, i.uv45.xy).rgb * w;
            col += tex2D(_MainTex, i.uv45.zw).rgb * w;
            col += tex2D(_MainTex, i.uv67.xy).rgb * w;
            col += tex2D(_MainTex, i.uv67.zw).rgb * w;
            col += tex2D(_MainTex, i.uv89.xy).rgb * w;
            col += tex2D(_MainTex, i.uv89.zw).rgb * w;
            col += tex2D(_MainTex, i.uv1011.xy).rgb * w;
            col += tex2D(_MainTex, i.uv1011.zw).rgb * w;
            col += tex2D(_MainTex, i.uv1213.xy).rgb * w;
            col += tex2D(_MainTex, i.uv1213.zw).rgb * w;
            col += tex2D(_MainTex, i.uv1415.xy).rgb * w;
            return half4(col, 1.0);
        }

        v2f_15taps vertUpSample(appdata v)
        {
            v2f_15taps o;

            o.vertex = float4(v.vertex.xy, 0.0, 1.0);
            float2 uv = GetUV(v.vertex.xy);

            float2 d = _MainTex_TexelSize.xy * _MaskedBloomScale;

            o.uv01.xy = UnityStereoScreenSpaceUVAdjust(uv, _MainTex_ST);
            o.uv01.zw = UnityStereoScreenSpaceUVAdjust(uv + Circle(7.0, 0.0) * d, _MainTex_ST);
            o.uv23.xy = UnityStereoScreenSpaceUVAdjust(uv + Circle(7.0, 1.0) * d, _MainTex_ST);
            o.uv23.zw = UnityStereoScreenSpaceUVAdjust(uv + Circle(7.0, 2.0) * d, _MainTex_ST);
            o.uv45.xy = UnityStereoScreenSpaceUVAdjust(uv + Circle(7.0, 3.0) * d, _MainTex_ST);
            o.uv45.zw = UnityStereoScreenSpaceUVAdjust(uv + Circle(7.0, 4.0) * d, _MainTex_ST);
            o.uv67.xy = UnityStereoScreenSpaceUVAdjust(uv + Circle(7.0, 5.0) * d, _MainTex_ST);
            o.uv67.zw = UnityStereoScreenSpaceUVAdjust(uv + Circle(7.0, 6.0) * d, _MainTex_ST);

            d = _MaskedBloomUpsampleTex_TexelSize.xy * _MaskedBloomScale;

            o.uv89.xy = UnityStereoScreenSpaceUVAdjust(uv + Circle(7.0, 0.0) * d, _MaskedBloomUpsampleTex_ST);
            o.uv89.zw = UnityStereoScreenSpaceUVAdjust(uv + Circle(7.0, 1.0) * d, _MaskedBloomUpsampleTex_ST);
            o.uv1011.xy = UnityStereoScreenSpaceUVAdjust(uv + Circle(7.0, 2.0) * d, _MaskedBloomUpsampleTex_ST);
            o.uv1011.zw = UnityStereoScreenSpaceUVAdjust(uv + Circle(7.0, 3.0) * d, _MaskedBloomUpsampleTex_ST);
            o.uv1213.xy = UnityStereoScreenSpaceUVAdjust(uv + Circle(7.0, 4.0) * d, _MaskedBloomUpsampleTex_ST);
            o.uv1213.zw = UnityStereoScreenSpaceUVAdjust(uv + Circle(7.0, 5.0) * d, _MaskedBloomUpsampleTex_ST);
            o.uv1415.xy = UnityStereoScreenSpaceUVAdjust(uv + Circle(7.0, 6.0) * d, _MaskedBloomUpsampleTex_ST);
            
            return o;
        }

        half4 fragUpSample (v2f_15taps i) : SV_Target
        {
            half w = 1.0 / 16.0;
            // Taps downsampled texture
            half3 col = tex2D(_MainTex, i.uv01.xy).rgb * w;
            col += tex2D(_MainTex, i.uv01.zw).rgb * w;
            col += tex2D(_MainTex, i.uv23.xy).rgb * w;
            col += tex2D(_MainTex, i.uv23.zw).rgb * w;
            col += tex2D(_MainTex, i.uv45.xy).rgb * w;
            col += tex2D(_MainTex, i.uv45.zw).rgb * w;
            col += tex2D(_MainTex, i.uv67.xy).rgb * w;
            col += tex2D(_MainTex, i.uv67.zw).rgb * w;

            // Taps upsampled texture
            col += tex2D(_MaskedBloomUpsampleTex, i.uv01.xy).rgb * w;
            col += tex2D(_MaskedBloomUpsampleTex, i.uv89.xy).rgb * w;
            col += tex2D(_MaskedBloomUpsampleTex, i.uv89.zw).rgb * w;
            col += tex2D(_MaskedBloomUpsampleTex, i.uv1011.xy).rgb * w;
            col += tex2D(_MaskedBloomUpsampleTex, i.uv1011.zw).rgb * w;
            col += tex2D(_MaskedBloomUpsampleTex, i.uv1213.xy).rgb * w;
            col += tex2D(_MaskedBloomUpsampleTex, i.uv1213.zw).rgb * w;
            col += tex2D(_MaskedBloomUpsampleTex, i.uv1415.xy).rgb * w;

            return half4(col, 1.0);
        }

    ENDCG
    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        // 0
	    Pass {
            CGPROGRAM
            #pragma vertex vertPrefilter
            #pragma fragment fragPrefilter
            ENDCG
		}

        // 1
	    Pass {
            CGPROGRAM
            #pragma vertex vertDownSample
            #pragma fragment fragDownSample
            ENDCG
		}

        // 2
	    Pass {
            CGPROGRAM
            #pragma vertex vertUpSample
            #pragma fragment fragUpSample
            ENDCG
		}

    }
}
