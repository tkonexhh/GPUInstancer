using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Events;
using Unity.Collections;
using UnityEngine.Jobs;
#if UNITY_EDITOR
using UnityEditor;
#endif

namespace GPUInstancer
{
    public static class GPUInstancerUtility
    {
        #region GPU Instancing

        /// <summary>
        /// Initializes GPU buffer related data for the instance prototypes. Instance transformation matrices must be generated before this.
        /// </summary>
        public static void InitializeGPUBuffers<T>(List<T> runtimeDataList) where T : GPUInstancerRuntimeData
        {
            if (runtimeDataList == null || runtimeDataList.Count == 0)
                return;

            for (int i = 0; i < runtimeDataList.Count; i++)
            {
                InitializeGPUBuffer(runtimeDataList[i]);
            }
        }

        public static void InitializeGPUBuffer<T>(T runtimeData) where T : GPUInstancerRuntimeData
        {
            if (runtimeData == null || runtimeData.bufferSize == 0)
                return;


            #region Set Visibility Buffer
            // Setup the visibility compute buffer
            if (runtimeData.transformationMatrixVisibilityBuffer == null || runtimeData.transformationMatrixVisibilityBuffer.count != runtimeData.bufferSize)
            {
                if (runtimeData.transformationMatrixVisibilityBuffer != null)
                    runtimeData.transformationMatrixVisibilityBuffer.Release();
                runtimeData.transformationMatrixVisibilityBuffer = new ComputeBuffer(runtimeData.bufferSize, GPUInstancerConstants.STRIDE_SIZE_MATRIX4X4);
                if (runtimeData.instanceDataNativeArray.IsCreated)
                    runtimeData.transformationMatrixVisibilityBuffer.SetData(runtimeData.instanceDataNativeArray);
            }

            #endregion Set Visibility Buffer

            #region Set Args Buffer
            if (runtimeData.argsBuffer == null)
            {
                // Initialize indirect renderer buffer
                int totalSubMeshCount = 0;

                for (int j = 0; j < runtimeData.renderers.Count; j++)
                {
                    totalSubMeshCount += runtimeData.renderers[j].mesh.subMeshCount;
                }

                // Initialize indirect renderer buffer. First LOD's each renderer's all submeshes will be followed by second LOD's each renderer's submeshes and so on.
                runtimeData.args = new uint[5 * totalSubMeshCount];
                int argsLastIndex = 0;

                // setup LOD renderers:
                for (int r = 0; r < runtimeData.renderers.Count; r++)
                {
                    runtimeData.renderers[r].argsBufferOffset = argsLastIndex;
                    // Setup the indirect renderer buffer:
                    for (int j = 0; j < runtimeData.renderers[r].mesh.subMeshCount; j++)
                    {
                        runtimeData.args[argsLastIndex++] = runtimeData.renderers[r].mesh.GetIndexCount(j); // index count per instance
                        runtimeData.args[argsLastIndex++] = 0;// (uint)runtimeData.bufferSize;
                        runtimeData.args[argsLastIndex++] = runtimeData.renderers[r].mesh.GetIndexStart(j); // start index location
                        runtimeData.args[argsLastIndex++] = 0; // base vertex location
                        runtimeData.args[argsLastIndex++] = 0; // start instance location
                    }
                }

                if (runtimeData.args.Length > 0)
                {
                    runtimeData.argsBuffer = new ComputeBuffer(runtimeData.args.Length, sizeof(uint), ComputeBufferType.IndirectArguments);
                    runtimeData.argsBuffer.SetData(runtimeData.args);
                }
            }
            #endregion Set Args Buffer

            SetAppendBuffers(runtimeData);
        }

