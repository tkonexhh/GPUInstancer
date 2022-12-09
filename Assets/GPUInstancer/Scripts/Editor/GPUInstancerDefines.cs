using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using UnityEditor;
using UnityEngine;

namespace GPUInstancer
{
    [InitializeOnLoad]
    public class GPUInstancerDefines
    {
        private static readonly string DEFINE_GPU_INSTANCER = "GPU_INSTANCER";
        private static readonly string[] AUTO_PACKAGE_IMPORTER_GUIDS = { "e134ae9cb2828d147a6ec91b020fcb63", "87dd7798fac1eed45bd360e61b272470" };

        // billboard extensions
        public static GPUInstancerPreviewCache previewCache;
        public static UnityEditor.PackageManager.Requests.ListRequest _packageListRequest;


        static GPUInstancerDefines()
        {
            if (EditorUserBuildSettings.selectedBuildTargetGroup == BuildTargetGroup.Unknown)
                return;
            List<string> defineList = new List<string>(PlayerSettings.GetScriptingDefineSymbolsForGroup(EditorUserBuildSettings.selectedBuildTargetGroup).Split(';'));
            if (!defineList.Contains(DEFINE_GPU_INSTANCER))
            {
                defineList.Add(DEFINE_GPU_INSTANCER);
                string defines = string.Join(";", defineList.ToArray());
                PlayerSettings.SetScriptingDefineSymbolsForGroup(EditorUserBuildSettings.selectedBuildTargetGroup, defines);
            }

            EditorApplication.update -= GenerateSettings;
            EditorApplication.update += GenerateSettings;

            if (previewCache == null)
                previewCache = new GPUInstancerPreviewCache();
        }

        static void GenerateSettings()
        {
            if (EditorApplication.isCompiling || EditorApplication.isUpdating)
                return;

            EditorApplication.update -= GenerateSettings;
        }

        public static void ImportPackages(bool forceReimport)
        {
            GPUIPackageImporter.ImportPackages(AUTO_PACKAGE_IMPORTER_GUIDS, forceReimport);
        }



        public static void LoadPackageDefinitions(bool forceNew = false)
        {
            if (forceNew || !GPUInstancerConstants.gpuiSettings.packagesLoaded)
            {
                _packageListRequest = UnityEditor.PackageManager.Client.List(true);
                GPUInstancerConstants.gpuiSettings.isHDRP = false;
                GPUInstancerConstants.gpuiSettings.isLWRP = false;
                GPUInstancerConstants.gpuiSettings.isShaderGraphPresent = false;
                EditorApplication.update -= PackageListRequestHandler;
                EditorApplication.update += PackageListRequestHandler;
            }
        }

        private static void PackageListRequestHandler()
        {
            try
            {
                if (_packageListRequest != null)
                {
                    if (!_packageListRequest.IsCompleted)
                        return;
                    if (_packageListRequest.Result != null)
                    {
                        foreach (var item in _packageListRequest.Result)
                        {
                            if (item.name.Contains("com.unity.render-pipelines.high-definition"))
                            {
                                GPUInstancerConstants.gpuiSettings.isHDRP = true;
                                Debug.Log("GPUI detected HD Render Pipeline.");
                            }
                            else if (item.name.Contains("com.unity.render-pipelines.lightweight"))
                            {
                                GPUInstancerConstants.gpuiSettings.isLWRP = true;
                                Debug.Log("GPUI detected LW Render Pipeline.");
                            }
                            else if (item.name.Contains("com.unity.render-pipelines.universal"))
                            {
                                GPUInstancerConstants.gpuiSettings.isURP = true;
                                Debug.Log("GPUI detected Universal Render Pipeline.");
                            }
                            else if (item.name.Contains("com.unity.shadergraph"))
                            {
                                GPUInstancerConstants.gpuiSettings.isShaderGraphPresent = true;
                                Debug.Log("GPUI detected ShaderGraph package.");
                            }
                        }

                        EditorUtility.SetDirty(GPUInstancerConstants.gpuiSettings);
                    }
                }
            }
            catch (Exception) { }
            _packageListRequest = null;
            GPUInstancerConstants.gpuiSettings.packagesLoaded = true;
            EditorApplication.update -= PackageListRequestHandler;
        }


        public static GPUInstancerShaderBindings GetGPUInstancerShaderBindings()
        {
            if (GPUInstancerConstants.gpuiSettings.shaderBindings == null)
                GPUInstancerConstants.gpuiSettings.shaderBindings = GPUInstancerSettings.GetDefaultGPUInstancerShaderBindings();
            return GPUInstancerConstants.gpuiSettings.shaderBindings;
        }

        public static ShaderVariantCollection GetShaderVariantCollection()
        {
            if (GPUInstancerConstants.gpuiSettings.shaderVariantCollection == null)
                GPUInstancerConstants.gpuiSettings.shaderVariantCollection = GPUInstancerSettings.GetDefaultShaderVariantCollection();
            return GPUInstancerConstants.gpuiSettings.shaderVariantCollection;
        }
    }
}
