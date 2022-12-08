


Shader "Inutan/URP/Character/ToonEye 眼睛" {
    // --------------------------------------------
    Properties {
        // level/style/toggle/open/showlist
        [Foldout(1, 1, 0, 1)] _F_Basic("Basic_Foldout", float) = 1 // 0表示不可以编辑

        // UnityEngine.Rendering.CullMode
        [Enum_Switch(Off, Front, Back)] _CullMode("Cull Mode", float) = 2
        _BloomIntensity("BloomIntensity", Range(0, 1)) = 0
        [Foldout_Out(1)] _F_Basic_Out("F_Basic_Out_Foldout", float) = 1

        // --------------------------------------------
        [Foldout(1, 1, 0, 1)] _F_Eye("基础_Foldout", float) = 1
        [Tex][NoScaleOffset] _MainTex("基础贴图 (A通道是高光部分)", 2D) = "white" {}
        _SpecularPower("高光强度", Range(1, 10)) = 1
        [Toggle_Switch] _HideSpecular ("隐藏高光", Float ) = 0
        [Foldout_Out(1)] _F_Eye_Out("F_Eye_Out_Foldout", float) = 1

         // --------------------------------------------
        [Foldout(1, 1, 1, 1)] _F_Eye_Lighting("光照_Foldout", float) = 0
        _BrightColor("明部颜色", Color) = (1, 1, 1, 1)
        _DarkColor("暗部颜色", Color) = (1, 1, 1, 1)
        _Shift_01("阴影边界偏移", Range(0, 1)) = 0.5
        _Gradient_01("阴影梯度变化", Range(0.0001, 1)) = 0.0001
        _LightIntensityLimit("光源最高强度限制", Range(1, 10)) = 1
        [Toggle_Switch] _UseShadowMap("使用遮挡阴影", float) = 0
        [Foldout_Out(1)] _F_Eye_Lighting_Out("F_Eye_Lighting_Out_Foldout", float) = 1

        // --------------------------------------------
        [Foldout(1, 1, 1, 1)] _F_Eye_SpecularAnim("高光动画_Foldout", float) = 0
        [Vector3(1)] _EyePosition("眼睛位置", float) = (0, 0, 0, 0)
        [Vector3(0)] _EyeRotation("眼睛朝向", float) = (0, 0, 1, 0)
        _EyeSpecularSpeed("高光旋转速度", Range(0, 1)) = 0.2
        _EyeSpecularAngle("高光旋转角度", Range(0, 10)) = 4
        [Foldout_Out(1)] _F_Eye_SpecularAnim_Out("F_Eye_SpecularAnim_Out_Foldout", float) = 1

        // --------------------------------------------
        [Foldout(1, 1, 1, 1)] _F_Eye_UVAnim("UVAnim_Foldout", float) = 0
        _UVAnimDistortOffset("X:扭曲偏移 Y:扭曲密度", Vector) = (0.5, 0.5, 0.5, 0.5)
        _UVAnimDistortIntensity("扭曲强度", Range(0, 1)) = 0.02
        _UVAnimSpeed("速度", Range(0, 1)) = 0.2
        _UVAnimIntensity("抖动强度", Range(0, 1)) = 0.001
        [Foldout_Out(1)] _F_Eye_UVAnim_Out("F_Eye_UVAnim_Out_Foldout", float) = 1
    }

    // --------------------------------------------
    SubShader {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True"}

        Pass {
            Name "ToonEye"

            Cull [_CullMode]

            HLSLPROGRAM
            #pragma target 4.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _F_EYE_SPECULARANIM_ON
            #pragma shader_feature_local _F_EYE_UVANIM_ON
            #pragma shader_feature_local _HIDESPECULAR_ON
            #pragma shader_feature_local _F_EYE_LIGHTING_ON
            #pragma shader_feature_local_fragment _USESHADOWMAP_ON

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

            #pragma vertex ToonEyeVertex
            #pragma fragment ToonEyeFragment

            #include "ToonLibrary/ToonEyePass.hlsl"

            ENDHLSL
        }

        Pass {
            Name "ToonEyeShadowCaster"
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

            #include "ToonLibrary/ToonEyeInput.hlsl"
            #include "ToonLibrary/ToonShadowCasterPass.hlsl"

            ENDHLSL
        }
    }

    // --------------------------------------------
    CustomEditor "Scarecrow.SimpleShaderGUI"
}