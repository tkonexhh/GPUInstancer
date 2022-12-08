
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class GrabPass : ScriptableRenderPass
{
    string m_GrabPassTextureName;
    RenderTargetIdentifier m_CameraColorTarget;
    RenderTargetHandle m_GrabPassRT;

    public GrabPass(RenderPassEvent renderPassEvent, string grabPassTextureName)
    {
        this.renderPassEvent = renderPassEvent;
        m_GrabPassTextureName = grabPassTextureName;

        m_GrabPassRT.Init(m_GrabPassTextureName);
    }

    public void Setup(RenderTargetIdentifier cameraColorTarget)
    {
        m_CameraColorTarget = cameraColorTarget;
    }

    public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
    {
        cmd.GetTemporaryRT(m_GrabPassRT.id, cameraTextureDescriptor);
        cmd.SetGlobalTexture(m_GrabPassTextureName, m_GrabPassRT.Identifier());
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        var cmd = CommandBufferPool.Get(nameof(GrabPass));
        cmd.Clear();

        Blit(cmd, m_CameraColorTarget, m_GrabPassRT.Identifier());

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    public override void OnCameraCleanup(CommandBuffer cmd)
    {
        cmd.ReleaseTemporaryRT(m_GrabPassRT.id);
    }
}