using System.Collections.Generic;
using UnityEngine;
using System;
#if UNITY_EDITOR
using UnityEditor;
#endif

namespace GPUInstancer
{
    public class GPUInstancerSettings : ScriptableObject
    {

        public GPUInstancerShaderBindings shaderBindings;
        public bool packagesLoaded;

        public int instancingBoundsSize = 10000;



        #region Editor Constants
        public float MAX_PREFAB_DISTANCE = 10000;
        #endregion Editor Constants

        public static GPUInstancerSettings GetDefaultGPUInstancerSettings()
        {
            GPUInstancerSettings gpuiSettings = Resources.Load<GPUInstancerSettings>(GPUInstancerConstants.SETTINGS_PATH + GPUInstancerConstants.GPUI_SETTINGS_DEFAULT_NAME);

            if (gpuiSettings == null)
            {
                gpuiSettings = ScriptableObject.CreateInstance<GPUInstancerSettings>();
#if UNITY_EDITOR
                if (!Application.isPlaying)
                {
                    if (!System.IO.Directory.Exists(GPUInstancerConstants.GetDefaultPath() + GPUInstancerConstants.RESOURCES_PATH + GPUInstancerConstants.SETTINGS_PATH))
                    {
                        System.IO.Directory.CreateDirectory(GPUInstancerConstants.GetDefaultPath() + GPUInstancerConstants.RESOURCES_PATH + GPUInstancerConstants.SETTINGS_PATH);
                    }

                    AssetDatabase.CreateAsset(gpuiSettings, GPUInstancerConstants.GetDefaultPath() + GPUInstancerConstants.RESOURCES_PATH + GPUInstancerConstants.SETTINGS_PATH + GPUInstancerConstants.GPUI_SETTINGS_DEFAULT_NAME + ".asset");
                    AssetDatabase.SaveAssets();
                    AssetDatabase.Refresh();
                }
#endif
            }
            gpuiSettings.SetDefultBindings();
            return gpuiSettings;
        }

        public virtual void SetDefultBindings()
        {
            SetDefaultGPUInstancerShaderBindings();
        }

        #region Shader Bindings
        public virtual void SetDefaultGPUInstancerShaderBindings()
        {
            if (shaderBindings == null)
            {
#if UNITY_EDITOR
                if (!Application.isPlaying)
                    Undo.RecordObject(this, "GPUInstancerShaderBindings instance generated");
#endif
                shaderBindings = GetDefaultGPUInstancerShaderBindings();
            }
        }

        public static GPUInstancerShaderBindings GetDefaultGPUInstancerShaderBindings()
        {
            GPUInstancerShaderBindings shaderBindings = Resources.Load<GPUInstancerShaderBindings>(GPUInstancerConstants.SETTINGS_PATH + GPUInstancerConstants.SHADER_BINDINGS_DEFAULT_NAME);

            if (shaderBindings == null)
            {
                shaderBindings = ScriptableObject.CreateInstance<GPUInstancerShaderBindings>();
                shaderBindings.ResetShaderInstances();
#if UNITY_EDITOR
                if (!Application.isPlaying)
                {
                    if (!System.IO.Directory.Exists(GPUInstancerConstants.GetDefaultPath() + GPUInstancerConstants.RESOURCES_PATH + GPUInstancerConstants.SETTINGS_PATH))
                    {
                        System.IO.Directory.CreateDirectory(GPUInstancerConstants.GetDefaultPath() + GPUInstancerConstants.RESOURCES_PATH + GPUInstancerConstants.SETTINGS_PATH);
                    }

                    AssetDatabase.CreateAsset(shaderBindings, GPUInstancerConstants.GetDefaultPath() + GPUInstancerConstants.RESOURCES_PATH + GPUInstancerConstants.SETTINGS_PATH + GPUInstancerConstants.SHADER_BINDINGS_DEFAULT_NAME + ".asset");
                    AssetDatabase.SaveAssets();
                    AssetDatabase.Refresh();
                }
#endif
            }

            return shaderBindings;
        }
        #endregion Shader Bindings

    }

}
