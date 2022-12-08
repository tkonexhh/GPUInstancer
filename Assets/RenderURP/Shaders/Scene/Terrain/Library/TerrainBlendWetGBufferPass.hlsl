#ifndef TERRAINBLENDWET_GBUFFER_PASS_INCLUDED
#define TERRAINBLENDWET_GBUFFER_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"


struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
    float2 texcoord     : TEXCOORD0;
    float2 staticLightmapUV   : TEXCOORD1;
    float2 dynamicLightmapUV  : TEXCOORD2;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv                       : TEXCOORD0;
    float3 positionWS               : TEXCOORD1;
    half3 normalWS                  : TEXCOORD2;
#if defined(_NORMALMAP)
    half4 tangentWS                 : TEXCOORD3;    // xyz: tangent, w: sign
#endif
#ifdef _ADDITIONAL_LIGHTS_VERTEX
    half3 vertexLighting            : TEXCOORD4;    // xyz: vertex lighting
#endif
#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    float4 shadowCoord              : TEXCOORD5;
#endif
// #if defined(_PARALLAXMAP)
    half3 viewDirTS                 : TEXCOORD6;
// #endif
    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 7);
#ifdef DYNAMICLIGHTMAP_ON
    float2  dynamicLightmapUV       : TEXCOORD8; // Dynamic lightmap UVs
#endif
    float4 positionCS               : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

#if _F_PUDDLE_ON
    float3 CalculatePuddle(float2 uv, half3x3 TBN, float3 viewDirWS, inout SurfaceData surfaceData)
    {
        //
        float puddle_mask = SAMPLE_TEXTURE2D(_PuddleMask, sampler_PuddleMask, TRANSFORM_TEX(uv, _PuddleMask)).r;
        #if _PUDDLEMASKINVERT_ON
            puddle_mask = 1 - puddle_mask;
        #endif

        puddle_mask = CalculateContrast(_PuddleMaskContrast + 1.0, float4(puddle_mask, puddle_mask, puddle_mask, 1)).r;
        puddle_mask = clamp(puddle_mask - _PuddleMaskSpread, 0, 1) * _PuddleMaskIntensity;

        //
        float3 normal_puddle = float3(0, 0, 1);
        #if _F_PUDDLENORMAL_ON
            // 切线空间法线
            normal_puddle = GetNormalPuddle(TEXTURE2D_ARGS(_PuddleNormalMap, sampler_PuddleNormalMap), 
                uv, _PuddleNormalTiling_1, _PuddleNormalRotation_1, _PuddleNormalSpeed_1, _PuddleNormalIntensity_1);
            #if _F_PUDDLENORMAL_2_ON
                float3 normal_puddle_2 = GetNormalPuddle(TEXTURE2D_ARGS(_PuddleNormalMap, sampler_PuddleNormalMap), 
                    uv, _PuddleNormalTiling_2, _PuddleNormalRotation_2, _PuddleNormalSpeed_2, _PuddleNormalIntensity_2);
                normal_puddle = BlendNormalRNM(normal_puddle, normal_puddle_2);
            #endif
        #endif
        
        //
        float3 normal_ripple = float3(0, 0, 1);
        #if _F_RIPPLE_ON
            float4 ripple_st = GetRippleAnim_ST(_RippleColRowSpeedStart);

            float2 ripple_uv_1 = uv * _RippleNormalTiling;
            normal_ripple = GetNormalPipple(TEXTURE2D_ARGS(_RippleNormalMap, sampler_RippleNormalMap),
                                ripple_uv_1, ripple_st, _RippleNormalIntensity_1);

            #if _F_RIPPLENORMAL_2_ON
                float2 ripple_uv_2 = ripple_uv_1 / _RippleNormalScale_2 + _RippleNormalOffset_2;
                ripple_uv_2 = Get_UV_Rotation(_RippleNormalRotation_2, ripple_uv_2);
                float3 normal_ripple_2 = GetNormalPipple(TEXTURE2D_ARGS(_RippleNormalMap, sampler_RippleNormalMap),
                                    ripple_uv_2, ripple_st, _RippleNormalIntensity_2);

                normal_ripple = BlendNormalRNM(normal_ripple, normal_ripple_2);
            #endif
        #endif

        // 波纹+涟漪
        float3 normal_final = BlendNormalRNM(normal_puddle, normal_ripple);

        #if _PUDDLENORMALBLENDMAIN_ON
            normal_final = BlendNormalRNM(surfaceData.normalTS, normal_final);
        #endif
        normal_final = lerp(surfaceData.normalTS, normal_final, puddle_mask);
        // 法线转到世界空间
        float3 normalWS = TransformTangentToWorld(normal_final, TBN);

        //
        half3 normal_reflect = normalize(reflect(viewDirWS, normalWS));
        float4 refl = SAMPLE_TEXTURECUBE_LOD(_PuddleReflectCubemap, sampler_PuddleReflectCubemap, normal_reflect, _PuddleReflectBlur);
        refl *= (refl.a * _PuddleReflectIntensity) * _PuddleReflectColor * puddle_mask;
        // Emission
        surfaceData.emission = refl.rgb;
        // Metallic
        surfaceData.metallic = lerp(surfaceData.metallic, _PuddleMetallic, puddle_mask);

        // Smoothness
        #if _F_RAINDOT_ON
            float roughness = Get_Roughness_Voronoi(TEXTURE2D_ARGS(_RainDotGradientTex, sampler_RainDotGradientTex), 
                            uv, _RainDotTiling, _RainDotSpeed, _RainDotSize, _RainDotIntensity);
            surfaceData.smoothness = surfaceData.smoothness * (1.0 - roughness) + roughness;
        #endif
        surfaceData.smoothness = lerp(surfaceData.smoothness, _PuddleSmoothness, puddle_mask);

        // Albedo
        #if _ADDPUDDLETEX_ON
            float3 albedo_puddle = SAMPLE_TEXTURE2D(_PuddleTex, sampler_PuddleTex, TRANSFORM_TEX(uv, _PuddleTex)).rgb;
        #else
            float3 albedo_puddle = surfaceData.albedo;
        #endif
        albedo_puddle *= _PuddleColor;

        surfaceData.albedo = lerp(surfaceData.albedo, albedo_puddle, puddle_mask);

        #if _DEBUGSHOWPUDDLEMASK_ON
            surfaceData.albedo = puddle_mask;
        #endif

        return normalWS;
    }
