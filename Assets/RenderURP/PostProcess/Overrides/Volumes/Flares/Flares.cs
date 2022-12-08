using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Inutan.PostProcessing
{
    [Serializable, VolumeComponentMenuForRenderPipeline("Post-processing Inutan/Flares",typeof(UniversalRenderPipeline))]
    public class Flares : VolumeSetting
    {
        // ----------------------------------------------------------------------------------------------------
        [Tooltip("半径")]
        public ClampedFloatParameter radius = new ClampedFloatParameter(0.15f, 0f, 1f);

        [Tooltip("横向拉伸")]
        public ClampedFloatParameter scaleX = new ClampedFloatParameter(1f, 1f, 5f);

        [Tooltip("0表示限制在屏幕边缘 越大就不被限制")]
        public FloatRangeParameter extent = new FloatRangeParameter(new Vector2(0, 1), 0, 2);

        [Tooltip("渐变")]
        public ClampedFloatParameter gradient = new ClampedFloatParameter(0f, 0f, 1f);

        [Tooltip("渐变次方")]
        public ClampedFloatParameter power = new ClampedFloatParameter(1f, 0.01f, 5f);
       
        [Tooltip("颜色")]
        public ColorParameter color = new ColorParameter(Color.white, false, false, false);

        [Tooltip("强度")]
        public ClampedFloatParameter intensity = new ClampedFloatParameter(1f, 0f, 10f);

        [Tooltip("Gamma空间下计算")]
        public BoolParameter gamma = new BoolParameter(true);

        [Tooltip("光源方向, 打开勾选可以在SceneView中Gizmos控制")]
        [DirectHandle]
        public DirectionParameter mainLightDir = new DirectionParameter(Vector3.zero, false, false);

        public override bool IsActive() => radius.overrideState && radius.value > 0
                                        && intensity.overrideState && intensity.value > 0
                                        && mainLightDir.overrideState;
    }

    [PostProcess("Flares", PostProcessInjectionPoint.BeforeRenderingPostProcessing)]
    public class FlaresRenderer : PostProcessVolumeRenderer<Flares>
    {
        static class ShaderConstants
        {
            internal static readonly int MainLightUV = Shader.PropertyToID("_MainLightUV");
            internal static readonly int Params1 = Shader.PropertyToID("_Params1");
            internal static readonly int Params2 = Shader.PropertyToID("_Params2");

            internal static readonly int Color = Shader.PropertyToID("_Color");
        }

        Material m_FlaresMaterial;

        // 3000作为锚定点半径
        const float MAINLIGHT_DISTANCE = 3000;
        // ------------------------------------------------------------------------------------
        string[] m_ShaderKeywords = new string[1];
        
        private void SetupMaterials(ref RenderingData renderingData)
        {
            var camera = renderingData.cameraData.camera;

            Vector4 mainLightDir = settings.mainLightDir.value;
            
            Vector3 mainLightPositionWS = (Quaternion.Euler(mainLightDir.x, mainLightDir.y, mainLightDir.z) * Vector3.forward).normalized * MAINLIGHT_DISTANCE;
            var mainLightUV = camera.WorldToViewportPoint(mainLightPositionWS);

            m_FlaresMaterial.SetVector(ShaderConstants.MainLightUV, mainLightUV);
            m_FlaresMaterial.SetVector(ShaderConstants.Params1, new Vector4(settings.radius.value, settings.gradient.value, settings.power.value, settings.intensity.value));
            m_FlaresMaterial.SetVector(ShaderConstants.Params2, new Vector4(settings.extent.value.x, settings.extent.value.y, settings.scaleX.value, MAINLIGHT_DISTANCE));
            m_FlaresMaterial.SetColor(ShaderConstants.Color, settings.color.value.linear);

            // -------------------------------------------------------------------------------------------------
            // local shader keywords
            m_ShaderKeywords[0] = settings.gamma.value ? "CALCULATE_IN_GAMMASPACE" : "_";
            m_FlaresMaterial.shaderKeywords = m_ShaderKeywords;
        }
     
        public override void Setup()
        {
            m_FlaresMaterial = GetMaterial(m_PostProcessFeatureData.shaders.flaresPS);
        }

        public override void Dispose(bool disposing) 
        {
            CoreUtils.Destroy(m_FlaresMaterial);
        }

        public override void Render(CommandBuffer cmd, RenderTargetIdentifier source, RenderTargetIdentifier target, ref RenderingData renderingData)
        {
            //
            SetupMaterials(ref renderingData);
            Blit(cmd, source, target, m_FlaresMaterial, 0);
        }
    }
}
