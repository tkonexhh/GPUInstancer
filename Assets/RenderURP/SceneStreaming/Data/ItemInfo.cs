using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Inutan
{
    [System.Serializable]
    public struct ItemInfo
    {
        public Vector3 position;
        public Quaternion rotation;
        public Vector3 scale;
        public Bounds bounds;
        public string resFlag;
        public int PVSID;
    }
}
