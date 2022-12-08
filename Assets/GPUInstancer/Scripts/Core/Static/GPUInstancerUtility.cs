using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Events;
using Unity.Collections;
using UnityEngine.Jobs;
#if UNITY_EDITOR
using UnityEditor;
#endif

namespace GPUInstancer
{
    public static class GPUInstancerUtility
    {
        #region GPU Instancing

        public static Texture2D dummyHiZTex;
        public static GPUIMatrixHandlingType matrixHandlingType;

        /// <summary>
        /// Initializes GPU buffer related data for the instance prototypes. Instance transformation matrices must be generated before this.
        /// </summary>
        public static void InitializeGPUBuffers<T>(List<T> runtimeDataList) where T : GPUInstancerRuntimeData
        {
            if (runtimeDataList == null || runtimeDataList.Count == 0)
                return;

            for (int i = 0; i < runtimeDataList.Count; i++)
            {
                InitializeGPUBuffer(runtimeDataList[i]);
            }
        }

        public static void InitializeGPUBuffer<T>(T runtimeData) where T : GPUInstancerRuntimeData
        {
            if (runtimeData == null || runtimeData.bufferSize == 0)
                return;

            if (runtimeData.instanceLODs == null || runtimeData.instanceLODs.Count == 0)
            {
                Debug.LogError("instance prototype with an empty LOD list detected. There must be at least one LOD defined per instance prototype.");
                return;
            }

            if (dummyHiZTex == null)
                dummyHiZTex = new Texture2D(1, 1);

            #region Set Visibility Buffer
            // Setup the visibility compute buffer
            if (runtimeData.transformationMatrixVisibilityBuffer == null || runtimeData.transformationMatrixVisibilityBuffer.count != runtimeData.bufferSize)
            {
                if (runtimeData.transformationMatrixVisibilityBuffer != null)
                    runtimeData.transformationMatrixVisibilityBuffer.Release();
                runtimeData.transformationMatrixVisibilityBuffer = new ComputeBuffer(runtimeData.bufferSize, GPUInstancerConstants.STRIDE_SIZE_MATRIX4X4);
                if (runtimeData.instanceDataNativeArray.IsCreated)
                    runtimeData.transformationMatrixVisibilityBuffer.SetData(runtimeData.instanceDataNativeArray);
            }
            #endregion Set Visibility Buffer

            #region Set LOD Buffer
            // Setup the LOD buffer
            if (runtimeData.instanceLODDataBuffer == null || runtimeData.instanceLODDataBuffer.count != runtimeData.bufferSize)
            {
                if (runtimeData.instanceLODDataBuffer != null)
                    runtimeData.instanceLODDataBuffer.Release();

                runtimeData.instanceLODDataBuffer = new ComputeBuffer(runtimeData.bufferSize, GPUInstancerConstants.STRIDE_SIZE_FLOAT4);
            }
            #endregion Set LOD Buffer

            #region Set Args Buffer
            if (runtimeData.argsBuffer == null)
            {
                // Initialize indirect renderer buffer

                int totalSubMeshCount = 0;
                for (int i = 0; i < runtimeData.instanceLODs.Count; i++)
                {
                    for (int j = 0; j < runtimeData.instanceLODs[i].renderers.Count; j++)
                    {
                        totalSubMeshCount += runtimeData.instanceLODs[i].renderers[j].mesh.subMeshCount;
                    }
                }

                // Initialize indirect renderer buffer. First LOD's each renderer's all submeshes will be followed by second LOD's each renderer's submeshes and so on.
                runtimeData.args = new uint[5 * totalSubMeshCount];
                int argsLastIndex = 0;

                // Setup LOD Data:
                for (int lod = 0; lod < runtimeData.instanceLODs.Count; lod++)
                {
                    // setup LOD renderers:
                    for (int r = 0; r < runtimeData.instanceLODs[lod].renderers.Count; r++)
                    {
                        runtimeData.instanceLODs[lod].renderers[r].argsBufferOffset = argsLastIndex;
                        // Setup the indirect renderer buffer:
                        for (int j = 0; j < runtimeData.instanceLODs[lod].renderers[r].mesh.subMeshCount; j++)
                        {
                            runtimeData.args[argsLastIndex++] = runtimeData.instanceLODs[lod].renderers[r].mesh.GetIndexCount(j); // index count per instance
                            runtimeData.args[argsLastIndex++] = 0;// (uint)runtimeData.bufferSize;
                            runtimeData.args[argsLastIndex++] = runtimeData.instanceLODs[lod].renderers[r].mesh.GetIndexStart(j); // start index location
                            runtimeData.args[argsLastIndex++] = 0; // base vertex location
                            runtimeData.args[argsLastIndex++] = 0; // start instance location
                        }
                    }
                }

                if (runtimeData.args.Length > 0)
                {
                    runtimeData.argsBuffer = new ComputeBuffer(runtimeData.args.Length, sizeof(uint), ComputeBufferType.IndirectArguments);

                    runtimeData.argsBuffer.SetData(runtimeData.args);


                }
            }
            #endregion Set Args Buffer

            SetAppendBuffers(runtimeData);

            runtimeData.InitializeData();
        }

        #region Set Append Buffers Platform Dependent
        public static void SetAppendBuffers<T>(T runtimeData) where T : GPUInstancerRuntimeData
        {
            switch (matrixHandlingType)
            {
                case GPUIMatrixHandlingType.MatrixAppend:
                    SetAppendBuffersVulkan(runtimeData);
                    break;
                case GPUIMatrixHandlingType.CopyToTexture:
                    SetAppendBuffersGLES3(runtimeData);
                    break;
                default:
                    SetAppendBuffersDefault(runtimeData);
                    break;
            }
        }

        private static void SetAppendBuffersDefault<T>(T runtimeData) where T : GPUInstancerRuntimeData
        {
            int lod = 0;
            foreach (GPUInstancerPrototypeLOD gpuiLod in runtimeData.instanceLODs)
            {
                if (gpuiLod.transformationMatrixAppendBuffer == null || gpuiLod.transformationMatrixAppendBuffer.count != runtimeData.bufferSize)
                {
                    // Create the LOD append buffers. Each LOD has its own append buffer.
                    if (gpuiLod.transformationMatrixAppendBuffer != null)
                        gpuiLod.transformationMatrixAppendBuffer.Release();

                    gpuiLod.transformationMatrixAppendBuffer = new ComputeBuffer(runtimeData.bufferSize, GPUInstancerConstants.STRIDE_SIZE_INT, ComputeBufferType.Append);
                }

                foreach (GPUInstancerRenderer renderer in gpuiLod.renderers)
                {
                    // Setup instance LOD renderer material property block shader buffers with the append buffer
                    renderer.mpb.SetBuffer(GPUInstancerConstants.VisibilityKernelPoperties.TRANSFORMATION_MATRIX_BUFFER, gpuiLod.transformationMatrixAppendBuffer);
                    renderer.mpb.SetBuffer(GPUInstancerConstants.VisibilityKernelPoperties.INSTANCE_DATA_BUFFER, runtimeData.transformationMatrixVisibilityBuffer);
                    renderer.mpb.SetBuffer(GPUInstancerConstants.VisibilityKernelPoperties.INSTANCE_LOD_BUFFER, runtimeData.instanceLODDataBuffer);
                    renderer.mpb.SetMatrix(GPUInstancerConstants.VisibilityKernelPoperties.RENDERER_TRANSFORM_OFFSET, renderer.transformOffset);
                    renderer.mpb.SetFloat(GPUInstancerConstants.VisibilityKernelPoperties.BUFFER_PARAMETER_LOD_LEVEL, -1);



                    SetRenderingLayerMask(runtimeData, renderer);
                }
                lod++;
            }
        }

        private static void SetAppendBuffersVulkan<T>(T runtimeData) where T : GPUInstancerRuntimeData
        {
            foreach (GPUInstancerPrototypeLOD gpuiLod in runtimeData.instanceLODs)
            {
                if (gpuiLod.transformationMatrixAppendBuffer == null || gpuiLod.transformationMatrixAppendBuffer.count != runtimeData.bufferSize)
                {
                    // Create the LOD append buffers. Each LOD has its own append buffer.
                    if (gpuiLod.transformationMatrixAppendBuffer != null)
                        gpuiLod.transformationMatrixAppendBuffer.Release();

                    gpuiLod.transformationMatrixAppendBuffer = new ComputeBuffer(runtimeData.bufferSize, GPUInstancerConstants.STRIDE_SIZE_MATRIX4X4, ComputeBufferType.Append);
                }

                foreach (GPUInstancerRenderer renderer in gpuiLod.renderers)
                {
                    // Setup instance LOD renderer material property block shader buffers with the append buffer
                    renderer.mpb.SetBuffer(GPUInstancerConstants.VisibilityKernelPoperties.TRANSFORMATION_MATRIX_BUFFER, gpuiLod.transformationMatrixAppendBuffer);
                    renderer.mpb.SetMatrix(GPUInstancerConstants.VisibilityKernelPoperties.RENDERER_TRANSFORM_OFFSET, renderer.transformOffset);

                    SetRenderingLayerMask(runtimeData, renderer);
                }
            }
        }

