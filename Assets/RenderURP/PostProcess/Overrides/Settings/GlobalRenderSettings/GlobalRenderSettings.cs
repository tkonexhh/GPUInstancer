using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Inutan.PostProcessing
{
    [Serializable, VolumeComponentMenuForRenderPipeline("GlobalRenderSettings Inutan", typeof(UniversalRenderPipeline))]
    public class GlobalRenderSettings : VolumeSetting
    {
        [InspectorName("URP PBR / PI"), Tooltip("切换成URP默认的PBR公式, 为了对齐效果除以了PI")]
        public BoolParameter urpPBRDivPI = new BoolParameter(false);

        [InspectorName("PBR * PI"), Tooltip("直接光整体乘以PI, 等同于Unity默认PBR的强度")]
        public BoolParameter pbrMultiPI = new BoolParameter(false);

        [Header("角色")]
        [Tooltip("基于场景曝光值进行偏移"), InspectorName("调整角色曝光")]
        public FloatParameter characterExposure = new FloatParameter(0f);

        [Header("植物")]
        [Tooltip("直接光固有色比例"), InspectorName("直接光固有色比例")]
        public ClampedFloatParameter directAlbedoIntensity = new ClampedFloatParameter(1f, 0f, 1f);
        [Tooltip("环境光漫反射颜色"), InspectorName("环境光漫反射颜色")]
        public ColorParameter inDirectDiffuseColor = new ColorParameter(Color.white, true, true, false);
        [Tooltip("亮部环境光比例"), InspectorName("亮部环境光比例")]
        public ClampedFloatParameter inDirectLightPercent = new ClampedFloatParameter(1f, 0f, 1f);
        [Tooltip("暗部环境光比例"), InspectorName("暗部环境光比例")]
        public ClampedFloatParameter inDirectShadePercent = new ClampedFloatParameter(1f, 0f, 1f);

        [Header("CameraFade")]
        [Tooltip("Editor下显示CameraFade"), InspectorName("Editor下显示CameraFade")]
        public BoolParameter useCameraFadeInEditor = new BoolParameter(false);
        [Tooltip("CameraFade类型"), InspectorName("CameraFade类型")]
        public ClampedIntParameter cameraFadeType = new ClampedIntParameter(2, 1, 5);

        public override bool IsActive()
        {
            return true;
        }
    }

    [PostProcess("GlobalRenderSettings", PostProcessInjectionPoint.BeforeRenderingDeferredLights)]
    public class GlobalRenderSettingsRenderer : PostProcessVolumeRenderer<GlobalRenderSettings>
        {
            static class ShaderConstants
            {
                internal static readonly int characterExposureMulti = Shader.PropertyToID("_CharacterExposureMulti");

                internal static readonly int GLOBAL_INDIRECT_ADJUST_PARAMS = Shader.PropertyToID("_GLOBAL_INDIRECT_ADJUST_PARAMS");
                internal static readonly int GLOBAL_INDIRECT_DIFFUSE_COLOR = Shader.PropertyToID("_GLOBAL_INDIRECT_DIFFUSE_COLOR");

                internal static readonly int GLOBAL_CAMERAFADE_PARAMS = Shader.PropertyToID("_GLOBAL_CAMERAFADE_PARAMS");
            }
            // -------------------------------------------------------------------------------------

            static readonly string GLOBAL_USE_CAMERAFADE = "_GLOBAL_USE_CAMERAFADE"; // 标记是否在editor下使用cameraFade
            static readonly string GLOBAL_RENDERSETTINGS_ENABLEKEYWORD = "_GLOBALRENDERSETTINGSENABLEKEYWORD";
            static readonly string GLOBAL_RENDERSETTINGS_URPPBRDIVPI = "_GLOBAL_RENDERSETTINGS_URPPBRDIVPI";
            static readonly string GLOBAL_RENDERSETTINGS_PBRMULTIPI = "_GLOBAL_RENDERSETTINGS_PBRMULTIPI";

            public static bool RuntimeUseCameraFade
            {
                get
                {
                    return m_RuntimeUseCameraFade;
                }
                set
                {
                    m_RuntimeUseCameraFade = value;
                }
            }
            static bool m_RuntimeUseCameraFade = true;

            public override void Setup()
            {

            }
            public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
            {
                CoreUtils.SetKeyword(cmd, GLOBAL_USE_CAMERAFADE, renderingData.cameraData.isSceneViewCamera ? (settings.useCameraFadeInEditor.value) : m_RuntimeUseCameraFade);
                CoreUtils.SetKeyword(cmd, GLOBAL_RENDERSETTINGS_ENABLEKEYWORD, true);
                CoreUtils.SetKeyword(cmd, GLOBAL_RENDERSETTINGS_URPPBRDIVPI, settings.urpPBRDivPI.value);
                CoreUtils.SetKeyword(cmd, GLOBAL_RENDERSETTINGS_PBRMULTIPI, settings.pbrMultiPI.value);

                cmd.SetGlobalVector(ShaderConstants.GLOBAL_INDIRECT_ADJUST_PARAMS, new Vector4(settings.directAlbedoIntensity.value, settings.inDirectLightPercent.value, settings.inDirectShadePercent.value, 1f));
                cmd.SetGlobalColor(ShaderConstants.GLOBAL_INDIRECT_DIFFUSE_COLOR, settings.inDirectDiffuseColor.value);

                cmd.SetGlobalFloat(ShaderConstants.characterExposureMulti, Mathf.Pow(2f, settings.characterExposure.value));

                cmd.SetGlobalVector(ShaderConstants.GLOBAL_CAMERAFADE_PARAMS, new Vector4(settings.cameraFadeType.value, 0, 0, 0));
            }

            public override void OnCameraCleanup(CommandBuffer cmd)
            {
                CoreUtils.SetKeyword(cmd, GLOBAL_USE_CAMERAFADE, true);
                CoreUtils.SetKeyword(cmd, GLOBAL_RENDERSETTINGS_ENABLEKEYWORD, false);
                CoreUtils.SetKeyword(cmd, GLOBAL_RENDERSETTINGS_PBRMULTIPI, false);
                CoreUtils.SetKeyword(cmd, GLOBAL_RENDERSETTINGS_URPPBRDIVPI, false);

                cmd.SetGlobalVector(ShaderConstants.GLOBAL_INDIRECT_ADJUST_PARAMS, new Vector4(1f, 1f, 1f, 1f));
                cmd.SetGlobalColor(ShaderConstants.GLOBAL_INDIRECT_DIFFUSE_COLOR, Color.white);

                cmd.SetGlobalVector(ShaderConstants.GLOBAL_CAMERAFADE_PARAMS, new Vector4(1, 1, 0, 0));
            }

            public override void Render(CommandBuffer cmd, RenderTargetIdentifier source, RenderTargetIdentifier target, ref RenderingData renderingData) {}

            public override void ShowHide(bool showHide) {}

        }
}