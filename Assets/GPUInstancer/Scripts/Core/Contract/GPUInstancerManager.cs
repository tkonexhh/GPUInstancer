using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using System.Threading;
using Inutan;
#if UNITY_EDITOR
using UnityEditor;
#endif

namespace GPUInstancer
{
    public abstract class GPUInstancerManager : MonoBehaviour
    {
        public GPUInstanceRenderer m_InstanceRenderer = new GPUInstanceRenderer();
        protected List<GPUInstancerPrefab> _registeredPrefabsRuntimeData = new List<GPUInstancerPrefab>();


        #region MonoBehaviour Methods

        private void OnEnable()
        {
            m_InstanceRenderer?.SetRenderersEnabled(false);
        }

        public void LateUpdate()
        {
            m_InstanceRenderer.Render();
        }

        public void OnDisable() // could also be OnDestroy, but OnDestroy seems to be too late to prevent buffer leaks.
        {
            m_InstanceRenderer.SetRenderersEnabled(false);
        }

        private void OnDestroy()
        {
            m_InstanceRenderer.Release();
        }

        #endregion MonoBehaviour Methods

        public void RegisterPrefabsInScene()
        {
            _registeredPrefabsRuntimeData.Clear();
            _registeredPrefabsRuntimeData.AddRange(FindObjectsOfType<GPUInstancerPrefab>());
            m_InstanceRenderer.ClearInstanceProxy();

            foreach (GPUInstancerPrefab prefabInstance in _registeredPrefabsRuntimeData)
            {
                m_InstanceRenderer.RegisterInstanceProxy(prefabInstance.gameObject);
            }

            m_InstanceRenderer.Init(_registeredPrefabsRuntimeData[0].gameObject);
        }


        public void ShowGameObject()
        {
            m_InstanceRenderer.SetRenderersEnabled(true);
        }
    }

}