        private static void SetAppendBuffersGLES3<T>(T runtimeData) where T : GPUInstancerRuntimeData
        {
            foreach (GPUInstancerPrototypeLOD gpuiLod in runtimeData.instanceLODs)
            {
                if (gpuiLod.transformationMatrixAppendBuffer == null || gpuiLod.transformationMatrixAppendBuffer.count != runtimeData.bufferSize)
                {
                    // Create the LOD append buffers. Each LOD has its own append buffer.
                    if (gpuiLod.transformationMatrixAppendBuffer != null)
                        gpuiLod.transformationMatrixAppendBuffer.Release();

                    gpuiLod.transformationMatrixAppendBuffer = new ComputeBuffer(runtimeData.bufferSize, GPUInstancerConstants.STRIDE_SIZE_INT, ComputeBufferType.Append);
                }
                if (gpuiLod.transformationMatrixAppendTexture == null || gpuiLod.transformationMatrixAppendTexture.width != runtimeData.bufferSize)
                {
                    DestroyObject(gpuiLod.transformationMatrixAppendTexture);

                    int rowCount = Mathf.CeilToInt(runtimeData.bufferSize / (float)GPUInstancerConstants.TEXTURE_MAX_SIZE);
                    gpuiLod.transformationMatrixAppendTexture = new RenderTexture(rowCount == 1 ? runtimeData.bufferSize : GPUInstancerConstants.TEXTURE_MAX_SIZE, 4 * rowCount, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear)
                    {
                        isPowerOfTwo = false,
                        enableRandomWrite = true,
                        filterMode = FilterMode.Point,
                        useMipMap = false,
                        autoGenerateMips = false
                    };
                    gpuiLod.transformationMatrixAppendTexture.Create();
                }

                foreach (GPUInstancerRenderer renderer in gpuiLod.renderers)
                {
                    // Setup instance LOD renderer material property block shader buffers with the append buffer
                    renderer.mpb.SetTexture(GPUInstancerConstants.BufferToTextureKernelPoperties.TRANSFORMATION_MATRIX_TEXTURE, gpuiLod.transformationMatrixAppendTexture);
                    renderer.mpb.SetMatrix(GPUInstancerConstants.VisibilityKernelPoperties.RENDERER_TRANSFORM_OFFSET, renderer.transformOffset);
                    renderer.mpb.SetFloat(GPUInstancerConstants.VisibilityKernelPoperties.BUFFER_PARAMETER_BUFFER_SIZE, runtimeData.bufferSize);
                    renderer.mpb.SetFloat(GPUInstancerConstants.VisibilityKernelPoperties.MAX_TEXTURE_SIZE, GPUInstancerConstants.TEXTURE_MAX_SIZE);

                    SetRenderingLayerMask(runtimeData, renderer);
                }
            }
        }

        private static void SetRenderingLayerMask<T>(T runtimeData, GPUInstancerRenderer renderer) where T : GPUInstancerRuntimeData
        {
            // Set Rendering Layer Mask
            if (!GPUInstancerConstants.gpuiSettings.IsStandardRenderPipeline() && renderer.rendererRef != null)
            {
                Vector4 renderingLayer = new Vector4(BitConverter.ToSingle(BitConverter.GetBytes(renderer.rendererRef.renderingLayerMask), 0), 0, 0, 0);
                renderer.mpb.SetVector(GPUInstancerConstants.VisibilityKernelPoperties.UNITY_RENDERING_LAYER, renderingLayer);

            }
        }
        #endregion Set Append Buffers Platform Dependent

        /// <summary>
        /// Indirectly renders matrices for all prototypes. 
        /// Transform matrices are sent to a compute shader which does culling operations and appends them to the GPU (Unlimited buffer size).
        /// All GPU buffers must be already initialized.
        /// </summary>
        public static void UpdateGPUBuffers<T>(ComputeShader cameraComputeShader, int[] cameraComputeKernelIDs,
            ComputeShader visibilityComputeShader, int[] instanceVisibilityComputeKernelIDs, List<T> runtimeDataList,
            GPUInstancerCameraData cameraData, bool isManagerFrustumCulling, bool isManagerOcclusionCulling, bool showRenderedAmount, bool isInitial)
            where T : GPUInstancerRuntimeData
        {
            if (runtimeDataList == null)
                return;

            for (int i = 0; i < runtimeDataList.Count; i++)
            {
                UpdateGPUBuffer(cameraComputeShader, cameraComputeKernelIDs, visibilityComputeShader, instanceVisibilityComputeKernelIDs,
                    runtimeDataList[i], cameraData, isManagerFrustumCulling, showRenderedAmount, isInitial);
            }
        }

        /// <summary>
        /// Indirectly renders matrices for all prototypes. 
        /// Transform matrices are sent to a compute shader which does culling operations and appends them to the GPU (Unlimited buffer size).
        /// All GPU buffers must be already initialized.
        /// </summary>
        public static void UpdateGPUBuffer<T>(ComputeShader cameraComputeShader, int[] cameraComputeKernelIDs,
            ComputeShader visibilityComputeShader, int[] instanceVisibilityComputeKernelIDs, T runtimeData,
            GPUInstancerCameraData cameraData, bool isManagerFrustumCulling, bool showRenderedAmount, bool isInitial)
            where T : GPUInstancerRuntimeData
        {
            if (runtimeData == null)
                return;

            if (runtimeData.transformationMatrixVisibilityBuffer == null || runtimeData.bufferSize == 0 || runtimeData.instanceCount == 0)
            {
                if (showRenderedAmount && runtimeData.args != null)
                {
                    for (int lod = 0; lod < runtimeData.instanceLODs.Count; lod++)
                    {
                        runtimeData.args[runtimeData.instanceLODs[lod].argsBufferOffset + 1] = 0;
                    }
                }
                return;
            }

            DispatchCSInstancedCameraCalculation(cameraComputeShader, cameraComputeKernelIDs, runtimeData, cameraData, isManagerFrustumCulling, isInitial);

            int lodCount = runtimeData.instanceLODs.Count;
            int instanceVisibilityComputeKernelId = instanceVisibilityComputeKernelIDs[
                lodCount > GPUInstancerConstants.COMPUTE_MAX_LOD_BUFFER ?
                    GPUInstancerConstants.COMPUTE_MAX_LOD_BUFFER - 1
                    : lodCount - 1];

            DispatchCSInstancedVisibilityCalculation(visibilityComputeShader, instanceVisibilityComputeKernelId, runtimeData, false, 0, 0);

            if (lodCount > GPUInstancerConstants.COMPUTE_MAX_LOD_BUFFER)
            {
                instanceVisibilityComputeKernelId = instanceVisibilityComputeKernelIDs[lodCount - GPUInstancerConstants.COMPUTE_MAX_LOD_BUFFER - 1];

                DispatchCSInstancedVisibilityCalculation(visibilityComputeShader, instanceVisibilityComputeKernelId, runtimeData, false,
                    GPUInstancerConstants.COMPUTE_MAX_LOD_BUFFER, 0);
            }

            GPUInstancerPrototypeLOD rdLOD;
            GPUInstancerRenderer rdRenderer;

            // Copy (overwrite) the modified instance count of the append buffer to each index of the indirect renderer buffer (argsBuffer)
            // that represents a submesh's instance count. The offset is calculated in parallel to the Graphics.DrawMeshInstancedIndirect call,
            // which expects args[1] to be the instance count for the first LOD's first renderer. Every 5 index offset of args represents the 
            // next submesh in the renderer, followed by the next renderer and it's submeshes. After all submeshes of all renderers for the 
            // first LOD, the other LODs follow in the same manner.
            // For reference, see: https://docs.unity3d.com/ScriptReference/ComputeBuffer.CopyCount.html

            int offset = 0;
            for (int lod = 0; lod < lodCount; lod++)
            {
                rdLOD = runtimeData.instanceLODs[lod];
                for (int r = 0; r < rdLOD.renderers.Count; r++)
                {
                    rdRenderer = rdLOD.renderers[r];
                    for (int j = 0; j < rdRenderer.mesh.subMeshCount; j++)
                    {
                        // LOD renderer start location + LOD renderer material start location + 1 :
                        offset = (rdRenderer.argsBufferOffset * GPUInstancerConstants.STRIDE_SIZE_INT) + (j * GPUInstancerConstants.STRIDE_SIZE_INT * 5) + GPUInstancerConstants.STRIDE_SIZE_INT;
                        ComputeBuffer.CopyCount(rdLOD.transformationMatrixAppendBuffer,
                                runtimeData.argsBuffer,
                                offset);
                    }
                }
            }

            // WARNING: this will read back the instance matrices buffer after the compute shader operates on it. This will impact FPS greatly. Use only for debug.
            if (showRenderedAmount)
            {
                if (runtimeData.argsBuffer != null && runtimeData.args != null && runtimeData.args.Length > 0)
                {
                    runtimeData.argsBuffer.GetData(runtimeData.args);
                }
            }
        }

