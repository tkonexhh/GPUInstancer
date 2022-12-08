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

        public bool useFloatingOriginHandler = false;
        public bool applyFloatingOriginRotationAndScale = false;
        public Transform floatingOriginTransform;
        [NonSerialized]
        public GPUInstancerFloatingOriginHandler floatingOriginHandler;

        [NonSerialized]
        public List<GPUInstancerRuntimeData> runtimeDataList;
        [NonSerialized]
        public Bounds instancingBounds;

        public bool isFrustumCulling = true;

        public static List<GPUInstancerManager> activeManagerList;
        public static bool showRenderedAmount;

        protected static ComputeShader _cameraComputeShader;
        protected static int[] _cameraComputeKernelIDs;
        protected static ComputeShader _visibilityComputeShader;
        protected static int[] _instanceVisibilityComputeKernelIDs;
        protected static ComputeShader _bufferToTextureComputeShader;
        protected static int _bufferToTextureComputeKernelID;
        protected static ComputeShader _argsBufferComputeShader;
        protected static int _argsBufferDoubleInstanceCountComputeKernelID;

#if UNITY_EDITOR
        public List<GPUInstancerPrototype> selectedPrototypeList;
        [NonSerialized]
        public GPUInstancerEditorSimulator gpuiSimulator;
        public bool isPrototypeTextMode = false;

        public bool showSceneSettingsBox = true;
        public bool showPrototypeBox = true;
        public bool showAdvancedBox = false;
        public bool showHelpText = false;
        public bool showDebugBox = true;
        public bool showGlobalValuesBox = true;
        public bool showRegisteredPrefabsBox = true;
        public bool showPrototypesBox = true;

        public bool keepSimulationLive = false;
#endif

        public class GPUIThreadData
        {
            public Thread thread;
            public object parameter;
        }
        public static int maxThreads = 3;
        public readonly List<Thread> activeThreads = new List<Thread>();
        public readonly Queue<GPUIThreadData> threadStartQueue = new Queue<GPUIThreadData>();
        public readonly Queue<Action> threadQueue = new Queue<Action>();



        // Time management
        public static int lastDrawCallFrame;
        public static float lastDrawCallTime;
        public static float timeSinceLastDrawCall;


        [NonSerialized]
        protected bool isInitial = true;

        [NonSerialized]
        public bool isInitialized = false;

#if UNITY_EDITOR && UNITY_2017_2_OR_NEWER
        [NonSerialized]
        public PlayModeStateChange playModeState;
