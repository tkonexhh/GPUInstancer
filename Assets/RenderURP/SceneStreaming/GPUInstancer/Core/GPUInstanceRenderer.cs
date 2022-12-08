using System.Collections.Generic;
using Unity.Collections;
using Unity.Jobs;
using UnityEngine;
using UnityEngine.Jobs;

namespace Inutan
{
    public enum Mode
    {
        GameObject,
        Instance,
        Indirect,
    }

    public class GPUInstanceRenderer
    {
        public bool enableFrustumCulling = true;//开启视锥剔除
        public bool enableOcclusionCulling = false;//开启遮挡剔除 TODO
        public bool useJobs = true;//使用Jobs来代替ComputeShader


        public Mode Mode { get; private set; }
        public GameObject renderTarget { get; private set; }//渲染
        public int totalCount => m_Locations.Count;
        public Vector2 showRange = new Vector2(0, 120);//显示范围 x:min y:max

        List<Matrix4x4> m_Locations = new List<Matrix4x4>();//收集到的全部坐标信息
        List<GameObject> m_SceneGameObjects = new List<GameObject>();
        //最终渲染用到的数据
        NativeArray<Matrix4x4> m_LocationNativeArray;//全部的坐标
        NativeArray<Matrix4x4> m_CulledLocationNativeArray;//job剔除后的剩余坐标

        InstanceStrategy m_InstanceStrategy;
        bool m_ShowGameObject;

        public void RegisterInstanceProxy(GameObject gameObject)
        {
            gameObject.SetActive(false);
            m_SceneGameObjects.Add(gameObject);
            var location = gameObject.transform.localToWorldMatrix;
            m_Locations.Add(location);
        }

        public void RemoveInstanceProxy(GameObject gameObject)
        {
            if (!m_SceneGameObjects.Contains(gameObject))
                return;

            int index = m_SceneGameObjects.IndexOf(gameObject);
            m_Locations.RemoveAt(index);
            m_SceneGameObjects.RemoveAt(index);
            RecreateNativeArray();
            gameObject.SetActive(true);
        }

        public void ClearInstanceProxy()
        {
            for (int i = 0; i < m_SceneGameObjects.Count; i++)
            {
                m_SceneGameObjects[i].SetActive(true);
            }
            m_SceneGameObjects.Clear();
            m_Locations.Clear();
            RecreateNativeArray();
        }

        public void Init(GameObject renderTarget)
        {
            this.renderTarget = renderTarget;
            SetMode(Mode.Indirect);
        }

        public void SetMode(Mode mode)
        {
            if (Mode == mode)
                return;

            Mode = mode;
            if (Mode == Mode.GameObject)
            {
                if (!m_ShowGameObject)
                    ShowGameObject();
                Release();
            }
            else
            {
                if (m_ShowGameObject)
                    HideGameObject();

                m_InstanceStrategy?.Release();

                if (Mode == Mode.Indirect)
                    m_InstanceStrategy = new InstanceStrategy_Indirect();
                else
                    m_InstanceStrategy = new InstanceStrategy_Instanced();

                m_InstanceStrategy.CreateRenderersFromGameObject(renderTarget);
                RecreateNativeArray();
            }
        }

        void RecreateNativeArray()
        {
            if (!m_LocationNativeArray.IsCreated || m_LocationNativeArray.Length != totalCount)
            {
                if (m_LocationNativeArray.IsCreated)
                    m_LocationNativeArray.Dispose();

                m_LocationNativeArray = new NativeArray<Matrix4x4>(totalCount, Allocator.Persistent);
            }

            for (int i = 0; i < totalCount; i++)
            {
                m_LocationNativeArray[i] = m_Locations[i];
            }

            if (m_InstanceStrategy != null)
                m_InstanceStrategy.maxCount = totalCount;
        }

        public void Render()
        {
            if (Mode == Mode.GameObject)
                return;

            if (totalCount <= 0)
                return;

            if (enableFrustumCulling && useJobs)
            {
                //使用jobs来算视锥剔除
                //两种剔除方式 一种简单剔除 适合草这样的物体 另一种完整剔除 适合普通物体 获取到bounds

                //TODO 如果相机不运动的话 也不需要更新
                GPUInstanceCameraData cameraData = new GPUInstanceCameraData();
                var camera = Camera.main;
                cameraData.position = camera.transform.position;
                cameraData.forward = camera.transform.forward;
                float fovCos = Mathf.Cos(camera.fieldOfView * camera.aspect * Mathf.Deg2Rad);
                cameraData.sqrFovCos = fovCos * fovCos - 0.05f;

                var culledLocationNativeQueue = new NativeQueue<Matrix4x4>(Allocator.TempJob);
                culledLocationNativeQueue.Clear();
                GPUInstanceCullingJob cullJob = new GPUInstanceCullingJob()
                {
                    allLocalToWorldNativeArray = m_LocationNativeArray,
                    cameraData = cameraData,
                    showRange = showRange,
                    finalVisibleNativeArray = culledLocationNativeQueue.AsParallelWriter(),
                };

                JobHandle shadowCullHandle = cullJob.Schedule(totalCount, 64);
                shadowCullHandle.Complete();

                int count = culledLocationNativeQueue.Count;

                //需要重新分配
                if (!m_CulledLocationNativeArray.IsCreated || m_CulledLocationNativeArray.Length != count)
                {
                    if (m_CulledLocationNativeArray.IsCreated)
                        m_CulledLocationNativeArray.Dispose();

                    m_CulledLocationNativeArray = new NativeArray<Matrix4x4>(count, Allocator.Persistent);
                }

                for (int i = 0; i < count; i++)
                {
                    m_CulledLocationNativeArray[i] = culledLocationNativeQueue.Dequeue();
                }
                culledLocationNativeQueue.Dispose();

                m_InstanceStrategy.localToWorldMatrixListNativeArray = m_CulledLocationNativeArray;

            }
            else
            {
                if (m_InstanceStrategy.localToWorldMatrixListNativeArray.Length != m_LocationNativeArray.Length)
                    m_InstanceStrategy.localToWorldMatrixListNativeArray = m_LocationNativeArray;//不用剔除 直接等于原始坐标信息
            }

            m_InstanceStrategy.Render();

            if (m_ShowGameObject)
                HideGameObject();

        }

        public void Release()
        {
            m_InstanceStrategy?.Release();

            if (m_LocationNativeArray.IsCreated)
                m_LocationNativeArray.Dispose();

            if (m_CulledLocationNativeArray.IsCreated)
                m_CulledLocationNativeArray.Dispose();
        }

        void ShowGameObject()
        {
            for (int i = 0; i < m_SceneGameObjects.Count; i++)
            {
                m_SceneGameObjects[i].SetActive(true);
            }
            m_ShowGameObject = true;
        }

        void HideGameObject()
        {
            for (int i = 0; i < m_SceneGameObjects.Count; i++)
            {
                m_SceneGameObjects[i].SetActive(false);
            }
            m_ShowGameObject = false;
        }
    }
}
