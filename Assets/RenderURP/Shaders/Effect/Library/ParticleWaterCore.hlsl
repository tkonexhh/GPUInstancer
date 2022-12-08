#ifndef PARTICLEWATER_CORE_INCLUDED
#define PARTICLEWATER_CORE_INCLUDED

#include "ParticleWaterInput.hlsl"

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
    CalculateVertexNoise(input.texcoord, input.color, input.normalOS, input.positionOS);

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
    GetNormal(input.uv, tangentToWorld, _NormalScale, normalTS, normalWS);
    half3 refractColor = GetGrabColor(input.positionNDC, normalTS).rgb;
   
    SurfaceData surfaceData;
    surfaceData.albedo               = refractColor * _MainColor.rgb;
    surfaceData.normalTS             = normalTS;
    surfaceData.alpha                = 1;
    surfaceData.metallic             = 0;
    surfaceData.specular             = 0;
    surfaceData.smoothness           = 0;
    surfaceData.occlusion            = 0;
    surfaceData.emission             = 0;
    surfaceData.clearCoatMask        = 0;
    surfaceData.clearCoatSmoothness  = 0;

    BRDFData brdfData;
    InitializeBRDFData(surfaceData, brdfData);

    half3 refNormalTS, refNormalWS;
    GetNormal(input.uv, tangentToWorld, _ReflectionNormalScale, refNormalTS, refNormalWS);

    // 间接光
    half3 indirectSpecular = GetReflectionCustom(viewDirWS, refNormalWS);
    half fresnelTerm = pow(1.0 - saturate(dot(refNormalWS, viewDirWS)), 5);
    half3 indirectDiffuse = SampleSH(normalWS);

    half3 indirectColor = indirectDiffuse * brdfData.diffuse + 
                        (indirectSpecular + _ReflectAddColor.rgb * input.color.rgb) * fresnelTerm;
    
    // diffuse
    Light mainLight =  GetMainLight();
    half NdotL = saturate(dot(normalWS, mainLight.direction));
    half NdotV = abs(dot(normalWS, viewDirWS));
    float3 halfDir = SafeNormalize (float3(mainLight.direction) + viewDirWS);
    half LdotH = saturate(dot(mainLight.direction, halfDir));
    half3 brdf = brdfData.diffuse * DisneyDiffuse(NdotV, NdotL, LdotH, 1) * PI;
    half3 directColor = brdf * mainLight.color * NdotL;

    // specular
    half3 specularColor = GetWaterSpecular(normalWS, viewDirWS, normalWS, mainLight.color,
                         _SpecularRoughness, _SpecularColor.rgb, _SpecularIntensity);
    directColor += specularColor;

    //
    half3 finalColor = indirectColor + directColor;

    return half4(finalColor, 1);
} 




#endif
