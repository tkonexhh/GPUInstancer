// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Inutan/URP/Scene/GlassPBR 玻璃"
{
    Properties
    {
        // level/style/toggle/open/showlist
        [Foldout(1, 1, 0, 1)] _F_Basic("Basic_Foldout", float) = 1

        [Enum_Switch(Off, Front, Back)] _CullMode("Cull Mode", float) = 2
        [Enum_Switch(Off, On)] _ZWrite("ZWrite", float) = 1

        [Enum_Switch(Opaque, Cutout, Fade, Transparent)] __RenderMode("Render Mode", float) = 3


        [Foldout(1, 1, 0, 1)] _F_PBR("默认PBR_Foldout", float) = 1

        [Tex]_MainTex("基础贴图 (Albedo)", 2D) = "white" {}
        _Color("基础颜色", Color) = (1, 1, 1, 1)

        [Enum_Switch(Value, Texture)] _MetallicGlossUse("金属光滑度 值/图", float) = 0
        [Switch(Value)]_Metallic("金属度 (Metallic)", Range(0.0, 1.0)) = 0.0
        [Switch(Value)]_Glossiness("光滑度 (Smoothness)", Range(0.0, 1.0)) = 0.5

        [Tex(_, Texture)][NoScaleOffset]_MetallicGlossMap("金属光滑度贴图(RA)", 2D) = "white" {}
        [Switch(Texture)]_GlossMapScale("光滑度缩放", Range(0.0, 1.0)) = 1.0

        [Toggle_Switch] _SpecularHighlights("启用高光", float) = 1
        [Toggle_Switch] _GlossyReflections("启用环境反射", float) = 1

        [Toggle_Switch] _UseNormalMap("使用法线", float) = 0
        [Tex(_BumpScale, _UseNormalMap)][NoScaleOffset] _BumpMap("法线贴图", 2D) = "bump" {}
        [HideInInspector]_BumpScale("法线缩放", Range(0, 1)) = 1.0

        [Toggle_Switch] _UseEmissionMap("使用自发光", float) = 0
        [Tex(_EmissionColor, _UseEmissionMap)][NoScaleOffset]_EmissionMap("自发光 (Emission)", 2D) = "white" {}
        [HideInInspector]_EmissionColor("自发光颜色", Color) = (0,0,0)

        [Tex(_OcclusionStrength)][NoScaleOffset]_OcclusionMap("环境光遮蔽(B)", 2D) = "white" {}
        [HideInInspector]_OcclusionStrength("环境光遮蔽强度", Range(0.0, 1.0)) = 1.0

        [Foldout(1, 1, 0, 1)] _F_Glass("玻璃 (RenderMode:Opaque 打开 Interior)_Foldout", float) = 1

        _FresnelStrength("菲涅尔强度", Range(1, 200)) = 1
        _FresnelColor("菲涅尔颜色", Color) = (1, 1, 1, 1)

        [Toggle_Switch] _UseReflectCubemap("自定环境Cubemap", float) = 0
        [Tex(_, _UseReflectCubemap)][NoScaleOffset] _ReflectCubemap("Cubemap", CUBE) = "black" {}

        // --------------------------------------------
        [Foldout(2, 2, 1, 1, Transparent)] _F_Refraction("折射_Foldout", float) = 0
        _RefractionDistort("折射扭曲", Range(0, 1)) = 0

        [Foldout_Out(2)] _F_Refraction_Out("F_Refraction_Out_Foldout", float) = 1

        // --------------------------------------------
        [Foldout(2, 2, 1, 1)] _F_FakeRef("贴片反射_Foldout", float) = 1
	    [Tex(_FakeRefColor)][NoScaleOffset] _FakeRefTex("贴片", 2D) = "white" {}
        [HideInInspector] _FakeRefColor("颜色", Color) = (1, 1, 1, 1)
    	_FakeRefIntensity("强度", Range(0, 5)) = 1
        _FakeRefSpeed("视角转动时变化速度", Range(0.01, 3)) = 0.3
	    _FakeRefPow("菲涅尔遮蔽", Range(0.01, 5)) = 0.5
        _FakeRefRotation("旋转", Range(0, 180)) = 0
        [Toggle_Switch] _FakeRefTwinkle("闪烁", float) = 0
        [Foldout_Out(2)] _F_FakeRef_Out("F_FakeRef_Out_Foldout", float) = 1

        // --------------------------------------------
        [Foldout(2, 2, 1, 1, Opaque)] _F_Interior("Interior_Foldout", float) = 1
        [Tex(_InteriorColor)] _InteriorTex("贴图", 2D) = "white" {}
        [HideInInspector] _InteriorColor("颜色", Color) = (1, 1, 1, 1)
        _InteriorIntensity("强度", Range(0, 5)) = 1
        [Toggle_Switch] _UseInteriorBlur("使用模糊图模拟粗糙度效果", float) = 0
        [Tex(_, _UseInteriorBlur)][NoScaleOffset] _InteriorBlurTex("模糊贴图", 2D) = "white" {}

        [Foldout(3, 2, 1, 0)] _F_InteriorAtlas("图集_Foldout", float) = 0
        _InteriorXCount("横向多少张", Float) = 1.0
        _InteriorYCount("纵向多少张", Float) = 1.0
        _InteriorIndex("坐标序号", Float) = 0.0
        [Foldout_Out(3)] _F_InteriorAtlas_Out("F_InteriorAtlas_Out_Foldout", float) = 1

        [Foldout(3, 2, 0, 1)] _F_InteriorSpaceParams("体积相关_Foldout", float) = 1
        _InteriorWidthRate("宽高比", Float) = 1.0
        _InteriorXYScale("深度", Range(0.0, 1.0)) = 1.0
        _InteriorDepth("远平面位置", Range(0.001, 0.999)) = 0.5
        [Toggle_Switch] _InteriorDepthDebug("远平面位置Debug", float) = 0
        [Foldout_Out(3)] _F_InteriorSpaceParams_Out("F_InteriorSpaceParams_Out_Foldout", float) = 1

        // --------------------------------------------
        [Foldout(3, 2, 1, 1, Opaque)] _F_InteriorDecal("窗户贴花_Foldout", float) = 0
        [Tex(_)] _InteriorDecalTex("贴图", 2D) = "black" {}
        [Toggle_Switch] _InteriorDecalUseTilling("贴花Tilling", float) = 0
        _InteriorDecalDepth("深度", Range(0.0, 0.5)) = 0.0
        [Toggle_Switch] _InteriorDecalUseNormalMap("使用法线贴图", float) = 0
        [Tex(_InteriorDecalBumpScale, _InteriorDecalUseNormalMap)][NoScaleOffset] _InteriorDecalBumpMap("法线贴图", 2D) = "bump" {}
        [HideInInspector]_InteriorDecalBumpScale("法线缩放", Range(0, 1)) = 1.0
        [Toggle_Switch] _InteriorDecalUsePBR("使用PBR", float) = 0
        [Tex(_, _InteriorDecalUsePBR)][NoScaleOffset] _InteriorDecalMetalMap("金属光滑度贴图(RA)", 2D) = "white" {}
        [Switch(_InteriorDecalUsePBR)]_InteriorDecalMetallic("金属度 (Metallic)", Range(0.0, 1.0)) = 0.5
        [Switch(_InteriorDecalUsePBR)]_InteriorDecalGlossiness("光滑度 (Smoothness)", Range(0.0, 1.0)) = 0.5
        [Foldout_Out(3)] _F_InteriorDecal_Out("F_InteriorDecal_Out_Foldout", float) = 1
        [Foldout_Out(2)] _F_Interior_Out("F_Interior_Out_Foldout", float) = 1

        [Foldout_Out(1)] _F_Out("F_Out_Foldout", float) = 1

        // Blending state
        [HideInInspector] _SrcBlend ("__src", Float) = 1.0
        [HideInInspector] _DstBlend ("__dst", Float) = 0.0
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline" "UniversalMaterialType" = "Lit" "IgnoreProjector" = "True" }
        LOD 300

        // ------------------------------------------------------------------
        Pass
        {
            Name "ForwardLit"
            // Deferred 下的 Opaque Forward Only 不能标记为 UniversalForward（会被认为是存粹Forward的）
            // Tags { "LightMode" = "UniversalForward" }

            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
            Cull [_CullMode]

            HLSLPROGRAM
            #pragma target 3.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local __RENDERMODE_OPAQUE __RENDERMODE_CUTOUT __RENDERMODE_FADE __RENDERMODE_TRANSPARENT

            #pragma shader_feature_local _METALLICGLOSSUSE_VALUE _METALLICGLOSSUSE_TEXTURE
            #pragma shader_feature_local _SPECULARHIGHLIGHTS_ON
            #pragma shader_feature_local _GLOSSYREFLECTIONS_ON
            #pragma shader_feature_local _USENORMALMAP_ON
            #pragma shader_feature_local _USEEMISSIONMAP_ON

            #pragma shader_feature_local _USEREFLECTCUBEMAP_ON
            #pragma shader_feature_local _F_INTERIOR_ON
            #pragma shader_feature_local_fragment _INTERIORDEPTHDEBUG_ON
            #pragma shader_feature_local_fragment _F_INTERIORATLAS_ON
            #pragma shader_feature_local_fragment _F_INTERIORDECAL_ON
            #pragma shader_feature_local_fragment _INTERIORDECALUSETILLING_ON
            #pragma shader_feature_local_fragment _INTERIORDECALUSENORMALMAP_ON
            #pragma shader_feature_local_fragment _INTERIORDECALUSEPBR_ON
            #pragma shader_feature_local _USEINTERIORBLUR_ON
            #pragma shader_feature_local _F_FAKEREF_ON
            #pragma shader_feature_local _F_REFRACTION_ON

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _CLUSTERED_RENDERING

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile_fog
            #pragma multi_compile_fragment _ DEBUG_DISPLAY

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer

            #pragma vertex GlassLitPassVertex
            #pragma fragment GlassLitPassFragment

            #include "Library/GlassPBRInput.hlsl"
            #include "Library/GlassPBRForwardPass.hlsl"

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

            HLSLPROGRAM
            #pragma target 3.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local __RENDERMODE_OPAQUE __RENDERMODE_CUTOUT __RENDERMODE_FADE __RENDERMODE_TRANSPARENT
            #pragma shader_feature_local _METALLICGLOSSUSE_VALUE _METALLICGLOSSUSE_TEXTURE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            // -------------------------------------
            // Universal Pipeline keywords

            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            // -------------------------------------
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Library/GlassPBRInput.hlsl"
            #include "Library/GlassPBRShadowCasterPass.hlsl"

            ENDHLSL
        }

    }

    CustomEditor "Scarecrow.SimpleShaderGUI"
}
