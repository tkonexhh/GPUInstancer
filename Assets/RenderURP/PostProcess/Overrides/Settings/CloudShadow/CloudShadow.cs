using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Inutan.PostProcessing
{
    [Serializable, VolumeComponentMenuForRenderPipeline("Post-processing Inutan/CloudShadow", typeof(UniversalRenderPipeline))]
    public class CloudShadow : VolumeSetting
    {
        [InspectorName("云阴影噪声图")]
        public Texture2DParameter cloudShadowTexture = new Texture2DParameter(null);
        [InspectorName("云阴影噪声图 反相")]
        public BoolParameter cloudShadowTextureInvert = new BoolParameter(false);
        [InspectorName("云阴影Tiling X")]
        public ClampedFloatParameter cloudShadowTillingX = new ClampedFloatParameter(0.1f, 0f, 10.0f);
        [InspectorName("云阴影Tiling Y")]
        public ClampedFloatParameter cloudShadowTillingY = new ClampedFloatParameter(0.1f, 0f, 10.0f);
        [InspectorName("云阴影Tilling Offset X")]
        public ClampedFloatParameter cloudShadowTillOffsetX = new ClampedFloatParameter(0f, 0f, 1.0f);
        [InspectorName("云阴影Tilling Offset Y")]
        public ClampedFloatParameter cloudShadowTillOffsetY = new ClampedFloatParameter(0f, 0f, 1.0f);
        [InspectorName("移动速度 X")]
        public FloatParameter cloudShadowSpeedX = new FloatParameter(0.5f);
        [InspectorName("移动速度 Y")]
        public FloatParameter cloudShadowSpeedY = new FloatParameter(0.0f);
        [InspectorName("云阴影覆盖范围")]
        public ClampedFloatParameter cloudShadowCoverage = new ClampedFloatParameter(0.5f, 0f, 1f);
        [InspectorName("云阴影软度")]
        public ClampedFloatParameter cloudShadowSoftness = new ClampedFloatParameter(0.5f, 0f, 1f);
        [InspectorName("云阴影颜色淡化")]
        public ClampedFloatParameter cloudShadowFade = new ClampedFloatParameter(0, 0, 1);
        [InspectorName("云阴影距离淡出")]
        public FloatParameter cloudShadowDistance = new FloatParameter(500);

        public override bool IsActive()
        {
            return cloudShadowTexture.overrideState && cloudShadowTexture != null;
        }
    }

    [PostProcess("CloudShadow", PostProcessInjectionPoint.BeforeRenderingDeferredLights)]
    public class CloudShadowRenderer : PostProcessVolumeRenderer<CloudShadow>
    {
        static class ShaderConstants
        {
            internal static readonly int CloudShadowTexture = Shader.PropertyToID("_CloudShadowTexture");
            internal static readonly int CloudShadowTiling = Shader.PropertyToID("_CloudShadowTiling");
            internal static readonly int CloudShadowParams = Shader.PropertyToID("_CloudShadowParams");
            internal static readonly int CloudShadowParams2 = Shader.PropertyToID("_CloudShadowParams2");
            internal static readonly int USECLOUDSHADOW = Shader.PropertyToID("_USECLOUDSHADOW");

        }
        // -------------------------------------------------------------------------------------

        public override void Setup() {}

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            cmd.SetGlobalFloat(ShaderConstants.USECLOUDSHADOW, 1);
            // TODO 如果只是静态图不用每帧更新
            cmd.SetGlobalTexture(ShaderConstants.CloudShadowTexture, settings.cloudShadowTexture.value);
            float tillingScale = 0.001f;
            cmd.SetGlobalVector(ShaderConstants.CloudShadowTiling, new Vector4(settings.cloudShadowTillingX.value * tillingScale, settings.cloudShadowTillingY.value * tillingScale, settings.cloudShadowTillOffsetX.value, settings.cloudShadowTillOffsetY.value));
            cmd.SetGlobalVector(ShaderConstants.CloudShadowParams, new Vector4(settings.cloudShadowCoverage.value, settings.cloudShadowSoftness.value, settings.cloudShadowTextureInvert.value ? 1.0f : 0.0f, settings.cloudShadowFade.value));
            cmd.SetGlobalVector(ShaderConstants.CloudShadowParams2, new Vector4(settings.cloudShadowSpeedX.value, settings.cloudShadowSpeedY.value, 1.0f / settings.cloudShadowDistance.value, 0));
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            cmd.SetGlobalFloat(ShaderConstants.USECLOUDSHADOW, 0);
        }

        public override void Render(CommandBuffer cmd, RenderTargetIdentifier source, RenderTargetIdentifier target, ref RenderingData renderingData) {}


    }
}