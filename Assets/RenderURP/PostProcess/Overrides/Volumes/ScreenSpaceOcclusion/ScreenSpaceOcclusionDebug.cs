
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Inutan.PostProcessing
{
    public class ScreenSpaceOcclusionDebug : ScriptableRenderPass
    {
        RenderTargetIdentifier m_SourceRT;
        public ScreenSpaceOcclusionDebug(RenderTargetIdentifier sourceRT)
        {
            this.renderPassEvent = RenderPassEvent.AfterRenderingTransparents;
            m_SourceRT = sourceRT;
            // m_SourceRT = new RenderTargetIdentifier("_SSAO_OcclusionTexture");
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var cmd = CommandBufferPool.Get(nameof(ScreenSpaceOcclusionDebug));
            cmd.Clear();

            Blit(cmd, m_SourceRT, renderingData.cameraData.renderer.cameraColorTarget);

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }
}