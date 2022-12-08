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
        public GPUInstancerPrototype prototype;

        // Mesh - Material - LOD info
        public List<GPUInstancerPrototypeLOD> instanceLODs;
        public GPUInstancerPrototypeLOD instanceData;
        public Bounds instanceBounds;
        public float[] lodSizes = new float[] {
            1000, 1000, 1000, 1000,
            1000, 1000, 1000, 1000,
            1000, 1000, 1000, 1000,
            1000, 1000, 1000, 1000 };
        public float lodBiasApplied = -1;

        // Instance Data
        public NativeArray<Matrix4x4> instanceDataNativeArray;

        // Currently instanced count
        public int instanceCount;
        // Buffer size
        public int bufferSize;

        // Buffers Data
        public ComputeBuffer transformationMatrixVisibilityBuffer;
        public ComputeBuffer argsBuffer; // for multiple material (submesh) rendering
        public ComputeBuffer instanceLODDataBuffer; // for storing LOD data
        public uint[] args;


        public GPUInstancerRuntimeData(GPUInstancerPrototype prototype)
        {
            this.prototype = prototype;
        }

        public virtual void InitializeData()
        {
        }

        public virtual void ReleaseBuffers()
        {
            if (instanceDataNativeArray.IsCreated)
                instanceDataNativeArray.Dispose();
        }

        #region AddLodAndRenderer

        /// <summary>
        /// Registers an LOD to the prototype. LODs contain the renderers for instance prototypes,
        /// so even if no LOD is being used, the prototype must be registered as LOD0 using this method.
        /// </summary>
        /// <param name="screenRelativeTransitionHeight">if not defined, will default to 0</param>
        public virtual void AddLod(float screenRelativeTransitionHeight = -1, bool excludeBounds = false)
        {
            if (instanceLODs == null)
                instanceLODs = new List<GPUInstancerPrototypeLOD>();

            GPUInstancerPrototypeLOD instanceLOD = new GPUInstancerPrototypeLOD();
            instanceLOD.excludeBounds = excludeBounds;
            instanceData = instanceLOD;
            instanceLODs.Add(instanceLOD);

            // Ensure the LOD will render if this is the first LOD and lodDistance is not set.
            if (instanceLODs.Count == 1 && screenRelativeTransitionHeight < 0f)
                lodSizes[0] = 0;

            // Do not modify the lodDistances vector if LOD distance is not supplied.
            if (screenRelativeTransitionHeight < 0f)
                return;

            if (lodBiasApplied == -1)
                lodBiasApplied = QualitySettings.lodBias;

            int lodIndex = (instanceLODs.Count - 1) * 4;
            if (instanceLODs.Count > 4)
                lodIndex = (instanceLODs.Count - 5) * 4 + 1;

            float lodSize = screenRelativeTransitionHeight / lodBiasApplied;
            lodSizes[lodIndex] = lodSize;

        }

        /// <summary>
        /// Adds a renderer to an LOD. Renderers define the meshes and materials to render for a given instance prototype LOD.
        /// </summary>
        /// <param name="lod">The LOD to add this renderer to. LOD indices start from 0.</param>
        /// <param name="mesh">The mesh that this renderer will use.</param>
        /// <param name="materials">The list of materials that this renderer will use (must be GPU Instancer compatible materials)</param>
        /// <param name="transformOffset">The transformation matrix that represents a change in position, rotation and scale 
        /// for this renderer as an offset from the instance prototype. This matrix will be applied to the prototype instance 
        /// matrix for final rendering calculations in the shader. Use Matrix4x4.Identity if no offset is desired.</param>
        public virtual void AddRenderer(int lod, Mesh mesh, List<Material> materials, Matrix4x4 transformOffset, MaterialPropertyBlock mpb, bool castShadows,
            int layer = 0, Renderer rendererRef = null, bool receiveShadows = true)
        {

            if (instanceLODs == null || instanceLODs.Count <= lod || instanceLODs[lod] == null)
            {
                Debug.LogError("Can't add renderer: Invalid LOD");
                return;
            }

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

            if (instanceLODs[lod].renderers == null)
                instanceLODs[lod].renderers = new List<GPUInstancerRenderer>();

            GPUInstancerRenderer renderer = new GPUInstancerRenderer
            {
                mesh = mesh,
                materials = materials,
                transformOffset = transformOffset,
                mpb = mpb,
                layer = layer,
                castShadows = castShadows,
                receiveShadows = receiveShadows,
                rendererRef = rendererRef,
                rendererRefName = rendererRef != null && rendererRef.gameObject != null ? rendererRef.gameObject.name : null
            };

            instanceLODs[lod].renderers.Add(renderer);
            CalculateBounds();
        }

        public virtual void CalculateBounds()
        {
            if (instanceLODs == null || instanceLODs.Count == 0 || instanceLODs[0].renderers == null ||
                instanceLODs[0].renderers.Count == 0)
                return;

            Bounds rendererBounds;
            for (int lod = 0; lod < instanceLODs.Count; lod++)
            {
                if (instanceLODs[lod].excludeBounds)
                    continue;

                for (int r = 0; r < instanceLODs[lod].renderers.Count; r++)
                {
                    rendererBounds = new Bounds(instanceLODs[lod].renderers[r].mesh.bounds.center + (Vector3)instanceLODs[lod].renderers[r].transformOffset.GetColumn(3),
                        new Vector3(
                        instanceLODs[lod].renderers[r].mesh.bounds.size.x * instanceLODs[lod].renderers[r].transformOffset.GetRow(0).magnitude,
                        instanceLODs[lod].renderers[r].mesh.bounds.size.y * instanceLODs[lod].renderers[r].transformOffset.GetRow(1).magnitude,
                        instanceLODs[lod].renderers[r].mesh.bounds.size.z * instanceLODs[lod].renderers[r].transformOffset.GetRow(2).magnitude));
                    if (lod == 0 && r == 0)
                    {
                        instanceBounds = rendererBounds;
                        continue;
                    }
                    instanceBounds.Encapsulate(rendererBounds);

                    //Vector3[] verts = instanceLODs[lod].renderers[r].mesh.vertices;
                    //for (var v = 0; v < verts.Length; v++)
                    //    instanceBounds.Encapsulate(verts[v]);
                }
            }

            instanceBounds.size += prototype.boundsOffset;
        }

        #endregion AddLodAndRenderer

        #region CreateRenderersFromGameObject

        /// <summary>
        /// Generates instancing renderer data for a given GameObject, at the first LOD level.
        /// </summary>
        public virtual bool CreateRenderersFromGameObject(GPUInstancerPrototype prototype)
        {
            if (prototype.prefabObject == null)
                return false;


            if (instanceLODs == null || instanceLODs.Count == 0)
                AddLod();
            return CreateRenderersFromMeshRenderers(0, prototype);

        }



        /// <summary>
        /// Generates instancing renderer data for a given protoype from its Mesh renderers at the given LOD level.
        /// </summary>
        /// <param name="lod">Which LOD level to generate renderers in</param>
        /// <param name="prototype">GPU Instancer Prototype</param>
        /// <param name="gpuiSettings">GPU Instancer settings to find appropriate shader for materials</param>
        /// <returns></returns>
        public virtual bool CreateRenderersFromMeshRenderers(int lod, GPUInstancerPrototype prototype)
        {
            if (instanceLODs == null || instanceLODs.Count <= lod || instanceLODs[lod] == null)
            {
                Debug.LogError("Can't create renderer(s): Invalid LOD");
                return false;
            }

            if (!prototype.prefabObject)
            {
                Debug.LogError("Can't create renderer(s): reference GameObject is null");
                return false;
            }

            List<MeshRenderer> meshRenderers = new List<MeshRenderer>();
            GetMeshRenderersOfTransform(prototype.prefabObject.transform, meshRenderers);

            if (meshRenderers == null || meshRenderers.Count == 0)
            {
                Debug.LogError("Can't create renderer(s): no MeshRenderers found in the reference GameObject <" + prototype.prefabObject.name +
                        "> or any of its children");
                return false;
            }

            foreach (MeshRenderer meshRenderer in meshRenderers)
            {
                if (meshRenderer.GetComponent<MeshFilter>() == null)
                {
                    Debug.LogWarning("MeshRenderer with no MeshFilter found on GameObject <" + prototype.prefabObject.name +
                        "> (Child: <" + meshRenderer.gameObject + ">). Are you missing a component?");
                    continue;
                }

                List<Material> instanceMaterials = new List<Material>();

                for (int m = 0; m < meshRenderer.sharedMaterials.Length; m++)
                {
                    instanceMaterials.Add(GPUInstancerConstants.gpuiSettings.shaderBindings.GetInstancedMaterial(meshRenderer.sharedMaterials[m]));
                }

                Matrix4x4 transformOffset = Matrix4x4.identity;
                Transform currentTransform = meshRenderer.gameObject.transform;
                while (currentTransform != prototype.prefabObject.transform)
                {
                    transformOffset = Matrix4x4.TRS(currentTransform.localPosition, currentTransform.localRotation, currentTransform.localScale) * transformOffset;
                    currentTransform = currentTransform.parent;
                }

                MaterialPropertyBlock mpb = new MaterialPropertyBlock();
                meshRenderer.GetPropertyBlock(mpb);

                AddRenderer(lod, meshRenderer.GetComponent<MeshFilter>().sharedMesh, instanceMaterials, transformOffset, mpb,
                    meshRenderer.shadowCastingMode != UnityEngine.Rendering.ShadowCastingMode.Off, meshRenderer.gameObject.layer, meshRenderer, meshRenderer.receiveShadows);
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

    public class GPUInstancerPrototypeLOD
    {
        // Prototype Data
        public List<GPUInstancerRenderer> renderers; // support for multiple mesh renderers
        // Buffers Data
        public ComputeBuffer transformationMatrixAppendBuffer;
        public ComputeBuffer shadowAppendBuffer;
        public bool excludeBounds;

        public RenderTexture transformationMatrixAppendTexture;
        public RenderTexture shadowAppendTexture;

        public int argsBufferOffset { get { return renderers == null || renderers.Count == 0 ? -1 : renderers[0].argsBufferOffset; } }
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
        public Renderer rendererRef;
        public string rendererRefName;
    }
}
