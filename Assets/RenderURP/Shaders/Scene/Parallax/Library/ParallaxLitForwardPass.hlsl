#ifndef PARALLAXLIT_FORWARDPASS_INCLUDED
    #define PARALLAXLIT_FORWARDPASS_INCLUDED

    // 视差贴图需要
    #define REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR 1

    // 由于define顺序， _PARALLAXMAP在Input.hlsl和GBufferPass.hlsl都要声明一次
    #ifdef _F_PARALLAX_ON
        #define _PARALLAXMAP 1
    #endif

    #define REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR 1

    #ifndef _SPECULARHIGHLIGHTS_ON
        #define _SPECULARHIGHLIGHTS_OFF 1
    #endif
    #ifndef _ENVIRONMENTREFLECTIONS_ON
        #define _ENVIRONMENTREFLECTIONS_OFF 1
    #endif

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

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

        #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
            float3 positionWS               : TEXCOORD1;
        #endif

        half3 normalWS                  : TEXCOORD2;
        #if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
            half4 tangentWS                 : TEXCOORD3;    // xyz: tangent, w: sign
        #endif
        #ifdef _ADDITIONAL_LIGHTS_VERTEX
            half3 vertexLighting            : TEXCOORD4;    // xyz: vertex lighting
        #endif

        #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
            float4 shadowCoord              : TEXCOORD5;
        #endif

        #if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
            half3 viewDirTS                 : TEXCOORD6;
        #endif

        DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 7);
        #ifdef DYNAMICLIGHTMAP_ON
            float2  dynamicLightmapUV       : TEXCOORD8; // Dynamic lightmap UVs
        #endif

        // MARK_INUTAN
        #ifdef _NEARCAMERAFADE_ON
            float4 positionNDC              : TEXCOORD9;
        #endif

        float4 positionCS               : SV_POSITION;
        UNITY_VERTEX_INPUT_INSTANCE_ID
        UNITY_VERTEX_OUTPUT_STEREO
    };



    void InitializeInputData(Varyings input, half3 normalTS, out InputData inputData)
    {
        inputData = (InputData)0;

        #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
            inputData.positionWS = input.positionWS;
        #endif

        inputData.positionCS = input.positionCS;
        half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
        #if defined(_NORMALMAP) || defined(_DETAIL)
            float sgn = input.tangentWS.w;      // should be either +1 or -1
            float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
            inputData.normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz));
        #else
            inputData.normalWS = input.normalWS;
        #endif

        inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
        inputData.viewDirectionWS = viewDirWS;

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

    ///////////////////////////////////////////////////////////////////////////////
    //                  Vertex and Fragment functions                            //
    ///////////////////////////////////////////////////////////////////////////////

    Varyings ParallaxLitForwardPassVertex(Attributes input)
    {
        Varyings output = (Varyings)0;

        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_TRANSFER_INSTANCE_ID(input, output);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

        VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
        // MARK_INUTAN
        #ifdef _NEARCAMERAFADE_ON
            output.positionNDC = vertexInput.positionNDC;
        #endif

        // normalWS and tangentWS already normalize.
        // this is required to avoid skewing the direction during interpolation
        // also required for per-vertex lighting and SH evaluation
        VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

        output.uv = TRANSFORM_TEX(input.texcoord, _MainTex);

        // already normalized from normal transform to WS.
        output.normalWS = normalInput.normalWS;

        #if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR) || defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
            real sign = input.tangentOS.w * GetOddNegativeScale();
            half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);
        #endif

        #if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
            output.tangentWS = tangentWS;
        #endif

        #if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
            half3 viewDirWS = GetWorldSpaceNormalizeViewDir(vertexInput.positionWS);
            half3 viewDirTS = GetViewDirectionTangentSpace(tangentWS, output.normalWS, viewDirWS);
            output.viewDirTS = viewDirTS;
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

        #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
            output.positionWS = vertexInput.positionWS;
        #endif

        #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
            output.shadowCoord = GetShadowCoord(vertexInput);
        #endif

        output.positionCS = vertexInput.positionCS;

        return output;
    }

    half4 ParallaxLitForwardPassFragment(Varyings input) : SV_Target
    {
        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

        // 需要定义视差图
        #if defined(_PARALLAXMAP)
            #if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
                half3 viewDirTS = input.viewDirTS;
            #else
                half3 viewDirTS = GetViewDirectionTangentSpace(input.tangentWS, input.normalWS, input.viewDirWS);
            #endif
            ApplyPerPixelDisplacement(viewDirTS, input.uv);
        #endif

        SurfaceData surfaceData;
        InitializeStandardLitSurfaceData(input.uv, surfaceData);

        InputData inputData;
        InitializeInputData(input, surfaceData.normalTS, inputData);
        #ifdef _DEBUG_DISPLAY
            SETUP_DEBUG_TEXTURE_DATA(inputData, input.uv, _BaseMap);
        #endif

        // #ifdef _DBUFFER
        //     ApplyDecalToSurfaceData(input.positionCS, surfaceData, inputData);
        // #endif

        // forward暂时没做闪点功能

        half4 color = UniversalFragmentPBR(inputData, surfaceData);

        return color;
    }

#endif