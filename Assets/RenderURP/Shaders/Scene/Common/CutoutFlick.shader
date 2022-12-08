
Shader "Inutan/URP/Scene/Common/CutoutFlick 远景闪烁灯光面片"
{
    Properties
    {
        [Tex]_MainTex("基础贴图 (Albedo)", 2D) = "white" {}
        [HDR]_Color("基础颜色", Color) = (1, 1, 1, 1)
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.33
        _FlickerSpeed("闪烁速度", Range(0, 1)) = 0
        _UVSpeedX("UV速度 X", Range(0, 1)) = 0
        _UVSpeedY("UV速度 Y", Range(0, 1)) = 0
        // --------------------------------------------
        [Foldout_Out(1)] _F_Out("F_Out_Foldout", float) = 1

    }
    
    SubShader
    {
        Tags { "RenderType"="TransparentCutout" "Queue"="AlphaTest" "IgnoreProjector"="True" "RenderPipeline" = "UniversalPipeline"}

        Pass 
        {
            Name "CutoutFlick"

            // 双面 写入深度是配合水面反射
            ZWrite On Cull Off

            HLSLPROGRAM
            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fog
            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            //--------------------------------------
            struct Attributes 
            {
                float4 positionOS   : POSITION;
                float4 texcoord     : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings 
            {
                float2 uv           : TEXCOORD0;
                float3 positionWS   : TEXCOORD1;
                half   fogFactor    : TEXCOORD2;
                float4 positionCS   : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            CBUFFER_START(UnityPerMaterial)
                float4  _MainTex_ST;
                half4   _Color;
                half    _Cutoff;
                half    _FlickerSpeed;
                half    _UVSpeedX;
                half    _UVSpeedY;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
          
            float Hash(in float2 input)
            {
                return frac((52.9829189 * frac(dot(input, float2(0.06711056, 0.00583715)))));
            }
            // -----------------------------------------------------------------------------
            // Vertex
            Varyings vert (Attributes input)
            {
                Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

                output.positionCS = vertexInput.positionCS;
                output.positionWS = vertexInput.positionWS;
                output.uv = TRANSFORM_TEX(input.texcoord + frac(_Time.y * 5 * float2(_UVSpeedX, _UVSpeedY)), _MainTex);

                half fogFactor = 0;
                #if !defined(_FOG_FRAGMENT)
                    fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
                #endif
                output.fogFactor = fogFactor;

                return output;
            }

            // -----------------------------------------------------------------------------
            // Fragment
            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);

                half4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                color *= _Color;

                clip(color.a - _Cutoff);

                half flick = lerp(1, 0.8, sin(_Time.y * _FlickerSpeed * 50 * Hash(ceil(input.positionCS.xx * 0.001))));
                color.rgb *= flick;

                float fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactor);
                color.rgb = MixFog(color.rgb, fogCoord);

                return color;
            }
            ENDHLSL
        }
    }
    CustomEditor "Scarecrow.SimpleShaderGUI"
}
