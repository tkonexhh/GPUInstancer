#ifndef FOLIAGE_DEBUGGING3D_INCLUDED
    #define FOLIAGE_DEBUGGING3D_INCLUDED

    // Ensure that we always include "DebuggingCommon.hlsl" even if we don't use it - saves extraneous includes elsewhere...
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Debug/DebuggingCommon.hlsl"

    #if defined(DEBUG_DISPLAY)
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/BRDF.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RealtimeLights.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

        #define SETUP_DEBUG_TEXTURE_DATA_FOLIAGE(inputData, uv, texture)    SetupDebugDataTexture_Foliage(inputData, uv, texture##_TexelSize, texture##_MipInfo, GetMipCount(TEXTURE2D_ARGS(texture, sampler##texture)))

        void SetupDebugDataTexture_Foliage(inout InputData inputData, float2 uv, float4 texelSize, float4 mipInfo, uint mipCount)
        {
            inputData.uv = uv;
            inputData.texelSize = texelSize;
            inputData.mipInfo = mipInfo;
            inputData.mipCount = mipCount;
        }

        bool UpdateSurfaceAndInputDataForDebug(inout FoliageSurfaceData surfaceData, inout InputData inputData)
        {
            bool changed = false;

            if (_DebugLightingMode == DEBUGLIGHTINGMODE_LIGHTING_WITHOUT_NORMAL_MAPS || _DebugLightingMode == DEBUGLIGHTINGMODE_LIGHTING_WITH_NORMAL_MAPS)
            {
                surfaceData.albedo = 1;
                surfaceData.occlusion = 1;
                surfaceData.metallic = 0;
                surfaceData.smoothness = 0;
                changed = true;
            }
            else if (_DebugLightingMode == DEBUGLIGHTINGMODE_REFLECTIONS || _DebugLightingMode == DEBUGLIGHTINGMODE_REFLECTIONS_WITH_SMOOTHNESS)
            {
                surfaceData.albedo = 0;
                surfaceData.occlusion = 1;
                surfaceData.metallic = 0;
                if (_DebugLightingMode == DEBUGLIGHTINGMODE_REFLECTIONS)
                {
                    surfaceData.smoothness = 1;
                }
                changed = true;
            }

            if (_DebugLightingMode == DEBUGLIGHTINGMODE_LIGHTING_WITHOUT_NORMAL_MAPS || _DebugLightingMode == DEBUGLIGHTINGMODE_REFLECTIONS)
            {
                const half3 normalTS = half3(0, 0, 1);
                #if defined(_NORMALMAP)
                    inputData.normalWS = TransformTangentToWorld(normalTS, inputData.tangentToWorld);
                #else
                    inputData.normalWS = inputData.normalWS;
                #endif
                surfaceData.normalTS = normalTS;
                changed = true;
            }

            return changed;
        }


        half4 CalculateDebugLightingComplexityColor_Foliage(in InputData inputData, in FoliageSurfaceData surfaceData)
        {
            // Assume a main light and add 1 to the additional lights.
            int numLights = GetAdditionalLightsCount() + 1;

            const uint2 tileSize = uint2(32,32);
            const uint maxLights = 9;
            const float opacity = 0.8f;

            uint2 pixelCoord = uint2(inputData.normalizedScreenSpaceUV * _ScreenParams.xy);
            half3 base = surfaceData.albedo;
            half4 overlay = half4(OverlayHeatMap(pixelCoord, tileSize, numLights, maxLights, opacity));

            uint2 tileCoord = (float2)pixelCoord / tileSize;
            uint2 offsetInTile = pixelCoord - tileCoord * tileSize;
            bool border = any(offsetInTile == 0 || offsetInTile == tileSize.x - 1);
            if (border)
            overlay = half4(1, 1, 1, 0.4f);

            return half4(lerp(base.rgb, overlay.rgb, overlay.a), 1);
        }

        bool CalculateColorForDebugMaterial_Foliage(in InputData inputData, in FoliageSurfaceData surfaceData, inout half4 debugColor)
        {
            // Debug materials...
            switch(_DebugMaterialMode)
            {
                case DEBUGMATERIALMODE_NONE:
                return false;

                case DEBUGMATERIALMODE_ALBEDO:
                debugColor = half4(surfaceData.albedo, 1);
                return true;

                case DEBUGMATERIALMODE_SPECULAR:
                debugColor = half4(0, 0, 0, 1);
                return true;

                case DEBUGMATERIALMODE_ALPHA:
                debugColor = half4(surfaceData.alpha.rrr, 1);
                return true;

                case DEBUGMATERIALMODE_SMOOTHNESS:
                debugColor = half4(surfaceData.smoothness.rrr, 1);
                return true;

                case DEBUGMATERIALMODE_AMBIENT_OCCLUSION:
                debugColor = half4(surfaceData.occlusion.rrr, 1);
                return true;

                case DEBUGMATERIALMODE_EMISSION:
                debugColor = half4(0, 0, 0, 1);
                return true;

                case DEBUGMATERIALMODE_NORMAL_WORLD_SPACE:
                debugColor = half4(inputData.normalWS.xyz * 0.5 + 0.5, 1);
                return true;

                case DEBUGMATERIALMODE_NORMAL_TANGENT_SPACE:
                debugColor = half4(surfaceData.normalTS.xyz * 0.5 + 0.5, 1);
                return true;

                case DEBUGMATERIALMODE_METALLIC:
                debugColor = half4(surfaceData.metallic.rrr, 1);
                return true;

                default:
                return TryGetDebugColorInvalidMode(debugColor);
            }
        }

        bool CalculateValidationColorForDebug_Foliage(in InputData inputData, in FoliageSurfaceData surfaceData, inout half4 debugColor)
        {
            switch(_DebugMaterialValidationMode)
            {
                case DEBUGMATERIALVALIDATIONMODE_NONE:
                return false;

                case DEBUGMATERIALVALIDATIONMODE_ALBEDO:
                return CalculateValidationAlbedo(surfaceData.albedo, debugColor);

                case DEBUGMATERIALVALIDATIONMODE_METALLIC:
                return CalculateValidationMetallic(surfaceData.albedo, surfaceData.metallic, debugColor);

                default:
                return TryGetDebugColorInvalidMode(debugColor);
            }
        }

        bool CalculateColorForDebug_Foliage(in InputData inputData, in FoliageSurfaceData surfaceData, inout half4 debugColor)
        {
            if (CalculateColorForDebugSceneOverride(debugColor))
            {
                return true;
            }
            else if (CalculateColorForDebugMaterial_Foliage(inputData, surfaceData, debugColor))
            {
                return true;
            }
            else if (CalculateValidationColorForDebug_Foliage(inputData, surfaceData, debugColor))
            {
                return true;
            }
            else
            {
                return false;
            }
        }

        bool CanDebugOverrideOutputColor_Foliage(inout InputData inputData, inout FoliageSurfaceData surfaceData, inout BRDFData brdfData, inout half4 debugColor)
        {
            if (_DebugMaterialMode == DEBUGMATERIALMODE_LIGHTING_COMPLEXITY)
            {
                debugColor = CalculateDebugLightingComplexityColor_Foliage(inputData, surfaceData);
                return true;
            }
            else
            {
                debugColor = half4(0, 0, 0, 1);

                if (_DebugLightingMode == DEBUGLIGHTINGMODE_SHADOW_CASCADES)
                {
                    surfaceData.albedo = CalculateDebugShadowCascadeColor(inputData);
                    debugColor = half4(surfaceData.albedo, 1.0);
                    return true;
                }
                else
                {
                    if (UpdateSurfaceAndInputDataForDebug(surfaceData, inputData))
                    {
                        // If we've modified any data we'll need to re-sample the GI to ensure that everything works correctly...
                        #if defined(DYNAMICLIGHTMAP_ON)
                            inputData.bakedGI = SAMPLE_GI(inputData.staticLightmapUV, inputData.dynamicLightmapUV.xy, inputData.vertexSH, inputData.normalWS);
                        #else
                            inputData.bakedGI = SAMPLE_GI(inputData.staticLightmapUV, inputData.vertexSH, inputData.normalWS);
                        #endif
                    }
                }

                // Update the BRDF data following any changes to the input/surface above...
                InitializeBRDFData(surfaceData.albedo, surfaceData.metallic, 0, surfaceData.smoothness, surfaceData.alpha, brdfData);

                return CalculateColorForDebug_Foliage(inputData, surfaceData, debugColor);
            }
        }

    #endif

#endif