using System;
using UnityEngine;

namespace GPUInstancer
{
    [Serializable]
    public class GPUInstancerCameraData
    {
        public Camera mainCamera;
        public bool renderOnlySelectedCamera = false;



        public GPUInstancerCameraData(Camera mainCamera)
        {
            this.mainCamera = mainCamera;
        }

        public void SetCamera(Camera mainCamera)
        {
            this.mainCamera = mainCamera;
        }


        public Camera GetRenderingCamera()
        {
            if (renderOnlySelectedCamera
#if UNITY_EDITOR
                || UnityEditor.EditorApplication.isPaused
#endif
                )
                return mainCamera;
            return null;
        }
    }
}