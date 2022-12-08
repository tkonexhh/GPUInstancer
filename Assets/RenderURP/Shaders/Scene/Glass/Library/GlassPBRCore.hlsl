#ifndef GLASSPBR_CORE_INCLUDED
#define GLASSPBR_CORE_INCLUDED

// --------------------------------------------------------------------------------------
// 间接镜面反射自定义
half3 GlassGlossyEnvironmentReflection(half3 reflectVector, float3 positionWS, half perceptualRoughness, half occlusion)
{
    half3 irradiance;

    #if !defined(_ENVIRONMENTREFLECTIONS_OFF)

        #ifdef _REFLECTION_PROBE_BOX_PROJECTION
            reflectVector = BoxProjectedCubemapDirection(reflectVector, positionWS, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
        #endif // _REFLECTION_PROBE_BOX_PROJECTION

        half mip = PerceptualRoughnessToMipmapLevel(perceptualRoughness);

        #if _USEREFLECTCUBEMAP_ON
            // 自定义环境反射cubemap
            half4 encodedIrradiance = half4(SAMPLE_TEXTURECUBE_LOD(_ReflectCubemap, sampler_ReflectCubemap, reflectVector, mip));
        #else
            half4 encodedIrradiance = half4(SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectVector, mip));
        #endif

        irradiance = encodedIrradiance.rgb;
    #else
        irradiance = _GlossyEnvironmentColor.rgb;
    #endif // _ENVIRONMENTREFLECTIONS_OFF

    irradiance *= occlusion * _FresnelColor.rgb * _FresnelStrength;

    return irradiance;
}

// --------------------------------------------------------------------------------------
// 间接光部分自定义
half3 GlassGlobalIllumination(BRDFData brdfData, BRDFData brdfDataClearCoat, float clearCoatMask,
half3 bakedGI, half occlusion, float3 positionWS,
half3 normalWS, half3 viewDirectionWS)
{
    half3 reflectVector = reflect(-viewDirectionWS, normalWS);
    half NoV = saturate(dot(normalWS, viewDirectionWS));
    // TODO 改成Pow5
    half fresnelTerm = Pow4(1.0 - NoV) * (1.0 - NoV);

    half3 indirectDiffuse = bakedGI;
    // 间接镜面反射自定义
    half3 indirectSpecular = GlassGlossyEnvironmentReflection(reflectVector, positionWS, brdfData.perceptualRoughness, 1.0h);

    half3 color = EnvironmentBRDF(brdfData, indirectDiffuse, indirectSpecular, fresnelTerm);

    return color * occlusion;
}

//---------------------------------------------------------------------------------
//bgolus's original source code: https://forum.unity.com/threads/interior-mapping.424676/#post-2751518
//this reusable InteriorUVFunction.hlsl is created base on bgolus's original source code
//for param "roomMaxDepth01Define": input 0.0001 if room is a "near 0 volume" room, input 0.9999 if room is a "near inf depth" room
#ifdef _INTERIORDEPTHDEBUG_ON
    float2 ConvertOriginalRawUVToInteriorUV(float2 originalRawUV, float3 viewDirTangentSpace, float roomMaxDepth01Define, out float debugInterp)
#else
    float2 ConvertOriginalRawUVToInteriorUV(float2 originalRawUV, float3 viewDirTangentSpace, float roomMaxDepth01Define)
