using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using System.Threading;
#if UNITY_EDITOR
using UnityEditor;
#endif

namespace GPUInstancer
{
    public abstract class GPUInstancerManager : MonoBehaviour
    {
        public List<GPUInstancerPrototype> prototypeList;

        [NonSerialized]
        public List<GPUInstancerRuntimeData> runtimeDataList;
        [NonSerialized]
        public Bounds instancingBounds;

        public static List<GPUInstancerManager> activeManagerList;



#if UNITY_EDITOR
        public List<GPUInstancerPrototype> selectedPrototypeList;

        public bool showSceneSettingsBox = true;
        public bool showPrototypeBox = true;
        public bool showAdvancedBox = false;
        public bool showHelpText = false;
        public bool showDebugBox = true;
        public bool showGlobalValuesBox = true;
        public bool showRegisteredPrefabsBox = true;
        public bool showPrototypesBox = true;
#endif


        [NonSerialized]
        public bool isInitialized = false;

#if UNITY_EDITOR 
        [NonSerialized]
        public PlayModeStateChange playModeState;
#endif
        [NonSerialized]
        public Dictionary<GPUInstancerPrototype, GPUInstancerRuntimeData> runtimeDataDictionary;

        #region MonoBehaviour Methods

        public virtual void Awake()
        {

#if UNITY_EDITOR
            if (!Application.isPlaying)
                CheckPrototypeChanges();
#endif
            if (Application.isPlaying && activeManagerList == null)
                activeManagerList = new List<GPUInstancerManager>();


#if UNITY_EDITOR
            EditorApplication.playModeStateChanged -= HandlePlayModeStateChanged;
            EditorApplication.playModeStateChanged += HandlePlayModeStateChanged;
#endif
        }

        public virtual void OnEnable()
        {
            if (!Application.isPlaying)
                return;

            if (activeManagerList != null && !activeManagerList.Contains(this))
                activeManagerList.Add(this);

            if (SystemInfo.supportsComputeShaders)
            {


                if (runtimeDataList == null || runtimeDataList.Count == 0)
                    InitializeRuntimeDataAndBuffers();

            }
        }

        public virtual void LateUpdate()
        {
            instancingBounds.center = Camera.main.transform.position;

            GPUInstancerUtility.UpdateGPUBuffers(runtimeDataList);
            GPUInstancerUtility.GPUIDrawMeshInstancedIndirect(runtimeDataList, instancingBounds);
        }

        public virtual void Reset()
        {
#if UNITY_EDITOR
            CheckPrototypeChanges();
#endif
        }

        public virtual void OnDisable() // could also be OnDestroy, but OnDestroy seems to be too late to prevent buffer leaks.
        {
            if (activeManagerList != null)
                activeManagerList.Remove(this);

            ClearInstancingData();
        }

        #endregion MonoBehaviour Methods

        #region Virtual Methods

        public virtual void ClearInstancingData()
        {
            GPUInstancerUtility.ReleaseInstanceBuffers(runtimeDataList);
            if (runtimeDataList != null)
                runtimeDataList.Clear();
            if (runtimeDataDictionary != null)
                runtimeDataDictionary.Clear();

            isInitialized = false;
        }

        public virtual void GeneratePrototypes(bool forceNew = false)
        {
            ClearInstancingData();

            if (forceNew || prototypeList == null)
                prototypeList = new List<GPUInstancerPrototype>();
            else
                prototypeList.RemoveAll(p => p == null);

        }

#if UNITY_EDITOR
        public virtual void CheckPrototypeChanges()
        {

            if (prototypeList == null)
                GeneratePrototypes();
            else
                prototypeList.RemoveAll(p => p == null);

        }
#endif
        public virtual void InitializeRuntimeDataAndBuffers(bool forceNew = true)
        {
            if (forceNew || !isInitialized)
            {
                instancingBounds = new Bounds(Vector3.zero, Vector3.one * 10000);

                GPUInstancerUtility.ReleaseInstanceBuffers(runtimeDataList);
                if (runtimeDataList != null)
                    runtimeDataList.Clear();
                else
                    runtimeDataList = new List<GPUInstancerRuntimeData>();

                if (runtimeDataDictionary != null)
                    runtimeDataDictionary.Clear();
                else
                    runtimeDataDictionary = new Dictionary<GPUInstancerPrototype, GPUInstancerRuntimeData>();

                if (prototypeList == null)
                    prototypeList = new List<GPUInstancerPrototype>();
            }
        }


        #endregion Virtual Methods

        #region Public Methods

#if UNITY_EDITOR
        public void HandlePlayModeStateChanged(PlayModeStateChange state)
        {
            playModeState = state;
        }
#endif

        public GPUInstancerRuntimeData GetRuntimeData(GPUInstancerPrototype prototype, bool logError = false)
        {
            GPUInstancerRuntimeData runtimeData = null;
            if (runtimeDataDictionary != null && !runtimeDataDictionary.TryGetValue(prototype, out runtimeData) && logError)
                Debug.LogError("Can not find runtime data for prototype: " + prototype + ". Please check if the prototype was added to the Manager and the initialize method was called.");
            return runtimeData;
        }
        #endregion Public Methods
    }

}