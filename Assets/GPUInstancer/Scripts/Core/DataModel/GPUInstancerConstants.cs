using UnityEngine;

namespace GPUInstancer
{

    public static class GPUInstancerConstants
    {
        private static GPUInstancerSettings _gpuiSettings;
        public static GPUInstancerSettings gpuiSettings
        {
            get
            {
                if (_gpuiSettings == null)
                    _gpuiSettings = GPUInstancerSettings.GetDefaultGPUInstancerSettings();
                return _gpuiSettings;
            }
            set
            {
                _gpuiSettings = value;
            }
        }

        public static readonly Matrix4x4 zeroMatrix = Matrix4x4.zero;

        #region Stride Sizes
        // Compute buffer stride sizes
        public static readonly int STRIDE_SIZE_MATRIX4X4 = 64;
        public static readonly int STRIDE_SIZE_BOOL = 4;
        public static readonly int STRIDE_SIZE_INT = 4;
        public static readonly int STRIDE_SIZE_FLOAT = 4;
        public static readonly int STRIDE_SIZE_FLOAT4 = 16;
        #endregion Stride Sizes

        #region Platform Dependent

        public static float COMPUTE_SHADER_THREAD_COUNT = 512;
        public static float COMPUTE_SHADER_THREAD_COUNT_2D = 16;

        public static readonly string GUID_COMPUTE_PLATFORM_DEFINES = "74a30c752a8958c45a96bc127e05f114";
        public static readonly string GUID_CGINC_PLATFORM_DEPENDENT = "79e50e99a1888054cb229e1c710f1795";

        #endregion Platform Dependent

        #region CS Visibility
        public static class VisibilityKernelPoperties
        {
            public static readonly int TRANSFORMATION_MATRIX_BUFFER = Shader.PropertyToID("gpuiTransformationMatrix");
            public static readonly int RENDERER_TRANSFORM_OFFSET = Shader.PropertyToID("gpuiTransformOffset");
        }
        #endregion CS Visibility


        #region Shaders
        // Unity Shader Names
        public static readonly string SHADER_UNITY_STANDARD = "Standard";
        public static readonly string SHADER_UNITY_STANDARD_SPECULAR = "Standard (Specular setup)";
        public static readonly string SHADER_UNITY_STANDARD_ROUGHNESS = "Standard (Roughness setup)";
        public static readonly string SHADER_UNITY_VERTEXLIT = "VertexLit";
        public static readonly string SHADER_UNITY_SPEED_TREE = "Nature/SpeedTree";
        public static readonly string SHADER_UNITY_SPEED_TREE_8 = "Nature/SpeedTree8";
        public static readonly string SHADER_UNITY_TREE_CREATOR_BARK = "Nature/Tree Creator Bark";
        public static readonly string SHADER_UNITY_TREE_CREATOR_BARK_OPTIMIZED = "Hidden/Nature/Tree Creator Bark Optimized";
        public static readonly string SHADER_UNITY_TREE_CREATOR_LEAVES = "Nature/Tree Creator Leaves";
        public static readonly string SHADER_UNITY_TREE_CREATOR_LEAVES_OPTIMIZED = "Hidden/Nature/Tree Creator Leaves Optimized";
        public static readonly string SHADER_UNITY_TREE_CREATOR_LEAVES_FAST = "Nature/Tree Creator Leaves Fast";
        public static readonly string SHADER_UNITY_TREE_CREATOR_LEAVES_FAST_OPTIMIZED = "Hidden/Nature/Tree Creator Leaves Fast Optimized";
        public static readonly string SHADER_UNITY_TREE_SOFT_OCCLUSION_BARK = "Nature/Tree Soft Occlusion Bark";
        public static readonly string SHADER_UNITY_TREE_SOFT_OCCLUSION_LEAVES = "Nature/Tree Soft Occlusion Leaves";

        public static readonly string SHADER_UNITY_INTERNAL_ERROR = "Hidden/InternalErrorShader";

        // Default GPU Instanced Shader Names
        public static readonly string SHADER_GPUI_STANDARD = "GPUInstancer/Standard";
        public static readonly string SHADER_GPUI_STANDARD_SPECULAR = "GPUInstancer/Standard (Specular setup)";
        public static readonly string SHADER_GPUI_STANDARD_ROUGHNESS = "GPUInstancer/Standard (Roughness setup)";
        public static readonly string SHADER_GPUI_VERTEXLIT = "GPUInstancer/VertexLit";
        public static readonly string SHADER_GPUI_FOLIAGE = "GPUInstancer/Foliage";
        public static readonly string SHADER_GPUI_FOLIAGE_LWRP = "GPUInstancer/FoliageLWRP";

#if UNITY_2020_2_OR_NEWER
        public static readonly string SHADER_GPUI_FOLIAGE_URP = "GPUInstancer/FoliageURP_GPUI_SG";
#else
        public static readonly string SHADER_GPUI_FOLIAGE_URP = "GPUInstancer/FoliageURP";
#endif
        public static readonly string SHADER_GPUI_SHADOWS_ONLY = "Hidden/GPUInstancer/ShadowsOnly";


