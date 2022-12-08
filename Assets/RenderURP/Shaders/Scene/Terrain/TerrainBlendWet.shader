// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Inutan/URP/Scene/Terrain/TerrainBlendWet 可刷地表加湿地"
{
    Properties
    {
		[Tex]_Control_0 ("控制通道", 2D) = "black" {}
        [Toggle_Switch] _UseNormalMap("使用法线", float) = 1
        _BlendWeight("整体高度混合权重 (依赖A通道高度图)", Range(0.001, 1)) = 0.001
        [Toggle_Switch] _ParallaxRaymarch("视差Raymarch(测试用)", float) = 0

        // level/style/toggle/open/showlist
        [Foldout(1, 1, 0, 1)] _F_Texlist ("纹理_Foldout", float) = 1

        [Foldout(2, 2, 0, 1)] _F_TexR ("1_Foldout", float) = 1
		[Tex(_SplatColor_0)]_Splat_0 ("基础贴图 (A通道高度图)", 2D) = "white" {}
        [HideInInspector]_SplatColor_0 ("颜色", Color) = (1, 1, 1, 1)
		[Tex(_NormalScale_0)][NoScaleOffset]_Normal_0 ("法线", 2D) = "bump" {}
        [HideInInspector]_NormalScale_0 ("法线强度", Range(0, 1)) = 1
		_Metallic_0 ("金属度 (Metallic)", Range(0, 1)) = 0
		_Smoothness_0 ("光滑度 (Smoothness)", Range(0, 1)) = 0
        [Toggle_Switch]_UseSmoothness_0 ("使用光滑度贴图", float) = 0
        [Toggle_Switch]_UseOcclusion_0 ("使用AO贴图", float) = 0
        [Switch(_UseOcclusion_0)] _OcclusionStrength_0 ("AO强度", Range(0, 1)) = 0
        [Tex(_, _UseOcclusion_0, _UseSmoothness_0)][NoScaleOffset] _PropMap_0 ("表面信息图( G:AO B:粗糙度 )", 2D) = "white" {}
        [Toggle_Switch]_UseParallax_0 ("视差 (从基础贴图A通道获取)", float) = 0
        [Switch(_UseParallax_0)] _Parallax_0 ("视差强度", Range(0, 1)) = 0

        [Foldout(2, 2, 0, 1)] _F_TexG("2_Foldout", float) = 1
	    [Tex(_SplatColor_1)]_Splat_1 ("基础贴图 (A通道高度图)", 2D) = "white" {}
        [HideInInspector]_SplatColor_1 ("颜色", Color) = (1, 1, 1, 1)
		[Tex(_NormalScale_1)][NoScaleOffset]_Normal_1 ("法线", 2D) = "bump" {}
        [HideInInspector]_NormalScale_1 ("法线强度", Range(0, 1)) = 1
		_Metallic_1 ("金属度 (Metallic)", Range(0, 1)) = 0
		_Smoothness_1 ("光滑度 (Smoothness)", Range(0, 1)) = 0
        [Toggle_Switch]_UseSmoothness_1 ("使用光滑度贴图", float) = 0
        [Toggle_Switch]_UseOcclusion_1 ("使用AO贴图", float) = 0
        [Switch(_UseOcclusion_1)] _OcclusionStrength_1 ("AO强度", Range(0, 1)) = 0
        [Tex(_, _UseOcclusion_1, _UseSmoothness_1)][NoScaleOffset] _PropMap_1 ("表面信息图( G:AO B:光滑度 )", 2D) = "white" {}
        [Toggle_Switch]_UseParallax_1 ("视差 (从基础贴图A通道获取)", float) = 0
        [Switch(_UseParallax_1)] _Parallax_1 ("视差强度", Range(0, 1)) = 0

        [Foldout(2, 2, 0, 1)] _F_TexB("3_Foldout", float) = 1
		[Tex(_SplatColor_2)]_Splat_2 ("基础贴图 (A通道高度图)", 2D) = "white" {}
        [HideInInspector]_SplatColor_2 ("颜色", Color) = (1, 1, 1, 1)
		[Tex(_NormalScale_2)][NoScaleOffset]_Normal_2 ("法线", 2D) = "bump" {}
        [HideInInspector]_NormalScale_2 ("法线强度", Range(0, 1)) = 1
		_Metallic_2 ("金属度 (Metallic)", Range(0, 1)) = 0
		_Smoothness_2 ("光滑度 (Smoothness)", Range(0, 1)) = 0
        [Toggle_Switch]_UseSmoothness_2 ("使用光滑度贴图", float) = 0
        [Toggle_Switch]_UseOcclusion_2 ("使用AO贴图", float) = 0
        [Switch(_UseOcclusion_2)] _OcclusionStrength_2 ("AO强度", Range(0, 1)) = 0
        [Tex(_, _UseOcclusion_2, _UseSmoothness_2)][NoScaleOffset] _PropMap_2 ("表面信息图( G:AO B:光滑度 )", 2D) = "white" {}
        [Toggle_Switch]_UseParallax_2 ("视差 (从基础贴图A通道获取)", float) = 0
        [Switch(_UseParallax_2)] _Parallax_2 ("视差强度", Range(0, 1)) = 0

        [Foldout(2, 2, 0, 1)] _F_TexA("4_Foldout", float) = 1
		[Tex(_SplatColor_3)]_Splat_3 ("基础贴图 (A通道高度图)", 2D) = "white" {}
        [HideInInspector]_SplatColor_3 ("颜色", Color) = (1, 1, 1, 1)
		[Tex(_NormalScale_3)][NoScaleOffset]_Normal_3 ("法线", 2D) = "bump" {}
        [HideInInspector]_NormalScale_3 ("法线强度", Range(0, 1)) = 1
		_Metallic_3 ("金属度 (Metallic)", Range(0, 1)) = 0
		_Smoothness_3 ("光滑度 (Smoothness)", Range(0, 1)) = 0
        [Toggle_Switch]_UseSmoothness_3 ("使用光滑度贴图", float) = 0
        [Toggle_Switch]_UseOcclusion_3 ("使用AO贴图", float) = 0
        [Switch(_UseOcclusion_3)] _OcclusionStrength_3 ("AO强度", Range(0, 1)) = 0
        [Tex(_, _UseOcclusion_3, _UseSmoothness_3)][NoScaleOffset] _PropMap_3 ("表面信息图( G:AO B:光滑度 )", 2D) = "white" {}
        [Toggle_Switch]_UseParallax_3 ("视差 (从基础贴图A通道获取)", float) = 0
        [Switch(_UseParallax_3)] _Parallax_3 ("视差强度", Range(0, 1)) = 0


        [Foldout(1, 1, 1, 1)] _F_Puddle ("雨坑_Foldout", float) = 1

        [Toggle_Switch] _AddPuddleTex("加入额外贴图", float) = 0
        [Tex(_, _AddPuddleTex)]_PuddleTex("额外贴图", 2D) = "white" {}
        _PuddleColor("颜色", Color) = (1, 1, 1, 1)

		_PuddleMetallic("金属度 (Metallic)", Range(0, 2)) = 0
		_PuddleSmoothness("光滑度 (Smoothness)", Range(0, 2)) = 1

        // mask
        [Foldout(2, 2, 0, 1)] _F_PuddleMask ("区域_Foldout", float) = 1
		[Tex(_PuddleMaskIntensity)]_PuddleMask("区域噪声图", 2D) = "black" {}
		[HideInInspector] _PuddleMaskIntensity("强度", Range(0, 1)) = 1
		[Toggle_Switch] _PuddleMaskInvert("反转", float) = 0
		_PuddleMaskContrast("阈值", float) = 0
		_PuddleMaskSpread("扩散", float) = 0
        [Toggle_Switch] _DebugShowPuddleMask("(调试用)显示区域", float) = 0

        // reflect
        [Foldout(2, 2, 0, 1)] _F_PuddleReflect ("反射_Foldout", float) = 1
		[Tex(_PuddleReflectColor)][NoScaleOffset] _PuddleReflectCubemap("Cubemap", CUBE) = "black" {}
        [HideInInspector] _PuddleReflectColor("颜色", Color) = (1, 1, 1, 1)
		_PuddleReflectIntensity("反射强度", Range(0, 10)) = 0.2
		_PuddleReflectBlur("反射模糊度(Mipmap)", Range(0, 7)) = 0.5

        // normal
        [Foldout(2, 2, 1, 1)] _F_PuddleNormal ("法线_Foldout", float) = 1
        
        [Tex][NoScaleOffset]_PuddleNormalMap("法线", 2D) = "bump" {}
        [Toggle_Switch] _PuddleNormalBlendMain("和地表法线混合", float) = 0

        [Foldout(3, 2, 0, 1)] _F_PuddleNormal_1 ("第1层_Foldout", float) = 1
		_PuddleNormalIntensity_1("强度", Range(0, 1)) = 0.5
		_PuddleNormalSpeed_1("速度", float) = 0.5
		_PuddleNormalRotation_1("旋转", float) = 0
		_PuddleNormalTiling_1("Tiling", float) = 1
        [Foldout(3, 2, 1, 1)] _F_PuddleNormal_2 ("第2层_Foldout", float) = 0
		_PuddleNormalIntensity_2("强度", Range(0, 1)) = 0.5
		_PuddleNormalSpeed_2("速度", float) = 0.5
		_PuddleNormalRotation_2("旋转", float) = 180
		_PuddleNormalTiling_2("Tiling", float) = 1

        [Foldout_Out(1)] _F_Out_PuddleNormal("_F_Out_PuddleNormal_Foldout", float) = 1

        // ripple
        [Foldout(2, 2, 1, 1)] _F_Ripple ("涟漪_Foldout", float) = 1

        _RippleColRowSpeedStart("x:行 y:列 z:速度 w:起始帧", Vector) = (4, 4, 1, 0)
		[Tex][NoScaleOffset]_RippleNormalMap("法线", 2D) = "bump" {}
		_RippleNormalTiling("Tiling", float) = 1
		_RippleNormalIntensity_1("强度", Range(0, 1)) = 0.4

        [Foldout(3, 2, 1, 1)] _F_RippleNormal_2 ("第2层_Foldout", float) = 0
		_RippleNormalIntensity_2("强度", Range(0, 1)) = 0.3
		_RippleNormalScale_2("缩放", float) = 1
		_RippleNormalRotation_2("旋转", float) = 45
		_RippleNormalOffset_2("偏移XY", float) = (1.5, 1.5, 0, 0)

        [Foldout_Out(1)] _F_Out_Ripple("_F_Out_Ripple_Foldout", float) = 1

        // rain dot
        [Foldout(2, 2, 1, 1)] _F_RainDot ("全局雨点_Foldout", float) = 1

        [Tex] _RainDotGradientTex("Gradient Tex", 2D) = "white" {}
		_RainDotIntensity("强度", Range(0, 1)) = 0
		_RainDotTiling("Tiling", Float) = 100
		_RainDotSpeed("速度", Range(0, 1)) = 0.1
		_RainDotSize("Size", Range(0, 1)) = 0.5

        [Foldout_Out(1)] _F_Out("F_Out_Foldout", float) = 1
    }


    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "UniversalMaterialType" = "Lit"}
        LOD 300

        // ------------------------------------------------------------------
        //  Deferred pass
        Pass
        {
            Name "GBuffer"
            Tags{"LightMode" = "UniversalGBuffer"}

            HLSLPROGRAM
            #pragma target 3.0
            #pragma exclude_renderers nomrt


            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _PARALLAXRAYMARCH_ON
            #pragma shader_feature_local _USENORMALMAP_ON
            #pragma shader_feature_local _USEPARALLAX_0_ON 
            #pragma shader_feature_local _USEPARALLAX_1_ON 
            #pragma shader_feature_local _USEPARALLAX_2_ON 
            #pragma shader_feature_local _USEPARALLAX_3_ON 
            #pragma shader_feature_local _USEOCCLUSION_0_ON 
            #pragma shader_feature_local _USEOCCLUSION_1_ON 
            #pragma shader_feature_local _USEOCCLUSION_2_ON 
            #pragma shader_feature_local _USEOCCLUSION_3_ON 
            #pragma shader_feature_local _USESMOOTHNESS_0_ON
            #pragma shader_feature_local _USESMOOTHNESS_1_ON
            #pragma shader_feature_local _USESMOOTHNESS_2_ON
            #pragma shader_feature_local _USESMOOTHNESS_3_ON

            #pragma shader_feature_local _F_PUDDLE_ON
            #pragma shader_feature_local _ADDPUDDLETEX_ON
            #pragma shader_feature_local _PUDDLEMASKINVERT_ON
            #pragma shader_feature_local _DEBUGSHOWPUDDLEMASK_ON
            #pragma shader_feature_local _PUDDLENORMALBLENDMAIN_ON
            #pragma shader_feature_local _F_PUDDLENORMAL_ON
            #pragma shader_feature_local _F_PUDDLENORMAL_2_ON

            #pragma shader_feature_local _F_RIPPLE_ON
            #pragma shader_feature_local _F_RIPPLENORMAL_2_ON

            #pragma shader_feature_local _F_RAINDOT_ON

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            //#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            //#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _RENDER_PASS_ENABLED
            #pragma multi_compile_fragment _ _SCREEN_SPACE_REFLECTION
            
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

            #pragma vertex TerrainGBufferPassVertex
            #pragma fragment TerrainGBufferPassFragment

            #include "Library/TerrainBlendWetInput.hlsl"
            #include "Library/TerrainBlendWetGBufferPass.hlsl"

            ENDHLSL
        }
    }

    CustomEditor "Scarecrow.SimpleShaderGUI"
}
