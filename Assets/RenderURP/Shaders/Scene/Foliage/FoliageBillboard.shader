
Shader "Inutan/URP/Scene/Foliage/FoliageBillboard"
{
    Properties
    {
        [Tex(_Color)]_MainTex("基础贴图 (Albedo)", 2D) = "white" {}
        [HideInInspector]_Color("基础颜色", Color) = (1, 1, 1, 1)
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.33
        _IndirectIntensity("环境光强度", Range(0, 10)) = 1
        _VerticalBillboarding("0: Y方向 1: 全方向", Range(0, 1)) = 0
      
        // --------------------------------------------
        [Foldout_Out(1)] _F_Out("F_Out_Foldout", float) = 1

    }

    SubShader
    {
        Tags { "RenderType"="TransparentCutout" "Queue"="AlphaTest" "IgnoreProjector"="True" "DisableBatching"="True" "RenderPipeline" = "UniversalPipeline"}

        Pass 
        {
            Name "FoliageBillboard"
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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/BRDF.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"

            struct Attributes 
            {
                float4 positionOS   : POSITION;
                float4 texcoord     : TEXCOORD0;
                float3 normalOS     : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings 
            {
                float2 uv           : TEXCOORD0;
                float3 positionWS   : TEXCOORD1;
                half   fogFactor    : TEXCOORD2;
                half3  normalWS     : TEXCOORD3;
                float4 positionCS   : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            CBUFFER_START(UnityPerMaterial)
                float4  _MainTex_ST;
                half4   _Color;
                half    _Cutoff;
                half    _IndirectIntensity;
                half    _VerticalBillboarding;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
          
            // -----------------------------------------------------------------------------
            // Vertex
            Varyings vert (Attributes input)
            {
                Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);

                // 要求顶点是竖直排列的，这样centerOffs的计算才是正确的
                float3 viewer = TransformWorldToObject(GetCurrentViewPosition());
                float3 center = float3(0, 0, 0);
                float3 normalDir = viewer - center;

                // _VerticalBillboarding=1表示完全朝视角方向，=0表示up为正上方
                normalDir.y = normalDir.y * _VerticalBillboarding;
                normalDir = normalize(normalDir);

                float3 upDir = abs(normalDir.y) > 0.999 ? float3(0, 0, 1) : float3(0, 1, 0);
                float3 rightDir = normalize(cross(upDir, normalDir));
                upDir = normalize(cross(normalDir, rightDir));

                float3 centerOffs = input.positionOS.xyz - center;
                float3 localPos = center + rightDir * centerOffs.x + upDir * centerOffs.y + normalDir * centerOffs.z;
                // -------------------------------------------------------

                output.positionWS = TransformObjectToWorld(localPos);
                output.positionCS = TransformWorldToHClip(output.positionWS);

                output.uv = TRANSFORM_TEX(input.texcoord, _MainTex);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);

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

                float3 irradianceSH = SampleSH(input.normalWS);
                color.rgb *= irradianceSH * _IndirectIntensity;

                float fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactor);
                color.rgb = MixFog(color.rgb, fogCoord);

                return color;
            }
            ENDHLSL
        }
    }

    CustomEditor "Scarecrow.SimpleShaderGUI"
}
