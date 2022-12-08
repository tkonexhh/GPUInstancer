Shader "Inutan/URP/Scene/Parallax/ParallaxLit PBR视差"
{
    Properties
    {
        // Base
        // level/style/toggle/open/showlist
        [Foldout(1, 1, 0, 1)] _F_Basic("基础_Foldout", float) = 1 // 0表示不可以编辑

        // MARK_INUTAN
        [Toggle_Switch] _NearCameraFade("Near Camera Fade", Float) = 0.0
        [Enum_Switch(Both, Back, Front)] _Cull("面渲染模式", Float) = 2.0

        [Toggle_Switch] _UseCutoff("使用Alpha CutOff", Float) = 0.0
        [Switch(_UseCutoff)]_Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

        [Space]
        [Tex(_Color)] _MainTex("基础贴图", 2D) = "white" {}
        [HideInInspector]_Color("颜色", Color) = (1, 1, 1, 1)

        [Space]
        [Tex(_BumpScale)][NoScaleOffset]_BumpMap("法线贴图", 2D) = "bump" {}
        [HideInInspector]_BumpScale("NormalScale", Float) = 1.0

        [Space]
        [Tex(_)][NoScaleOffset]_MetallicGlossMap("金属度贴图(r:金属度 a:光滑度)", 2D) = "white"{}
        _Metallic("金属度", Range(0, 1)) = 0.5
        _Smoothness("光滑度", Range(0, 1)) = 0.5

        [Space]
        [Tex(_OcclusionStrength)][NoScaleOffset]_OcclusionMap("环境遮罩贴图", 2D) = "white"{}
        [HideInInspector]_OcclusionStrength("环境遮罩强度", Range(0,1)) = 1

        // Emission
        [Foldout(1, 1, 1, 1)] _F_Parallax("Parallax 视差_Foldout", float) = 0
        [Tex(_)][NoScaleOffset]_ParallaxMap("视差贴图", 2D) = "white"{}
        [Enum_Switch(URP, Iterations4)] _ParallaxType("计算模式", Float) = 1.0
        _Parallax("Parallax", Range(0.0, 0.1)) = 0.0
        _ParallaxTilling("Parallax Tilling", Float) = 1.0
        [Foldout_Out(1)] _F_Parallax_Out("_F_Parallax_Out_Foldout", float) = 1

        // Emission
        [Foldout(1, 1, 1, 1)] _F_Emission("自发光_Foldout", float) = 0
        [Tex()][NoScaleOffset] _EmissionMap("自发光贴图", 2D) = "white" {}
        [HDR]_EmissionColor("自发光颜色", Color) = (1, 1, 1, 1)
        [Foldout(2, 2, 1, 1)] _F_Sparkles("闪点_Foldout", float) = 0
        [Tex()] _SparklesNoiseMap("噪声图", 2D) = "black" {}
        [HDR]_SparklesColor("闪点颜色", Color) = (1, 1, 1, 1)
        _SparklesSpeed("自动速度", Range(0.0, 0.1)) = 0.02
        _SparklesCameraSpeed("镜头旋转变换速度", Range(0.0, 0.5)) = 0.04
        [Foldout_Out(2)] _F_Sparkles_Out("_F_Sparkles_Out_Foldout", float) = 1
        [Foldout_Out(1)] _F_Emission_Out("_F_Emission_Out_Foldout", float) = 1

        // Advanced Options
        [Foldout(1, 1, 0, 1)] _F_AdvancedOptions("Advanced Options_Foldout", float) = 1
        [Toggle_Switch] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [Toggle_Switch] _EnvironmentReflections("Environment Reflections", Float) = 1.0
        [Foldout_Out(1)] _F_AdvancedOptions_Out("_F_AdvancedOptions_Out_Foldout", float) = 1

    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True" }
        LOD 300

        Pass
        {
            Name "GBuffer"
            Tags{"LightMode" = "UniversalGBuffer"}

            ZWrite On
            ZTest LEqual
            Cull[_Cull]

            HLSLPROGRAM
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _USECUTOFF_ON
            #pragma shader_feature_local _F_PARALLAX_ON
            #pragma shader_feature_local_fragment _F_EMISSION_ON
            #pragma shader_feature_local_fragment _F_SPARKLES_ON
            #pragma shader_feature_local _PARALLAXTYPE_URP _PARALLAXTYPE_ITERATIONS4

            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_ON
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_ON
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF
            // MARK_INUTAN
            #pragma shader_feature_local _NEARCAMERAFADE_ON

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
            // MARK_INUTAN
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
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #pragma vertex ParallaxLitGBufferPassVertex
            #pragma fragment ParallaxLitGBufferPassFragment

            #include "Library/ParallaxLitInput.hlsl"
            #include "Library/ParallaxLitGBufferPass.hlsl"
            ENDHLSL
        }

        //  Shadow rendering pass
        Pass {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _USECUTOFF_ON

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            // -------------------------------------
            // Universal Pipeline keywords

            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            // -------------------------------------
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Library/ParallaxLitInput.hlsl"
            #include "Library/ParallaxLitShadowCasterPass.hlsl"

            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            #pragma target 4.5

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _USECUTOFF_ON

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "Library/ParallaxLitInput.hlsl"
            #include "Library/ParallaxLitDepthOnlyPass.hlsl"
            ENDHLSL
        }

        // This pass it not used during regular rendering, only for lightmap baking.
        Pass
        {
            Name "Meta"
            Tags{"LightMode" = "Meta"}

            Cull Off

            HLSLPROGRAM
            #pragma target 4.5

            #pragma vertex UniversalVertexMeta
            #pragma fragment UniversalFragmentMetaLit

            #pragma shader_feature EDITOR_VISUALIZATION
            #pragma shader_feature_local _USECUTOFF_ON
            #pragma shader_feature_local_fragment _F_EMISSION_ON

            #include "Library/ParallaxLitInput.hlsl"
            #include "Library/ParallaxLitMetaPass.hlsl"

            ENDHLSL
        }

        // ------------------------------------------------------------------
        //  Forward pass
        //  现在用来给RenderDebugger服务
        Pass
        {
            Name "ParallaxLit Forward"
            Tags{"LightMode" = "UniversalForward"}

            ZWrite On
            ZTest LEqual
            Cull[_Cull]

            HLSLPROGRAM
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _USECUTOFF_ON
            #pragma shader_feature_local _F_PARALLAX_ON
            #pragma shader_feature_local_fragment _F_EMISSION_ON
            #pragma shader_feature_local_fragment _F_SPARKLES_ON
            #pragma shader_feature_local _PARALLAXTYPE_URP _PARALLAXTYPE_ITERATIONS4

            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_ON
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_ON
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF
            // MARK_INUTAN
            #pragma shader_feature_local _NEARCAMERAFADE_ON

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _RENDER_PASS_ENABLED
            // MARK_INUTAN
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
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #pragma vertex ParallaxLitForwardPassVertex
            #pragma fragment ParallaxLitForwardPassFragment

            #include "Library/ParallaxLitInput.hlsl"
            #include "Library/ParallaxLitForwardPass.hlsl"
            ENDHLSL
        }
    }

    // --------------------------------------------
    CustomEditor "Scarecrow.SimpleShaderGUI"
}
