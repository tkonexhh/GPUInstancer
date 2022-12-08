using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;
using Sirenix.OdinInspector;

namespace Inutan
{
    [AddComponentMenu("Rendering/Lens Flare SRP Occlusion")]
    [RequireComponent(typeof(LensFlareComponentSRP))]
    [ExecuteInEditMode]
    public class LensFlareComponentSRPOcclusion : MonoBehaviour
    {
        [ReadOnly, LabelText("摄像机")]
        public Camera m_Camera;

        [ReadOnly, LabelText("当前遮挡物")]
        public GameObject m_OcclusionObject;

        public LayerMask m_Layer;

        [LabelText("遮挡时强度变化速度")]
        public float m_OcclusionIntensitySpeed = 0;

        [LabelText("遮挡时缩放变化速度")]
        public float m_OcclusionScaleSpeed = 0;


        //
        private LensFlareComponentSRP m_LensFlare;

        private float m_OcclusionValue = 1;
        private float m_OcclusionIntensity = 1;
        private float m_OcclusionScale = 1;

        void OnDisable()
        {
            // m_LensFlare.SetOcclusionMulti(1, 1);
        }
        static Vector3 WorldToViewportLocal(bool isCameraRelative, Matrix4x4 viewProjMatrix, Vector3 cameraPosWS, Vector3 positionWS)
        {
            Vector3 localPositionWS = positionWS;
            if (isCameraRelative)
            {
                localPositionWS -= cameraPosWS;
            }
            Vector4 viewportPos4 = viewProjMatrix * localPositionWS;
            Vector3 viewportPos = new Vector3(viewportPos4.x, viewportPos4.y, 0f);
            viewportPos /= viewportPos4.w;
            viewportPos.x = viewportPos.x * 0.5f + 0.5f;
            viewportPos.y = viewportPos.y * 0.5f + 0.5f;
            viewportPos.y = 1.0f - viewportPos.y;
            viewportPos.z = viewportPos4.w;
            return viewportPos;
        }

        bool CalculateOffScreen(Camera camera)
        {
            var gpuView = camera.worldToCameraMatrix;
            var gpuNonJitteredProj = GL.GetGPUProjectionMatrix(camera.projectionMatrix, true);
            gpuView.SetColumn(3, new Vector4(0, 0, 0, 1));
            var gpuVP = gpuNonJitteredProj * camera.worldToCameraMatrix;

            Vector3 viewportPos = WorldToViewportLocal(true, gpuVP, camera.transform.position, transform.position);

            if (viewportPos.x < 0.0f || viewportPos.x > 1.0f ||
                viewportPos.y < 0.0f || viewportPos.y > 1.0f || viewportPos.z < 0.0f)
                return true;

            return false;
        }
        void Update()
        {
#if UNITY_EDITOR
            if (!Application.isPlaying)
            {
                if (SceneView.lastActiveSceneView != null)
                    m_Camera = SceneView.lastActiveSceneView.camera;
            }
#endif

            if (Application.isPlaying)
            {
                if (m_Camera == null)
                    m_Camera = Camera.main;
            }

            if (m_Camera == null)
                return;

            // 视锥范围外的flare不参与射线检测
            if (CalculateOffScreen(m_Camera))
                return;

            RaycastHit hit;

            Vector3 direction = m_Camera.transform.position - transform.position;
            if (Physics.Raycast(transform.position, direction, out hit, direction.magnitude, m_Layer))
            {
                m_OcclusionValue = 0;
#if UNITY_EDITOR
                // Debug.DrawRay(transform.position, direction, Color.red);
                m_OcclusionObject = hit.collider.gameObject;
#endif
            }
            else
            {
                m_OcclusionValue = 1;

#if UNITY_EDITOR
                // Debug.DrawRay(transform.position, direction);
                m_OcclusionObject = null;
#endif
            }

            m_OcclusionIntensity = Mathf.Lerp(m_OcclusionIntensity, m_OcclusionValue, Time.deltaTime * m_OcclusionIntensitySpeed);
            m_OcclusionScale = Mathf.Lerp(m_OcclusionScale, m_OcclusionValue, Time.deltaTime * m_OcclusionScaleSpeed);

            if (m_LensFlare == null)
                m_LensFlare = GetComponent<LensFlareComponentSRP>();

            // m_LensFlare.SetOcclusionMulti(m_OcclusionIntensity, m_OcclusionScale);
        }
    }
}
