using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.Universal.Internal;

[Serializable]
public class WaterAquariumFeature : ScriptableRendererFeature
{
    [SerializeField]
    List<string> m_LightModeTags = new List<string> { "WaterAquariumInner", "WaterAquariumOuterMulti", "WaterAquariumOuterAdd"};

    [SerializeField]
    public RenderPassEvent m_RenderPassEvent = RenderPassEvent.AfterRenderingTransparents;

    [SerializeField]
    public int m_RenderPassOffset = -10;
    // ------------------------------------------------------------------------------------------------------------

    private WaterAquariumPass m_WaterAquariumPass;

    public override void Create()
    {
        m_WaterAquariumPass = new WaterAquariumPass(m_RenderPassEvent + m_RenderPassOffset, m_LightModeTags);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_WaterAquariumPass);
    }
}