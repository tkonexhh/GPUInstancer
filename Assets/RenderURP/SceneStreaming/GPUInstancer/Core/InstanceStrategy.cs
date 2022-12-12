using System.Collections;
using System.Collections.Generic;
using Unity.Collections;
using UnityEngine;

namespace Inutan
{
    public abstract class InstanceStrategy
    {
        public abstract void Render(List<GPUInstancerRenderer> renderers, NativeArray<Matrix4x4> localToWorldMatrixListNativeArray);
        public virtual void Release() { }
    }


}
