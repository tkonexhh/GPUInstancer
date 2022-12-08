#ifndef GPU_INSTANCE_INCLUDED
#define GPU_INSTANCE_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

uniform StructuredBuffer<float4x4> gpuiTransformationMatrix;//全部的localtoworld
uniform float4x4 gpuiTransformOffset;

///从传入的localtoworld 变换
float3 TransformInstanceObjectToWorld(float3 positionOS, uint instanceID)
{
    float4x4 _ObjectToWorld = mul(gpuiTransformationMatrix[instanceID], gpuiTransformOffset);
    return mul(_ObjectToWorld, float4(positionOS, 1.0)).xyz;
}

void SetupGPUInstance()
{
    #ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED

        unity_ObjectToWorld = mul(gpuiTransformationMatrix[unity_InstanceID], gpuiTransformOffset);

    #endif //UNITY_PROCEDURAL_INSTANCING_ENABLED

}

#endif