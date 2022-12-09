using System;
using UnityEngine;

namespace GPUInstancer
{
    [Serializable]
    public class GPUInstancerPrefabPrototype : GPUInstancerPrototype
    {
        public bool enableRuntimeModifications;
        public bool startWithRigidBody;
        public bool addRemoveInstancesAtRuntime;
        public int extraBufferSize;
        public bool addRuntimeHandlerScript;
        public bool meshRenderersDisabled;
        public bool isTransformsSerialized;
        public TextAsset serializedTransformData;
        public int serializedTransformDataCount;
    }
}
