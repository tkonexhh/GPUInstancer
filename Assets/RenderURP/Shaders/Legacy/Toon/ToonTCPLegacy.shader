
Shader "Inutan/URP/Legacy/Toon/ToonTCPLegacy 旧版本角色"
{
	Properties
	{
		_Color ("Color", Color) = (1,1,1,1)
		_HColor ("Highlight Color", Color) = (0.75,0.75,0.75,1)
		_SColor ("Shadow Color", Color) = (0.2,0.2,0.2,1)
		[Tex]_MainTex ("Albedo", 2D) = "white" {}

		_RampThreshold ("Threshold", Range(0.01,1)) = 0.5
		_RampSmoothing ("Smoothing", Range(0.001,1)) = 0.5
		
		_OutlineWidth ("Width", Range(0.1,4)) = 1
		_OutlineColorVertex ("Color", Color) = (0,0,0,1)
		//
		[Enum_Switch(_, _, Face)] _NormalsSource ("只是为了兼容以前脸部描边粗细", Float) = 0
	}

	SubShader
	{
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True"}

		Pass {
            Name "ToonTCPLegacy"
 			
			HLSLPROGRAM
            #pragma target 4.0
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

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer

            #pragma vertex ToonTCPLegacyVertex
            #pragma fragment ToonTCPLegacyFragment

			#include "Library/ToonTCPLegacyInput.hlsl"
            #include "Library/ToonTCPLegacyPass.hlsl"

            ENDHLSL
		}

		Pass {
            Name "ToonTCPLegacyOutline"
            Tags{"LightMode" = "ToonOutline"}

            Cull Front

            HLSLPROGRAM
            #pragma target 4.0

            // -------------------------------------
            // Material Keywords
            //--------------------------------------
			#pragma shader_feature_local _NORMALSSOURCE_FACE
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex ToonTCPLegacyOutlineVertex
            #pragma fragment ToonTCPLegacyOutlineFragment

			#include "Library/ToonTCPLegacyInput.hlsl"
            #include "Library/ToonTCPLegacyOutlinePass.hlsl"

            ENDHLSL
        }

        Pass {
            Name "ToonTCPLegacyShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Off
   
            HLSLPROGRAM
            #pragma target 4.0

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

			#include "Library/ToonTCPLegacyInput.hlsl"

            // -----------------------------------------------------------------
            // 替换默认的ShadowCasterPass中数据
            #define _BaseMap _MainTex
            #define _BaseMap_ST _MainTex_ST
            #define sampler_BaseMap sampler_MainTex
            #define _BaseColor 1
            #define _Cutoff 0

            half Alpha(half albedoAlpha, half4 color, half cutoff) { return 0; }
            half4 SampleAlbedoAlpha(float2 uv, TEXTURE2D_PARAM(albedoAlphaMap, sampler_albedoAlphaMap)) { return 0; }
            // -----------------------------------------------------------------

            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"

            ENDHLSL
        }

	}

	CustomEditor "Scarecrow.SimpleShaderGUI"
}
