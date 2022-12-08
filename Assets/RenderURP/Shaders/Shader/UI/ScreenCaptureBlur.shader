
Shader "Hidden/PostProcessing/Inutan/ScreenCaptureBlur"
{
	Properties
	{
		_MainTex("Base (RGB)", 2D) = "white" {}
	}

	CGINCLUDE

	#include "UnityCG.cginc"

	sampler2D _MainTex;
	uniform half4 _MainTex_TexelSize;
	uniform float4 _MainTex_ST;
	uniform half _Offset;

	struct VertexInput
	{
		float4 vertex : POSITION;
		half2 texcoord : TEXCOORD0;
	};

	struct v2f_DownSample
	{
		float4 vertex: SV_POSITION;
		float2 uv: TEXCOORD0;
		float4 uv01: TEXCOORD1;
		float4 uv23: TEXCOORD2;
	};


	struct v2f_UpSample
	{
		float4 vertex: SV_POSITION;
		float4 uv01: TEXCOORD0;
		float4 uv23: TEXCOORD1;
		float4 uv45: TEXCOORD2;
		float4 uv67: TEXCOORD3;
	};

	struct v2f_Flip
	{
		float4 vertex: SV_POSITION;
		float2 uv: TEXCOORD0;
	};

	v2f_DownSample Vert_DownSample(VertexInput v)
	{
		v2f_DownSample o;
		o.vertex = UnityObjectToClipPos(v.vertex);

		float2 uv = TRANSFORM_TEX(v.texcoord, _MainTex);

		_MainTex_TexelSize *= 0.5;
		o.uv = uv;
		o.uv01.xy = uv - _MainTex_TexelSize * float2(1 + _Offset, 1 + _Offset); //top right
		o.uv01.zw = uv + _MainTex_TexelSize * float2(1 + _Offset, 1 + _Offset); //bottom left
		o.uv23.xy = uv - float2(_MainTex_TexelSize.x, -_MainTex_TexelSize.y) * float2(1 + _Offset, 1 + _Offset); //top left
		o.uv23.zw = uv + float2(_MainTex_TexelSize.x, -_MainTex_TexelSize.y) * float2(1 + _Offset, 1 + _Offset); //bottom right

		return o;
	}


	half4 Frag_DownSample(v2f_DownSample i): SV_Target
	{
		half4 sum = tex2D(_MainTex, i.uv) * 4;
		sum += tex2D(_MainTex, i.uv01.xy);
		sum += tex2D(_MainTex, i.uv01.zw);
		sum += tex2D(_MainTex, i.uv23.xy);
		sum += tex2D(_MainTex, i.uv23.zw);

		return sum * 0.125;
	}

	v2f_UpSample Vert_UpSample(VertexInput v)
	{
		v2f_UpSample o;
		o.vertex = UnityObjectToClipPos(v.vertex);

		float2 uv = TRANSFORM_TEX(v.texcoord, _MainTex);

		_MainTex_TexelSize *= 0.5;
		_Offset = float2(1 + _Offset, 1 + _Offset);

		o.uv01.xy = uv + float2(-_MainTex_TexelSize.x * 2, 0) * _Offset;
		o.uv01.zw = uv + float2(-_MainTex_TexelSize.x, _MainTex_TexelSize.y) * _Offset;
		o.uv23.xy = uv + float2(0, _MainTex_TexelSize.y * 2) * _Offset;
		o.uv23.zw = uv + _MainTex_TexelSize * _Offset;
		o.uv45.xy = uv + float2(_MainTex_TexelSize.x * 2, 0) * _Offset;
		o.uv45.zw = uv + float2(_MainTex_TexelSize.x, -_MainTex_TexelSize.y) * _Offset;
		o.uv67.xy = uv + float2(0, -_MainTex_TexelSize.y * 2) * _Offset;
		o.uv67.zw = uv - _MainTex_TexelSize * _Offset;

		return o;
	}

	half4 Frag_UpSample(v2f_UpSample i): SV_Target
	{
		half4 sum = 0;
		sum += tex2D(_MainTex, i.uv01.xy);
		sum += tex2D(_MainTex, i.uv01.zw) * 2;
		sum += tex2D(_MainTex, i.uv23.xy);
		sum += tex2D(_MainTex, i.uv23.zw) * 2;
		sum += tex2D(_MainTex, i.uv45.xy);
		sum += tex2D(_MainTex, i.uv45.zw) * 2;
		sum += tex2D(_MainTex, i.uv67.xy);
		sum += tex2D(_MainTex, i.uv67.zw) * 2;
		return sum * 0.0833;
	}

	v2f_Flip Vert_Flip(VertexInput v)
	{
		v2f_Flip o;
		o.vertex = UnityObjectToClipPos(v.vertex);

		#if UNITY_UV_STARTS_AT_TOP
			v.texcoord = v.texcoord * float2(1.0, -1.0) + float2(0.0, 1.0);
		#endif

		o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
		return o;
	}

	half4 Frag_Flip(v2f_Flip i): SV_Target
	{
		return half4(tex2D(_MainTex, i.uv.xy).rgb, 1);
	}

	ENDCG

	SubShader
	{
		Cull Off ZWrite Off ZTest Always

		Pass
		{
			CGPROGRAM
			#pragma vertex Vert_DownSample
			#pragma fragment Frag_DownSample
			ENDCG
		}

		Pass
		{
			CGPROGRAM
			#pragma vertex Vert_UpSample
			#pragma fragment Frag_UpSample
			ENDCG
		}

		Pass
		{
			CGPROGRAM
			#pragma vertex Vert_Flip
			#pragma fragment Frag_Flip
			ENDCG
		}
	}

	FallBack Off
}