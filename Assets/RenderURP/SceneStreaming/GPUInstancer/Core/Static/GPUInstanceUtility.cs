using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System;
using UnityEngine.Rendering;

namespace Inutan
{
    public static class GPUInstanceUtility
    {



        public static void DrawMeshInstancedIndirect(List<GPUInstancerRenderer> renderers, Bounds instancingBounds, ComputeBuffer argsBuffer)
        {
            GPUInstancerRenderer rdRenderer;
            Material rdMaterial;
            int offset = 0;
            int submeshIndex = 0;

            for (int r = 0; r < renderers.Count; r++)
            {
                rdRenderer = renderers[r];
                for (int m = 0; m < rdRenderer.materials.Count; m++)
                {
                    rdMaterial = rdRenderer.materials[m];
                    submeshIndex = Math.Min(m, rdRenderer.mesh.subMeshCount - 1);
                    offset = (rdRenderer.argsBufferOffset + 5 * submeshIndex) * GPUInstancerConstants.STRIDE_SIZE_INT;

                    Graphics.DrawMeshInstancedIndirect(rdRenderer.mesh, submeshIndex,
                        rdMaterial,
                        instancingBounds,
                        argsBuffer,
                        offset,
                        rdRenderer.mpb,
                        ShadowCastingMode.Off,
                        rdRenderer.receiveShadows,
                        rdRenderer.layer
                        );
                }

            }
        }
    }
}
