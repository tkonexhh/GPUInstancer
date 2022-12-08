
Shader "Inutan/URP/Scene/Water/WaterOcean 海面"
{
    Properties 
    {
        // level/style/toggle/open/showlist
        [Foldout(1, 1, 0, 1)] _F_Basic("Basic_Foldout", float) = 1
        
        // UnityEngine.Rendering.CullMode
        [Enum_Switch(Off, Front, Back)] _CullMode("Cull Mode", float) = 2
        [Enum_Switch(Off, On)] _ZWrite("ZWrite", float) = 1
        // [Tex][NoScaleOffset]_MirrorReflectionMap("_MirrorReflectionMap", 2D) = "white" {}

        // --------------------------------------------
        [Foldout(1, 1, 0, 1)] _F_Normal("Normal_Foldout", float) = 1

        [Tex(_NormalScale)][NoScaleOffset]_NormalTex("法线贴图", 2D) = "bump" {}
        [HideInInspector] _NormalScale("NormalScale", Range(0, 1)) = 0
        _NormalTiling("法线 Tiling", float) = 1

        [Foldout_Out(1)] _F_Normal_Out("_F_Normal_Out_Foldout", float) = 1

        // --------------------------------------------
        [Foldout(1, 1, 0, 1)] _F_Outer("水体_Foldout", float) = 1
        _WaterSpeed("水流速度", Range(0, 2)) = 1

        [Foldout(2, 2, 0, 1)] _F_OuterColor("颜色_Foldout", float) = 1
     
        _WaterColor("水体颜色 (垂直角度)", Color) = (1, 1, 1, 1)
        _WaterColorGrazing("水体颜色 (平行角度)", Color) = (1, 1, 1, 1)
        _FadeShallow("浅水渐变", Range(0, 50)) = 10
        _WaterColorShallow("水体颜色 (浅水, 色盘颜色仅作参考)", Color) = (1, 1, 1, 1)
        _FadeShallowSp("浅水过度", Range(0, 1)) = 1

        [Foldout(2, 2, 0, 1)] _F_OuterReflection("反射_Foldout", float) = 1
        _ReflectionStrength("反射强度", Range(0, 10)) = 1
        _ReflectionFixColor("修正颜色", Color) = (1, 1, 1, 1)
        [Toggle_Switch] _UseReflectionProbe("使用反射探针", float) = 0
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
        _SpecularDist("高光远近缩放参数", Range(0, 1)) = 0.115
        _SpecularMipmap("自定义Mipmap", Range(0, 7)) = 2.5
        _SpecularNormalScale("高光法线强度", Range(0, 1)) = 1
        _SpecularRoughness("高光范围", Range(0, 0.5)) = 0.06
        _SpecularColor("高光颜色", Color) = (1, 1, 1, 1)
        _SpecularIntensity("高光强度", Range(0, 13)) = 2
        _SpecularPower("高光密度", Range(1, 5)) = 3

        [Foldout_Out(1)] _F_Light_Out("_F_Light_Out_Foldout", float) = 1

        // --------------------------------------------
        [Foldout(1, 1, 1, 1)] _F_Caustics("焦散_Foldout", float) = 0
        [Tex(_CausticsColor)][NoScaleOffset]_CausticsTex("焦散贴图", 2D) = "white" {}
        [HideInInspector]_CausticsColor("焦散颜色", Color) = (1, 1, 1, 1)
        _CausticsIntensity("焦散强度", Range(0, 10)) = 5
        _CausticsTiling("Tiling", float) = 8
        _CausticsSpeed("速度", Range(0, 1)) = 0.3
        [Range] _CausticsRange("渐变范围", float) = (3.5, 8, 0, 10)
        _CausticsDistort("扭曲度", Range(0, 5)) = 1
        [Foldout_Out(1)] _F_Caustics_Out("_F_Caustics_Out_Foldout", float) = 1

        // --------------------------------------------
        [Foldout(1, 1, 1, 1)] _F_Foam("泡沫_Foldout", float) = 0
        [Tex(_FoamIntensity)][NoScaleOffset]_FoamTex("泡沫贴图", 2D) = "white" {}
        [HideInInspector]_FoamIntensity("泡沫强度", Range(0, 10)) = 1
        _FoamTiling("Tiling", float) = 0.32
        _FoamFeather("过渡", Range(0, 1)) = 1
        _FoamThreshold("阈值", Range(0, 5)) = 1.23
        _FoamSpeed("速度", Range(0, 1)) = 0.5
        [Space(10)]
        _FoamNormalIntensity("法线强度", Range(0, 1)) = 1
        _FoamNormalOffset("法线偏移", Range(0, 1)) = 0.11
        _FoamNormalWrap("明暗强弱", Range(0, 1)) = 0
        [Foldout_Out(1)] _F_Foam_Out("_F_Foam_Out_Foldout", float) = 1

        [Foldout_Out(1)] _F_Out("F_Out_Foldout", float) = 1
    }


    SubShader 
    {
        // 渲染队列排在半透明部分 GrabPass 暂时设定在AfterSkyBox 不考虑半透明物体的反射
        Tags {"Queue"="Transparent-1" "RenderType"="Transparent" "IgnoreProjector"="True" "DisableBatching"="True" "RenderPipeline" = "UniversalPipeline"}

        Pass {

            Name "WaterOcean"

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

            #pragma shader_feature_local _USEREFLECTIONPROBE_ON
            #pragma shader_feature_local _USESSR_ON

            #pragma shader_feature_local _F_CAUSTICS_ON
            #pragma shader_feature_local _F_FOAM_ON

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
            #pragma fragment WaterOceanFragment

            #include "Library/WaterOceanInput.hlsl"
            #include "Library/WaterOceanCore.hlsl"

            ENDHLSL
        }
    }

    CustomEditor "Scarecrow.SimpleShaderGUI"
}
