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
        public bool enableMROnRemoveInstance = true;
        protected Dictionary<GPUInstancerPrototype, List<GPUInstancerPrefab>> _registeredPrefabsRuntimeData;
        // protected List<IPrefabVariationData> _variationDataList;

        #region MonoBehavior Methods

        public override void Reset()
        {
            base.Reset();
            RegisterPrefabsInScene();
        }

        #endregion MonoBehavior Methods

        public override void ClearInstancingData()
        {
            base.ClearInstancingData();

            if (Application.isPlaying && _registeredPrefabsRuntimeData != null && enableMROnManagerDisable)
            {
                foreach (GPUInstancerPrefabPrototype p in _registeredPrefabsRuntimeData.Keys)
                {
                    if (p.meshRenderersDisabled)
                        continue;
                    foreach (GPUInstancerPrefab prefabInstance in _registeredPrefabsRuntimeData[p])
                    {
                        if (!prefabInstance)
                            continue;
#if UNITY_EDITOR 
                        if (playModeState != PlayModeStateChange.EnteredEditMode && playModeState != PlayModeStateChange.ExitingPlayMode)
#endif
                            SetRenderersEnabled(prefabInstance, true);
                    }
                }
            }

            // if (_variationDataList != null)
            // {
            //     foreach (IPrefabVariationData pvd in _variationDataList)
            //         pvd.ReleaseBuffer();
            // }
        }

        public override void GeneratePrototypes(bool forceNew = false)
        {
            base.GeneratePrototypes();

            GPUInstancerUtility.SetPrefabInstancePrototypes(gameObject, prototypeList, prefabList, forceNew);
        }

#if UNITY_EDITOR
        public override void CheckPrototypeChanges()
        {
            base.CheckPrototypeChanges();

            if (prefabList == null)
                prefabList = new List<GameObject>();

            prefabList.RemoveAll(p => p == null);
            prefabList.RemoveAll(p => p.GetComponent<GPUInstancerPrefab>() == null);
            prototypeList.RemoveAll(p => p == null);
            prototypeList.RemoveAll(p => !prefabList.Contains(p.prefabObject));

            if (prefabList.Count != prototypeList.Count)
                GeneratePrototypes();

            registeredPrefabs.RemoveAll(rpd => !prototypeList.Contains(rpd.prefabPrototype));
            foreach (GPUInstancerPrefabPrototype prototype in prototypeList)
            {
                if (!registeredPrefabs.Exists(rpd => rpd.prefabPrototype == prototype))
                    registeredPrefabs.Add(new RegisteredPrefabsData(prototype));
            }
        }
