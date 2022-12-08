
Shader "Inutan/URP/Scene/Water/WaterFlow 流动面片水"
{
    Properties 
    {
        // level/style/toggle/open/showlist
        [Foldout(1, 1, 0, 1)] _F_Basic("Basic_Foldout", float) = 1
        
        // UnityEngine.Rendering.CullMode
        [Enum_Switch(Off, Front, Back)] _CullMode("Cull Mode", float) = 0
        [Enum_Switch(Off, On)] _ZWrite("ZWrite", float) = 0

        // --------------------------------------------
        [Foldout(1, 1, 0, 1)] _F_UVAnim("UVAnim_Foldout", float) = 1
        _UVSpeedX("UV速度 X", Range(0, 1)) = 0
        _UVSpeedY("UV速度 Y", Range(0, 1)) = 0

        [Foldout(1, 1, 0, 1)] _F_Normal("Normal_Foldout", float) = 1

        [Tex(_NormalScale)] _NormalTex("法线贴图", 2D) = "bump" {}
        [HideInInspector] _NormalScale("NormalScale", Range(0, 1)) = 0

        [Foldout_Out(1)] _F_Normal_Out("_F_Normal_Out_Foldout", float) = 1

        [Foldout(1, 1, 0, 1)] _F_Mask("Mask_Foldout", float) = 1
        [Tex(_MaskIntensity)] _MaskTex("遮罩 (R 通道)", 2D) = "white" {}
        [HideInInspector] _MaskIntensity("MaskIntensity", Range(0, 20)) = 1

        [Foldout(1, 1, 0, 1)] _F_Reflection("反射_Foldout", float) = 1
        _ReflectionStrength("反射强度", Range(0, 10)) = 1
        [Tex][NoScaleOffset] _ReflectCubemap("Cubemap", CUBE) = "black" {}

        // --------------------------------------------
        [Foldout(1, 1, 0, 1)] _F_Light("灯光和高光_Foldout", float) = 1

        [Toggle_Switch] _UserLightDirection("自定主光源方向", float) = 0
        [Vector3(0, _UserLightDirection)] _LightDirection("主光源方向", float) = (1, 0, 0, 0)

        [Foldout(2, 2, 0, 1)] _F_Specular("高光_Foldout", float) = 1
        _SpecularRoughness("高光范围", Range(0, 0.5)) = 0.06
        _SpecularColor("高光颜色", Color) = (1, 1, 1, 1)
        _SpecularIntensity("高光强度", Range(0, 13)) = 2
      
        [Foldout_Out(1)] _F_Light_Out("_F_Light_Out_Foldout", float) = 1

        [Foldout_Out(1)] _F_Out("F_Out_Foldout", float) = 1
    }


    SubShader 
    {
        Tags {"Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" "DisableBatching"="True" "RenderPipeline" = "UniversalPipeline"}

        Pass {
            Name "WaterFlow"
            // 为了能获取到Transparent之后的GrabPass，需要额外添加一个RenderFeature
            Tags{"LightMode" = "AfterTransparentPass"}

            ZWrite [_ZWrite]
            Cull[_CullMode]
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma target 4.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _USERLIGHTDIRECTION_ON

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            // -------------------------------------
            // Unity defined keywords
			#pragma multi_compile_fog

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex WaterVertex
            #pragma fragment WaterFlowFragment

            #include "Library/WaterFlowInput.hlsl"
            #include "Library/WaterFlowCore.hlsl"

            ENDHLSL
        }
     
    }

    CustomEditor "Scarecrow.SimpleShaderGUI"
}
