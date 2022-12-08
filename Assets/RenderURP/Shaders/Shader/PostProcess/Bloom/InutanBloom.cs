using System;
using UnityEngine.Serialization;

namespace UnityEngine.Rendering.PostProcessing
{
    public enum MaskedBloomType
    {
        Origin = 0,
        Mixed = 1,
        Mask = 2,
        MaskedBloom = 3,
        OriginBloom = 4,
    }

    [Serializable]
    public sealed class MaskedBloomTypeParameter : ParameterOverride<MaskedBloomType> {}
   
    // -------------------------------------------------------------------------------------
    [Serializable]
    [PostProcess(typeof(InutanBloomRenderer), PostProcessEvent.BeforeStack, "Inutan/Bloom")]
    public sealed class InutanBloom : PostProcessEffectSettings
    {
        [Min(0f)]
        public FloatParameter intensity = new FloatParameter { value = 0f };

        [Min(0f)]
        public FloatParameter threshold = new FloatParameter { value = 1f };

        [Range(0f, 1f)]
        public FloatParameter softKnee = new FloatParameter { value = 0.5f };

        public FloatParameter clamp = new FloatParameter { value = 65472f };

        [Range(1f, 10f)]
        public FloatParameter diffusion = new FloatParameter { value = 7f };

        [Range(-1f, 1f)]
        public FloatParameter anamorphicRatio = new FloatParameter { value = 0f };
        
        [ColorUsage(false, true)]
        public ColorParameter color = new ColorParameter { value = Color.white };

        public BoolParameter fastMode = new BoolParameter { value = false };

      
        public override bool IsEnabledAndSupported(PostProcessRenderContext context)
        {
            return enabled.value
                && intensity.value > 0f;
        }


        /// ==================================================
        // Masked Bloom
        public BoolParameter useMaskedBloom = new BoolParameter { value = false };

        public MaskedBloomTypeParameter typeMasked = new MaskedBloomTypeParameter { value = MaskedBloomType.Mixed };

        [Range(0.25f, 5.5f)]
        public FloatParameter scaleMasked = new FloatParameter { value = 2f };

        [Range(0.0f, 1.5f)]
        public FloatParameter thresholdMasked = new FloatParameter { value = 1f };

        [Range(0.0f, 2.5f)]
        public FloatParameter intensityMasked = new FloatParameter { value = 1f };


        // ======================================================
    }

    [UnityEngine.Scripting.Preserve]
    internal sealed class InutanBloomRenderer : PostProcessEffectRenderer<InutanBloom>
    {
        enum Pass
        {
            Prefilter13,
            Prefilter4,
            Downsample13,
            Downsample4,
            UpsampleTent,
            UpsampleBox,
            DebugOverlayThreshold,
            DebugOverlayTent,
            DebugOverlayBox,
            Final
        }

        // [down,up]
        Level[] m_Pyramid;
        const int k_MaxPyramidSize = 16; // Just to make sure we handle 64k screens... Future-proof!

        struct Level
        {
            internal int down;
            internal int up;
        }

        public override void Init()
        {
            m_Pyramid = new Level[k_MaxPyramidSize];

            for (int i = 0; i < k_MaxPyramidSize; i++)
            {
                m_Pyramid[i] = new Level
                {
                    down = Shader.PropertyToID("_BloomMipDown" + i),
                    up = Shader.PropertyToID("_BloomMipUp" + i)
                };
            }

            InitMaskedBloom();
        }

        string shaderNameBloom = "Hidden/PostProcessing/Inutan/Bloom";
        string shaderNameBloomMasked = "Hidden/PostProcessing/Inutan/MaskedBloom";
        // ------------------------------------------------------------
        int downsampleTmpRTId;
        int upsampleTmpRTId;
        int[] bloomRTIds;

        void InitMaskedBloom()
        {
            downsampleTmpRTId = Shader.PropertyToID("_MaskedBloomDownsampleTex");
            upsampleTmpRTId = Shader.PropertyToID("_MaskedBloomUpsampleTex");

            bloomRTIds = new int[7];
            for(int i = 0; i <= 3; i ++)
            {
                bloomRTIds[i] = Shader.PropertyToID("_MaskedBloomDownSampled" + Mathf.Pow(2, i+3));
                if(i != 3)
                    bloomRTIds[i+4] = Shader.PropertyToID("_MaskedBloomUpSampled" + Mathf.Pow(2, 5-i));
            }
        }

