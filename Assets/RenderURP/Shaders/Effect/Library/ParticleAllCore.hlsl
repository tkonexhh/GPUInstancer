#ifndef PARTICLEALL_CORE_INCLUDED
#define PARTICLEALL_CORE_INCLUDED

#include "ParticleAllInput.hlsl"

struct Attributes
{
    float4 positionOS       : POSITION;
    float4 color            : COLOR;
    float3 normalOS         : NORMAL;
    float4 texcoord         : TEXCOORD0;    // xy : uv0     zw : uv1
    float4 customData1      : TEXCOORD1;    // x : multi color intensity   y : dissolve threshold
    float4 customData2      : TEXCOORD2;    // rgb : multi color
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4  uv                   : TEXCOORD0;
    float4  color                : TEXCOORD1;
    half3   normalWS             : TEXCOORD2;
    float3  positionWS           : TEXCOORD3;
    float4  positionNDC          : TEXCOORD4;
    float4  customData1          : TEXCOORD5;
    float4  customData2          : TEXCOORD6;
    float4  positionCS           : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};


// -----------------------------------------------------------
// Vertex
Varyings ParticleVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);

    #if _F_VERTEXNOISE_ON
        GetVertexNoise(input.texcoord, input.normalOS, input.color, input.positionOS);
    #endif

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS);

    output.uv = input.texcoord;
    output.color = input.color;
    output.normalWS = normalInput.normalWS;
    output.positionWS = vertexInput.positionWS;
    output.positionNDC = vertexInput.positionNDC;
    output.customData1 = input.customData1;
    output.customData2 = input.customData2;
    output.positionCS = vertexInput.positionCS;
    return output;
}


// -----------------------------------------------------------
// Fragment
half4 ParticleFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);

    float2 screenUV = GetScreenUV(input.positionNDC);

    // just for _F_RIM_ON
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    half3 normalWS = normalize(input.normalWS);

    // ----------------------------------------------------------------

    half4 finalColor = 0;

    // distort for uv
    float2 mainDistortUV = 0; float2 dissolveDistortUV = 0; float2 maskDistortUV = 0;
    #if _F_UVDISTORT_ON
        GetDistortUVForUV(input.uv.xy, mainDistortUV, dissolveDistortUV, maskDistortUV);
    #endif

    // main color
    half4 mainColor = GetMainColor(lerp(input.uv.xy, input.uv.zw, _UseUV1), mainDistortUV, input.color, input.customData1, input.customData2);
    finalColor += mainColor;

    // screenmap
    #if _F_SCREENMAP_ON
        half4 screenMap = GetScreenMapColor(screenUV);
        finalColor *= screenMap;
    #endif

    // rim
    #if _F_RIM_ON
        GetRimColor(normalWS, viewDirWS, finalColor);
    #endif

    // dissolve
    #if _F_DISSOLVE_ON
        GetDissolveColor(input.uv.xy, dissolveDistortUV, maskDistortUV, input.customData1, finalColor);
    #endif

    // mask
    #if _F_MASK_ON
        GetMask(input.uv.xy, maskDistortUV, input.customData1, finalColor);
    #endif
    
    // contact
    #if _F_CONTACT_ON
        GetContactColor(screenUV, input.positionNDC, finalColor);
    #endif

    return finalColor;
} 




#endif
