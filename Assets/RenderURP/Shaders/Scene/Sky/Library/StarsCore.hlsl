#ifndef STARS_CORE_INCLUDED
#define STARS_CORE_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

// ----------------------------------------------------------
// TODO 因为使用了PropertyBlock URP batch并不过工作
// CBUFFER_START(UnityPerMaterial)
   	half _StarBrightness;
	half _StarSize;
// CBUFFER_END

struct Attributes
{
    float4 positionOS   : POSITION;
	float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
	float4 color 		: COLOR;
    float2 texcoord     : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
	float3 uv 				: TEXCOORD0;
	float3 color  			: COLOR;
	float4 positionCS   	: SV_POSITION;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

// -----------------------------------------------------------
// Vertex
Varyings StarsVertex(Attributes input)
{
	Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);

	float tanFovHalf = 1.0 / max(0.1, UNITY_MATRIX_P[0][0]); // (r-l) / (2*n)
	float radius = 4.0 * tanFovHalf / _ScreenParams.x;
	float alpha = _StarBrightness * 0.00001 * input.color.a / (radius * radius);
	float size = _StarSize * radius;

	float3 u_vec = input.tangentOS;
	float3 v_vec = cross(input.normalOS, input.tangentOS);

	float u_fac = input.texcoord.x - 0.5;
	float v_fac = input.texcoord.y - 0.5;

	input.positionOS.xyz -= u_vec * u_fac * size;
	input.positionOS.xyz -= v_vec * v_fac * size;

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

	output.positionCS = vertexInput.positionCS;

	float3 skyPos = input.positionOS.xyz;

	output.uv.xy = 2.0 * input.texcoord - 1.0;
	output.uv.z  = skyPos.y * 25;

	output.color = half3(alpha, alpha, alpha);

	return output;
}
	
// -----------------------------------------------------------
// Fragment
half4 StarsFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);

	half  dist  = length(input.uv.xy);
	half  spot  = saturate(1.0 - dist);
	half  alpha = saturate(input.uv.z) * spot;

	return half4(input.color * alpha, 1);
}

#endif
