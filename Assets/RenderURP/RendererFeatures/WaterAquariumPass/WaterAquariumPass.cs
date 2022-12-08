using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class WaterAquariumPass : ScriptableRenderPass
{
    ProfilingSampler m_ProfilingSampler = new ProfilingSampler(nameof(WaterAquariumPass));
    List<ShaderTagId> m_ShaderTagIdList;
    FilteringSettings m_FilteringSettings;
    RenderStateBlock m_RenderStateBlock;

    public WaterAquariumPass(RenderPassEvent renderPassEvent, IEnumerable<string> lightModeTagList)
    {
        this.renderPassEvent = renderPassEvent;

        m_FilteringSettings = new FilteringSettings(RenderQueueRange.all);
        m_RenderStateBlock = new RenderStateBlock(RenderStateMask.Nothing);

        m_ShaderTagIdList = new List<ShaderTagId>();
        foreach (var lightModeTag in lightModeTagList)
        {
            m_ShaderTagIdList.Add(new ShaderTagId(lightModeTag));
        }
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        // 对排序简单处理
        SortingCriteria sortingCriteria = SortingCriteria.CommonTransparent;

        var drawingSettings = CreateDrawingSettings(m_ShaderTagIdList, ref renderingData, sortingCriteria);
      
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