        public static void DispatchCSInstancedCameraCalculation<T>(ComputeShader cameraComputeShader, int[] cameraComputeKernelIDs, T runtimeData,
            GPUInstancerCameraData cameraData, bool isManagerFrustumCulling, bool isInitial)
            where T : GPUInstancerRuntimeData
        {
            int lodCount = runtimeData.instanceLODs.Count;

            int instanceVisibilityComputeKernelId = cameraComputeKernelIDs[0];

            cameraComputeShader.SetBuffer(instanceVisibilityComputeKernelId, GPUInstancerConstants.VisibilityKernelPoperties.INSTANCE_LOD_BUFFER, runtimeData.instanceLODDataBuffer);
            cameraComputeShader.SetBuffer(instanceVisibilityComputeKernelId, GPUInstancerConstants.VisibilityKernelPoperties.INSTANCE_DATA_BUFFER, runtimeData.transformationMatrixVisibilityBuffer);

            cameraComputeShader.SetMatrix(GPUInstancerConstants.VisibilityKernelPoperties.BUFFER_PARAMETER_MVP_MATRIX,
                cameraData.mvpMatrix);
            cameraComputeShader.SetVector(GPUInstancerConstants.VisibilityKernelPoperties.BUFFER_PARAMETER_BOUNDS_CENTER,
                runtimeData.instanceBounds.center);
            cameraComputeShader.SetVector(GPUInstancerConstants.VisibilityKernelPoperties.BUFFER_PARAMETER_BOUNDS_EXTENTS,
                runtimeData.instanceBounds.extents);
            cameraComputeShader.SetBool(GPUInstancerConstants.VisibilityKernelPoperties.BUFFER_PARAMETER_FRUSTUM_CULL_SWITCH,
                isManagerFrustumCulling && runtimeData.prototype.isFrustumCulling);
            cameraComputeShader.SetFloat(GPUInstancerConstants.VisibilityKernelPoperties.BUFFER_PARAMETER_MIN_VIEW_DISTANCE,
                runtimeData.prototype.minDistance);
            cameraComputeShader.SetFloat(GPUInstancerConstants.VisibilityKernelPoperties.BUFFER_PARAMETER_MAX_VIEW_DISTANCE,
                runtimeData.prototype.maxDistance);
            cameraComputeShader.SetVector(GPUInstancerConstants.VisibilityKernelPoperties.BUFFER_PARAMETER_CAMERA_POSITION,
                cameraData.cameraPosition);
            cameraComputeShader.SetFloat(GPUInstancerConstants.VisibilityKernelPoperties.BUFFER_PARAMETER_FRUSTUM_OFFSET,
                runtimeData.prototype.frustumOffset);
            // cameraComputeShader.SetFloat(GPUInstancerConstants.VisibilityKernelPoperties.BUFFER_PARAMETER_OCCLUSION_OFFSET,
            //     runtimeData.prototype.occlusionOffset);
            // cameraComputeShader.SetInt(GPUInstancerConstants.VisibilityKernelPoperties.BUFFER_PARAMETER_OCCLUSION_ACCURACY,
            //     runtimeData.prototype.occlusionAccuracy);
            // cameraComputeShader.SetFloat(GPUInstancerConstants.VisibilityKernelPoperties.BUFFER_PARAMETER_MIN_CULLING_DISTANCE,
            //     runtimeData.prototype.minCullingDistance);
            cameraComputeShader.SetInt(GPUInstancerConstants.VisibilityKernelPoperties.BUFFER_PARAMETER_BUFFER_SIZE, runtimeData.instanceCount);

            float shadowDistance = -1;

            cameraComputeShader.SetFloat(GPUInstancerConstants.VisibilityKernelPoperties.BUFFER_PARAMETER_SHADOW_DISTANCE, shadowDistance);

            cameraComputeShader.SetFloats(GPUInstancerConstants.VisibilityKernelPoperties.BUFFER_PARAMETER_LOD_SIZES, runtimeData.lodSizes);
            cameraComputeShader.SetInt(GPUInstancerConstants.VisibilityKernelPoperties.BUFFER_PARAMETER_LOD_COUNT, lodCount);

            cameraComputeShader.SetFloat(GPUInstancerConstants.VisibilityKernelPoperties.BUFFER_PARAMETER_HALF_ANGLE, cameraData.halfAngle);


            cameraComputeShader.SetBool(GPUInstancerConstants.VisibilityKernelPoperties.BUFFER_PARAMETER_OCCLUSION_CULL_SWITCH, false);
            // setting a dummy placeholder or the compute shader will throw errors.
            cameraComputeShader.SetTexture(instanceVisibilityComputeKernelId, GPUInstancerConstants.VisibilityKernelPoperties.BUFFER_PARAMETER_HIERARCHICAL_Z_TEXTURE_MAP,
                dummyHiZTex);


            // Dispatch the compute shader
            cameraComputeShader.Dispatch(instanceVisibilityComputeKernelId,
                Mathf.CeilToInt(runtimeData.instanceCount / GPUInstancerConstants.COMPUTE_SHADER_THREAD_COUNT), 1, 1);
        }

        public static void DispatchCSInstancedVisibilityCalculation<T>(ComputeShader visibilityComputeShader, int instanceVisibilityComputeKernelId, T runtimeData,
            bool isShadow, int lodShift, int lodAppendIndex) where T : GPUInstancerRuntimeData
        {
            GPUInstancerPrototypeLOD rdLOD;
            int lodCount = runtimeData.instanceLODs.Count;

            visibilityComputeShader.SetBuffer(instanceVisibilityComputeKernelId, GPUInstancerConstants.VisibilityKernelPoperties.INSTANCE_DATA_BUFFER,
                runtimeData.transformationMatrixVisibilityBuffer);
            visibilityComputeShader.SetBuffer(instanceVisibilityComputeKernelId, GPUInstancerConstants.VisibilityKernelPoperties.INSTANCE_LOD_BUFFER,
                runtimeData.instanceLODDataBuffer);

            for (int lod = 0; lod < lodCount - lodShift && lod < GPUInstancerConstants.COMPUTE_MAX_LOD_BUFFER; lod++)
            {
                rdLOD = runtimeData.instanceLODs[lod + lodShift];
                if (isShadow)
                {
                    rdLOD.shadowAppendBuffer.SetCounterValue(0);
                    visibilityComputeShader.SetBuffer(instanceVisibilityComputeKernelId, GPUInstancerConstants.VisibilityKernelPoperties.TRANSFORMATION_MATRIX_APPEND_BUFFERS[lod],
                            rdLOD.shadowAppendBuffer);
                }
                else
                {
                    if (lodAppendIndex == 0)
                        rdLOD.transformationMatrixAppendBuffer.SetCounterValue(0);
                    visibilityComputeShader.SetBuffer(instanceVisibilityComputeKernelId, GPUInstancerConstants.VisibilityKernelPoperties.TRANSFORMATION_MATRIX_APPEND_BUFFERS[lod],
                            rdLOD.transformationMatrixAppendBuffer);
                }
            }

            visibilityComputeShader.SetInt(GPUInstancerConstants.VisibilityKernelPoperties.BUFFER_PARAMETER_BUFFER_SIZE, runtimeData.instanceCount);
            visibilityComputeShader.SetInt(GPUInstancerConstants.VisibilityKernelPoperties.BUFFER_PARAMETER_LOD_SHIFT, lodShift);
            visibilityComputeShader.SetInt(GPUInstancerConstants.VisibilityKernelPoperties.BUFFER_PARAMETER_LOD_APPEND_INDEX, lodAppendIndex);

            // Dispatch the compute shader
            visibilityComputeShader.Dispatch(instanceVisibilityComputeKernelId,
                Mathf.CeilToInt(runtimeData.instanceCount / GPUInstancerConstants.COMPUTE_SHADER_THREAD_COUNT), 1, 1);
        }

        public static void GPUIDrawMeshInstancedIndirect<T>(List<T> runtimeDataList, Bounds instancingBounds, GPUInstancerCameraData cameraData, int layerMask = ~0,
            bool lightProbeDisabled = false)
            where T : GPUInstancerRuntimeData
        {
            if (runtimeDataList == null)
                return;

            Camera rendereringCamera = cameraData.GetRenderingCamera();
            foreach (T runtimeData in runtimeDataList)
            {
                if (runtimeData == null || runtimeData.transformationMatrixVisibilityBuffer == null || runtimeData.bufferSize == 0 || runtimeData.instanceCount == 0)
                    continue;

                // Everything is ready; execute the instanced indirect rendering. We execute a drawcall for each submesh of each LOD.
                GPUInstancerPrototypeLOD rdLOD;
                GPUInstancerRenderer rdRenderer;
                Material rdMaterial;
                int offset = 0;
                int submeshIndex = 0;
                for (int lod = 0; lod < runtimeData.instanceLODs.Count; lod++)
                {
                    rdLOD = runtimeData.instanceLODs[lod];

                    for (int r = 0; r < rdLOD.renderers.Count; r++)
                    {
                        rdRenderer = rdLOD.renderers[r];
                        if (!IsInLayer(layerMask, rdRenderer.layer))
                            continue;

                        for (int m = 0; m < rdRenderer.materials.Count; m++)
                        {
                            rdMaterial = rdRenderer.materials[m];

                            submeshIndex = Math.Min(m, rdRenderer.mesh.subMeshCount - 1);
                            offset = (rdRenderer.argsBufferOffset + 5 * submeshIndex) * GPUInstancerConstants.STRIDE_SIZE_INT;

                            Graphics.DrawMeshInstancedIndirect(rdRenderer.mesh, submeshIndex,
                                rdMaterial,
                                instancingBounds,
                                runtimeData.argsBuffer,
                                offset,
                                rdRenderer.mpb,
                                ShadowCastingMode.Off, rdRenderer.receiveShadows, rdRenderer.layer,
                                rendereringCamera
#if UNITY_2018_1_OR_NEWER
                                , lightProbeDisabled ? LightProbeUsage.Off : LightProbeUsage.BlendProbes
#endif
                                );
                        }
                    }
                }
            }
        }

        public static void DispatchBufferToTexture<T>(List<T> runtimeDataList, ComputeShader bufferToTextureComputeShader, int bufferToTextureComputeKernelID) where T : GPUInstancerRuntimeData
        {
            if (runtimeDataList == null)
                return;

            foreach (T runtimeData in runtimeDataList)
            {
                if (runtimeData == null || runtimeData.args == null || runtimeData.transformationMatrixVisibilityBuffer == null || runtimeData.bufferSize == 0)
                    continue;

                for (int lod = 0; lod < runtimeData.instanceLODs.Count; lod++)
                {
                    bufferToTextureComputeShader.SetBuffer(bufferToTextureComputeKernelID, GPUInstancerConstants.VisibilityKernelPoperties.INSTANCE_DATA_BUFFER, runtimeData.transformationMatrixVisibilityBuffer);
                    bufferToTextureComputeShader.SetBuffer(bufferToTextureComputeKernelID, GPUInstancerConstants.VisibilityKernelPoperties.TRANSFORMATION_MATRIX_BUFFER, runtimeData.instanceLODs[lod].transformationMatrixAppendBuffer);
                    bufferToTextureComputeShader.SetTexture(bufferToTextureComputeKernelID, GPUInstancerConstants.BufferToTextureKernelPoperties.TRANSFORMATION_MATRIX_TEXTURE, runtimeData.instanceLODs[lod].transformationMatrixAppendTexture);
                    bufferToTextureComputeShader.SetBuffer(bufferToTextureComputeKernelID, GPUInstancerConstants.VisibilityKernelPoperties.ARGS_BUFFER, runtimeData.argsBuffer);
                    bufferToTextureComputeShader.SetInt(GPUInstancerConstants.VisibilityKernelPoperties.ARGS_BUFFER_INDEX, runtimeData.instanceLODs[lod].argsBufferOffset + 1);
                    bufferToTextureComputeShader.SetInt(GPUInstancerConstants.VisibilityKernelPoperties.MAX_TEXTURE_SIZE, GPUInstancerConstants.TEXTURE_MAX_SIZE);

                    bufferToTextureComputeShader.Dispatch(bufferToTextureComputeKernelID, Mathf.CeilToInt(runtimeData.bufferSize / GPUInstancerConstants.COMPUTE_SHADER_THREAD_COUNT), 1, 1);


                }
            }
        }


