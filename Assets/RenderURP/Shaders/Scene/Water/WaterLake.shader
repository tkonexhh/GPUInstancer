
Shader "Inutan/URP/Scene/Water/WaterLake 湖面"
{
    Properties 
    {
        // level/style/toggle/open/showlist
        [Foldout(1, 1, 0, 1)] _F_Basic("Basic_Foldout", float) = 1
        
        // UnityEngine.Rendering.CullMode
        [Enum_Switch(Off, Front, Back)] _CullMode("Cull Mode", float) = 2
        [Enum_Switch(Off, On)] _ZWrite("ZWrite", float) = 1

        // --------------------------------------------
        [Foldout(1, 1, 0, 1)] _F_Normal("Normal_Foldout", float) = 1

        [Tex(_NormalScale)][NoScaleOffset]_NormalTex("法线贴图", 2D) = "bump" {}
        [HideInInspector] _NormalScale("NormalScale", Range(0, 1)) = 0
        _NormalTiling("法线 Tiling", float) = 1

        [Foldout_Out(1)] _F_Normal_Out("_F_Normal_Out_Foldout", float) = 1

        // --------------------------------------------
        [Foldout(1, 1, 0, 1)] _F_Outer("水体_Foldout", float) = 1
        _WaterSpeed("水流速度", Range(0, 2)) = 1
        _WaterDistortScale("折射扭曲度", Range(0, 1)) = 0

        [Foldout(2, 2, 0, 1)] _F_OuterColor("颜色_Foldout", float) = 1

        _WaterColor("水体颜色 (垂直角度)", Color) = (1, 1, 1, 1)
        _WaterColorGrazing("水体颜色 (平行角度)", Color) = (1, 1, 1, 1)
        _FadeShallow("浅水渐变", Range(0, 50)) = 0

        [Foldout(2, 2, 0, 1)] _F_OuterReflection("反射_Foldout", float) = 1
        _ReflectionStrength("反射强度", Range(0, 10)) = 1
        [Tex][NoScaleOffset] _ReflectCubemap("Cubemap", CUBE) = "black" {}
        [Toggle_Switch] _UseSSR("SSR", float) = 0
        [Switch(_UseSSR)]_SSRMaxCount("SSR最多步进次数", Range(1, 64)) = 64
        [Switch(_UseSSR)]_SSRStep("SSR步长", Range(1, 32)) = 32

        [Foldout_Out(1)] _F_Outer_Out("_F_Outer_Out_Foldout", float) = 1

        // --------------------------------------------
        [Foldout(1, 1, 0, 1)] _F_Light("灯光和高光_Foldout", float) = 1

        [Toggle_Switch] _LightColorToSpecular("光源颜色影响高光", float) = 1
        [Toggle_Switch] _UserLightDirection("自定主光源方向", float) = 0
        [Vector3(0, _UserLightDirection)] _LightDirection("主光源方向", float) = (1, 0, 0, 0)
        _DiffuseLightIntensity("表面受光强度", Range(0, 1)) = 1
        _ShadowIntensity("表面阴影强度", Range(0, 1)) = 1
        
        [Foldout(2, 2, 0, 1)] _F_Specular("高光_Foldout", float) = 1
        _SpecularNormalScale("高光法线强度", Range(0, 1)) = 1
        _SpecularRoughness("高光范围", Range(0, 0.5)) = 0.06
        _SpecularColor("高光颜色", Color) = (1, 1, 1, 1)
        _SpecularIntensity("高光强度", Range(0, 13)) = 2

        [Foldout_Out(1)] _F_Light_Out("_F_Light_Out_Foldout", float) = 1

        [Foldout_Out(1)] _F_Out("F_Out_Foldout", float) = 1
    }


    SubShader 
    {
        Tags {"Queue"="Transparent-1" "RenderType"="Transparent" "IgnoreProjector"="True" "DisableBatching"="True" "RenderPipeline" = "UniversalPipeline"}

        Pass {

            Name "WaterLake"

            // 写入需要打开 因为在Transparent中 自身计算时不包含自己的深度 
            // 深度是给Transparent之后使用的
            ZWrite [_ZWrite]
            Cull[_CullMode]

            HLSLPROGRAM
            #pragma target 4.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _LIGHTCOLORTOSPECULAR_ON
            #pragma shader_feature_local _USERLIGHTDIRECTION_ON
            #pragma shader_feature_local _USESSR_ON

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
            #pragma fragment WaterLakeFragment

            #include "Library/WaterLakeInput.hlsl"
            #include "Library/WaterLakeCore.hlsl"
            ENDHLSL
        }
     
    }

    CustomEditor "Scarecrow.SimpleShaderGUI"
}
