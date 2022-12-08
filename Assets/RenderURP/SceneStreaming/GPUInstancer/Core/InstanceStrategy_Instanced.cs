using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Inutan
{
    public class InstanceStrategy_Instanced : InstanceStrategy
    {
        List<InstancedPage> m_Pages = new List<InstancedPage>();

        int m_LastCount = -1;

        public override void Render()
        {
            if (renderers == null || localToWorldMatrixListNativeArray == null)
                return;

            if (m_LastCount == -1 || m_LastCount != maxCount)
            {
                //根据现在
                int pageCount = Mathf.CeilToInt((float) maxCount / (float) InstancedPage.MAXCOUNT);
                int needToCreate = pageCount - m_Pages.Count;
                for (int i = 0; i < needToCreate; i++)
                {
                    m_Pages.Add(new InstancedPage());
                }
            }

            if (m_LastCount != renderCount)
            {
                for (int i = 0; i < m_Pages.Count; i++)
                {
                    m_Pages[i].Clear();
                }

                for (int i = 0; i < localToWorldMatrixListNativeArray.Length; i++)
                {
                    int pageIndex = i / InstancedPage.MAXCOUNT;
                    m_Pages[pageIndex].AddInstance(localToWorldMatrixListNativeArray[i]);
                }

                m_LastCount = renderCount;
            }

            for (int i = 0; i < m_Pages.Count; i++)
            {
                m_Pages[i].Render(renderers);
            }
        }

        public override void Release()
        {
            base.Release();
            m_Pages.Clear();
        }

        public override Material GetDrawMaterial(Material material)
        {
            if (material.enableInstancing)
                return material;

            var instancedMaterial = Material.Instantiate(material);
            instancedMaterial.enableInstancing = true;
            return instancedMaterial;
        }
    }

    public class InstancedPage//
    {
        public const int MAXCOUNT = 1023;
        private Matrix4x4[] m_RenderMatrix = new Matrix4x4[MAXCOUNT];
        public int renderCount;

        public bool AddInstance(Matrix4x4 item)
        {
            if (renderCount >= MAXCOUNT)
                return false;

            m_RenderMatrix[renderCount] = item;
            renderCount++;
            return true;
        }

        public void Clear()
        {
            renderCount = 0;
        }

        public void Render(List<GPUInstancerRenderer> renderer)
        {
            if (renderCount <= 0)
                return;

            for (int r = 0; r < renderer.Count; r++)
            {
                GPUInstancerRenderer rdRenderer = renderer[r];
                for (int m = 0; m < rdRenderer.materials.Count; m++)
                {
                    int submeshIndex = Math.Min(m, rdRenderer.mesh.subMeshCount - 1);
                    var material = rdRenderer.materials[m];
                    Graphics.DrawMeshInstanced(rdRenderer.mesh, submeshIndex, material, m_RenderMatrix, renderCount);
                }
            }

        }
    }
}
