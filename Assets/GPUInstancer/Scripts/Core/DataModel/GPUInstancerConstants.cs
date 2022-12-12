using UnityEngine;

namespace GPUInstancer
{

    public static class GPUInstancerConstants
    {

        #region Stride Sizes
        // Compute buffer stride sizes
        public static readonly int STRIDE_SIZE_MATRIX4X4 = 64;
        public static readonly int STRIDE_SIZE_BOOL = 4;
        public static readonly int STRIDE_SIZE_INT = 4;
        public static readonly int STRIDE_SIZE_FLOAT = 4;
        public static readonly int STRIDE_SIZE_FLOAT4 = 16;
        #endregion Stride Sizes

        #region CS Visibility
        public static class VisibilityKernelPoperties
        {
            public static readonly int TRANSFORMATION_MATRIX_BUFFER = Shader.PropertyToID("gpuiTransformationMatrix");
            public static readonly int RENDERER_TRANSFORM_OFFSET = Shader.PropertyToID("gpuiTransformOffset");
        }
        #endregion CS Visibility


        #region Shaders
        // Unity Shader Names


        public static readonly string SHADER_GPUI_ERROR = "Hidden/GPUInstancer/InternalErrorShader";

        #endregion Shaders

        #region Paths
        // GPUInstancer Default Paths
        public static readonly string DEFAULT_PATH_GUID = "954b4ec3db4c00f46a67fcb9b4f72411";
        public static readonly string PROTOTYPES_PREFAB_PATH = "PrototypeData/Prefab/";


        private static string _defaultPath;
        public static string GetDefaultPath()
        {
            if (string.IsNullOrEmpty(_defaultPath))
            {
#if UNITY_EDITOR
                _defaultPath = UnityEditor.AssetDatabase.GUIDToAssetPath(DEFAULT_PATH_GUID);
                if (!string.IsNullOrEmpty(_defaultPath))
                    _defaultPath = _defaultPath.Replace("Resources/Editor/GPUInstancerPathLocator.asset", "");
#endif
                if (string.IsNullOrEmpty(_defaultPath))
                    _defaultPath = "Assets/GPUInstancer/";
            }
            return _defaultPath;
        }
        #endregion Paths

        #region Texts
        // Editor Texts
        public static readonly string TEXT_PREFAB_TYPE_WARNING_TITLE = "Prefab Type Warning";
        public static readonly string TEXT_PREFAB_TYPE_WARNING = "GPU Instancer Prefab Manager only accepts user created prefabs. Cannot add selected object.";

        public static readonly string TEXT_PREFAB_TYPE_WARNING_3D = "GPU Instancer Prefab Manager only accepts user created prefabs. Please create a prefab from this imported 3D model asset.";
        public static readonly string TEXT_OK = "OK";

        #endregion Texts
    }
}