        #region Set Append Buffers Platform Dependent
        public static void SetAppendBuffers<T>(T runtimeData) where T : GPUInstancerRuntimeData
        {
            foreach (GPUInstancerRenderer renderer in runtimeData.renderers)
            {
                // Setup instance LOD renderer material property block shader buffers with the append buffer
                renderer.mpb.SetBuffer(GPUInstancerConstants.VisibilityKernelPoperties.TRANSFORMATION_MATRIX_BUFFER, runtimeData.transformationMatrixVisibilityBuffer);
                renderer.mpb.SetMatrix(GPUInstancerConstants.VisibilityKernelPoperties.RENDERER_TRANSFORM_OFFSET, renderer.transformOffset);
            }
        }

        #endregion Set Append Buffers Platform Dependent


        public static void UpdateGPUBuffers<T>(List<T> runtimeDataList, GPUInstancerCameraData cameraData, bool isManagerFrustumCulling) where T : GPUInstancerRuntimeData
        {
            if (runtimeDataList == null)
                return;

            for (int i = 0; i < runtimeDataList.Count; i++)
            {
                UpdateGPUBuffer(runtimeDataList[i], cameraData, isManagerFrustumCulling);
            }
        }

        public static void UpdateGPUBuffer<T>(T runtimeData, GPUInstancerCameraData cameraData, bool isManagerFrustumCulling) where T : GPUInstancerRuntimeData
        {
            if (runtimeData == null)
                return;

            if (runtimeData.transformationMatrixVisibilityBuffer == null || runtimeData.bufferSize == 0 || runtimeData.instanceCount == 0)
            {
                if (runtimeData.args != null)
                {
                    runtimeData.args[1] = 0;
                }
                return;
            }
            runtimeData.args[1] = (uint)runtimeData.instanceCount;
            runtimeData.transformationMatrixVisibilityBuffer.SetData(runtimeData.instanceDataNativeArray);
            runtimeData.argsBuffer.SetData(runtimeData.args);
        }

        public static void GPUIDrawMeshInstancedIndirect<T>(List<T> runtimeDataList, Bounds instancingBounds, GPUInstancerCameraData cameraData) where T : GPUInstancerRuntimeData
        {
            if (runtimeDataList == null)
                return;

            Camera rendereringCamera = cameraData.GetRenderingCamera();
            foreach (T runtimeData in runtimeDataList)
            {
                if (runtimeData == null || runtimeData.transformationMatrixVisibilityBuffer == null || runtimeData.bufferSize == 0 || runtimeData.instanceCount == 0)
                    continue;

                // Everything is ready; execute the instanced indirect rendering. We execute a drawcall for each submesh of each LOD.
                GPUInstancerRenderer rdRenderer;
                Material rdMaterial;
                int offset = 0;
                int submeshIndex = 0;

                for (int r = 0; r < runtimeData.renderers.Count; r++)
                {
                    rdRenderer = runtimeData.renderers[r];
                    for (int m = 0; m < rdRenderer.materials.Count; m++)
                    {
                        rdMaterial = rdRenderer.materials[m];
                        submeshIndex = Math.Min(m, rdRenderer.mesh.subMeshCount - 1);
                        offset = (rdRenderer.argsBufferOffset + 5 * submeshIndex) * GPUInstancerConstants.STRIDE_SIZE_INT;

                        Graphics.DrawMeshInstancedIndirect(rdRenderer.mesh, submeshIndex,
                            rdMaterial,
                            instancingBounds,
                            runtimeData.argsBuffer,
                            offset,
                            rdRenderer.mpb,
                            ShadowCastingMode.Off,
                            rdRenderer.receiveShadows,
                            rdRenderer.layer
                            );
                    }

                }
            }
        }



        public static bool IsInLayer(int layerMask, int layer)
        {
            return layerMask == (layerMask | (1 << layer));
        }
        #endregion GPU Instancing

        #region Prototype Release

        public static void ReleaseInstanceBuffers<T>(List<T> runtimeDataList) where T : GPUInstancerRuntimeData
        {
            if (runtimeDataList == null)
                return;

            for (int i = 0; i < runtimeDataList.Count; i++)
            {
                ReleaseInstanceBuffers(runtimeDataList[i]);
            }
        }