#endif
{
    originalRawUV = originalRawUV * _InteriorTex_ST.xy + _InteriorTex_ST.zw;

    //remap [0,1] to [+inf,0]
    //->if input roomMaxDepth01Define = 0    -> depthScale = +inf   (0 volume room)
    //->if input roomMaxDepth01Define = 0.5  -> depthScale = 1
    //->if input roomMaxDepth01Define = 1    -> depthScale = 0              (inf depth room)
    float depthScale = rcp(roomMaxDepth01Define) - 1.0;

    //normalized box space is a space where room's min max corner = (-1,-1,-1) & (+1,+1,+1)
    //apply simple scale & translate to tangent space = transform tangent space to normalized box space

    //now prepare ray box intersection test's input data in normalized box space
    float3 viewRayStartPosBoxSpace = float3(originalRawUV * 2 - 1, -1); //normalized box space's ray start pos is on trinagle surface, where z = -1
    float3 viewRayDirBoxSpace = viewDirTangentSpace * float3(1, 1, -depthScale);//transform input ray dir from tangent space to normalized box space

    // 我们的假室内可以使用长方形图，这里应用宽高比
    float xyScale = max(_InteriorXYScale, 0.001);
    float xyRate = max(_InteriorWidthRate, 0.001);
    viewRayDirBoxSpace *= float3(xyScale, xyScale * xyRate, 1.0);

    //do ray & axis aligned box intersection test in normalized box space (all input transformed to normalized box space)
    //intersection test function used = https://www.iquilezles.org/www/articles/intersectors/intersectors.htm
    //============================================================================
    float3 viewRayDirBoxSpaceRcp = rcp(viewRayDirBoxSpace);

    //hitRayLengthForSeperatedAxis means normalized box space depth hit per x/y/z plane seperated
    //(we dont care about near hit result here, we only want far hit result)
    float3 hitRayLengthForSeperatedAxis = abs(viewRayDirBoxSpaceRcp) - viewRayStartPosBoxSpace * viewRayDirBoxSpaceRcp;
    //shortestHitRayLength = normalized box space real hit ray length
    float shortestHitRayLength = min(min(hitRayLengthForSeperatedAxis.x, hitRayLengthForSeperatedAxis.y), hitRayLengthForSeperatedAxis.z);
    //normalized box Space real hit pos = rayOrigin + t * rayDir.
    float3 hitPosBoxSpace = viewRayStartPosBoxSpace + shortestHitRayLength * viewRayDirBoxSpace;
    //============================================================================

    // remap from [-1,1] to [0,1] room depth
    float interp = hitPosBoxSpace.z * 0.5 + 0.5;

    // 远平面debug显示
    #ifdef _INTERIORDEPTHDEBUG_ON
        debugInterp = interp;
    #endif

    // account for perspective in "room" textures
    // assumes camera with an fov of 53.13 degrees (atan(0.5))
    //hard to explain, visual result = transform nonlinear depth back to linear
    float realZ = saturate(interp) / depthScale + 1;
    interp = 1.0 - (1.0 / realZ);
    interp *= depthScale + 1.0;

    //linear iterpolate from wall back to near
    float2 interiorUV = hitPosBoxSpace.xy * lerp(1.0, 1 - roomMaxDepth01Define, interp);

    //convert back to valid 0~1 uv, ready for user's tex2D() call
    interiorUV = interiorUV * 0.5 + 0.5;

    #ifdef _F_INTERIORATLAS_ON
        // 我们的假室内可以用一张图上存多张
        float4 atlasST = 0;
        int index = (int)max(_InteriorIndex, 0);
        int posy = floor(index / _InteriorXCount);
        int posx = fmod(index, _InteriorXCount);
        atlasST.xy = float2(1.0 / _InteriorXCount, 1.0 / _InteriorYCount);
        atlasST.zw = atlasST.xy * float2((uint)posx, _InteriorYCount - 1 - (uint)posy);
        interiorUV = interiorUV * atlasST.xy + atlasST.zw;
    #endif
    return interiorUV;
}

// TODO 公用函数整合
float2 Get_UV_Rotation(float rad, float2 uv)
{
    float2 cos_sin = float2(cos(rad), sin(rad));
    float2x2 rotation = float2x2(cos_sin.x, -cos_sin.y, cos_sin.y, cos_sin.x);

    return mul(uv - 0.5, rotation) + 0.5;
}


// --------------------------------------------------------------------------------------
// 假室内窗户上的贴花
#if _INTERIORDECALUSEPBR_ON
    void GlassCalculateInteriorDecal(float2 uv, float3 viewDirTangentSpace, Varyings input, InputData inputData, SurfaceData surfaceData, inout half3 color)
#else
    void GlassCalculateInteriorDecal(float2 uv, float3 viewDirTangentSpace, Varyings input, SurfaceData surfaceData, inout half3 color)
