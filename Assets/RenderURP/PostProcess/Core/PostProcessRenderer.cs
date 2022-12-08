using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Inutan.PostProcessing
{
    // 支持位操作 所以一个效果可以选择配置在不同的位置
    [Flags]
    public enum PostProcessInjectionPoint 
    {
        BeforeRenderingDeferredLights   = 1 << 0,
        AfterRenderingSkybox            = 1 << 1,
        BeforeRenderingPostProcessing   = 1 << 2,
        AfterRenderingPostProcessing    = 1 << 3,
    }


    public abstract class PostProcessRenderer
    {
        static readonly int m_SourceTex = Shader.PropertyToID("_SourceTex");
        bool m_Initialized = false;
        bool m_ShowHide = false;

        public virtual bool visibleInSceneView => true;
        public virtual ScriptableRenderPassInput input => ScriptableRenderPassInput.None;
        // 默认最后都需要渲染到Camera
        public virtual bool renderToCamera => true;
        // 如果明确知道该效果不会出现把source同时作为target的情况
        // dontCareSourceTargetCopy设置为true，则该效果出现在队列第一个时，就不需要拷贝原始RT
        public virtual bool dontCareSourceTargetCopy => false;
        public virtual string name => "";

        public PostProcessFeatureData m_PostProcessFeatureData;
        public PostProcessRenderPass m_RenderPass;
        public ProfilingSampler profilingSampler;

        public abstract bool IsActive();
        internal void SetupInternal(PostProcessRenderPass renderPass, PostProcessFeatureData data)
        {
            if(m_Initialized)
                return;
            m_Initialized = true;

            m_RenderPass = renderPass;
            m_PostProcessFeatureData = data;
            Setup();
        }
        // 只会调用一次
        public virtual void Setup() {}
        public abstract void Render(CommandBuffer cmd, RenderTargetIdentifier source, RenderTargetIdentifier destination, ref RenderingData renderingData);
        public virtual void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData) {}
        public virtual void OnCameraCleanup(CommandBuffer cmd) {}
        public virtual void AddRenderPasses(ref RenderingData renderingData) {}
        // 无论Active是否都会进入
        public virtual void Dispose(bool disposing) {}

        internal void ShowHideInternal()
        {
           if(m_ShowHide != IsActive())
           {
               m_ShowHide = IsActive();
               ShowHide(m_ShowHide);
           }
        }
        public virtual void ShowHide(bool showHide) {}

        public Material GetMaterial(Shader shader)
        {
            if (shader == null)
            {
                Debug.LogError("Missing shader in PostProcessFeatureData");
                return null;
            }
        
            return CoreUtils.CreateEngineMaterial(shader);
        }

        public void InitProfilingSampler()
        {
            var attribute = PostProcessAttribute.GetAttribute(GetType());
            profilingSampler = new ProfilingSampler(attribute?.Name);
        }
        public void Blit(CommandBuffer cmd, RenderTargetIdentifier source, RenderTargetIdentifier destination, Material material, int passIndex = 0)
        {
            cmd.SetGlobalTexture(m_SourceTex, source);
            cmd.Blit(source, destination, material, passIndex);
        }

        public void DescriptorDownSample(ref RenderTextureDescriptor desc, int downSample)
        {
            desc.width = Mathf.Max(Mathf.FloorToInt(desc.width / downSample), 1);
            desc.height = Mathf.Max(Mathf.FloorToInt(desc.height / downSample), 1);
        }
    }

    [Serializable]
    public abstract class VolumeSetting : VolumeComponent, IPostProcessComponent
    {        
        // 只是为了隐式处理点击总的选项开关功能
        [HideInInspector]
        public BoolParameter enabled = new BoolParameter(true, true);
        public abstract bool IsActive();
        public bool IsTileCompatible() => false;
    }

    public abstract class PostProcessVolumeRenderer<T> : PostProcessRenderer where T : VolumeSetting
    {
        public T settings => VolumeManager.instance.stack.GetComponent<T>();
        public override bool IsActive() => settings.active && settings.enabled.overrideState && settings.IsActive();
    }


    public class PostProcessComponentManager
    {
        public Dictionary<Type, PostProcessRenderer> m_PostProcessComponentRenderers = new Dictionary<Type, PostProcessRenderer>();

        private static PostProcessComponentManager m_Instance;

        public static PostProcessComponentManager GetInstance()
        {
            if(m_Instance == null)
            {
                m_Instance = new PostProcessComponentManager();
            }
            return m_Instance;
        }

        public bool AddPostProcessingComponent(PostProcessRenderer renderer)
        {
            return m_PostProcessComponentRenderers.TryAdd(renderer.GetType(), renderer);
        }

        public void DelPostProcessingComponent(PostProcessRenderer renderer)
        {
            m_PostProcessComponentRenderers.Remove(renderer.GetType());
        }
    }

    [ExecuteInEditMode, DisallowMultipleComponent]
    public abstract class PostProcessComponent : MonoBehaviour
    {
        PostProcessComponentRenderer m_Renderer;

        bool m_AddSuccess = false;

        public virtual PostProcessComponentRenderer Create() => null;

        public PostProcessComponent()
        {
            if(m_Renderer == null)
                m_Renderer = Create();
            m_Renderer.m_Component = this;
            m_AddSuccess = PostProcessComponentManager.GetInstance().AddPostProcessingComponent(m_Renderer);
        }
       
        public virtual void Start() {}
        public virtual void OnEnable() {}
        public virtual void OnDisable(){}
        public virtual void OnDestroy()
        {
            if(m_AddSuccess)
                PostProcessComponentManager.GetInstance().DelPostProcessingComponent(m_Renderer);
        }
    }

    public abstract class PostProcessComponentRenderer : PostProcessRenderer
    {
        public PostProcessComponentRenderer()
        {
            profilingSampler = new ProfilingSampler(name);
        }
        
        public PostProcessComponent m_Component;
        public override bool IsActive() => m_Component.enabled;
    }


    [System.AttributeUsage(System.AttributeTargets.Class, Inherited = false, AllowMultiple = false)]
    public sealed class PostProcessAttribute : System.Attribute 
    {
        readonly string name;

        readonly PostProcessInjectionPoint injectionPoint;

        readonly bool shareInstance;
        //
        public string Name => name;

        public PostProcessInjectionPoint InjectionPoint => injectionPoint;

        public bool ShareInstance => shareInstance;

        public PostProcessAttribute(string name, PostProcessInjectionPoint injectionPoint, bool shareInstance = false)
        {
            this.name = name;
            this.injectionPoint = injectionPoint;
            this.shareInstance = shareInstance;
        }

        public static PostProcessAttribute GetAttribute(Type type)
        {
            if(type == null) return null;

            var atttributes = type.GetCustomAttributes(typeof(PostProcessAttribute), false);
            return (atttributes.Length != 0) ? (atttributes[0] as PostProcessAttribute) : null;
        }
    }

    [AttributeUsage(AttributeTargets.All, Inherited = false, AllowMultiple = false)]
    public sealed class DirectHandleAttribute : PropertyAttribute{}

    [Serializable]
    public class DirectionParameter : VolumeParameter<Vector4>
    {
        public DirectionParameter(Vector3 value, bool showHandle, bool overrideState = false)
            : base(new Vector4(value.x, value.y, value.z, showHandle ? 1 : -1), overrideState) { }
    }
}