        public static readonly string SHADER_GPUI_SPEED_TREE = "GPUInstancer/Nature/SPDTree";
        public static readonly string SHADER_GPUI_SPEED_TREE_8 = "GPUInstancer/Nature/SPDTree8";
        public static readonly string SHADER_GPUI_TREE_PROXY = "Hidden/GPUInstancer/Nature/TreeProxy";
        public static readonly string SHADER_GPUI_TREE_CREATOR_BARK = "GPUInstancer/Nature/Tree Creator Bark";
        public static readonly string SHADER_GPUI_TREE_CREATOR_BARK_OPTIMIZED = "GPUInstancer/Nature/Tree Creator Bark Optimized";
        public static readonly string SHADER_GPUI_TREE_CREATOR_LEAVES = "GPUInstancer/Nature/Tree Creator Leaves";
        public static readonly string SHADER_GPUI_TREE_CREATOR_LEAVES_OPTIMIZED = "GPUInstancer/Nature/Tree Creator Leaves Optimized";
        public static readonly string SHADER_GPUI_TREE_CREATOR_LEAVES_FAST = "GPUInstancer/Nature/Tree Creator Leaves Fast";
        public static readonly string SHADER_GPUI_TREE_CREATOR_LEAVES_FAST_OPTIMIZED = "GPUInstancer/Nature/Tree Creator Leaves Fast Optimized";
        public static readonly string SHADER_GPUI_TREE_SOFT_OCCLUSION_BARK = "GPUInstancer/Nature/Tree Soft Occlusion Bark";
        public static readonly string SHADER_GPUI_TREE_SOFT_OCCLUSION_LEAVES = "GPUInstancer/Nature/Tree Soft Occlusion Leaves";
        public static readonly string SHADER_GPUI_BILLBOARD_2D_RENDERER_TREE = "GPUInstancer/Billboard/2DRendererTree";
        public static readonly string SHADER_GPUI_BILLBOARD_2D_RENDERER_TREECREATOR = "GPUInstancer/Billboard/2DRendererTreeCreator";
        public static readonly string SHADER_GPUI_BILLBOARD_2D_RENDERER_SOFTOCCLUSION = "GPUInstancer/Billboard/2DRendererSoftOcclusion";
        public static readonly string SHADER_GPUI_BILLBOARD_2D_RENDERER_STANDARD = "GPUInstancer/Billboard/2DRendererStandard";

        public static readonly string SHADER_GPUI_ERROR = "Hidden/GPUInstancer/InternalErrorShader";
        public static readonly string SHADER_GPUI_BILLBOARD_2D_RENDERER_URP = "GPUInstancer/Billboard/BillboardURP_GPUI";
        public static readonly string SHADER_GPUI_BILLBOARD_2D_RENDERER_HDRP = "GPUInstancer/Billboard/BillboardHDRP_GPUI";

        #endregion Shaders

        #region Paths
        // GPUInstancer Default Paths
        public static readonly string DEFAULT_PATH_GUID = "954b4ec3db4c00f46a67fcb9b4f72411";
        public static readonly string RESOURCES_PATH = "Resources/";
        public static readonly string SETTINGS_PATH = "Settings/";
        public static readonly string SHADERS_PATH = "Shaders/";
        public static readonly string EDITOR_TEXTURES_PATH = "Textures/Editor/";
        public static readonly string GPUI_SETTINGS_DEFAULT_NAME = "GPUInstancerSettings";
        public static readonly string SHADER_BINDINGS_DEFAULT_NAME = "GPUInstancerShaderBindings";
        public static readonly string SHADER_VARIANT_COLLECTION_DEFAULT_NAME = "GPUIShaderVariantCollection";
        public static readonly string PROTOTYPES_PREFAB_PATH = "PrototypeData/Prefab/";
        public static readonly string PROTOTYPES_SHADERS_PATH = "PrototypeData/Shaders/";
        public static readonly string PROTOTYPES_SERIALIZED_PATH = "PrototypeData/SerializedTransforms/";



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

        public static readonly string ERRORTEXT_cameraNotFound = "Main Camera cannot be found. GPU Instancer needs either an existing camera with the \"Main Camera\" tag on the scene to autoselect it, or a manually specified camera. If you add your camera at runtime, please use the \"GPUInstancerAPI.SetCamera\" API function.";

        // Debug
        public static readonly int DEBUG_INFO_SIZE = 105;

        public static readonly string ERRORTEXT_shaderGraph = "ShaderGraph shader does not contain GPU Instacer Setup: {0}. Please add GPUInstacer Setup from the ShaderGraph window.";

        #endregion Texts
    }
}