#endif
{
    #if __RENDERMODE_OPAQUE && _F_INTERIORDECAL_ON
        float2 decalUV = uv * _InteriorDecalTex_ST.xy + _InteriorDecalTex_ST.zw;
        // 让窗户贴花可以有一个深度
        // 有几层Tilling变换，为了保持深度正确，这里有一个稍复杂的长宽比矫正
        decalUV -= (viewDirTangentSpace.xy / viewDirTangentSpace.z) * float2(_InteriorTex_ST.y * _InteriorDecalTex_ST.x, _InteriorWidthRate * _InteriorTex_ST.x * _InteriorDecalTex_ST.y) * _InteriorDecalDepth;

        // 法线对interior的扰动
        #if _NORMALMAP
            float3 bump = normalize(surfaceData.normalTS);
            decalUV += bump.xy;
        #endif

        float4 decalTex = SAMPLE_TEXTURE2D(_InteriorDecalTex, sampler_InteriorDecalTex, decalUV);
        #ifndef _INTERIORDECALUSETILLING_ON
            bool offScreen = any(abs(decalUV.xy * 2 - 1) >= 1.0f);
            if (offScreen)
                decalTex = 0;
        #endif
        float decalAlpha = decalTex.a;
        float3 decalColor = decalTex.rgb;

        // decal的所有PBR部分将使用half计算。希望尽量少消耗。

        // 使用法线贴图 ?
        #if _INTERIORDECALUSENORMALMAP_ON
            half4 normalMap = SAMPLE_TEXTURE2D(_InteriorDecalBumpMap, sampler_InteriorDecalBumpMap, decalUV);
            half3 normalTS = UnpackNormalScale(normalMap, _InteriorDecalBumpScale);
            half sgn = input.tangentWS.w;      // should be either +1 or -1
            half3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
            half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);
            half3 normalWS = TransformTangentToWorld(normalTS, tangentToWorld);
        #else
            half3 normalWS = input.normalWS.xyz;
        #endif

        // 无参数获取mainLight，这个函数不会对阴影进行采样。
        Light mainLight = GetMainLight();

        // 开启了PBR选项 ?
        #if _INTERIORDECALUSEPBR_ON
            half2 metalSmoothness = SAMPLE_TEXTURE2D(_InteriorDecalMetalMap, sampler_InteriorDecalMetalMap, decalUV).ra;
            half metallic = metalSmoothness.r * _InteriorDecalMetallic;
            half smoothness = metalSmoothness.g * _InteriorDecalGlossiness;

            BRDFData brdfData;
            half fakeAlpha = 1;
            InitializeBRDFData(decalColor, metallic, 0, smoothness, fakeAlpha, brdfData);

            decalColor = LightingPhysicallyBased(brdfData, mainLight, normalWS, inputData.viewDirectionWS) * decalAlpha;
            decalColor += GlobalIllumination(brdfData, inputData.bakedGI, 1, inputData.positionWS, normalWS, inputData.viewDirectionWS) * decalAlpha;
        #else
            half NdotL = dot(normalWS, mainLight.direction);
            decalColor *= NdotL * 0.5 + 0.5;
        #endif

        // alpha blend 注意 此时 _ALPHAPREMULTIPLY_ON 是打开的
        color = lerp(color, decalColor, decalAlpha);
    #endif
}

// --------------------------------------------------------------------------------------
// 贴片反射 和 假室内
void GlassCalculateInterior(float2 uv, float4 viewDirTSorPositionNDC, Varyings input, InputData inputData, SurfaceData surfaceData, inout half4 color)
{
    // 贴片反射
    #if _F_FAKEREF_ON
        half fresnel = pow(1.0 - saturate(dot(inputData.viewDirectionWS, inputData.normalWS)), _FakeRefPow);
        half2 offset = (TransformObjectToWorld(0) - GetCameraPositionWS() * _FakeRefSpeed).xz;

        float2 fake_uv = Get_UV_Rotation(_FakeRefRotation * PI / 180, lerp(uv, 0, _FakeRefTwinkle) + offset);

        half4 fake_ref = SAMPLE_TEXTURE2D(_FakeRefTex, sampler_FakeRefTex, fake_uv);
        color.rgb += fake_ref.rgb * _FakeRefIntensity * fresnel * _FakeRefColor.rgb;
    #endif

    // interior
    #if __RENDERMODE_OPAQUE && _F_INTERIOR_ON
        #ifdef _INTERIORDEPTHDEBUG_ON
            float outDebugInterp = 0;
            float2 interiorUV = ConvertOriginalRawUVToInteriorUV(uv, -viewDirTSorPositionNDC.xyz, _InteriorDepth, outDebugInterp);
        #else
            float2 interiorUV = ConvertOriginalRawUVToInteriorUV(uv, -viewDirTSorPositionNDC.xyz, _InteriorDepth);
        #endif

        // 法线对interior的扰动
        #if _NORMALMAP
            float3 bump = normalize(surfaceData.normalTS);
            interiorUV.xy += bump.xy;
        #endif

        float3 interior = SAMPLE_TEXTURE2D(_InteriorTex, sampler_InteriorTex, interiorUV).rgb;
        // 再传入一张模糊好的图模拟毛玻璃部分
        #if _USEINTERIORBLUR_ON
            float3 interior_blur = SAMPLE_TEXTURE2D(_InteriorBlurTex, sampler_InteriorBlurTex, interiorUV).rgb;
            float roughness = PerceptualSmoothnessToRoughness(surfaceData.smoothness);
            // 模糊好的图需要保留一定细节所以不能太糊 对应到粗糙度 这里可能需要进行缩放 方便统一范围
            interior = lerp(interior, interior_blur, saturate(roughness/**2*/));
        #endif
        interior *= _InteriorColor.rgb * _InteriorIntensity;

        // 假室内窗户贴花
        #if _INTERIORDECALUSEPBR_ON
            GlassCalculateInteriorDecal(uv, -viewDirTSorPositionNDC.xyz, input, inputData, surfaceData, interior);
        #else
            GlassCalculateInteriorDecal(uv, -viewDirTSorPositionNDC.xyz, input, surfaceData, interior);
        #endif

        // 远平面位置debug
        #ifdef _INTERIORDEPTHDEBUG_ON
            if (abs(outDebugInterp - 1) <= 0.001)
            {
                color.rgba = float4(0.01, 0.1, 0.02, 0.9);
            }
        #endif

        // alpha blend 注意 此时 _ALPHAPREMULTIPLY_ON 是打开的
        color.rgb = color.rgb * color.a + interior * (1 - color.a);
        color.a = 1.0;
    #elif _F_REFRACTION_ON
        half3 grabColor = GetGrabColor(viewDirTSorPositionNDC, surfaceData.normalTS).rgb;
        // alpha blend 注意 此时 _ALPHAPREMULTIPLY_ON 是打开的
        color.rgb = color.rgb * color.a + grabColor * (1 - color.a);
        color.a = 1.0;
    #endif
}


