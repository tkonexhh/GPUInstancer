

Shader "Inutan/URP/Character/ToonHairDye 头发换色" {
    // --------------------------------------------
    Properties {
        // level/style/toggle/open/showlist
        [Foldout(1, 1, 0, 1)] _F_Basic("Basic_Foldout", float) = 1 // 0表示不可以编辑

        // UnityEngine.Rendering.CullMode
        [Enum_Switch(Off, Front, Back)] _CullMode("Cull Mode", float) = 2
        [Enum_Switch(Opaque, Cutout)] __RenderMode("Render Mode", float) = 0

        _BloomIntensity("BloomIntensity", Range(0, 1)) = 0

        [Foldout(2, 2, 0, 1, Cutout)] _F_Cutout("裁切_Foldout", float) = 1
        [Toggle_Switch] _UseClippingMask("替换基础贴图A通道", float) = 0
        [Tex(_, _UseClippingMask)][NoScaleOffset] _ClippingMask("裁切蒙板", 2D) = "white" {}
        [Toggle_Switch] _InverseClipping ("反转蒙板", Float ) = 0
        _ClippingLevel ("裁切强度", Range(0, 1)) = 0

        // --------------------------------------------
        [Foldout(1, 1, 0, 1)] _F_Normal("Normal_Foldout", float) = 1

        [Tex(_NormalScale)]_NormalTex("法线贴图", 2D) = "bump" {}
        [HideInInspector] _NormalScale("NormalScale", Range(0, 1)) = 0
        [Toggle_Switch] _DebugShowNormal("(调试用)查看法线", float) = 0

        // --------------------------------------------
        [Foldout(1, 1, 0, 1)] _F_TexPack("贴图合并_Foldout", float) = 1
        [Tex][NoScaleOffset] _HairFlowTex("头发FlowMap", 2D) = "white" {}
        [Tex][NoScaleOffset] _HairTex("头发贴图    R: 漫反射阈值     G: AO    B: 头发纹理    A: 高光形状", 2D) = "white" {}
        [Tex][NoScaleOffset] _AreaMask("染色分区    RGB: 染色ID    A: 染色渐变    (无图=黑色)", 2D) = "black" {}
        [Toggle_Switch] _DebugShowAreaMask("(调试用) 显示染色分区", float) = 0
        [Foldout_Out(1)] _F_TexPack_Out("_F_TexPack_Out_Foldout", float) = 1

        // --------------------------------------------
        [Foldout(1, 1, 1, 1)] _F_Diffuse("Diffuse_Foldout", float) = 1

        [Tex(_BaseColor)][NoScaleOffset] _MainTex("基础贴图", 2D) = "white" {}
        [HideInInspector] _BaseColor("明部颜色", Color) = (1, 1, 1, 1)
        // 代替法线贴图效果
        [Toggle_Switch] _UseDiffuseThreshold("使用漫反射阈值图 (头发贴图 R通道)", float) = 0
        _HairDetailsStrength("头发纹理强度", Range(0, 1)) = 0
        [Foldout(2, 2, 0, 1)] _Shade_1("第1层阴影_Foldout", float) = 1
        _ShadeColor_1("阴影颜色", Color) = (1, 1, 1, 1)
        _Shift_01("阴影边界偏移", Range(0, 1)) = 0.5
        _Gradient_01("阴影梯度变化", Range(0.0001, 1)) = 0.5

        [Foldout(3, 2, 1, 1)] _FakeSSS("阴影边界_Foldout", float) = 0
        _FakeSSSColor("颜色", Color) = (1, 1, 1, 1)
        [Range] _FakeSSSWidth("边界范围", float) = (0.09,0.11,0,0.5)

        [Foldout_Out(1)] _F_Diffuse_Out("F_Diffuse_Out_Foldout", float) = 1

        // --------------------------------------------
        [Foldout(1, 1, 1, 1)] _F_Specular("Specular_Foldout", float) = 0

        [HDR]_SpecularColor("高光颜色", Color) = (1, 1, 1, 1)

        // ----------- 头发高光
        [Foldout(2, 2, 0, 1)] _F_Specular_Hair("头发高光_Foldout", float) = 1
        _SpecularIntensity("高光强度", Range(0, 1)) = 1
        [Toggle_Switch] _SpecularHairUseSN("使用球形切线", float) = 0
        [Vector3(1, _SpecularHairUseSN)]_SpecularHairSNOffset("头发球形中心相对于模型原点偏移", Vector) = (0, 1.4, 0, 1)
        [Toggle_Switch] _UseFlowMap("使用头发FlowMap控制切线方向", float) = 0
        _SpecularHairBias("高光偏移", Range(-2, 2)) = 0.45
        _SpecularHairPower("高光范围", Range(0.001, 2)) = 1
        _SpecularHairFlowIntensity("高光扰动强度", Range(0, 1)) = 0
        [Foldout(2, 2, 0, 1)] _F_SpecularPBR_Hair("PBR高光_Foldout", float) = 1
        _SpecularPBRIntensity("高光强度", Range(0, 5)) = 0
        [Tex][NoScaleOffset] _HairPBRSpecMask("遮罩", 2D) = "white" {}

        [Foldout_Out(1)] _F_Specular_Out("F_Specular_Out_Foldout", float) = 1


        // --------------------------------------------
        [Foldout(1, 1, 1, 1)] _F_Indirect("环境光_Foldout", float) = 0
        _IndirectAOIntensity("间接光AO遮蔽强度", Range(0, 1)) = 1
        _InDirectIntensity("间接光总体强度", Range(0, 1)) = 1
        _InDirectSpecularIntensity("间接光镜面反射强度", Range(0, 1)) = 0
        [Toggle_Switch] _DebugNotUseEnvToAlbedo("不使用环境光向纯色的渐变 (调试用)", float) = 0
        [Foldout_Out(1)] _F_Indirect_Out("F_Indirect_Out_Foldout", float) = 1

        // --------------------------------------------
        [Foldout(1, 1, 0, 1)] _F_Light("Light_Foldout", float) = 1
        [Toggle_Switch] _UserLightDirection("自定主光源方向", float) = 0
        [Vector3(0, _UserLightDirection)] _MainLightDirection("主光源方向", float) = (1, 0, 0, 0)

        [Toggle_Switch] _UseShadowMap("使用遮挡阴影", float) = 0
        [Toggle_Switch] _UseAdditionalLight("开启多光源", float) = 0
        _LightIntensityLimit("光源最高强度限制", Range(1, 10)) = 1

        [Foldout_Out(1)] _F_Light_Out("F_Light_Out_Foldout", float) = 1
        // --------------------------------------------

        [Foldout(1, 1, 1, 1)] _F_Fresnel("Fresnel_Foldout", float) = 0

        [Toggle_Switch] _DebugFresnel("显示边缘光 (调试用)", float) = 0

        [Enum_Switch(Default, Cel)] _Fres_Func("边缘光类型(临时)", float) = 0

        _FresnelLightRange("主光方向范围", Range(0,1)) = 1
        [HDR]_FresnelColor("边缘光颜色", Color) = (1, 1, 1, 1)
        _FresnelPow("边缘光渐变", Range(0, 1)) = 0
        _FresnelInnerRange("边缘光内侧范围", Range(0.0001, 1)) = 0.0001

        [Tex(_FresnelIntensity)][NoScaleOffset] _FresnelMask("边缘光遮罩(A通道)", 2D) = "white" {}
        [HideInInspector] _FresnelIntensity("FresnelIntensity", Range(-1, 1)) = 0

        [Foldout(2, 2, 1, 1)] _Fres_Shade_Mask("暗部边缘光遮蔽_Foldout", float) = 0
        _FresnelShadeMaskIntensity("暗部边缘光范围", Range(-1, 0.5)) = 0

        [Foldout(3, 2, 1, 1)] _Fres_Shade("暗部边缘光_Foldout", float) = 0
        _FresnelShadeColor("暗部边缘光颜色", Color) = (1, 1, 1, 1)
        _FresnelShadePow("暗部边缘光渐变", Range(0, 1)) = 0

        [Foldout_Out(1)] _F_Fres_Out("F_Fres_Out_Foldout", float) = 1

        // --------------------------------------------

        [Foldout(1, 1, 1, 1)] _F_Dye("染色测试_Foldout", float) = 0

        [Toggle_Switch] _DebugShowDyePoint("(调试用) 边界无混合", float) = 0
        //
        [Toggle_Switch] _DyeFadeOverlay("渐变混合模式 (叠加)", float) = 1

        [Foldout(2, 2, 1, 0)] _F_DyeEntiretyFade("整体渐变_Foldout", float) = 0
        _DyeEntiretyFadeColor("渐变颜色", Color) = (1, 1, 1, 1)
        [Toggle_Switch] _DyeEntiretyFadeInvert("反相", float) = 0
        _DyeEntiretyFadeData("X: 底部坐标 Y: 顶部坐标 Z: 渐变过度", vector) = (0, 1.6, 1, 0)
        _DyeEntiretyFadeShift("渐变偏移", Range(0, 1)) = 0.5
        _DyeEntiretyFadeAngle("渐变旋转", Range(0, 180)) = 0

        [Foldout(2, 2, 0, 0)] _F_DyeConfig("自动颜色计算配置_Foldout", float) = 1
        [Foldout(3, 2, 0, 1)] _F_Dye_1("暗部配置_Foldout", float) = 1
        // 暗部
        _DyeShadeSat("暗部饱和度倍率", Range(0, 3)) = 1.65
        _DyeShadeLum("暗部明度倍率", Range(0, 3)) = 0.5
        _DyeShadeLumPower("暗部明度曲线(小于1偏黑更亮，大于1偏黑更暗)", Range(0.5, 3)) = 1.2
        // 暗部边界
        [Foldout(3, 2, 0, 1)] _F_Dye_2("暗部边界配置_Foldout", float) = 1
        _DyeSSSSat("暗部边界饱和度倍率", Range(0, 3)) = 1.31
        _DyeSSSLum("暗部边界明度倍率", Range(0, 3)) = 1.43
        // 高光
        [Foldout(3, 2, 0, 1)] _F_Dye_3("高光配置_Foldout", float) = 1
        _DyeSpecularSat("高光饱和度偏移", Range(-3, 3)) = 0.2
        _DyeSpecularLum("高光明度偏移", Range(-1, 1)) = 0.08
        // 描边
        [Foldout(3, 2, 0, 1)] _F_Dye_4("描边配置_Foldout", float) = 1
        _DyeOutlineHue("描边色相旋转", Range(-360, 360)) = -15
        _DyeOutlineSat("描边饱和度倍率", Range(0, 3)) = 1.93
        _DyeOutlineLum("描边明度倍率", Range(0, 3)) = 0.31
        _DyeOutlineThreshold("描边明度反转阈值", Range(0, 0.1)) = 0.07
        // AO
        [Foldout(3, 2, 0, 1)] _F_Dye_5("固有色过渡配置_Foldout", float) = 1
        _DyeAOSat("固有色过渡 饱和度倍率", Range(0, 3)) = 1.3
        _DyeAOLum("固有色过渡 明度倍率", Range(0, 3)) = 1

        [Foldout(2, 2, 0, 0)] _F_DyeColor("染色_Foldout", float) = 1

        [Foldout(3, 20, 1, 1)] _F_DyeColor0("染色0_Foldout", float) = 1
        _DyeColor0("固有色", Color) = (0, 0, 0, 1)
        _DyeColorFade0("渐变色", Color) = (0, 0, 0, 1)
        [Foldout(3, 21, 1, 1)] _F_DyeColor1("染色1_Foldout", float) = 1
        _DyeColor1("固有色", Color) = (0, 0, 1, 1)
        _DyeColorFade1("渐变色", Color) = (0, 0, 0, 1)
        [Foldout(3, 22, 1, 1)] _F_DyeColor2("染色2_Foldout", float) = 1
        _DyeColor2("固有色", Color) = (0, 1, 0, 1)
        _DyeColorFade2("渐变色", Color) = (0, 0, 0, 1)
        [Foldout(3, 23, 1, 1)] _F_DyeColor3("染色3_Foldout", float) = 1
        _DyeColor3("固有色", Color) = (0, 1, 1, 1)
        _DyeColorFade3("渐变色", Color) = (0, 0, 0, 1)
        [Foldout(3, 24, 1, 1)] _F_DyeColor4("染色4_Foldout", float) = 1
        _DyeColor4("固有色", Color) = (1, 0, 0, 1)
        _DyeColorFade4("渐变色", Color) = (0, 0, 0, 1)
        [Foldout(3, 25, 1, 1)] _F_DyeColor5("染色5_Foldout", float) = 1
        _DyeColor5("固有色", Color) = (1, 0, 1, 1)
        _DyeColorFade5("渐变色", Color) = (0, 0, 0, 1)
        [Foldout(3, 26, 1, 1)] _F_DyeColor6("染色6_Foldout", float) = 1
        _DyeColor6("固有色", Color) = (1, 1, 0, 1)
        _DyeColorFade6("渐变色", Color) = (0, 0, 0, 1)
        [Foldout(3, 27, 0, 1)] _F_DyeColor7("染色7 (默认不可染色)_Foldout", float) = 0
        _DyeColor7("固有色", Color) = (1, 1, 1, 1)
        _DyeColorFade7("渐变色", Color) = (0, 0, 0, 1)

        // --------------------------------------------
        [Foldout(1, 1, 1, 1)] _F_Outline("Outline(不是真的能关闭)_Foldout", float) = 0
        _OutlineWidth("描边宽度", float) = 0
        [Tex][NoScaleOffset] _OutlineMask("描边蒙板(R通道)", 2D) = "white" {}
        _OutlineColor("描边颜色", Color) = (0.5, 0.5, 0.5, 1)

        //
        [Enum_Switch(Normal, VertexColor)] _OutlineType("顶点色平滑版本(需要预先生成)", float) = 0
        [Toggle_Switch] _AutoWidth("摄像机远近变化时宽度保持", float) = 0
        [Range(_AutoWidth)] _FadeDist("超出最大距离描边消失(从近处开始过渡)", float) = (0,20,0,100)
        _Offset_Z ("前后偏移(控制内部描边)", Float) = 0
        [Toggle_Switch] _DebugOutlineMask("显示描边遮罩 (调试用)", float) = 0

        // --------------------------------------------
        [Foldout_Out(1)] _F_Out("F_Out_Foldout", float) = 1


        // Blending state
        [HideInInspector] _SrcBlend ("__src", Float) = 1.0
        [HideInInspector] _DstBlend ("__dst", Float) = 0.0
    }

    // --------------------------------------------
    SubShader {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True"}

        Pass {
            Name "ToonHairDye"

            Cull [_CullMode]
            Blend [_SrcBlend] [_DstBlend]

            HLSLPROGRAM
            #pragma target 4.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _USEDIFFUSETHRESHOLD_ON
            #pragma shader_feature_local _USEFLOWMAP_ON
            #pragma shader_feature_local _SPECULARHAIRUSESN_ON

            //
            #pragma shader_feature_local __RENDERMODE_OPAQUE __RENDERMODE_CUTOUT
            #pragma shader_feature_local _USECLIPPINGMASK_ON
            #pragma shader_feature_local _INVERSECLIPPING_ON

            #pragma shader_feature_local _FAKESSS_ON

            #pragma shader_feature_local _FRES_FUNC_DEFAULT _FRES_FUNC_CEL
            #pragma shader_feature_local _F_FRESNEL_ON
            #pragma shader_feature_local _FRES_SHADE_MASK_ON
            #pragma shader_feature_local _FRES_SHADE_ON

            #pragma shader_feature_local _USERLIGHTDIRECTION_ON
            #pragma shader_feature_local _USESHADOWMAP_ON
            #pragma shader_feature_local _USEADDITIONALLIGHT_ON
            #pragma shader_feature_local _F_INDIRECT_ON

            #pragma shader_feature_local _DEBUGSHOWNORMAL_ON
            #pragma shader_feature_local _DEBUGOUTLINEMASK_ON
            #pragma shader_feature_local _DEBUGFRESNEL_ON

            #pragma shader_feature_local _F_DYE_ON
            #pragma shader_feature_local _F_DYEENTIRETYFADE_ON
            #pragma shader_feature_local _DYEFADEOVERLAY_ON
            #pragma shader_feature_local _DEBUGSHOWAREAMASK_ON
            #pragma shader_feature_local _DEBUGSHOWDYEPOINT_ON

            #pragma shader_feature_local _DEBUGNOTUSEENVTOALBEDO_ON

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _CLUSTERED_RENDERING

            // -------------------------------------
            // Global RenderSettings keywords
            #pragma multi_compile _ _GLOBALRENDERSETTINGSENABLEKEYWORD

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer

            #pragma vertex ToonStandardVertex
            #pragma fragment ToonStandardFragment

            #define _TOON_HAIR_ON 1
            #include "ToonLibrary/ToonStandardPassDye.hlsl"

            ENDHLSL
        }

        Pass {
            Name "ToonHairDyeOutline"
            Tags{"LightMode" = "ToonOutline"}

            Cull Front

            HLSLPROGRAM
            #pragma target 4.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local __RENDERMODE_OPAQUE __RENDERMODE_CUTOUT
            #pragma shader_feature_local _USECLIPPINGMASK_ON
            #pragma shader_feature_local _INVERSECLIPPING_ON

            #pragma shader_feature_local _F_OUTLINE_ON
            #pragma shader_feature_local _OUTLINETYPE_NORMAL _OUTLINETYPE_VERTEXCOLOR
            #pragma shader_feature_local _AUTOWIDTH_ON
            // #pragma shader_feature_local _F_OUTLINECOLORS_ON
            #pragma shader_feature_local _F_DYE_ON

            // -------------------------------------
            // Global RenderSettings keywords
            #pragma multi_compile _ _GLOBALRENDERSETTINGSENABLEKEYWORD

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex ToonOutlineVertex
            #pragma fragment ToonOutlineFragment

            #define _TOON_HAIR_ON 1
            #include "ToonLibrary/ToonStandardInput.hlsl"
            #include "ToonLibrary/ToonOutlinePass.hlsl"

            ENDHLSL
        }

        Pass {
            Name "ToonHairDyeShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Off

            HLSLPROGRAM
            #pragma target 4.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local __RENDERMODE_OPAQUE __RENDERMODE_CUTOUT
            #pragma shader_feature_local _USECLIPPINGMASK_ON
            #pragma shader_feature_local _INVERSECLIPPING_ON
            // for eye specular anim
            #pragma shader_feature_local _F_EYE_SPECULARANIM_ON
            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #pragma vertex ToonShadowPassVertex
            #pragma fragment ToonShadowPassFragment

            #define _TOON_HAIR_ON 1
            #include "ToonLibrary/ToonStandardInput.hlsl"
            #include "ToonLibrary/ToonShadowCasterPass.hlsl"

            ENDHLSL
        }
    }

    // --------------------------------------------
    CustomEditor "Scarecrow.SimpleShaderGUI"
}