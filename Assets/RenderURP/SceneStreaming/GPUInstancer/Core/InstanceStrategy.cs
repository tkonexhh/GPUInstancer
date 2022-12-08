using System.Collections;
using System.Collections.Generic;
using Unity.Collections;
using UnityEngine;

namespace Inutan
{
    public abstract class InstanceStrategy
    {
        protected List<GPUInstancerRenderer> renderers = new List<GPUInstancerRenderer>();
        public NativeArray<Matrix4x4> localToWorldMatrixListNativeArray;
        public int renderCount => localToWorldMatrixListNativeArray.Length;
        public int maxCount;//最大数量用于一些变量刷新


        public virtual void Init() { }
        public abstract void Render();
        public virtual void Release()
        {
            renderers.Clear();
            maxCount = 0;
        }

        /// <summary>
        /// 获取批量渲染实际使用的材质
        /// </summary>
        /// <param name="material"></param>
        /// <returns></returns>
        public abstract Material GetDrawMaterial(Material material);


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
                    instanceMaterials.Add(GetDrawMaterial(meshRenderer.sharedMaterials[m]));
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


}
