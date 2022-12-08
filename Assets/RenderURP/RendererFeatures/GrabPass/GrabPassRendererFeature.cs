using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable]
public class GrabPassRendererFeature : ScriptableRendererFeature
{
    private const string DefaultLightModeTag = "AfterGrabPass";
    private const string DefaultGrabPassTextureName = "_GrabTexture";

    // GrabTexture 生成的位置
    [SerializeField]
    RenderPassEvent m_RenderPassEvent = RenderPassEvent.AfterRenderingSkybox;

    [SerializeField]
    string m_GrabPassTextureName = DefaultGrabPassTextureName;

    // 指定LightModeTag的物体 相对固定在GrabTexture后面一个顺序渲染
    // 不指定的物体 就需要自己判断是否在GrabPass后面的合适位置
    [SerializeField]
    List<string> m_LightModeTags = new List<string> { DefaultLightModeTag };

    // ------------------------------------------------------------------------------------------------------------
    private GrabPass m_GrabPass;
    private AfterGrabPass m_AfterGrabPass;

    public override void Create()
    {
        m_GrabPass = new GrabPass(m_RenderPassEvent, m_GrabPassTextureName);
        if(m_LightModeTags.Count > 0)
            m_AfterGrabPass = new AfterGrabPass(m_RenderPassEvent, m_LightModeTags);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        m_GrabPass.Setup(renderer.cameraColorTarget);

        renderer.EnqueuePass(m_GrabPass);
        if(m_LightModeTags.Count > 0)
            renderer.EnqueuePass(m_AfterGrabPass);
    }
}