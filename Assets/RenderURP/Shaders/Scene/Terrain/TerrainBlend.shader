// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Inutan/URP/Scene/Terrain/TerrainBlend 可刷地表"
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

            #include "Library/TerrainBlendInput.hlsl"
            #include "Library/TerrainBlendGBufferPass.hlsl"

            ENDHLSL
        }
    }

    CustomEditor "Scarecrow.SimpleShaderGUI"
}
