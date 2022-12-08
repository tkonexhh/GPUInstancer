#ifndef WATER_PASS_INCLUDED
#define WATER_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"

struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
    float2 texcoord     : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2  uv                       : TEXCOORD0;
    float3  positionWS               : TEXCOORD1;
    half3   normalWS                 : TEXCOORD2;
    half4   tangentWS                : TEXCOORD3;    // xyz: tangent, w: sign

    float4  positionNDC              : TEXCOORD4;
    float3  rayVS                    : TEXCOORD5;
    float3  upWS                     : TEXCOORD6;

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        float4  shadowCoord              : TEXCOORD7;
    #endif

    float4  positionCS               : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

half3x3 GetTangentToWorld(Varyings input)
{
    float sgn = input.tangentWS.w;      // should be either +1 or -1
    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
    half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);

    return tangentToWorld;
}

float4 GetShadowCoord(Varyings input)
{
    float4 shadowCoord = float4(0.0, 0.0, 0.0, 0.0);
    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        shadowCoord = input.shadowCoord;
    #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
        shadowCoord = TransformWorldToShadowCoord(input.positionWS);
    #endif

    return shadowCoord;
}

Light GetLight(Varyings input)
{
    float4 shadowCoord = GetShadowCoord(input);
    Light mainLight = GetMainLight(shadowCoord, input.positionWS, 1.0);
    #if _USERLIGHTDIRECTION_ON
        mainLight.direction = -_LightDirection;
    #endif
    // 默认光源颜色不应用
	#if !_LIGHTCOLORTOSPECULAR_ON
        mainLight.color = 1.0;
    #endif

    return mainLight;
}

// -----------------------------------------------------------
// Vertex
Varyings WaterVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);

	#if _F_WAVE_ON
		CalculateWaves(input.positionOS);
	#endif

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    output.uv = input.texcoord;
    output.normalWS = normalInput.normalWS;

    real sign = input.tangentOS.w * GetOddNegativeScale();
    output.tangentWS = half4(normalInput.tangentWS.xyz, sign);

    output.positionWS = vertexInput.positionWS;
    output.positionNDC = vertexInput.positionNDC;

    output.rayVS = TransformWorldToView(TransformObjectToWorld(input.positionOS.xyz)) * float3(-1, -1, 1);
    output.upWS = TransformObjectToWorldDir(float3(0, 1, 0));

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        output.shadowCoord = GetShadowCoord(vertexInput);
    #endif

    output.positionCS = vertexInput.positionCS;

    return output;
}

#endif
