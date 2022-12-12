using UnityEngine;
using System.Collections.Generic;
using System.Linq;
using UnityEngine.Rendering;
using System;
using Unity.Collections;
using UnityEngine.Jobs;
using Unity.Jobs;

namespace GPUInstancer
{
    public class GPUInstancerRuntimeData
    {
        public GameObject prototype;
        public List<GPUInstancerRenderer> renderers = new List<GPUInstancerRenderer>();
        public Bounds instanceBounds;

        // Instance Data
        public NativeArray<Matrix4x4> instanceDataNativeArray;

        // Currently instanced count
        public int instanceCount;
        // Buffer size
        public int bufferSize;

        // Buffers Data
        public ComputeBuffer transformationMatrixVisibilityBuffer;
        public ComputeBuffer argsBuffer; // for multiple material (submesh) rendering
        public uint[] args;


        public GPUInstancerRuntimeData(GameObject prototype)
        {
            this.prototype = prototype;
        }

        public virtual void ReleaseBuffers()
        {
            if (instanceDataNativeArray.IsCreated)
                instanceDataNativeArray.Dispose();
        }

        #region AddLodAndRenderer

        public virtual void AddRenderer(Mesh mesh, List<Material> materials, Matrix4x4 transformOffset, MaterialPropertyBlock mpb, bool castShadows, int layer = 0, bool receiveShadows = true)
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
            CalculateBounds();
        }

        public virtual void CalculateBounds()
        {
            if (renderers == null || renderers.Count == 0)
                return;

            Bounds rendererBounds;

            for (int r = 0; r < renderers.Count; r++)
            {
                rendererBounds = new Bounds(renderers[r].mesh.bounds.center + (Vector3)renderers[r].transformOffset.GetColumn(3),
                    new Vector3(
                    renderers[r].mesh.bounds.size.x * renderers[r].transformOffset.GetRow(0).magnitude,
                    renderers[r].mesh.bounds.size.y * renderers[r].transformOffset.GetRow(1).magnitude,
                    renderers[r].mesh.bounds.size.z * renderers[r].transformOffset.GetRow(2).magnitude));
                if (r == 0)
                {
                    instanceBounds = rendererBounds;
                    continue;
                }
                instanceBounds.Encapsulate(rendererBounds);
            }
        }

        #endregion AddLodAndRenderer

        #region CreateRenderersFromGameObject

        /// <summary>
        /// Generates instancing renderer data for a given GameObject, at the first LOD level.
        /// </summary>
        public virtual bool CreateRenderersFromGameObject(GameObject prefabObject)
        {
            if (prefabObject == null)
            {
                Debug.LogError("Can't create renderer(s): reference GameObject is null");
                return false;
            }

            List<MeshRenderer> meshRenderers = new List<MeshRenderer>();
            GetMeshRenderersOfTransform(prefabObject.transform, meshRenderers);

            if (meshRenderers.Count == 0)
            {
                Debug.LogError("Can't create renderer(s): no MeshRenderers found in the reference GameObject <" + prefabObject.name +
                        "> or any of its children");
                return false;
            }

            foreach (MeshRenderer meshRenderer in meshRenderers)
            {
                if (meshRenderer.GetComponent<MeshFilter>() == null)
                {
                    Debug.LogWarning("MeshRenderer with no MeshFilter found on GameObject <" + prefabObject.name +
                        "> (Child: <" + meshRenderer.gameObject + ">). Are you missing a component?");
                    continue;
                }

                List<Material> instanceMaterials = new List<Material>();

                for (int m = 0; m < meshRenderer.sharedMaterials.Length; m++)
                {
                    instanceMaterials.Add(GPUInstancerShaderBindings.GetInstancedMaterial(meshRenderer.sharedMaterials[m]));
                }

                Matrix4x4 transformOffset = Matrix4x4.identity;
                Transform currentTransform = meshRenderer.gameObject.transform;
                while (currentTransform != prefabObject.transform)
                {
                    transformOffset = Matrix4x4.TRS(currentTransform.localPosition, currentTransform.localRotation, currentTransform.localScale) * transformOffset;
                    currentTransform = currentTransform.parent;
                }

                MaterialPropertyBlock mpb = new MaterialPropertyBlock();
                meshRenderer.GetPropertyBlock(mpb);

                AddRenderer(meshRenderer.GetComponent<MeshFilter>().sharedMesh,
                    instanceMaterials,
                    transformOffset,
                    mpb,
                    meshRenderer.shadowCastingMode != UnityEngine.Rendering.ShadowCastingMode.Off,
                    meshRenderer.gameObject.layer,
                    meshRenderer.receiveShadows);
            }

            return true;
        }

        public virtual void GetMeshRenderersOfTransform(Transform objectTransform, List<MeshRenderer> meshRenderers)
        {
            MeshRenderer meshRenderer = objectTransform.GetComponent<MeshRenderer>();
            if (meshRenderer != null)
                meshRenderers.Add(meshRenderer);

            Transform childTransform;
            for (int i = 0; i < objectTransform.childCount; i++)
            {
                childTransform = objectTransform.GetChild(i);
                if (childTransform.GetComponent<GPUInstancerPrefab>() != null)
                    continue;
                GetMeshRenderersOfTransform(childTransform, meshRenderers);
            }
        }

        #endregion CreateRenderersFromGameObject
    }

    public class GPUInstancerRenderer
    {
        public Mesh mesh;
        public List<Material> materials; // support for multiple submeshes.
        public Matrix4x4 transformOffset;
        public int argsBufferOffset;
        public MaterialPropertyBlock mpb;
        public int layer;
        public bool castShadows;
        public bool receiveShadows;
    }
}
