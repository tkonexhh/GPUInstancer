using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;

namespace UnityEditor.Rendering.PostProcessing
{
    [PostProcessEditor(typeof(InutanBloom))]
    internal sealed class InutanBloomEditor : PostProcessEffectEditor<InutanBloom>
    {
        SerializedParameterOverride m_Intensity;
        SerializedParameterOverride m_Threshold;
        SerializedParameterOverride m_SoftKnee;
        SerializedParameterOverride m_Clamp;
        SerializedParameterOverride m_Diffusion;
        SerializedParameterOverride m_AnamorphicRatio;
        SerializedParameterOverride m_Color;
        SerializedParameterOverride m_FastMode;

        SerializedParameterOverride m_DirtTexture;
        SerializedParameterOverride m_DirtIntensity;

        ///////
        SerializedParameterOverride useMaskedBloom;
        SerializedParameterOverride typeMasked;
        SerializedParameterOverride scaleMasked;
        SerializedParameterOverride thresholdMasked;
        SerializedParameterOverride intensityMasked;

        public override void OnEnable()
        {
            m_Intensity = FindParameterOverride(x => x.intensity);
            m_Threshold = FindParameterOverride(x => x.threshold);
            m_SoftKnee = FindParameterOverride(x => x.softKnee);
            m_Clamp = FindParameterOverride(x => x.clamp);
            m_Diffusion = FindParameterOverride(x => x.diffusion);
            m_AnamorphicRatio = FindParameterOverride(x => x.anamorphicRatio);
            m_Color = FindParameterOverride(x => x.color);
            m_FastMode = FindParameterOverride(x => x.fastMode);

            // 
            useMaskedBloom = FindParameterOverride(x => x.useMaskedBloom);
            typeMasked = FindParameterOverride(x => x.typeMasked);
            scaleMasked = FindParameterOverride(x => x.scaleMasked);
            thresholdMasked = FindParameterOverride(x => x.thresholdMasked);
            intensityMasked = FindParameterOverride(x => x.intensityMasked);
        }

        public override void OnInspectorGUI()
        {
            EditorUtilities.DrawHeaderLabel("Bloom");

            PropertyField(m_Intensity);
            PropertyField(m_Threshold);
            PropertyField(m_SoftKnee);
            PropertyField(m_Clamp);
            PropertyField(m_Diffusion);
            PropertyField(m_AnamorphicRatio);
            PropertyField(m_Color);
            PropertyField(m_FastMode);

            EditorGUILayout.Space();
            PropertyField(useMaskedBloom);

            if(useMaskedBloom.overrideState.boolValue)
            {
                EditorUtilities.DrawHeaderLabel("BloomMasked");
                PropertyField(typeMasked);
                PropertyField(scaleMasked);
                PropertyField(thresholdMasked);
                PropertyField(intensityMasked);
            }
        }
    }
}
