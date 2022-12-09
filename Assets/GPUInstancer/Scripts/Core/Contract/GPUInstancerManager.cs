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

        public bool autoSelectCamera = true;
        public GPUInstancerCameraData cameraData = new GPUInstancerCameraData(null);


        [NonSerialized]
        public List<GPUInstancerRuntimeData> runtimeDataList;
        [NonSerialized]
        public Bounds instancingBounds;

        public static List<GPUInstancerManager> activeManagerList;
        public static bool showRenderedAmount;



#if UNITY_EDITOR
        public List<GPUInstancerPrototype> selectedPrototypeList;
        public bool isPrototypeTextMode = false;

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
        public bool isQuiting = false;
        [NonSerialized]
        public Dictionary<GPUInstancerPrototype, GPUInstancerRuntimeData> runtimeDataDictionary;

        public LayerMask layerMask = ~0;

        #region MonoBehaviour Methods

        public virtual void Awake()
        {
            GPUInstancerConstants.gpuiSettings.SetDefultBindings();

#if UNITY_EDITOR
            if (!Application.isPlaying)
                CheckPrototypeChanges();
#endif
            if (Application.isPlaying && activeManagerList == null)
                activeManagerList = new List<GPUInstancerManager>();



            showRenderedAmount = false;

            InitializeCameraData();

#if UNITY_EDITOR && UNITY_2017_2_OR_NEWER
            EditorApplication.playModeStateChanged -= HandlePlayModeStateChanged;
            EditorApplication.playModeStateChanged += HandlePlayModeStateChanged;
#endif
        }

        public virtual void Start()
        {

        }

        public virtual void OnEnable()
        {
            if (!Application.isPlaying)
                return;

            if (cameraData.mainCamera == null)
            {
                InitializeCameraData();
                if (cameraData.mainCamera == null)
                    Debug.LogWarning(GPUInstancerConstants.ERRORTEXT_cameraNotFound);
            }

            if (activeManagerList != null && !activeManagerList.Contains(this))
                activeManagerList.Add(this);

            if (SystemInfo.supportsComputeShaders)
            {
                if (GPUInstancerConstants.gpuiSettings == null || GPUInstancerConstants.gpuiSettings.shaderBindings == null)
                    Debug.LogWarning("No shader bindings file was supplied. Instancing will terminate!");

                if (runtimeDataList == null || runtimeDataList.Count == 0)
                    InitializeRuntimeDataAndBuffers();

            }


        }


        public virtual void LateUpdate()
        {
#if UNITY_EDITOR
            if (!Application.isPlaying)
                CheckPrototypeChanges();
            else
            {
#endif
                if (cameraData.mainCamera != null)
                {
                    UpdateBuffers(cameraData);
                }
#if UNITY_EDITOR
            }
#endif
        }


        public virtual void Reset()
        {
            GPUInstancerConstants.gpuiSettings.SetDefultBindings();
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

        private void OnApplicationQuit()
        {
            isQuiting = true;
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

            GPUInstancerConstants.gpuiSettings.SetDefultBindings();
        }

#if UNITY_EDITOR
        public virtual void CheckPrototypeChanges()
        {
            GPUInstancerConstants.gpuiSettings.SetDefultBindings();

            if (prototypeList == null)
                GeneratePrototypes();
            else
                prototypeList.RemoveAll(p => p == null);

        }
#endif
        public virtual void InitializeRuntimeDataAndBuffers(bool forceNew = true)
        {
            // GPUInstancerUtility.SetPlatformDependentVariables();
            if (forceNew || !isInitialized)
            {
                instancingBounds = new Bounds(Vector3.zero, Vector3.one * GPUInstancerConstants.gpuiSettings.instancingBoundsSize);

                GPUInstancerUtility.ReleaseInstanceBuffers(runtimeDataList);
                // GPUInstancerUtility.ReleaseSPBuffers(spData);
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

        public virtual void DeletePrototype(GPUInstancerPrototype prototype, bool removeSO = true)
        {
#if UNITY_EDITOR
            UnityEditor.Undo.RecordObject(this, "Delete prototype");
#endif
            prototypeList.Remove(prototype);
        }
        #endregion Virtual Methods

        #region Public Methods


        public void InitializeCameraData()
        {
            if (autoSelectCamera || cameraData.mainCamera == null)
                cameraData.SetCamera(Camera.main);
            else
                cameraData.CalculateHalfAngle();
        }

        public void UpdateBuffers(GPUInstancerCameraData renderingCameraData)
        {
            if (renderingCameraData != null && renderingCameraData.mainCamera != null && SystemInfo.supportsComputeShaders)
            {
                renderingCameraData.CalculateCameraData();

                instancingBounds.center = renderingCameraData.mainCamera.transform.position;

                GPUInstancerUtility.UpdateGPUBuffers(runtimeDataList, renderingCameraData);
                GPUInstancerUtility.GPUIDrawMeshInstancedIndirect(runtimeDataList, instancingBounds, renderingCameraData);
            }
        }

        public void SetCamera(Camera camera)
        {
            if (cameraData == null)
                cameraData = new GPUInstancerCameraData(camera);
            else
                cameraData.SetCamera(camera);
        }

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