        public static bool IsInLayer(int layerMask, int layer)
        {
            return layerMask == (layerMask | (1 << layer));
        }
        #endregion GPU Instancing

        #region Prototype Release

        public static void ReleaseInstanceBuffers<T>(List<T> runtimeDataList) where T : GPUInstancerRuntimeData
        {
            if (runtimeDataList == null)
                return;

            for (int i = 0; i < runtimeDataList.Count; i++)
            {
                ReleaseInstanceBuffers(runtimeDataList[i]);
            }
        }

        public static void ReleaseInstanceBuffers<T>(T runtimeData) where T : GPUInstancerRuntimeData
        {
            if (runtimeData == null)
                return;

            if (runtimeData.instanceLODs != null)
            {
                for (int lod = 0; lod < runtimeData.instanceLODs.Count; lod++)
                {
                    if (runtimeData.instanceLODs[lod].transformationMatrixAppendBuffer != null)
                        runtimeData.instanceLODs[lod].transformationMatrixAppendBuffer.Release();
                    runtimeData.instanceLODs[lod].transformationMatrixAppendBuffer = null;

                    DestroyObject(runtimeData.instanceLODs[lod].transformationMatrixAppendTexture);
                    runtimeData.instanceLODs[lod].transformationMatrixAppendTexture = null;

                    DestroyObject(runtimeData.instanceLODs[lod].shadowAppendTexture);
                    runtimeData.instanceLODs[lod].shadowAppendTexture = null;

                    if (runtimeData.instanceLODs[lod].shadowAppendBuffer != null)
                        runtimeData.instanceLODs[lod].shadowAppendBuffer.Release();
                    runtimeData.instanceLODs[lod].shadowAppendBuffer = null;
                }
            }

            if (runtimeData.instanceLODDataBuffer != null)
                runtimeData.instanceLODDataBuffer.Release();
            runtimeData.instanceLODDataBuffer = null;

            if (runtimeData.transformationMatrixVisibilityBuffer != null)
                runtimeData.transformationMatrixVisibilityBuffer.Release();
            runtimeData.transformationMatrixVisibilityBuffer = null;

            if (runtimeData.argsBuffer != null)
                runtimeData.argsBuffer.Release();
            runtimeData.argsBuffer = null;

            runtimeData.ReleaseBuffers();
        }


        #endregion Prototype Release

        #region Create Prototypes


        #region Create Prefab Prototypes

        public static void SetPrefabInstancePrototypes(GameObject gameObject, List<GPUInstancerPrototype> prototypeList, List<GameObject> prefabList, bool forceNew)
        {
            if (prefabList == null)
                return;

#if UNITY_EDITOR
            if (!Application.isPlaying)
                Undo.RecordObject(gameObject, "Prefab prototypes changed");

            bool changed = false;
            if (forceNew)
            {
                foreach (GPUInstancerPrefabPrototype prototype in prototypeList)
                {
                    AssetDatabase.DeleteAsset(AssetDatabase.GetAssetPath(prototype));
                    changed = true;
                }
            }
            else
            {
                foreach (GPUInstancerPrefabPrototype prototype in prototypeList)
                {
                    if (!prefabList.Contains(prototype.prefabObject))
                    {
                        AssetDatabase.DeleteAsset(AssetDatabase.GetAssetPath(prototype));
                        changed = true;
                    }
                }
            }
            if (changed)
            {
                AssetDatabase.SaveAssets();
                AssetDatabase.Refresh();
            }
#endif

            foreach (GameObject go in prefabList)
            {
                if (!forceNew && prototypeList.Exists(p => p.prefabObject == go))
                    continue;

                prototypeList.Add(GeneratePrefabPrototype(go, forceNew));
            }

#if UNITY_EDITOR
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();

            if (!Application.isPlaying)
            {
                GPUInstancerPrefab[] prefabInstances = GameObject.FindObjectsOfType<GPUInstancerPrefab>();
                for (int i = 0; i < prefabInstances.Length; i++)
                {
#if UNITY_2018_2_OR_NEWER
                    UnityEngine.Object prefabRoot = PrefabUtility.GetCorrespondingObjectFromSource(prefabInstances[i].gameObject);
#else
                    UnityEngine.Object prefabRoot = PrefabUtility.GetPrefabParent(prefabInstances[i].gameObject);
#endif
                    if (prefabRoot != null && ((GameObject)prefabRoot).GetComponent<GPUInstancerPrefab>() != null && prefabInstances[i].prefabPrototype != ((GameObject)prefabRoot).GetComponent<GPUInstancerPrefab>().prefabPrototype)
                    {
                        Undo.RecordObject(prefabInstances[i], "Changed GPUInstancer Prefab Prototype " + prefabInstances[i].gameObject + i);
                        prefabInstances[i].prefabPrototype = ((GameObject)prefabRoot).GetComponent<GPUInstancerPrefab>().prefabPrototype;
                    }
                }
            }
#endif
        }

        public static GPUInstancerPrefabPrototype GeneratePrefabPrototype(GameObject go, bool forceNew, bool attachScript = true)
        {
            GPUInstancerPrefab prefabScript = go.GetComponent<GPUInstancerPrefab>();
            if (attachScript && prefabScript == null)
#if UNITY_2018_3_OR_NEWER && UNITY_EDITOR
                prefabScript = AddComponentToPrefab<GPUInstancerPrefab>(go);
#else
                prefabScript = go.AddComponent<GPUInstancerPrefab>();
#endif
            if (attachScript && prefabScript == null)
                return null;

            GPUInstancerPrefabPrototype prototype = null;
            if (prefabScript != null)
                prototype = prefabScript.prefabPrototype;
            if (prototype == null)
            {
                prototype = ScriptableObject.CreateInstance<GPUInstancerPrefabPrototype>();
                if (prefabScript != null)
                    prefabScript.prefabPrototype = prototype;
                prototype.prefabObject = go;
                prototype.name = go.name + "_" + go.GetInstanceID();
                // DetermineTreePrototypeType(prototype);


                GenerateInstancedShadersForGameObject(prototype);

#if UNITY_EDITOR
                if (!Application.isPlaying)
                    EditorUtility.SetDirty(go);
#endif
            }
#if UNITY_EDITOR
            if (!Application.isPlaying && string.IsNullOrEmpty(AssetDatabase.GetAssetPath(prototype)))
            {
                string assetPath = GPUInstancerConstants.GetDefaultPath() + GPUInstancerConstants.PROTOTYPES_PREFAB_PATH + prototype.name + ".asset";

                if (!System.IO.Directory.Exists(GPUInstancerConstants.GetDefaultPath() + GPUInstancerConstants.PROTOTYPES_PREFAB_PATH))
                {
                    System.IO.Directory.CreateDirectory(GPUInstancerConstants.GetDefaultPath() + GPUInstancerConstants.PROTOTYPES_PREFAB_PATH);
                }

                AssetDatabase.CreateAsset(prototype, assetPath);
            }

#if UNITY_2018_3_OR_NEWER
            if (!Application.isPlaying && prefabScript != null && prefabScript.prefabPrototype != prototype)
            {
                GameObject prefabContents = LoadPrefabContents(go);
                prefabContents.GetComponent<GPUInstancerPrefab>().prefabPrototype = prototype;
                UnloadPrefabContents(go, prefabContents);
            }
#endif
#endif
            return prototype;
        }

        #endregion

        #endregion



        #region Shader Functions

        public static void GenerateInstancedShadersForGameObject(GPUInstancerPrototype prototype)
        {
            if (prototype.prefabObject == null)
                return;

            MeshRenderer[] meshRenderers = prototype.prefabObject.GetComponentsInChildren<MeshRenderer>();

#if UNITY_EDITOR
            string warnings = "";
#endif

            foreach (MeshRenderer mr in meshRenderers)
            {
                Material[] mats = mr.sharedMaterials;

                for (int i = 0; i < mats.Length; i++)
                {
                    if (mats[i] == null || mats[i].shader == null)
                        continue;
                    if (GPUInstancerConstants.gpuiSettings.shaderBindings.IsShadersInstancedVersionExists(mats[i].shader.name))
                    {
                        if (!GPUInstancerConstants.gpuiSettings.disableAutoVariantHandling)
                            GPUInstancerConstants.gpuiSettings.AddShaderVariantToCollection(mats[i]);
                        continue;
                    }

                    if (!Application.isPlaying)
                    {
                        if (IsShaderInstanced(mats[i].shader))
                        {
                            GPUInstancerConstants.gpuiSettings.shaderBindings.AddShaderInstance(mats[i].shader.name, mats[i].shader, true);
                            if (!GPUInstancerConstants.gpuiSettings.disableAutoVariantHandling)
                                GPUInstancerConstants.gpuiSettings.AddShaderVariantToCollection(mats[i]);
                        }
                        else if (!GPUInstancerConstants.gpuiSettings.disableAutoShaderConversion)
                        {
                            Shader instancedShader = CreateInstancedShader(mats[i].shader);
                            if (instancedShader != null)
                            {
                                GPUInstancerConstants.gpuiSettings.shaderBindings.AddShaderInstance(mats[i].shader.name, instancedShader);
                                if (!GPUInstancerConstants.gpuiSettings.disableAutoVariantHandling)
                                    GPUInstancerConstants.gpuiSettings.AddShaderVariantToCollection(mats[i]);
                            }
#if UNITY_EDITOR
                            else
                            {
                                if (!warnings.Contains(mats[i].shader.name))
                                {
                                    string originalAssetPath = AssetDatabase.GetAssetPath(mats[i].shader);
                                    if (originalAssetPath.ToLower().EndsWith(".shadergraph"))
                                        warnings += string.Format(GPUInstancerConstants.ERRORTEXT_shaderGraph, mats[i].shader.name);
                                    else
                                        warnings += "Can not create instanced version for shader: " + mats[i].shader.name + ". If you are using a Unity built-in shader, please download the shader to your project from the Unity Archive.";
                                }
                            }
#endif
                        }
                    }
                }
            }


#if UNITY_EDITOR
            if (string.IsNullOrEmpty(warnings))
            {
                if (prototype.warningText != null)
                {
                    prototype.warningText = null;
                    EditorUtility.SetDirty(prototype);
                }
            }
            else
            {
                if (prototype.warningText != warnings)
                {
                    prototype.warningText = warnings;
                    EditorUtility.SetDirty(prototype);
                }
            }
#endif
        }

