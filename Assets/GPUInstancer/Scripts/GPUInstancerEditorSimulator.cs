#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace GPUInstancer
{
    /// <summary>
    /// Simulate GPU Instancing while game is not running or when editor is paused
    /// </summary>
    public class GPUInstancerEditorSimulator
    {
        public GPUInstancerManager gpuiManager;
        public bool simulateAtEditor;
        public bool initializingInstances;
        public static GPUInstancerCameraData sceneViewCameraData = new GPUInstancerCameraData(null);

        public static readonly string sceneViewCameraName = "SceneCamera";

        public GPUInstancerEditorSimulator(GPUInstancerManager gpuiManager)
        {
            this.gpuiManager = gpuiManager;

            if (sceneViewCameraData == null)
                sceneViewCameraData = new GPUInstancerCameraData(null);
            sceneViewCameraData.renderOnlySelectedCamera = true;

            if (gpuiManager != null)
            {
                EditorApplication.update -= FindSceneViewCamera;
                EditorApplication.update += FindSceneViewCamera;
#if UNITY_2017_2_OR_NEWER
                EditorApplication.pauseStateChanged -= HandlePauseStateChanged;
                EditorApplication.pauseStateChanged += HandlePauseStateChanged;
#else
                EditorApplication.playmodeStateChanged = HandlePlayModeStateChanged;
#endif
            }
        }

        public void StartSimulation()
        {
            if ((Application.isPlaying && !EditorApplication.isPaused) || gpuiManager == null || !gpuiManager.isActiveAndEnabled)
                return;
            initializingInstances = true;

            simulateAtEditor = true;
            EditorApplication.update -= FindSceneViewCamera;
            EditorApplication.update += FindSceneViewCamera;
            EditorApplication.update -= EditorUpdate;
            EditorApplication.update += EditorUpdate;

            EditorApplication.playModeStateChanged -= HandlePlayModeStateChanged;
            EditorApplication.playModeStateChanged += HandlePlayModeStateChanged;
        }

        public void StopSimulation()
        {
            if (!Application.isPlaying)
                gpuiManager.ClearInstancingData();

            simulateAtEditor = false;

            UnityEngine.Rendering.RenderPipelineManager.beginFrameRendering -= CameraOnBeginRenderingSRP;

            EditorApplication.update -= EditorUpdate;

            EditorApplication.playModeStateChanged -= HandlePlayModeStateChanged;

        }

        public void ClearEditorUpdates()
        {
            simulateAtEditor = false;

            UnityEngine.Rendering.RenderPipelineManager.beginFrameRendering -= CameraOnBeginRenderingSRP;

            EditorApplication.update -= FindSceneViewCamera;

            EditorApplication.pauseStateChanged -= HandlePauseStateChanged;
            EditorApplication.playModeStateChanged -= HandlePlayModeStateChanged;

        }

        private void FindSceneViewCamera()
        {
            if (sceneViewCameraData.mainCamera == null || sceneViewCameraData.mainCamera.name != sceneViewCameraName)
            {
                if (SceneView.lastActiveSceneView != null && SceneView.lastActiveSceneView.camera != null)
                    sceneViewCameraData.SetCamera(SceneView.lastActiveSceneView.camera);
                else
                {
                    Camera currentCam = Camera.current;
                    if (currentCam != null && currentCam.name == sceneViewCameraName)
                        sceneViewCameraData.SetCamera(currentCam);
                    else
                        return;
                }
            }
            EditorApplication.update -= FindSceneViewCamera;
        }

        private void EditorUpdate()
        {
            if (sceneViewCameraData.mainCamera != null && sceneViewCameraData.mainCamera.name == sceneViewCameraName && gpuiManager != null)
            {
                if (initializingInstances)
                {
                    gpuiManager.Awake();
                    if (!gpuiManager.isInitialized)
                    {
                        gpuiManager.InitializeRuntimeDataAndBuffers();
                    }
                    initializingInstances = false;
                    return;
                }



                UnityEngine.Rendering.RenderPipelineManager.beginFrameRendering -= CameraOnBeginRenderingSRP;
                UnityEngine.Rendering.RenderPipelineManager.beginFrameRendering += CameraOnBeginRenderingSRP;


                EditorApplication.update -= EditorUpdate;
            }
        }


        private void CameraOnBeginRenderingSRP(UnityEngine.Rendering.ScriptableRenderContext context, Camera[] cams)
        {
            if (!gpuiManager.isInitialized)
            {
                StopSimulation();
                StartSimulation();
                return;
            }
            foreach (Camera cam in cams)
            {
                if (sceneViewCameraData.mainCamera == cam)
                {
                    gpuiManager.Update();
                    gpuiManager.UpdateBuffers(sceneViewCameraData);
                }
                else if (gpuiManager.cameraData.mainCamera == cam)
                {
                    gpuiManager.Update();
                    gpuiManager.UpdateBuffers(gpuiManager.cameraData);
                }
            }
        }

        public void HandlePlayModeStateChanged(PlayModeStateChange state)
        {
            StopSimulation();
        }

        public void HandlePauseStateChanged(PauseState state)
        {
            if (gpuiManager == null)
            {
                EditorApplication.pauseStateChanged -= HandlePauseStateChanged;
                return;
            }
            if (Application.isPlaying)
            {
                switch (state)
                {
                    case PauseState.Paused:
                        StartSimulation();
                        break;
                    case PauseState.Unpaused:
                        StopSimulation();
                        break;
                }
            }
        }

    }
}
#endif // UNITY_EDITOR