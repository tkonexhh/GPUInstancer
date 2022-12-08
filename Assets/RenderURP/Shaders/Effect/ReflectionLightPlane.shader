Shader "Inutan/URP/Effect/ReflectionLightPlane 发光特效面片带反射球"
{
    Properties
    {
        [Foldout(1, 1, 0, 1)] _F_Base("基础_Foldout", float) = 1
        [Enum_Switch(Both, Back, Front)] _CullMode("面渲染模式", Float) = 0.0
        [Toggle_Switch] _FaceToCameraMode ("面向摄像机", Float) = 0

        [HDR] _MainColor ("颜色", Color) = (1,1,1,1)
        [Tex(_)] _BaseTex ("BaseTex 贴图", 2D) = "white" {}
        _AlphaBrightness ("Alpha Brightness 亮度", Float) = 1

        [Foldout(2, 2, 0, 0)] _F_BaseTexChannel("贴图通道_Foldout", float) = 1
        [Enum_Switch(RGB, R, G, B, A)] _BaseTexColorChannelSwitch ("BaseTex Color Channel", Float) = 0
        [Enum_Switch(A, R, G, B)] _BaseTexAlphaChannelSwitch ("BaseTex Alpha Channel", Float) = 0
        [Foldout_Out(2)] _F_BaseTexChannel_Out("F_BaseTexChannel_Out_Foldout", float) = 1

        [Foldout(2, 2, 1, 1)] _F_EnvReflection("环境反射_Foldout", float) = 0
        _EnvReflectionBlendIntensity("强度", Float) = 1.0
        [Enum_Switch(EnvMultiply, EnvAdd)] _EnvReflectionBlendMode ("混合模式", Float) = 0
        [Toggle_Switch] _EnvReflectionCustomCubeMap ("自定义反射球", Float) = 0
        [Tex(_, _EnvReflectionCustomCubeMap)][NoScaleOffset] _ReflectCubemap("Cubemap", CUBE) = "black" {}
        _EnvReflectionEdgePower ("Power 曲线", Float) = 1
        _EnvReflectionEdgeScale ("Scale 缩放", Float) = 1
        [Foldout_Out(2)] _F_EnvRelfection_Out("F_EnvRelfection_Out_Foldout", float) = 1

        [Foldout(2, 2, 0, 0)] _F_UVMove("UV 移动_Foldout", float) = 1
        _BaseTex_Uspeed ("U speed", Float) = 0
        _BaseTex_Vspeed ("V speed", Float) = 0
        [Foldout_Out(2)] _F_UVMove_Out("F_UVMove_Out_Foldout", float) = 1

        [Foldout(2, 2, 1, 0)] _F_UseMaskTex("Mask_Foldout", float) = 0
        [Tex(_)] _MaskTex ("MaskTex", 2D) = "white" {}
        [Enum_Switch(R, G, B, A)] _MaskTexChannelSwitch ("MaskTex Channel", Float) = 2
        [Enum_Switch(Multiply, Add)] _MaskTexBlendMode ("MaskTex BlendMode 混合模式", Float) = 0
        [Switch(Add)]_MaskTexBlendAddIntensity("Add Intensity", Range(0.0, 2.0)) = 1.0
        _MaskTex_Uspeed ("U speed", Float) = 0
        _MaskTex_Vspeed ("V speed", Float) = 0
        _MaskTexBrightness ("MaskTex Brightness 亮度", Float) = 1
        [Foldout_Out(2)] _F_UseMaskTex_Out("F_UseMaskTex_Out_Foldout", float) = 1

        [Foldout(2, 2, 0, 0)] _F_UV2Noise("UV2 Noise_Foldout", float) = 1
        [Toggle_Switch] _BaseTexURandomToggle ("BaseTex U Random", Float) = 0
        [Toggle_Switch] _BaseTexVRandomToggle ("BaseTex V Random", Float) = 0
        [Foldout_Out(2)] _F_UV2Noise_Out("F_UV2Noise_Out_Foldout", float) = 1

        [Foldout(1, 1, 0, 1)] _F_Alpha("Alpha_Foldout", float) = 1

        [Foldout(2, 2, 1, 1)] _F_AlphaNdotV("Alpha 法线边缘淡出_Foldout", float) = 1
        [Toggle_Switch] _AlphaSoftedgeTwoSideToggle ("双面", Float) = 1
        _AlphaSoftedgePower ("Power 曲线", Float) = 1
        _AlphaSoftedgeScale ("Scale 缩放", Float) = 1
        [Toggle_Switch] _AlphaSoftedgeInvertToggle ("反转", Float) = 0
        [Foldout_Out(2)] _F_AlphaNdotV_Out("F_AlphaNdotV_Out_Foldout", float) = 1

        [Foldout(2, 2, 1, 1)] _F_AlphaDistanceFade("Alpha 距离淡出_Foldout", float) = 1
        _AlphaFadeDepthOffset ("DepthOffset", Float) = 0
        _AlphaFadeDistance ("Distance 距离", Float) = 70
        _AlphaFadeOffset ("Offset 偏移", Float) = 10
        [Toggle_Switch] _AlphaFadeDistanceInvertToggle ("距离反转(勾上后 近处消失)", Float) = 1
        [Toggle_Switch] _AlphaFadeDistanceTwoWayToggle ("DistanceTwoWay", Float) = 0
        [Switch(_AlphaFadeDistanceTwoWayToggle)]_AlphaFadeDistanceTwoWay ("Distance 距离(Two Way)", Float) = 50
        [Switch(_AlphaFadeDistanceTwoWayToggle)]_AlphaFadeOffsetTwoWay ("Offset 偏移(Two Way)", Float) = 34
        [Foldout_Out(2)] _F_AlphaDistanceFade_Out("F_AlphaDistanceFade_Out_Foldout", float) = 1

        [Foldout(2, 2, 1, 1)] _F_AlphaDepthFade("Alpha 深度淡出_Foldout", float) = 1
        _DepthThresh ("DepthThresh", Range(0.001, 20)) = 0.001
        _DepthFade ("DepthFade", Range(0.001, 20)) = 20
        [Foldout_Out(2)] _F_AlphaDepthFade_Out("F_AlphaDepthFade_Out_Foldout", float) = 1

        [Foldout(1, 1, 0, 1)] _F_Debug("Debug_Foldout", float) = 1
        [Toggle_Switch] _DebugShow ("显示纯色", Float) = 0

        [Foldout(1, 1, 0, 1)] _F_Advance("Advance_Foldout", float) = 1
        _ZBias ("Z Bias", Float) = 0
        [Toggle_Switch] _ZTest("深度检测", Float) = 1
        [Foldout_Out(1)] _F_Advance_Out("F_Advance_Out_Foldout", float) = 1
    }
    SubShader{
        Tags {"QUEUE" = "Transparent" "RenderType" = "Transparent" "RenderPipeline" = "UniversalRenderPipeline" }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
            float4 _BaseTex_ST, _MaskTex_ST;
            half4 _MainColor;
            half _BaseTexColorChannelSwitch;
            half _BaseTexAlphaChannelSwitch;
            half _AlphaBrightness;

            half _EnvReflectionBlendIntensity;
            half _EnvReflectionEdgePower;
            half _EnvReflectionEdgeScale;

            half _AlphaSoftedgeTwoSideToggle;
            float _AlphaSoftedgePower;
            float _AlphaSoftedgeScale;

            float _AlphaFadeDepthOffset;
            float _AlphaFadeOffset;
            float _AlphaFadeOffsetTwoWay;
            float _AlphaFadeDistance;
            float _AlphaFadeDistanceTwoWay;

            half _AlphaFadeDistanceInvertToggle;
            half _AlphaFadeDistanceTwoWayToggle;

            float _DepthThresh, _DepthFade;

            float _BaseTex_Uspeed;
            float _BaseTex_Vspeed;
            half _BaseTexURandomToggle;
            half _BaseTexVRandomToggle;

            float _MaskTex_Uspeed;
            float _MaskTex_Vspeed;
            half _MaskTexBrightness;
            half _MaskTexBlendAddIntensity;

            float _ZBias;
        CBUFFER_END
        ENDHLSL

        Pass {
            Name "Forward"
            Tags { "LightMode" = "UniversalForward" }

            Blend SrcAlpha One, SrcAlpha One
            ZWrite Off
            ZTest [_ZTest]
            Cull [_CullMode]

            HLSLPROGRAM
            #pragma target 3.0

            #pragma vertex vert
            #pragma fragment frag

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _FACETOCAMERAMODE_ON
            #pragma shader_feature_local _F_USEMASKTEX_ON
            #pragma shader_feature_local _F_ALPHANDOTV_ON
            #pragma shader_feature_local _F_ALPHADISTANCEFADE_ON
            #pragma shader_feature_local _F_ALPHADEPTHFADE_ON
            #pragma shader_feature_local_fragment _ALPHASOFTEDGEINVERTTOGGLE_ON
            #pragma shader_feature_local_fragment _F_ENVREFLECTION_ON
            #pragma shader_feature_local_fragment _ENVREFLECTIONBLENDMODE_ENVMULTIPLY _ENVREFLECTIONBLENDMODE_ENVADD
            #pragma shader_feature_local_fragment _ENVREFLECTIONCUSTOMCUBEMAP_ON
            #pragma shader_feature_local _BASETEXCOLORCHANNELSWITCH_RGB _BASETEXCOLORCHANNELSWITCH_R _BASETEXCOLORCHANNELSWITCH_G _BASETEXCOLORCHANNELSWITCH_B _BASETEXCOLORCHANNELSWITCH_A
            #pragma shader_feature_local _BASETEXALPHACHANNELSWITCH_A _BASETEXALPHACHANNELSWITCH_R _BASETEXALPHACHANNELSWITCH_G _BASETEXALPHACHANNELSWITCH_B
            #pragma shader_feature_local _MASKTEXCHANNELSWITCH_R _MASKTEXCHANNELSWITCH_G _MASKTEXCHANNELSWITCH_B _MASKTEXCHANNELSWITCH_A
            #pragma shader_feature_local _MASKTEXBLENDMODE_MULTIPLY _MASKTEXBLENDMODE_ADD

            #pragma shader_feature_local _DEBUGSHOW_ON

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing


            struct a2v {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
                float2 uv2          : TEXCOORD1;
                float3 normalOS 	: NORMAL;
                float4 color        : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f {
                float4 positionCS  : SV_POSITION;
                float2 uv           : TEXCOORD0;
                float4 viewDirWS_depthVS : TEXCOORD1;
                float3 normalWS 	: TEXCOORD2;
                float3 positionWS   : TEXCOORD3;
                float4 screenUV 	: TEXCOORD5;
                #ifdef _F_USEMASKTEX_ON
                    float2 maskTexUV    : TEXCOORD6;
                #endif
                float4 color        : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            #ifdef _F_ALPHADEPTHFADE_ON
                TEXTURE2D_X(_CameraDepthTexture);
            #endif
            TEXTURE2D(_BaseTex); SAMPLER(sampler_BaseTex);
            #ifdef _F_USEMASKTEX_ON
                TEXTURE2D(_MaskTex); SAMPLER(sampler_MaskTex);
            #endif

            #ifdef _F_ENVREFLECTION_ON
                TEXTURECUBE(_ReflectCubemap);               SAMPLER(sampler_ReflectCubemap);
            #endif

            v2f vert(a2v v) {
                v2f o = (v2f)0;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);

                float3 positionOS = v.positionOS.xyz;
                #ifdef _FACETOCAMERAMODE_ON
                    float3 scale = 1;
                    float4x4 matrixOSToWS = GetObjectToWorldMatrix();
                    scale.x = length(float3(matrixOSToWS[0][0], matrixOSToWS[1][0], matrixOSToWS[2][0]));
                    scale.y = length(float3(matrixOSToWS[0][1], matrixOSToWS[1][1], matrixOSToWS[2][1]));
                    scale.z = length(float3(matrixOSToWS[0][2], matrixOSToWS[1][2], matrixOSToWS[2][2]));
                    float3 positionFaceToCamera_VS = TransformWorldToView(TransformObjectToWorld(float3(0, 0, 0))) + v.positionOS.xyz * scale.xyz;
                    positionOS = TransformWorldToObject(mul(UNITY_MATRIX_I_V, float4(positionFaceToCamera_VS, 1)).xyz);
                #endif

                VertexPositionInputs positionInputs = GetVertexPositionInputs(positionOS);
                o.positionWS = positionInputs.positionWS;
                o.positionCS = positionInputs.positionCS;
                o.positionCS.z = -_ZBias * o.positionCS.w + o.positionCS.z;

                o.color = v.color;

                float2 uvMoveSpeed = frac(float2(_BaseTex_Uspeed, _BaseTex_Vspeed) * _Time.y);
                // 2uv用来做随机
                o.uv = TRANSFORM_TEX(v.uv, _BaseTex) + uvMoveSpeed + v.uv2 * float2(_BaseTexURandomToggle, _BaseTexVRandomToggle);

                o.viewDirWS_depthVS.w = -positionInputs.positionVS.z;
                o.viewDirWS_depthVS.xyz = GetWorldSpaceNormalizeViewDir(positionInputs.positionWS.xyz);

                o.normalWS = TransformObjectToWorldNormal(v.normalOS);

                o.screenUV.zw = positionInputs.positionCS.zw;
                o.screenUV.x = positionInputs.positionCS.x * 0.5 + positionInputs.positionCS.w * 0.5;
                o.screenUV.y = positionInputs.positionCS.y * _ProjectionParams.x * 0.5 + positionInputs.positionCS.w * 0.5;

                #ifdef _F_USEMASKTEX_ON
                    float2 maskUVSpeed = frac(float2(_MaskTex_Uspeed, _MaskTex_Vspeed) * _Time.y);
                    o.maskTexUV = TRANSFORM_TEX(v.uv, _MaskTex) + maskUVSpeed;
                #endif

                return o;
            }

            half4 frag(v2f i) : SV_Target {
                UNITY_SETUP_INSTANCE_ID(i);

                #ifdef _DEBUGSHOW_ON
                    return float4(0, 1, 0, 1);
                #endif

                half4 baseMap = SAMPLE_TEXTURE2D(_BaseTex, sampler_BaseTex, i.uv);
                half3 baseColor = baseMap.rgb;
                #ifdef _BASETEXCOLORCHANNELSWITCH_R
                    baseColor = baseMap.r;
                #endif
                #ifdef _BASETEXCOLORCHANNELSWITCH_G
                    baseColor = baseMap.g;
                #endif
                #ifdef _BASETEXCOLORCHANNELSWITCH_B
                    baseColor = baseMap.b;
                #endif
                #ifdef _BASETEXCOLORCHANNELSWITCH_A
                    baseColor = baseMap.a;
                #endif
                baseColor *= _MainColor.rgb * i.color.xyz;

                float alpha = baseMap.a;
                #ifdef _BASETEXALPHACHANNELSWITCH_R
                    alpha = baseMap.r;
                #endif
                #ifdef _BASETEXALPHACHANNELSWITCH_G
                    alpha = baseMap.g;
                #endif
                #ifdef _BASETEXALPHACHANNELSWITCH_B
                    alpha = baseMap.b;
                #endif
                alpha *= _AlphaBrightness * _MainColor.a * i.color.a;


                #ifdef _F_USEMASKTEX_ON
                    half4 maskMap = SAMPLE_TEXTURE2D(_MaskTex, sampler_MaskTex, i.maskTexUV);
                    half mask = maskMap.r;
                    #ifdef _MASKTEXCHANNELSWITCH_G
                        mask = maskMap.g;
                    #endif
                    #ifdef _MASKTEXCHANNELSWITCH_B
                        mask = maskMap.b;
                    #endif
                    #ifdef _MASKTEXCHANNELSWITCH_A
                        mask = maskMap.a;
                    #endif
                    mask *= _MaskTexBrightness;
                    #ifdef _MASKTEXBLENDMODE_ADD
                        alpha = alpha * _MaskTexBlendAddIntensity + mask;
                    #else // _MASKTEXBLENDMODE_MULTIPLY
                        alpha = alpha * mask;
                    #endif
                #endif

                #ifdef _F_ENVREFLECTION_ON
                    half3 reflectVector = reflect(-i.viewDirWS_depthVS.xyz, i.normalWS.xyz);
                    half mip = PerceptualRoughnessToMipmapLevel(0.01);
                    #ifdef _ENVREFLECTIONCUSTOMCUBEMAP_ON
                        half4 encodedIrradiance = half4(SAMPLE_TEXTURECUBE_LOD(_ReflectCubemap, sampler_ReflectCubemap, reflectVector, mip));
                    #else
                        half4 encodedIrradiance = half4(SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectVector, mip));
                    #endif
                    float NdotV_env = dot(i.viewDirWS_depthVS.xyz, i.normalWS.xyz);
                    float envReflectionEdge = pow(max(0, 1.0 - NdotV_env), _EnvReflectionEdgePower);
                    envReflectionEdge = 1.0 - saturate(_EnvReflectionEdgeScale * envReflectionEdge);

                    #ifdef _ENVREFLECTIONBLENDMODE_ENVMULTIPLY
                        encodedIrradiance.rgb = lerp(encodedIrradiance.rgb, 1.0, envReflectionEdge);
                        baseColor *= lerp(1.0, encodedIrradiance.rgb, saturate(_EnvReflectionBlendIntensity));
                    #else
                        encodedIrradiance.rgb = lerp(encodedIrradiance.rgb, 0.0, envReflectionEdge);
                        baseColor += encodedIrradiance.rgb * max(0.0, _EnvReflectionBlendIntensity);
                    #endif
                #endif

                // Alpha
                //──────────────────────────────────────────────────────────────────────────────────────────────────────
                // NdotV Fade
                #ifdef _F_ALPHANDOTV_ON
                    float3 V = normalize(i.viewDirWS_depthVS.xyz);
                    float3 N = normalize(i.normalWS.xyz);
                    float NdotV = dot(N, V);
                    float alphaSoftEdgeResult = pow(max(0, 1.0 - clamp(lerp(NdotV, abs(NdotV), _AlphaSoftedgeTwoSideToggle), -1.0, 1.0)), _AlphaSoftedgePower);
                    alphaSoftEdgeResult = 1.0 - saturate(_AlphaSoftedgeScale * alphaSoftEdgeResult);
                    #ifdef _ALPHASOFTEDGEINVERTTOGGLE_ON
                        alphaSoftEdgeResult = 1.0 - alphaSoftEdgeResult;
                    #endif
                    alpha *= alphaSoftEdgeResult;
                #endif


                // ViewSpace Distance Fade
                #ifdef _F_ALPHADISTANCEFADE_ON
                    float depthVS = i.viewDirWS_depthVS.w - _AlphaFadeDepthOffset;
                    float alphaVSFade = saturate((depthVS - _AlphaFadeOffset) / _AlphaFadeDistance);
                    float alphaVSFadeTwoWay = saturate((depthVS - _AlphaFadeOffsetTwoWay) / _AlphaFadeDistanceTwoWay);
                    if(_AlphaFadeDistanceInvertToggle == 0)
                    {
                        alphaVSFade = 1.0 - alphaVSFade;
                    }
                    float alphaVSFadeResult = alphaVSFade;
                    if(_AlphaFadeDistanceTwoWayToggle)
                    {
                        alphaVSFadeResult = min(alphaVSFade, alphaVSFadeTwoWay);
                    }
                    alpha *= alphaVSFadeResult;
                #endif

                // Depth Fade
                #ifdef _F_ALPHADEPTHFADE_ON
                    float2 screenUV = i.positionCS.xy * (_ScaledScreenParams.zw - 1.0);
                    float depthScene = LOAD_TEXTURE2D_X(_CameraDepthTexture, i.positionCS.xy).x;
                    float eye_z = LinearEyeDepth(depthScene, _ZBufferParams) - i.screenUV.w;
                    float sceneDepthFadeResult = lerp(saturate(_DepthThresh * eye_z), 1, saturate(eye_z / _DepthFade));
                    alpha *= sceneDepthFadeResult;
                #endif
                //──────────────────────────────────────────────────────────────────────────────────────────────────────

                baseColor = max(0.0, baseColor);
                alpha = max(0.0, alpha);
                return float4(baseColor, alpha);
            }
            ENDHLSL
        }
    }
    CustomEditor "Scarecrow.SimpleShaderGUI"
}