        public static bool IsShaderInstanced(Shader shader)
        {
#if UNITY_EDITOR
            if (shader == null || shader.name == GPUInstancerConstants.SHADER_UNITY_INTERNAL_ERROR)
            {
                Debug.LogError("Can not find shader! Please make sure that the material has a shader assigned.");
                return false;
            }
            string originalAssetPath = AssetDatabase.GetAssetPath(shader);
            string originalShaderText = "";
            try
            {
                originalShaderText = System.IO.File.ReadAllText(originalAssetPath);
            }
            catch (Exception)
            {
                return false;
            }
            if (!string.IsNullOrEmpty(originalShaderText))
            {
                if (originalAssetPath.ToLower().EndsWith(".shadergraph"))
                {
                    return originalShaderText.Contains("GPUInstancerShaderGraphNode") || originalShaderText.Contains("GPU Instancer Setup");
                }
                else
                {
                    return originalShaderText.Contains("GPUInstancerInclude.cginc");
                }
            }
#endif
            return false;
        }

        public static Shader CreateInstancedShader(Shader originalShader, bool useOriginal = false)
        {
#if UNITY_EDITOR
            try
            {
                if (originalShader == null || originalShader.name == GPUInstancerConstants.SHADER_UNITY_INTERNAL_ERROR)
                {
                    Debug.LogError("Can not find shader! Please make sure that the material has a shader assigned.");
                    return null;
                }
                Shader originalShaderRef = Shader.Find(originalShader.name);
                string originalAssetPath = AssetDatabase.GetAssetPath(originalShaderRef);

                // can not work with ShaderGraph or other non shader code
                if (!originalAssetPath.EndsWith(".shader"))
                    return null;

                EditorUtility.DisplayProgressBar("GPU Instancer Shader Conversion", "Creating instanced shader for " + originalShader.name + ". Please wait...", 0.1f);

                string[] originalLines = System.IO.File.ReadAllLines(originalAssetPath);
                #region Remove Existing procedural setup
                System.Text.StringBuilder sb = new System.Text.StringBuilder();
                using (System.IO.StreamReader sr = new System.IO.StreamReader(originalAssetPath))
                {
                    while (!sr.EndOfStream)
                    {
                        string line = sr.ReadLine();
                        if (!line.Contains("#pragma instancing_options")
                        && !line.Contains("GPUInstancerInclude.cginc")
                        //&& !line.Contains("#include \"UnityCG.cginc\"")
                        && !line.Contains("#pragma multi_compile_instancing"))
                            sb.Append(line + "\n");
                    }
                }
                string originalShaderText = sb.ToString();
                #endregion Remove Existing procedural setup

                bool createInDefaultFolder = false;
                // create shader versions for packages inside GPUI folder
                if (originalAssetPath.StartsWith("Packages/"))
                    createInDefaultFolder = true;

                // Packages/com.unity.render-pipelines.high-definition/HDRP/
                // if HDRP, replace relative paths
                bool isHDRP = false;
                string hdrpIncludeAddition = "Packages/com.unity.render-pipelines.high-definition/";
                if (originalShader.name.StartsWith("HDRenderPipeline/"))
                {
                    isHDRP = true;
                    string[] hdrpSplit = originalAssetPath.Split('/');
                    bool foundHDRP = false;
                    for (int i = 0; i < hdrpSplit.Length; i++)
                    {
                        if (hdrpSplit[i].Contains(".shader"))
                            break;
                        if (foundHDRP)
                        {
                            hdrpIncludeAddition += hdrpSplit[i] + "/";
                        }
                        else
                        {
                            if (hdrpSplit[i] == "com.unity.render-pipelines.high-definition")
                                foundHDRP = true;
                        }
                    }
                }

                // Packages/com.unity.render-pipelines.lightweight/Shaders/Lit.shader
                // if LWRP, replace relative paths
                bool isLWRP = false;
                string lwrpIncludeAddition = "Packages/com.unity.render-pipelines.lightweight/";
                if (originalShader.name.StartsWith("Lightweight Render Pipeline/"))
                {
                    isLWRP = true;
                    string[] lwrpSplit = originalAssetPath.Split('/');
                    bool foundLWRP = false;
                    for (int i = 0; i < lwrpSplit.Length; i++)
                    {
                        if (lwrpSplit[i].Contains(".shader"))
                            break;
                        if (foundLWRP)
                        {
                            lwrpIncludeAddition += lwrpSplit[i] + "/";
                        }
                        else
                        {
                            if (lwrpSplit[i] == "com.unity.render-pipelines.lightweight")
                                foundLWRP = true;
                        }
                    }
                }


                // Packages/com.unity.render-pipelines.universal/Shaders/Lit.shader
                // if URP, replace relative paths
                bool isURP = false;
                string urpIncludeAddition = "Packages/com.unity.render-pipelines.universal/";
                if (originalShader.name.StartsWith("Universal Render Pipeline/"))
                {
                    isURP = true;
                    string[] urpSplit = originalAssetPath.Split('/');
                    bool foundURP = false;
                    for (int i = 0; i < urpSplit.Length; i++)
                    {
                        if (urpSplit[i].Contains(".shader"))
                            break;
                        if (foundURP)
                        {
                            urpIncludeAddition += urpSplit[i] + "/";
                        }
                        else
                        {
                            if (urpSplit[i] == "com.unity.render-pipelines.universal")
                                foundURP = true;
                        }
                    }
                }

                EditorUtility.DisplayProgressBar("GPU Instancer Shader Conversion", "Creating instanced shader for " + originalShader.name + ".  Please wait...", 0.5f);

                string newShaderName = useOriginal ? "" : "GPUInstancer/" + originalShader.name;
                string newShaderText = useOriginal ? originalShaderText.Replace("\r\n", "\n") : originalShaderText.Replace("\r\n", "\n").Replace(originalShader.name, newShaderName);

                string includePath = "Include/GPUInstancerInclude.cginc";
                string standardShaderPath = AssetDatabase.GetAssetPath(Shader.Find(GPUInstancerConstants.SHADER_GPUI_STANDARD));
                if (string.IsNullOrEmpty(standardShaderPath))
                    standardShaderPath = GPUInstancerConstants.GetDefaultPath() + GPUInstancerConstants.SHADERS_PATH + "Standard_GPUI.shader";
                string[] oapSplit = originalAssetPath.Split('/');
                if (createInDefaultFolder)
                {
                    if (!System.IO.Directory.Exists(GPUInstancerConstants.GetDefaultPath() + GPUInstancerConstants.PROTOTYPES_SHADERS_PATH))
                        System.IO.Directory.CreateDirectory(GPUInstancerConstants.GetDefaultPath() + GPUInstancerConstants.PROTOTYPES_SHADERS_PATH);

                    originalAssetPath = GPUInstancerConstants.GetDefaultPath() + GPUInstancerConstants.PROTOTYPES_SHADERS_PATH + oapSplit[oapSplit.Length - 1];
                    oapSplit = originalAssetPath.Split('/');
                }
                string[] sspSplit = standardShaderPath.Split('/');
                int startIndex = 0;
                for (int i = 0; i < oapSplit.Length - 1; i++)
                {
                    if (oapSplit[i] == sspSplit[i])
                        startIndex++;
                    else break;
                }
                for (int i = sspSplit.Length - 2; i >= startIndex; i--)
                {
                    includePath = sspSplit[i] + "/" + includePath;
                }
                //includePath = System.IO.Path.GetDirectoryName(standardShaderPath) + "/" + includePath;

                for (int i = startIndex; i < oapSplit.Length - 1; i++)
                {
                    includePath = "../" + includePath;
                }
                includePath = "./" + includePath;

                // For vertex/fragment and surface shaders
                #region CGPROGRAM
                int lastIndex = 0;
                string searchStart = "CGPROGRAM";
                string additionTextStart = "\n#include \"UnityCG.cginc\"\n#include \"" + includePath + "\"\n#pragma instancing_options procedural:setupGPUI\n#pragma multi_compile_instancing";
                string searchEnd = "ENDCG";
                string additionTextEnd = "";//"#include \"" + includePath + "\"\n";

                int foundIndex = -1;
                while (true)
                {
                    foundIndex = newShaderText.IndexOf(searchStart, lastIndex);
                    if (foundIndex == -1)
                        break;
                    lastIndex = foundIndex + searchStart.Length + additionTextStart.Length + 1;

                    newShaderText = newShaderText.Substring(0, foundIndex + searchStart.Length) + additionTextStart + newShaderText.Substring(foundIndex + searchStart.Length, newShaderText.Length - foundIndex - searchStart.Length);

                    foundIndex = newShaderText.IndexOf(searchEnd, lastIndex);
                    lastIndex = foundIndex + searchStart.Length + additionTextEnd.Length + 1;
                    newShaderText = newShaderText.Substring(0, foundIndex) + additionTextEnd + newShaderText.Substring(foundIndex, newShaderText.Length - foundIndex);
                }
                #endregion CGPROGRAM

                // For HDRP Shaders Include relative path fix
                #region HDRP relative path fix
                if (isHDRP && createInDefaultFolder)
                {
                    lastIndex = 0;
                    searchStart = "#include \"";
                    searchEnd = "\"";
                    string restOfText;

                    foundIndex = -1;
                    while (true)
                    {
                        foundIndex = newShaderText.IndexOf(searchStart, lastIndex);
                        if (foundIndex == -1)
                            break;
                        lastIndex = foundIndex + searchStart.Length + 1;

                        restOfText = newShaderText.Substring(foundIndex + searchStart.Length, newShaderText.Length - foundIndex - searchStart.Length);
                        if (!restOfText.StartsWith("HDRP") && !restOfText.StartsWith("CoreRP") && !restOfText.StartsWith("Packages"))
                        {
                            newShaderText = newShaderText.Substring(0, foundIndex + searchStart.Length) + hdrpIncludeAddition + restOfText;
                            lastIndex += hdrpIncludeAddition.Length;
                        }

                        foundIndex = newShaderText.IndexOf(searchEnd, lastIndex);
                        lastIndex = foundIndex;
                    }
                }
                #endregion HDRP relative path fix

                // For LWRP Shaders Include relative path fix
                #region LWRP relative path fix
                if (isLWRP && createInDefaultFolder)
                {
                    lastIndex = 0;
                    searchStart = "#include \"";
                    searchEnd = "\"";
                    string restOfText;

                    foundIndex = -1;
                    while (true)
                    {
                        foundIndex = newShaderText.IndexOf(searchStart, lastIndex);
                        if (foundIndex == -1)
                            break;
                        lastIndex = foundIndex + searchStart.Length + 1;

                        restOfText = newShaderText.Substring(foundIndex + searchStart.Length, newShaderText.Length - foundIndex - searchStart.Length);
                        if (!restOfText.StartsWith("LWRP") && !restOfText.StartsWith("CoreRP") && !restOfText.StartsWith("Packages"))
                        {
                            newShaderText = newShaderText.Substring(0, foundIndex + searchStart.Length) + lwrpIncludeAddition + restOfText;
                            lastIndex += lwrpIncludeAddition.Length;
                        }

                        foundIndex = newShaderText.IndexOf(searchEnd, lastIndex);
                        lastIndex = foundIndex;
                    }
                }
                #endregion LWRP relative path fix

                // For URP Shaders Include relative path fix
                #region URP relative path fix
                if (isURP && createInDefaultFolder)
                {
                    lastIndex = 0;
                    searchStart = "#include \"";
                    searchEnd = "\"";
                    string restOfText;

                    foundIndex = -1;
                    while (true)
                    {
                        foundIndex = newShaderText.IndexOf(searchStart, lastIndex);
                        if (foundIndex == -1)
                            break;
                        lastIndex = foundIndex + searchStart.Length + 1;

                        restOfText = newShaderText.Substring(foundIndex + searchStart.Length, newShaderText.Length - foundIndex - searchStart.Length);
                        if (!restOfText.StartsWith("URP") && !restOfText.StartsWith("CoreRP") && !restOfText.StartsWith("Packages"))
                        {
                            newShaderText = newShaderText.Substring(0, foundIndex + searchStart.Length) + urpIncludeAddition + restOfText;
                            lastIndex += urpIncludeAddition.Length;
                        }

                        foundIndex = newShaderText.IndexOf(searchEnd, lastIndex);
                        lastIndex = foundIndex;
                    }
                }
                #endregion URP relative path fix

                // For SRP Shaders
                #region HLSLPROGRAM
                lastIndex = 0;
                searchStart = "HLSLPROGRAM";
                additionTextStart = GPUInstancerConstants.gpuiSettings.isHDRP ? "\n#include \"Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl\"\n#include \"Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl\"\n\n#include \"" + includePath + "\"\n#pragma instancing_options procedural:setupGPUI\n#pragma multi_compile_instancing\n" : "";
                searchEnd = "ENDHLSL";
                additionTextEnd = GPUInstancerConstants.gpuiSettings.isHDRP ? "" : "\n#include \"" + includePath + "\"\n#pragma instancing_options procedural:setupGPUI\n#pragma multi_compile_instancing\n";

                foundIndex = -1;
                while (true)
                {
                    foundIndex = newShaderText.IndexOf(searchStart, lastIndex);
                    if (foundIndex == -1)
                        break;
                    lastIndex = foundIndex + searchStart.Length + additionTextStart.Length + 1;

                    newShaderText = newShaderText.Substring(0, foundIndex + searchStart.Length) + additionTextStart + newShaderText.Substring(foundIndex + searchStart.Length, newShaderText.Length - foundIndex - searchStart.Length);

                    foundIndex = newShaderText.IndexOf(searchEnd, lastIndex);
                    lastIndex = foundIndex + searchStart.Length + additionTextEnd.Length + 1;
                    newShaderText = newShaderText.Substring(0, foundIndex) + additionTextEnd + newShaderText.Substring(foundIndex, newShaderText.Length - foundIndex);
                }
                #endregion HLSLPROGRAM

                string originalFileName = System.IO.Path.GetFileName(originalAssetPath);
                string newAssetPath = useOriginal ? originalAssetPath : originalAssetPath.Replace(originalFileName, originalFileName.Replace(".shader", "_GPUI.shader"));

                byte[] bytes = System.Text.Encoding.UTF8.GetBytes(newShaderText);
                VersionControlCheckout(newAssetPath);
                System.IO.FileStream fs = System.IO.File.Create(newAssetPath);
                fs.Write(bytes, 0, bytes.Length);
                fs.Close();
                //System.IO.File.WriteAllText(newAssetPath, newShaderText);
                EditorUtility.DisplayProgressBar("GPU Instancer Shader Conversion", "Importing instanced shader for " + originalShader.name, 0.8f);
                AssetDatabase.ImportAsset(newAssetPath, ImportAssetOptions.ForceUpdate);
                AssetDatabase.Refresh();

                Shader instancedShader = AssetDatabase.LoadAssetAtPath<Shader>(newAssetPath);
                if (instancedShader == null)
                    instancedShader = Shader.Find(newShaderName);

                if (instancedShader != null)
                    Debug.Log("Generated GPUI support enabled version for shader: " + originalShader.name, instancedShader);
                EditorUtility.ClearProgressBar();

                return instancedShader;
            }
            catch (Exception e)
            {
                if (e is System.IO.DirectoryNotFoundException && e.Message.ToLower().Contains("unity_builtin_extra"))
                    Debug.LogError("\"" + originalShader.name + "\" shader is a built-in shader which is not included in GPUI package. Please download the original shader file from Unity Archive to enable auto-conversion for this shader. Check prototype settings on the Manager for instructions.");
                else
                    Debug.LogException(e);
                EditorUtility.ClearProgressBar();
            }
#endif
            return null;
        }

