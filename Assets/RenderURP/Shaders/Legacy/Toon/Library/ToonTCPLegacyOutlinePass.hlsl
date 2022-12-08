
#ifndef TOON_TCP_LEGACY_OUTLINE_INCLUDED
#define TOON_TCP_LEGACY_OUTLINE_INCLUDED

// -----------------------------------------------------------------
struct Attributes
{
    float4 positionOS       : POSITION;
    float3 normalOS         : NORMAL;
    float4 texcoord         : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 color            : TEXCOORD0;
    float4 positionCS       : SV_POSITION;
};

// -----------------------------------------------------------
// Vertex
Varyings ToonTCPLegacyOutlineVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);

    // TODO 暂时为了兼容老版本 其实直接用uv是没意义的 存粹只是一个巧合看起来细了
	#if _NORMALSSOURCE_FACE
        float3 normalOS = input.texcoord.xyz;
    #else
        float3 normalOS = input.normalOS;
    #endif

    output.positionCS = TransformObjectToHClip(input.positionOS.xyz + normalOS * _OutlineWidth * 0.01);
    output.color = _OutlineColorVertex;

    return output;
}

// -----------------------------------------------------------
// Fragment
half4 ToonTCPLegacyOutlineFragment(Varyings input) : SV_TARGET
{
    UNITY_SETUP_INSTANCE_ID(input);

    return float4(input.color.rgb, 1);
}

#endif
