
Shader "Inutan/URP/Scene/Water/WaterAquarium 水箱"
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
        _WaterDistortScale("扭曲度", Range(0, 1)) = 0.5

        [Foldout_Out(1)] _F_Normal_Out("_F_Normal_Out_Foldout", float) = 1

        // --------------------------------------------
        [Foldout(1, 1, 0, 1)] _F_Mesh("Mesh_Foldout", float) = 1
        _WaterSize("体积", Vector) = (10, 12, 10, 0)
        _WaterSpeed("水流速度", Range(0, 2)) = 0.1
        [Toggle_Switch] _DebugShowFade("显示计算后深度 (调试用)", float) = 0

        [Foldout(2, 2, 1, 1)] _F_Wave("波浪_Foldout", float) = 0
        [Enum_Switch(Sine, Gerstner)] _WaveType("波浪", float) = 0
        [Enum_Switch(_2, _4, _6)] _WaveNums("波浪叠加", float) = 0
        _WaveAmplitude("振幅", Range(0, 1)) = 0.3
        _WaveLength("波长", Range(0, 1)) = 1
        _WaveSpeed("速度", Range(0, 1)) = 0.5
        _WaveDir("方向", Range(0, 360)) = 255
        

        [Foldout_Out(1)] _F_Mesh_Out("_F_Mesh_Out_Foldout", float) = 1

        // --------------------------------------------
        [Foldout(1, 1, 0, 1)] _F_Inner("内侧_Foldout", float) = 1
        [Toggle_Switch] _UseInnerColor("调整内侧颜色", float) = 0
        [Switch(_UseInnerColor)]_InnerColor("内侧颜色", Color) = (1, 1, 1, 1)
        [Switch(_UseInnerColor)]_InnerLerp("内侧颜色过度", Range(0, 1)) = 1

        [Foldout_Out(1)] _F_Inner_Out("_F_Inner_Out_Foldout", float) = 1

        // --------------------------------------------
        [Foldout(1, 1, 0, 1)] _F_Outer("外侧_Foldout", float) = 1

        [Foldout(2, 2, 0, 1)] _F_OuterColor("颜色_Foldout", float) = 1
     
        _TurbidityColor("浑浊颜色 (加法)", Color) = (1, 1, 1, 1)
        _Turbidity("浑浊渐变", Range(0, 1)) = 0
        [Toggle_Switch] _DebugShowTurbidity("显示浑浊渐变 (调试用)", float) = 0
        _WaterColor("水体颜色 (乘法)", Color) = (1, 1, 1, 1)
        _Transparent("水体渐变", Range(0, 1)) = 0
        [Toggle_Switch] _DebugShowTransparent("显示水体渐变 (调试用)", float) = 0

        [Foldout(2, 2, 1, 1)] _F_Transmission("透射_Foldout", float) = 0
        _TransmissionColor("透射颜色", Color) = (1, 1, 1, 1)
        _TransmissionScale("透射强度", Range(0, 1)) = 1
        _TransmissionPower("透射渐变", Range(1, 4)) = 1

        [Foldout_Out(2)] _F_Transmission_Out("_F_Transmission_Out_Foldout", float) = 1


        [Foldout_Out(1)] _F_Outer_Out("_F_Outer_Out_Foldout", float) = 1

        // --------------------------------------------
        [Foldout(1, 1, 0, 1)] _F_Light("灯光和高光_Foldout", float) = 1

        [Toggle_Switch] _LightColorToSpecular("光源颜色影响高光", float) = 1
        [Toggle_Switch] _UserLightDirection("自定主光源方向", float) = 0
        [Vector3(0, _UserLightDirection)] _LightDirection("主光源方向", float) = (1, 0, 0, 0)
        _DiffuseLightIntensity("表面受光强度", Range(0, 1)) = 1
        _ShadowIntensity("表面阴影强度", Range(0, 1)) = 1

        [Foldout(2, 2, 0, 1)] _F_Specular("高光_Foldout", float) = 1
        _SpecularRoughness("高光范围", Range(0, 0.5)) = 0.06
        _SpecularColor("高光颜色", Color) = (1, 1, 1, 1)
        _SpecularIntensity("高光强度", Range(0, 13)) = 2

        [Foldout(2, 2, 1, 1)] _F_PointVolume("虚拟点体积光_Foldout", float) = 0
        [Vector3(1)]_PointVolumePos("位置", float) = (0, 0, 0, 0)
        _PointVolumeColor("颜色", Color) = (1, 1, 1, 1)
        _PointVolumeRadius("半径", Range(0, 100)) = 10
        _PointVolumeIntensity("强度", Range(0, 100)) = 1

        [Foldout_Out(1)] _F_Light_Out("_F_Light_Out_Foldout", float) = 1


        // --------------------------------------------
        [Foldout(1, 1, 1, 1)] _F_Caustics("焦散_Foldout", float) = 0

        _CausticsRangeGradient("区域衰减", Range(0, 10)) = 0
        [Toggle_Switch]_CausticsVerticalMask("遮蔽垂直表面焦散", float) = 0
        [Switch(_CausticsVerticalMask)]_CausticsVerticalThreshold("垂直遮蔽阈值", Range(-1, 1)) = 0

        [Toggle_Switch]_CausticsUseFunc("使用纯计算版本", float) = 0
        [Tex(_CausticsColor)][NoScaleOffset]_CausticsTex("焦散贴图", 2D) = "white" {}
        [HideInInspector]_CausticsColor("焦散颜色", Color) = (1, 1, 1, 1)
        _CausticsIntensity("焦散强度", Range(0, 10)) = 2
        _CausticsTiling("Tiling", float) = 0.4
        _CausticsSpeed("速度", Range(0, 1)) = 0.3

        [Toggle_Switch]_DebugShowCausticsMask("显示焦散蒙板 (调试用)", float) = 0
        [Toggle_Switch]_DebugShowCaustics("显示焦散 (调试用)", float) = 0



        [Foldout_Out(1)] _F_Out("F_Out_Foldout", float) = 1
    }


    SubShader 
    {
        Tags 
        {  
            "Queue"="Transparent" 
            "RenderType"="Transparent" 
            "IgnoreProjector"="True" 
            "DisableBatching"="True" 
            "RenderPipeline"="UniversalPipeline" 
            "LightMode"="WaterAquarium"
        }

        Pass 
        {
            Name "WaterAquariumInner"
            Tags { "LightMode"="AdditionPassOne" }
            
            ZWrite Off
            Cull Front
            Blend SrcAlpha OneMinusSrcAlpha
            
            HLSLPROGRAM
            #pragma target 4.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _F_WAVE_ON
            #pragma shader_feature_local _WAVETYPE_SINE _WAVETYPE_GERSTNER
            #pragma shader_feature_local _WAVENUMS__2 _WAVENUMS__4 _WAVENUMS__6

            #pragma shader_feature_local _USEINNERCOLOR_ON

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
            #pragma fragment WaterAquariumInnerFragment

            #include "Library/WaterAquariumInput.hlsl"
            #include "Library/WaterAquariumCore.hlsl"

            ENDHLSL
        }
        
        Pass 
        {
            Name "WaterAquariumOuterMulti"
            Tags { "LightMode"="AdditionPassTwo" }

            ZWrite Off
            Cull Back
            Blend Zero SrcColor

            HLSLPROGRAM
            #pragma target 4.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _F_WAVE_ON
            #pragma shader_feature_local _WAVETYPE_SINE _WAVETYPE_GERSTNER
            #pragma shader_feature_local _WAVENUMS__2 _WAVENUMS__4 _WAVENUMS__6

            #pragma shader_feature_local _F_CAUSTICS_ON
            #pragma shader_feature_local _CAUSTICSVERTICALMASK_ON
            #pragma shader_feature_local _CAUSTICSUSEFUNC_ON
            
            #pragma shader_feature_local _LIGHTCOLORTOSPECULAR_ON
            #pragma shader_feature_local _USERLIGHTDIRECTION_ON

            #pragma shader_feature_local _F_TRANSMISSION_ON
            #pragma shader_feature_local _F_POINTVOLUME_ON

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
            #pragma fragment WaterAquariumOuterMultiFragment

            #include "Library/WaterAquariumInput.hlsl"
            #include "Library/WaterAquariumCore.hlsl"

            ENDHLSL
        }

        Pass 
        {
            Name "WaterAquariumOuterAdd"
            Tags { "LightMode"="AdditionPassThree" }

            ZWrite [_ZWrite]
            Cull [_CullMode]
            Blend One SrcAlpha

            HLSLPROGRAM
            #pragma target 4.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _F_WAVE_ON
            #pragma shader_feature_local _WAVETYPE_SINE _WAVETYPE_GERSTNER
            #pragma shader_feature_local _WAVENUMS__2 _WAVENUMS__4 _WAVENUMS__6

            #pragma shader_feature_local _F_CAUSTICS_ON
            #pragma shader_feature_local _CAUSTICSVERTICALMASK_ON
            #pragma shader_feature_local _CAUSTICSUSEFUNC_ON

            #pragma shader_feature_local _LIGHTCOLORTOSPECULAR_ON
            #pragma shader_feature_local _USERLIGHTDIRECTION_ON

            #pragma shader_feature_local _F_TRANSMISSION_ON
            #pragma shader_feature_local _F_POINTVOLUME_ON

            #pragma shader_feature_local _DEBUGSHOWFADE_ON
            #pragma shader_feature_local _DEBUGSHOWTURBIDITY_ON
            #pragma shader_feature_local _DEBUGSHOWTRANSPARENT_ON
            #pragma shader_feature_local _DEBUGSHOWCAUSTICSMASK_ON
            #pragma shader_feature_local _DEBUGSHOWCAUSTICS_ON

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
            #pragma fragment WaterAquariumOuterAddFragment

            #include "Library/WaterAquariumInput.hlsl"
            #include "Library/WaterAquariumCore.hlsl"

            ENDHLSL
        }
       
        // TODO 扭曲后面考虑用蒙版统一处理
        Pass 
        {
            Name "WaterAquariumFinal"
            Tags { "LightMode"="AfterTransparentPass" }

            ZWrite On
            Cull Back
            
            HLSLPROGRAM
            #pragma target 4.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _F_WAVE_ON
            #pragma shader_feature_local _WAVETYPE_SINE _WAVETYPE_GERSTNER
            #pragma shader_feature_local _WAVENUMS__2 _WAVENUMS__4 _WAVENUMS__6

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
            #pragma fragment WaterAquariumFinalFragment

            #include "Library/WaterAquariumInput.hlsl"
            #include "Library/WaterAquariumCore.hlsl"

            ENDHLSL
        }
    }

    CustomEditor "Scarecrow.SimpleShaderGUI"
}
