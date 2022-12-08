using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Inutan.PostProcessing
{
    [Serializable, VolumeComponentMenuForRenderPipeline("Post-processing Inutan/LightShaft",typeof(UniversalRenderPipeline))]
    public class LightShaft : VolumeSetting
    {
        public enum Quality
        {
            Low,
            Medium,
            High
        }
        public enum DebugMode
        {
            Disabled,
            Prefilter,
            LightShaftOnly,
        }
        [Serializable]
        public sealed class QualityParameter : VolumeParameter<Quality> {}
        [Serializable]
        public class DebugModeParameter : VolumeParameter<DebugMode> { }
        // ----------------------------------------------------------------------------------------------------

        [Tooltip("分辨率, 模糊采样次数, 模糊迭代次数")]
        public QualityParameter quality = new QualityParameter { value = Quality.Medium };

        [Space(6)]
        [Tooltip("强度")]
        public ClampedFloatParameter intensity = new ClampedFloatParameter(1f, 0f, 10f);

        [Tooltip("颜色")]
        public ColorParameter color = new ColorParameter(Color.gray, false, false, false);

        [Tooltip("光源周围圆形范围衰减半径")]
        public ClampedFloatParameter radius = new ClampedFloatParameter(1.5f, 0.001f, 1.5f);

        [Tooltip("扩散范围")]
        public ClampedFloatParameter density = new ClampedFloatParameter(1f, 0.1f, 1f);
       
        [Tooltip("深度阈值")]
        public ClampedFloatParameter threshold = new ClampedFloatParameter(0.018f, 0.001f, 0.9f);

        [Tooltip("光源方向, 打开勾选可以在SceneView中Gizmos控制")]
        [DirectHandle]
        public DirectionParameter mainLightDir = new DirectionParameter(Vector3.zero, false, false);

        public DebugModeParameter debugMode = new DebugModeParameter { value = DebugMode.Disabled };

        public override bool IsActive() => intensity.overrideState && intensity.value > 0 && mainLightDir.overrideState;
    }

    // TODO 需要一个ToneMapping之前的流程 现在放前面会受到bloom影响 放后面没有ToneMapping
    [PostProcess("LightShaft", PostProcessInjectionPoint.BeforeRenderingPostProcessing | PostProcessInjectionPoint.AfterRenderingPostProcessing)]
    public class LightShaftRenderer : PostProcessVolumeRenderer<LightShaft>
    {
        static class ShaderConstants
        {
            internal static readonly int RadialBlurTempRT_1 = Shader.PropertyToID("_RadialBlurTempRT_1");
            internal static readonly int RadialBlurTempRT_2 = Shader.PropertyToID("_RadialBlurTempRT_2");
            internal static readonly int LightShaftTex = Shader.PropertyToID("_LightShaftTex");
            internal static readonly int MainLightUV = Shader.PropertyToID("_MainLightUV");
            internal static readonly int Params = Shader.PropertyToID("_Params");
            internal static readonly int Color = Shader.PropertyToID("_Color");

            public static string GetQualityKeyword(LightShaft.Quality quality)
            {
                switch (quality)
                {
                    case LightShaft.Quality.Low:
                        return "QUALITY_LOW";
                    case LightShaft.Quality.High:
                        return "QUALITY_HIGH";
                    case LightShaft.Quality.Medium:
                    default:
                        return "QUALITY_MEDIUM";
                }
            }

            public static string GetDebugKeyword(LightShaft.DebugMode debugMode)
            { 
                switch (debugMode)
                {
                    case LightShaft.DebugMode.Prefilter:
                        return "DEBUG_PREFILTER";
                    case LightShaft.DebugMode.LightShaftOnly:
                        return "DEBUG_LIGHTSHAFTONLY";
                    case LightShaft.DebugMode.Disabled:
                    default:
                        return "_";
                }
            }
        }

        Material m_LightShaftMaterial;

        bool m_OutsideScreen = false;
        // ------------------------------------------------------------------------------------
        string[] m_ShaderKeywords = new string[2];
        
        private void SetupMaterials(ref RenderingData renderingData)
        {
            var camera = renderingData.cameraData.camera;

            Vector4 mainLightDir = settings.mainLightDir.value;
            var mainLightUV = camera.WorldToViewportPoint(camera.transform.position - (Quaternion.Euler(mainLightDir.x, mainLightDir.y, mainLightDir.z) * Vector3.forward));

            m_OutsideScreen = mainLightUV.z <= 0;
            if(m_OutsideScreen)
                return;

            m_LightShaftMaterial.SetVector(ShaderConstants.MainLightUV, mainLightUV);
            m_LightShaftMaterial.SetVector(ShaderConstants.Params, new Vector4(settings.intensity.value, settings.radius.value, settings.density.value, settings.threshold.value));
            m_LightShaftMaterial.SetColor(ShaderConstants.Color, settings.color.value.linear);

            // -------------------------------------------------------------------------------------------------
            // local shader keywords
            m_ShaderKeywords[0] = ShaderConstants.GetQualityKeyword(settings.quality.value);
            m_ShaderKeywords[1] = ShaderConstants.GetDebugKeyword(settings.debugMode.value);
            m_LightShaftMaterial.shaderKeywords = m_ShaderKeywords;
        }
     
        public override void Setup()
        {
            m_LightShaftMaterial = GetMaterial(m_PostProcessFeatureData.shaders.lightShaftPS);
        }

        public override void Dispose(bool disposing) 
        {
            CoreUtils.Destroy(m_LightShaftMaterial);
        }

        public override void Render(CommandBuffer cmd, RenderTargetIdentifier source, RenderTargetIdentifier target, ref RenderingData renderingData)
        {
            var desc = renderingData.cameraData.cameraTargetDescriptor;
            desc.msaaSamples = 1;
            desc.depthBufferBits = 0;
            if(settings.quality.value != LightShaft.Quality.High)
                DescriptorDownSample(ref desc, 4);

            //
            SetupMaterials(ref renderingData);

            if(m_OutsideScreen)
            {
                m_RenderPass.Blit(cmd, source, target);
                return;
            }

            if(settings.debugMode.value == LightShaft.DebugMode.Prefilter)
            {
                Blit(cmd, source, target, m_LightShaftMaterial, 0);
                return;
            }

            int fromId = ShaderConstants.RadialBlurTempRT_1;
            int toId = ShaderConstants.RadialBlurTempRT_2;

            cmd.GetTemporaryRT(fromId, desc, FilterMode.Bilinear);
            cmd.GetTemporaryRT(toId, desc, FilterMode.Bilinear);

            // Prefilter
            Blit(cmd, source, fromId, m_LightShaftMaterial, 0);

            // Radial Blur
            int iter = settings.quality.value == LightShaft.Quality.Low ? 3 : 4;
            for (int i = 0; i < iter; i++)
            {
                Blit(cmd, fromId, toId, m_LightShaftMaterial, 1);
                CoreUtils.Swap(ref fromId, ref toId);
            }

            // Composite
            cmd.SetGlobalTexture(ShaderConstants.LightShaftTex, toId);
            Blit(cmd, source, target, m_LightShaftMaterial, 2);

            cmd.ReleaseTemporaryRT(fromId);
            cmd.ReleaseTemporaryRT(toId);
        }
    }
}
