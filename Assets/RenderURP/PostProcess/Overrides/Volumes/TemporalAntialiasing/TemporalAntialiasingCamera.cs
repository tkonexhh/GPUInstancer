
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Inutan.PostProcessing
{
    public class TemporalAntialiasingCamera : ScriptableRenderPass
    {
        ProfilingSampler m_ProfilingSampler = new ProfilingSampler(nameof(TemporalAntialiasingCamera));

        Matrix4x4 m_JitteredProjectionMatrix;

        public TemporalAntialiasingCamera()
        {
            this.renderPassEvent = RenderPassEvent.BeforeRenderingGbuffer;
        }

        public void Setup(Matrix4x4 projectionMatrix)
        {
            m_JitteredProjectionMatrix = projectionMatrix;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var cmd = CommandBufferPool.Get();
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                cmd.SetViewProjectionMatrices(renderingData.cameraData.camera.worldToCameraMatrix, m_JitteredProjectionMatrix);
            }
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }
}