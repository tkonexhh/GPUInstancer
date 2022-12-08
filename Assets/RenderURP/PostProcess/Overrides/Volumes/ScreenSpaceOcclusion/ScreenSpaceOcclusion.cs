using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Inutan.PostProcessing
{
    [Serializable, VolumeComponentMenuForRenderPipeline("Post-processing Inutan/ScreenSpaceOcclusion",typeof(UniversalRenderPipeline))]
    public class ScreenSpaceOcclusion : VolumeSetting
    {
        public enum AOType
        {
            HorizonBasedAmbientOcclusion,
            GroundTruthBasedAmbientOcclusion,
            ScalableAmbientObscurance,
        }
        public enum Quality
        {
            Lowest,
            Low,
            Medium,
            High,
            Highest
        }
        public enum Resolution
        {
            Full,
            Half
        }
        public enum BlurType
        {
            None,
            x2,
            x3,
            x4,
            x5
        }
        public enum ReconstructNormal
        {
            Disabled,
            Low,
            Medium,
            High,
        }
        public enum DebugMode
        {
            Disabled,
            AOOnly,
            ViewNormal,
        }

        [Serializable]
        public sealed class AOTypeParameter : VolumeParameter<AOType> {}
        [Serializable]
        public sealed class QualityParameter : VolumeParameter<Quality> {}
        [Serializable]
        public sealed class ResolutionParameter : VolumeParameter<Resolution> {}
        [Serializable]
        public sealed class BlurTypeParameter : VolumeParameter<BlurType> {}
        [Serializable]
        public sealed class ReconstructNormalParameter : VolumeParameter<ReconstructNormal> {}
        [Serializable]
        public sealed class DebugModeParameter : VolumeParameter<DebugMode> {}

        // ----------------------------------------------------------------------------------------------------
        [Tooltip("类型 HBAO/GTAO")]
        public AOTypeParameter type = new AOTypeParameter { value = AOType.HorizonBasedAmbientOcclusion };

        [Tooltip("可见性估算采样数")]
        public QualityParameter quality = new QualityParameter { value = Quality.Medium };

        [Tooltip("分辨率")]
        public ResolutionParameter resolution = new ResolutionParameter { value = Resolution.Full };

        [Tooltip("利用深度重建法线, 可以消除原始法线带来的一些不必要的高频信息, 有额外消耗")]
        public ReconstructNormalParameter reconstructNormal = new ReconstructNormalParameter { value = ReconstructNormal.Disabled };

        [Space(6)]
        [Tooltip("强度")]
        public ClampedFloatParameter intensity = new ClampedFloatParameter(0f, 0, 4f);

        [Tooltip("采样半径")]
        public ClampedFloatParameter radius = new ClampedFloatParameter(0.8f, 0f, 10f);

        [Tooltip("像素层级采样半径限制")]
        public ClampedFloatParameter maxRadiusPixels = new ClampedFloatParameter(128f, 16f, 512f);

        [Tooltip("由于几何面连续性问题, 实际可见性会被多算, 偏移用以弥补")]
        public ClampedFloatParameter bias = new ClampedFloatParameter(0.5f, 0f, 0.99f);

        [Tooltip("GTAO中使用, 减少薄的物体AO过度的问题")]
        public ClampedFloatParameter thickness = new ClampedFloatParameter(0f, 0, 1f);

        [Tooltip("直接光部分AO遮蔽强度")]
        public ClampedFloatParameter directLightingStrength = new ClampedFloatParameter(0.25f, 0, 1f);

        [Tooltip("最大距离范围")]
        public FloatParameter maxDistance = new FloatParameter(150f);

        [Tooltip("距离衰减")]
        public FloatParameter distanceFalloff = new FloatParameter(50f);

        [Tooltip("模糊采样次数")]
        public BlurTypeParameter blurType = new BlurTypeParameter { value = BlurType.x3 };

        [Tooltip("锐化")]
        public ClampedFloatParameter sharpness = new ClampedFloatParameter(8f, 0f, 16f);

        [Tooltip("植物SSAO淡化")]
        public ClampedFloatParameter foliageFade = new ClampedFloatParameter(0f, 0f, 1f);

        public DebugModeParameter debugMode = new DebugModeParameter { value = DebugMode.Disabled };

        public override bool IsActive() => intensity.value > 0;
    }

    [PostProcess("ScreenSpaceOcclusion", PostProcessInjectionPoint.BeforeRenderingDeferredLights)]
    public class ScreenSpaceOcclusionRenderer : PostProcessVolumeRenderer<ScreenSpaceOcclusion>
    {
        static class ShaderConstants
        {

            internal static readonly int OcclusionDepthTex = Shader.PropertyToID("_OcclusionDepthTex");
            internal static readonly int OcclusionTempTex = Shader.PropertyToID("_OcclusionTempTex");
            internal static readonly int OcclusionFinalTex = Shader.PropertyToID("_OcclusionFinalTex");
            internal static readonly int FullTexelSize = Shader.PropertyToID("_Full_TexelSize");
            internal static readonly int ScaledTexelSize = Shader.PropertyToID("_Scaled_TexelSize");
            internal static readonly int TargetScale = Shader.PropertyToID("_TargetScale");
            internal static readonly int UVToView = Shader.PropertyToID("_UVToView");
            internal static readonly int WorldToCameraMatrix = Shader.PropertyToID("_WorldToCameraMatrix");
            internal static readonly int Radius = Shader.PropertyToID("_Radius");
            internal static readonly int RadiusToScreen = Shader.PropertyToID("_RadiusToScreen");
            internal static readonly int MaxRadiusPixels = Shader.PropertyToID("_MaxRadiusPixels");
            internal static readonly int InvRadius2 = Shader.PropertyToID("_InvRadius2");
            internal static readonly int AngleBias = Shader.PropertyToID("_AngleBias");
            internal static readonly int AOMultiplier = Shader.PropertyToID("_AOMultiplier");
            internal static readonly int Intensity = Shader.PropertyToID("_Intensity");
            internal static readonly int Thickness = Shader.PropertyToID("_Thickness");
            internal static readonly int MaxDistance = Shader.PropertyToID("_MaxDistance");
            internal static readonly int DistanceFalloff = Shader.PropertyToID("_DistanceFalloff");
            internal static readonly int BlurSharpness = Shader.PropertyToID("_BlurSharpness");
            internal static readonly int CameraProjMatrix = Shader.PropertyToID("_CameraProjMatrix");

            public static string GetAOTypeKeyword(ScreenSpaceOcclusion.AOType type)
            {
                switch (type)
                {
                    case ScreenSpaceOcclusion.AOType.GroundTruthBasedAmbientOcclusion:
                        return "GROUNDTRUTH_BASED_AMBIENTOCCLUSION";
                    case ScreenSpaceOcclusion.AOType.ScalableAmbientObscurance:
                        return "SCALABLE_AMBIENT_OBSCURANCE";
                    case ScreenSpaceOcclusion.AOType.HorizonBasedAmbientOcclusion:
                    default:
                        return "HORIZON_BASED_AMBIENTOCCLUSION";
                }
            }
            public static string GetQualityKeyword(ScreenSpaceOcclusion.Quality quality)
            {
                switch (quality)
                {
                    case ScreenSpaceOcclusion.Quality.Lowest:
                        return "QUALITY_LOWEST";
                    case ScreenSpaceOcclusion.Quality.Low:
                        return "QUALITY_LOW";
                    case ScreenSpaceOcclusion.Quality.Medium:
                        return "QUALITY_MEDIUM";
                    case ScreenSpaceOcclusion.Quality.High:
                        return "QUALITY_HIGH";
                    case ScreenSpaceOcclusion.Quality.Highest:
                        return "QUALITY_HIGHEST";
                    default:
                        return "QUALITY_MEDIUM";
                }
            }

            public static string GetBlurRadiusKeyword(ScreenSpaceOcclusion.BlurType blurType)
            {
                switch (blurType)
                {
                    case ScreenSpaceOcclusion.BlurType.x2:
                        return "BLUR_RADIUS_2";
                    case ScreenSpaceOcclusion.BlurType.x3:
                        return "BLUR_RADIUS_3";
                    case ScreenSpaceOcclusion.BlurType.x4:
                        return "BLUR_RADIUS_4";
                    case ScreenSpaceOcclusion.BlurType.x5:
                        return "BLUR_RADIUS_5";
                    case ScreenSpaceOcclusion.BlurType.None:
                    default:
                        return "BLUR_RADIUS_3";
                }
            }
            public static string GetReconstructNormal(ScreenSpaceOcclusion.ReconstructNormal reconstructNormal)
            {
                switch (reconstructNormal)
                {
                    case ScreenSpaceOcclusion.ReconstructNormal.Low:
                        return "RECONSTRUCT_NORMAL_LOW";
                    case ScreenSpaceOcclusion.ReconstructNormal.Medium:
                        return "RECONSTRUCT_NORMAL_MEDIUM";
                    case ScreenSpaceOcclusion.ReconstructNormal.High:
                        return "RECONSTRUCT_NORMAL_HIGH";
                    case ScreenSpaceOcclusion.ReconstructNormal.Disabled:
                    default:
                        return "_";
                }
            }
            public static string GetDebugKeyword(ScreenSpaceOcclusion.DebugMode debugMode)
            {
                switch (debugMode)
                {
                    case ScreenSpaceOcclusion.DebugMode.AOOnly:
                        return "DEBUG_AO";
                    case ScreenSpaceOcclusion.DebugMode.ViewNormal:
                        return "DEBUG_VIEWNORMAL";
                    case ScreenSpaceOcclusion.DebugMode.Disabled:
                    default:
                        return "_";
                }
            }
        }

        public override bool renderToCamera => false;

        Material m_AmbientOcclusionMaterial;

        // ------------------------------------------------------------------------------------
        string[] m_ShaderKeywords = new string[5];

        RenderTextureDescriptor m_AmbientOcclusionDescriptor;

        RenderTextureFormat m_AmbientOcclusionColorFormat;

        ScreenSpaceOcclusionDebug m_DebugPass;

        private void SetupMaterials(ref RenderingData renderingData)
        {
            var cameraData = renderingData.cameraData;

            var width = cameraData.cameraTargetDescriptor.width;
            var height = cameraData.cameraTargetDescriptor.height;
            var widthAO = m_AmbientOcclusionDescriptor.width;
            var heightAO = m_AmbientOcclusionDescriptor.height;

            // float tanHalfFovY = Mathf.Tan(0.5f * cameraData.camera.fieldOfView * Mathf.Deg2Rad);
            // float invFocalLenX = 1.0f / (1.0f / tanHalfFovY * ((float)height / (float)width));
            // float invFocalLenY = 1.0f / (1.0f / tanHalfFovY);
            float invFocalLenX = 1.0f / cameraData.camera.projectionMatrix.m00;
            float invFocalLenY = 1.0f / cameraData.camera.projectionMatrix.m11;

            if(settings.type.value == ScreenSpaceOcclusion.AOType.ScalableAmbientObscurance)
                m_AmbientOcclusionMaterial.SetMatrix(ShaderConstants.CameraProjMatrix, cameraData.camera.projectionMatrix);

            float maxRadInPixels = Mathf.Max(16, settings.maxRadiusPixels.value * Mathf.Sqrt((width * height) / (1080.0f * 1920.0f)));

            var targetScale = settings.resolution.value == ScreenSpaceOcclusion.Resolution.Half ?
                            new Vector4((width + 0.5f) / width, (height + 0.5f) / height, 1f, 1f) :
                            Vector4.one;

            m_AmbientOcclusionMaterial.SetVector(ShaderConstants.FullTexelSize, new Vector4(1f / width, 1f / height, width, height));
            m_AmbientOcclusionMaterial.SetVector(ShaderConstants.ScaledTexelSize, new Vector4(1f / widthAO, 1f / heightAO, widthAO, heightAO));
            m_AmbientOcclusionMaterial.SetVector(ShaderConstants.TargetScale, targetScale);
            m_AmbientOcclusionMaterial.SetVector(ShaderConstants.UVToView, new Vector4(2.0f * invFocalLenX, -2.0f * invFocalLenY, -1.0f * invFocalLenX, 1.0f * invFocalLenY));
            m_AmbientOcclusionMaterial.SetMatrix(ShaderConstants.WorldToCameraMatrix, cameraData.camera.worldToCameraMatrix);

            m_AmbientOcclusionMaterial.SetFloat(ShaderConstants.Radius, settings.radius.value);
            m_AmbientOcclusionMaterial.SetFloat(ShaderConstants.RadiusToScreen, settings.radius.value * 0.5f * (height / (invFocalLenY * 2.0f)));
            m_AmbientOcclusionMaterial.SetFloat(ShaderConstants.MaxRadiusPixels, maxRadInPixels);
            m_AmbientOcclusionMaterial.SetFloat(ShaderConstants.InvRadius2, 1.0f / (settings.radius.value * settings.radius.value));
            m_AmbientOcclusionMaterial.SetFloat(ShaderConstants.AngleBias, settings.bias.value);
            m_AmbientOcclusionMaterial.SetFloat(ShaderConstants.AOMultiplier, 2.0f * (1.0f / (1.0f - settings.bias.value)));
            m_AmbientOcclusionMaterial.SetFloat(ShaderConstants.Intensity, settings.intensity.value);
            m_AmbientOcclusionMaterial.SetFloat(ShaderConstants.Thickness, settings.thickness.value);
            m_AmbientOcclusionMaterial.SetFloat(ShaderConstants.MaxDistance, settings.maxDistance.value);
            m_AmbientOcclusionMaterial.SetFloat(ShaderConstants.DistanceFalloff, settings.distanceFalloff.value);
            m_AmbientOcclusionMaterial.SetFloat(ShaderConstants.BlurSharpness, settings.sharpness.value);

            // -------------------------------------------------------------------------------------------------
            // local shader keywords
            m_ShaderKeywords[0] = ShaderConstants.GetAOTypeKeyword(settings.type.value);
            m_ShaderKeywords[1] = ShaderConstants.GetQualityKeyword(settings.quality.value);
            m_ShaderKeywords[2] = ShaderConstants.GetBlurRadiusKeyword(settings.blurType.value);
            m_ShaderKeywords[3] = ShaderConstants.GetReconstructNormal(settings.reconstructNormal.value);
            m_ShaderKeywords[4] = ShaderConstants.GetDebugKeyword(settings.debugMode.value);

            m_AmbientOcclusionMaterial.shaderKeywords = m_ShaderKeywords;
        }
        public override void Setup()
        {
            m_AmbientOcclusionMaterial = GetMaterial(m_PostProcessFeatureData.shaders.screenSpaceOcclusionPS);
            m_DebugPass = new ScreenSpaceOcclusionDebug(ShaderConstants.OcclusionFinalTex);

            // TODO 移动端默认如果是 B10G11R11_UFloatPack32 传递深度精度会不太够
            m_AmbientOcclusionColorFormat = SystemInfo.SupportsRenderTextureFormat(RenderTextureFormat.ARGBHalf) ? RenderTextureFormat.ARGBHalf : RenderTextureFormat.Default;
        }

        public override void Dispose(bool disposing)
        {
            CoreUtils.Destroy(m_AmbientOcclusionMaterial);
        }
        public override void AddRenderPasses(ref RenderingData renderingData)
        {
            if(settings.debugMode.value != ScreenSpaceOcclusion.DebugMode.Disabled)
                renderingData.cameraData.renderer.EnqueuePass(m_DebugPass);
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            CoreUtils.SetKeyword(cmd, ShaderKeywordStrings.ScreenSpaceOcclusion, true);
            // ---------------------------------------------------------------------------

            m_AmbientOcclusionDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            m_AmbientOcclusionDescriptor.msaaSamples = 1;
            m_AmbientOcclusionDescriptor.depthBufferBits = 0;
            m_AmbientOcclusionDescriptor.colorFormat = m_AmbientOcclusionColorFormat;

            if (settings.resolution.value == ScreenSpaceOcclusion.Resolution.Half)
            {
                DescriptorDownSample(ref m_AmbientOcclusionDescriptor, 2);
            }

            cmd.GetTemporaryRT(ShaderConstants.OcclusionFinalTex, m_AmbientOcclusionDescriptor, FilterMode.Bilinear);

            // 默认此时有depth和normal 不再用ConfigureInput调整管线内顺序（input默认为None）

            // 非renderToCamera类型 最终输出需要指定 （renderPass自己的Blit方法包含这个功能）
            // TODO 放在这里是否会对整个renderPass上层造成问题
          
            m_RenderPass.ConfigureTarget(ShaderConstants.OcclusionFinalTex);
            // m_RenderPass.ConfigureColorStoreAction(RenderBufferStoreAction.DontCare);

        }
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(ShaderConstants.OcclusionFinalTex);
            CoreUtils.SetKeyword(cmd, ShaderKeywordStrings.ScreenSpaceOcclusion, false);
        }

        public override void Render(CommandBuffer cmd, RenderTargetIdentifier source, RenderTargetIdentifier target, ref RenderingData renderingData)
        {
            //
            SetupMaterials(ref renderingData);

            // AO
            cmd.GetTemporaryRT(ShaderConstants.OcclusionDepthTex, m_AmbientOcclusionDescriptor, FilterMode.Bilinear);
            Blit(cmd, source, ShaderConstants.OcclusionDepthTex, m_AmbientOcclusionMaterial, 0);

            // Blur
            if (settings.blurType.value != ScreenSpaceOcclusion.BlurType.None)
            {
                cmd.GetTemporaryRT(ShaderConstants.OcclusionTempTex, m_AmbientOcclusionDescriptor, FilterMode.Bilinear);
                Blit(cmd, ShaderConstants.OcclusionDepthTex, ShaderConstants.OcclusionTempTex, m_AmbientOcclusionMaterial, 1);
                Blit(cmd, ShaderConstants.OcclusionTempTex, ShaderConstants.OcclusionDepthTex, m_AmbientOcclusionMaterial, 2);

                cmd.ReleaseTemporaryRT(ShaderConstants.OcclusionTempTex);
            }

            // Composite
            cmd.SetGlobalTexture("_ScreenSpaceOcclusionTexture", ShaderConstants.OcclusionFinalTex);
            // 在_AmbientOcclusionParam.r存植物的AO淡化
            cmd.SetGlobalVector("_AmbientOcclusionParam", new Vector4(settings.foliageFade.value, 0f, 0f, settings.directLightingStrength.value));
            Blit(cmd, ShaderConstants.OcclusionDepthTex, ShaderConstants.OcclusionFinalTex, m_AmbientOcclusionMaterial, 3);

            cmd.ReleaseTemporaryRT(ShaderConstants.OcclusionDepthTex);
        }
    }
}
