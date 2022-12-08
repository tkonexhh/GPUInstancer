#ifndef PARTICLEWALLSIMPLE_CORE_INCLUDED
#define PARTICLEWALLSIMPLE_CORE_INCLUDED

#include "ParticleWallSimpleInput.hlsl"

struct Attributes
{
    float4 positionOS       : POSITION;
    float4 color            : COLOR;
    float2 texcoord         : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2  uv                   : TEXCOORD0;
    float4  color                : TEXCOORD1;
    float4  positionNDC          : TEXCOORD2;
    float4  positionCS           : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};


// -----------------------------------------------------------
// Vertex
Varyings ParticleWallSimpleVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

    output.uv = input.texcoord;
    output.color = input.color;
    output.positionNDC = vertexInput.positionNDC;
    output.positionCS = vertexInput.positionCS;
    return output;
}


// -----------------------------------------------------------
// Fragment
half4 ParticleWallSimpleFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);

    float2 screenUV = GetScreenUV(input.positionNDC);
    float3 scale = GetScale();

    // base color
    float4 finalColor = _Color * _Intensity;
    finalColor.rgb *= input.color.rgb;


    //
    #if _F_DETIALTEX_1_ON
        float4 detail_1 = GetDetailTex(input.uv, screenUV, 
                    TEXTURE2D_ARGS(_DetialTex_1, sampler_DetialTex_1), 
                    _UseScreenUV_1, _UseGlobalTiling_1, _DetialTex_1_ST, scale);
        finalColor *= detail_1;
    #endif

    #if _F_DETIALTEX_2_ON
        float4 detail_2 = GetDetailTex(input.uv, screenUV, 
                    TEXTURE2D_ARGS(_DetialTex_2, sampler_DetialTex_2), 
                    _UseScreenUV_2, _UseGlobalTiling_2, _DetialTex_2_ST, scale);
        finalColor *= detail_2;
    #endif

    #if _F_DETIALTEX_3_ON
        float4 detail_3 = GetDetailTex(input.uv, screenUV, 
                    TEXTURE2D_ARGS(_DetialTex_3, sampler_DetialTex_3), 
                    _UseScreenUV_3, _UseGlobalTiling_3, _DetialTex_3_ST, scale);
        finalColor *= detail_3;
    #endif

    #if _F_DETIALTEX_4_ON
        float4 detail_4 = GetDetailTex(input.uv, screenUV, 
                    TEXTURE2D_ARGS(_DetialTex_4, sampler_DetialTex_4), 
                    _UseScreenUV_4, _UseGlobalTiling_4, _DetialTex_4_ST, scale);
        finalColor *= detail_4;
    #endif

    #if _F_DETIALTEX_5_ON
        float4 detail_5 = GetDetailTex(input.uv, screenUV, 
                    TEXTURE2D_ARGS(_DetialTex_5, sampler_DetialTex_5), 
                    _UseScreenUV_5, _UseGlobalTiling_5, _DetialTex_5_ST, scale);
        finalColor *= detail_5;
    #endif

    // dissolve
    #if _F_DISSOLVE_ON
        float4 dissolve = GetDetailTex(input.uv, screenUV, 
                    TEXTURE2D_ARGS(_DissolveTex, sampler_DissolveTex), 
                    0, _UseGlobalTiling_D, _DissolveTex_ST, scale);
        
        // (1~2) - (0~2) clamp to (0~1)
        dissolve.rgb = clamp((dissolve.rgb + 1) - _DissolveThreshold * 2, 0, 1);
        finalColor.rgb *= dissolve;
    #endif

    return finalColor;
} 




#endif
