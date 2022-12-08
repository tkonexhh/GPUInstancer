using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Inutan.PostProcessing
{
    [Serializable, VolumeComponentMenuForRenderPipeline("Post-processing Inutan/ScreenSpaceReflection",typeof(UniversalRenderPipeline))]
    public class ScreenSpaceReflection : VolumeSetting
    {
        public enum Resolution
        {
            Half,
            Full,
            Double
        }

        public enum DebugMode
        {
            Disabled,
            SSROnly,
            IndirectSpecular,
        }

        [Serializable]
        public class ResolutionParameter : VolumeParameter<Resolution> { }

        [Serializable]
        public class DebugModeParameter : VolumeParameter<DebugMode> { }

        [Tooltip("分辨率")]
        public ResolutionParameter resolution = new ResolutionParameter { value = Resolution.Double };

        [Tooltip("最大追踪次数, 移动端会被固定到10次")]
        public ClampedIntParameter maximumIterationCount = new ClampedIntParameter(256, 1, 256);

        [Tooltip("模糊迭代次数")]
        public ClampedIntParameter blurIterations = new ClampedIntParameter(3, 1, 4);

        [Space(6)]
        [Tooltip("强度")]
        public ClampedFloatParameter intensity = new ClampedFloatParameter(1f, 0f, 5f);

        [Tooltip("实际上是追踪步长, 越大精度越低, 追踪范围越大, 越节省追踪次数")]
        public ClampedFloatParameter thickness = new ClampedFloatParameter(8f, 1f, 64f);

        [Tooltip("最大追踪距离")]
        public MinFloatParameter maximumMarchDistance = new MinFloatParameter(100f, 0f);

        [Tooltip("值越大, 未追踪部分天空颜色会越多, 过度边界会越硬")]
        public ClampedFloatParameter distanceFade = new ClampedFloatParameter(0.02f, 0f, 1f);

        [Tooltip("渐变")]
        public ClampedFloatParameter vignette = new ClampedFloatParameter(0f, 0f, 1f);

        [Tooltip("减少闪烁问题, 需要MotionVector, SceneView未处理")]
        public BoolParameter antiFlicker = new BoolParameter(true);

        [Tooltip("Unity老版本算法")]
        public BoolParameter oldMethod = new BoolParameter(false);


        public DebugModeParameter debugMode = new DebugModeParameter { value = DebugMode.Disabled };

        public override bool IsActive() => intensity.value > 0;
    }

    [PostProcess("ScreenSpaceReflection", PostProcessInjectionPoint.AfterRenderingSkybox)]
    public class ScreenSpaceReflectionRenderer : PostProcessVolumeRenderer<ScreenSpaceReflection>
    {
        static class ShaderConstants
        {
            internal static readonly int ResolveTex = Shader.PropertyToID("_ResolveTex");
            internal static readonly int NoiseTex = Shader.PropertyToID("_NoiseTex");
            internal static readonly int TestTex = Shader.PropertyToID("_TestTex");
            internal static readonly int HistoryTex = Shader.PropertyToID("_HistoryTex");

            internal static readonly int ViewMatrix = Shader.PropertyToID("_ViewMatrixSSR");
            internal static readonly int InverseViewMatrix = Shader.PropertyToID("_InverseViewMatrixSSR");
            internal static readonly int InverseProjectionMatrix = Shader.PropertyToID("_InverseProjectionMatrixSSR");
            internal static readonly int ScreenSpaceProjectionMatrix = Shader.PropertyToID("_ScreenSpaceProjectionMatrixSSR");

            internal static readonly int Params1 = Shader.PropertyToID("_Params1");
            internal static readonly int Params2 = Shader.PropertyToID("_Params2");
            internal static readonly int Offset = Shader.PropertyToID("_Offset");

            public static int[] _BlurMipUp;
            public static int[] _BlurMipDown;

            public static string GetDebugKeyword(ScreenSpaceReflection.DebugMode debugMode)
            {
                switch (debugMode)
                {
                    case ScreenSpaceReflection.DebugMode.SSROnly:
                        return "DEBUG_SCREEN_SPACE_REFLECTION";
                    case ScreenSpaceReflection.DebugMode.IndirectSpecular:
                        return "DEBUG_INDIRECT_SPECULAR";
                    case ScreenSpaceReflection.DebugMode.Disabled:
                    default:
                        return "_";
                }
            }
        }

        Material m_ScreenSpaceReflectionMaterial;
        Material m_BlurMaterial;
        string[] m_ShaderKeywords = new string[2];
        RenderTextureDescriptor m_ScreenSpaceReflectionDescriptor;

        bool m_SupportARGBHalf = true;
        const int k_MaxPyramidSize = 16;

        ScreenSpaceReflectionPreDepth m_ScreenSpaceReflectionPreDepth;

        public override ScriptableRenderPassInput input => settings.antiFlicker.value ?  ScriptableRenderPassInput.Motion : base.input;


        const int k_NumHistoryTextures = 2;
        RenderTexture[] m_HistoryPingPongRT = new RenderTexture[k_NumHistoryTextures];
        int m_PingPong = 0;
        public void GetHistoryPingPongRT(ref RenderTexture rt1, ref RenderTexture rt2)
        {
            int index = m_PingPong;
            m_PingPong = ++m_PingPong % 2;

            rt1 = m_HistoryPingPongRT[index];
            rt2 = m_HistoryPingPongRT[m_PingPong];
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

        void CheckHistoryRT(int id, CommandBuffer cmd, RenderTargetIdentifier source, RenderTextureDescriptor desc)
        {
            var rt = m_HistoryPingPongRT[id];

            if(rt == null || rt.width != desc.width || rt.height != desc.height)
            {
                var newRT = RenderTexture.GetTemporary(desc);
                newRT.name = "_ReflectionHistoryRT_" + id;

                // 分辨率改变时还是从上一个历史RT拷贝
                m_RenderPass.Blit(cmd, rt == null ? source : rt, newRT);

                if(rt != null)
                    RenderTexture.ReleaseTemporary(rt);

                m_HistoryPingPongRT[id] = newRT;
            }
        }

        public ScreenSpaceReflectionRenderer()
        {
            m_ScreenSpaceReflectionPreDepth = new ScreenSpaceReflectionPreDepth();
        }

        public override void AddRenderPasses(ref RenderingData renderingData)
        {
            m_ScreenSpaceReflectionPreDepth.AddRenderPasses(renderingData.cameraData.renderer, ref renderingData);
        }

        public override void Setup()
        {
            m_ScreenSpaceReflectionMaterial = GetMaterial(m_PostProcessFeatureData.shaders.screenSpaceReflectionPS);
            m_BlurMaterial = GetMaterial(m_PostProcessFeatureData.shaders.dualBlurPS);

            ShaderConstants._BlurMipUp = new int[k_MaxPyramidSize];
            ShaderConstants._BlurMipDown = new int[k_MaxPyramidSize];
            for (int i = 0; i < k_MaxPyramidSize; i++)
            {
                ShaderConstants._BlurMipUp[i] = Shader.PropertyToID("_SSR_BlurMipUp" + i);
                ShaderConstants._BlurMipDown[i] = Shader.PropertyToID("_SSR_BlurMipDown" + i);
            }

            m_SupportARGBHalf = SystemInfo.SupportsRenderTextureFormat(RenderTextureFormat.ARGBHalf);
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
            CoreUtils.Destroy(m_ScreenSpaceReflectionMaterial);
            CoreUtils.Destroy(m_BlurMaterial);
            Clear();
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            CoreUtils.SetKeyword(cmd, "_SCREEN_SPACE_REFLECTION", true);
        }
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            CoreUtils.SetKeyword(cmd, "_SCREEN_SPACE_REFLECTION", false);
        }

        private void SetupMaterials(ref RenderingData renderingData)
        {
            var cameraData = renderingData.cameraData;
            var camera = cameraData.camera;

            var width = cameraData.cameraTargetDescriptor.width;
            var height = cameraData.cameraTargetDescriptor.height;
            var size = m_ScreenSpaceReflectionDescriptor.width;

            var noiseTex = m_PostProcessFeatureData.textures.blueNoiseTex;
            m_ScreenSpaceReflectionMaterial.SetTexture(ShaderConstants.NoiseTex, noiseTex);

            var screenSpaceProjectionMatrix = new Matrix4x4();
            screenSpaceProjectionMatrix.SetRow(0, new Vector4(size * 0.5f, 0f, 0f, size * 0.5f));
            screenSpaceProjectionMatrix.SetRow(1, new Vector4(0f, size * 0.5f, 0f, size * 0.5f));
            screenSpaceProjectionMatrix.SetRow(2, new Vector4(0f, 0f, 1f, 0f));
            screenSpaceProjectionMatrix.SetRow(3, new Vector4(0f, 0f, 0f, 1f));

            var projectionMatrix = GL.GetGPUProjectionMatrix(camera.projectionMatrix, false);
            screenSpaceProjectionMatrix *= projectionMatrix;

            m_ScreenSpaceReflectionMaterial.SetMatrix(ShaderConstants.ViewMatrix, camera.worldToCameraMatrix);
            m_ScreenSpaceReflectionMaterial.SetMatrix(ShaderConstants.InverseViewMatrix, camera.worldToCameraMatrix.inverse);
            m_ScreenSpaceReflectionMaterial.SetMatrix(ShaderConstants.InverseProjectionMatrix, projectionMatrix.inverse);
            m_ScreenSpaceReflectionMaterial.SetMatrix(ShaderConstants.ScreenSpaceProjectionMatrix, screenSpaceProjectionMatrix);
            m_ScreenSpaceReflectionMaterial.SetVector(ShaderConstants.Params1, new Vector4((float)settings.vignette.value, settings.distanceFade.value, settings.maximumMarchDistance.value, settings.intensity.value));
            m_ScreenSpaceReflectionMaterial.SetVector(ShaderConstants.Params2, new Vector4(width / height, (float)size / (float)noiseTex.width, settings.thickness.value, settings.maximumIterationCount.value));


            // 没有调节的需求
            m_BlurMaterial.SetFloat(ShaderConstants.Offset, 0.1f);

            // -------------------------------------------------------------------------------------------------
            // local shader keywords
            m_ShaderKeywords[0] = settings.oldMethod.value ? "_OLD_METHOD" : "_";
            m_ShaderKeywords[1] = ShaderConstants.GetDebugKeyword(settings.debugMode.value);

            m_ScreenSpaceReflectionMaterial.shaderKeywords = m_ShaderKeywords;
        }

        public override void Render(CommandBuffer cmd, RenderTargetIdentifier source, RenderTargetIdentifier target, ref RenderingData renderingData)
        {
            m_ScreenSpaceReflectionDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            m_ScreenSpaceReflectionDescriptor.msaaSamples = 1;
            m_ScreenSpaceReflectionDescriptor.depthBufferBits = 0;

            int size = Mathf.ClosestPowerOfTwo(Mathf.Min(m_ScreenSpaceReflectionDescriptor.width, m_ScreenSpaceReflectionDescriptor.height));

            if (settings.resolution.value == ScreenSpaceReflection.Resolution.Half)
                size >>= 1;
            else if (settings.resolution.value == ScreenSpaceReflection.Resolution.Double)
                size <<= 1;
            m_ScreenSpaceReflectionDescriptor.width = size;
            m_ScreenSpaceReflectionDescriptor.height = size;

            //
            SetupMaterials(ref renderingData);

            // SSR 移动端用B10G11R11 见MakeRenderTextureGraphicsFormat 就算不管Alpha通道问题 精度也非常难受
            var testDesc = m_ScreenSpaceReflectionDescriptor;
            var resolveDesc = m_ScreenSpaceReflectionDescriptor;
            if(m_SupportARGBHalf)
            {
                testDesc.colorFormat = RenderTextureFormat.ARGBHalf;
                resolveDesc.colorFormat = RenderTextureFormat.ARGBHalf;
            }
            else
            {
                // resolve需要一个渐变模糊后参与最终混合, 必须要Alpha通道
                // 移动端没办法 就只能降到LDR了
                resolveDesc.colorFormat = RenderTextureFormat.ARGB32;
            }

            cmd.GetTemporaryRT(ShaderConstants.TestTex, testDesc, FilterMode.Point);
            cmd.GetTemporaryRT(ShaderConstants.ResolveTex, resolveDesc, FilterMode.Bilinear);

            Blit(cmd, source, ShaderConstants.TestTex, m_ScreenSpaceReflectionMaterial, 0);

            cmd.SetGlobalTexture(ShaderConstants.TestTex, ShaderConstants.TestTex);
            Blit(cmd, source, ShaderConstants.ResolveTex, m_ScreenSpaceReflectionMaterial, 1);

            RenderTargetIdentifier lastDownId = ShaderConstants.ResolveTex;

            // ----------------------------------------------------------------------------------
            // 简化版本没有用Jitter所以sceneview部分就不处理了
            if(!renderingData.cameraData.isSceneViewCamera && settings.antiFlicker.value)
            {
                CheckHistoryRT(0, cmd, source, resolveDesc);
                CheckHistoryRT(1, cmd, source, resolveDesc);

                // 不确定移动端CopyTexture的支持，所以先用这种方法
                RenderTexture rt1 = null, rt2 = null;
                GetHistoryPingPongRT(ref rt1, ref rt2);

                //
                cmd.SetGlobalTexture(ShaderConstants.HistoryTex, rt1);
                Blit(cmd, ShaderConstants.ResolveTex, rt2, m_ScreenSpaceReflectionMaterial, 2);
                lastDownId = new RenderTargetIdentifier(rt2);
            }
            // ----------------------------------------------------------------------------------


            // ------------------------------------------------------------------------------------------------
            // 简化版本 DualBlur替代 放弃不同粗糙度mipmap的采样
            int iter = settings.blurIterations.value;
            RenderTextureDescriptor blurDesc = resolveDesc;
            for (int i = 0; i < iter; i++)
            {
                cmd.GetTemporaryRT(ShaderConstants._BlurMipUp[i], blurDesc, FilterMode.Bilinear);
                cmd.GetTemporaryRT(ShaderConstants._BlurMipDown[i], blurDesc, FilterMode.Bilinear);

                Blit(cmd, lastDownId, ShaderConstants._BlurMipDown[i], m_BlurMaterial, 0);

                lastDownId = ShaderConstants._BlurMipDown[i];
                DescriptorDownSample(ref blurDesc, 2);
            }

            // Upsample
            int lastUp = ShaderConstants._BlurMipDown[iter - 1];
            for (int i = iter - 2; i >= 0; i--)
            {
                Blit(cmd, lastUp, ShaderConstants._BlurMipUp[i], m_BlurMaterial, 1);
                lastUp = ShaderConstants._BlurMipUp[i];
            }

            // Render blurred texture in blend pass
            Blit(cmd, lastUp, ShaderConstants.ResolveTex, m_BlurMaterial, 1);

            /////////////////////////////////////////////////////////////////////
            cmd.SetGlobalTexture(ShaderConstants.ResolveTex, ShaderConstants.ResolveTex);
            Blit(cmd, source, target, m_ScreenSpaceReflectionMaterial, 3);

            cmd.ReleaseTemporaryRT(ShaderConstants.ResolveTex);
            cmd.ReleaseTemporaryRT(ShaderConstants.TestTex);

            // Cleanup
            for (int i = 0; i < iter; i++)
            {
                if (ShaderConstants._BlurMipDown[i] != lastUp)
                    cmd.ReleaseTemporaryRT(ShaderConstants._BlurMipDown[i]);
                if (ShaderConstants._BlurMipUp[i] != lastUp)
                    cmd.ReleaseTemporaryRT(ShaderConstants._BlurMipUp[i]);
            }
        }
    }
}
