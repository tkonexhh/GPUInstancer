#ifndef PARTICLEWALLPRO_CORE_INCLUDED
#define PARTICLEWALLPRO_CORE_INCLUDED

#include "ParticleWallProInput.hlsl"

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


// -----------------------------------------------------------
// Vertex
Varyings ParticleWallProVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);

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

// -----------------------------------------------------------
// Fragment
half4 ParticleWallProFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);

    float3 scale = GetScale();

    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    float2 screenUV = GetScreenUV(input.positionNDC);

    half3x3 tangentToWorld = GetTangentToWorld(input.normalWS, input.tangentWS);
    half3 normalTS, normalWS;
    GetNormal(input.uv, tangentToWorld, scale, normalTS, normalWS);

  
    // dissolve clip
    #if _F_DISSOLVE_ON
        ClipByDissolve(input.uv, scale);
    #endif

    // base color
    float4 finalColor = _Color * _Intensity;
    finalColor.rgb *= input.color.rgb;

    float4 finalAddColor = 0;
    float hasAnyAddColor = 0;
    //
    #if _F_DETIALTEX_1_ON
        float4 detail_1 = GetDetailTex(input.uv, screenUV, 
                    TEXTURE2D_ARGS(_DetialTex_1, sampler_DetialTex_1), 
                    _UseScreenUV_1, _UseGlobalTiling_1, _DetialTex_1_ST, scale);
        finalColor *= lerp(detail_1, 1, _UseAdd_1);
        finalAddColor += lerp(0, detail_1, _UseAdd_1);
        hasAnyAddColor += _UseAdd_1;
    #endif

    #if _F_DETIALTEX_2_ON
        float4 detail_2 = GetDetailTex(input.uv, screenUV, 
                    TEXTURE2D_ARGS(_DetialTex_2, sampler_DetialTex_2), 
                    _UseScreenUV_2, _UseGlobalTiling_2, _DetialTex_2_ST, scale);
        finalColor *= lerp(detail_2, 1, _UseAdd_2);
        finalAddColor += lerp(0, detail_2, _UseAdd_2);
        hasAnyAddColor += _UseAdd_2;
    #endif

    #if _F_DETIALTEX_3_ON
        float4 detail_3 = GetDetailTex(input.uv, screenUV, 
                    TEXTURE2D_ARGS(_DetialTex_3, sampler_DetialTex_3), 
                    _UseScreenUV_3, _UseGlobalTiling_3, _DetialTex_3_ST, scale);
        finalColor *= lerp(detail_3, 1, _UseAdd_3);
        finalAddColor += lerp(0, detail_3, _UseAdd_3);
        hasAnyAddColor += _UseAdd_3;
    #endif

    #if _F_DETIALTEX_4_ON
        float4 detail_4 = GetDetailTex(input.uv, screenUV, 
                    TEXTURE2D_ARGS(_DetialTex_4, sampler_DetialTex_4), 
                    _UseScreenUV_4, _UseGlobalTiling_4, _DetialTex_4_ST, scale);
        finalColor *= lerp(detail_4, 1, _UseAdd_4);
        finalAddColor += lerp(0, detail_4, _UseAdd_4);
        hasAnyAddColor += _UseAdd_4;
    #endif

    finalColor *= lerp(1, finalAddColor, hasAnyAddColor > 0);

    // fade
    half alpha = 1;
    #if _F_FADE_ON
        float fade = SAMPLE_TEXTURE2D(_FadeTex, sampler_FadeTex, input.uv).r;
        alpha = saturate(fade* exp(_FadeIntensity * 10 - 5));
    #endif

    // refract
	half3 refractColor = GetRefractColor(input.positionWS, viewDirWS, normalWS);

    return float4(finalColor.rgb + refractColor, alpha);
} 




#endif
