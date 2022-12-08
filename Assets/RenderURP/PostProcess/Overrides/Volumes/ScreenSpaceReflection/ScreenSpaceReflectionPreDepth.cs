
using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.Universal.Internal;

public class ScreenSpaceReflectionPreDepth
{
    RenderPassEvent m_RenderPassEvent = RenderPassEvent.AfterRenderingGbuffer;
    // 
    CopyDepthPass m_CopyDepthPass;
    Material m_CopyDepthMaterial;

    RenderTargetIdentifier m_CameraDepthAttachmentIndentifier;
    RenderTargetHandle m_ScreenSpaceReflectionDepthRT;

    public ScreenSpaceReflectionPreDepth()
    {   
        // MARK 这里使用两种方式构造RenderTargetHandle是为了说明两者的区别
        // 后者创建 id = Shader.PropertyToID(shaderProperty) rtid 为空 即尚未指向RT 在Identifier()返回时才新建RenderTargetIdentifier
        // 而前者 id = -2 rtid = RenderTargetIdentifier 用来指向已经存在的RT
        // 这里需要CopyDepthPass中新建新的RT 所以destination用后者创建 这样HasInternalRenderTargetId为false AllocateRT为true 不需要再指定SetGlobalTexture

        m_CameraDepthAttachmentIndentifier = new RenderTargetIdentifier("_CameraDepthAttachment");

        // TODO 为了过滤Gbuffer阶段和后续渲染物体 再拷贝一份此刻的深度做计算 （也可以考虑渲染在Gbuffer中，避免拷贝切换，暂时为了减少代码侵入）
        m_ScreenSpaceReflectionDepthRT.Init("_ScreenSpaceReflectionDepth");


        m_CopyDepthMaterial = CoreUtils.CreateEngineMaterial("Hidden/Universal Render Pipeline/CopyDepth");

        m_CopyDepthPass = new CopyDepthPass(m_RenderPassEvent, m_CopyDepthMaterial);

    }

    public void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // RT内部会释放
        m_CopyDepthPass.Setup(new RenderTargetHandle(m_CameraDepthAttachmentIndentifier), m_ScreenSpaceReflectionDepthRT);

        renderer.EnqueuePass(m_CopyDepthPass);
    }

    public void Dispose(bool disposing)
    {
        CoreUtils.Destroy(m_CopyDepthMaterial);
    }
}
