using System;
using System.Collections.Generic;
using UnityEngine;
using System.Threading;
using Unity.Collections;
using System.Linq;
using UnityEngine.Jobs;
#if UNITY_EDITOR
using UnityEditor;
#endif
using Inutan;

namespace GPUInstancer
{
    [ExecuteInEditMode]
    public class GPUInstancerPrefabManager : GPUInstancerManager
    {
        [SerializeField]
        public List<RegisteredPrefabsData> registeredPrefabs = new List<RegisteredPrefabsData>();
        [SerializeField]
        public List<GameObject> prefabList = new List<GameObject>();
        public bool enableMROnManagerDisable = true;
        protected Dictionary<GPUInstancerPrototype, List<GPUInstancerPrefab>> _registeredPrefabsRuntimeData = new Dictionary<GPUInstancerPrototype, List<GPUInstancerPrefab>>();


        public override void ClearInstancingData()
        {
            base.ClearInstancingData();

            if (Application.isPlaying && _registeredPrefabsRuntimeData != null && enableMROnManagerDisable)
            {
                foreach (GPUInstancerPrefabPrototype p in _registeredPrefabsRuntimeData.Keys)
                {
                    foreach (GPUInstancerPrefab prefabInstance in _registeredPrefabsRuntimeData[p])
                    {
                        if (!prefabInstance)
                            continue;

                        SetRenderersEnabled(prefabInstance, true);
                    }
                }
            }
        }

        public override void GeneratePrototypes(bool forceNew = false)
        {
            base.GeneratePrototypes();

            GPUInstancerUtility.SetPrefabInstancePrototypes(gameObject, prototypeList, prefabList, forceNew);
        }

        public override void InitializeRuntimeDataAndBuffers(bool forceNew = true)
        {
            base.InitializeRuntimeDataAndBuffers(forceNew);

            if (!forceNew && isInitialized)
                return;

#if UNITY_EDITOR
            if (Application.isPlaying)
            {
#endif
                if (registeredPrefabs != null && registeredPrefabs.Count > 0)
                {
                    foreach (RegisteredPrefabsData rpd in registeredPrefabs)
                    {
                        if (!_registeredPrefabsRuntimeData.ContainsKey(rpd.prefabPrototype))
                            _registeredPrefabsRuntimeData.Add(rpd.prefabPrototype, rpd.registeredPrefabs);
                        else
                            _registeredPrefabsRuntimeData[rpd.prefabPrototype].AddRange(rpd.registeredPrefabs);
                    }
                    registeredPrefabs.Clear();
                }

                if (_registeredPrefabsRuntimeData.Count != prototypeList.Count)
                {
                    foreach (GPUInstancerPrototype p in prototypeList)
                    {
                        if (!_registeredPrefabsRuntimeData.ContainsKey(p))
                            _registeredPrefabsRuntimeData.Add(p, new List<GPUInstancerPrefab>());
                    }
                }
#if UNITY_EDITOR
            }
#endif

            InitializeRuntimeDataRegisteredPrefabs();

            isInitialized = true;
        }

        public virtual void InitializeRuntimeDataRegisteredPrefabs(int additionalBufferSize = 0)
        {
            if (runtimeDataList == null)
                runtimeDataList = new List<GPUInstanceRenderer>();
            if (runtimeDataDictionary == null)
                runtimeDataDictionary = new Dictionary<GPUInstancerPrototype, GPUInstanceRenderer>();

            foreach (GPUInstancerPrefabPrototype p in prototypeList)
            {
#if UNITY_EDITOR
                if (!Application.isPlaying)
                    continue;
#endif
                InitializeRuntimeDataForPrefabPrototype(p, additionalBufferSize);
            }
        }

        public virtual GPUInstanceRenderer InitializeRuntimeDataForPrefabPrototype(GPUInstancerPrefabPrototype p, int additionalBufferSize = 0)
        {
            GPUInstanceRenderer runtimeData = null;
            runtimeDataDictionary.TryGetValue(p, out runtimeData);

            if (runtimeData == null)
            {
                runtimeData = new GPUInstanceRenderer();
                runtimeData.ClearInstanceProxy();
                if (!runtimeData.CreateRenderersFromGameObject(p.prefabObject))
                    return null;
                runtimeDataList.Add(runtimeData);
                runtimeDataDictionary.Add(p, runtimeData);

            }

            List<GPUInstancerPrefab> registeredPrefabsList = null;

            if (_registeredPrefabsRuntimeData.TryGetValue(p, out registeredPrefabsList))
            {

                foreach (GPUInstancerPrefab prefabInstance in registeredPrefabsList)
                {
                    if (prefabInstance != null)
                        runtimeData.RegisterInstanceProxy(prefabInstance.gameObject);
                }
            }

            runtimeData.Init(p.prefabObject);

            return runtimeData;
        }

        public virtual void SetRenderersEnabled(GPUInstancerPrefab prefabInstance, bool enabled)
        {
            if (!prefabInstance || !prefabInstance.prefabPrototype || !prefabInstance.prefabPrototype.prefabObject)
                return;

            MeshRenderer[] meshRenderers = prefabInstance.GetComponentsInChildren<MeshRenderer>(true);
            if (meshRenderers != null && meshRenderers.Length > 0)
                for (int mr = 0; mr < meshRenderers.Length; mr++)
                    meshRenderers[mr].enabled = enabled;

        }

        #region API Methods

        public virtual void RegisterPrefabsInScene()
        {

            registeredPrefabs.Clear();
            foreach (GPUInstancerPrefabPrototype pp in prototypeList)
                registeredPrefabs.Add(new RegisteredPrefabsData(pp));

            GPUInstancerPrefab[] scenePrefabInstances = FindObjectsOfType<GPUInstancerPrefab>();
            foreach (GPUInstancerPrefab prefabInstance in scenePrefabInstances)
                AddRegisteredPrefab(prefabInstance);
        }

        public virtual void ClearRegisteredPrefabInstances()
        {
            foreach (GPUInstancerPrototype p in _registeredPrefabsRuntimeData.Keys)
            {
                _registeredPrefabsRuntimeData[p].Clear();
            }
        }
        #endregion API Methods

        public virtual void AddRegisteredPrefab(GPUInstancerPrefab prefabInstance)
        {
            RegisteredPrefabsData data = null;
            foreach (RegisteredPrefabsData item in registeredPrefabs)
            {
                if (item.prefabPrototype == prefabInstance.prefabPrototype)
                {
                    data = item;
                    break;
                }
            }
            if (data != null)
                data.registeredPrefabs.Add(prefabInstance);
        }
    }

    [Serializable]
    public class RegisteredPrefabsData
    {
        public GPUInstancerPrefabPrototype prefabPrototype;
        public List<GPUInstancerPrefab> registeredPrefabs;

        public RegisteredPrefabsData(GPUInstancerPrefabPrototype prefabPrototype)
        {
            this.prefabPrototype = prefabPrototype;
            registeredPrefabs = new List<GPUInstancerPrefab>();
        }
    }

}