        #endregion Shader Functions

        #region Extensions
        public static Matrix4x4 Matrix4x4FromString(string matrixStr)
        {
            Matrix4x4 matrix4x4 = new Matrix4x4();
            string[] floatStrArray = matrixStr.Split(';');
            for (int i = 0; i < floatStrArray.Length; i++)
            {
                matrix4x4[i / 4, i % 4] = float.Parse(floatStrArray[i]);
            }
            return matrix4x4;
        }

        public static string Matrix4x4ToString(Matrix4x4 matrix4x4)
        {
            string matrix4X4String = matrix4x4.ToString().Replace("\n", ";").Replace("\t", ";");
            matrix4X4String = matrix4X4String.Substring(0, matrix4X4String.Length - 1);
            return matrix4X4String;
        }

        public static void SetMatrix4x4ToTransform(this Transform transform, Matrix4x4 matrix)
        {
            transform.position = matrix.GetColumn(3);
            transform.localScale = new Vector3(
                                matrix.GetColumn(0).magnitude,
                                matrix.GetColumn(1).magnitude,
                                matrix.GetColumn(2).magnitude
                                );
            transform.rotation = Quaternion.LookRotation(matrix.GetColumn(2), matrix.GetColumn(1));
        }

        // Dispatch Compute Shader to update positions
        public static void SetGlobalPositionOffset(GPUInstancerManager manager, Vector3 offsetPosition)
        {
            if (manager.runtimeDataList != null)
            {
                foreach (GPUInstancerRuntimeData runtimeData in manager.runtimeDataList)
                {

                    if (runtimeData == null)
                    {
                        Debug.LogWarning("SetGlobalPositionOffset called before manager initialization. Offset will not be applied.");
                        continue;
                    }

                    if (runtimeData.instanceCount == 0 || runtimeData.bufferSize == 0)
                        continue;

                    if (runtimeData.transformationMatrixVisibilityBuffer == null)
                    {
                        Debug.LogWarning("SetGlobalPositionOffset called before buffers are initialized. Offset will not be applied.");
                        continue;
                    }

                    GPUInstancerConstants.computeRuntimeModification.SetBuffer(GPUInstancerConstants.computeBufferTransformOffsetId,
                        GPUInstancerConstants.VisibilityKernelPoperties.INSTANCE_DATA_BUFFER, runtimeData.transformationMatrixVisibilityBuffer);
                    GPUInstancerConstants.computeRuntimeModification.SetInt(
                        GPUInstancerConstants.VisibilityKernelPoperties.BUFFER_PARAMETER_BUFFER_SIZE, runtimeData.bufferSize);
                    GPUInstancerConstants.computeRuntimeModification.SetVector(
                        GPUInstancerConstants.RuntimeModificationKernelProperties.BUFFER_PARAMETER_POSITION_OFFSET, offsetPosition);

                    GPUInstancerConstants.computeRuntimeModification.Dispatch(GPUInstancerConstants.computeBufferTransformOffsetId,
                        Mathf.CeilToInt(runtimeData.bufferSize / GPUInstancerConstants.COMPUTE_SHADER_THREAD_COUNT), 1, 1);
                }
            }
        }

        public static void SetGlobalMatrixOffset(GPUInstancerManager manager, Matrix4x4 offsetMatrix)
        {
            if (manager.runtimeDataList != null)
            {
                foreach (GPUInstancerRuntimeData runtimeData in manager.runtimeDataList)
                {

                    if (runtimeData == null)
                    {
                        Debug.LogWarning("SetGlobalMatrixOffset called before manager initialization. Offset will not be applied.");
                        continue;
                    }

                    if (runtimeData.instanceCount == 0 || runtimeData.bufferSize == 0)
                        continue;

                    if (runtimeData.transformationMatrixVisibilityBuffer == null)
                    {
                        Debug.LogWarning("SetGlobalMatrixOffset called before buffers are initialized. Offset will not be applied.");
                        continue;
                    }

                    GPUInstancerConstants.computeRuntimeModification.SetBuffer(GPUInstancerConstants.computeBufferMatrixOffsetId,
                        GPUInstancerConstants.VisibilityKernelPoperties.INSTANCE_DATA_BUFFER, runtimeData.transformationMatrixVisibilityBuffer);
                    GPUInstancerConstants.computeRuntimeModification.SetInt(
                        GPUInstancerConstants.VisibilityKernelPoperties.BUFFER_PARAMETER_BUFFER_SIZE, runtimeData.bufferSize);
                    GPUInstancerConstants.computeRuntimeModification.SetMatrix(
                        GPUInstancerConstants.RuntimeModificationKernelProperties.BUFFER_PARAMETER_MATRIX_OFFSET, offsetMatrix);

                    GPUInstancerConstants.computeRuntimeModification.Dispatch(GPUInstancerConstants.computeBufferMatrixOffsetId,
                        Mathf.CeilToInt(runtimeData.bufferSize / GPUInstancerConstants.COMPUTE_SHADER_THREAD_COUNT), 1, 1);
                }
            }
        }


