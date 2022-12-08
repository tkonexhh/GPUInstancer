
Shader "Inutan/URP/Effect/Crystal(SRPBatch) 可收集水晶（合批定制）" {
    Properties {
        // level/style/toggle/open/showlist
        [Foldout(1, 1, 0, 1)] _F_Basic("Basic_Foldout", float) = 1
        [Tex(_ )][NoScaleOffset] _MainTex("基础贴图", 2D) = "white" {}
        [HDR] _MainColor("颜色", Color) = (1, 1, 1, 1)
        _ColorIntensity_Basic ("颜色强度", Float) = 1.0
        _RoateSpeedY ("Y旋转速度", Float) = 0.0
        [Foldout_Out(1)] _F_Basic_Out("_F_Basic_Out_Foldout", float) = 1

        [Foldout(1, 1, 0, 1)] _F_Layer1("第一层_Foldout", float) = 1
        [Tex(_ )] _Layer1Tex("贴图", 2D) = "white" {}
        [HDR] _Layer1Color("颜色", Color) = (1, 1, 1, 1)
        _ColorIntensity_Layer1 ("颜色强度", Float) = 1.0
        _DynamicUV_Layer1 ("DynamicUV XY:速度", Vector) = (0, 0, 0, 0)

        [Foldout(2, 2, 0, 1)] _F_Layer1_Mask("Mask_Foldout", float) = 1
        [Tex(_ )][NoScaleOffset] _Layer1MaskTex("贴图", 2D) = "white" {}
        _DynamicUV_Layer1Mask ("DynamicUV XY:速度", Vector) = (0, 0, 0, 0)
        [Foldout_Out(2)] _F_Layer1_Mask_Out("_F_Layer1_Mask_Out_Foldout", float) = 1

        [Foldout_Out(1)] _F_Layer1_Out("_F_Layer1_Out_Foldout", float) = 1

        [Foldout(1, 1, 0, 1)] _F_Layer2("第二层_Foldout", float) = 1
        [Tex(_ )] _Layer2Tex("贴图", 2D) = "white" {}
        [HDR] _Layer2Color("颜色", Color) = (1, 1, 1, 1)
        _ColorIntensity_Layer2 ("颜色强度", Float) = 1.0
        _DynamicUV_Layer2 ("DynamicUV XY:速度", Vector) = (0, 0, 0, 0)
        [Foldout_Out(1)] _F_Layer2_Out("_F_Layer2_Out_Foldout", float) = 1
    }

    // --------------------------------------------
    SubShader {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True"}

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
            half _RoateSpeedY;
            float4 _MainTex_ST;
            half4 _MainColor;
            half _ColorIntensity_Basic;

            float4 _Layer1Tex_ST;
            half4 _Layer1Color;
            half _ColorIntensity_Layer1;
            half2 _DynamicUV_Layer1;
            half2 _DynamicUV_Layer1Mask;

            float4 _Layer2Tex_ST;
            half4 _Layer2Color;
            half _ColorIntensity_Layer2;
            half2 _DynamicUV_Layer2;

        CBUFFER_END
        ENDHLSL

        Pass {
            // 由于是延迟管线，这里不给管线tag，作为无tag的pass让管线收集到forward去
            Name "Crystal(SRPBatch) Forward"

            ZWrite On

            HLSLPROGRAM
            #pragma target 4.0

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer

            #pragma vertex vert
            #pragma fragment frag

            struct Attributes {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
                float4 color        : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings {
                float4 positionCS   : SV_POSITION;
                float4 uvs          : TEXCOORD0;
                float4 uvs2         : TEXCOORD1;
                float4 color        : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            TEXTURE2D(_Layer1Tex);
            SAMPLER(sampler_Layer1Tex);
            TEXTURE2D(_Layer1MaskTex);
            SAMPLER(sampler_Layer1MaskTex);

            TEXTURE2D(_Layer2Tex);
            SAMPLER(sampler_Layer2Tex);

            // 旋转Y轴
            float3 RoatePosByY(float roateSpeedY, float3 posOrigin)
            {
                roateSpeedY *= 0.017453292;
                float cosY = cos(roateSpeedY);
                float sinY = sin(roateSpeedY);
                // 矩阵
                // Ry =
                // cosY  0  sinY  0
                // 0     1  0     0
                // -sinY 0  cosY  0
                // 0     0  0     1
                return float3(posOrigin.x * cosY - posOrigin.z * sinY, posOrigin.y, posOrigin.x * sinY + posOrigin.z * cosY);
            }

            Varyings vert(Attributes input) {
                Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);

                float3 positionOS = RoatePosByY(_RoateSpeedY * _Time.y, input.positionOS.xyz);

                VertexPositionInputs positionInputs = GetVertexPositionInputs(positionOS);
                output.positionCS = positionInputs.positionCS;

                output.uvs.xy = TRANSFORM_TEX(input.uv, _MainTex);
                output.uvs.zw = TRANSFORM_TEX(input.uv, _Layer1Tex);
                output.uvs2.xy = TRANSFORM_TEX(input.uv, _Layer2Tex);

                output.color = input.color;
                return output;
            }

            half4 frag(Varyings input) : SV_Target {
                UNITY_SETUP_INSTANCE_ID(input);

                half3 baseColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uvs.xy).rgb;
                baseColor *= _MainColor.rgb * _ColorIntensity_Basic;

                // Layer1
                half3 layer1Color = SAMPLE_TEXTURE2D(_Layer1Tex, sampler_Layer1Tex, input.uvs.zw + _DynamicUV_Layer1.xy * _Time.y).rgb;
                layer1Color *= _Layer1Color.rgb * _ColorIntensity_Layer1;
                half layer1Mask = SAMPLE_TEXTURE2D(_Layer1MaskTex, sampler_Layer1MaskTex, input.uvs.xy + _DynamicUV_Layer1Mask.xy * _Time.y).r;
                layer1Color *= layer1Mask;

                // Blend是SrcColor One, BlendOp是Add
                half3 finalColor = layer1Color * layer1Color + baseColor;


                // Layer2
                half3 layer2Color = SAMPLE_TEXTURE2D(_Layer2Tex, sampler_Layer2Tex, input.uvs2.xy + _DynamicUV_Layer2.xy * _Time.y).rgb;
                layer2Color *= _Layer2Color.rgb * _ColorIntensity_Layer2;

                // Blend是SrcColor One, BlendOp是Add
                finalColor = layer2Color * layer2Color + finalColor;


                return half4(finalColor, 1.0);
            }

            ENDHLSL

        }

    }

    CustomEditor "Scarecrow.SimpleShaderGUI"
}