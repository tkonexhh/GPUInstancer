using System;
using System.Collections.Generic;
using System.Linq;
using Unity.Collections;
using UnityEngine;
using UnityEngine.Events;

namespace GPUInstancer
{
    public static class GPUInstancerAPI
    {
        #region Global

        /// <summary>
        ///     <para>Main GPU Instancer initialization Method. Generates the necessary GPUInstancer runtime data from predifined 
        ///     GPU Instancer prototypes that are registered in the manager, and generates all necessary GPU buffers for instancing.</para>
        ///     <para>Use this as the final step after you setup a GPU Instancer manager and all its prototypes.</para>
        ///     <para>Note that you can also use this to re-initialize the GPU Instancer prototypes that are registered in the manager at runtime.</para>
        /// </summary>
        /// <param name="manager">The manager that defines the prototypes you want to GPU instance.</param>
        /// <param name="forceNew">If set to false the manager will not run initialization if it was already initialized before</param>
        public static void InitializeGPUInstancer(GPUInstancerManager manager, bool forceNew = true)
        {
            manager.InitializeRuntimeDataAndBuffers(forceNew);
        }

        /// <summary>
        ///     <para>Sets the active camera for all managers. This camera is used by GPU Instancer for various calculations (including culling operations). </para>
        ///     <para>Use this right after you add or change your camera at runtime. </para>
        /// </summary>
        /// <param name="camera">The camera that GPU Instancer will use.</param>
        public static void SetCamera(Camera camera)
        {
            if (GPUInstancerManager.activeManagerList != null)
                GPUInstancerManager.activeManagerList.ForEach(m => m.SetCamera(camera));
        }

        #endregion Global

        #region Editor Only
#if UNITY_EDITOR
        /// <summary>
        /// [EDITOR-ONLY] Shader auto-conversion can be run with this method without using a GPUI Manager
        /// </summary>
        /// <param name="shader">Shader to convert</param>
        /// <returns>True if successful</returns>
        public static bool SetupShaderForGPUI(Shader shader)
        {
            if (shader == null || shader.name == GPUInstancerConstants.SHADER_UNITY_INTERNAL_ERROR)
            {
                Debug.LogError("Can not find shader! Please make sure that the material has a shader assigned.");
                return false;
            }
            GPUInstancerConstants.gpuiSettings.shaderBindings.ClearEmptyShaderInstances();
            if (!GPUInstancerConstants.gpuiSettings.shaderBindings.IsShadersInstancedVersionExists(shader.name))
            {
                if (GPUInstancerUtility.IsShaderInstanced(shader))
                {
                    GPUInstancerConstants.gpuiSettings.shaderBindings.AddShaderInstance(shader.name, shader, true);
                    Debug.Log("Shader setup for GPUI has been successfully completed.");
                    return true;
                }
                else
                {
                    Shader instancedShader = GPUInstancerUtility.CreateInstancedShader(shader);
                    if (instancedShader != null)
                    {
                        GPUInstancerConstants.gpuiSettings.shaderBindings.AddShaderInstance(shader.name, instancedShader);
                        return true;
                    }
                    else
                    {
                        string originalAssetPath = UnityEditor.AssetDatabase.GetAssetPath(shader);
                        if (originalAssetPath.ToLower().EndsWith(".shadergraph"))
                            Debug.LogError(string.Format(GPUInstancerConstants.ERRORTEXT_shaderGraph, shader.name));
                        else
                            Debug.LogError("Can not create instanced version for shader: " + shader.name + ".");
                        return false;
                    }
                }
            }
            else
            {
                Debug.Log(shader.name + " shader has already been setup for GPUI.");
                return true;
            }
        }

        /// <summary>
        /// [EDITOR-ONLY] Adds the shader variant used in the given material to the GPUIShaderVariantCollection. This collection is used to include the shader variants with GPUI support in your builds.
        /// Normally GPUI Managers makes this automatically, but if you generate your managers at runtime, this method can be usefull to add these shader variants manually.
        /// </summary>
        /// <param name="material"></param>
        public static void AddShaderVariantToCollection(Material material)
        {
            GPUInstancerConstants.gpuiSettings.AddShaderVariantToCollection(material);
        }


#endif
        #endregion Editor Only
    }
}
