using System;
using System.Collections.Generic;
using UnityEngine;

namespace GPUInstancer
{
    /// <summary>
    /// Add this to the prefabs of GameObjects you want to GPU Instance at runtime.
    /// </summary>
    public class GPUInstancerPrefab : MonoBehaviour
    {
        [HideInInspector]
        public GPUInstancerPrefabPrototype prefabPrototype;
        [NonSerialized]
        public int gpuInstancerID;
        [NonSerialized]
        public PrefabInstancingState state = PrefabInstancingState.None;

        protected bool _isTransformSet;
        protected Transform _instanceTransform;


        public virtual Transform GetInstanceTransform(bool forceNew = false)
        {
            if (!_isTransformSet || forceNew)
            {
                _instanceTransform = transform;
                _isTransformSet = true;
            }
            return _instanceTransform;
        }

    }

    public enum PrefabInstancingState
    {
        None,
        Disabled,
        Instanced
    }
}
