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
        public bool enableFrustumCulling = false;//开启视锥剔除
        public bool enableOcclusionCulling = false;//开启遮挡剔除 TODO
        public bool useJobs = true;//使用Jobs来代替ComputeShader

        public List<GPUInstancerRenderer> renderers = new List<GPUInstancerRenderer>();
        public Mode Mode { get; private set; }
        public GameObject renderTarget { get; private set; }//渲染
        public int instanceCount => m_Locations.Count;
        public Vector2 showRange = new Vector2(0, 5000);//显示范围 x:min y:max

        List<Matrix4x4> m_Locations = new List<Matrix4x4>();//收集到的全部坐标信息
        List<GameObject> m_SceneGameObjects = new List<GameObject>();
        //最终渲染用到的数据
        NativeArray<Matrix4x4> m_LocationNativeArray;//全部的坐标
        NativeArray<Matrix4x4> m_CulledLocationNativeArray;//job剔除后的剩余坐标

        InstanceStrategy m_InstanceStrategy;
        bool m_ShowGameObject;

        public void RegisterInstanceProxy(GameObject gameObject)
        {
            if (gameObject == null)
                return;
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
        }

        public void ClearInstanceProxy()
        {
            ShowGameObject();
            m_SceneGameObjects.Clear();
            m_Locations.Clear();
        }

        public void Init(GameObject renderTarget)
        {
            if (renderTarget == null)
            {
                Debug.LogError("当前批量渲染的物体为null");
                return;
            }

            this.renderTarget = renderTarget;
            CreateRenderersFromGameObject(renderTarget);
            SetMode(Mode.Indirect);
            RecreateNativeArray();
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
            }
        }

        void RecreateNativeArray()
        {
            if (!m_LocationNativeArray.IsCreated || m_LocationNativeArray.Length != instanceCount)
            {
                if (m_LocationNativeArray.IsCreated)
                    m_LocationNativeArray.Dispose();

                m_LocationNativeArray = new NativeArray<Matrix4x4>(instanceCount, Allocator.Persistent);
            }

            for (int i = 0; i < instanceCount; i++)
            {
                m_LocationNativeArray[i] = m_Locations[i];
            }

        }

        public void Render()
        {
            if (Mode == Mode.GameObject)
                return;

            if (instanceCount <= 0)
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

                JobHandle shadowCullHandle = cullJob.Schedule(instanceCount, 64);
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

                if (m_CulledLocationNativeArray.Length > 0)
                    m_InstanceStrategy.Render(renderers, m_CulledLocationNativeArray);

            }
            else
            {
                if (m_LocationNativeArray.Length > 0)
                    m_InstanceStrategy.Render(renderers, m_LocationNativeArray);
            }
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
            SetRenderersEnabled(true);
            m_ShowGameObject = true;
        }

        void HideGameObject()
        {
            SetRenderersEnabled(false);
            m_ShowGameObject = false;
        }

        void SetRenderersEnabled(bool enable)
        {
            for (int i = 0; i < m_SceneGameObjects.Count; i++)
            {
                var meshRenderers = m_SceneGameObjects[i].GetComponentsInChildren<MeshRenderer>();
                if (meshRenderers != null && meshRenderers.Length > 0)
                {
                    for (int mr = 0; mr < meshRenderers.Length; mr++)
                    {
                        meshRenderers[mr].enabled = enable;
                    }
                }
            }
        }

        #region CreateRenderersFromGameObject

        public bool CreateRenderersFromGameObject(GameObject target)
        {
            renderers.Clear();

            List<MeshRenderer> meshRenderers = new List<MeshRenderer>();
            GetMeshRenderersOfTransform(target.transform, meshRenderers);

            if (meshRenderers == null || meshRenderers.Count == 0)
            {
                Debug.LogError("Can't create renderer(s): no MeshRenderers found in the reference GameObject <" + target.name + "> or any of its children");
                return false;
            }

            foreach (MeshRenderer meshRenderer in meshRenderers)
            {
                var meshFilter = meshRenderer.GetComponent<MeshFilter>();
                if (meshFilter == null)
                {
                    Debug.LogWarning("MeshRenderer with no MeshFilter found on GameObject <" + target.name + "> (Child: <" + meshRenderer.gameObject + ">). Are you missing a component?");
                    continue;
                }

                Matrix4x4 transformOffset = Matrix4x4.identity;
                Transform currentTransform = meshRenderer.gameObject.transform;
                while (currentTransform != target.transform)
                {
                    transformOffset = Matrix4x4.TRS(currentTransform.localPosition, currentTransform.localRotation, currentTransform.localScale) * transformOffset;
                    currentTransform = currentTransform.parent;
                }

                List<Material> instanceMaterials = new List<Material>();
                for (int m = 0; m < meshRenderer.sharedMaterials.Length; m++)
                {
                    instanceMaterials.Add(GPUInstancerShaderBindings.GetInstancedMaterial(meshRenderer.sharedMaterials[m]));
                }

                MaterialPropertyBlock mpb = new MaterialPropertyBlock();
                meshRenderer.GetPropertyBlock(mpb);

                bool castShadow = meshRenderer.shadowCastingMode != UnityEngine.Rendering.ShadowCastingMode.Off;
                int layer = meshRenderer.gameObject.layer;
                AddRenderer(meshFilter.sharedMesh, instanceMaterials, transformOffset, mpb, castShadow, layer, meshRenderer.receiveShadows);
            }

            return true;
        }

        void GetMeshRenderersOfTransform(Transform objectTransform, List<MeshRenderer> meshRenderers)
        {
            MeshRenderer meshRenderer = objectTransform.GetComponent<MeshRenderer>();
            if (meshRenderer != null)
                meshRenderers.Add(meshRenderer);

            Transform childTransform;
            for (int i = 0; i < objectTransform.childCount; i++)
            {
                childTransform = objectTransform.GetChild(i);
                GetMeshRenderersOfTransform(childTransform, meshRenderers);
            }
        }

        public void AddRenderer(Mesh mesh, List<Material> materials, Matrix4x4 transformOffset, MaterialPropertyBlock mpb, bool castShadows, int layer = 0, bool receiveShadows = true)
        {
            if (mesh == null)
            {
                Debug.LogError("Can't add renderer: mesh is null. Make sure that all the MeshFilters on the objects has a mesh assigned.");
                return;
            }

            if (materials == null || materials.Count == 0)
            {
                Debug.LogError("Can't add renderer: no materials. Make sure that all the MeshRenderers have their materials assigned.");
                return;
            }

            GPUInstancerRenderer renderer = new GPUInstancerRenderer
            {
                mesh = mesh,
                materials = materials,
                transformOffset = transformOffset,
                mpb = mpb,
                layer = layer,
                castShadows = castShadows,
                receiveShadows = receiveShadows,
            };
            renderers.Add(renderer);
        }
    }

    #endregion

}
