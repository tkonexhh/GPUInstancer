
Shader "Inutan/URP/Scene/Decal/DecalDirt 贴花污渍"
{
	Properties
	{
		// Base
		// level/style/toggle/open/showlist
		[Foldout(1, 1, 0, 1)] _F_Basic("基础_Foldout", float) = 1 // 0表示不可以编辑
		[Tex(_Color)] _MainTex("基础贴图", 2D) = "white" {}
		[HideInInspector]_Color("颜色", Color) = (1, 1, 1, 1)

		[Tex(_BumpScale)][NoScaleOffset]_BumpMap("法线贴图", 2D) = "bump" {}
		[HideInInspector]_BumpScale("NormalScale", Range(0, 1)) = 0

		[Tex(_Metallic)][NoScaleOffset]_MetallicGlossMap("金属度", 2D) = "white"{}
		[HideInInspector]_Metallic("金属", Range(0, 1)) = 0.5

		_Smoothness("光滑度", Range(0, 1)) = 0.5

		[Tex(_OcclusionStrength)][NoScaleOffset]_OcclusionMap("环境遮罩贴图", 2D) = "white"{}
		[HideInInspector]_OcclusionStrength("环境遮罩强度", Range(0,1)) = 1

		// Dissolve
		[Foldout(1, 1, 1, 1)] _F_Dissolve("溶解_Foldout", float) = 0
		[Tex] _DissolveTex("溶解贴图", 2D) = "white" {}
		[Enum_Switch(R, G, B, A)] _DissolveChannel("使用溶解贴图通道", float) = 0
		[Toggle_Switch] _DissolveInvert("贴图反转", float) = 0
		[Space(10)]
		_DissolveThreshold("溶解阈值", Range(0, 1)) = 0.5
		[Space(10)]
		_DissolveSpread("溶解渐变", Range(0, 1)) = 0.5
		_DissolveEdgeWidth("溶解边缘宽度", Range(0, 1)) = 0
		[HDR]_DissolveEdgeColor("溶解边缘颜色", Color) = (1, 1, 1, 1)
		[Foldout_Out(1)] _F_Dissolve_Out("_F_Dissolve_Out_Foldout", float) = 1

		// Emission
		[Foldout(1, 1, 1, 1)] _F_Emission("自发光_Foldout", float) = 0
		[Tex()][NoScaleOffset] _EmissionTex("自发光贴图", 2D) = "black" {}
		[HDR]_EmissionColor("自发光颜色", Color) = (1, 1, 1, 1)
		[Foldout_Out(1)] _F_Emission_Out("_F_Emission_Out_Foldout", float) = 1
	}

	SubShader
	{
		Tags {"RenderType" = "Transparent" "Queue" = "Transparent+100" "RenderPipeline" = "UniversalPipeline"}

		Pass
		{
			Name "DecalDirt"
			Tags{"LightMode" = "AfterTransparentPass"}

			Blend SrcAlpha OneMinusSrcAlpha

			HLSLPROGRAM
			// -------------------------------------
			// Material Keywords
			#pragma shader_feature_local _F_DISSOLVE_ON
			#pragma shader_feature_local _F_USEMETALLICTEX_ON
			#pragma shader_feature_local _F_USESMOOTHNESSTEX_ON
			#pragma shader_feature_local _F_EMISSION_ON

			// -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _CLUSTERED_RENDERING

			// -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ DEBUG_DISPLAY

			// GPU Instancing
			#pragma multi_compile_instancing

			#pragma vertex DecalDirtPassVertex
			#pragma fragment DecalDirtPassFragment

			#include "Library/DecalDirtPBRInput.hlsl"
			#include "Library/DecalDirtPBRForwardPass.hlsl"

			ENDHLSL
		}
	}

	// --------------------------------------------
	CustomEditor "Scarecrow.SimpleShaderGUI"
}