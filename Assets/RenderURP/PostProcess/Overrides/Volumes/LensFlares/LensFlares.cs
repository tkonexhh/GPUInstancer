using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Inutan.PostProcessing
{
    [Serializable, VolumeComponentMenuForRenderPipeline("Post-processing Inutan/LensFlares",typeof(UniversalRenderPipeline))]
    public class LensFlares : VolumeSetting
    {
        public enum DebugMode
        {
            Disabled,
            LensFlaresOnly,
        }

        [Serializable]
        public class DebugModeParameter : VolumeParameter<DebugMode> { }
        // -------------------------------------------------------------------------------------
        [Tooltip("总强度")]
        public ClampedFloatParameter intensity = new ClampedFloatParameter(1f, 0f, 20f);
        [Tooltip("阈值上下限")]
        public FloatRangeParameter thresholdLevel = new FloatRangeParameter(new Vector2(1, 3), 0f, 10f);
        [Tooltip("晕出范围")]
        public ClampedFloatParameter thresholdRange = new ClampedFloatParameter(2f, 0.01f, 10f);

        [Space(6)]
        [Tooltip("光斑强度")]
        public ClampedFloatParameter ghostIntensity = new ClampedFloatParameter(0.1f, 0f, 1);
        [Tooltip("光斑偏移")]
        public Vector3Parameter ghostScale = new Vector3Parameter(new Vector3(-0.4f, -0.2f, -0.1f));

        [Space(6)]
        [Tooltip("光环强度")]
        public ClampedFloatParameter haloIntensity = new ClampedFloatParameter(0.3f, 0f, 1);
        [Tooltip("光环宽度")]
        public ClampedFloatParameter haloWidth = new ClampedFloatParameter(0.6f, 0f, 1);
        [Tooltip("光环中心遮罩")]
        public ClampedFloatParameter haloMask = new ClampedFloatParameter(0.8f, 0f, 1);
        [Tooltip("光环分离度")]
        public ClampedFloatParameter haloCompression = new ClampedFloatParameter(0.65f, 0f, 1);

        [Space(6)]
        [Tooltip("模糊度")]
        public ClampedIntParameter blurIterations = new ClampedIntParameter(2, 1, 4);

        public DebugModeParameter debugMode = new DebugModeParameter { value = DebugMode.Disabled };

        public override bool IsActive() => intensity.value > 0;
    }

    [PostProcess("LensFlares", PostProcessInjectionPoint.BeforeRenderingPostProcessing)]
    public class LensFlaresRenderer : PostProcessVolumeRenderer<LensFlares>
    {
        static class ShaderConstants
        {
            internal static readonly int PrefilterTex = Shader.PropertyToID("_PrefilterTex");
            internal static readonly int ChromaticTex = Shader.PropertyToID("_ChromaticTex");
            //
            internal static readonly int Params1 = Shader.PropertyToID("_Params1");
            internal static readonly int Params2 = Shader.PropertyToID("_Params2");
            internal static readonly int Params3 = Shader.PropertyToID("_Params3");
            //
            internal static readonly int Offset = Shader.PropertyToID("_Offset");

            public static int[] _BlurMipUp;
            public static int[] _BlurMipDown;

            public static string GetDebugKeyword(LensFlares.DebugMode debugMode)
            {
                switch (debugMode)
                {
                    case LensFlares.DebugMode.LensFlaresOnly:
                        return "DEBUG_LENSFLARES";
                    case LensFlares.DebugMode.Disabled:
                    default:
                        return "_";
                }
            }
        }
        LensFlaresPre m_CompositePass;

        Material m_LensFlaresMaterial;
        Material m_BlurMaterial;

        string[] m_ShaderKeywords = new string[1];
        const int k_MaxPyramidSize = 16;

        public override void Setup()
        {
            m_LensFlaresMaterial = GetMaterial(m_PostProcessFeatureData.shaders.lensFlaresPS);
            m_BlurMaterial = GetMaterial(m_PostProcessFeatureData.shaders.dualBlurPS);

            ShaderConstants._BlurMipUp = new int[k_MaxPyramidSize];
            ShaderConstants._BlurMipDown = new int[k_MaxPyramidSize];
            for (int i = 0; i < k_MaxPyramidSize; i++)
            {
                ShaderConstants._BlurMipUp[i] = Shader.PropertyToID("_LensFlares_BlurMipUp" + i);
                ShaderConstants._BlurMipDown[i] = Shader.PropertyToID("_LensFlares_BlurMipDown" + i);
            }

            m_CompositePass = new LensFlaresPre(this, ShaderConstants.PrefilterTex);
        }
        public override void AddRenderPasses(ref RenderingData renderingData)
        {
            renderingData.cameraData.renderer.EnqueuePass(m_CompositePass);
        }

        public override void Dispose(bool disposing)
        {
            CoreUtils.Destroy(m_LensFlaresMaterial);
            CoreUtils.Destroy(m_BlurMaterial);
        }

        private void SetupMaterials(ref RenderingData renderingData)
        {
            m_LensFlaresMaterial.SetVector(ShaderConstants.Params1, new Vector4(
                                            settings.intensity.value, settings.thresholdLevel.value.x,
                                            settings.thresholdLevel.value.y, settings.thresholdRange.value
                                        ));

            m_LensFlaresMaterial.SetVector(ShaderConstants.Params2, new Vector4(
                                            settings.ghostIntensity.value, settings.ghostScale.value.x,
                                            settings.ghostScale.value.y, settings.ghostScale.value.z
                                        ));

            m_LensFlaresMaterial.SetVector(ShaderConstants.Params3, new Vector4(
                                            settings.haloIntensity.value, settings.haloWidth.value,
                                            settings.haloMask.value, settings.haloCompression.value
                                        ));

            m_BlurMaterial.SetFloat(ShaderConstants.Offset, 0.1f);

            // -------------------------------------------------------------------------------------------------
            // local shader keywords
            m_ShaderKeywords[0] = ShaderConstants.GetDebugKeyword(settings.debugMode.value);
            m_LensFlaresMaterial.shaderKeywords = m_ShaderKeywords;
        }

        void DualBlur(bool tag, CommandBuffer cmd, RenderTextureDescriptor desc, RenderTargetIdentifier source, RenderTargetIdentifier target)
        {
            int iter = settings.blurIterations.value;
            RenderTextureDescriptor blurDesc = desc;
            RenderTargetIdentifier lastDownId = source;

            for (int i = 0; i < iter; i++)
            {
                if(tag)
                {
                    cmd.GetTemporaryRT(ShaderConstants._BlurMipUp[i], blurDesc, FilterMode.Bilinear);
                    cmd.GetTemporaryRT(ShaderConstants._BlurMipDown[i], blurDesc, FilterMode.Bilinear);
                    DescriptorDownSample(ref blurDesc, 2);
                }

                Blit(cmd, lastDownId, ShaderConstants._BlurMipDown[i], m_BlurMaterial, 0);
                lastDownId = ShaderConstants._BlurMipDown[i];
            }

            // Upsample
            int lastUp = ShaderConstants._BlurMipDown[iter - 1];
            for (int i = iter - 2; i >= 0; i--)
            {
                Blit(cmd, lastUp, ShaderConstants._BlurMipUp[i], m_BlurMaterial, 1);
                lastUp = ShaderConstants._BlurMipUp[i];
            }

            // Render blurred texture in blend pass
            Blit(cmd, lastUp, target, m_BlurMaterial, 1);

            // Cleanup
            if(!tag)
            {
                for (int i = 0; i < iter; i++)
                {
                    if (ShaderConstants._BlurMipDown[i] != lastUp)
                        cmd.ReleaseTemporaryRT(ShaderConstants._BlurMipDown[i]);
                    if (ShaderConstants._BlurMipUp[i] != lastUp)
                        cmd.ReleaseTemporaryRT(ShaderConstants._BlurMipUp[i]);
                }
            }
        }

        public void RenderLensFlares(CommandBuffer cmd, RenderTargetIdentifier source, ref RenderingData renderingData)
        {
            var lensFlaresDesc = renderingData.cameraData.cameraTargetDescriptor;
            lensFlaresDesc.msaaSamples = 1;
            lensFlaresDesc.depthBufferBits = 0;

            //
            SetupMaterials(ref renderingData);

            DescriptorDownSample(ref lensFlaresDesc, 2);

            // down sample and prefilter
            cmd.GetTemporaryRT(ShaderConstants.PrefilterTex, lensFlaresDesc, FilterMode.Bilinear);
            Blit(cmd, source, ShaderConstants.PrefilterTex, m_LensFlaresMaterial, 0);

            // blur before
            DualBlur(true, cmd, lensFlaresDesc, ShaderConstants.PrefilterTex, ShaderConstants.PrefilterTex);

            // chromatic
            cmd.GetTemporaryRT(ShaderConstants.ChromaticTex, lensFlaresDesc, FilterMode.Bilinear);
            Blit(cmd, ShaderConstants.PrefilterTex, ShaderConstants.ChromaticTex, m_LensFlaresMaterial, 1);

            // ghost and halo
            Blit(cmd, ShaderConstants.ChromaticTex, ShaderConstants.PrefilterTex, m_LensFlaresMaterial, 2);

            // blur after
            DualBlur(false, cmd, lensFlaresDesc, ShaderConstants.PrefilterTex, ShaderConstants.PrefilterTex);

            cmd.SetGlobalTexture(ShaderConstants.PrefilterTex, ShaderConstants.PrefilterTex);

            cmd.ReleaseTemporaryRT(ShaderConstants.ChromaticTex);
        }
        public override void Render(CommandBuffer cmd, RenderTargetIdentifier source, RenderTargetIdentifier target, ref RenderingData renderingData)
        {
            Blit(cmd, source, target, m_LensFlaresMaterial, 3);
        }
    }
}