        public static void ReleaseInstanceBuffers<T>(T runtimeData) where T : GPUInstancerRuntimeData
        {
            if (runtimeData == null)
                return;

            if (runtimeData.transformationMatrixVisibilityBuffer != null)
                runtimeData.transformationMatrixVisibilityBuffer.Release();
            runtimeData.transformationMatrixVisibilityBuffer = null;

            if (runtimeData.argsBuffer != null)
                runtimeData.argsBuffer.Release();
            runtimeData.argsBuffer = null;

            runtimeData.ReleaseBuffers();
        }


        #endregion Prototype Release

        #region Create Prototypes


        #region Create Prefab Prototypes

        public static void SetPrefabInstancePrototypes(GameObject gameObject, List<GPUInstancerPrototype> prototypeList, List<GameObject> prefabList, bool forceNew)
        {
            if (prefabList == null)
                return;

#if UNITY_EDITOR
            if (!Application.isPlaying)
                Undo.RecordObject(gameObject, "Prefab prototypes changed");

            bool changed = false;
            if (forceNew)
            {
                foreach (GPUInstancerPrefabPrototype prototype in prototypeList)
                {
                    AssetDatabase.DeleteAsset(AssetDatabase.GetAssetPath(prototype));
                    changed = true;
                }
            }
            else
            {
                foreach (GPUInstancerPrefabPrototype prototype in prototypeList)
                {
                    if (!prefabList.Contains(prototype.prefabObject))
                    {
                        AssetDatabase.DeleteAsset(AssetDatabase.GetAssetPath(prototype));
                        changed = true;
                    }
                }
            }
            if (changed)
            {
                AssetDatabase.SaveAssets();
                AssetDatabase.Refresh();
            }
#endif

            foreach (GameObject go in prefabList)
            {
                if (!forceNew && prototypeList.Exists(p => p.prefabObject == go))
                    continue;

                prototypeList.Add(GeneratePrefabPrototype(go, forceNew));
            }

#if UNITY_EDITOR
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();

            if (!Application.isPlaying)
            {
                GPUInstancerPrefab[] prefabInstances = GameObject.FindObjectsOfType<GPUInstancerPrefab>();
                for (int i = 0; i < prefabInstances.Length; i++)
                {
#if UNITY_2018_2_OR_NEWER
                    UnityEngine.Object prefabRoot = PrefabUtility.GetCorrespondingObjectFromSource(prefabInstances[i].gameObject);
#else
                    UnityEngine.Object prefabRoot = PrefabUtility.GetPrefabParent(prefabInstances[i].gameObject);
#endif
                    if (prefabRoot != null && ((GameObject)prefabRoot).GetComponent<GPUInstancerPrefab>() != null && prefabInstances[i].prefabPrototype != ((GameObject)prefabRoot).GetComponent<GPUInstancerPrefab>().prefabPrototype)
                    {
                        Undo.RecordObject(prefabInstances[i], "Changed GPUInstancer Prefab Prototype " + prefabInstances[i].gameObject + i);
                        prefabInstances[i].prefabPrototype = ((GameObject)prefabRoot).GetComponent<GPUInstancerPrefab>().prefabPrototype;
                    }
                }
            }
#endif
        }

