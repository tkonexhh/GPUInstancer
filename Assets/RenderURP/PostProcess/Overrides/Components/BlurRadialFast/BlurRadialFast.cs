using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Inutan.PostProcessing
{
    public class BlurRadialFast : PostProcessComponent
    {
        [Range(-0.5f, 0.5f)]
        public float Intensity = 0.125f;
        [Range(-2f, 2f)]
        public float MovX = 0.5f;
        [Range(-2f, 2f)]
        public float MovY = 0.5f;

        //
        public override PostProcessComponentRenderer Create() => new BlurRadialFastRenderer();

    }

    public class BlurRadialFastRenderer : PostProcessComponentRenderer
    {
        static class ShaderConstants
        {
            internal static readonly int Params = Shader.PropertyToID("_Params");
        }

        public override string name => "BlurRadialFast";
        public BlurRadialFast comp => m_Component as BlurRadialFast;

        Material m_BlurRadialFastMaterial;

        // ------------------------------------------------------------------------------------
        private void SetupMaterials(ref RenderingData renderingData)
        {
            m_BlurRadialFastMaterial.SetVector(ShaderConstants.Params, new Vector4(comp.Intensity, comp.MovX, comp.MovY, 0));
        }
     
        public override void Setup()
        {
            m_BlurRadialFastMaterial = GetMaterial(m_PostProcessFeatureData.shaders.blurRadialFastPS);
        }

        public override void Dispose(bool disposing) 
        {
            CoreUtils.Destroy(m_BlurRadialFastMaterial);
        }

        public override void Render(CommandBuffer cmd, RenderTargetIdentifier source, RenderTargetIdentifier target, ref RenderingData renderingData)
        {
            //
            SetupMaterials(ref renderingData);
            Blit(cmd, source, target, m_BlurRadialFastMaterial, 0);
        }
    }
}
