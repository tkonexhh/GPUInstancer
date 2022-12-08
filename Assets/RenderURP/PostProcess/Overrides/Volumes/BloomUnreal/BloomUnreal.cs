using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Inutan.PostProcessing
{
    [Serializable, VolumeComponentMenuForRenderPipeline("Post-processing Inutan/BloomUnreal",typeof(UniversalRenderPipeline))]
    public class BloomUnreal : VolumeSetting
    {
        public enum Quality
        {
            Lowest,         // 3
            Low,            // 4
            Medium,         // 5
            High,           // 6
            Highest         // DownSampleFilter + 6
        }
        [Serializable]
        public sealed class QualityParameter : VolumeParameter<Quality> {}

        // -------------------------------------------------------------------------------------
        [Tooltip("质量, 建议用High")]
        public QualityParameter quality = new QualityParameter { value = Quality.Highest };

        [Space(6)]
        [Tooltip("强度")]
        public ClampedFloatParameter intensity = new ClampedFloatParameter(0.675f, 0f, 20f);

        [Tooltip("阈值, -1: 不过滤")]
        public ClampedFloatParameter threshold = new ClampedFloatParameter(-1f, -1f, 8f);

        [Tooltip("0: 默认 <0: 横向拉伸 >0: 十字拉伸")]
        public ClampedFloatParameter cross = new ClampedFloatParameter(0f, -1f, 0.9f);
        public override bool IsActive() => intensity.value > 0;
    }

    [PostProcess("BloomUnreal", PostProcessInjectionPoint.BeforeRenderingPostProcessing)]
    public class BloomUnrealRenderer : PostProcessVolumeRenderer<BloomUnreal>
    {
        static class ShaderConstants
        {
            internal static readonly int PrefilterTex = Shader.PropertyToID("_PrefilterTex");
            internal static readonly int AdditiveTex = Shader.PropertyToID("_AdditiveTex");
            internal static readonly int BloomTex = Shader.PropertyToID("_BloomTex");
 
            internal static readonly int Threshold = Shader.PropertyToID("_Threshold");
            internal static readonly int Intensity = Shader.PropertyToID("_Intensity");
            
            internal static readonly int SampleWeights = Shader.PropertyToID("_SampleWeights");
            internal static readonly int OffsetUVs = Shader.PropertyToID("_OffsetUVs");
            internal static readonly int SampleCount = Shader.PropertyToID("_SampleCount");

            public static int[] _BloomMipUp;
            public static int[] _BloomMipDown;

            public static int GetQualityCount(BloomUnreal.Quality quality)
            {
                switch (quality)
                {
                    case BloomUnreal.Quality.Lowest:
                        return 3;
                    case BloomUnreal.Quality.Low:
                        return 4;
                    case BloomUnreal.Quality.Medium:
                        return 5;
                    case BloomUnreal.Quality.High:
                    case BloomUnreal.Quality.Highest:
                    default:
                        return 6;
                }
            }
        }

        Material m_BloomUnrealMaterial;
        string[] m_ShaderKeywords = new string[1];
        const string USE_COMBINE_ADDITIVE = "USE_COMBINE_ADDITIVE";
        const string USE_DOWNSAMPLE_FILTER = "USE_DOWNSAMPLE_FILTER";

        const int k_MaxPyramidSize = 6;
        const int k_MaxFilterSamples = 32;

        // Unreal 默认的BloomSizeScale 没有需求变化
        const float m_BloomSizeScale = 4.0f;

        // Unreal 默认的各个下采样级别的 BloomTint 和 BloomSize 没有修改需求就不暴露出来了
        Vector4[] m_BloomTintAndSize = new Vector4[k_MaxPyramidSize] 
        {
            new Vector4(0.3465f,   0.3465f,   0.3465f,   0.3f ),
            new Vector4(0.138f ,   0.138f ,   0.138f ,   1.0f ),
            new Vector4(0.1176f,   0.1176f,   0.1176f,   2.0f ),
            new Vector4(0.066f ,   0.066f ,   0.066f ,   10.0f),
            new Vector4(0.066f ,   0.066f ,   0.066f ,   30.0f),
            new Vector4(0.061f ,   0.061f ,   0.061f ,   64.0f)
        };

        Vector2[] m_BloomMipSize;
        Vector2[] m_OffsetAndWeight = new Vector2[k_MaxFilterSamples];
        Vector4[] m_SampleWeights = new Vector4[k_MaxFilterSamples];
        Vector2[] m_SampleOffsets = new Vector2[k_MaxFilterSamples];
        Vector4[] m_OffsetUVs = new Vector4[(k_MaxFilterSamples + 1) / 2];

        // -------------------------------------------------------------------------------------
        // Unreal Bloom 代码
        // Evaluates an unnormalized normal distribution PDF around 0 at given X with Variance.
        float NormalDistributionUnscaled(float x, float sigma, float crossCenterWeight)
        {
            float dx = Mathf.Abs(x);

            float clampedOneMinusDX = Mathf.Max(0.0f, 1.0f - dx);
           // Tweak the gaussian shape e.g. "r.Bloom.Cross 3.5"
            if (crossCenterWeight > 1.0f)
            {
                return Mathf.Pow(clampedOneMinusDX, crossCenterWeight);
            }
            else
            {
                // Constant is tweaked give a similar look to UE4 before we fix the scale bug (Some content tweaking might be needed).
                // The value defines how much of the Gaussian clipped by the sample window.
                // r.Filter.SizeScale allows to tweak that for performance/quality.
                const float legacyCompatibilityConstant = -16.7f;

                float gaussian = Mathf.Exp(legacyCompatibilityConstant * Mathf.Pow(dx / sigma, 2));

                return Mathf.Lerp(gaussian, clampedOneMinusDX, crossCenterWeight);
            }
        }
        float GetClampedKernelRadius(int sampleCountMax, float kernelRadius)
        {
            return Mathf.Clamp(kernelRadius, 0.00001f, sampleCountMax - 1);
        }
        int GetIntegerKernelRadius(int sampleCountMax, float kernelRadius)
        {
            float radius = GetClampedKernelRadius(sampleCountMax, kernelRadius);
            // Smallest radius will be 1.
            return Math.Min(Mathf.CeilToInt(radius), sampleCountMax - 1);
        }
        int Compute1DGaussianFilterKernel(ref Vector2[] outOffsetAndWeight, int sampleCountMax, float kernelRadius, float crossCenterWeight)
        {
            float clampedKernelRadius = GetClampedKernelRadius(sampleCountMax, kernelRadius);
            int integerKernelRadius = GetIntegerKernelRadius(sampleCountMax, kernelRadius);

            int sampleCount = 0;
            float weightSum = 0.0f;

            for (int i = -integerKernelRadius; i <= integerKernelRadius; i += 2)
            {
                float weight0 = NormalDistributionUnscaled(i, clampedKernelRadius, crossCenterWeight);
                float weight1 = 0.0f;

                // We use the bilinear filter optimization for gaussian blur. However, we don't want to bias the
                // last sample off the edge of the filter kernel, so the very last tap just is on the pixel center.
                if(i != integerKernelRadius)
                {
                    weight1 = NormalDistributionUnscaled(i + 1, clampedKernelRadius, crossCenterWeight);
                }

                float totalWeight = weight0 + weight1;
                outOffsetAndWeight[sampleCount] = new Vector2(i + (weight1 / totalWeight), totalWeight);
                weightSum += totalWeight;
                sampleCount++;
            }

            // Normalize blur weights.
            float weightSumInverse = 1.0f / weightSum;
            for (int i = 0; i < sampleCount; ++i)
            {
                outOffsetAndWeight[i].y *= weightSumInverse;
            }

            return sampleCount;
        }

        float GetBlurRadius(float width, float kernelSizePercent)
        {
            const float percentToScale = 0.01f;
            const float diameterToRadius = 0.5f;

            return width * kernelSizePercent * percentToScale * diameterToRadius;
        }

        void SetupBlur(CommandBuffer cmd, float blurRadius, float crossCenterWeight, Vector4 tint, Vector2 size)
        {
            int sampleCount = Compute1DGaussianFilterKernel(ref m_OffsetAndWeight, k_MaxFilterSamples, blurRadius, crossCenterWeight);
    
            //
            // Weights multiplied by a white tint.
            for (int i = 0; i < sampleCount; ++i)
            {
                float offset = m_OffsetAndWeight[i].x;
                float weight = m_OffsetAndWeight[i].y;

                m_SampleWeights[i] = tint * weight;
                m_SampleOffsets[i] = size * offset;
            }

            // 奇偶压缩
            for (int i = 0; i < sampleCount; i += 2)
            {
                m_OffsetUVs[i / 2].x = m_SampleOffsets[i].x;
                m_OffsetUVs[i / 2].y = m_SampleOffsets[i].y;

                if (i + 1 < sampleCount)
                {
                    m_OffsetUVs[i / 2].z = m_SampleOffsets[i + 1].x;
                    m_OffsetUVs[i / 2].w = m_SampleOffsets[i + 1].y;
                }
            }

            cmd.SetGlobalVectorArray(ShaderConstants.OffsetUVs, m_OffsetUVs);
            cmd.SetGlobalVectorArray(ShaderConstants.SampleWeights, m_SampleWeights);
            cmd.SetGlobalFloat(ShaderConstants.SampleCount, sampleCount);
        }
        // -------------------------------------------------------------------------------------

        public override void Setup()
        {
            m_BloomUnrealMaterial = GetMaterial(m_PostProcessFeatureData.shaders.bloomUnrealPS);

            ShaderConstants._BloomMipUp = new int[k_MaxPyramidSize];
            ShaderConstants._BloomMipDown = new int[k_MaxPyramidSize];

            for (int i = 0; i < k_MaxPyramidSize; i++)
            {
                ShaderConstants._BloomMipUp[i] = Shader.PropertyToID("_BloomMipUp" + i);
                ShaderConstants._BloomMipDown[i] = Shader.PropertyToID("_BloomMipDown" + i);
            }

            m_BloomMipSize = new Vector2[k_MaxPyramidSize];
        }

        public override void Dispose(bool disposing) 
        {
            CoreUtils.Destroy(m_BloomUnrealMaterial);
        }
        
        private void SetupMaterials(ref RenderingData renderingData)
        {
            m_BloomUnrealMaterial.SetFloat(ShaderConstants.Intensity, settings.intensity.value);
            m_BloomUnrealMaterial.SetFloat(ShaderConstants.Threshold, settings.threshold.value);

            // -------------------------------------------------------------------------------------------------
            // local shader keywords
            m_ShaderKeywords[0] = settings.quality.value == BloomUnreal.Quality.Highest ? USE_DOWNSAMPLE_FILTER : "_";
            m_BloomUnrealMaterial.shaderKeywords = m_ShaderKeywords;
        }

        public override void Render(CommandBuffer cmd, RenderTargetIdentifier source, RenderTargetIdentifier target, ref RenderingData renderingData)
        {
            var bloomDesc = renderingData.cameraData.cameraTargetDescriptor;
            bloomDesc.msaaSamples = 1;
            bloomDesc.depthBufferBits = 0;

            //
            SetupMaterials(ref renderingData);


			bool thresholdEnabled = settings.threshold.value > -1.0f;

            RenderTargetIdentifier lastDownId = source;

            int iter = k_MaxPyramidSize;
            for (int i = 0; i < iter; i++)
            {
                DescriptorDownSample(ref bloomDesc, 2);

                m_BloomMipSize[i] = new Vector2(bloomDesc.width, bloomDesc.height);
                cmd.GetTemporaryRT(ShaderConstants._BloomMipUp[i], bloomDesc, FilterMode.Bilinear);
                cmd.GetTemporaryRT(ShaderConstants._BloomMipDown[i], bloomDesc, FilterMode.Bilinear);

                // 再HalfResolution下考虑是否需要阈值过滤
                if(i == 0 && thresholdEnabled)
                {
                    cmd.GetTemporaryRT(ShaderConstants.PrefilterTex, bloomDesc, FilterMode.Bilinear);
                    // Downsample to prefilter rt
                    Blit(cmd, lastDownId, ShaderConstants.PrefilterTex, m_BloomUnrealMaterial, 0);
                    // Prefilter to mip down rt
                    Blit(cmd, ShaderConstants.PrefilterTex, ShaderConstants._BloomMipDown[i], m_BloomUnrealMaterial, 1);

                    cmd.ReleaseTemporaryRT(ShaderConstants.PrefilterTex);
                }
                else
                {
                    Blit(cmd, lastDownId, ShaderConstants._BloomMipDown[i], m_BloomUnrealMaterial, 0);
                }

                lastDownId = ShaderConstants._BloomMipDown[i];
            }


			Vector2 crossCenterWeight = new Vector2(Mathf.Max(settings.cross.value, 0.0f), Mathf.Abs(settings.cross.value));

            int maxCount = k_MaxPyramidSize - ShaderConstants.GetQualityCount(settings.quality.value);
            int lastUp = -1;
            for (int i = iter - 1; i >= maxCount; i--)
            {
                var bloomMipSize = m_BloomMipSize[i];
                var bloomTintAndSize = m_BloomTintAndSize[i];

            	float blurRadius = GetBlurRadius(bloomMipSize.x, bloomTintAndSize.w * m_BloomSizeScale);
             
                // 横向模糊时不做混合 也不需要Tint参与权重
                // Horizontal
                SetupBlur(cmd, blurRadius, crossCenterWeight.x, Vector4.one, new Vector2(1.0f / bloomMipSize.x, 0));

                CoreUtils.SetKeyword(cmd, USE_COMBINE_ADDITIVE, false);
                Blit(cmd, ShaderConstants._BloomMipDown[i], ShaderConstants._BloomMipUp[i], m_BloomUnrealMaterial, 3);

                // 最小级别的只是自身模糊
                // Vertical
                SetupBlur(cmd, blurRadius, crossCenterWeight.y, bloomTintAndSize / k_MaxPyramidSize, new Vector2(0, 1.0f / bloomMipSize.y));

                if(lastUp != -1)
                {
                    cmd.SetGlobalTexture(ShaderConstants.AdditiveTex, lastUp);
                    CoreUtils.SetKeyword(cmd, USE_COMBINE_ADDITIVE, true);
                }
                Blit(cmd, ShaderConstants._BloomMipUp[i], ShaderConstants._BloomMipDown[i], m_BloomUnrealMaterial, 3);

                lastUp = ShaderConstants._BloomMipDown[i];
            }

            // Combine
            cmd.SetGlobalTexture(ShaderConstants.BloomTex, lastUp);
            Blit(cmd, source, target, m_BloomUnrealMaterial, 2);

            // Clear
            for (int i = 0; i < iter; i++)
            {
                cmd.ReleaseTemporaryRT(ShaderConstants._BloomMipDown[i]);
                cmd.ReleaseTemporaryRT(ShaderConstants._BloomMipUp[i]);
            }
        }
    }
}