        #region Texture Methods

        public static void CopyTextureWithComputeShader(Texture source, Texture destination, int offsetX, int sourceMip = 0, int destinationMip = 0, bool reverseZ = true)
        {
#if UNITY_2018_3_OR_NEWER
            GPUInstancerConstants.computeTextureUtils.SetTexture(GPUInstancerConstants.computeTextureUtilsCopyTextureId,
                GPUInstancerConstants.CopyTextureKernelProperties.SOURCE_TEXTURE, source, sourceMip);
            GPUInstancerConstants.computeTextureUtils.SetTexture(GPUInstancerConstants.computeTextureUtilsCopyTextureId,
                GPUInstancerConstants.CopyTextureKernelProperties.DESTINATION_TEXTURE, destination, destinationMip);
#else
            GPUInstancerConstants.computeTextureUtils.SetTexture(GPUInstancerConstants.computeTextureUtilsCopyTextureId,
                GPUInstancerConstants.CopyTextureKernelProperties.SOURCE_TEXTURE, source);
            GPUInstancerConstants.computeTextureUtils.SetTexture(GPUInstancerConstants.computeTextureUtilsCopyTextureId,
                GPUInstancerConstants.CopyTextureKernelProperties.DESTINATION_TEXTURE, destination);
#endif

            GPUInstancerConstants.computeTextureUtils.SetInt(GPUInstancerConstants.CopyTextureKernelProperties.OFFSET_X, offsetX);
            GPUInstancerConstants.computeTextureUtils.SetInt(GPUInstancerConstants.CopyTextureKernelProperties.SOURCE_SIZE_X, source.width);
            GPUInstancerConstants.computeTextureUtils.SetInt(GPUInstancerConstants.CopyTextureKernelProperties.SOURCE_SIZE_Y, source.height);
            GPUInstancerConstants.computeTextureUtils.SetBool(GPUInstancerConstants.CopyTextureKernelProperties.REVERSE_Z, reverseZ);

            GPUInstancerConstants.computeTextureUtils.Dispatch(GPUInstancerConstants.computeTextureUtilsCopyTextureId,
                Mathf.CeilToInt(source.width / GPUInstancerConstants.COMPUTE_SHADER_THREAD_COUNT_2D),
                Mathf.CeilToInt(source.height / GPUInstancerConstants.COMPUTE_SHADER_THREAD_COUNT_2D), 1);
        }

        public static void CopyTextureArrayWithComputeShader(Texture source, Texture destination, int offsetX, int textureArrayIndex, int sourceMip = 0, int destinationMip = 0, bool reverseZ = true)
        {
            GPUInstancerConstants.computeTextureUtils.SetTexture(2, GPUInstancerConstants.CopyTextureKernelProperties.SOURCE_TEXTURE_ARRAY, source, sourceMip);
            GPUInstancerConstants.computeTextureUtils.SetTexture(2, GPUInstancerConstants.CopyTextureKernelProperties.DESTINATION_TEXTURE, destination, destinationMip);

            GPUInstancerConstants.computeTextureUtils.SetInt(GPUInstancerConstants.CopyTextureKernelProperties.OFFSET_X, offsetX);
            GPUInstancerConstants.computeTextureUtils.SetInt(GPUInstancerConstants.CopyTextureKernelProperties.TEXTURE_ARRAY_INDEX, textureArrayIndex);
            GPUInstancerConstants.computeTextureUtils.SetInt(GPUInstancerConstants.CopyTextureKernelProperties.SOURCE_SIZE_X, source.width);
            GPUInstancerConstants.computeTextureUtils.SetInt(GPUInstancerConstants.CopyTextureKernelProperties.SOURCE_SIZE_Y, source.height);
            GPUInstancerConstants.computeTextureUtils.SetBool(GPUInstancerConstants.CopyTextureKernelProperties.REVERSE_Z, reverseZ);

            GPUInstancerConstants.computeTextureUtils.Dispatch(2,
                Mathf.CeilToInt(source.width / GPUInstancerConstants.COMPUTE_SHADER_THREAD_COUNT_2D),
                Mathf.CeilToInt(source.height / GPUInstancerConstants.COMPUTE_SHADER_THREAD_COUNT_2D), 1);
        }

        public static void ReduceTextureWithComputeShader(Texture source, Texture destination, int offsetX, int sourceMip = 0, int destinationMip = 0)
        {
            int sourceW = source.width;
            int sourceH = source.height;
            int destinationW = destination.width;
            int destinationH = destination.height;
            for (int i = 0; i < sourceMip; i++)
            {
                sourceW >>= 1;
                sourceH >>= 1;
            }
            for (int i = 0; i < destinationMip; i++)
            {
                destinationW >>= 1;
                destinationH >>= 1;
            }

            GPUInstancerConstants.computeTextureUtils.SetTexture(1, GPUInstancerConstants.CopyTextureKernelProperties.SOURCE_TEXTURE, source, sourceMip);
            GPUInstancerConstants.computeTextureUtils.SetTexture(1, GPUInstancerConstants.CopyTextureKernelProperties.DESTINATION_TEXTURE, destination, destinationMip);

            GPUInstancerConstants.computeTextureUtils.SetInt(GPUInstancerConstants.CopyTextureKernelProperties.OFFSET_X, offsetX);
            GPUInstancerConstants.computeTextureUtils.SetInt(GPUInstancerConstants.CopyTextureKernelProperties.SOURCE_SIZE_X, sourceW);
            GPUInstancerConstants.computeTextureUtils.SetInt(GPUInstancerConstants.CopyTextureKernelProperties.SOURCE_SIZE_Y, sourceH);
            GPUInstancerConstants.computeTextureUtils.SetInt(GPUInstancerConstants.CopyTextureKernelProperties.DESTINATION_SIZE_X, destinationW);
            GPUInstancerConstants.computeTextureUtils.SetInt(GPUInstancerConstants.CopyTextureKernelProperties.DESTINATION_SIZE_Y, destinationH);

            GPUInstancerConstants.computeTextureUtils.Dispatch(1, Mathf.CeilToInt(destinationW / GPUInstancerConstants.COMPUTE_SHADER_THREAD_COUNT_2D),
                Mathf.CeilToInt(destinationH / GPUInstancerConstants.COMPUTE_SHADER_THREAD_COUNT_2D), 1);
        }

        #endregion Texture Methods

        public static NativeArray<T> ResizeNativeArray<T>(NativeArray<T> previousArray, int newSize, Allocator allocator) where T : struct
        {
            NativeArray<T> result = new NativeArray<T>(newSize, allocator);
            if (previousArray.IsCreated)
            {
                int count = Math.Min(previousArray.Length, newSize);
                for (int i = 0; i < count; i++)
                {
                    result[i] = previousArray[i];
                }
                previousArray.Dispose();
            }
            return result;
        }


        public static void DestroyObject(UnityEngine.Object obj)
        {
            if (obj != null)
            {
                if (Application.isPlaying)
                    UnityEngine.Object.Destroy(obj);
                else
                    UnityEngine.Object.DestroyImmediate(obj);
            }
        }

        #endregion Extensions



        #region Prefab System
#if UNITY_2018_3_OR_NEWER && UNITY_EDITOR
        public static T AddComponentToPrefab<T>(GameObject prefabObject) where T : Component
        {
            PrefabAssetType prefabType = PrefabUtility.GetPrefabAssetType(prefabObject);

            if (prefabType == PrefabAssetType.Regular || prefabType == PrefabAssetType.Variant)
            {
                string prefabPath = AssetDatabase.GetAssetPath(prefabObject);
                if (string.IsNullOrEmpty(prefabPath))
                    return null;
                GameObject prefabContents = PrefabUtility.LoadPrefabContents(prefabPath);

                prefabContents.AddComponent<T>();

                PrefabUtility.SaveAsPrefabAsset(prefabContents, prefabPath);
                PrefabUtility.UnloadPrefabContents(prefabContents);

                return prefabObject.GetComponent<T>();
            }

            return prefabObject.AddComponent<T>();
        }

        public static void RemoveComponentFromPrefab<T>(GameObject prefabObject) where T : Component
        {
            string prefabPath = AssetDatabase.GetAssetPath(prefabObject);
            if (string.IsNullOrEmpty(prefabPath))
                return;
            GameObject prefabContents = PrefabUtility.LoadPrefabContents(prefabPath);

            T component = prefabContents.GetComponent<T>();
            if (component)
            {
                GameObject.DestroyImmediate(component, true);
            }

            PrefabUtility.SaveAsPrefabAsset(prefabContents, prefabPath);
            PrefabUtility.UnloadPrefabContents(prefabContents);
        }

        public static GameObject LoadPrefabContents(GameObject prefabObject)
        {
            string prefabPath = AssetDatabase.GetAssetPath(prefabObject);
            if (string.IsNullOrEmpty(prefabPath))
                return null;
            return PrefabUtility.LoadPrefabContents(prefabPath);
        }

        public static void UnloadPrefabContents(GameObject prefabObject, GameObject prefabContents, bool saveChanges = true)
        {
            if (!prefabContents)
                return;
            if (saveChanges)
            {
                string prefabPath = AssetDatabase.GetAssetPath(prefabObject);
                if (string.IsNullOrEmpty(prefabPath))
                    return;
                PrefabUtility.SaveAsPrefabAsset(prefabContents, prefabPath);
            }
            PrefabUtility.UnloadPrefabContents(prefabContents);
            if (prefabContents)
            {
                Debug.Log("Destroying prefab contents...");
                GameObject.DestroyImmediate(prefabContents);
            }
        }

