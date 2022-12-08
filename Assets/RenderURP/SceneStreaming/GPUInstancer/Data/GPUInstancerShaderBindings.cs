using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Inutan
{
    public class GPUInstancerShaderBindings
    {
        static GPUInstancerShaderBindings()
        {
            _standardShaders.Add(SHADER_INUTAN_FOLIAGE); _standardShadersGPUI.Add(GPUI_SHADER_INUTAN_FOLIAGE);
            _standardShaders.Add(SHADER_URP_LIT); _standardShadersGPUI.Add(GPUI_SHADER_URP_LIT);
            _standardShaders.Add(SHADER_URP_HIDDEN_LIT); _standardShadersGPUI.Add(GPUI_SHADER_URP_LIT);
        }

        private static List<string> _standardShaders = new List<string> { };
        private static List<string> _standardShadersGPUI = new List<string> { };

        #region Shaders
        static readonly string SHADER_INUTAN_FOLIAGE = "Inutan/URP/Scene/Foliage/Foliage 植物"; static readonly string GPUI_SHADER_INUTAN_FOLIAGE = "Hidden/Inutan/URP/Scene/Foliage/Foliage 植物 GPUInstance";
        static readonly string SHADER_URP_LIT = "Universal Render Pipeline/Lit"; static readonly string GPUI_SHADER_URP_LIT = "Hidden/Universal Render Pipeline/Lit GPUInstance";
        static readonly string SHADER_URP_HIDDEN_LIT = "Hidden/Universal Render Pipeline/Lit";

        static readonly string SHADER_GPUI_ERROR = "Hidden/Inutan/GPUInstancer/InternalErrorShader";
        #endregion Shaders

        public static Shader GetInstancedShader(string shaderName)
        {
            if (string.IsNullOrEmpty(shaderName))
                return null;

            if (_standardShaders.Contains(shaderName))
            {
                return Shader.Find(_standardShadersGPUI[_standardShaders.IndexOf(shaderName)]);
            }

            if (_standardShadersGPUI.Contains(shaderName))
                return Shader.Find(shaderName);

            Debug.LogError("目标Shader 未提供Indirect版本: " + shaderName);
            return Shader.Find(SHADER_GPUI_ERROR);
        }
    }
}
