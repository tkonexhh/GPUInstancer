
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Inutan.PostProcessing
{
    public class LensFlaresPre : ScriptableRenderPass
    {
        LensFlaresRenderer m_LensFlares;
        int m_LensFlaresID;

        public LensFlaresPre(LensFlaresRenderer lensFlares, int lensFlaresID)
        {
            this.renderPassEvent = RenderPassEvent.AfterRenderingDeferredLights;
            m_LensFlares = lensFlares;
            m_LensFlaresID = lensFlaresID;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            var lensFlaresDesc = renderingData.cameraData.cameraTargetDescriptor;
            lensFlaresDesc.msaaSamples = 1;
            lensFlaresDesc.depthBufferBits = 0;
            
            cmd.GetTemporaryRT(m_LensFlaresID, lensFlaresDesc, FilterMode.Bilinear);
            ConfigureTarget(m_LensFlaresID);
        }
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(m_LensFlaresID);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var cmd = CommandBufferPool.Get(nameof(LensFlaresPre));
            cmd.Clear();

            m_LensFlares.RenderLensFlares(cmd, renderingData.cameraData.renderer.cameraColorTarget, ref renderingData);

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }
}