        public static GPUInstancerPrefabPrototype GeneratePrefabPrototype(GameObject go, bool forceNew, bool attachScript = true)
        {
            GPUInstancerPrefab prefabScript = go.GetComponent<GPUInstancerPrefab>();
            if (attachScript && prefabScript == null)
#if UNITY_2018_3_OR_NEWER && UNITY_EDITOR
                prefabScript = AddComponentToPrefab<GPUInstancerPrefab>(go);
#else
                prefabScript = go.AddComponent<GPUInstancerPrefab>();
#endif
            if (attachScript && prefabScript == null)
                return null;

            GPUInstancerPrefabPrototype prototype = null;
            if (prefabScript != null)
                prototype = prefabScript.prefabPrototype;
            if (prototype == null)
            {
                prototype = ScriptableObject.CreateInstance<GPUInstancerPrefabPrototype>();
                if (prefabScript != null)
                    prefabScript.prefabPrototype = prototype;
                prototype.prefabObject = go;
                prototype.name = go.name + "_" + go.GetInstanceID();
                // DetermineTreePrototypeType(prototype);


                // GenerateInstancedShadersForGameObject(prototype);

#if UNITY_EDITOR
                if (!Application.isPlaying)
                    EditorUtility.SetDirty(go);
#endif
            }
#if UNITY_EDITOR
            if (!Application.isPlaying && string.IsNullOrEmpty(AssetDatabase.GetAssetPath(prototype)))
            {
                string assetPath = GPUInstancerConstants.GetDefaultPath() + GPUInstancerConstants.PROTOTYPES_PREFAB_PATH + prototype.name + ".asset";

                if (!System.IO.Directory.Exists(GPUInstancerConstants.GetDefaultPath() + GPUInstancerConstants.PROTOTYPES_PREFAB_PATH))
                {
                    System.IO.Directory.CreateDirectory(GPUInstancerConstants.GetDefaultPath() + GPUInstancerConstants.PROTOTYPES_PREFAB_PATH);
                }

                AssetDatabase.CreateAsset(prototype, assetPath);
            }

            if (!Application.isPlaying && prefabScript != null && prefabScript.prefabPrototype != prototype)
            {
                GameObject prefabContents = LoadPrefabContents(go);
                prefabContents.GetComponent<GPUInstancerPrefab>().prefabPrototype = prototype;
                UnloadPrefabContents(go, prefabContents);
            }

#endif
            return prototype;
        }

        #endregion

        #endregion



        #region Shader Functions

        public static bool IsShaderInstanced(Shader shader)
        {
#if UNITY_EDITOR
            if (shader == null || shader.name == GPUInstancerConstants.SHADER_UNITY_INTERNAL_ERROR)
            {
                Debug.LogError("Can not find shader! Please make sure that the material has a shader assigned.");
                return false;
            }
            string originalAssetPath = AssetDatabase.GetAssetPath(shader);
            string originalShaderText = "";
            try
            {
                originalShaderText = System.IO.File.ReadAllText(originalAssetPath);
            }
            catch (Exception)
            {
                return false;
            }
            if (!string.IsNullOrEmpty(originalShaderText))
            {
                if (originalAssetPath.ToLower().EndsWith(".shadergraph"))
                {
                    return originalShaderText.Contains("GPUInstancerShaderGraphNode") || originalShaderText.Contains("GPU Instancer Setup");
                }
                else
                {
                    return originalShaderText.Contains("GPUInstancerInclude.cginc");
                }
            }
#endif
            return false;
        }