        void MaskedBloomSetup(PropertySheet sheet)
        {
            sheet.DisableKeyword("MASKEDBLOOM_MIXED");
            sheet.DisableKeyword("MASKEDBLOOM_MASK");
            sheet.DisableKeyword("MASKEDBLOOM_MASKEDBLOOM");
            sheet.DisableKeyword("MASKEDBLOOM_ORIGINBLOOM");

            if(!settings.useMaskedBloom) return;

            sheet.properties.SetFloat("_MaskedBloomIntensity", Mathf.GammaToLinearSpace(settings.intensityMasked));

            switch((MaskedBloomType)settings.typeMasked)
            {
                case MaskedBloomType.Mixed:
                {
                    sheet.EnableKeyword("MASKEDBLOOM_MIXED");
                }
                    break;
                case MaskedBloomType.Mask:
                {
                    sheet.EnableKeyword("MASKEDBLOOM_MASK");
                }
                    break;
                case MaskedBloomType.MaskedBloom:
                {
                    sheet.EnableKeyword("MASKEDBLOOM_MASKEDBLOOM");
                }
                    break;
                case MaskedBloomType.OriginBloom:
                {
                    sheet.EnableKeyword("MASKEDBLOOM_ORIGINBLOOM");
                }
                    break;
            }
        }

        public void MaskedBloomRender(PostProcessRenderContext context)
        {
            if(!settings.useMaskedBloom) return;


            var cmd = context.command;
            cmd.BeginSample("MaskedBloom");

            var sheet = context.propertySheets.Get(Shader.Find(shaderNameBloomMasked));

            sheet.properties.SetFloat("_MaskedBloomThreshold", Mathf.GammaToLinearSpace(settings.thresholdMasked));
            sheet.properties.SetFloat("_MaskedBloomScale", settings.scaleMasked * 0.5f);

            int tw = Mathf.FloorToInt(context.screenWidth / 4);
            int th = Mathf.FloorToInt(context.screenHeight / 4);

            // Downsample to 1/4 first
            context.GetScreenSpaceTemporaryRT(cmd, downsampleTmpRTId, 0, context.sourceFormat, RenderTextureReadWrite.Default, FilterMode.Bilinear, tw, th);
            cmd.BlitFullscreenTriangle(context.source, downsampleTmpRTId, sheet, 0);

            for(int i = 0; i <= 3; i ++)
            {
                tw /= 2;
                th /= 2;

                context.GetScreenSpaceTemporaryRT(cmd, bloomRTIds[i], 0, context.sourceFormat, RenderTextureReadWrite.Default, FilterMode.Bilinear, tw, th);
                if(i != 3)
                    context.GetScreenSpaceTemporaryRT(cmd, bloomRTIds[6-i], 0, context.sourceFormat, RenderTextureReadWrite.Default, FilterMode.Bilinear, tw, th);

                int fromId = i == 0 ? downsampleTmpRTId : bloomRTIds[i-1];
                cmd.BlitFullscreenTriangle(fromId, bloomRTIds[i], sheet, 1);
            }

            for(int i = 2; i >= 0; i --)
            {
                cmd.SetGlobalTexture(upsampleTmpRTId, bloomRTIds[i]);
                cmd.BlitFullscreenTriangle(bloomRTIds[5-i], bloomRTIds[6-i], sheet, 2);
            }

            cmd.SetGlobalTexture("_BloomMasked", bloomRTIds[6]);
            
            cmd.EndSample("MaskedBloom");
        }

        private void MaskedBloomCleanUp(CommandBuffer cmd)
        {
            if(!settings.useMaskedBloom) return;

            cmd.ReleaseTemporaryRT(downsampleTmpRTId);

            if (bloomRTIds != null && bloomRTIds.Length > 0)
            {
                for (int i = 0; i < bloomRTIds.Length; i++)
                {
                    cmd.ReleaseTemporaryRT(bloomRTIds[i]);
                }
            }
        }


