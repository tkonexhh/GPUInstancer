using System;
using System.Collections.Generic;
using UnityEngine;

namespace GPUInstancer
{
    public class GPUInstancerShaderBindings
    {

        private static List<string> _standardUnityShaders = new List<string> { };
        private static List<string> _standardShadersGPUI = new List<string> { };

        static readonly string SHADER_URP_LIT = "Universal Render Pipeline/Lit"; static readonly string GPUI_SHADER_URP_LIT = "GPUInstancer/Universal Render Pipeline/Lit";
        static readonly string SHADER_URP_HIDDEN_LIT = "Hidden/Universal Render Pipeline/Lit";

        static GPUInstancerShaderBindings()
        {
            // _standardUnityShaders.Add(SHADER_INUTAN_FOLIAGE); _standardUnityShaders.Add(GPUI_SHADER_INUTAN_FOLIAGE);
            _standardUnityShaders.Add(SHADER_URP_LIT); _standardShadersGPUI.Add(GPUI_SHADER_URP_LIT);
            _standardUnityShaders.Add(SHADER_URP_HIDDEN_LIT); _standardShadersGPUI.Add(GPUI_SHADER_URP_LIT);
        }


        public virtual Shader GetInstancedShader(string shaderName, string extensionCode = null)
        {

            if (string.IsNullOrEmpty(shaderName))
                return null;

            if (_standardUnityShaders.Contains(shaderName))
                return Shader.Find(_standardShadersGPUI[_standardUnityShaders.IndexOf(shaderName)]);

            if (_standardShadersGPUI.Contains(shaderName))
                return Shader.Find(shaderName);

            Debug.LogError("Can not find GPU Instancer setup for shader: " + shaderName + ". Check prototype settings on the Manager for instructions.", Shader.Find(shaderName));
            return Shader.Find(GPUInstancerConstants.SHADER_GPUI_ERROR);
        }

        public virtual Material GetInstancedMaterial(Material originalMaterial, string extensionCode = null)
        {

            if (originalMaterial == null || originalMaterial.shader == null)
            {
                Debug.LogWarning("One of the GPU Instancer prototypes is missing material reference! Check the Material references in MeshRenderer.");
                return new Material(Shader.Find(GPUInstancerConstants.SHADER_GPUI_ERROR));
            }

            Material instancedMaterial = new Material(GetInstancedShader(originalMaterial.shader.name));
            instancedMaterial.CopyPropertiesFromMaterial(originalMaterial);
            instancedMaterial.name = originalMaterial.name + "_GPUI";

            return instancedMaterial;
        }
    }


}