using System.Collections;
using System.Collections.Generic;
using Sirenix.OdinInspector;
using UnityEditor;
using UnityEngine;

namespace Inutan
{
    public class SceneFBXConnectPrefab
    {
        [LabelText("根物体"), SceneObjectsOnly]
        public GameObject root;

        [LabelText("FBX资源"), AssetsOnly]
        [OnValueChanged("OnFBXChanged")]
        public GameObject fbx;

        [LabelText("Prefab资源"), AssetsOnly]
        [OnValueChanged("OnPrefabChanged")]
        public GameObject prefab;


        //Odin 
        void OnFBXChanged()
        {
            if (fbx == null)
                return;
            var assetPath = AssetDatabase.GetAssetPath(fbx).ToLower();
            if (!assetPath.EndsWith(".fbx"))
            {
                fbx = null;
            }
        }

        void OnPrefabChanged()
        {
            if (prefab == null)
                return;
            var assetPath = AssetDatabase.GetAssetPath(prefab).ToLower();
            if (!assetPath.EndsWith(".prefab"))
            {
                prefab = null;
            }
        }

        [Button("一键转化")]
        void Convert()
        {
            if (prefab == null || fbx == null || root == null)
            {
                EditorHelper.DisplayDialog("未选择");
                return;
            }

            // var folders = root.GetComponentsInChildren<HierarchyFolderRoot>();
            var fbxPath = AssetDatabase.GetAssetPath(fbx);
            List<GameObject> waitToDestroy = new List<GameObject>();

            // foreach (var folder in folders)
            {
                int count = root.transform.childCount;
                for (int i = 0; i < count; i++)
                {
                    var child = root.transform.GetChild(i);
                    var prefabAssetType = PrefabUtility.GetPrefabAssetType(child);
                    if (prefabAssetType == PrefabAssetType.Model)
                    {
                        if (PrefabUtility.GetPrefabAssetPathOfNearestInstanceRoot(child).Equals(fbxPath))
                        {
                            var newPrefab = PrefabUtility.InstantiatePrefab(prefab) as GameObject;
                            newPrefab.transform.SetParent(root.transform);
                            newPrefab.layer = child.gameObject.layer;
                            newPrefab.transform.CopyFrom(child);
                            newPrefab.isStatic = child.gameObject.isStatic;
                            newPrefab.transform.SetAsLastSibling();
                            waitToDestroy.Add(child.gameObject);
                        }
                    }
                }
            }



            for (int i = waitToDestroy.Count - 1; i >= 0; i--)
            {
                GameObject.DestroyImmediate(waitToDestroy[i]);
            }

        }
    }
}
