using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class WaterAquariumInnerPass : ScriptableRenderPass
{
    ProfilingSampler m_ProfilingSampler = new ProfilingSampler(nameof(WaterAquariumInnerPass));
    ShaderTagId m_ShaderTagId;
    FilteringSettings m_FilteringSettings;
    RenderStateBlock m_RenderStateBlock;

    public WaterAquariumInnerPass(RenderPassEvent renderPassEvent, string lightModeTag)
    {
        this.renderPassEvent = renderPassEvent;

        m_FilteringSettings = new FilteringSettings(RenderQueueRange.all);
        m_RenderStateBlock = new RenderStateBlock(RenderStateMask.Nothing);

        m_ShaderTagId = new ShaderTagId(lightModeTag);
    }


    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        // 对排序简单处理
        SortingCriteria sortingCriteria = SortingCriteria.CommonTransparent;

        var drawingSettings = CreateDrawingSettings(m_ShaderTagId, ref renderingData, sortingCriteria);
      
        var cmd = CommandBufferPool.Get();
        using (new ProfilingScope(cmd, m_ProfilingSampler))
        {
            // Ensure we flush our command-buffer before we render...
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();

            // Render objects with specified LightModes After GrabPass.
            context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref m_FilteringSettings, ref m_RenderStateBlock);
        }

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

}