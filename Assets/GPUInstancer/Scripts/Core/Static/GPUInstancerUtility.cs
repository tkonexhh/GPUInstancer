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
using Inutan;

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
                runtimeData.transformationMatrixVisibilityBuffer = new ComputeBuffer(runtimeData.bufferSize, Inutan.GPUInstancerConstants.STRIDE_SIZE_MATRIX4X4);
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

            foreach (GPUInstancerRenderer renderer in runtimeData.renderers)
            {
                // Setup instance LOD renderer material property block shader buffers with the append buffer
                renderer.mpb.SetBuffer(InstanceStrategy_Indirect.ShaderIDs.TRANSFORMATION_MATRIX_BUFFER, runtimeData.transformationMatrixVisibilityBuffer);
                renderer.mpb.SetMatrix(InstanceStrategy_Indirect.ShaderIDs.RENDERER_TRANSFORM_OFFSET, renderer.transformOffset);
            }
        }

        public static void UpdateGPUBuffers<T>(List<T> runtimeDataList) where T : GPUInstancerRuntimeData
        {
            if (runtimeDataList == null)
                return;

            for (int i = 0; i < runtimeDataList.Count; i++)
            {
                UpdateGPUBuffer(runtimeDataList[i]);
            }
        }

        public static void UpdateGPUBuffer<T>(T runtimeData) where T : GPUInstancerRuntimeData
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
            runtimeData.argsBuffer.SetData(runtimeData.args);
        }

        public static void GPUIDrawMeshInstancedIndirect<T>(List<T> runtimeDataList, Bounds instancingBounds) where T : GPUInstancerRuntimeData
        {
            if (runtimeDataList == null)
                return;

            foreach (T runtimeData in runtimeDataList)
            {
                if (runtimeData == null || runtimeData.transformationMatrixVisibilityBuffer == null || runtimeData.bufferSize == 0 || runtimeData.instanceCount == 0)
                    continue;

                Inutan.GPUInstanceUtility.DrawMeshInstancedIndirect(runtimeData.renderers, instancingBounds, runtimeData.argsBuffer);

            }
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
                    UnityEngine.Object prefabRoot = PrefabUtility.GetCorrespondingObjectFromSource(prefabInstances[i].gameObject);

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
#if UNITY_EDITOR
                prefabScript = AddComponentToPrefab<GPUInstancerPrefab>(go);
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


#endif
        #endregion Prefab System

    }
}