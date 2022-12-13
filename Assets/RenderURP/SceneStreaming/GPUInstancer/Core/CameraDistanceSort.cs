using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using Unity.Burst;

namespace Inutan
{
    [BurstCompile]
    public struct CameraDistanceSort : IComparer<Matrix4x4>
    {
        public Vector3 cameraPosition;
        public bool reverse; //不透明物体 false 即可  透明物体 需要设置为true

        public int Compare(Matrix4x4 x, Matrix4x4 y)
        {
            var posX = x.GetPosition();
            var posY = y.GetPosition();
            var distanceToCameraX = Vector3.SqrMagnitude(cameraPosition - posX);
            var distanceToCameraY = Vector3.SqrMagnitude(cameraPosition - posY);
            int reverseParameter = reverse ? -1 : 1;
            int result = distanceToCameraX > distanceToCameraY ? 1 : -1;
            return result * reverseParameter;
        }


    }
}