        public static Shader CreateInstancedShader(Shader originalShader, bool useOriginal = false)
        {
#if UNITY_EDITOR
            try
            {
                if (originalShader == null || originalShader.name == GPUInstancerConstants.SHADER_UNITY_INTERNAL_ERROR)
                {
                    Debug.LogError("Can not find shader! Please make sure that the material has a shader assigned.");
                    return null;
                }
                Shader originalShaderRef = Shader.Find(originalShader.name);
                string originalAssetPath = AssetDatabase.GetAssetPath(originalShaderRef);

                // can not work with ShaderGraph or other non shader code
                if (!originalAssetPath.EndsWith(".shader"))
                    return null;

                EditorUtility.DisplayProgressBar("GPU Instancer Shader Conversion", "Creating instanced shader for " + originalShader.name + ". Please wait...", 0.1f);

                string[] originalLines = System.IO.File.ReadAllLines(originalAssetPath);
                #region Remove Existing procedural setup
                System.Text.StringBuilder sb = new System.Text.StringBuilder();
                using (System.IO.StreamReader sr = new System.IO.StreamReader(originalAssetPath))
                {
                    while (!sr.EndOfStream)
                    {
                        string line = sr.ReadLine();
                        if (!line.Contains("#pragma instancing_options")
                        && !line.Contains("GPUInstancerInclude.cginc")
                        //&& !line.Contains("#include \"UnityCG.cginc\"")
                        && !line.Contains("#pragma multi_compile_instancing"))
                            sb.Append(line + "\n");
                    }
                }
                string originalShaderText = sb.ToString();
                #endregion Remove Existing procedural setup

                bool createInDefaultFolder = false;
                // create shader versions for packages inside GPUI folder
                if (originalAssetPath.StartsWith("Packages/"))
                    createInDefaultFolder = true;


                // Packages/com.unity.render-pipelines.universal/Shaders/Lit.shader
                // if URP, replace relative paths
                bool isURP = false;
                string urpIncludeAddition = "Packages/com.unity.render-pipelines.universal/";
                if (originalShader.name.StartsWith("Universal Render Pipeline/"))
                {
                    isURP = true;
                    string[] urpSplit = originalAssetPath.Split('/');
                    bool foundURP = false;
                    for (int i = 0; i < urpSplit.Length; i++)
                    {
                        if (urpSplit[i].Contains(".shader"))
                            break;
                        if (foundURP)
                        {
                            urpIncludeAddition += urpSplit[i] + "/";
                        }
                        else
                        {
                            if (urpSplit[i] == "com.unity.render-pipelines.universal")
                                foundURP = true;
                        }
                    }
                }

                EditorUtility.DisplayProgressBar("GPU Instancer Shader Conversion", "Creating instanced shader for " + originalShader.name + ".  Please wait...", 0.5f);

                string newShaderName = useOriginal ? "" : "GPUInstancer/" + originalShader.name;
                string newShaderText = useOriginal ? originalShaderText.Replace("\r\n", "\n") : originalShaderText.Replace("\r\n", "\n").Replace(originalShader.name, newShaderName);

                string includePath = "Include/GPUInstancerInclude.cginc";
                string standardShaderPath = AssetDatabase.GetAssetPath(Shader.Find(GPUInstancerConstants.SHADER_GPUI_STANDARD));
                if (string.IsNullOrEmpty(standardShaderPath))
                    standardShaderPath = GPUInstancerConstants.GetDefaultPath() + GPUInstancerConstants.SHADERS_PATH + "Standard_GPUI.shader";
                string[] oapSplit = originalAssetPath.Split('/');
                if (createInDefaultFolder)
                {
                    if (!System.IO.Directory.Exists(GPUInstancerConstants.GetDefaultPath() + GPUInstancerConstants.PROTOTYPES_SHADERS_PATH))
                        System.IO.Directory.CreateDirectory(GPUInstancerConstants.GetDefaultPath() + GPUInstancerConstants.PROTOTYPES_SHADERS_PATH);

                    originalAssetPath = GPUInstancerConstants.GetDefaultPath() + GPUInstancerConstants.PROTOTYPES_SHADERS_PATH + oapSplit[oapSplit.Length - 1];
                    oapSplit = originalAssetPath.Split('/');
                }
                string[] sspSplit = standardShaderPath.Split('/');
                int startIndex = 0;
                for (int i = 0; i < oapSplit.Length - 1; i++)
                {
                    if (oapSplit[i] == sspSplit[i])
                        startIndex++;
                    else break;
                }
                for (int i = sspSplit.Length - 2; i >= startIndex; i--)
                {
                    includePath = sspSplit[i] + "/" + includePath;
                }
                //includePath = System.IO.Path.GetDirectoryName(standardShaderPath) + "/" + includePath;

                for (int i = startIndex; i < oapSplit.Length - 1; i++)
                {
                    includePath = "../" + includePath;
                }
                includePath = "./" + includePath;

                // For vertex/fragment and surface shaders
                #region CGPROGRAM
                int lastIndex = 0;
                string searchStart = "CGPROGRAM";
                string additionTextStart = "\n#include \"UnityCG.cginc\"\n#include \"" + includePath + "\"\n#pragma instancing_options procedural:setupGPUI\n#pragma multi_compile_instancing";
                string searchEnd = "ENDCG";
                string additionTextEnd = "";//"#include \"" + includePath + "\"\n";

                int foundIndex = -1;
                while (true)
                {
                    foundIndex = newShaderText.IndexOf(searchStart, lastIndex);
                    if (foundIndex == -1)
                        break;
                    lastIndex = foundIndex + searchStart.Length + additionTextStart.Length + 1;

                    newShaderText = newShaderText.Substring(0, foundIndex + searchStart.Length) + additionTextStart + newShaderText.Substring(foundIndex + searchStart.Length, newShaderText.Length - foundIndex - searchStart.Length);

                    foundIndex = newShaderText.IndexOf(searchEnd, lastIndex);
                    lastIndex = foundIndex + searchStart.Length + additionTextEnd.Length + 1;
                    newShaderText = newShaderText.Substring(0, foundIndex) + additionTextEnd + newShaderText.Substring(foundIndex, newShaderText.Length - foundIndex);
                }
                #endregion CGPROGRAM



                // For URP Shaders Include relative path fix
                #region URP relative path fix
                if (isURP && createInDefaultFolder)
                {
                    lastIndex = 0;
                    searchStart = "#include \"";
                    searchEnd = "\"";
                    string restOfText;

                    foundIndex = -1;
                    while (true)
                    {
                        foundIndex = newShaderText.IndexOf(searchStart, lastIndex);
                        if (foundIndex == -1)
                            break;
                        lastIndex = foundIndex + searchStart.Length + 1;

                        restOfText = newShaderText.Substring(foundIndex + searchStart.Length, newShaderText.Length - foundIndex - searchStart.Length);
                        if (!restOfText.StartsWith("URP") && !restOfText.StartsWith("CoreRP") && !restOfText.StartsWith("Packages"))
                        {
                            newShaderText = newShaderText.Substring(0, foundIndex + searchStart.Length) + urpIncludeAddition + restOfText;
                            lastIndex += urpIncludeAddition.Length;
                        }

                        foundIndex = newShaderText.IndexOf(searchEnd, lastIndex);
                        lastIndex = foundIndex;
                    }
                }
                #endregion URP relative path fix

                // For SRP Shaders
                #region HLSLPROGRAM
                lastIndex = 0;
                searchStart = "HLSLPROGRAM";
                additionTextStart = GPUInstancerConstants.gpuiSettings.isHDRP ? "\n#include \"Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl\"\n#include \"Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl\"\n\n#include \"" + includePath + "\"\n#pragma instancing_options procedural:setupGPUI\n#pragma multi_compile_instancing\n" : "";
                searchEnd = "ENDHLSL";
                additionTextEnd = GPUInstancerConstants.gpuiSettings.isHDRP ? "" : "\n#include \"" + includePath + "\"\n#pragma instancing_options procedural:setupGPUI\n#pragma multi_compile_instancing\n";

                foundIndex = -1;
                while (true)
                {
                    foundIndex = newShaderText.IndexOf(searchStart, lastIndex);
                    if (foundIndex == -1)
                        break;
                    lastIndex = foundIndex + searchStart.Length + additionTextStart.Length + 1;

                    newShaderText = newShaderText.Substring(0, foundIndex + searchStart.Length) + additionTextStart + newShaderText.Substring(foundIndex + searchStart.Length, newShaderText.Length - foundIndex - searchStart.Length);

                    foundIndex = newShaderText.IndexOf(searchEnd, lastIndex);
                    lastIndex = foundIndex + searchStart.Length + additionTextEnd.Length + 1;
                    newShaderText = newShaderText.Substring(0, foundIndex) + additionTextEnd + newShaderText.Substring(foundIndex, newShaderText.Length - foundIndex);
                }
                #endregion HLSLPROGRAM

                string originalFileName = System.IO.Path.GetFileName(originalAssetPath);
                string newAssetPath = useOriginal ? originalAssetPath : originalAssetPath.Replace(originalFileName, originalFileName.Replace(".shader", "_GPUI.shader"));

                byte[] bytes = System.Text.Encoding.UTF8.GetBytes(newShaderText);
                // VersionControlCheckout(newAssetPath);
                System.IO.FileStream fs = System.IO.File.Create(newAssetPath);
                fs.Write(bytes, 0, bytes.Length);
                fs.Close();
                //System.IO.File.WriteAllText(newAssetPath, newShaderText);
                EditorUtility.DisplayProgressBar("GPU Instancer Shader Conversion", "Importing instanced shader for " + originalShader.name, 0.8f);
                AssetDatabase.ImportAsset(newAssetPath, ImportAssetOptions.ForceUpdate);
                AssetDatabase.Refresh();

                Shader instancedShader = AssetDatabase.LoadAssetAtPath<Shader>(newAssetPath);
                if (instancedShader == null)
                    instancedShader = Shader.Find(newShaderName);

                if (instancedShader != null)
                    Debug.Log("Generated GPUI support enabled version for shader: " + originalShader.name, instancedShader);
                EditorUtility.ClearProgressBar();

                return instancedShader;
            }
            catch (Exception e)
            {
                if (e is System.IO.DirectoryNotFoundException && e.Message.ToLower().Contains("unity_builtin_extra"))
                    Debug.LogError("\"" + originalShader.name + "\" shader is a built-in shader which is not included in GPUI package. Please download the original shader file from Unity Archive to enable auto-conversion for this shader. Check prototype settings on the Manager for instructions.");
                else
                    Debug.LogException(e);
                EditorUtility.ClearProgressBar();
            }
#endif
            return null;
        }

