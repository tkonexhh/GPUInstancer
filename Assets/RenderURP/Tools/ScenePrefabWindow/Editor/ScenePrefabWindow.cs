using System.Collections;
using System.Collections.Generic;
using Sirenix.OdinInspector.Editor;
using UnityEditor;
using UnityEngine;

namespace Inutan.InutanEditor
{
    public class ScenePrefabWindow : OdinMenuEditorWindow
    {
        [MenuItem("Tools/场景工具")]
        private static void OpenWindow()
        {
            var window = GetWindow<ScenePrefabWindow>();
            window.Show();
            window.titleContent = new GUIContent("场景工具");
        }


        protected override OdinMenuTree BuildMenuTree()
        {
            var tree = new OdinMenuTree();
            tree.Selection.SupportsMultiSelect = false;

            tree.Add("模型FBX一键链接预制体", new SceneFBXConnectPrefab());
            tree.Add("预制体命名格式化", new ScenePrefabNameFormatter());

            return tree;
        }


    }
}
