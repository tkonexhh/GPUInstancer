#if UNITY_EDITOR
using UnityEditor;
using UnityEditor.ProjectWindowCallback;
#endif
using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Inutan.PostProcessing
{
    [Serializable]
    [CreateAssetMenu(menuName = "Inutan/PostProcessFeatureData")]
    public class PostProcessFeatureData : ScriptableObject
    {
        [Serializable]
        public sealed class ShaderResources
        {
            public Shader dualBlurPS;
            public Shader screenSpaceReflectionPS;
            public Shader screenSpaceOcclusionPS;
            public Shader temporalAntialiasingPS;
            public Shader temporalAntialiasingLitePS;

            public Shader flaresPS;
            public Shader lightShaftPS;
            public Shader bloomUnrealPS;
            public Shader lensFlaresPS;

            //
            public Shader blurRadialFastPS;

            public Shader foligeGPU;
            public Shader litGPU;
        }

        [Serializable]
        public sealed class TextureResources
        {
            public Texture2D blueNoiseTex;
        }

        public ShaderResources shaders;
        public TextureResources textures;
    }
}