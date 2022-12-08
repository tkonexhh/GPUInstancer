#ifndef FOLIAGE_FORWARD_PASS_INCLUDED
#define FOLIAGE_FORWARD_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "FoliageDebugging3D.hlsl"

// TODO 第二套UV存储其他数据情况
struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
    float4 color        : COLOR;
    float2 texcoord     : TEXCOORD0;
    float2 staticLightmapUV   : TEXCOORD1;
    float2 dynamicLightmapUV  : TEXCOORD2;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv                       : TEXCOORD0;
    float4 positionWS               : TEXCOORD1;    // xyz: positionWS, w:topLerpColor
    half3 normalWS                  : TEXCOORD2;
    half4 tangentWS                 : TEXCOORD3;    // xyz: tangent, w: sign
    float4 color                    : TEXCOORD4;
    float4 centerAOColor            : TEXCOORD5;
    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        float4 shadowCoord          : TEXCOORD6;
    #endif

    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 7);
    #ifdef DYNAMICLIGHTMAP_ON
        float2  dynamicLightmapUV   : TEXCOORD8; // Dynamic lightmap UVs
    #endif
    #ifdef _NEARCAMERAFADE_ON
        float4 positionNDC          : TEXCOORD9;
    #endif
    float4 positionCS               : SV_POSITION;
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
Varyings FoliageForwardPassVertex(Attributes input)
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
        output.positionWS.w = saturate(dot(normalInput.normalWS.xyz, float3(0,1,0)) * _TopLerpScale + _TopLerpOffset);
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
half4 FoliageForwardPassFragment(Varyings input, FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC) : SV_Target
#else
half4 FoliageForwardPassFragment(Varyings input) : SV_Target
#endif
{
    UNITY_SETUP_INSTANCE_ID(input);

    #ifdef _BACKFACEFLIPNORMAL_ON
        //是否为正面
        bool isFront = IS_FRONT_VFACE(cullFace, true, false);
        if(isFront == false)
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
    #if defined(DEBUG_DISPLAY)
        SETUP_DEBUG_TEXTURE_DATA_FOLIAGE(inputData, input.uv, _MainTex);
    #endif

    #if _F_TOPLERP_ON
        surfaceData.albedo = lerp(surfaceData.albedo, _TopLerpColor.rgb, input.positionWS.w);
    #endif

    BRDFData brdfData;
    InitializeBRDFData(surfaceData.albedo, surfaceData.metallic, 0, surfaceData.smoothness, surfaceData.alpha, brdfData);

    #if defined(DEBUG_DISPLAY)
    half4 debugColor;

    if (CanDebugOverrideOutputColor_Foliage(inputData, surfaceData, brdfData, debugColor))
    {
        return debugColor;
    }
    #endif


    Light mainLight = GetMainLight(inputData.shadowCoord, inputData.positionWS, inputData.shadowMask);
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, inputData.shadowMask);

    // half4 color = UniversalFragmentPBR(inputData, surfaceData.albedo, surfaceData.metallic, 0, surfaceData.smoothness, 1, 0, surfaceData.alpha);
    // return color;

    // 对于光照一些的debug支持并没有，所以这里先不显示
    clip(-1);
    return half4(0, 0, 0, 1);
}

#endif