        #endregion Shader Functions

        #region Extensions
        public static Matrix4x4 Matrix4x4FromString(string matrixStr)
        {
            Matrix4x4 matrix4x4 = new Matrix4x4();
            string[] floatStrArray = matrixStr.Split(';');
            for (int i = 0; i < floatStrArray.Length; i++)
            {
                matrix4x4[i / 4, i % 4] = float.Parse(floatStrArray[i]);
            }
            return matrix4x4;
        }

        public static string Matrix4x4ToString(Matrix4x4 matrix4x4)
        {
            string matrix4X4String = matrix4x4.ToString().Replace("\n", ";").Replace("\t", ";");
            matrix4X4String = matrix4X4String.Substring(0, matrix4X4String.Length - 1);
            return matrix4X4String;
        }

        public static void SetMatrix4x4ToTransform(this Transform transform, Matrix4x4 matrix)
        {
            transform.position = matrix.GetColumn(3);
            transform.localScale = new Vector3(
                                matrix.GetColumn(0).magnitude,
                                matrix.GetColumn(1).magnitude,
                                matrix.GetColumn(2).magnitude
                                );
            transform.rotation = Quaternion.LookRotation(matrix.GetColumn(2), matrix.GetColumn(1));
        }

        public static NativeArray<T> ResizeNativeArray<T>(NativeArray<T> previousArray, int newSize, Allocator allocator) where T : struct
        {
            NativeArray<T> result = new NativeArray<T>(newSize, allocator);
            if (previousArray.IsCreated)
            {
                int count = Math.Min(previousArray.Length, newSize);
                for (int i = 0; i < count; i++)
                {
                    result[i] = previousArray[i];
                }
                previousArray.Dispose();
            }
            return result;
        }


