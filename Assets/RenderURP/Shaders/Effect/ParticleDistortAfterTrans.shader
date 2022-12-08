


Shader "Inutan/URP/Effect/ParticleDistortAfterTrans 粒子扭曲 (包括半透物体)" {
    // --------------------------------------------
    Properties {
        // level/style/toggle/open/showlist
        [Foldout(1, 1, 0, 1)] _F_Basic("基础_Foldout", float) = 1 // 0表示不可以编辑
        
        // UnityEngine.Rendering.CullMode
        [Enum_Switch(Off, Front, Back)] _CullMode("Cull Mode", float) = 2

        // 加两条下划线，防止继承默认材质球中同名的属性，选起来麻烦
        [Enum_Switch(Off, On)] __ZWrite("ZWrite", float) = 0
        
        //
        [Foldout(1, 1, 0, 1)] _F_Distort("扭曲_Foldout", float) = 1
        [Tex(_DistortIntensity)] _DistortTex("扭曲贴图 (默认使用法线贴图)", 2D) = "white" {}
        [Toggle_Switch] _UseCustomTex("使用黑白图格式 (RG: 控制扭曲方向 A: 控制扭曲强度)", float) = 0
        [HideInInspector]_DistortIntensity("扭曲强度", Range(0, 2)) = 1
        [Toggle_Switch] _UseCustomData("使用CustomData (1.x:强度)", float) = 0
        _DistortUVSpeedX("扭曲贴图 UV速度 X", Range(-10, 10)) = 0
        _DistortUVSpeedY("扭曲贴图 UV速度 Y", Range(-10, 10)) = 0
        [Foldout_Out(1)] _F_Distort_Out("_F_Distort_Out_Foldout", float) = 1

        // --------------------------------------------
        [Foldout_Out(1)] _F_Out("F_Out_Foldout", float) = 1
    }

    // --------------------------------------------
    SubShader {
        Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" "RenderPipeline" = "UniversalPipeline"}

        Pass {
            Name "ParticleDistortAfterTrans"
            // 放在这个位置 基本对于大部分层级物体都会进行扭曲
            Tags { "LightMode"="AfterTransparentPass" }

            Cull [_CullMode]
            ZWrite [__ZWrite]
            Offset -1, -1
            
            HLSLPROGRAM
            #pragma target 4.0

            #pragma shader_feature_local _USECUSTOMTEX_ON
            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex ParticleDistortVertex
            #pragma fragment ParticleDistortFragment

            #include "Library/ParticleDistortCore.hlsl"

            ENDHLSL
        }
    }

    // --------------------------------------------
    CustomEditor "Scarecrow.SimpleShaderGUI"
}