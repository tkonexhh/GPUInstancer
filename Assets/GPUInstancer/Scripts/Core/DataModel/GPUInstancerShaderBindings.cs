using System;
using System.Collections.Generic;
using UnityEngine;

namespace GPUInstancer
{
    public class GPUInstancerShaderBindings : ScriptableObject
    {
        public List<ShaderInstance> shaderInstances;

        private static readonly List<string> _standardUnityShaders = new List<string> {
            GPUInstancerConstants.SHADER_UNITY_STANDARD, GPUInstancerConstants.SHADER_UNITY_STANDARD_SPECULAR,
            GPUInstancerConstants.SHADER_UNITY_STANDARD_ROUGHNESS, GPUInstancerConstants.SHADER_UNITY_VERTEXLIT,
            GPUInstancerConstants.SHADER_UNITY_SPEED_TREE, GPUInstancerConstants.SHADER_UNITY_SPEED_TREE_8,
            GPUInstancerConstants.SHADER_UNITY_TREE_CREATOR_BARK, GPUInstancerConstants.SHADER_UNITY_TREE_CREATOR_BARK_OPTIMIZED,
            GPUInstancerConstants.SHADER_UNITY_TREE_CREATOR_LEAVES, GPUInstancerConstants.SHADER_UNITY_TREE_CREATOR_LEAVES_OPTIMIZED,
            GPUInstancerConstants.SHADER_UNITY_TREE_CREATOR_LEAVES_FAST, GPUInstancerConstants.SHADER_UNITY_TREE_CREATOR_LEAVES_FAST_OPTIMIZED,
            GPUInstancerConstants.SHADER_UNITY_TREE_SOFT_OCCLUSION_BARK, GPUInstancerConstants.SHADER_UNITY_TREE_SOFT_OCCLUSION_LEAVES
        };
        private static readonly List<string> _standardUnityShadersGPUI = new List<string> {
            GPUInstancerConstants.SHADER_GPUI_STANDARD, GPUInstancerConstants.SHADER_GPUI_STANDARD_SPECULAR,
            GPUInstancerConstants.SHADER_GPUI_STANDARD_ROUGHNESS, GPUInstancerConstants.SHADER_GPUI_VERTEXLIT,
            GPUInstancerConstants.SHADER_GPUI_SPEED_TREE, GPUInstancerConstants.SHADER_GPUI_SPEED_TREE_8,
            GPUInstancerConstants.SHADER_GPUI_TREE_CREATOR_BARK, GPUInstancerConstants.SHADER_GPUI_TREE_CREATOR_BARK_OPTIMIZED,
            GPUInstancerConstants.SHADER_GPUI_TREE_CREATOR_LEAVES, GPUInstancerConstants.SHADER_GPUI_TREE_CREATOR_LEAVES_OPTIMIZED,
            GPUInstancerConstants.SHADER_GPUI_TREE_CREATOR_LEAVES_FAST, GPUInstancerConstants.SHADER_GPUI_TREE_CREATOR_LEAVES_FAST_OPTIMIZED,
            GPUInstancerConstants.SHADER_GPUI_TREE_SOFT_OCCLUSION_BARK, GPUInstancerConstants.SHADER_GPUI_TREE_SOFT_OCCLUSION_LEAVES
        };


        public virtual Shader GetInstancedShader(string shaderName, string extensionCode = null)
        {

            if (string.IsNullOrEmpty(shaderName))
                return null;

            if (shaderInstances == null)
                shaderInstances = new List<ShaderInstance>();

            foreach (ShaderInstance si in shaderInstances)
            {
                if (si.name.Equals(shaderName) && string.IsNullOrEmpty(si.extensionCode))
                    return si.instancedShader;
            }

            if (_standardUnityShaders.Contains(shaderName))
                return Shader.Find(_standardUnityShadersGPUI[_standardUnityShaders.IndexOf(shaderName)]);

            if (_standardUnityShadersGPUI.Contains(shaderName))
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
            if (GPUInstancerConstants.gpuiSettings.useOriginalMaterialWhenInstanced && IsOriginalShaderInstanced(originalMaterial.shader.name))
                return originalMaterial;
            Material instancedMaterial = new Material(GetInstancedShader(originalMaterial.shader.name));
            instancedMaterial.CopyPropertiesFromMaterial(originalMaterial);
            instancedMaterial.name = originalMaterial.name + "_GPUI";

            return instancedMaterial;
        }

        public virtual void ResetShaderInstances()
        {
            if (shaderInstances == null)
                shaderInstances = new List<ShaderInstance>();
            else
                shaderInstances.Clear();

#if UNITY_EDITOR
            UnityEditor.EditorUtility.SetDirty(this);
#endif
        }


        public virtual bool IsOriginalShaderInstanced(string shaderName)
        {
            if (_standardUnityShadersGPUI.Contains(shaderName))
                return true;

            foreach (ShaderInstance si in shaderInstances)
            {
                if (si.name.Equals(shaderName) && si.isOriginalInstanced)
                    return true;
            }
            return false;
        }
    }

    [Serializable]
    public class ShaderInstance
    {
        public string name;
        public Shader instancedShader;
        public string modifiedDate;
        public bool isOriginalInstanced;
        public string extensionCode;

        public ShaderInstance(string name, Shader instancedShader, bool isOriginalInstanced, string extensionCode = null)
        {
            this.name = name;
            this.instancedShader = instancedShader;
            this.modifiedDate = DateTime.Now.ToString("MM/dd/yyyy HH:mm:ss.fff",
                                System.Globalization.CultureInfo.InvariantCulture);
            this.isOriginalInstanced = isOriginalInstanced;
            this.extensionCode = extensionCode;
        }
    }

}