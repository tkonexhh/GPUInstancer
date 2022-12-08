// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Inutan/URP/Scene/Terrain/TerrainTriplanar 水平地形混合"
{
    Properties
    {
        [Foldout(1, 1, 0, 1)] _F_PBR("基础_Foldout", float) = 1

        [Tex(_Color)]_MainTex("基础贴图 (Albedo)", 2D) = "white" {}
        [HideInInspector]_Color("基础颜色", Color) = (1, 1, 1, 1)

        [Enum_Switch(Value, Texture)] _MetallicGlossUse("金属光滑度 值/图", float) = 0
        [Switch(Value)]_Glossiness("光滑度 (Smoothness)", Range(0.0, 1.0)) = 0.5
        [Switch(Value)]_Metallic("金属度 (Metallic)", Range(0.0, 1.0)) = 0.0

        [Tex(_, Texture)][NoScaleOffset]_MetallicGlossMap("金属光滑度贴图", 2D) = "white" {}
        [Switch(Texture)]_GlossMapScale("光滑度缩放", Range(0.0, 1.0)) = 1.0

        [Tex(_BumpScale)][NoScaleOffset] _BumpMap("法线贴图", 2D) = "bump" {}
        [HideInInspector]_BumpScale("法线缩放", Range(0, 1)) = 1.0

        [Tex(_OcclusionStrength)][NoScaleOffset]_OcclusionMap("环境光遮蔽 (Occlusion)", 2D) = "white" {}
        [HideInInspector]_OcclusionStrength("环境光遮蔽强度", Range(0.0, 1.0)) = 1.0

        [Foldout_Out(1)] _F_Out_PBR("F_Out_PBR_Foldout", float) = 1

        //
        [Foldout(1, 1, 1, 1)] _F_Triplanar("Triplanar_Foldout", float) = 1

        _TriplanarTiling("Tiling", Float) = 0.01
		_BlendStrength("混合强度", Range(0, 2)) = 1.5
		_BlendNormalInfluence("基础法线影响", Range(0, 1)) = 0
		_BlendNormalStrength("基础法线强度", Range(0, 1)) = 0

        //
        [Tex(_TriplanarColor)][NoScaleOffset]_TriplanarTex("基础贴图 (Albedo)", 2D) = "white" {}
        [HideInInspector]_TriplanarColor("基础颜色", Color) = (1, 1, 1, 1)

        [Enum_Switch(Value, Texture)] _TriplanarMetallicGlossUse("金属光滑度 值/图", float) = 0
        [Switch(Value)]_TriplanarGlossiness("光滑度 (Smoothness)", Range(0.0, 1.0)) = 0.5
        [Switch(Value)]_TriplanarMetallic("金属度 (Metallic)", Range(0.0, 1.0)) = 0.0

        [Tex(_, Texture)][NoScaleOffset]_TriplanarMetallicGlossMap("金属光滑度贴图", 2D) = "white" {}
        [Switch(Texture)]_TriplanarGlossMapScale("光滑度缩放", Range(0.0, 1.0)) = 1.0

        [Tex(_TriplanarBumpScale)][NoScaleOffset] _TriplanarBumpMap("法线贴图", 2D) = "bump" {}
        [HideInInspector]_TriplanarBumpScale("法线缩放", Range(0, 1)) = 1.0

        [Tex(_TriplanarOcclusionStrength)][NoScaleOffset]_TriplanarOcclusionMap("环境光遮蔽 (Occlusion)", 2D) = "white" {}
        [HideInInspector]_TriplanarOcclusionStrength("环境光遮蔽强度", Range(0.0, 1.0)) = 1.0

        [Foldout_Out(1)] _F_Out_Triplanar("F_Out_Triplanar_Foldout", float) = 1

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
            #pragma shader_feature_local _METALLICGLOSSUSE_VALUE _METALLICGLOSSUSE_TEXTURE

            #pragma shader_feature_local _F_TRIPLANAR_ON
            #pragma shader_feature_local _TRIPLANARMETALLICGLOSSUSE_VALUE _TRIPLANARMETALLICGLOSSUSE_TEXTURE

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

            #include "Library/TerrainTriplanarInput.hlsl"
            #include "Library/TerrainTriplanarGBufferPass.hlsl"

            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            // -------------------------------------
            // Universal Pipeline keywords

            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
    }


    CustomEditor "Scarecrow.SimpleShaderGUI"
}