#endif
        public override void InitializeRuntimeDataAndBuffers(bool forceNew = true)
        {
            base.InitializeRuntimeDataAndBuffers(forceNew);

            if (!forceNew && isInitialized)
                return;

            if (_registeredPrefabsRuntimeData == null)
                _registeredPrefabsRuntimeData = new Dictionary<GPUInstancerPrototype, List<GPUInstancerPrefab>>();

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
            GPUInstancerUtility.InitializeGPUBuffers(runtimeDataList);
            isInitialized = true;
        }

        public override void DeletePrototype(GPUInstancerPrototype prototype, bool removeSO = true)
        {
            base.DeletePrototype(prototype, removeSO);

            prefabList.Remove(prototype.prefabObject);
            if (removeSO)
            {
#if UNITY_2018_3_OR_NEWER && UNITY_EDITOR
                GPUInstancerUtility.RemoveComponentFromPrefab<GPUInstancerPrefab>(prototype.prefabObject);
                GPUInstancerUtility.RemoveComponentFromPrefab<GPUInstancerPrefabRuntimeHandler>(prototype.prefabObject);
#else
                DestroyImmediate(prototype.prefabObject.GetComponent<GPUInstancerPrefab>(), true);
                if (prototype.prefabObject.GetComponent<GPUInstancerPrefabRuntimeHandler>() != null)
                    DestroyImmediate(prototype.prefabObject.GetComponent<GPUInstancerPrefabRuntimeHandler>(), true);
#endif
#if UNITY_EDITOR
                EditorUtility.SetDirty(prototype.prefabObject);
                AssetDatabase.DeleteAsset(AssetDatabase.GetAssetPath(prototype));
#endif
            }
            GeneratePrototypes(false);
        }

        public virtual void InitializeRuntimeDataRegisteredPrefabs(int additionalBufferSize = 0)
        {
            if (runtimeDataList == null)
                runtimeDataList = new List<GPUInstancerRuntimeData>();
            if (runtimeDataDictionary == null)
                runtimeDataDictionary = new Dictionary<GPUInstancerPrototype, GPUInstancerRuntimeData>();

            foreach (GPUInstancerPrefabPrototype p in prototypeList)
            {
#if UNITY_EDITOR
                if (!Application.isPlaying && !p.isTransformsSerialized && !p.meshRenderersDisabled)
                    continue;
#endif
                InitializeRuntimeDataForPrefabPrototype(p, additionalBufferSize);
            }
        }

        public virtual GPUInstancerRuntimeData InitializeRuntimeDataForPrefabPrototype(GPUInstancerPrefabPrototype p, int additionalBufferSize = 0)
        {
            GPUInstancerRuntimeData runtimeData = GetRuntimeData(p);
            if (runtimeData == null)
            {
                runtimeData = new GPUInstancerRuntimeData(p);
                if (!runtimeData.CreateRenderersFromGameObject(p))
                    return null;
                runtimeDataList.Add(runtimeData);
                runtimeDataDictionary.Add(p, runtimeData);

            }
            int instanceCount = 0;
            List<GPUInstancerPrefab> registeredPrefabsList = null;
            if (p.isTransformsSerialized)
            {
                string matrixStr;
                System.IO.StringReader strReader = new System.IO.StringReader(p.serializedTransformData.text);
                List<Matrix4x4> matrixData = new List<Matrix4x4>();
                while (true)
                {
                    matrixStr = strReader.ReadLine();
                    if (!string.IsNullOrEmpty(matrixStr))
                    {
                        matrixData.Add(GPUInstancerUtility.Matrix4x4FromString(matrixStr));
                    }
                    else
                        break;
                }
                if (runtimeData.instanceDataNativeArray.IsCreated)
                    runtimeData.instanceDataNativeArray.Dispose();
                runtimeData.instanceDataNativeArray = new NativeArray<Matrix4x4>(matrixData.ToArray(), Allocator.Persistent);
                runtimeData.bufferSize = matrixData.Count + (p.enableRuntimeModifications && p.addRemoveInstancesAtRuntime ? p.extraBufferSize : 0) + additionalBufferSize;
                instanceCount = matrixData.Count;
            }
#if UNITY_EDITOR
            else if (!Application.isPlaying && p.meshRenderersDisabled)
            {
                List<GPUInstancerPrefab> prefabInstances = registeredPrefabs.Find(rpd => rpd.prefabPrototype == p).registeredPrefabs;
                runtimeData.ReleaseBuffers();
                runtimeData.bufferSize = prefabInstances.Count;
                runtimeData.instanceDataNativeArray = new NativeArray<Matrix4x4>(runtimeData.bufferSize, Allocator.Persistent);
                instanceCount = runtimeData.bufferSize;
                for (int i = 0; i < instanceCount; i++)
                {
                    runtimeData.instanceDataNativeArray[i] = prefabInstances[i].GetInstanceTransform().localToWorldMatrix;
                }
            }
#endif
            else if (_registeredPrefabsRuntimeData.TryGetValue(p, out registeredPrefabsList))
            {
                runtimeData.ReleaseBuffers();
                runtimeData.bufferSize = registeredPrefabsList.Count + (p.enableRuntimeModifications && p.addRemoveInstancesAtRuntime ? p.extraBufferSize : 0) + additionalBufferSize;
                if (runtimeData.bufferSize > 0)
                {
                    runtimeData.instanceDataNativeArray = new NativeArray<Matrix4x4>(runtimeData.bufferSize, Allocator.Persistent);

                    Matrix4x4 instanceData;


                    foreach (GPUInstancerPrefab prefabInstance in registeredPrefabsList)
                    {
                        if (!prefabInstance)
                            continue;

                        Transform instanceTransform = prefabInstance.GetInstanceTransform();
                        instanceData = instanceTransform.localToWorldMatrix;
                        prefabInstance.state = PrefabInstancingState.Instanced;

                        bool disableRenderers = true;

                        if (disableRenderers && !p.meshRenderersDisabled)
                            SetRenderersEnabled(prefabInstance, false);


                        runtimeData.instanceDataNativeArray[instanceCount] = instanceData;
                        instanceCount++;
                        prefabInstance.gpuInstancerID = instanceCount;
                    }
                }
            }

            // set instanceCount
            runtimeData.instanceCount = instanceCount;


            return runtimeData;
        }

        public virtual void SetRenderersEnabled(GPUInstancerPrefab prefabInstance, bool enabled)
        {
            if (!prefabInstance || !prefabInstance.prefabPrototype || !prefabInstance.prefabPrototype.prefabObject)
                return;

            MeshRenderer[] meshRenderers = prefabInstance.GetComponentsInChildren<MeshRenderer>(true);
            if (meshRenderers != null && meshRenderers.Length > 0)
                for (int mr = 0; mr < meshRenderers.Length; mr++)
                    if (GPUInstancerUtility.IsInLayer(layerMask, meshRenderers[mr].gameObject.layer))
                        meshRenderers[mr].enabled = enabled;

            BillboardRenderer[] billboardRenderers = prefabInstance.GetComponentsInChildren<BillboardRenderer>(true);
            if (billboardRenderers != null && billboardRenderers.Length > 0)
                for (int mr = 0; mr < billboardRenderers.Length; mr++)
                    if (GPUInstancerUtility.IsInLayer(layerMask, billboardRenderers[mr].gameObject.layer))
                        billboardRenderers[mr].enabled = enabled;

            LODGroup lodGroup = prefabInstance.GetComponent<LODGroup>();
            if (lodGroup != null)
                lodGroup.enabled = enabled;
        }

        #region API Methods

        public static void ExpandBufferSize(GPUInstancerRuntimeData runtimeData, int newBufferSize)
        {
            if (runtimeData.bufferSize < newBufferSize)
            {
                runtimeData.bufferSize = newBufferSize;
                runtimeData.instanceDataNativeArray = GPUInstancerUtility.ResizeNativeArray(runtimeData.instanceDataNativeArray, newBufferSize, Allocator.Persistent);
            }
        }

        public virtual void SetInstanceTransform(GPUInstancerRuntimeData runtimeData, int index, Transform transform)
        {
            runtimeData.instanceDataNativeArray[index] = transform ? transform.localToWorldMatrix : Matrix4x4.zero;

        }

        public virtual void AddPrefabInstance(GPUInstancerPrefab prefabInstance, bool automaticallyIncreaseBufferSize = false)
        {

            if (!prefabInstance || prefabInstance.state == PrefabInstancingState.Instanced)
                return;

            if (runtimeDataList == null)
                return;

            GPUInstancerRuntimeData runtimeData = GetRuntimeData(prefabInstance.prefabPrototype, true);
            if (runtimeData != null)
            {
                Transform instanceTransform = prefabInstance.GetInstanceTransform();
                if (runtimeData.bufferSize == runtimeData.instanceCount)
                {
                    if (automaticallyIncreaseBufferSize)
                    {
                        ExpandBufferSize(runtimeData, runtimeData.bufferSize + 1024);
                        SetInstanceTransform(runtimeData, runtimeData.instanceCount, instanceTransform);
                        runtimeData.instanceCount++;
                        prefabInstance.gpuInstancerID = runtimeData.instanceCount;
                        _registeredPrefabsRuntimeData[prefabInstance.prefabPrototype].Add(prefabInstance);
                        if (!prefabInstance.prefabPrototype.meshRenderersDisabled)
                            SetRenderersEnabled(prefabInstance, false);
                        prefabInstance.state = PrefabInstancingState.Instanced;
                        GPUInstancerUtility.InitializeGPUBuffer(runtimeData);

                        return;
                    }
                    else
                    {
                        Debug.LogWarning("Can not add instance. Buffer is full.");
                        return;
                    }
                }
                prefabInstance.state = PrefabInstancingState.Instanced;
                SetInstanceTransform(runtimeData, runtimeData.instanceCount, instanceTransform);
                runtimeData.instanceCount++;
                prefabInstance.gpuInstancerID = runtimeData.instanceCount;

                runtimeData.transformationMatrixVisibilityBuffer.SetData(runtimeData.instanceDataNativeArray, prefabInstance.gpuInstancerID - 1, prefabInstance.gpuInstancerID - 1, 1);
                if (!prefabInstance.prefabPrototype.meshRenderersDisabled)
                    SetRenderersEnabled(prefabInstance, false);

                if (!_registeredPrefabsRuntimeData.ContainsKey(prefabInstance.prefabPrototype))
                    _registeredPrefabsRuntimeData.Add(prefabInstance.prefabPrototype, new List<GPUInstancerPrefab>());
                _registeredPrefabsRuntimeData[prefabInstance.prefabPrototype].Add(prefabInstance);

            }
        }



        public virtual void RemovePrefabInstance(GPUInstancerPrefab prefabInstance, bool setRenderersEnabled = true)
        {

            if (!prefabInstance || prefabInstance.state == PrefabInstancingState.None)
                return;

            GPUInstancerRuntimeData runtimeData = GetRuntimeData(prefabInstance.prefabPrototype);
            if (runtimeData != null)
            {
                if (prefabInstance.gpuInstancerID > runtimeData.bufferSize || prefabInstance.gpuInstancerID <= 0)
                {
                    Debug.LogWarning("Instance can not be removed.");
                    return;
                }

                List<GPUInstancerPrefab> prefabInstanceList = _registeredPrefabsRuntimeData[prefabInstance.prefabPrototype];

                if (prefabInstance.gpuInstancerID == runtimeData.instanceCount)
                {
                    prefabInstance.state = PrefabInstancingState.None;
                    SetInstanceTransform(runtimeData, prefabInstance.gpuInstancerID - 1, null);
                    runtimeData.instanceCount--;
                    prefabInstanceList.RemoveAt(prefabInstance.gpuInstancerID - 1);
                    if (setRenderersEnabled && enableMROnRemoveInstance && !prefabInstance.prefabPrototype.meshRenderersDisabled)
                        SetRenderersEnabled(prefabInstance, true);
                }
                else
                {
                    GPUInstancerPrefab lastIndexPrefabInstance = null;
                    for (int i = prefabInstanceList.Count - 1; i >= 0; i--)
                    {
                        GPUInstancerPrefab loopPI = prefabInstanceList[i];
                        if (loopPI == null)
                        {
                            prefabInstanceList.RemoveAt(i);
                            if (i < prefabInstanceList.Count - 1)
                                i++;
                        }
                        else if (loopPI.gpuInstancerID == runtimeData.instanceCount)
                        {
                            lastIndexPrefabInstance = loopPI;
                            break;
                        }
                    }
                    if (!lastIndexPrefabInstance)
                    {
                        prefabInstanceList.RemoveAll(pi => pi == null);
                        Debug.LogWarning("Prefab instance was destoyed before being removed from instance list in GPUI Prefab Manager!");
                        return;
                    }

                    prefabInstance.state = PrefabInstancingState.None;

                    // exchange last index with this one
                    SetInstanceTransform(runtimeData, prefabInstance.gpuInstancerID - 1, lastIndexPrefabInstance.GetInstanceTransform());
                    // set last index data to Matrix4x4.zero
                    SetInstanceTransform(runtimeData, lastIndexPrefabInstance.gpuInstancerID - 1, null);
                    runtimeData.instanceCount--;

                    runtimeData.transformationMatrixVisibilityBuffer.SetData(runtimeData.instanceDataNativeArray, prefabInstance.gpuInstancerID - 1, prefabInstance.gpuInstancerID - 1, 1);

                    prefabInstanceList.RemoveAt(lastIndexPrefabInstance.gpuInstancerID - 1);
                    lastIndexPrefabInstance.gpuInstancerID = prefabInstance.gpuInstancerID;
                    prefabInstanceList[lastIndexPrefabInstance.gpuInstancerID - 1] = lastIndexPrefabInstance;

                    if (setRenderersEnabled && enableMROnRemoveInstance && !prefabInstance.prefabPrototype.meshRenderersDisabled)
                        SetRenderersEnabled(prefabInstance, true);

                }
            }

        }

        public virtual void RegisterPrefabsInScene()
        {
#if UNITY_EDITOR
            Undo.RecordObject(this, "Registered prefabs changed");
#endif
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

        public virtual int GetEnabledPrefabCount()
        {
            int sum = 0;

            return sum;
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