// --------------------------------------------------------------------------------------
// PBR lighting
half4 GlassFragmentPBR(float2 uv, float4 viewDirTSorPositionNDC, InputData inputData, SurfaceData surfaceData, Varyings vertexInputs)
{
    #if defined(_SPECULARHIGHLIGHTS_OFF)
        bool specularHighlightsOff = true;
    #else
        bool specularHighlightsOff = false;
    #endif
    BRDFData brdfData;

    InitializeBRDFData(surfaceData, brdfData);

    #if defined(DEBUG_DISPLAY)
        half4 debugColor;

        if (CanDebugOverrideOutputColor(inputData, surfaceData, brdfData, debugColor))
        {
            return debugColor;
        }
    #endif

    // Clear-coat calculation...
    BRDFData brdfDataClearCoat = CreateClearCoatBRDFData(surfaceData, brdfData);
    half4 shadowMask = CalculateShadowMask(inputData);
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
    uint meshRenderingLayers = GetMeshRenderingLightLayer();
    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);

    // NOTE: We don't apply AO to the GI here because it's done in the lighting calculation below...
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);

    LightingData lightingData = CreateLightingData(inputData, surfaceData);

    // 间接光部分自定义
    lightingData.giColor = GlassGlobalIllumination(brdfData, brdfDataClearCoat, surfaceData.clearCoatMask,
    inputData.bakedGI, aoFactor.indirectAmbientOcclusion, inputData.positionWS,
    inputData.normalWS, inputData.viewDirectionWS);

    if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
    {
        lightingData.mainLightColor = LightingPhysicallyBased(brdfData, brdfDataClearCoat,
        mainLight,
        inputData.normalWS, inputData.viewDirectionWS,
        surfaceData.clearCoatMask, specularHighlightsOff);
    }

    // TODO 玻璃就先不受点光源影响了 点光源布光产生的高光有时候效果不好
    // #if defined(_ADDITIONAL_LIGHTS)
    //     uint pixelLightCount = GetAdditionalLightsCount();

    //     #if USE_CLUSTERED_LIGHTING
    //         for (uint lightIndex = 0; lightIndex < min(_AdditionalLightsDirectionalCount, MAX_VISIBLE_LIGHTS); lightIndex++)
    //         {
    //             Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

    //             if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
    //             {
    //                 lightingData.additionalLightsColor += LightingPhysicallyBased(brdfData, brdfDataClearCoat, light,
    //                                                                             inputData.normalWS, inputData.viewDirectionWS,
    //                                                                             surfaceData.clearCoatMask, specularHighlightsOff);
    //             }
    //         }
    //     #endif

    //     LIGHT_LOOP_BEGIN(pixelLightCount)
    //         Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

    //         if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
    //         {
    //             // 点光源 会变成负值 TODO 有问题
    //             lightingData.additionalLightsColor += abs(LightingPhysicallyBased(brdfData, brdfDataClearCoat, light,
    //                                                                         inputData.normalWS, inputData.viewDirectionWS,
    //                                                                         surfaceData.clearCoatMask, specularHighlightsOff));
    //         }
    //     LIGHT_LOOP_END
    // #endif

    // #if defined(_ADDITIONAL_LIGHTS_VERTEX)
    //     lightingData.vertexLightingColor += inputData.vertexLighting * brdfData.diffuse;
    // #endif

    half4 finalColor = CalculateFinalColor(lightingData, surfaceData.alpha);

    // 贴片反射 和 假室内 或 折射
    GlassCalculateInterior(uv, viewDirTSorPositionNDC, vertexInputs, inputData, surfaceData, finalColor);

    return finalColor;
}









#endif
