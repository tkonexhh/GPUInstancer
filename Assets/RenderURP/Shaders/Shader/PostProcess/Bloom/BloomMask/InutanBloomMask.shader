
Shader "Hidden/PostProcessing/Inutan/BloomMask" {
	SubShader
	{
		// 0 Copy
		Pass {
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			uniform sampler2D _BloomMaskCopyTex;
			uniform half4 _BloomMaskCopyTex_ST;
			
			struct appdata
			{
				half4 vertex : POSITION;
				half4 texcoord : TEXCOORD0;
			};

			struct v2f {
				half4 pos : SV_POSITION;
				half2 uv : TEXCOORD0;
			};	
			
			v2f vert (appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
		       	o.uv = TRANSFORM_TEX(v.texcoord, _BloomMaskCopyTex).xy;
				return o;
			}

			half4 frag(v2f i) : COLOR
			{
				return tex2D(_BloomMaskCopyTex, i.uv);
			}
			ENDCG
        } 

		// 1 Mask
		Pass {
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			float _BloomIntensity;
			struct appdata
			{
				half4 vertex : POSITION;
			};

			struct v2f {
				half4 pos : SV_POSITION;
			};	
			
			v2f vert (appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				return o;
			}

			half4 frag(v2f i) : COLOR
			{
				return float4(1, 1, 1, _BloomIntensity);
			}
			ENDCG
        } 

		// 2 Copy Back
		Pass {
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			uniform sampler2D _BloomMaskTex;
			uniform float4 _BloomMaskTex_ST;
			struct appdata
			{
				half4 vertex : POSITION;
				half4 texcoord : TEXCOORD0;
			};

			struct v2f {
				half4 pos : SV_POSITION;
				half2 uv : TEXCOORD0;
			};	
			
			v2f vert (appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
		       	o.uv = TRANSFORM_TEX(v.texcoord, _BloomMaskTex).xy;
				return o;
			}

			half4 frag(v2f i) : COLOR
			{
				return tex2D(_BloomMaskTex, i.uv);
			}
			ENDCG
        } 
    }
	Fallback Off
}
