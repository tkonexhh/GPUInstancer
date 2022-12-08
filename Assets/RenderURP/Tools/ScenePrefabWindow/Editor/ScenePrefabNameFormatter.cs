using System.Collections;
using System.Collections.Generic;
using Sirenix.OdinInspector;
using UnityEditor;
using UnityEngine;

namespace Inutan
{
    public class ScenePrefabNameFormatter
    {
        [LabelText("根物体"), SceneObjectsOnly]
        public GameObject root;

        [LabelText("Prefab资源"), AssetsOnly]
        [OnValueChanged("OnPrefabChanged")]
        public GameObject prefab;


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
            if (prefab == null || root == null)
            {
                EditorHelper.DisplayDialog("未选择");
                return;
            }

            // var folders = root.GetComponentsInChildren<HierarchyFolderRoot>();
            var prefabPath = AssetDatabase.GetAssetPath(prefab);

            int index = 0;
            // foreach (var folder in folders)
            {
                int count = root.transform.childCount;
                for (int i = 0; i < count; i++)
                {
                    var child = root.transform.GetChild(i);
                    var prefabAssetType = PrefabUtility.GetPrefabAssetType(child);
                    if (prefabAssetType == PrefabAssetType.Regular)
                    {
                        if (PrefabUtility.GetPrefabAssetPathOfNearestInstanceRoot(child).Equals(prefabPath))
                        {
                            child.name = prefab.name + "_" + index;
                            index++;
                        }
                    }
                }

            }
        }
    }
}