        public override void Render(PostProcessRenderContext context)
        {
            MaskedBloomRender(context);

            //
            var cmd = context.command;
            cmd.BeginSample("BloomPyramid");

            var sheet = context.propertySheets.Get(Shader.Find(shaderNameBloom));

            float ratio = Mathf.Clamp(settings.anamorphicRatio, -1, 1);
            float rw = ratio < 0 ? -ratio : 0f;
            float rh = ratio > 0 ?  ratio : 0f;

            int tw = Mathf.FloorToInt(context.screenWidth / (2f - rw));
            int th = Mathf.FloorToInt(context.screenHeight / (2f - rh));

            int s = Mathf.Max(tw, th);
            float logs = Mathf.Log(s, 2f) + Mathf.Min(settings.diffusion.value, 10f) - 10f;
            int logs_i = Mathf.FloorToInt(logs);
            int iterations = Mathf.Clamp(logs_i, 1, k_MaxPyramidSize);
            float sampleScale = 0.5f + logs - logs_i;
            sheet.properties.SetFloat(Shader.PropertyToID("_SampleScale"), sampleScale);

            float lthresh = Mathf.GammaToLinearSpace(settings.threshold.value);
            float knee = lthresh * settings.softKnee.value + 1e-5f;
            var threshold = new Vector4(lthresh, lthresh - knee, knee * 2f, 0.25f / knee);
            sheet.properties.SetVector(Shader.PropertyToID("_Threshold"), threshold);
            float lclamp = Mathf.GammaToLinearSpace(settings.clamp.value);
            sheet.properties.SetVector(Shader.PropertyToID("_Params"), new Vector4(lclamp, 0f, 0f, 0f));

            int qualityOffset = settings.fastMode ? 1 : 0;

            // Downsample
            var lastDown = context.source;
            for (int i = 0; i < iterations; i++)
            {
                int mipDown = m_Pyramid[i].down;
                int mipUp = m_Pyramid[i].up;
                int pass = i == 0
                    ? (int)Pass.Prefilter13 + qualityOffset
                    : (int)Pass.Downsample13 + qualityOffset;

                context.GetScreenSpaceTemporaryRT(cmd, mipDown, 0, context.sourceFormat, RenderTextureReadWrite.Default, FilterMode.Bilinear, tw, th);
                context.GetScreenSpaceTemporaryRT(cmd, mipUp, 0, context.sourceFormat, RenderTextureReadWrite.Default, FilterMode.Bilinear, tw, th);
                cmd.BlitFullscreenTriangle(lastDown, mipDown, sheet, pass);

                lastDown = mipDown;
                tw = Mathf.Max(tw / 2, 1);
                th = Mathf.Max(th / 2, 1);
            }

            // Upsample
            int lastUp = m_Pyramid[iterations - 1].down;
            for (int i = iterations - 2; i >= 0; i--)
            {
                int mipDown = m_Pyramid[i].down;
                int mipUp = m_Pyramid[i].up;
                cmd.SetGlobalTexture(Shader.PropertyToID("_BloomTex"), mipDown);
                cmd.BlitFullscreenTriangle(lastUp, mipUp, sheet, (int)Pass.UpsampleTent + qualityOffset);
                lastUp = mipUp;
            }

            var linearColor = settings.color.value.linear;
            float intensity = RuntimeUtilities.Exp2(settings.intensity.value / 10f) - 1f;
            // float intensity = Mathf.GammaToLinearSpace(settings.intensity.value);
            var shaderSettings = new Vector4(sampleScale, intensity, 0f, iterations);

            // Debug overlays
            if (context.IsDebugOverlayEnabled(DebugOverlay.BloomThreshold))
            {
                context.PushDebugOverlay(cmd, context.source, sheet, (int)Pass.DebugOverlayThreshold);
            }
            else if (context.IsDebugOverlayEnabled(DebugOverlay.BloomBuffer))
            {
                sheet.properties.SetVector(Shader.PropertyToID("_ColorIntensity"), new Vector4(linearColor.r, linearColor.g, linearColor.b, intensity));
                context.PushDebugOverlay(cmd, m_Pyramid[0].up, sheet, (int)Pass.DebugOverlayTent + qualityOffset);
            }

            // Shader properties
            if (settings.fastMode)
                sheet.EnableKeyword("BLOOM_LOW");
            else
                sheet.EnableKeyword("BLOOM");

            MaskedBloomSetup(sheet);
            sheet.properties.SetVector(Shader.PropertyToID("_Bloom_Settings"), shaderSettings);
            sheet.properties.SetColor(Shader.PropertyToID("_Bloom_Color"), linearColor);

            cmd.SetGlobalTexture(Shader.PropertyToID("_BloomTex"), lastUp);
            cmd.BlitFullscreenTriangle(context.source, context.destination, sheet, (int)Pass.Final);

            // Cleanup
            for (int i = 0; i < iterations; i++)
            {
                if (m_Pyramid[i].down != lastUp)
                    cmd.ReleaseTemporaryRT(m_Pyramid[i].down);
                if (m_Pyramid[i].up != lastUp)
                    cmd.ReleaseTemporaryRT(m_Pyramid[i].up);
            }

            cmd.EndSample("BloomPyramid");

            if (lastUp > -1) cmd.ReleaseTemporaryRT(lastUp);
            
            MaskedBloomCleanUp(cmd);
        }
    }
}
