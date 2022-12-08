#ifndef PARTICLEWATER_CORE_INCLUDED
#define PARTICLEWATER_CORE_INCLUDED

#include "ParticleWaterInputDeprecated.hlsl"

struct Attributes
{
    float4 positionOS       : POSITION;
    float3 normalOS         : NORMAL;
    float4 tangentOS        : TANGENT;
    float4 color            : COLOR;
    float2 texcoord         : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2  uv                   : TEXCOORD0;
    float4  color                : TEXCOORD1;
    float3  positionWS           : TEXCOORD2;
    half3   normalWS             : TEXCOORD3;
    half4   tangentWS            : TEXCOORD4;   // xyz: tangent, w: sign
    float4  positionNDC          : TEXCOORD5;
    float4  positionCS           : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

half3x3 GetTangentToWorld(Varyings input)
{
    float sgn = input.tangentWS.w;      // should be either +1 or -1
    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
    half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);

    return tangentToWorld;
}

// -----------------------------------------------------------
// Vertex
Varyings ParticleWaterVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);

    // // 
    CalculateVertexNoise(input.texcoord, input.color, input.tangentOS, input.normalOS, input.positionOS);

    //
    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    output.uv = input.texcoord;
    output.color = input.color;
    output.normalWS = normalInput.normalWS;

    real sign = input.tangentOS.w * GetOddNegativeScale();
    output.tangentWS = half4(normalInput.tangentWS.xyz, sign);

    //
    output.positionWS = vertexInput.positionWS;
    output.positionNDC = vertexInput.positionNDC;

    output.positionCS = vertexInput.positionCS;

    return output;
}

#define WaterSurfaceF0 0.03

// -----------------------------------------------------------
// Fragment
half4 ParticleWaterFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);

    // ----------------------------------------------------------------
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);

    half3x3 tangentToWorld = GetTangentToWorld(input);
    half3 normalTS, normalWS;
    GetNormal(input.uv, tangentToWorld, normalTS, normalWS);
    half3 refractColor = GetGrabColor(input.positionNDC, normalTS).rgb;

    // specular
    half3 specularColor = GetWaterSpecular(normalWS, viewDirWS, normalWS, 
                        1,
                         _SpecularRoughness, _SpecularColor.rgb, _SpecularIntensity);

    //  surface color
    half3 surfaceColor = refractColor + specularColor;

    // 反射
    half3 reflectColor = GetReflectionCustom(viewDirWS, normalWS);

    // fresnel
    half fresnelTerm = GetWaterFresnelTerm(normalWS, viewDirWS, WaterSurfaceF0, 5.0);


    float2 mainUV = TRANSFORM_TEX(input.uv, _MainTex) + frac(float2(_MainUVSpeedX, _MainUVSpeedY) * _Time.y);
    float4 mainColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, mainUV);
    mainColor = pow(mainColor, _MainPower);

    // final color
	half3 finalColor = lerp(surfaceColor * _ShadeColor, surfaceColor * _LightColor.rgb, mainColor.rgb);
    finalColor += reflectColor * fresnelTerm;

    return half4(finalColor, 1);
} 




#endif
