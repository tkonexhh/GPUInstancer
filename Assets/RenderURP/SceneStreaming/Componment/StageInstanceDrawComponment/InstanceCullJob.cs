using Unity.Burst;
using Unity.Collections;
using Unity.Jobs;
using UnityEngine;

namespace Inutan
{
    [BurstCompile]
    public struct InstanceCullJob : IJobParallelFor
    {
        [ReadOnly] public NativeArray<Vector3> allPositions;
        [ReadOnly] public Vector3 cameraPos;
        [ReadOnly] public Vector3 cameraForward;
        [ReadOnly] public float sqrShowRange;
        [ReadOnly] public float sqrFovCos;
        [WriteOnly] public NativeArray<bool> visibleFlags;




        public void Execute(int index)
        {
            Vector3 position = allPositions[index];
            Vector3 offset = position - cameraPos;

            // 距离剔除
            float sqrDistance = Vector3.SqrMagnitude(offset);
            if (sqrDistance > sqrShowRange)
            {
                visibleFlags[index] = false;
                return;
            }


            // 角度剔除
            float dot = Vector3.Dot(cameraForward, offset);
            if (dot < 0 || dot * dot / sqrDistance < sqrFovCos)
            {
                visibleFlags[index] = false;
                return;
            }

            visibleFlags[index] = true;
        }
    }
}
