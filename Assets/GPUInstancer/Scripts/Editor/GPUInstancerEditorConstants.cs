using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.Events;

namespace GPUInstancer
{
    public static class GPUInstancerEditorConstants
    {

        public static readonly string TEXT_prototypes = "Prototypes";
        public static readonly string TEXT_add = "Add\n<size=8>Click / Drop</size>";
        public static readonly string TEXT_addTextMode = "Add Prototype";


        public static readonly string TEXT_registerPrefabsInScene = "Register Instances in Scene";
        public static readonly string TEXT_registeredPrefabs = "Registered Instances";


        public static readonly string TEXT_prefabObject = "Prefab Object";
        public static readonly string TEXT_prototypeSO = "Prototype SO";
        public static readonly string TEXT_prefabInstancingNone = "Instancing has not been initialized";


        public static readonly string TEXT_settingMaxPrefabDist = "Max Prefab Distance";
        public static readonly string TEXT_settingInstancingBoundsSize = "Instancing Bounds Size";

        public static readonly string TEXT_settingHasCustomRenderingSettings = "Use Custom Rendering Settings";
        public static readonly string TEXT_settingComputeThread = "Max. Compute Thread Count";
        public static readonly string TEXT_settingMatrixHandlingType = "Max. Compute Buffers";

        // Editor HelpText
        public static readonly string HELPTEXT_prototypes = "\"Prototypes\" show the list of objects that will be used in GPU Instancer. To modify a prototype, click on its icon or text. Use the \"Text Mode\" or \"Icon Mode\" button to switch between preview modes.";
        public static readonly string HELPTEXT_addprototypeprefab = "Click on \"Add\" button and select a prefab to add a prefab prototype to the manager. Note that prefab manager only accepts user created prefabs. It will not accept prefabs that are generated when importing your 3D model assets.";
        public static readonly string HELPTEXT_registerPrefabsInScene = "The \"Register Prefabs In Scene\" button can be used to register the prefab instances that are currently in the scene, so that they can be used by GPU Instancer. For adding new instances at runtime check API documentation.";

        public static readonly string HELPTEXT_maxDistance = "\"Min-Max Distance\" defines the minimum and maximum distance from the selected camera within which this prototype will be rendered.";



        public static readonly string HELPTEXT_settingInstancingBoundsSize = "Defines the bounds parameter's size for the instanced rendering draw call.";

        public static readonly string HELPTEXT_settingHasCustomRenderingSettings = "Use Custom Rendering Settings";
        public static readonly string HELPTEXT_settingComputeThread = "Max. Compute Thread Count";
        public static readonly string HELPTEXT_settingMatrixHandlingType = "Max. Compute Buffers";

        public static readonly string HELP_ICON = "help_gpui";
        public static readonly string HELP_ICON_ACTIVE = "help_gpui_active";
        public static readonly string PREVIEW_BOX_ICON = "previewBox";

        public static class Contents
        {

            public static GUIContent registerPrefabsInScene = new GUIContent(TEXT_registerPrefabsInScene);

            public static GUIContent add = new GUIContent(TEXT_add);
            public static GUIContent addTextMode = new GUIContent(TEXT_addTextMode);
            public static GUIContent enableMeshRenderers = new GUIContent("Enable Mesh Renderers");


            public static GUIContent settingMaxPrefabDist = new GUIContent(TEXT_settingMaxPrefabDist, HELPTEXT_maxDistance);

            public static GUIContent settingInstancingBoundsSize = new GUIContent(TEXT_settingInstancingBoundsSize, HELPTEXT_settingInstancingBoundsSize);
            public static GUIContent settingHasCustomRenderingSettings = new GUIContent(TEXT_settingHasCustomRenderingSettings, HELPTEXT_settingHasCustomRenderingSettings);
            public static GUIContent settingComputeThread = new GUIContent(TEXT_settingComputeThread, HELPTEXT_settingComputeThread);
            public static GUIContent[] settingComputeThreadOptions = new GUIContent[] { new GUIContent("64"), new GUIContent("128"), new GUIContent("256"), new GUIContent("512"), new GUIContent("1024") };
            public static GUIContent settingMatrixHandlingType = new GUIContent(TEXT_settingMatrixHandlingType, HELPTEXT_settingMatrixHandlingType);
            public static GUIContent[] settingMatrixHandlingTypeOptions = new GUIContent[] { new GUIContent("Unlimited"), new GUIContent("1 Compute Buffer"), new GUIContent("None") };


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
            public static Color darkBlue = new Color(0.07f, 0.27f, 0.35f, 1);
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

        // Toolbar buttons
        [MenuItem("Tools/GPU Instancer/Add Prefab Manager", validate = false, priority = 1)]
        public static void ToolbarAddPrefabManager()
        {
            GameObject go = new GameObject("GPUI Prefab Manager");
            go.AddComponent<GPUInstancerPrefabManager>();

            Selection.activeGameObject = go;
            Undo.RegisterCreatedObjectUndo(go, "Add GPUI Prefab Manager");
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


        private static bool _hasCustomRenderingSettings;
        private static int _threadCountSelection;
        private static int _matrixHandlingTypeSelection;
        private static bool _customRenderingSettingsChanged;

        public static void DrawGPUISettings()
        {

            float previousLabelWight = EditorGUIUtility.labelWidth;
            EditorGUIUtility.labelWidth = previousLabelWight + 75f;
            EditorGUI.BeginChangeCheck();

            EditorGUILayout.BeginVertical(Styles.box);
            DrawCustomLabel("Constants", Styles.boldLabel);
            GUILayout.Space(5);

            GUILayout.Space(5);
            EditorGUILayout.EndVertical();

            EditorGUILayout.BeginVertical(Styles.box);
            GUILayout.Space(5);
            DrawCustomLabel("Rendering Settings [ADVANCED]", Styles.boldLabel);

            EditorGUI.BeginChangeCheck();
            _hasCustomRenderingSettings = EditorGUILayout.Toggle(Contents.settingHasCustomRenderingSettings, _hasCustomRenderingSettings);
            if (_hasCustomRenderingSettings)
            {
                _threadCountSelection = EditorGUILayout.Popup(Contents.settingComputeThread, _threadCountSelection, Contents.settingComputeThreadOptions);
                _matrixHandlingTypeSelection = EditorGUILayout.Popup(Contents.settingMatrixHandlingType, _matrixHandlingTypeSelection, Contents.settingMatrixHandlingTypeOptions);
            }
            if (EditorGUI.EndChangeCheck())
            {
                _customRenderingSettingsChanged = true;
            }

            GUILayout.Space(5);
            EditorGUILayout.EndVertical();




            EditorGUILayout.BeginVertical(Styles.box);
            GUILayout.Space(5);
            DrawCustomLabel("Update Jobs", Styles.boldLabel);


            GUILayout.Space(5);
            EditorGUILayout.EndVertical();


            EditorGUIUtility.labelWidth = previousLabelWight;
        }
    }
}