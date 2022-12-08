using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.Universal.Internal;


public class AfterTransparentPass : ScriptableRenderPass
{
    ProfilingSampler m_ProfilingSampler = new ProfilingSampler(nameof(AfterTransparentPass));
    List<ShaderTagId> m_ShaderTagIdList;
    FilteringSettings m_FilteringSettings;
    RenderStateBlock m_RenderStateBlock;

    public AfterTransparentPass(RenderPassEvent renderPassEvent, IEnumerable<string> lightModeTagList)
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

    public void Setup()
    {
        // 把CopyDepthPass移动到该Pass之前
        ScriptableRenderPassInput passInput = ScriptableRenderPassInput.Depth;
        ConfigureInput(passInput);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        var sortFlags = SortingCriteria.CommonTransparent;
        var drawSettings = CreateDrawingSettings(m_ShaderTagIdList, ref renderingData, sortFlags);

        // MARK 如果CommandBufferPool.Get(nameof(AfterTransparentPass)) 就会和 ProfilingScope 重复添加调试标签
        CommandBuffer cmd = CommandBufferPool.Get();
        using (new ProfilingScope(cmd, m_ProfilingSampler))
        {
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
        
            context.DrawRenderers(renderingData.cullResults, ref drawSettings, ref m_FilteringSettings, ref m_RenderStateBlock);
        }
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }
}