        #endregion Extensions



        #region Prefab System
#if UNITY_EDITOR
        public static T AddComponentToPrefab<T>(GameObject prefabObject) where T : Component
        {
            PrefabAssetType prefabType = PrefabUtility.GetPrefabAssetType(prefabObject);

            if (prefabType == PrefabAssetType.Regular || prefabType == PrefabAssetType.Variant)
            {
                string prefabPath = AssetDatabase.GetAssetPath(prefabObject);
                if (string.IsNullOrEmpty(prefabPath))
                    return null;
                GameObject prefabContents = PrefabUtility.LoadPrefabContents(prefabPath);

                prefabContents.AddComponent<T>();

                PrefabUtility.SaveAsPrefabAsset(prefabContents, prefabPath);
                PrefabUtility.UnloadPrefabContents(prefabContents);

                return prefabObject.GetComponent<T>();
            }

            return prefabObject.AddComponent<T>();
        }

        public static void RemoveComponentFromPrefab<T>(GameObject prefabObject) where T : Component
        {
            string prefabPath = AssetDatabase.GetAssetPath(prefabObject);
            if (string.IsNullOrEmpty(prefabPath))
                return;
            GameObject prefabContents = PrefabUtility.LoadPrefabContents(prefabPath);

            T component = prefabContents.GetComponent<T>();
            if (component)
            {
                GameObject.DestroyImmediate(component, true);
            }

            PrefabUtility.SaveAsPrefabAsset(prefabContents, prefabPath);
            PrefabUtility.UnloadPrefabContents(prefabContents);
        }

