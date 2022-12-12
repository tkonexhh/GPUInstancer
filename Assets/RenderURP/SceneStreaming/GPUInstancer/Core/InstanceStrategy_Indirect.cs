using System;
using System.Collections;
using System.Collections.Generic;
using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;

namespace Inutan
{
    public class InstanceStrategy_Indirect : InstanceStrategy
    {
        Bounds instancingBounds = new Bounds(Vector3.zero, Vector3.one * 5000);

        uint[] m_Args;

        // Buffers Data
        ComputeBuffer m_ArgsBuffer;
        ComputeBuffer m_LocationBuffer;

        public static class ShaderIDs
        {
            public static readonly int TRANSFORMATION_MATRIX_BUFFER = Shader.PropertyToID("gpuiTransformationMatrix");
            public static readonly int RENDERER_TRANSFORM_OFFSET = Shader.PropertyToID("gpuiTransformOffset");
        }

        void InitBuffer(List<GPUInstancerRenderer> renderers, NativeArray<Matrix4x4> localToWorldMatrixListNativeArray)
        {
            //Set Args Buffer
            if (m_ArgsBuffer == null)
            {
                int totalSubMeshCount = 0;
                for (int r = 0; r < renderers.Count; r++)
                {
                    totalSubMeshCount += renderers[r].mesh.subMeshCount;
                }

                m_Args = new uint[5 * totalSubMeshCount];

                int argsLastIndex = 0;
                for (int r = 0; r < renderers.Count; r++)
                {
                    GPUInstancerRenderer rdRenderer = renderers[r];
                    rdRenderer.argsBufferOffset = argsLastIndex;
                    for (int j = 0; j < rdRenderer.mesh.subMeshCount; j++)
                    {
                        m_Args[argsLastIndex++] = rdRenderer.mesh.GetIndexCount(j); // index count per instance
                        m_Args[argsLastIndex++] = 0;// (uint)runtimeData.bufferSize;
                        m_Args[argsLastIndex++] = rdRenderer.mesh.GetIndexStart(j); // start index location
                        m_Args[argsLastIndex++] = 0; // base vertex location
                        m_Args[argsLastIndex++] = 0; // start instance location
                    }
                }

                if (m_Args.Length > 0)
                {
                    m_ArgsBuffer = new ComputeBuffer(m_Args.Length, sizeof(uint), ComputeBufferType.IndirectArguments);
                }
            }

            //Set Visibility Buffer
            int count = localToWorldMatrixListNativeArray.Length;
            if (m_LocationBuffer == null || m_LocationBuffer.count != count)
            {
                if (m_LocationBuffer != null)
                    m_LocationBuffer.Release();
                m_LocationBuffer = new ComputeBuffer(count, GPUInstancerConstants.STRIDE_SIZE_MATRIX4X4, ComputeBufferType.Structured, ComputeBufferMode.SubUpdates);

                if (localToWorldMatrixListNativeArray.IsCreated)
                {
                    m_LocationBuffer.SetData(localToWorldMatrixListNativeArray);

                    for (int r = 0; r < renderers.Count; r++)
                    {
                        //TODO 先直接等于当前数量
                        m_Args[1 + r * 5] = (uint)count;
                        m_ArgsBuffer.SetData(m_Args);
                    }
                }

                for (int r = 0; r < renderers.Count; r++)
                {
                    GPUInstancerRenderer rdRenderer = renderers[r];
                    rdRenderer.mpb.SetBuffer(ShaderIDs.TRANSFORMATION_MATRIX_BUFFER, m_LocationBuffer);
                    rdRenderer.mpb.SetMatrix(ShaderIDs.RENDERER_TRANSFORM_OFFSET, rdRenderer.transformOffset);
                }
            }
        }

        public override void Render(List<GPUInstancerRenderer> renderers, NativeArray<Matrix4x4> localToWorldMatrixListNativeArray)
        {
            InitBuffer(renderers, localToWorldMatrixListNativeArray);
            GPUInstanceUtility.DrawMeshInstancedIndirect(renderers, instancingBounds, m_ArgsBuffer);
        }

        public override void Release()
        {
            base.Release();
            if (m_ArgsBuffer != null)
                m_ArgsBuffer.Release();
            m_ArgsBuffer = null;

            if (m_LocationBuffer != null)
                m_LocationBuffer.Release();
            m_LocationBuffer = null;
        }
    }
}
