
#ifndef TOON_SKIN_INCLUDED
#define TOON_SKIN_INCLUDED

#include "ToonSkinInput.hlsl"
#include "ToonSkinCore.hlsl"
#include "ToonLightFades.hlsl"

// -----------------------------------------------------------
// Vertex
Varyings ToonSkinVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    output.uvs = float4(input.texcoord0, input.texcoord1);
    output.positionWS = vertexInput.positionWS;
    output.normalWS = normalInput.normalWS;

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        output.shadowCoord = GetShadowCoord(vertexInput);
    #endif

    // 通过欧拉角获取头部旋转矩阵
    float3x3 eulerMatrix = EulerToMartix(_FaceDirRotation.xyz);
    output.headDirRightWS.xyz = mul(eulerMatrix, float3(1,0,0));
    output.headDirForwardWS.xyz = mul(eulerMatrix, float3(0,0,1));

    output.positionCS = vertexInput.positionCS;

    // 如果开了sdf阴影，对头部周围八个点进行阴影采样平均
    #if _FACE_SHADE_ON
        ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
        half4 shadowParams = GetMainLightShadowParams();
        float shadowBoxSizeHalf = 0.6;
        float shadowAverageResult = 0;
        float3 zeroPositionWS = TransformObjectToWorld(float3(0,0,0));
        // 8个点呈圆形排布
        shadowAverageResult += SampleShadowmap(TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture), TransformWorldToShadowCoord(zeroPositionWS + float3(0,shadowBoxSizeHalf,shadowBoxSizeHalf)), shadowSamplingData, shadowParams, false);
        shadowAverageResult += SampleShadowmap(TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture), TransformWorldToShadowCoord(zeroPositionWS + float3(0.382683426176 * shadowBoxSizeHalf,shadowBoxSizeHalf, 0.923879535075 * shadowBoxSizeHalf)), shadowSamplingData, shadowParams, false);
        shadowAverageResult += SampleShadowmap(TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture), TransformWorldToShadowCoord(zeroPositionWS + float3(0.707106771713 * shadowBoxSizeHalf,shadowBoxSizeHalf, 0.70710679066 * shadowBoxSizeHalf)), shadowSamplingData, shadowParams, false);
        shadowAverageResult += SampleShadowmap(TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture), TransformWorldToShadowCoord(zeroPositionWS + float3(0.923879524821 * shadowBoxSizeHalf,shadowBoxSizeHalf, 0.382683450932 * shadowBoxSizeHalf)), shadowSamplingData, shadowParams, false);
        shadowAverageResult += SampleShadowmap(TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture), TransformWorldToShadowCoord(zeroPositionWS + float3(shadowBoxSizeHalf,shadowBoxSizeHalf, 0)), shadowSamplingData, shadowParams, false);
        shadowAverageResult += SampleShadowmap(TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture), TransformWorldToShadowCoord(zeroPositionWS + float3(0.923879545329 * shadowBoxSizeHalf,shadowBoxSizeHalf, -0.382683401421 * shadowBoxSizeHalf)), shadowSamplingData, shadowParams, false);
        shadowAverageResult += SampleShadowmap(TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture), TransformWorldToShadowCoord(zeroPositionWS + float3(0.707106809607 * shadowBoxSizeHalf,shadowBoxSizeHalf, -0.707106752766 * shadowBoxSizeHalf)), shadowSamplingData, shadowParams, false);
        shadowAverageResult += SampleShadowmap(TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture), TransformWorldToShadowCoord(zeroPositionWS + float3(0.382683475687 * shadowBoxSizeHalf,shadowBoxSizeHalf, -0.923879514567 * shadowBoxSizeHalf)), shadowSamplingData, shadowParams, false);
        shadowAverageResult *= 0.125;
        output.faceShadeAverage = shadowAverageResult;
    #endif

    return output;
}

// -----------------------------------------------------------
// Fragment
half4 ToonSkinFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);

    float2 uv0 = input.uvs.xy;

    // 法线
    float3 N = normalize(input.normalWS);
    half3 V = GetWorldSpaceNormalizeViewDir(input.positionWS);

    // --------------------------------------------------------------------
    CalculateColors Cals;
    GetConfigInfo(uv0, Cals);

    // 摄像机关于FOV和距离的缩放
    float cameraDisFade = GetCameraFade(input.positionWS.xyz);

    Light mainLight = GetMainLight(input);
    half shadowAttenuation = 1;
    half3 directColor = GetDirectColor(input, N, Cals, mainLight, shadowAttenuation);

    // 边缘光
    half3 fresnelColor = 0;
    #if _F_FRESNEL_ON
        #if _DEBUGFRESNEL_ON
            half fresnelDebug = 0;
            GetFresnelColor(uv0, N, N, V, mainLight.direction, Cals, fresnelDebug);
            return fresnelDebug;
        #else
            fresnelColor = GetFresnelColor(uv0, N, N, V, mainLight.direction, Cals) * mainLight.color;
            fresnelColor *= 1.0 - cameraDisFade;
        #endif
    #endif

    // 直接光部分
    half3 finalColor = directColor + fresnelColor;

    // 间接光部分
    #if _F_INDIRECT_ON
        finalColor += GetIndirectColor(N, V, Cals);
    #endif

    #if _DEBUGOUTLINEMASK_ON
        return half4(SAMPLE_TEXTURE2D(_OutlineMask, sampler_OutlineMask, uv0));
    #endif

    // 如果不使用阴影，不应该在压黑的时候处理阴影区域。
    #ifndef _USESHADOWMAP_ON
        shadowAttenuation = 1.0;
    #endif

    // 压黑
    DoCharacterDark(input.positionWS, cameraDisFade, shadowAttenuation, finalColor);

    ApplyGlobalSettings_Exposure(finalColor);

    return half4(finalColor, 1);
}

#endif
