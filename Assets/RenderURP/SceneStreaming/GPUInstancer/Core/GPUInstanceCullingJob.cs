using System.Collections;
using System.Collections.Generic;
using Unity.Burst;
using Unity.Collections;
using Unity.Jobs;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Jobs;

namespace Inutan
{

    [BurstCompile]
    public struct GPUInstanceCullingJob : IJobParallelFor
    {
        [ReadOnly] public NativeArray<Matrix4x4> allLocalToWorldNativeArray;
        [ReadOnly] public GPUInstanceCameraData cameraData;
        [ReadOnly] public Vector2 showRange;
        public NativeQueue<Matrix4x4>.ParallelWriter finalVisibleNativeArray;

        public void Execute(int index)
        {
            Matrix4x4 localToWorld = allLocalToWorldNativeArray[index];
            Vector3 position = localToWorld.GetPosition();

            Vector3 offset = position - cameraData.position;
            float sqrDistance = Vector3.SqrMagnitude(offset);
            //距离剔除
            if (sqrDistance > showRange.y * showRange.y || sqrDistance < showRange.x * showRange.x)
            {
                //在显示范围外
                return;
            }

            // 角度剔除
            Vector3 cameraForward = cameraData.forward;
            float dot = Vector3.Dot(cameraForward, offset);
            if (dot < 0 || dot * dot / sqrDistance < cameraData.sqrFovCos)
            {
                return;
            }

            finalVisibleNativeArray.Enqueue(localToWorld);
        }
    }

    public struct GPUInstanceCameraData
    {
        public Vector3 position;
        public Vector3 forward;
        public float sqrFovCos;
    }
}
