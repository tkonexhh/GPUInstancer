
using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.Universal.Internal;


[Serializable]
public class AfterTransparentFeature : ScriptableRendererFeature
{
    private const string DefaultLightModeTag = "AfterTransparentPass";

    [SerializeField]
    RenderPassEvent m_RenderPassEvent = RenderPassEvent.AfterRenderingTransparents;

    [SerializeField]
    List<string> m_LightModeTags = new List<string> { DefaultLightModeTag };

    [SerializeField]
    bool m_CopyDepthMode = false;

    // ------------------------------------------------------------------------------------------------------------

    AfterTransparentPass m_AfterTransparentPass;

    // 
    CopyDepthPass m_CopyDepthPass;
    Material m_CopyDepthMaterial;

    RenderTargetIdentifier m_CameraDepthAttachmentIndentifier;
    RenderTargetIdentifier m_CameraDepthTextureIndentifier;

    public override void Create()
    {   
        m_AfterTransparentPass = new AfterTransparentPass(m_RenderPassEvent, m_LightModeTags);

        // ----------------------------------------------------------------------------------------------------
        // CopyDepth
        m_CameraDepthAttachmentIndentifier = new RenderTargetIdentifier("_CameraDepthAttachment");
        m_CameraDepthTextureIndentifier = new RenderTargetIdentifier("_CameraDepthTexture");
        m_CopyDepthMaterial = CoreUtils.CreateEngineMaterial("Hidden/Universal Render Pipeline/CopyDepth");

        // m_CopyDepthMode:false 默认CopyDepth方式，简单的在m_AfterTransparentPass前面拷贝一次

        // m_CopyDepthMode:true 时，将默认管线中的CopyDepthPass移动到m_AfterTransparentPass-1前面
        // 然后添加一个新的CopyDepthPass到AfterRenderingOpaques

        // 理论上结果一样，但后者会让默认管线中做一些额外处理
        if(m_CopyDepthMode)
            m_CopyDepthPass = new CopyDepthPass(RenderPassEvent.AfterRenderingOpaques, m_CopyDepthMaterial);
        else
            // 注意 CopyDepth位于m_AfterTransparentPass前和m_AfterTransparentPass-1是有区别的
            // 现在两者已经不一样了
            m_CopyDepthPass = new CopyDepthPass(m_RenderPassEvent/*-1*/, m_CopyDepthMaterial);

    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        m_CopyDepthPass.Setup(new RenderTargetHandle(m_CameraDepthAttachmentIndentifier),
                            new RenderTargetHandle(m_CameraDepthTextureIndentifier));
        renderer.EnqueuePass(m_CopyDepthPass);

        // ----------------------------------------------------------------------------------------------------
        if(m_CopyDepthMode)
            m_AfterTransparentPass.Setup();

        renderer.EnqueuePass(m_AfterTransparentPass);
    }

    protected override void Dispose(bool disposing)
    {
        CoreUtils.Destroy(m_CopyDepthMaterial);
    }
}
