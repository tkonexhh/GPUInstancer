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

        // billboard extensions
        public static GPUInstancerPreviewCache previewCache;


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




    }
}
