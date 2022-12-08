using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

namespace Inutan
{
    public static class EditorHelper
    {
        public static void DisplayDialog(string message)
        {
#if UNITY_EDITOR
            EditorUtility.DisplayDialog("Tips", message, "ok");
#endif
        }
    }
}
