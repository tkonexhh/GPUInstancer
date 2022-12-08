#ifndef PARTICLEDISTORT_CORE_INCLUDED
#define PARTICLEDISTORT_CORE_INCLUDED

#include "ParticleDistortInput.hlsl"

struct Attributes
{
    float4 positionOS       : POSITION;
    float4 color            : COLOR;
    float2 texcoord         : TEXCOORD0;
    float4 customData1      : TEXCOORD1;    // x : multi color intensity   y : dissolve threshold
    float4 customData2      : TEXCOORD2;    // rgb : multi color
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2  uv                   : TEXCOORD0;
    float4  color                : TEXCOORD1;
    float4  positionNDC          : TEXCOORD2;
    float4  customData1          : TEXCOORD3;
    float4  customData2          : TEXCOORD4;
    float4  positionCS           : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};


// -----------------------------------------------------------
// Vertex
Varyings ParticleDistortVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

    output.uv = input.texcoord;
    output.color = input.color;
    output.positionNDC = vertexInput.positionNDC;
    output.customData1 = input.customData1;
    output.customData2 = input.customData2;
    output.positionCS = vertexInput.positionCS;
    return output;
}


// -----------------------------------------------------------
// Fragment
half4 ParticleDistortFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);

    // ----------------------------------------------------------------
    half3 normalTS = GetNormalTS(input.uv, input.color, input.customData1);
    half4 grabColor = GetGrabColor(input.positionNDC, normalTS);

    return half4(grabColor.rgb, 1);
} 




#endif