#endif

void InitializeInputData(Varyings input, inout SurfaceData surfaceData, out InputData inputData)
{
    inputData = (InputData)0;

    inputData.positionWS = input.positionWS;
    inputData.positionCS = input.positionCS;

    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    inputData.viewDirectionWS = viewDirWS;

    #if defined(_NORMALMAP)
        float sgn = input.tangentWS.w;      // should be either +1 or -1
        float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
        half3x3 TBN = half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);
    #endif

    // 雨地默认打开法线
    #if _F_PUDDLE_ON
        inputData.normalWS = CalculatePuddle(input.uv, TBN, viewDirWS, surfaceData);
    #else
        #if defined(_NORMALMAP)
            inputData.normalWS = TransformTangentToWorld(surfaceData.normalTS, TBN);
        #else
            inputData.normalWS = input.normalWS;
        #endif
    #endif

   
    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        inputData.shadowCoord = input.shadowCoord;
    #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
        inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
    #else
        inputData.shadowCoord = float4(0, 0, 0, 0);
    #endif

    inputData.fogCoord = 0.0; // we don't apply fog in the guffer pass

    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        inputData.vertexLighting = input.vertexLighting.xyz;
    #else
        inputData.vertexLighting = half3(0, 0, 0);
    #endif

    #if defined(DYNAMICLIGHTMAP_ON)
        inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV, input.vertexSH, inputData.normalWS);
    #else
        inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, inputData.normalWS);
    #endif

    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);
}

// -------------------------------------------------------------------------------
// Vertex
Varyings TerrainGBufferPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    output.uv = input.texcoord;
    output.normalWS = normalInput.normalWS;

    #if defined(_NORMALMAP) || defined(_PARALLAXMAP)
        real sign = input.tangentOS.w * GetOddNegativeScale();
        half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);

        #if defined(_NORMALMAP)
            output.tangentWS = tangentWS;
        #endif
        #if defined(_PARALLAXMAP)
            half3 viewDirWS = GetWorldSpaceNormalizeViewDir(vertexInput.positionWS);
            half3 viewDirTS = GetViewDirectionTangentSpace(tangentWS, output.normalWS, viewDirWS);
            output.viewDirTS = viewDirTS;
        #endif
    #endif
   
    OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
    #ifdef DYNAMICLIGHTMAP_ON
        output.dynamicLightmapUV = input.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
    #endif
    OUTPUT_SH(output.normalWS.xyz, output.vertexSH);

    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
        output.vertexLighting = vertexLight;
    #endif

    output.positionWS = vertexInput.positionWS;

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        output.shadowCoord = GetShadowCoord(vertexInput);
    #endif

    output.positionCS = vertexInput.positionCS;

    return output;
}

// -------------------------------------------------------------------------------
// Fragment
FragmentOutput TerrainGBufferPassFragment(Varyings input)
{
    UNITY_SETUP_INSTANCE_ID(input);

    SurfaceData surfaceData;
    InitializeTerrainBlendSurfaceData(input.viewDirTS, input.uv, surfaceData);

    InputData inputData;
    InitializeInputData(input, surfaceData, inputData);

    #ifdef _DBUFFER
        ApplyDecalToSurfaceData(input.positionCS, surfaceData, inputData);
    #endif

    BRDFData brdfData;
    InitializeBRDFData(surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.alpha, brdfData);

    Light mainLight = GetMainLight(inputData.shadowCoord, inputData.positionWS, inputData.shadowMask);
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, inputData.shadowMask);
    #ifdef _SCREEN_SPACE_REFLECTION
        half3 color = inputData.bakedGI * brdfData.diffuse * surfaceData.occlusion;
    #else
        half3 color = GlobalIllumination(brdfData, inputData.bakedGI, surfaceData.occlusion, inputData.positionWS, inputData.normalWS, inputData.viewDirectionWS);
    #endif
    return BRDFDataToGbuffer(brdfData, inputData, surfaceData.smoothness, surfaceData.emission + color, surfaceData.occlusion);
}

#endif
