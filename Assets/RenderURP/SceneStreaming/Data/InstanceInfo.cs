using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Inutan
{
    [System.Serializable]
    public class InstanceInfo
    {
        public string key;
        public List<InstanceLocation> locations = new List<InstanceLocation>();
    }


    [System.Serializable]
    public struct InstanceLocation
    {
        public Vector3 position;
        public Vector3 scale;
        public Quaternion rotation;
    }

    //如果是植被的话 数据能够进一步压缩
    [System.Serializable]
    public struct GrassLocation
    {
        public Vector3 position;
        public float scale;
        public float rotationY;
    }
}
