using System;
using UnityEngine;

namespace GPUInstancer
{
    [Serializable]
    public abstract class GPUInstancerPrototype : ScriptableObject
    {
        public GameObject prefabObject;

        // Culling
        public float minDistance = 0;
        public float maxDistance = 500;

        // Bounds
        public Vector3 boundsOffset;

        // Other
        public string warningText;

        public override string ToString()
        {
            if (prefabObject != null)
                return prefabObject.name;
            return name;
        }

        public virtual Texture2D GetPreviewTexture()
        {
            return null;
        }
    }
}
