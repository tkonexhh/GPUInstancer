using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Inutan.PostProcessing
{
    public class PostProcessRenderPass : ScriptableRenderPass
    {
        Dictionary<Type, PostProcessRenderer> m_PostProcessComponentRenderers;
        List<PostProcessRenderer> m_PostProcessRenderers;
        List<PostProcessRenderer> m_ActivePostProcessRenderers;
        string m_PassName;

        PostProcessFeatureData m_PostProcessFeatureData;

        RenderTargetHandle m_TempRT0;
        RenderTargetHandle m_TempRT1;
        public bool HasPostProcessRenderers => m_PostProcessRenderers.Count != 0 || m_PostProcessComponentRenderers?.Count != 0;

        public PostProcessRenderPass(PostProcessInjectionPoint injectionPoint, 
                                    List<PostProcessRenderer> renderers, 
                                    PostProcessFeatureData data,
                                    ref Dictionary<Type, PostProcessRenderer> componentRenderers)
                                    : this(injectionPoint, renderers, data)
        {
            m_PostProcessComponentRenderers = componentRenderers;
        }

        public PostProcessRenderPass(PostProcessInjectionPoint injectionPoint, 
                                    List<PostProcessRenderer> renderers, 
                                    PostProcessFeatureData data)
        {
            m_PostProcessRenderers = renderers;
            m_PostProcessFeatureData = data;

            foreach(var renderer in m_PostProcessRenderers)
            {
                renderer.InitProfilingSampler();
            }

            m_ActivePostProcessRenderers = new List<PostProcessRenderer>();

            switch(injectionPoint)
            {
                case PostProcessInjectionPoint.BeforeRenderingDeferredLights: 
                    renderPassEvent = RenderPassEvent.BeforeRenderingDeferredLights;
                    m_PassName = "PostProcessRenderPass BeforeRenderingDeferredLights";
                    break;
                case PostProcessInjectionPoint.AfterRenderingSkybox: 
                    // +1 为了放在MotionVector后面
                    renderPassEvent = RenderPassEvent.AfterRenderingSkybox + 1;
                    m_PassName = "PostProcessRenderPass AfterRenderingSkybox";
                    break;
                case PostProcessInjectionPoint.BeforeRenderingPostProcessing: 
                    renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
                    m_PassName = "PostProcessRenderPass BeforeRenderingPostProcessing";
                    break;
                case PostProcessInjectionPoint.AfterRenderingPostProcessing:
                    renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing;
                    m_PassName = "PostProcessRenderPass AfterRenderingPostProcessing";
                    break;
            }

            m_TempRT0.Init("_TempRT0");
            m_TempRT1.Init("_TempRT1");
        }


        public void AddRenderPasses(ref RenderingData renderingData)
        {
            if(!HasPostProcessRenderers)
                return;

            if(!Setup(ref renderingData))
                return;

            renderingData.cameraData.renderer.EnqueuePass(this);
        }

        private bool RenderInit(bool isSceneView, 
                                ref PostProcessRenderer postProcessRenderer, 
                                ref ScriptableRenderPassInput passInput, 
                                ref RenderingData renderingData)
        {
            if(isSceneView && !postProcessRenderer.visibleInSceneView) return false;

            if(postProcessRenderer.IsActive())
            {
                postProcessRenderer.SetupInternal(this, m_PostProcessFeatureData);
                postProcessRenderer.AddRenderPasses(ref renderingData);

                m_ActivePostProcessRenderers.Add(postProcessRenderer);
                passInput |= postProcessRenderer.input;
            }
            postProcessRenderer.ShowHideInternal();

            return true;
        }

        public bool Setup(ref RenderingData renderingData)
        {
            bool isSceneView = renderingData.cameraData.isSceneViewCamera;
            // TODO isPreviewCamera

            ScriptableRenderPassInput passInput = ScriptableRenderPassInput.None;

            m_ActivePostProcessRenderers.Clear();

            for(int index = 0; index < m_PostProcessRenderers.Count; index++)
            {
                var postProcessRenderer = m_PostProcessRenderers[index];
                //
                if(!RenderInit(isSceneView, ref postProcessRenderer, ref passInput, ref renderingData))
                    continue;
            }
            
            // 非volume体系的外挂后处理
            if(m_PostProcessComponentRenderers != null)
            {
                foreach(var v in m_PostProcessComponentRenderers)
                {
                    var postProcessRenderer = v.Value;
                    // 
                    if(!RenderInit(isSceneView, ref postProcessRenderer, ref passInput, ref renderingData))
                        continue;
                }
            }

            // 放在外部先
            ConfigureInput(passInput);

            return m_ActivePostProcessRenderers.Count != 0;
        } 

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            //
            for(int index = 0; index < m_ActivePostProcessRenderers.Count; index++)
            {
                m_ActivePostProcessRenderers[index].OnCameraSetup(cmd, ref renderingData);
            }

            //
            RenderTextureDescriptor sourceDesc = renderingData.cameraData.cameraTargetDescriptor;
            sourceDesc.msaaSamples = 1;
            sourceDesc.depthBufferBits = 0;

            cmd.GetTemporaryRT(m_TempRT0.id, sourceDesc);
            cmd.GetTemporaryRT(m_TempRT1.id, sourceDesc);
        }

        // 在OnCameraSetup之后Execute之前，暂时先不放在这个阶段
        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor) {}

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            //
            for(int index = 0; index < m_ActivePostProcessRenderers.Count; index++)
            {
                m_ActivePostProcessRenderers[index].OnCameraCleanup(cmd);
            }

            //
            cmd.ReleaseTemporaryRT(m_TempRT0.id);
            cmd.ReleaseTemporaryRT(m_TempRT1.id);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var cmd = CommandBufferPool.Get(m_PassName);
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();

            RenderTargetIdentifier cameraColorTarget = renderingData.cameraData.renderer.cameraColorTarget;
            RenderTargetIdentifier source = cameraColorTarget;
            RenderTargetIdentifier target = m_TempRT0.id;

            for(int index = 0; index < m_ActivePostProcessRenderers.Count; ++index)
            {
                var renderer = m_ActivePostProcessRenderers[index];

                if(!renderer.renderToCamera)
                {
                    // 不需要渲染到最终摄像机 就无所谓RT切换 (注意: 最终输出完全取决于内部 如果在队列最后一个 可能会导致RT没能切回摄像机)
                    using(new ProfilingScope(cmd,  renderer.profilingSampler))
                    {
                        renderer.Render(cmd, source, 0, ref renderingData);
                    }
                    continue;
                }

                // --------------------------------------------------------------------------
                if(index == m_ActivePostProcessRenderers.Count - 1)
                {
                    // 最后一个 target 正常必须是 m_CameraColorTarget
                    // 如果 source == m_CameraColorTarget 则需要把 m_CameraColorTarget copyto RT
                    if(source == cameraColorTarget && !renderer.dontCareSourceTargetCopy)
                    {
                        // blit source: m_CameraColorTarget target: m_TempRT
                        // copy
                        // swap source: m_TempRT target: m_CameraColorTarget
                        Blit(cmd, source, target);
                        CoreUtils.Swap(ref source, ref target);
                    }
                    target = cameraColorTarget;
                }
                else
                {
                    // 不是最后一个时 如果 target == m_CameraColorTarget 就改成非souce的那个RT
                    // source: lastRT target: nextRT
                    if(target == cameraColorTarget)
                    {
                        target = source == m_TempRT0.id ? m_TempRT1.id : m_TempRT0.id;
                    }
                }
                    
                using(new ProfilingScope(cmd,  renderer.profilingSampler))
                {
                    renderer.Render(cmd, source, target, ref renderingData);
                    CoreUtils.Swap(ref source, ref target);
                }
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public void Dispose(bool disposing)
        {
            //
            for(int index = 0; index < m_PostProcessRenderers.Count; index++)
            {
                m_PostProcessRenderers[index].Dispose(disposing);
            }
        }

    }
}