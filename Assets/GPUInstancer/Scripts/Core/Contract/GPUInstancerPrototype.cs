using System;
using UnityEngine;

namespace GPUInstancer
{
    [Serializable]
    public abstract class GPUInstancerPrototype : ScriptableObject
    {
        public GameObject prefabObject;


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
