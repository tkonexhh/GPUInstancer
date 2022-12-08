Shader "Hidden/Inutan/GPUInstancer/InternalErrorShader"
{
    SubShader
    {
        Pass
        {
            HLSLPROGRAM

            #pragma target 3.0
            #pragma vertex Vertex
            #pragma fragment Fragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "./GPUInstanceInclude.hlsl"

            struct Attributes
            {
                float4 positionOS: POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 vertex: SV_POSITION;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings Vertex(Attributes input, uint instanceID: SV_InstanceID)
            {
                Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                
                float3 positionWS = TransformInstanceObjectToWorld(input.positionOS, instanceID);
                output.vertex = TransformWorldToHClip(positionWS);
                return output;
            }

            half4 Fragment(Varyings input): SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                return half4(1, 0, 1, 1);
            }

            ENDHLSL

        }
    }
    FallBack Off
}
