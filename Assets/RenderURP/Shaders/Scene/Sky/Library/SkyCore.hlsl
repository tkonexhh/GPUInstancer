#ifndef SKY_CORE_INCLUDED
#define SKY_CORE_INCLUDED

#include "SkyScattering.hlsl"

struct Attributes
{
    float4 positionOS   : POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
	float3 inScatterColor  	: TEXCOORD0;
	float3 outScatterColor 	: TEXCOORD1;
	float3 viewDir    		: TEXCOORD2;
	float3 positionMoonS	: TEXCOORD3;
	float4 positionCS   	: SV_POSITION;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

// -----------------------------------------------------------
// Vertex
Varyings SkyVertex(Attributes input)
{
	Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

	output.positionCS = vertexInput.positionCS;
	output.viewDir = normalize(input.positionOS.xyz);

	float3 positionWS = vertexInput.positionWS;
	output.positionMoonS = mul(_WorldToMoonMatrix, float4(positionWS, 1)).xyz;
	
	ScatteringCoefficients(output.viewDir, output.inScatterColor, output.outScatterColor);

	return output;
}
	
// -----------------------------------------------------------
// Fragment
half4 SkyFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);

   	float4 color = ScatteringColor(input.positionMoonS, normalize(input.viewDir), 
   								input.inScatterColor, input.outScatterColor);
	return color;
}

#endif
