
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class AfterGrabPass : ScriptableRenderPass
{
    ProfilingSampler m_ProfilingSampler = new ProfilingSampler(nameof(AfterGrabPass));
    List<ShaderTagId> m_ShaderTagIdList;
    FilteringSettings m_FilteringSettings;
    RenderStateBlock m_RenderStateBlock;

    public AfterGrabPass(RenderPassEvent renderPassEvent, IEnumerable<string> lightModeTagList)
    {
        this.renderPassEvent = renderPassEvent + 1;

        // 暂不需要LayerMask
        m_FilteringSettings = new FilteringSettings(RenderQueueRange.all);
        // 
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
        SortingCriteria sortingCriteria = (renderPassEvent > RenderPassEvent.AfterRenderingSkybox)
            ? SortingCriteria.CommonTransparent
            : renderingData.cameraData.defaultOpaqueSortFlags;

        var drawingSettings = CreateDrawingSettings(m_ShaderTagIdList, ref renderingData, sortingCriteria);

        //
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