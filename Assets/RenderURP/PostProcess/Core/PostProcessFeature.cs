using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering.Universal;

namespace Inutan.PostProcessing
{
    public class PostProcessFeature : ScriptableRendererFeature
    {
        [System.Serializable]
        public class PostProcessSettings
        {
            [SerializeField]
            public PostProcessFeatureData m_PostProcessFeatureData;

            [SerializeField]
            public List<string> m_RenderersBeforeRenderingDeferredLights, m_RenderersAfterRenderingSkybox, m_RenderersBeforeRenderingPostProcessing, m_RenderersAfterRenderingPostProcessing;

            public PostProcessSettings()
            {
                m_RenderersBeforeRenderingDeferredLights = new List<string>();
                m_RenderersAfterRenderingSkybox          = new List<string>();
                m_RenderersBeforeRenderingPostProcessing = new List<string>();
                m_RenderersAfterRenderingPostProcessing  = new List<string>();
            }
        }

        [SerializeField] public PostProcessSettings m_Settings = new PostProcessSettings();

        PostProcessRenderPass m_BeforeRenderingDeferredLights, m_AfterRenderingSkybox, m_BeforeRenderingPostProcessing, m_AfterRenderingPostProcessing;

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            if(m_Settings.m_PostProcessFeatureData == null)
            {
                Debug.LogError("Please Add PostProcessFeatureData To PostProcessFeature");
                return;
            }
            // 暂时插入在这个三个位置
            if(renderingData.cameraData.postProcessEnabled) 
            {
                m_BeforeRenderingDeferredLights.AddRenderPasses(ref renderingData);
                m_AfterRenderingSkybox.AddRenderPasses(ref renderingData);
                m_BeforeRenderingPostProcessing.AddRenderPasses(ref renderingData);
                // 暂时不考虑 Camera stack 的情况
                m_AfterRenderingPostProcessing.AddRenderPasses(ref renderingData);
            }
        }

        public override void Create()
        {
            // GraphicsSettings.currentRenderPipeline as UniversalRenderPipelineAsset 获取不到renderfeature

            // TODO 页面操作会进入这里 
            Dictionary<string, PostProcessRenderer> shared = new Dictionary<string, PostProcessRenderer>();
            m_BeforeRenderingDeferredLights = new PostProcessRenderPass(PostProcessInjectionPoint.BeforeRenderingDeferredLights, 
                                InstantiateRenderers(m_Settings.m_RenderersBeforeRenderingDeferredLights, shared), 
                                m_Settings.m_PostProcessFeatureData);
            m_AfterRenderingSkybox = new PostProcessRenderPass(PostProcessInjectionPoint.AfterRenderingSkybox, 
                                InstantiateRenderers(m_Settings.m_RenderersAfterRenderingSkybox, shared), 
                                m_Settings.m_PostProcessFeatureData);
            // 外挂后处理目前只放在这个位置
            m_BeforeRenderingPostProcessing  = new PostProcessRenderPass(PostProcessInjectionPoint.BeforeRenderingPostProcessing,  
                                InstantiateRenderers(m_Settings.m_RenderersBeforeRenderingPostProcessing, shared), 
                                m_Settings.m_PostProcessFeatureData, ref PostProcessComponentManager.GetInstance().m_PostProcessComponentRenderers);
            m_AfterRenderingPostProcessing  = new PostProcessRenderPass(PostProcessInjectionPoint.AfterRenderingPostProcessing,  
                                InstantiateRenderers(m_Settings.m_RenderersAfterRenderingPostProcessing, shared), 
                                m_Settings.m_PostProcessFeatureData);
        }

        protected override void Dispose(bool disposing)
        {
            m_BeforeRenderingDeferredLights.Dispose(disposing);
            m_AfterRenderingSkybox.Dispose(disposing);
            m_BeforeRenderingPostProcessing.Dispose(disposing);
            m_AfterRenderingPostProcessing.Dispose(disposing);
        }

        // 根据Attribute定义 收集子类
        private List<PostProcessRenderer> InstantiateRenderers(List<String> names, Dictionary<string, PostProcessRenderer> shared)
        {
            var renderers = new List<PostProcessRenderer>(names.Count);
            foreach(var name in names)
            {
                if(shared.TryGetValue(name, out var renderer))
                {
                    renderers.Add(renderer);
                } 
                else 
                {
                    var type = Type.GetType(name);
                    if(type == null || !type.IsSubclassOf(typeof(PostProcessRenderer))) continue;
                    var attribute = PostProcessAttribute.GetAttribute(type);
                    if(attribute == null) continue;

                    renderer = Activator.CreateInstance(type) as PostProcessRenderer;
                    renderers.Add(renderer);
                    
                    if(attribute.ShareInstance)
                        shared.Add(name, renderer);
                }
            }
            return renderers;
        }
    }
}