        public static GameObject GetCorrespongingPrefabOfVariant(GameObject variant)
        {
            GameObject result = variant;
            PrefabAssetType prefabType = PrefabUtility.GetPrefabAssetType(result);
            if (prefabType == PrefabAssetType.Variant)
            {
                if (PrefabUtility.IsPartOfNonAssetPrefabInstance(result))
                    result = GetOutermostPrefabAssetRoot(result);

                prefabType = PrefabUtility.GetPrefabAssetType(result);
                if (prefabType == PrefabAssetType.Variant)
                    result = GetOutermostPrefabAssetRoot(result);
            }
            return result;
        }

        public static GameObject GetOutermostPrefabAssetRoot(GameObject prefabInstance)
        {
            GameObject result = prefabInstance;
            GameObject newPrefabObject = PrefabUtility.GetCorrespondingObjectFromSource(result);
            if (newPrefabObject != null)
            {
                while (newPrefabObject.transform.parent != null)
                    newPrefabObject = newPrefabObject.transform.parent.gameObject;
                result = newPrefabObject;
            }
            return result;
        }

        public static List<GameObject> GetCorrespondingPrefabAssetsOfGameObjects(GameObject[] gameObjects)
        {
            List<GameObject> result = new List<GameObject>();
            PrefabAssetType prefabType;
            GameObject prefabRoot;
            foreach (GameObject go in gameObjects)
            {
                prefabRoot = null;
                if (go != PrefabUtility.GetOutermostPrefabInstanceRoot(go))
                    continue;
                prefabType = PrefabUtility.GetPrefabAssetType(go);
                if (prefabType == PrefabAssetType.Regular)
                    prefabRoot = PrefabUtility.GetCorrespondingObjectFromSource(go);
                else if (prefabType == PrefabAssetType.Variant)
                    prefabRoot = GetCorrespongingPrefabOfVariant(go);

                if (prefabRoot != null)
                    result.Add(prefabRoot);
            }

            return result;
        }
#endif
        #endregion Prefab System

        #region Version Control


        public static void VersionControlCheckout(string path)
        {
#if UNITY_EDITOR
            if (UnityEditor.VersionControl.Provider.enabled && UnityEditor.VersionControl.Provider.isActive)
            {
                UnityEditor.VersionControl.Asset asset = UnityEditor.VersionControl.Provider.GetAssetByPath(path);
                if (asset == null)
                    return;

                if (UnityEditor.VersionControl.Provider.hasCheckoutSupport)
                {
                    UnityEditor.VersionControl.Task checkOutTask = UnityEditor.VersionControl.Provider.Checkout(asset, UnityEditor.VersionControl.CheckoutMode.Both);
                    checkOutTask.Wait();
                }
            }
#endif
        }
        #endregion Version Control

        #region Platform Dependent

        public static void SetPlatformDependentVariables()
        {
            GPUIPlatform platform = DeterminePlatform();
            matrixHandlingType = GPUInstancerConstants.gpuiSettings.GetMatrixHandlingType(platform);

            GPUIComputeThreadCount computeThreadCount = GPUInstancerConstants.gpuiSettings.GetComputeThreadCount(platform);
            switch (computeThreadCount)
            {
                case GPUIComputeThreadCount.x64:
                    GPUInstancerConstants.COMPUTE_SHADER_THREAD_COUNT = 64;
                    GPUInstancerConstants.COMPUTE_SHADER_THREAD_COUNT_2D = 8;
                    break;
                case GPUIComputeThreadCount.x128:
                    GPUInstancerConstants.COMPUTE_SHADER_THREAD_COUNT = 128;
                    GPUInstancerConstants.COMPUTE_SHADER_THREAD_COUNT_2D = 8;
                    break;
                case GPUIComputeThreadCount.x256:
                    GPUInstancerConstants.COMPUTE_SHADER_THREAD_COUNT = 256;
                    GPUInstancerConstants.COMPUTE_SHADER_THREAD_COUNT_2D = 16;
                    break;
                case GPUIComputeThreadCount.x512:
                    GPUInstancerConstants.COMPUTE_SHADER_THREAD_COUNT = 512;
                    GPUInstancerConstants.COMPUTE_SHADER_THREAD_COUNT_2D = 16;
                    break;
                case GPUIComputeThreadCount.x1024:
                    GPUInstancerConstants.COMPUTE_SHADER_THREAD_COUNT = 1024;
                    GPUInstancerConstants.COMPUTE_SHADER_THREAD_COUNT_2D = 32;
                    break;
                default:
                    GPUInstancerConstants.COMPUTE_SHADER_THREAD_COUNT = 512;
                    GPUInstancerConstants.COMPUTE_SHADER_THREAD_COUNT_2D = 16;
                    break;
            }
        }

        public static GPUIPlatform DeterminePlatform()
        {
            switch (SystemInfo.graphicsDeviceType)
            {
                case GraphicsDeviceType.OpenGLCore:
                    return GPUIPlatform.OpenGLCore;
                case GraphicsDeviceType.Metal:
                    return GPUIPlatform.Metal;
                case GraphicsDeviceType.OpenGLES3:
                    return GPUIPlatform.GLES31;
                case GraphicsDeviceType.Vulkan:
                    return GPUIPlatform.Vulkan;
                case GraphicsDeviceType.PlayStation4:
                    return GPUIPlatform.PS4;
                case GraphicsDeviceType.XboxOne:
                    return GPUIPlatform.XBoxOne;
                default:
                    return GPUIPlatform.Default;
            }
        }

        public static void UpdatePlatformDependentFiles()
        {
#if UNITY_EDITOR
            SetPlatformDependentVariables();

            // PlatformDefines.compute rewrite
            string computePlatformDefinesPath = AssetDatabase.GUIDToAssetPath(GPUInstancerConstants.GUID_COMPUTE_PLATFORM_DEFINES);
            if (!string.IsNullOrEmpty(computePlatformDefinesPath))
            {
                //TextAsset platformDefines = AssetDatabase.LoadAssetAtPath<TextAsset>(computePlatformDefinesPath);
                string computePlatformDefinesText = "#ifndef __platformDefines_hlsl_\n#define __platformDefines_hlsl_\n\n";
                if (!GPUInstancerConstants.gpuiSettings.hasCustomRenderingSettings)
                {
                    computePlatformDefinesText += "#if SHADER_API_METAL\n    #define GPUI_THREADS 256\n    #define GPUI_THREADS_2D 16\n#elif SHADER_API_GLES3\n    #define GPUI_THREADS 128\n    #define GPUI_THREADS_2D 8\n#elif SHADER_API_VULKAN\n    #define GPUI_THREADS 128\n    #define GPUI_THREADS_2D 8\n#elif SHADER_API_GLCORE\n    #define GPUI_THREADS 256\n    #define GPUI_THREADS_2D 16\n#elif SHADER_API_PS4\n    #define GPUI_THREADS 512\n    #define GPUI_THREADS_2D 16\n#else\n    #define GPUI_THREADS 512\n    #define GPUI_THREADS_2D 16\n#endif";
                }
                else
                {
                    computePlatformDefinesText += "#define GPUI_THREADS " + GPUInstancerConstants.COMPUTE_SHADER_THREAD_COUNT + "\n#define GPUI_THREADS_2D " + GPUInstancerConstants.COMPUTE_SHADER_THREAD_COUNT_2D;
                }
                computePlatformDefinesText += "\n\n#endif";
                byte[] bytes = System.Text.Encoding.UTF8.GetBytes(computePlatformDefinesText);
                VersionControlCheckout(computePlatformDefinesPath);
                System.IO.FileStream fs = System.IO.File.Create(computePlatformDefinesPath);
                fs.Write(bytes, 0, bytes.Length);
                fs.Close();
                AssetDatabase.ImportAsset(computePlatformDefinesPath, ImportAssetOptions.ForceUpdate);
            }

            // GPUIPlatformDependent.cginc rewrite
            string cgincPlatformDependentPath = AssetDatabase.GUIDToAssetPath(GPUInstancerConstants.GUID_CGINC_PLATFORM_DEPENDENT);
            if (!string.IsNullOrEmpty(cgincPlatformDependentPath))
            {
                //TextAsset cgincPlatformDependent = AssetDatabase.LoadAssetAtPath<TextAsset>(cgincPlatformDependentPath);
                string cgincPlatformDependentText = "#ifndef GPU_INSTANCER_PLATFORM_DEPENDENT_INCLUDED\n#define GPU_INSTANCER_PLATFORM_DEPENDENT_INCLUDED\n\n";
                if (!GPUInstancerConstants.gpuiSettings.hasCustomRenderingSettings)
                {
                    cgincPlatformDependentText += "#if SHADER_API_GLES3\n    #define GPUI_MHT_COPY_TEXTURE 1\n#elif SHADER_API_VULKAN\n    #define GPUI_MHT_COPY_TEXTURE 1\n#endif";
                }
                else if (matrixHandlingType == GPUIMatrixHandlingType.MatrixAppend)
                {
                    cgincPlatformDependentText += "    #define GPUI_MHT_MATRIX_APPEND 1";
                }
                else if (matrixHandlingType == GPUIMatrixHandlingType.CopyToTexture)
                {
                    cgincPlatformDependentText += "    #define GPUI_MHT_COPY_TEXTURE 1";
                }
                else
                {
                    cgincPlatformDependentText += "    #define gpui_InstanceID gpuiTransformationMatrix[unity_InstanceID]";
                }
                cgincPlatformDependentText += "\n\n#endif // GPU_INSTANCER_PLATFORM_DEPENDENT_INCLUDED";
                byte[] bytes = System.Text.Encoding.UTF8.GetBytes(cgincPlatformDependentText);
                VersionControlCheckout(cgincPlatformDependentPath);
                System.IO.FileStream fs = System.IO.File.Create(cgincPlatformDependentPath);
                fs.Write(bytes, 0, bytes.Length);
                fs.Close();
                AssetDatabase.ImportAsset(cgincPlatformDependentPath, ImportAssetOptions.ForceUpdate);
            }

            AssetDatabase.Refresh();
#endif
        }

        #endregion Platform Dependent
    }
}