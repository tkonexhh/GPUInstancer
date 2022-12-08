#ifndef DECALDIRTPBR_FORWARD_PASS_INCLUDED
#define DECALDIRTPBR_FORWARD_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

#define REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR

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
    float2 uv                       : TEXCOORD0;
    half3 normalWS                  : TEXCOORD2;
#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
    half4 tangentWS                 : TEXCOORD3;    // xyz: tangent, w: sign
#endif
    float3 viewDirWS                : TEXCOORD4;

    float4  positionNDC             : TEXCOORD7;

    float3 rayVS 		            : TEXCOORD10;

    float4 positionCS               : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

void InitializeInputData(Varyings input, half3 normalTS, float3 positionWS, out InputData inputData)
{
    inputData = (InputData)0;

    inputData.positionWS = positionWS;

    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(positionWS);
#if defined(_NORMALMAP)
    float sgn = input.tangentWS.w;      // should be either +1 or -1
    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
    half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);

    #if defined(_NORMALMAP)
    inputData.tangentToWorld = tangentToWorld;
    #endif
    inputData.normalWS = TransformTangentToWorld(normalTS, tangentToWorld);
#else
    inputData.normalWS = input.normalWS;
#endif

    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    inputData.viewDirectionWS = viewDirWS;

    inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);

    inputData.bakedGI = SampleSH(input.normalWS.xyz);

    float4 newPositionCS = TransformWorldToHClip(positionWS);
    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(newPositionCS);

}

// -----------------------------------------------------------------------------
// Vertex
Varyings DecalDirtPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

    output.uv = TRANSFORM_TEX(input.texcoord, _MainTex);

    // 这里修改法线为始终朝向世界的Up
    // output.normalWS = normalInput.normalWS;
    output.normalWS = float3(0.0, 1.0, 0.0);
    #if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
        half4 tangentWS = half4(0.0, 0.0, 1.0, 1.0);
    #endif
    #if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
        output.tangentWS = tangentWS;
    #endif

    output.positionNDC = vertexInput.positionNDC;

    // 这里不使用烘焙的光照贴图

    output.rayVS = TransformWorldToView(TransformObjectToWorld(input.positionOS.xyz)) * float3(-1, -1, 1);

    output.positionCS = vertexInput.positionCS;

    return output;
}

float2 DoDecal(Varyings input, out float3 positionWS)
{
    float2 screenUV = input.positionNDC.xy * rcp(input.positionNDC.w);

    float rawDepth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV).r;
    float sceneZ = (unity_OrthoParams.w == 0) ? LinearEyeDepth(rawDepth, _ZBufferParams) : LinearDepthToEyeDepth(rawDepth);
    float3 surfacePositionVS = input.rayVS * sceneZ / input.rayVS.z;

    float4 surfacePositionWS = mul(unity_CameraToWorld, float4(surfacePositionVS, 1));
    float3 surfacePositionOS = TransformWorldToObject(surfacePositionWS.xyz);

    // 剔除掉在立方体外面的内容
    clip(float3(0.5, 0.5, 0.5) - abs(surfacePositionOS));

    // 使用物体空间坐标的xy坐标作为采样uv 方便进行形变调整
    float2 uv = surfacePositionOS.xy + 0.5;
    uv = TRANSFORM_TEX(uv, _MainTex);

    positionWS = surfacePositionWS.xyz;

    return uv;
}

#if _F_DISSOLVE_ON
    float Warp(float input, float a, float b)
    {
        input = saturate((input - a) / (b - a));
        return input;
    }
    float GetDissolveEdge(float dissolveTex)
    {
        float spread = clamp(_DissolveSpread, 0.00001, 0.999999);
        float edgeWidth = _DissolveEdgeWidth;
        float threshold = _DissolveThreshold * (1 + edgeWidth);

        float dissolve_1 = 2 - (threshold * (2 - spread) + dissolveTex);
        dissolve_1 = Warp(dissolve_1, spread, 1);
        return dissolve_1;
    }
    void DissolveFunc(half dissolveTex, half threshold, half spread, half edgeWidth, half4 edgeColor, float dissolve_1, inout half4 finalColor)
    {
        spread = clamp(spread, 0.00001, 0.999999);
        threshold *= (1 + edgeWidth);

        half dissolve_2 = 2 - ((threshold - edgeWidth) * (2- spread) + dissolveTex);
        dissolve_2 = Warp(dissolve_2, spread, 1);

        finalColor.rgb *= lerp(edgeColor.rgb, 1, dissolve_1);
        finalColor.a *= dissolve_2;
    }
#endif

// -----------------------------------------------------------------------------
// Fragment
half4 DecalDirtPassFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);

    float3 surfacePositionWS;
    // 计算decal的uv和世界坐标
    float2 uv = DoDecal(input, surfacePositionWS);

    SurfaceData surfaceData;
    InitializeStandardLitSurfaceData(uv, surfaceData);

    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, surfacePositionWS, inputData);

    // 如果都往一个方向偏，效果会比较明显
    inputData.normalWS = lerp(inputData.normalWS, float3(0,0,1), 1 - surfaceData.alpha);

    #if _F_DISSOLVE_ON
        float2 dissolveUV = TRANSFORM_TEX(uv, _DissolveTex);
        float dissolveTex = SAMPLE_TEXTURE2D(_DissolveTex, sampler_DissolveTex, dissolveUV)[(int)_DissolveChannel];
        dissolveTex = lerp(dissolveTex, 1 - dissolveTex, _DissolveInvert);
        half dissolveThreshold = _DissolveThreshold;

        // 先获取边缘，对边缘的法线进行旋转
        float dissolveEdge = GetDissolveEdge(dissolveTex);
        // 如果都往一个方向偏，效果会比较明显
        inputData.normalWS = lerp(inputData.normalWS, float3(0,0,1), 1 - dissolveEdge);
    #endif

    SETUP_DEBUG_TEXTURE_DATA(inputData, uv, _MainTex);

    // 这里不使用DBuffer的贴花

    half4 color = UniversalFragmentPBR(inputData, surfaceData);

    // Dissolve
    #if _F_DISSOLVE_ON
        DissolveFunc(dissolveTex, dissolveThreshold, _DissolveSpread, _DissolveEdgeWidth, _DissolveEdgeColor, dissolveEdge, color);
    #endif

    // 这里不使用fog

    return color;
}

#endif