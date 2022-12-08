


Shader "Inutan/URP/Effect/ParticleAll 粒子综合" {
    // --------------------------------------------
    Properties {
        // level/style/toggle/open/showlist
        [Foldout(1, 1, 0, 1)] _F_Basic("基础_Foldout", float) = 1 // 0表示不可以编辑

        // UnityEngine.Rendering.CullMode
        [Enum_Switch(Off, Front, Back)] _CullMode("Cull Mode", float) = 2

        // 加两条下划线，防止继承默认材质球中同名的属性，选起来麻烦
        [Enum_Switch(Off, On)] __ZWrite("ZWrite", float) = 0
	    [Enum(UnityEngine.Rendering.BlendMode)] __SrcBlend("Src Factor", Float) = 5  // SrcAlpha
        [Enum(UnityEngine.Rendering.BlendMode)] __DstBlend("Dst Factor", Float) = 10 // OneMinusSrcAlpha

        [Foldout(1, 1, 0, 1)] _F_Common("通用_Foldout", float) = 1
        [Tex(_MainIntensity)] _MainTex("基础贴图", 2D) = "white" {}
        [HideInInspector] _MainIntensity("基础颜色强度", Range(0, 10)) = 1
        [HDR]_MainColor("基础颜色", Color) = (1, 1, 1, 1)
        [Toggle_Switch] _UseCustomData("使用CustomData (1.x:强度 2.rgb:颜色)", float) = 0
        [Toggle_Switch] _UseUV1("使用UV1 (配合 TextureSheetAnimation)", float) = 0
        [Toggle_Switch] _PreMultipAlpha("基础颜色预乘Alpha", float) = 0
        _MainUVSpeedX("基础贴图 UV速度 X", Range(-10, 10)) = 0
        _MainUVSpeedY("基础贴图 UV速度 Y", Range(-10, 10)) = 0
        [Foldout_Out(1)] _F_Common_Out("_F_Common_Out_Foldout", float) = 1

        //
        [Foldout(1, 1, 1, 1)] _F_UVDistort("UV扭曲_Foldout", float) = 0
        [Tex(_UVDistortIntensity)] _UVDistortTex("UV扭曲贴图", 2D) = "white" {}
        [HideInInspector]_UVDistortIntensity("UV扭曲强度", Range(0, 1)) = 1
        _UVDistortSpeedX("UV扭曲贴图 速度 X", Range(-10, 10)) = 0
        _UVDistortSpeedY("UV扭曲贴图 速度 Y", Range(-10, 10)) = 0
        [Toggle_Switch] _UseForMainTex("应用于基础UV", float) = 1
        [Toggle_Switch] _UseForDissolveTex("应用于溶解UV", float) = 0
        [Toggle_Switch] _UseForMaskTex("应用于蒙板UV", float) = 0
        [Foldout_Out(1)] _F_UVDistort_Out("_F_UVDistort_Out_Foldout", float) = 1

        //
        [Foldout(1, 1, 1, 1)] _F_VertexNoise("顶点扰动_Foldout", float) = 0
        [Tex(_VertexNoiseIntensity)] _VertexNoiseTex("顶点扰动贴图", 2D) = "white" {}
        [HideInInspector] _VertexNoiseIntensity("顶点扰动强度", Range(0, 1)) = 1
        _VertexNoiseUVSpeedX("顶点扰动贴图 UV速度 X", Range(-10, 10)) = 0
        _VertexNoiseUVSpeedY("顶点扰动贴图 UV速度 Y", Range(-10, 10)) = 0
        [Foldout_Out(1)] _F_VertexNoise_Out("_F_VertexNoise_Out_Foldout", float) = 1

        //
        [Foldout(1, 1, 1, 1)] _F_Rim("边缘_Foldout", float) = 0
        [Foldout(2, 2, 1, 1)] _F_RimColor("边缘颜色_Foldout", float) = 0
        [HDR]_RimColor("边缘颜色", Color) = (1, 1, 1, 1)
        _RimRange("边缘范围", Range(0, 1)) = 1
        _RimGradient("边缘过度", Range(0, 1)) = 1

        [Foldout(2, 2, 1, 1)] _F_RimFade("边缘渐变_Foldout", float) = 0
        _RimFadeRange("渐变范围", Range(0, 1)) = 1
        _RimFadeGradient("渐变过度", Range(0, 1)) = 1
        _RimFadePower("渐变过度Power", Range(0, 10)) = 1
        [Foldout_Out(1)] _F_Rim_Out("_F_Rim_Out_Foldout", float) = 1

        //
        [Foldout(1, 1, 1, 1)] _F_Contact("和物体接触_Foldout", float) = 0
        [HDR]_ContantColor("接触位置颜色", Color) = (1, 1, 1, 1)
        _ContactFade("过度范围", Range(0, 10)) = 1
        _ContactMaxDistance("过度范围调大造成深度穿帮时缩小该值", Range(0, 100)) = 100
        [Toggle_Switch] _ContactAlphaMode("渐变模式", float) = 0
        [Foldout_Out(1)] _F_Contact_Out("_F_Contact_Out_Foldout", float) = 1

        //
        [Foldout(1, 1, 1, 1)] _F_Dissolve("溶解_Foldout", float) = 0
        [Tex] _DissolveTex("溶解贴图", 2D) = "white" {}
        [Enum_Switch(R, G, B, A)] _DissolveChannel("使用溶解贴图通道", float) = 0
        [Toggle_Switch] _DissolveInvert("贴图反转", float) = 0
        [Toggle_Switch] _DissolveMultiUseCustomData("溶解系数使用CustomData (1:y)", float) = 0
        [NonSwitch(_DissolveMultiUseCustomData)]_DissolveMulti("溶解系数 (还原旧版本用 不推荐)", float) = 1
        [Space(10)]
        [Toggle_Switch] _DissolveUseCustomData("溶解阈值使用CustomData (1:y)", float) = 0
        [NonSwitch(_DissolveUseCustomData)]_DissolveThreshold("溶解阈值", Range(0, 1)) = 0.5
        [Space(10)]
        _DissolveSpread("溶解渐变", Range(0, 1)) = 0.5
        _DissolveEdgeWidth("溶解边缘宽度", Range(0, 1)) = 0
        [HDR]_DissolveEdgeColor("溶解边缘颜色", Color) = (1, 1, 1, 1)
        _DissolveUVSpeedX("溶解贴图 UV速度 X", Range(-10, 10)) = 0
        _DissolveUVSpeedY("溶解贴图 UV速度 Y", Range(-10, 10)) = 0
        [Toggle_Switch] _UseDissolveMask("使用溶解蒙板 (打开后在蒙板标签内)", float) = 0
        [Foldout_Out(1)] _F_Dissolve_Out("_F_Dissolve_Out_Foldout", float) = 1

        //
        [Foldout(1, 1, 1, 1)] _F_Mask("蒙板_Foldout", float) = 0

        [Foldout(2, 2, 1, 0)] _F_Mask_1("蒙板1_Foldout", float) = 0
        [Tex][NoScaleOffset] _MaskTex_1("蒙板贴图", 2D) = "white" {}
        [Enum_Switch(R, G, B, A)] _Mask_1_Channel("使用蒙板贴图通道", float) = 0
        [Toggle_Switch]_Mask_1_Invert("反转", float) = 0
        _Mask_1_Power("次方", Range(0, 10)) = 1
        _Mask_1_Target("遮蔽目标通道 [0:RGB 1:A]", Range(0, 1)) = 1
        [Toggle_Switch] _Mask_1_UseCustomData("Offset使用CustomData (1:zw)", float) = 0
        _Mask_1_Tiling("Tiling / Offset", vector) = (1, 1, 0, 0)
        _Mask_1_UVSpeedX("蒙板贴图 UV速度 X", Range(-10, 10)) = 0
        _Mask_1_UVSpeedY("蒙板贴图 UV速度 Y", Range(-10, 10)) = 0

        [Foldout(2, 2, 1, 0)] _F_Mask_2("蒙板2_Foldout", float) = 0
        [Tex][NoScaleOffset] _MaskTex_2("蒙板贴图", 2D) = "white" {}
        [Enum_Switch(R, G, B, A)] _Mask_2_Channel("使用蒙板贴图通道", float) = 1
        [Toggle_Switch]_Mask_2_Invert("反转", float) = 0
        _Mask_2_Power("次方", Range(0, 10)) = 1
        _Mask_2_Target("遮蔽目标通道 [0:RGB 1:A]", Range(0, 1)) = 1
        [Toggle_Switch] _Mask_2_UseCustomData("Offset使用CustomData (1:zw)", float) = 0
        _Mask_2_Tiling("Tiling / Offset", vector) = (1, 1, 0, 0)
        _Mask_2_UVSpeedX("蒙板贴图 UV速度 X", Range(-10, 10)) = 0
        _Mask_2_UVSpeedY("蒙板贴图 UV速度 Y", Range(-10, 10)) = 0

        [Foldout(2, 2, 1, 0)] _F_Mask_3("蒙板3_Foldout", float) = 0
        [Tex][NoScaleOffset] _MaskTex_3("蒙板贴图", 2D) = "white" {}
        [Enum_Switch(R, G, B, A)] _Mask_3_Channel("使用蒙板贴图通道", float) = 2
        [Toggle_Switch]_Mask_3_Invert("反转", float) = 0
        _Mask_3_Power("次方", Range(0, 10)) = 1
        _Mask_3_Target("遮蔽目标通道 [0:RGB 1:A]", Range(0, 1)) = 1
        [Toggle_Switch] _Mask_3_UseCustomData("Offset使用CustomData (1:zw)", float) = 0
        _Mask_3_Tiling("Tiling / Offset", vector) = (1, 1, 0, 0)
        _Mask_3_UVSpeedX("蒙板贴图 UV速度 X", Range(-10, 10)) = 0
        _Mask_3_UVSpeedY("蒙板贴图 UV速度 Y", Range(-10, 10)) = 0

        [Foldout(2, 2, 0, 0, _UseDissolveMask)] _F_Mask_d("溶解蒙板_Foldout", float) = 1
        [Tex][NoScaleOffset] _MaskTex_d("蒙板贴图", 2D) = "white" {}
        [Enum_Switch(R, G, B, A)] _Mask_d_Channel("使用蒙板贴图通道", float) = 3
        [Toggle_Switch]_Mask_d_Invert("反转", float) = 0
        _Mask_d_Power("次方", Range(0, 10)) = 1
        [Toggle_Switch] _Mask_d_UseCustomData("Offset使用CustomData (1:zw)", float) = 0
        _Mask_d_Tiling("Tiling / Offset", vector) = (1, 1, 0, 0)
        _Mask_d_UVSpeedX("蒙板贴图 UV速度 X", Range(-10, 10)) = 0
        _Mask_d_UVSpeedY("蒙板贴图 UV速度 Y", Range(-10, 10)) = 0
        [Foldout_Out(1)] _F_Mask_Out("_F_Mask_Out_Foldout", float) = 1

        //
        [Foldout(1, 1, 1, 1)] _F_ScreenMap("屏幕空间贴图_Foldout", float) = 0
        [Tex] _ScreenMapTex("屏幕空间贴图", 2D) = "white" {}
        [HDR] _ScreenMapColor("颜色", Color) = (1, 1, 1, 1)
        _ScreenMapUVSpeedX("屏幕空间贴图 UV速度 X", Range(-10, 10)) = 0
        _ScreenMapUVSpeedY("屏幕空间贴图 UV速度 Y", Range(-10, 10)) = 0
        [Foldout_Out(1)] _F_ScreenMap_Out("_F_ScreenMap_Out_Foldout", float) = 1

        // --------------------------------------------
        [Foldout_Out(1)] _F_Out("F_Out_Foldout", float) = 1
    }

    // --------------------------------------------
    SubShader {
        Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" "RenderPipeline" = "UniversalPipeline" "PreviewType"="Plane"}

        Pass {
            Name "ParticleAll"

            Cull[_CullMode]
            Blend [__SrcBlend] [__DstBlend]
            ZWrite [__ZWrite]
            Offset -1, -1

            HLSLPROGRAM
            #pragma target 4.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _F_MASK_ON
            #pragma shader_feature_local _F_MASK_1_ON
            #pragma shader_feature_local _F_MASK_2_ON
            #pragma shader_feature_local _F_MASK_3_ON
            #pragma shader_feature_local _USEDISSOLVEMASK_ON
            #pragma shader_feature_local _F_DISSOLVE_ON
            #pragma shader_feature_local _F_UVDISTORT_ON
            #pragma shader_feature_local _F_RIM_ON
            #pragma shader_feature_local _F_RIMCOLOR_ON
            #pragma shader_feature_local _F_RIMFADE_ON
            #pragma shader_feature_local _F_CONTACT_ON
            #pragma shader_feature_local _F_VERTEXNOISE_ON
            #pragma shader_feature_local _F_SCREENMAP_ON

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex ParticleVertex
            #pragma fragment ParticleFragment

            #include "Library/ParticleAllCore.hlsl"

            ENDHLSL
        }
    }

    // --------------------------------------------
    CustomEditor "Scarecrow.SimpleShaderGUI"
}