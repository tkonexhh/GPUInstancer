#ifndef FOLIAGE_GBUFFER_PASS_INCLUDED
#define FOLIAGE_GBUFFER_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"

// TODO 第二套UV存储其他数据情况
struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float4 color : COLOR;
    float2 texcoord : TEXCOORD0;
    float2 staticLightmapUV : TEXCOORD1;
    float2 dynamicLightmapUV : TEXCOORD2;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv : TEXCOORD0;
    float4 positionWS : TEXCOORD1;    // xyz: positionWS, w:topLerpColor
    half3 normalWS : TEXCOORD2;
    half4 tangentWS : TEXCOORD3;    // xyz: tangent, w: sign
    float4 color : TEXCOORD4;
    float4 centerAOColor : TEXCOORD5;
    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        float4 shadowCoord : TEXCOORD6;
    #endif

    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 7);
    #ifdef DYNAMICLIGHTMAP_ON
        float2 dynamicLightmapUV : TEXCOORD8; // Dynamic lightmap UVs
    #endif
    #ifdef _NEARCAMERAFADE_ON
        float4 positionNDC : TEXCOORD9;
    #endif
    float4 positionCS : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

void InitializeInputData(Varyings input, half3 normalTS, out InputData inputData)
{
    inputData = (InputData)0;

    inputData.positionWS = input.positionWS.xyz;
    inputData.positionCS = input.positionCS;
    #if defined(_NORMALMAP)
        float sgn = input.tangentWS.w;      // should be either +1 or -1
        float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
        inputData.normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz));
    #else
        inputData.normalWS = input.normalWS;
    #endif
    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);

    inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS.xyz);

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        inputData.shadowCoord = input.shadowCoord;
    #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
        inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS.xyz);
    #else
        inputData.shadowCoord = float4(0, 0, 0, 0);
    #endif

    inputData.fogCoord = 0.0; // we don't apply fog in the guffer pass

    #if defined(DYNAMICLIGHTMAP_ON)
        inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV, input.vertexSH, inputData.normalWS);
    #else
        inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, inputData.normalWS);
    #endif

    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);
}

// ----------------------------------------------------------------------------
// Vertex
Varyings FoliageGBufferPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);

    // ----------------------------------------------------------------------------------------------------------
    // 顶点色
    output.color = input.color;
    #if _F_WIND_ON
        #if _WINDTYPE_TREE
            VertexWind(input.texcoord, input.tangentOS.xyz,
            _WindDir, _WindPower, _WindTreeCenter,
            input.positionOS);
        #else
            VertexWindVegetation(input.color, input.normalOS,
            _WindDir, _BranchStrength, _WaveStrength, _DetailStrength, _DetailFrequency,
            input.positionOS);
        #endif
    #endif

    // 色相调整 顶点部分数据
    #if _F_HUEVARIATION_ON
        float hueVariationAmount = _HueVariationColor.a;
        #if _HUEVARIETY_ON
            hueVariationAmount *= 0.5 + frac(input.positionOS.x + input.normalOS.y + input.normalOS.x) * 0.5;
        #endif
        output.color.g = saturate(hueVariationAmount);
    #endif

    // 中心AO点
    #if _F_CENTERAO_ON
        float distance = length(input.positionOS.xyz - _CenterAOPosition);
        float center_ao = saturate(pow(max(distance / _CenterAOStrength, 0), _CenterAOPower));
        float3 center_aocolor = lerp(_CenterAOColor.rgb, 1, center_ao);
        output.centerAOColor.rgb = center_aocolor;
        output.centerAOColor.a = center_ao;
    #endif
    // 中心法线
    #if _USENORMALTHIEF_ON
        input.normalOS = normalize(input.positionOS.xyz - _NormalThiefPosition.xyz);
    #endif


    // ----------------------------------------------------------------------------------------------------------
    // ShaderVariablesFunctions.hlsl

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

    #ifdef _NEARCAMERAFADE_ON
        output.positionNDC = vertexInput.positionNDC;
    #endif
    // TBN
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    #if _F_TOPLERP_ON
        output.positionWS.w = saturate(dot(normalInput.normalWS.xyz, float3(0, 1, 0)) * _TopLerpScale + _TopLerpOffset);
        output.positionWS.w *= smoothstep(_TopLerpParams.y, _TopLerpParams.x, input.positionOS.y);
    #endif

    output.uv = TRANSFORM_TEX(input.texcoord, _MainTex);

    output.normalWS = normalInput.normalWS;
    real sign = input.tangentOS.w * GetOddNegativeScale();
    half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);
    output.tangentWS = tangentWS;

    OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
    #ifdef DYNAMICLIGHTMAP_ON
        output.dynamicLightmapUV = input.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
    #endif
    OUTPUT_SH(output.normalWS.xyz, output.vertexSH);

    output.positionWS.xyz = vertexInput.positionWS;

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        output.shadowCoord = GetShadowCoord(vertexInput);
    #endif

    output.positionCS = vertexInput.positionCS;

    return output;
}

