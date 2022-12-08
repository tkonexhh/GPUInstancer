// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Inutan/URP/Scene/Foliage/Foliage 植物"
{
    Properties
    {
        // level/style/toggle/open/showlist
        [Foldout(1, 1, 0, 1)] _F_PBR("基础_Foldout", float) = 1
        [Enum_Switch(Both, Back, Front)] _CullFoliage("面渲染模式", Float) = 0.0

        [Tex(_Color)]_MainTex("基础贴图 (Albedo)", 2D) = "white" {}
        [HideInInspector]_Color("基础颜色", Color) = (1, 1, 1, 1)

        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.33

        [Toggle_Switch] _NearCameraFade("Near Camera Fade (Editor默认不使用)", Float) = 0.0

        [Foldout(2, 2, 0, 1)] _F_Mask("Mask_Foldout", float) = 1
        [Tex(_)][NoScaleOffset]_MaskMap("Mask R:金属度 G:光照遮罩 B:透射遮罩 A:光滑度", 2D) = "white" {}
        _UseLightMaskForLight("光照遮罩影响光照强度", Range(0, 1)) = 1

        [Enum_Switch(MetallicValue, MetallicTexture)] _MetallicUse("金属度 值/图", float) = 0
        [Switch(MetallicValue)]_MetallicValue("金属度", Range(0.0, 1.0)) = 0.0
        [Switch(MetallicTexture)]_MetallicScale("金属度缩放", Range(0.0, 1.0)) = 0.0

        [Enum_Switch(Value, Texture)] _MetallicGlossUse("光滑度 值/图", float) = 0
        [Switch(Value)]_Glossiness("光滑度", Range(0.0, 1.0)) = 0.0
        [Switch(Texture)]_GlossMapScale("光滑度缩放", Range(0.0, 1.0)) = 1.0

        [Foldout_Out(2)] _F_Mask_Out("F_Mask_Out_Foldout", float) = 1

        [Foldout(2, 2, 0, 1)] _F_Normal("法线_Foldout", float) = 1
        [Toggle_Switch] _BackFaceFlipNormal("反面反转法线", float) = 0
        [Toggle_Switch] _UseNormalMap("使用法线贴图", float) = 0
        [Tex(_BumpScale, _UseNormalMap)][NoScaleOffset] _BumpMap("法线贴图", 2D) = "bump" {}
        [HideInInspector]_BumpScale("法线缩放", float) = 1.0

        [Toggle_Switch] _UseNormalThief("使用中心调整法线", float) = 0
        [Switch(_UseNormalThief)]_NormalThiefPosition("中心坐标 XYZ", Vector) = (0, 0, 0, 0)
        [Toggle_Switch] _DebugShowNormal("显示法线 (调试用)", float) = 0
        [Foldout_Out(2)] _F_Normal_Out("F_Normal_Out_Foldout", float) = 1

        [Foldout(2, 2, 1, 1)] _F_HueVariation("色相变化_Foldout", float) = 0

        _HueVariationColor ("颜色 (Alpha表示强度)", Color) = (1.0,0.5,0.0,0.1)
        [Toggle_Switch]_HueVariety("杂色 (根据叶片原始法线和顶点位置微调强度)", float) = 0

        [Foldout(1, 1, 0, 1)] _F_AO("AO_Foldout", float) = 1
        [Toggle_Switch] _DebugShowAO("显示AO (调试用)", float) = 0

        [Foldout(2, 2, 1, 1)] _F_VertexAO("顶点AO(顶点色R通道)_Foldout", float) = 0
        _VertexAOPower("顶点AO强度", Range(1, 15)) = 1
        _VertexAOColor("顶点AO颜色", Color) = (0, 0, 0, 0)

        [Foldout(2, 2, 1, 1)] _F_CenterAO("中心AO_Foldout", float) = 0
        [Vector3(1)]_CenterAOPosition("中心AO位置 XYZ", float) = (0, 0, 0, 0)
        _CenterAOPower("中心AO渐变", Range(1, 15)) = 1
        _CenterAOStrength("中心AO强度", Range(0, 100)) = 1
        _CenterAOColor("中心AO颜色", Color) = (0, 0, 0, 0)
        [Foldout_Out(2)] _F_CenterAO_Out("F_CenterAO_Out_Foldout", float) = 1

        [Foldout(1, 1, 1, 1)] _F_Transmission("透射(应用灯光颜色)_Foldout", float) = 1
        _TransmissionScale("透射强度", Range(0, 5)) = 1
        _TransmissionFakeRange("透射范围扩大", Range(0, 0.5)) = 0.2
        [Toggle_Switch] _TransmissionUseMaskMap("使用透射遮罩(MaskMap.b)", Float) = 0

        [Foldout(1, 1, 1, 1)] _F_TopLerp("高度渐变_Foldout", float) = 0
        _TopLerpColor("颜色", Color) = (1, 1, 1, 1)
        _TopLerpScale("亮度缩放", Range(0, 1)) = 0.3
        _TopLerpOffset("亮度加", Range(-1, 1)) = 0.0
        _TopLerpParams("参数(X: 最高, Y: 最低)", Vector) = (20, 1, 0, 0)
        [Toggle_Switch]_TopLerpDebug("调试显示", float) = 0
        [Foldout_Out(1)] _F_TopLerpColor_Out("F_TopLerpColor_Out_Foldout", float) = 1
        //
        [Foldout(1, 1, 1, 1)] _F_Matcap("Matcap_Foldout", float) = 0
        [Tex][NoScaleOffset] _MatcapTex("Matcap贴图", 2D) = "white" {}
        _MatcapScale("缩放", Range(1, 10)) = 1
        _MatcapRotation("旋转", Range(0, 360)) = 0
        [Tex][NoScaleOffset] _MatcapRampTex("Ramp贴图", 2D) = "white" {}
        [HDR] _MatcapRampColor("颜色", Color) = (1, 1, 1, 1)
        _MatcapRampTilingExp("TilingExp", Range(0.2, 4)) = 1
        _MatcapGlowExp("过度", Range(0.2, 8)) = 1
        _MatcapGlowAmount("强度", Range(0, 10)) = 1
        [Toggle_Switch] _MatcapMultiBaseColor("混合固有色贴图", float) = 1
        [Foldout_Out(1)] _F_Matcap_Out("F_Matcap_Out_Foldout", float) = 1

        [Foldout(1, 1, 1, 1)] _F_Wind("风 (综合)_Foldout", float) = 0
        [Vector3(0)]_WindDir("风向", float) = (0, 0, 1, 1)
        [Toggle_Switch] _DebugShowWind("(调试用)", float) = 0

        [Enum_Switch(Tree, Vegetation)] _WindType("风类型 (树 / 草木)", float) = 0

        [Foldout(2, 2, 0, 1, Tree)] _F_Wind_Tree("风 (树)_Foldout", float) = 1
        _WindPower("风力", Range(0, 5)) = 1
        [Vector3(1)]_WindTreeCenter("树根锚点", Vector) = (0, 0, 0, 0)
        [Foldout_Out(2)] _F_Wind_Tree_Out("F_Wind_Tree_Out_Foldout", float) = 1

        [Foldout(2, 2, 0, 1, Vegetation)] _F_Wind_Vegetation("风 (草木)_Foldout", float) = 1
        _BranchStrength("主干摆动强度", Range(0, 1)) = 0
        _WaveStrength("整体波动强度", Range(0, 1)) = 0
        _DetailStrength("细节抖动强度 (可能造成法线闪烁)", Range(0, 1)) = 0
        _DetailFrequency("细节抖动频率", Range(0, 1)) = 1
        [Foldout_Out(2)] _F_Wind_Vegetation_Out("F_Wind_Vegetation_Out_Foldout", float) = 1

        // --------------------------------------------
        [Foldout_Out(1)] _F_Out("F_Out_Foldout", float) = 1

        // Blending state
        [HideInInspector] _SrcBlend ("__src", Float) = 1.0
        [HideInInspector] _DstBlend ("__dst", Float) = 0.0

    }

    SubShader
    {
        Tags { "RenderType"="TransparentCutout" "Queue"="AlphaTest" "IgnoreProjector"="True" "DisableBatching"="LODFading" "RenderPipeline" = "UniversalPipeline" "UniversalMaterialType" = "Lit"}

        // ------------------------------------------------------------------
        //  Deferred pass
        Pass
        {
            Name "GBuffer"
            Tags { "LightMode" = "UniversalGBuffer" }

            Cull [_CullFoliage]
            Blend One Zero

            HLSLPROGRAM
            #pragma target 3.0
            #pragma exclude_renderers nomrt

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _NEARCAMERAFADE_ON
            #pragma shader_feature_local _METALLICUSE_METALLICVALUE _METALLICUSE_METALLICTEXTURE
            #pragma shader_feature_local _METALLICGLOSSUSE_VALUE _METALLICGLOSSUSE_TEXTURE
            #pragma shader_feature_local _BACKFACEFLIPNORMAL_ON
            #pragma shader_feature_local _USENORMALMAP_ON

            #pragma shader_feature_local _F_VERTEXAO_ON
            #pragma shader_feature_local _F_CENTERAO_ON

            #pragma shader_feature_local _F_HUEVARIATION_ON
            #pragma shader_feature_local _HUEVARIETY_ON

            #pragma shader_feature_local _F_TRANSMISSION_ON
            #pragma shader_feature_local _TRANSMISSIONUSEMASKMAP_ON

            #pragma shader_feature_local _USENORMALTHIEF_ON

            #pragma shader_feature_local _F_MATCAP_ON

            #pragma shader_feature_local _F_WIND_ON
            #pragma shader_feature_local _WINDTYPE_TREE _WINDTYPE_VEGETATION

            #pragma shader_feature_local _DEBUGSHOWAO_ON
            #pragma shader_feature_local _DEBUGSHOWNORMAL_ON
            #pragma shader_feature_local _DEBUGSHOWWIND_ON

            #pragma shader_feature_local _F_TOPLERP_ON
            #pragma shader_feature_local _TOPLERPDEBUG_ON

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            //#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            //#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _RENDER_PASS_ENABLED
            #pragma multi_compile_fragment _ _SCREEN_SPACE_REFLECTION
            // 开关cameraFade
            #pragma multi_compile_fragment _ _GLOBAL_USE_CAMERAFADE

            // Global RenderSettings keywords
            #pragma multi_compile _ _GLOBALRENDERSETTINGSENABLEKEYWORD

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer

            #pragma vertex FoliageGBufferPassVertex
            #pragma fragment FoliageGBufferPassFragment

            #include "Library/FoliageInput.hlsl"
            #include "Library/FoliageGBufferPass.hlsl"
            ENDHLSL
        }

        // ------------------------------------------------------------------
        //  Shadow rendering pass
        Pass {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull [_CullFoliage]

            HLSLPROGRAM
            #pragma target 3.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _F_WIND_ON
            #pragma shader_feature_local _WINDTYPE_TREE _WINDTYPE_VEGETATION

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #pragma vertex FoliageShadowPassVertex
            #pragma fragment FoliageShadowPassFragment

            #include "Library/FoliageInput.hlsl"
            #include "Library/FoliageShadowCasterPass.hlsl"
            ENDHLSL
        }

        // ------------------------------------------------------------------
        //  Forward pass
        //  现在用来给RenderDebugger服务
        Pass {
            Name "Foliage Forward"
            Tags{"LightMode" = "UniversalForward"}

            Cull [_CullFoliage]
            Blend One Zero
            ZWrite On

            HLSLPROGRAM
            #pragma target 3.0
            #pragma exclude_renderers nomrt

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _NEARCAMERAFADE_ON
            #pragma shader_feature_local _METALLICUSE_METALLICVALUE _METALLICUSE_METALLICTEXTURE
            #pragma shader_feature_local _METALLICGLOSSUSE_VALUE _METALLICGLOSSUSE_TEXTURE
            #pragma shader_feature_local _BACKFACEFLIPNORMAL_ON
            #pragma shader_feature_local _USENORMALMAP_ON

            #pragma shader_feature_local _F_VERTEXAO_ON
            #pragma shader_feature_local _F_CENTERAO_ON

            #pragma shader_feature_local _F_HUEVARIATION_ON
            #pragma shader_feature_local _HUEVARIETY_ON

            #pragma shader_feature_local _F_TRANSMISSION_ON
            #pragma shader_feature_local _TRANSMISSIONUSEMASKMAP_ON

            #pragma shader_feature_local _USENORMALTHIEF_ON

            #pragma shader_feature_local _USENORMALAPPLYLIGHTMASK_ON

            #pragma shader_feature_local _F_MATCAP_ON

            #pragma shader_feature_local _F_WIND_ON
            #pragma shader_feature_local _WINDTYPE_TREE _WINDTYPE_VEGETATION

            #pragma shader_feature_local _DEBUGSHOWAO_ON
            #pragma shader_feature_local _DEBUGSHOWNORMAL_ON
            #pragma shader_feature_local _DEBUGSHOWWIND_ON

            #pragma shader_feature_local _F_TOPLERP_ON
            #pragma shader_feature_local _TOPLERPDEBUG_ON

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            //#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            //#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _RENDER_PASS_ENABLED
            #pragma multi_compile_fragment _ _SCREEN_SPACE_REFLECTION
            // 开关cameraFade
            #pragma multi_compile_fragment _ _GLOBAL_USE_CAMERAFADE

            // Global RenderSettings keywords
            #pragma multi_compile _ _GLOBALRENDERSETTINGSENABLEKEYWORD

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DEBUG_DISPLAY
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer

            #pragma vertex FoliageForwardPassVertex
            #pragma fragment FoliageForwardPassFragment

            #include "Library/FoliageInput.hlsl"
            #include "Library/FoliageForwardPass.hlsl"
            ENDHLSL

        }
    }

    FallBack "Transparent/Cutout/VertexLit"
    CustomEditor "Scarecrow.SimpleShaderGUI"
}
