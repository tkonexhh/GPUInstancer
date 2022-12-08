using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Inutan.PostProcessing
{
    [Serializable, VolumeComponentMenuForRenderPipeline("Post-processing Inutan/TemporalAntialiasing",typeof(UniversalRenderPipeline))]
    public class TemporalAntialiasing : VolumeSetting
    {
        public enum Quality
        {
            Low,
            Medium,
            High
        }
        [Serializable]
        public sealed class QualityParameter : VolumeParameter<Quality> {}

        // ----------------------------------------------------------------------------------------------------
        [Tooltip("SceneView可见")]
        public BoolParameter visibleInSceneView = new BoolParameter(true);

        [Tooltip("使用MotionVector (SceneView没有)")]
        public BoolParameter useMotionVector = new BoolParameter(false);

        [Tooltip("ToneMapping减少闪烁，但是会降低一些高亮的溢出")]
        public BoolParameter useToneMapping = new BoolParameter(false);

        public QualityParameter quality = new QualityParameter { value = Quality.High };
       
        [Space(6)]
        [Tooltip("锐化做的比较轻微且只在HighQuality生效")]
        public ClampedFloatParameter sharpenStrength = new ClampedFloatParameter(0.15f, 0f, 0.5f);

        [Tooltip("历史帧中静止像素混合比例")]
        public ClampedFloatParameter stationaryBlending = new ClampedFloatParameter(0.95f, 0f, 0.99f);

        [Tooltip("历史帧中明显运动帧混合比例")]
        public ClampedFloatParameter motionBlending = new ClampedFloatParameter(0.7f, 0, 0.99f);

        // --------------------------------------------------------------------------------------
        // sharpenBlend antiFlicker 暂时不工作
        // 其他暂用默认值
        [Tooltip("锐化混合只在HighQuality生效")]
        [HideInInspector]
        public ClampedFloatParameter sharpenBlend = new ClampedFloatParameter(0.2f, 0f, 1f);

        [Tooltip("对历史帧做锐化只在HighQuality生效")]
        [HideInInspector]
        public BoolParameter useBicubic = new BoolParameter(false);

        [Tooltip("锐化做的比较轻微且只在HighQuality生效")]
        [HideInInspector]
        public ClampedFloatParameter sharpenHistoryStrength = new ClampedFloatParameter(0.35f, 0f, 1f);

        [Tooltip("降低闪烁")]
        [HideInInspector]
        public ClampedFloatParameter antiFlicker = new ClampedFloatParameter(0.5f, 0, 1f);

        public override bool IsActive() => true;
    }

    [PostProcess("TemporalAntialiasing", PostProcessInjectionPoint.BeforeRenderingPostProcessing)]
    public class TemporalAntialiasingRenderer : PostProcessVolumeRenderer<TemporalAntialiasing>
    {
        static class ShaderConstants
        {
            internal static readonly int PrevViewProjectionMatrix = Shader.PropertyToID("_PrevViewProjectionMatrix");
            internal static readonly int Jitter = Shader.PropertyToID("_Jitter");
            internal static readonly int Params1 = Shader.PropertyToID("_Params1");
            internal static readonly int Params2 = Shader.PropertyToID("_Params2");
            internal static readonly int HistoryTexture = Shader.PropertyToID("_HistoryTexture");

            public static string GetQualityKeyword(TemporalAntialiasing.Quality quality)
            { 
                switch (quality)
                {
                    case TemporalAntialiasing.Quality.Low:
                        return "LOW_QUALITY";
                    case TemporalAntialiasing.Quality.High:
                        return "HIGH_QUALITY";
                    case TemporalAntialiasing.Quality.Medium:
                    default:
                        return "MEDIUM_QUALITY";
                }
            }
        }

        class MultiCameraInfo 
        {
            const int k_NumHistoryTextures = 2;

            RenderTexture[] m_HistoryPingPongRT;

            public Matrix4x4 m_PreviousViewProjectionMatrix = Matrix4x4.zero;
            
            int m_PingPong = 0;
          
            public MultiCameraInfo()
            {
                m_HistoryPingPongRT = new RenderTexture[k_NumHistoryTextures];
            }

            public Matrix4x4 GetSetPreviousVPMatrix(Matrix4x4 curVPMatrix)
            {
                Matrix4x4 preVPMatrix = m_PreviousViewProjectionMatrix == Matrix4x4.zero ? curVPMatrix : m_PreviousViewProjectionMatrix;
                m_PreviousViewProjectionMatrix = curVPMatrix;
                return preVPMatrix;
            }
            public RenderTexture GetHistoryRT(int id)
            {
                return m_HistoryPingPongRT[id];
            }

            public void SetHistoryRT(int id, RenderTexture rt)
            {
                m_HistoryPingPongRT[id] = rt;
            }

            public void GetHistoryPingPongRT(ref RenderTexture rt1, ref RenderTexture rt2)
            {
                int index = m_PingPong;
                m_PingPong = ++m_PingPong % 2;

                rt1 = GetHistoryRT(index);
                rt2 = GetHistoryRT(m_PingPong);
            }

            public void Clear()
            {
                for(int i = 0; i < m_HistoryPingPongRT.Length; i ++)
                {
                    if(m_HistoryPingPongRT[i] != null)
                        RenderTexture.ReleaseTemporary(m_HistoryPingPongRT[i]);
                    m_HistoryPingPongRT[i] = null;
                }
            }
           
        }

        public int sampleIndex { get; private set; }
        const int k_SampleCount = 8;

        Vector2 GenerateRandomOffset()
        {
            // The variance between 0 and the actual halton sequence values reveals noticeable instability
            // in Unity's shadow maps, so we avoid index 0.
            var offset = new Vector2(
                HaltonSequence.Get((sampleIndex & 1023) + 1, 2) - 0.5f,
                HaltonSequence.Get((sampleIndex & 1023) + 1, 3) - 0.5f
            );

            if (++sampleIndex >= k_SampleCount)
                sampleIndex = 0;

            return offset;
        }

        public static Matrix4x4 GetJitteredProjectionMatrix(CameraData cameraData, ref Vector2 jitter)
        {
            var projMatrix = cameraData.camera.projectionMatrix;
            var desc = cameraData.cameraTargetDescriptor;

            jitter = new Vector2(jitter.x / desc.width, jitter.y / desc.height);

            if (cameraData.camera.orthographic)
            {
                projMatrix[0, 3] -= jitter.x * 2;
                projMatrix[1, 3] -= jitter.y * 2;
            }
            else
            {
                projMatrix[0, 2] += jitter.x * 2;
                projMatrix[1, 2] += jitter.y * 2;
            }

            return projMatrix;
        }

        public override bool visibleInSceneView => settings.visibleInSceneView.value;
        public override ScriptableRenderPassInput input => settings.useMotionVector.value ? ScriptableRenderPassInput.Motion : base.input;
        public override bool dontCareSourceTargetCopy => true;

        Material m_TemporalAntialiasingMaterial;
        // ------------------------------------------------------------------------------------
        string[] m_ShaderKeywords = new string[4];

        Matrix4x4 m_PreviousViewProjectionMatrix;
        Vector2 m_Jitter;
        TemporalAntialiasingCamera m_TemporalAntialiasingCamera;
        
        // 为了SceneView的显示 得把历史RT分开存
        Dictionary<int, MultiCameraInfo> m_MultiCameraInfo = new Dictionary<int, MultiCameraInfo>();

        void CheckHistoryRT(int id, int hash, CommandBuffer cmd, RenderTargetIdentifier source, RenderTextureDescriptor desc)
        {
            if(!m_MultiCameraInfo.ContainsKey(hash))
            {
                m_MultiCameraInfo[hash] = new MultiCameraInfo();
            }

            var rt = m_MultiCameraInfo[hash].GetHistoryRT(id);

            if(rt == null || rt.width != desc.width || rt.height != desc.height)
            {
                var newRT = RenderTexture.GetTemporary(desc);
                newRT.name = "_TemporalHistoryRT_" + id;

                // 分辨率改变时还是从上一个历史RT拷贝
                m_RenderPass.Blit(cmd, rt == null ? source : rt, newRT);

                if(rt != null)
                    RenderTexture.ReleaseTemporary(rt);

                m_MultiCameraInfo[hash].SetHistoryRT(id, newRT);
            }
        }

        private void SetupMaterials(ref RenderingData renderingData)
        {
            var cameraData = renderingData.cameraData;

            var width = cameraData.cameraTargetDescriptor.width;
            var height = cameraData.cameraTargetDescriptor.height;

            m_TemporalAntialiasingMaterial.SetMatrix(ShaderConstants.PrevViewProjectionMatrix, m_PreviousViewProjectionMatrix);
            m_TemporalAntialiasingMaterial.SetVector(ShaderConstants.Jitter, m_Jitter);

            float antiFlickerIntensity = Mathf.Lerp(0.0f, 3.5f, settings.antiFlicker.value);
            float contrastForMaxAntiFlicker = 0.7f - Mathf.Lerp(0.0f, 0.3f, Mathf.SmoothStep(0.5f, 1.0f, settings.antiFlicker.value));

            m_TemporalAntialiasingMaterial.SetVector(ShaderConstants.Params1, new Vector4(settings.sharpenStrength.value, antiFlickerIntensity, contrastForMaxAntiFlicker, settings.sharpenHistoryStrength.value));
            m_TemporalAntialiasingMaterial.SetVector(ShaderConstants.Params2, new Vector4(settings.sharpenBlend.value, settings.stationaryBlending.value, settings.motionBlending.value, 0));

            // -------------------------------------------------------------------------------------------------
            // local shader keywords
            m_ShaderKeywords[0] = ShaderConstants.GetQualityKeyword(settings.quality.value);
            m_ShaderKeywords[1] = (!cameraData.isSceneViewCamera && settings.useMotionVector.value) ? "_USEMOTIONVECTOR" : "_";
            m_ShaderKeywords[2] = settings.useToneMapping.value ? "_USETONEMAPPING" : "_";
            m_ShaderKeywords[3] = settings.useBicubic.value ? "_USEBICUBIC5TAP" : "_";
            m_TemporalAntialiasingMaterial.shaderKeywords = m_ShaderKeywords;
        }
     
        void Clear()
        {
            foreach (var info in m_MultiCameraInfo)
            {
                if (info.Value != null)
                    info.Value.Clear();
            }
            m_MultiCameraInfo.Clear();

            sampleIndex = 0;
        }

        public override void Setup()
        {
            m_TemporalAntialiasingMaterial = GetMaterial(m_PostProcessFeatureData.shaders.temporalAntialiasingPS);
            m_TemporalAntialiasingCamera = new TemporalAntialiasingCamera();
        }
        public override void ShowHide(bool showHide)
        {
            if(!showHide)
            {
                Clear();
            }
        }

        public override void Dispose(bool disposing) 
        {
            CoreUtils.Destroy(m_TemporalAntialiasingMaterial);
            Clear();
        }

        public override void AddRenderPasses(ref RenderingData renderingData)
        {
            CameraData cameraData = renderingData.cameraData;
            Camera camera = cameraData.camera;
            int hash = camera.GetHashCode();

            if(!m_MultiCameraInfo.ContainsKey(hash))
            {
                m_MultiCameraInfo[hash] = new MultiCameraInfo();
            }
            Matrix4x4 curVPMatrix = camera.projectionMatrix * camera.worldToCameraMatrix;
            m_PreviousViewProjectionMatrix = m_MultiCameraInfo[hash].GetSetPreviousVPMatrix(curVPMatrix);
            // -------------------------------------------------------------------------------------
            // TODO jitterSpread
            Vector2 jitter = GenerateRandomOffset();
            Matrix4x4 jitterredProjectMatrix = GetJitteredProjectionMatrix(cameraData, ref jitter);
            m_Jitter = jitter;

            // camera setup
            m_TemporalAntialiasingCamera.Setup(jitterredProjectMatrix);
            renderingData.cameraData.renderer.EnqueuePass(m_TemporalAntialiasingCamera);
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData) {}
        public override void OnCameraCleanup(CommandBuffer cmd) {}

        public override void Render(CommandBuffer cmd, RenderTargetIdentifier source, RenderTargetIdentifier target, ref RenderingData renderingData)
        {
            RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;
            desc.msaaSamples = 1;
            desc.depthBufferBits = 0;

            Camera camera = renderingData.cameraData.camera;

            //
            SetupMaterials(ref renderingData);

            int hash = camera.GetHashCode();
            CheckHistoryRT(0, hash, cmd, source, desc);
            CheckHistoryRT(1, hash, cmd, source, desc);

            RenderTexture rt1 = null, rt2 = null;
            m_MultiCameraInfo[hash].GetHistoryPingPongRT(ref rt1, ref rt2);

            //
            cmd.SetGlobalTexture(ShaderConstants.HistoryTexture, rt1);
            Blit(cmd, source, rt2, m_TemporalAntialiasingMaterial, 0);
            //
            m_RenderPass.Blit(cmd, rt2, target);
        }
    }
}