// ----------------------------------------------------------------------------
// Fragment
#define kMaterialFlagFoliageOn           16


#ifdef _BACKFACEFLIPNORMAL_ON
    FragmentOutput FoliageGBufferPassFragment(Varyings input, FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC)
#else
    FragmentOutput FoliageGBufferPassFragment(Varyings input)
#endif
{
    UNITY_SETUP_INSTANCE_ID(input);

    #ifdef _BACKFACEFLIPNORMAL_ON
        //是否为正面
        bool isFront = IS_FRONT_VFACE(cullFace, true, false);
        if (isFront == false)
        {
            input.normalWS *= -1;
        }
    #endif

    FoliageSurfaceData surfaceData;
    half lightMask = 1;
    half transmissionMask = 1;
    InitializeFoliageSurfaceData(input.uv, input.color, input.positionWS.xyz, input.centerAOColor, surfaceData, lightMask, transmissionMask);

    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, inputData);
    SETUP_DEBUG_TEXTURE_DATA(inputData, input.uv, _MainTex);

    #ifdef _NEARCAMERAFADE_ON
        #ifdef _GLOBAL_USE_CAMERAFADE
            #ifdef _GLOBALRENDERSETTINGSENABLEKEYWORD
                float cameraFadeType = _GLOBAL_CAMERAFADE_PARAMS.x;
            #else
                float cameraFadeType = 1;
            #endif

            float centerMask = 0.5 - length(input.positionNDC.xy * rcp(input.positionNDC.w) - 0.5);
            half3 positionVS = TransformWorldToView(input.positionWS.xyz);
            float fade = 1;
            if (cameraFadeType == 5)
            {
                float depthFade = smoothstep(0, 10, -positionVS.z);
                fade = lerp(lerp(0.15, 0, centerMask), depthFade, depthFade);
            }
            else
            {
                fade = length(positionVS) * lerp(0.15, 0, centerMask);
            }
            fade = saturate(lerp(-1, 1, fade));

            float dither = 1;
            if (cameraFadeType == 1 || cameraFadeType == 5)
                dither = (1.0 / 4.0) * (half) (frac((input.positionCS.y - input.positionCS.x) / 4.0) * 4.0);
            if (cameraFadeType == 2)
                dither = GenerateHashedRandomFloat(input.positionCS.xy * (_ScaledScreenParams.zw - 1) * 32768); // LODDitheringTransition函数里的方法, 但把屏幕大小映射一下
            if (cameraFadeType == 3)
            {
                // 玻璃用的
                #define ditherPattern float4x4(0.0, 0.5, 0.125, 0.625, 0.75, 0.22, 0.875, 0.375, 0.1875, 0.6875, 0.0625, 0.5625, 0.9375, 0.4375, 0.8125, 0.3125)
                dither = ditherPattern[fmod(input.positionCS.x, 4)][fmod(input.positionCS.y, 4)];
            }
            if (cameraFadeType == 4)
                dither = frac(dot(float3(input.positionCS.xy, 0.5f), float3(0.40625f, 0.15625f, 0.46875f))); // 大网眼
            clip(fade - CopySign(dither, fade));
        #endif
    #endif

    #if _F_TOPLERP_ON
        surfaceData.albedo = lerp(surfaceData.albedo, _TopLerpColor.rgb, input.positionWS.w);
    #endif

    BRDFData brdfData;
    InitializeBRDFData(surfaceData.albedo, surfaceData.metallic, 0, surfaceData.smoothness, surfaceData.alpha, brdfData);
    Light mainLight = GetMainLight(inputData.shadowCoord, inputData.positionWS, inputData.shadowMask);
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, inputData.shadowMask);

    #ifdef _GLOBALRENDERSETTINGSENABLEKEYWORD
        // 间接光漫反射 (SH or lightmap)
        inputData.bakedGI *= _GLOBAL_INDIRECT_DIFFUSE_COLOR.rgb;
    #endif

    // 间接光部分直接在cameraRT中 StencilDeferred处理直接光部分
    #ifdef _SCREEN_SPACE_REFLECTION
        half3 color = inputData.bakedGI * brdfData.diffuse * surfaceData.occlusion;
    #else
        half3 color = GlobalIllumination(brdfData, inputData.bakedGI, surfaceData.occlusion, inputData.positionWS, inputData.normalWS, inputData.viewDirectionWS);
    #endif

    #ifdef _GLOBALRENDERSETTINGSENABLEKEYWORD
        // 控制直接光部分强度
        brdfData.albedo *= _GLOBAL_INDIRECT_ADJUST_PARAMS.r;
    #endif

    FragmentOutput output = BRDFDataToGbuffer(brdfData, inputData, surfaceData.smoothness, color, surfaceData.occlusion);

    // -----------------------------------------------------------------------------------
    // 植物 deferred 特殊标记
    uint materialFlags = UnpackMaterialFlags(output.GBuffer0.a);
    materialFlags |= kMaterialFlagFoliageOn;
    output.GBuffer0.a = PackMaterialFlags(materialFlags);
    // GBuffer1  metallic/specular specular        specular        occlusion
    // occlusion 本来是用来处理SSAO的 舍弃
    #ifdef _F_TRANSMISSION_ON
        output.GBuffer1.g = _TransmissionFakeRange;
        output.GBuffer1.b = _TransmissionScale * 0.2;
    #else
        output.GBuffer1.g = 0;
        output.GBuffer1.b = 0;
    #endif
    #ifdef _TRANSMISSIONUSEMASKMAP_ON
        output.GBuffer1.b *= transmissionMask;
    #endif
    output.GBuffer1.a = lightMask;
    // -----------------------------------------------------------------------------------

    #if _F_MATCAP_ON
        output.GBuffer3.rgb += GetMatcapColor(surfaceData.albedo, inputData.normalWS);
    #endif

    // 调试用
    #if _DEBUGSHOWAO_ON || _DEBUGSHOWNORMAL_ON || _DEBUGSHOWWIND_ON || _TOPLERPDEBUG_ON
        #if _DEBUGSHOWAO_ON
            output.GBuffer3 = surfaceData.ao;
        #elif _DEBUGSHOWNORMAL_ON
            output.GBuffer3 = float4(inputData.normalWS, 1);
        #elif _DEBUGSHOWWIND_ON
            output.GBuffer3 = input.color.b;
        #elif _TOPLERPDEBUG_ON
            output.GBuffer3.rgb = lerp(0, 1, input.positionWS.w);
        #endif
        output.GBuffer0 = 0;
        output.GBuffer1 = 0;
        output.GBuffer2 = float4(0, 0, 1, 0);
    #endif

    return output;
}

#endif
