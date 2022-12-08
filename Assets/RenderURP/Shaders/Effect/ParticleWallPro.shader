


Shader "Inutan/URP/Effect/ParticleWallPro 粒子阻挡墙高级版" {
    // --------------------------------------------
    Properties {
        // level/style/toggle/open/showlist
        [Foldout(1, 1, 0, 1)] _F_Basic("基础_Foldout", float) = 1 // 0表示不可以编辑
        
        // UnityEngine.Rendering.CullMode
        [Enum_Switch(Off, Front, Back)] _CullMode("Cull Mode", float) = 0

        // 加两条下划线，防止继承默认材质球中同名的属性，选起来麻烦
        [Enum_Switch(Off, On)] __ZWrite("ZWrite", float) = 0
        [Enum(UnityEngine.Rendering.BlendMode)] __SrcBlend("Src Factor", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] __DstBlend("Dst Factor", Float) = 1

        //
        [Foldout(1, 1, 0, 1)] _F_Common("通用_Foldout", float) = 1
        [HDR] _Color("颜色", Color) = (1, 1, 1, 1)
        _Intensity("强度", Range(0, 2)) = 1
        _GlobalTiling("XY : 全局Tiling", float) = (1, 1, 0, 0)
        [Toggle_Switch][HideInInspector] _AutoScaleUV("Tiling自适应缩放 (只匹配XY轴)", float) = 1

        [Foldout(2, 2, 0, 1)] _F_NormalTex("法线_Foldout", float) = 1
        [Toggle_Switch] _UseGlobalTiling_N("使用全局Tiling", float) = 1
        [Tex(_NormalScale)] _NormalTex("法线", 2D) = "bump" {}
        [HideInInspector] _NormalScale("法线强度", Range(0, 1)) = 1
        _RefractionDistance("折射厚度", float) = 0
        [Foldout_Out(2)]_F_NormalTex_Out("F_NormalTex_Out_Foldout", float) = 1

        [Foldout(2, 2, 1, 1)] _F_DetialTex_1("贴图1_Foldout", float) = 1
        [Toggle_Switch] _UseScreenUV_1("使用屏幕空间UV", float) = 0
        [Toggle_Switch] _UseGlobalTiling_1("使用全局Tiling", float) = 1
        [Toggle_Switch] _UseAdd_1("加法混合", float) = 0
        [Tex] _DetialTex_1("贴图", 2D) = "white" {}
        [Foldout_Out(2)] _F_DetialTex_1_Out("F_DetialTex_1_Out_Foldout", float) = 1

        [Foldout(2, 2, 1, 1)] _F_DetialTex_2("贴图2_Foldout", float) = 1
        [Toggle_Switch] _UseScreenUV_2("使用屏幕空间UV", float) = 0
        [Toggle_Switch] _UseGlobalTiling_2("使用全局Tiling", float) = 1
        [Toggle_Switch] _UseAdd_2("加法混合", float) = 0
        [Tex] _DetialTex_2("贴图", 2D) = "white" {}
        [Foldout_Out(2)] _F_DetialTex_2_Out("F_DetialTex_2_Out_Foldout", float) = 1

        [Foldout(2, 2, 1, 1)] _F_DetialTex_3("贴图3_Foldout", float) = 1
        [Toggle_Switch] _UseScreenUV_3("使用屏幕空间UV", float) = 0
        [Toggle_Switch] _UseGlobalTiling_3("使用全局Tiling", float) = 1
        [Toggle_Switch] _UseAdd_3("加法混合", float) = 0
        [Tex] _DetialTex_3("贴图", 2D) = "white" {}
        [Foldout_Out(2)] _F_DetialTex_3_Out("F_DetialTex_3_Out_Foldout", float) = 1

        [Foldout(2, 2, 1, 1)] _F_DetialTex_4("贴图4_Foldout", float) = 1
        [Toggle_Switch] _UseScreenUV_4("使用屏幕空间UV", float) = 0
        [Toggle_Switch] _UseGlobalTiling_4("使用全局Tiling", float) = 1
        [Toggle_Switch] _UseAdd_4("加法混合", float) = 0
        [Tex] _DetialTex_4("贴图", 2D) = "white" {}
        [Foldout_Out(2)] _F_DetialTex_4_Out("F_DetialTex_4_Out_Foldout", float) = 1
        
        //
        [Foldout(1, 1, 1, 1)] _F_Fade("渐变_Foldout", float) = 1
        [Tex(_FadeIntensity)] _FadeTex("渐变贴图", 2D) = "white" {}
        [HideInInspector] _FadeIntensity("渐变强度", Range(0, 1)) = 1
        [Foldout_Out(2)] _F_Fade_Out("F_Fade_Out_Foldout", float) = 1

        //
        [Foldout(1, 1, 1, 1)] _F_Dissolve("溶解_Foldout", float) = 1
        [Toggle_Switch] _UseGlobalTiling_D("使用全局Tiling", float) = 1
        [Tex(_DissolveThreshold)] _DissolveTex("溶解贴图", 2D) = "white" {}
        [HideInInspector] _DissolveThreshold("溶解阈值", Range(-1, 1)) = 0

        [Space]
        [Tex] _DissolveMaskTex_1("溶解遮罩1", 2D) = "white" {}
        [Tex] _DissolveMaskTex_2("溶解遮罩2", 2D) = "white" {}
        _DissolveMaskBlend("溶解遮罩混合", Range(0, 1))= 0

        [Foldout_Out(2)] _F_Dissolve_Out("F_Dissolve_Out_Foldout", float) = 1

        // --------------------------------------------
        [Foldout_Out(1)] _F_Out("F_Out_Foldout", float) = 1
    }

    // --------------------------------------------
    SubShader {
        // 放在半透明前面 只对不透明进行折射
        Tags {"Queue"="Transparent-1" "IgnoreProjector"="True" "RenderType"="Transparent" "RenderPipeline" = "UniversalPipeline"}

        Pass {
            Name "ParticleWallPro"

            Cull [_CullMode]
            ZWrite [__ZWrite]
            Blend [__SrcBlend] [__DstBlend]
            Offset -1, -1
            
            HLSLPROGRAM
            #pragma target 4.0

            #pragma shader_feature_local _AUTOSCALEUV_ON

            #pragma shader_feature_local _F_DETIALTEX_1_ON
            #pragma shader_feature_local _F_DETIALTEX_2_ON
            #pragma shader_feature_local _F_DETIALTEX_3_ON
            #pragma shader_feature_local _F_DETIALTEX_4_ON

            #pragma shader_feature_local _F_FADE_ON
            #pragma shader_feature_local _F_DISSOLVE_ON

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex ParticleWallProVertex
            #pragma fragment ParticleWallProFragment

            #include "Library/ParticleWallProCore.hlsl"

            ENDHLSL
        }
    }

    // --------------------------------------------
    CustomEditor "Scarecrow.SimpleShaderGUI"
}