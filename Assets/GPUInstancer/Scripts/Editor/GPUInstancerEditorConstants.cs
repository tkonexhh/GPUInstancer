using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.Events;

namespace GPUInstancer
{
    public static class GPUInstancerEditorConstants
    {

        public static readonly string TEXT_prototypes = "Prototypes";
        public static readonly string TEXT_addTextMode = "Add Prototype";
        public static readonly string TEXT_registeredPrefabs = "Registered Instances";
        public static readonly string TEXT_prefabObject = "Prefab Object";
        public static readonly string TEXT_prototypeSO = "Prototype SO";

        // Editor HelpText
        public static readonly string HELPTEXT_prototypes = "\"Prototypes\" show the list of objects that will be used in GPU Instancer. To modify a prototype, click on its icon or text. Use the \"Text Mode\" or \"Icon Mode\" button to switch between preview modes.";


        public static class Contents
        {
            public static GUIContent addTextMode = new GUIContent(TEXT_addTextMode);
            public static GUIContent enableMeshRenderers = new GUIContent("Enable Mesh Renderers");

        }

        public static class Styles
        {
            public static GUIStyle label = new GUIStyle("Label");
            public static GUIStyle boldLabel = new GUIStyle("BoldLabel");
            public static GUIStyle foldout = new GUIStyle("Foldout");
            public static GUIStyle box = new GUIStyle("Box");
            public static GUIStyle richLabel = new GUIStyle("Label");
        }

        public static class Colors
        {
            public static Color lightBlue = new Color(0.5f, 0.6f, 0.8f, 1);
            public static Color lightGreen = new Color(0.2f, 1f, 0.2f, 1);
            public static Color green = new Color(0, 0.4f, 0, 1);
        }

        public static void DrawCustomLabel(string text, GUIStyle style, bool center = true)
        {
            if (center)
            {
                EditorGUILayout.BeginHorizontal();
                GUILayout.FlexibleSpace();
            }

            GUILayout.Label(text, style);

            if (center)
            {
                GUILayout.FlexibleSpace();
                EditorGUILayout.EndHorizontal();
            }
        }

        public static void DrawColoredButton(GUIContent guiContent, Color backgroundColor, Color textColor, FontStyle fontStyle, Rect buttonRect, UnityAction clickAction,
            bool isRichText = false, bool dragDropEnabled = false, UnityAction<Object> dropAction = null, GUIStyle style = null)
        {
            Color oldBGColor = GUI.backgroundColor;
            GUI.backgroundColor = backgroundColor;
            if (style == null)
                style = new GUIStyle("button");
            style.normal.textColor = textColor;
            style.active.textColor = textColor;
            style.hover.textColor = textColor;
            style.focused.textColor = textColor;
            style.fontStyle = fontStyle;
            style.richText = isRichText;

            if (buttonRect == Rect.zero)
            {
                if (GUILayout.Button(guiContent, style))
                {
                    if (clickAction != null)
                        clickAction.Invoke();
                }
            }
            else
            {
                if (GUI.Button(buttonRect, guiContent, style))
                {
                    if (clickAction != null)
                        clickAction.Invoke();
                }
            }

            GUI.backgroundColor = oldBGColor;

            if (dragDropEnabled && dropAction != null)
            {
                Event evt = Event.current;
                switch (evt.type)
                {
                    case EventType.DragUpdated:
                    case EventType.DragPerform:
                        if (!buttonRect.Contains(evt.mousePosition))
                            return;

                        DragAndDrop.visualMode = DragAndDropVisualMode.Copy;

                        if (evt.type == EventType.DragPerform)
                        {
                            DragAndDrop.AcceptDrag();

                            foreach (Object dragged_object in DragAndDrop.objectReferences)
                            {
                                dropAction(dragged_object);
                            }
                        }
                        break;
                }
            }
        }


        private static void AddPrefabObjectsToList(GameObject go, List<GameObject> prefabList)
        {
            PrefabAssetType prefabType = PrefabUtility.GetPrefabAssetType(go);
            if (prefabType == PrefabAssetType.Regular || prefabType == PrefabAssetType.Variant)
            {
                GameObject prefab = (GameObject)PrefabUtility.GetCorrespondingObjectFromSource(go);
                if (prefabType == PrefabAssetType.Variant)
                {
                    GameObject newPrefabObject = (GameObject)PrefabUtility.GetCorrespondingObjectFromSource(prefab);
                    if (newPrefabObject != null)
                    {
                        while (newPrefabObject.transform.parent != null)
                            newPrefabObject = newPrefabObject.transform.parent.gameObject;
                        prefab = newPrefabObject;
                    }
                }
                if (prefab != null && prefab.transform.parent == null && !prefabList.Contains(prefab))
                {
                    prefabList.Add(prefab);
                    GameObject prefabContents = GPUInstancerUtility.LoadPrefabContents(prefab);
                    List<Transform> childTransforms = new List<Transform>(prefabContents.GetComponentsInChildren<Transform>());
                    childTransforms.Remove(prefabContents.transform);
                    foreach (Transform childTransform in childTransforms)
                    {
                        AddPrefabObjectsToList(childTransform.gameObject, prefabList);
                    }
                    GPUInstancerUtility.UnloadPrefabContents(prefab, prefabContents, false);
                }
            }
        }


    }
}