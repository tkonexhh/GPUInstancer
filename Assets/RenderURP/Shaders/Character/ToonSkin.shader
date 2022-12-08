


Shader "Inutan/URP/Character/ToonSkin 皮肤" {
    // --------------------------------------------
    Properties {
        // level/style/toggle/open/showlist
        [Foldout(1, 1, 0, 1)] _F_Basic("Basic_Foldout", float) = 1 // 0表示不可以编辑

        // UnityEngine.Rendering.CullMode
        [Enum_Switch(Off, Front, Back)] _CullMode("Cull Mode", float) = 2

        _BloomIntensity("BloomIntensity", Range(0, 1)) = 0

        // --------------------------------------------
        [Foldout(1, 1, 1, 1)] _F_Diffuse("Diffuse_Foldout", float) = 1

        [Tex(_BaseColor)][NoScaleOffset] _MainTex("基础贴图", 2D) = "white" {}
        [HideInInspector] _BaseColor("明部颜色", Color) = (1, 1, 1, 1)

        [Foldout(2, 2, 0, 1)] _Shade_1("第1层阴影_Foldout", float) = 1
        _ShadeColor_1("阴影颜色", Color) = (1, 1, 1, 1)
        _Shift_01("阴影边界偏移", Range(0, 1)) = 0.5
        _Gradient_01("阴影梯度变化", Range(0.0001, 1)) = 0.5

        [Foldout(3, 2, 1, 1)] _FakeSSS("阴影边界_Foldout", float) = 0
        _FakeSSSColor("颜色", Color) = (1, 1, 1, 1)
        [Range] _FakeSSSWidth("边界范围", float) = (0.09,0.11,0,0.5)

        [Foldout(2, 2, 1, 1)] _Face_Shade("脸部阴影_Foldout", float) = 0
        [Tex][NoScaleOffset] _FaceShade("脸部阴影", 2D) = "white" {}
        [Toggle_Switch] _FaceShadeUseUV1("使用UV2", float) = 0
        [Toggle_Switch] _FaceShadeLinear("线性过渡", float) = 1
        _FaceShadeOffset("脸部阴影偏移", Range(-3, 3)) = 0

        [Foldout_Out(1)] _F_Diffuse_Out("F_Diffuse_Out_Foldout", float) = 1

        // --------------------------------------------
        [Foldout(1, 1, 1, 1)] _F_Indirect("环境光_Foldout", float) = 0
        _InDirectIntensity("间接光总体强度", Range(0, 1)) = 1
        [Foldout_Out(1)] _F_Indirect_Out("F_Indirect_Out_Foldout", float) = 1

        // --------------------------------------------
        [Foldout(1, 1, 0, 1)] _F_Light("Light_Foldout", float) = 1
        [Toggle_Switch] _UserLightDirection("自定主光源方向", float) = 0
        [Vector3(0, _UserLightDirection)] _MainLightDirection("主光源方向", float) = (1, 0, 0, 0)

        [Toggle_Switch] _UseShadowMap("使用遮挡阴影", float) = 0
        [Toggle_Switch] _UseAdditionalLight("开启多光源", float) = 0
        _LightIntensityLimit("光源最高强度限制", Range(1, 10)) = 1

        [Foldout_Out(1)] _F_Light_Out("F_Light_Out_Foldout", float) = 1
        // --------------------------------------------

        [Foldout(1, 1, 1, 1)] _F_Fresnel("Fresnel_Foldout", float) = 0

        [Toggle_Switch] _DebugFresnel("显示边缘光 (调试用)", float) = 0

        [Enum_Switch(Default, Cel)] _Fres_Func("边缘光类型(临时)", float) = 0

        _FresnelLightRange("主光方向范围", Range(0,1)) = 1
        [HDR]_FresnelColor("边缘光颜色", Color) = (1, 1, 1, 1)
        _FresnelPow("边缘光渐变", Range(0, 1)) = 0
        _FresnelInnerRange("边缘光内侧范围", Range(0.0001, 1)) = 0.0001

        [Tex(_FresnelIntensity)][NoScaleOffset] _FresnelMask("边缘光遮罩(A通道)", 2D) = "white" {}
        [HideInInspector] _FresnelIntensity("FresnelIntensity", Range(-1, 1)) = 0

        [Foldout(2, 2, 1, 1)] _Fres_Shade_Mask("暗部边缘光遮蔽_Foldout", float) = 0
        _FresnelShadeMaskIntensity("暗部边缘光范围", Range(-1, 0.5)) = 0

        [Foldout(3, 2, 1, 1)] _Fres_Shade("暗部边缘光_Foldout", float) = 0
        _FresnelShadeColor("暗部边缘光颜色", Color) = (1, 1, 1, 1)
        _FresnelShadePow("暗部边缘光渐变", Range(0, 1)) = 0

        [Foldout_Out(1)] _F_Fres_Out("F_Fres_Out_Foldout", float) = 1

        // --------------------------------------------
        [Foldout(1, 1, 1, 1)] _F_Outline("Outline(不是真的能关闭)_Foldout", float) = 0
        _OutlineWidth("描边宽度", float) = 0
        [Tex][NoScaleOffset] _OutlineMask("描边蒙板(R通道)", 2D) = "white" {}
        _OutlineColor("描边颜色", Color) = (0.5, 0.5, 0.5, 1)

        //
        [Enum_Switch(Normal, VertexColor)] _OutlineType("顶点色平滑版本(需要预先生成)", float) = 0
        [Toggle_Switch] _AutoWidth("摄像机远近变化时宽度保持", float) = 0
        [Range(_AutoWidth)] _FadeDist("超出最大距离描边消失(从近处开始过渡)", float) = (0,20,0,100)
        _Offset_Z ("前后偏移(控制内部描边)", Float) = 0
        [Toggle_Switch] _DebugOutlineMask("显示描边遮罩 (调试用)", float) = 0

        // --------------------------------------------
        [Foldout_Out(1)] _F_Out("F_Out_Foldout", float) = 1


        // Blending state
        [HideInInspector] _SrcBlend ("__src", Float) = 1.0
        [HideInInspector] _DstBlend ("__dst", Float) = 0.0
    }

    // --------------------------------------------
    SubShader {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True"}

        Pass {
            Name "ToonSkin"

            Cull [_CullMode]
            Blend [_SrcBlend] [_DstBlend]

            HLSLPROGRAM
            #pragma target 4.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _FAKESSS_ON
            #pragma shader_feature_local _FACE_SHADE_ON
            #pragma shader_feature_local _FACESHADELINEAR_ON
            #pragma shader_feature_local _FACESHADEUSEUV1_ON

            #pragma shader_feature_local _FRES_FUNC_DEFAULT _FRES_FUNC_CEL
            #pragma shader_feature_local _F_FRESNEL_ON
            #pragma shader_feature_local _FRES_SHADE_MASK_ON
            #pragma shader_feature_local _FRES_SHADE_ON

            #pragma shader_feature_local _USERLIGHTDIRECTION_ON
            #pragma shader_feature_local _USESHADOWMAP_ON
            #pragma shader_feature_local _USEADDITIONALLIGHT_ON
            #pragma shader_feature_local _F_INDIRECT_ON

            #pragma shader_feature_local _DEBUGOUTLINEMASK_ON
            #pragma shader_feature_local _DEBUGFRESNEL_ON

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

            // -------------------------------------
            // Global RenderSettings keywords
            #pragma multi_compile _ _GLOBALRENDERSETTINGSENABLEKEYWORD

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer

            #pragma vertex ToonSkinVertex
            #pragma fragment ToonSkinFragment

            #include "ToonLibrary/ToonSkinPass.hlsl"

            ENDHLSL
        }

        Pass {
            Name "ToonSkinOutline"
            Tags{"LightMode" = "ToonOutline"}

            Cull Front

            HLSLPROGRAM
            #pragma target 4.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local __RENDERMODE_OPAQUE __RENDERMODE_CUTOUT
            #pragma shader_feature_local _USECLIPPINGMASK_ON
            #pragma shader_feature_local _INVERSECLIPPING_ON

            #pragma shader_feature_local _F_OUTLINE_ON
            #pragma shader_feature_local _OUTLINETYPE_NORMAL _OUTLINETYPE_VERTEXCOLOR
            #pragma shader_feature_local _AUTOWIDTH_ON
            // #pragma shader_feature_local _F_OUTLINECOLORS_ON
            #pragma shader_feature_local _F_DYE_ON

            // -------------------------------------
            // Global RenderSettings keywords
            #pragma multi_compile _ _GLOBALRENDERSETTINGSENABLEKEYWORD

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex ToonOutlineVertex
            #pragma fragment ToonOutlineFragment

            #include "ToonLibrary/ToonSkinInput.hlsl"
            #include "ToonLibrary/ToonOutlinePass.hlsl"

            ENDHLSL
        }

        Pass {
            Name "ToonSkinShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Off

            HLSLPROGRAM
            #pragma target 4.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local __RENDERMODE_OPAQUE __RENDERMODE_CUTOUT
            #pragma shader_feature_local _USECLIPPINGMASK_ON
            #pragma shader_feature_local _INVERSECLIPPING_ON
            // for eye specular anim
            #pragma shader_feature_local _F_EYE_SPECULARANIM_ON
            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #pragma vertex ToonShadowPassVertex
            #pragma fragment ToonShadowPassFragment

            #include "ToonLibrary/ToonSkinInput.hlsl"
            #include "ToonLibrary/ToonShadowCasterPass.hlsl"

            ENDHLSL
        }
    }

    // --------------------------------------------
    CustomEditor "Scarecrow.SimpleShaderGUI"
}