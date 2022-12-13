using System.Collections;
using System.Collections.Generic;
using Sirenix.OdinInspector;
using Unity.Collections;
using Unity.Jobs;
using UnityEngine;
#if UNITY_EDITOR
using UnityEditor;
#endif

namespace Inutan
{
    //临时使用的植被批量渲染
    public class GrassRenderer : MonoBehaviour
    {
        // [OnValueChanged("OnModeChanged")]
        // public Mode mode;
        [OnValueChanged("OnEnableFrustumCulling")]
        public bool enableFrustumCulling = true;
        [MinMaxSlider(0, 5000)]
        [OnValueChanged("OnShowRangeChanged")]
        public Vector2 showRange = new Vector2(0, 5000);
        public List<GameObject> grasseGOs = new List<GameObject>();

        GPUInstanceRenderer m_InstanceRenderer = new GPUInstanceRenderer();

        public void InitGameobject(GameObject target, int count)
        {
            for (int i = grasseGOs.Count - 1; i >= 0; i--)
            {
                GameObject.Destroy(grasseGOs[i]);
            }
            grasseGOs.Clear();

            int SizeX = 50, SizeY = 50;
            float delta = 2;

            for (int i = 0; i < count; i++)
            {
                int z = i / SizeX / SizeY;
                int y = (i - z * SizeX * SizeY) / SizeX;
                int x = (i - z * SizeX * SizeY) % SizeX;
                var go = GameObject.Instantiate(target);
                go.transform.position = new Vector3(delta * x, delta * z, delta * y);
                go.transform.localScale = Vector3.one;
                go.transform.localRotation = Quaternion.identity;
                grasseGOs.Add(go);
            }

            m_InstanceRenderer.ClearInstanceProxy();
            for (int i = 0; i < grasseGOs.Count; i++)
            {
                m_InstanceRenderer.RegisterInstanceProxy(grasseGOs[i]);
            }
            m_InstanceRenderer.Init(target);
            m_InstanceRenderer.showRange = showRange;
            m_InstanceRenderer.enableFrustumCulling = enableFrustumCulling;
            // m_InstanceRenderer.SetMode(mode);
            // mode = m_InstanceRenderer.Mode;
        }

        private void LateUpdate()
        {
            m_InstanceRenderer?.Render();
        }

        private void OnEnable()
        {
            m_InstanceRenderer?.SetRenderersEnabled(false);
        }

        private void OnDisable()
        {
            m_InstanceRenderer?.SetRenderersEnabled(true);
        }

        private void OnDestroy()
        {
            m_InstanceRenderer?.Release();
        }

        void OnModeChanged()
        {
            // SetMode(mode);
        }

        void OnEnableFrustumCulling()
        {
            m_InstanceRenderer.enableFrustumCulling = enableFrustumCulling;
        }

        void OnShowRangeChanged()
        {
            m_InstanceRenderer.showRange = showRange;
        }

#if UNITY_EDITOR
        private void OnDrawGizmos()
        {
            var camera = Camera.main;
            Vector3 center = camera.transform.position;
            Gizmos.color = Color.red;
            Gizmos.DrawWireSphere(center, showRange.x);
            Gizmos.color = Color.green;
            Gizmos.DrawWireSphere(center, showRange.y);
            Handles.color = new Color(1, 0, 0, 0.3f);
            Vector3 from = camera.transform.forward;
            float degree = camera.fieldOfView * camera.aspect;
            Quaternion q = Quaternion.AngleAxis(-degree * 0.5f, camera.transform.up);
            from = q * from;
            Handles.DrawSolidArc(center, camera.transform.up, from, degree, showRange.y);
        }
#endif

    }
}