#endif
        [NonSerialized]
        public bool isQuiting = false;
        [NonSerialized]
        public Dictionary<GPUInstancerPrototype, GPUInstancerRuntimeData> runtimeDataDictionary;

        public LayerMask layerMask = ~0;
        public bool lightProbeDisabled = false;

        #region MonoBehaviour Methods

        public virtual void Awake()
        {
            GPUInstancerConstants.gpuiSettings.SetDefultBindings();
            GPUInstancerUtility.SetPlatformDependentVariables();

#if UNITY_EDITOR
            if (!Application.isPlaying)
                CheckPrototypeChanges();
#endif
            if (Application.isPlaying && activeManagerList == null)
                activeManagerList = new List<GPUInstancerManager>();

            if (SystemInfo.supportsComputeShaders)
            {
                if (_visibilityComputeShader == null)
                {
                    switch (GPUInstancerUtility.matrixHandlingType)
                    {
                        case GPUIMatrixHandlingType.MatrixAppend:
                            _visibilityComputeShader = (ComputeShader)Resources.Load(GPUInstancerConstants.VISIBILITY_COMPUTE_RESOURCE_PATH_VULKAN);
                            GPUInstancerConstants.DETAIL_STORE_INSTANCE_DATA = true;
                            GPUInstancerConstants.COMPUTE_MAX_LOD_BUFFER = 2;
                            break;
                        case GPUIMatrixHandlingType.CopyToTexture:
                            _visibilityComputeShader = (ComputeShader)Resources.Load(GPUInstancerConstants.VISIBILITY_COMPUTE_RESOURCE_PATH);
                            _bufferToTextureComputeShader = (ComputeShader)Resources.Load(GPUInstancerConstants.BUFFER_TO_TEXTURE_COMPUTE_RESOURCE_PATH);
                            _bufferToTextureComputeKernelID = _bufferToTextureComputeShader.FindKernel(GPUInstancerConstants.BUFFER_TO_TEXTURE_KERNEL);
                            break;
                        default:
                            _visibilityComputeShader = (ComputeShader)Resources.Load(GPUInstancerConstants.VISIBILITY_COMPUTE_RESOURCE_PATH);
                            break;
                    }

                    _instanceVisibilityComputeKernelIDs = new int[GPUInstancerConstants.VISIBILITY_COMPUTE_KERNELS.Length];
                    for (int i = 0; i < _instanceVisibilityComputeKernelIDs.Length; i++)
                        _instanceVisibilityComputeKernelIDs[i] = _visibilityComputeShader.FindKernel(GPUInstancerConstants.VISIBILITY_COMPUTE_KERNELS[i]);
                    GPUInstancerConstants.TEXTURE_MAX_SIZE = SystemInfo.maxTextureSize;

                    _cameraComputeShader = (ComputeShader)Resources.Load(GPUInstancerConstants.CAMERA_COMPUTE_RESOURCE_PATH);
                    _cameraComputeKernelIDs = new int[GPUInstancerConstants.CAMERA_COMPUTE_KERNELS.Length];
                    for (int i = 0; i < _cameraComputeKernelIDs.Length; i++)
                        _cameraComputeKernelIDs[i] = _cameraComputeShader.FindKernel(GPUInstancerConstants.CAMERA_COMPUTE_KERNELS[i]);

                    _argsBufferComputeShader = Resources.Load<ComputeShader>(GPUInstancerConstants.ARGS_BUFFER_COMPUTE_RESOURCE_PATH);
                    _argsBufferDoubleInstanceCountComputeKernelID = _argsBufferComputeShader.FindKernel(GPUInstancerConstants.ARGS_BUFFER_DOUBLE_INSTANCE_COUNT_KERNEL);
                }

                GPUInstancerConstants.SetupComputeRuntimeModification();
                GPUInstancerConstants.SetupComputeSetDataPartial();
            }
            else if (Application.isPlaying)
            {
                Debug.LogError("Target Graphics API does not support Compute Shaders. Please refer to Minimum Requirements on GPUInstancer/ReadMe.txt for detailed information.");
                this.enabled = false;
            }

            showRenderedAmount = false;

            InitializeCameraData();

#if UNITY_EDITOR && UNITY_2017_2_OR_NEWER
            EditorApplication.playModeStateChanged -= HandlePlayModeStateChanged;
            EditorApplication.playModeStateChanged += HandlePlayModeStateChanged;
#endif
        }

        public virtual void Start()
        {
            if (Application.isPlaying && SystemInfo.supportsComputeShaders)
            {
                // SetupOcclusionCulling(cameraData);
            }
#if UNITY_EDITOR
            // Sometimes Awake is not called on Editor Mode after compilation
            else if (_instanceVisibilityComputeKernelIDs == null)
                Awake();
#endif
        }

        public virtual void OnEnable()
        {
#if UNITY_EDITOR
            if (gpuiSimulator == null)
                gpuiSimulator = new GPUInstancerEditorSimulator(this);
#endif

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
                isInitial = true;
            }

            if (useFloatingOriginHandler && floatingOriginTransform != null)
            {
                if (floatingOriginHandler == null)
                {
                    floatingOriginHandler = floatingOriginTransform.gameObject.GetComponent<GPUInstancerFloatingOriginHandler>();
                    if (floatingOriginHandler == null)
                        floatingOriginHandler = floatingOriginTransform.gameObject.AddComponent<GPUInstancerFloatingOriginHandler>();
                }
                floatingOriginHandler.applyRotationAndScale = applyFloatingOriginRotationAndScale;
                if (floatingOriginHandler.gPUIManagers == null)
                    floatingOriginHandler.gPUIManagers = new List<GPUInstancerManager>();
                if (!floatingOriginHandler.gPUIManagers.Contains(this))
                    floatingOriginHandler.gPUIManagers.Add(this);
            }
        }

        public virtual void Update()
        {
            ClearCompletedThreads();
            while (threadStartQueue.Count > 0 && activeThreads.Count < maxThreads)
            {
                GPUIThreadData threadData = threadStartQueue.Dequeue();
                threadData.thread.Start(threadData.parameter);
                activeThreads.Add(threadData.thread);
            }
            if (threadQueue.Count > 0)
            {
                Action action = threadQueue.Dequeue();
                if (action != null)
                    action.Invoke();
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

        public virtual void OnDestroy()
        {
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
#if UNITY_EDITOR
            if (gpuiSimulator != null)
            {
                gpuiSimulator.ClearEditorUpdates();
                gpuiSimulator = null;
            }
#endif

            if (floatingOriginHandler != null && floatingOriginHandler.gPUIManagers != null && floatingOriginHandler.gPUIManagers.Contains(this))
            {
                floatingOriginHandler.gPUIManagers.Remove(this);
            }
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
            // GPUInstancerUtility.ReleaseSPBuffers(spData);
            if (runtimeDataList != null)
                runtimeDataList.Clear();
            if (runtimeDataDictionary != null)
                runtimeDataDictionary.Clear();
            // spData = null;
            threadStartQueue.Clear();
            threadQueue.Clear();
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

            if (GPUInstancerConstants.gpuiSettings != null && GPUInstancerConstants.gpuiSettings.shaderBindings != null)
            {
                GPUInstancerConstants.gpuiSettings.shaderBindings.ClearEmptyShaderInstances();
                foreach (GPUInstancerPrototype prototype in prototypeList)
                {
                    if (prototype.prefabObject != null)
                    {
                        GPUInstancerUtility.GenerateInstancedShadersForGameObject(prototype);
                        if (string.IsNullOrEmpty(prototype.warningText))
                        {
                            if (prototype.prefabObject.GetComponentInChildren<MeshRenderer>() == null)
                            {
                                prototype.warningText = "Prefab object does not contain any Mesh Renderers.";
                            }
                        }
                    }
                    else
                    {
                        if (GPUInstancerConstants.gpuiSettings.IsStandardRenderPipeline())
                            GPUInstancerConstants.gpuiSettings.AddShaderVariantToCollection(GPUInstancerConstants.SHADER_GPUI_FOLIAGE);
                        else if (GPUInstancerConstants.gpuiSettings.isURP)
                        {
                            if (Shader.Find(GPUInstancerConstants.SHADER_GPUI_FOLIAGE_URP) != null)
                                GPUInstancerConstants.gpuiSettings.AddShaderVariantToCollection(GPUInstancerConstants.SHADER_GPUI_FOLIAGE_URP);
                        }

                    }
                }
            }

        }
#endif
        public virtual void InitializeRuntimeDataAndBuffers(bool forceNew = true)
        {
            GPUInstancerUtility.SetPlatformDependentVariables();
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

        public void ClearCompletedThreads()
        {
            if (activeThreads.Count > 0)
            {
                for (int i = activeThreads.Count - 1; i >= 0; i--)
                {
                    if (!activeThreads[i].IsAlive)
                        activeThreads.RemoveAt(i);
                }
            }
        }

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

                if (lastDrawCallFrame != Time.frameCount)
                {
                    lastDrawCallFrame = Time.frameCount;
                    timeSinceLastDrawCall = Time.realtimeSinceStartup - lastDrawCallTime;
                    lastDrawCallTime = Time.realtimeSinceStartup;
                }

                GPUInstancerUtility.UpdateGPUBuffers(_cameraComputeShader, _cameraComputeKernelIDs, _visibilityComputeShader, _instanceVisibilityComputeKernelIDs, runtimeDataList, renderingCameraData, isFrustumCulling,
                    false, showRenderedAmount, isInitial);
                isInitial = false;

                if (GPUInstancerUtility.matrixHandlingType == GPUIMatrixHandlingType.CopyToTexture)
                    GPUInstancerUtility.DispatchBufferToTexture(runtimeDataList, _bufferToTextureComputeShader, _bufferToTextureComputeKernelID);

                GPUInstancerUtility.GPUIDrawMeshInstancedIndirect(runtimeDataList, instancingBounds, renderingCameraData, layerMask, lightProbeDisabled);
            }
        }

        public void SetCamera(Camera camera)
        {
            if (cameraData == null)
                cameraData = new GPUInstancerCameraData(camera);
            else
                cameraData.SetCamera(camera);

            // if (cameraData.hiZOcclusionGenerator != null)
            //     DestroyImmediate(cameraData.hiZOcclusionGenerator);
        }



#if UNITY_EDITOR && UNITY_2017_2_OR_NEWER
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