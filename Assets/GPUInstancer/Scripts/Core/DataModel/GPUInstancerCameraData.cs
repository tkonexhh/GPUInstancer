﻿using System;
using UnityEngine;

namespace GPUInstancer
{
    [Serializable]
    public class GPUInstancerCameraData
    {
        public Camera mainCamera;
        public bool renderOnlySelectedCamera = false;

        [NonSerialized]
        public Matrix4x4 mvpMatrix;
        [NonSerialized]
        public Vector3 cameraPosition = Vector3.zero;
        [NonSerialized]
        public float halfAngle;

        public GPUInstancerCameraData() : this(null) { }

        public GPUInstancerCameraData(Camera mainCamera)
        {
            this.mainCamera = mainCamera;
            CalculateHalfAngle();
        }

        public void SetCamera(Camera mainCamera)
        {
            this.mainCamera = mainCamera;
            CalculateHalfAngle();
        }

        public void CalculateCameraData()
        {
            mvpMatrix = mainCamera.projectionMatrix * mainCamera.worldToCameraMatrix;

            cameraPosition = mainCamera.transform.position;
        }

        public void CalculateHalfAngle()
        {
            if (mainCamera != null)
                halfAngle = Mathf.Tan(Mathf.Deg2Rad * mainCamera.fieldOfView * 0.25f);
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