        public static GameObject LoadPrefabContents(GameObject prefabObject)
        {
            string prefabPath = AssetDatabase.GetAssetPath(prefabObject);
            if (string.IsNullOrEmpty(prefabPath))
                return null;
            return PrefabUtility.LoadPrefabContents(prefabPath);
        }

        public static void UnloadPrefabContents(GameObject prefabObject, GameObject prefabContents, bool saveChanges = true)
        {
            if (!prefabContents)
                return;
            if (saveChanges)
            {
                string prefabPath = AssetDatabase.GetAssetPath(prefabObject);
                if (string.IsNullOrEmpty(prefabPath))
                    return;
                PrefabUtility.SaveAsPrefabAsset(prefabContents, prefabPath);
            }
            PrefabUtility.UnloadPrefabContents(prefabContents);
            if (prefabContents)
            {
                Debug.Log("Destroying prefab contents...");
                GameObject.DestroyImmediate(prefabContents);
            }
        }

        public static GameObject GetCorrespongingPrefabOfVariant(GameObject variant)
        {
            GameObject result = variant;
            PrefabAssetType prefabType = PrefabUtility.GetPrefabAssetType(result);
            if (prefabType == PrefabAssetType.Variant)
            {
                if (PrefabUtility.IsPartOfNonAssetPrefabInstance(result))
                    result = GetOutermostPrefabAssetRoot(result);

                prefabType = PrefabUtility.GetPrefabAssetType(result);
                if (prefabType == PrefabAssetType.Variant)
                    result = GetOutermostPrefabAssetRoot(result);
            }
            return result;
        }

        public static GameObject GetOutermostPrefabAssetRoot(GameObject prefabInstance)
        {
            GameObject result = prefabInstance;
            GameObject newPrefabObject = PrefabUtility.GetCorrespondingObjectFromSource(result);
            if (newPrefabObject != null)
            {
                while (newPrefabObject.transform.parent != null)
                    newPrefabObject = newPrefabObject.transform.parent.gameObject;
                result = newPrefabObject;
            }
            return result;
        }

        public static List<GameObject> GetCorrespondingPrefabAssetsOfGameObjects(GameObject[] gameObjects)
        {
            List<GameObject> result = new List<GameObject>();
            PrefabAssetType prefabType;
            GameObject prefabRoot;
            foreach (GameObject go in gameObjects)
            {
                prefabRoot = null;
                if (go != PrefabUtility.GetOutermostPrefabInstanceRoot(go))
                    continue;
                prefabType = PrefabUtility.GetPrefabAssetType(go);
                if (prefabType == PrefabAssetType.Regular)
                    prefabRoot = PrefabUtility.GetCorrespondingObjectFromSource(go);
                else if (prefabType == PrefabAssetType.Variant)
                    prefabRoot = GetCorrespongingPrefabOfVariant(go);

                if (prefabRoot != null)
                    result.Add(prefabRoot);
            }

            return result;
        }
#endif
        #endregion Prefab System




    }
}