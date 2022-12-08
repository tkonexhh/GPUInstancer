


Shader "Hidden/Inutan/URP/Effect/ParticleWaterDeprecated" {
    // --------------------------------------------
    Properties {
        // level/style/toggle/open/showlist
        [Foldout(1, 1, 0, 1)] _F_Basic("基础_Foldout", float) = 1 // 0表示不可以编辑
        
        // UnityEngine.Rendering.CullMode
        [Enum_Switch(Off, Front, Back)] _CullMode("Cull Mode", float) = 2

        // 加两条下划线，防止继承默认材质球中同名的属性，选起来麻烦
        [Enum_Switch(Off, On)] __ZWrite("ZWrite", float) = 0
        
        [Foldout(1, 1, 0, 1)] _F_Common("通用_Foldout", float) = 1

        [Tex(_MainPower)] _MainTex("基础贴图", 2D) = "white" {}
        [HideInInspector]_MainPower("基础贴图对比度", Range(1, 5)) = 1
        [HDR]_LightColor("亮部颜色", Color) = (1, 1, 1, 1)
        [HDR]_ShadeColor("暗部颜色", Color) = (1, 1, 1, 1)
        _MainUVSpeedX("基础贴图 UV速度 X", Range(-10, 10)) = 0
        _MainUVSpeedY("基础贴图 UV速度 Y", Range(-10, 10)) = 0

        [Foldout_Out(1)] _F_Common_Out("_F_Common_Out_Foldout", float) = 1

        //
        [Foldout(1, 1, 0, 1)] _F_VertexNoise("顶点扰动_Foldout", float) = 1
        [Tex][NoScaleOffset] _VertexNoiseTex("贴图", 2D) = "white" {}
        _VertexNoiseIntensity("强度", Range(0, 2)) = 1
        _VertexNoiseFrequency("频率", Range(0, 10)) = 2
        _VertexNoiseSpeedX("速度 X", Range(-10, 10)) = 0
        _VertexNoiseSpeedY("速度 Y", Range(-10, 10)) = 0
        [Toggle_Switch]_VertexNoiseCalculate("计算方案", float) = 0

        [Foldout_Out(1)] _F_VertexNoise_Out("_F_VertexNoise_Out_Foldout", float) = 1

        // 
        [Foldout(1, 1, 0, 1)] _F_Normal("Normal_Foldout", float) = 1

        [Tex(_NormalScale)][NoScaleOffset] _NormalTex("法线贴图", 2D) = "bump" {}
        [HideInInspector] _NormalScale("NormalScale", Range(0, 1)) = 0
        _NormalTiling("法线Tiling", float) = 1
        _NormalUVDirection("法线UV流动方向 XY: 第一层 ZW: 第二层", Vector) = (-0.03, 0, 0.04, 0.04)
        _NormalUVSpeed("法线UV流动速度", Range(1, 5)) = 1
        _RefractionDistort("折射扭曲强度", Range(0, 1)) = 0

        [Foldout_Out(1)] _F_Normal_Out("_F_Normal_Out_Foldout", float) = 1

        [Foldout(1, 1, 0, 1)] _F_Reflection("反射_Foldout", float) = 1
        _ReflectionStrength("反射强度", Range(0, 10)) = 1
        [Tex][NoScaleOffset] _ReflectCubemap("Cubemap", CUBE) = "black" {}
        [HDR]_ReflectColor("反射颜色", Color) = (1, 1, 1, 1)

        [Foldout(1, 1, 0, 1)] _F_Specular("高光_Foldout", float) = 1
        _SpecularRoughness("高光范围", Range(0, 0.5)) = 0.06
        [HDR]_SpecularColor("高光颜色", Color) = (1, 1, 1, 1)
        _SpecularIntensity("高光强度", Range(0, 13)) = 2

        // --------------------------------------------
        [Foldout_Out(1)] _F_Out("F_Out_Foldout", float) = 1
    }

    // --------------------------------------------
    SubShader {
        Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" "RenderPipeline" = "UniversalPipeline"}

        Pass {
            Name "ParticleWater"
            // TODO 放在这个位置 基本对于大部分层级物体都会进行扭曲
            Tags { "LightMode"="AfterTransparentPass" }

            Cull [_CullMode]
            ZWrite [__ZWrite]
            Offset -1, -1
            
            HLSLPROGRAM
            #pragma target 4.0

            #pragma shader_feature_local _VERTEXNOISECALCULATE_ON

            #pragma shader_feature_local _F_RIM_ON
            #pragma shader_feature_local _F_RIMCOLOR_ON
            #pragma shader_feature_local _F_RIMFADE_ON
            #pragma shader_feature_local _F_CONTACT_ON
            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex ParticleWaterVertex
            #pragma fragment ParticleWaterFragment

            #include "Library/ParticleWaterCoreDeprecated.hlsl"

            ENDHLSL
        }
    }

    // --------------------------------------------
    CustomEditor "Scarecrow.SimpleShaderGUI"
}