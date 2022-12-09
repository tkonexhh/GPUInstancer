using System;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.Events;
using UnityEngine.Rendering;

namespace GPUInstancer
{
    public abstract class GPUInstancerEditor : Editor
    {
        public static readonly float PROTOTYPE_RECT_SIZE = 80;
        public static readonly float PROTOTYPE_RECT_PADDING = 5;
        public static readonly Vector2 PROTOTYPE_RECT_PADDING_VECTOR = new Vector2(PROTOTYPE_RECT_PADDING, PROTOTYPE_RECT_PADDING);
        public static readonly Vector2 PROTOTYPE_RECT_SIZE_VECTOR = new Vector2(PROTOTYPE_RECT_SIZE - PROTOTYPE_RECT_PADDING * 2, PROTOTYPE_RECT_SIZE - PROTOTYPE_RECT_PADDING * 2);

        public static readonly float PROTOTYPE_TEXT_RECT_SIZE_X = 200;
        public static readonly float PROTOTYPE_TEXT_RECT_SIZE_Y = 30;
        public static readonly Vector2 PROTOTYPE_TEXT_RECT_SIZE_VECTOR = new Vector2(PROTOTYPE_TEXT_RECT_SIZE_X - PROTOTYPE_RECT_PADDING * 2, PROTOTYPE_TEXT_RECT_SIZE_Y - PROTOTYPE_RECT_PADDING * 2);

        //protected SerializedProperty prop_settings;
        protected SerializedProperty prop_autoSelectCamera;
        protected SerializedProperty prop_mainCamera;
        protected SerializedProperty prop_renderOnlySelectedCamera;

        protected bool showSceneSettingsBox = true;
        protected bool showPrototypeBox = true;
        protected bool showAdvancedBox = false;
        protected bool showHelpText = false;
        protected bool showDebugBox = true;
        protected bool showGlobalValuesBox = true;
        protected bool showRegisteredPrefabsBox = true;
        protected bool showPrototypesBox = true;

        protected Texture2D helpIcon;
        protected Texture2D helpIconActive;
        protected Texture2D previewBoxIcon;

        protected GUIContent[] prototypeContents = null;

        protected List<GPUInstancerPrototype> prototypeList;
        protected Dictionary<GPUInstancerPrototype, bool> prototypeSelection;

        protected bool useCustomPreviewBackgroundColor = false;
        protected Color previewBackgroundColor;

        protected bool isTextMode = false;

        private GameObject _redirectObject;

        // Previews
        private GPUInstancerPreviewDrawer _previewDrawer;

        protected virtual void OnEnable()
        {
            GPUInstancerConstants.gpuiSettings.SetDefultBindings();

            prototypeContents = null;

            helpIcon = Resources.Load<Texture2D>(GPUInstancerConstants.EDITOR_TEXTURES_PATH + GPUInstancerEditorConstants.HELP_ICON);
            helpIconActive = Resources.Load<Texture2D>(GPUInstancerConstants.EDITOR_TEXTURES_PATH + GPUInstancerEditorConstants.HELP_ICON_ACTIVE);
            previewBoxIcon = Resources.Load<Texture2D>(GPUInstancerConstants.EDITOR_TEXTURES_PATH + GPUInstancerEditorConstants.PREVIEW_BOX_ICON);

            prop_autoSelectCamera = serializedObject.FindProperty("autoSelectCamera");
            prop_mainCamera = serializedObject.FindProperty("cameraData").FindPropertyRelative("mainCamera");
            prop_renderOnlySelectedCamera = serializedObject.FindProperty("cameraData").FindPropertyRelative("renderOnlySelectedCamera");


            GPUInstancerDefines.previewCache.ClearEmptyPreviews();
        }

        protected virtual void OnDisable()
        {
            EditorApplication.update -= GeneratePrototypeContentTextures;
            prototypeContents = null;

            if (_previewDrawer != null)
                _previewDrawer.Cleanup();
            _previewDrawer = null;
        }

        public override void OnInspectorGUI()
        {
            if (prototypeContents == null || prototypeList.Count != prototypeContents.Length)
                GeneratePrototypeContents();

            GPUInstancerEditorConstants.Styles.foldout.fontStyle = FontStyle.Bold;
            GPUInstancerEditorConstants.Styles.richLabel.richText = true;
        }

        public virtual void InspectorGUIEnd()
        {
            if (_redirectObject != null)
            {
                Selection.activeGameObject = _redirectObject;
                _redirectObject = null;
            }
        }

        public virtual void FillPrototypeList() { }

        public void GeneratePrototypeContents()
        {
            FillPrototypeList();
            prototypeContents = new GUIContent[prototypeList.Count];
            if (prototypeList == null || prototypeList.Count == 0)
                return;
            for (int i = 0; i < prototypeList.Count; i++)
            {
                prototypeContents[i] = new GUIContent(GPUInstancerDefines.previewCache.GetPreview(prototypeList[i]), prototypeList[i].ToString());
            }

            EditorApplication.update -= GeneratePrototypeContentTextures;
            EditorApplication.update += GeneratePrototypeContentTextures;
        }

        public void GeneratePrototypeContentTextures()
        {
            if (isTextMode)
                return;

            if (prototypeContents == null || prototypeContents.Length == 0 || prototypeList == null)
                return;

            for (int i = 0; i < prototypeContents.Length && i < prototypeList.Count; i++)
            {
                if (prototypeContents[i].image == null)
                {
                    if (_previewDrawer == null)
                        _previewDrawer = new GPUInstancerPreviewDrawer(previewBoxIcon);

                    prototypeContents[i].image = GPUInstancerDefines.previewCache.GetPreview(prototypeList[i]);

                    if (prototypeContents[i].image == null)
                    {
                        Texture2D texture = GetPreviewTexture(prototypeList[i]);
                        prototypeContents[i].image = texture;
                        GPUInstancerDefines.previewCache.AddPreview(prototypeList[i], texture);

                        return;
                    }
                }
            }

            if (_previewDrawer != null)
                _previewDrawer.Cleanup();
            _previewDrawer = null;
            EditorApplication.update -= GeneratePrototypeContentTextures;
        }

        public Texture2D GetPreviewTexture(GPUInstancerPrototype prototype)
        {
            try
            {
                if (prototype.prefabObject == null)
                {
                    if (prototype.GetPreviewTexture() != null)
                    {
                        _previewDrawer.SetAdditionalTexture(prototype.GetPreviewTexture());
                        Texture2D result = _previewDrawer.GetPreviewForGameObject(null, new Rect(0, 0, PROTOTYPE_RECT_SIZE - 10, PROTOTYPE_RECT_SIZE - 10),
                            useCustomPreviewBackgroundColor ? previewBackgroundColor : Color.clear);
                        _previewDrawer.SetAdditionalTexture(null);
                        return result;
                    }
                }
                else
                {
                    if (prototype.prefabObject.GetComponentInChildren<MeshFilter>() == null && prototype.prefabObject.GetComponentInChildren<SkinnedMeshRenderer>() == null)
                        return null;

                    return _previewDrawer.GetPreviewForGameObject(prototype.prefabObject, new Rect(0, 0, PROTOTYPE_RECT_SIZE - 10, PROTOTYPE_RECT_SIZE - 10),
                        useCustomPreviewBackgroundColor ? previewBackgroundColor : Color.clear);
                }

                if (Application.isPlaying && GPUInstancerManager.activeManagerList != null)
                {
                    for (int i = 0; i < GPUInstancerManager.activeManagerList.Count; i++)
                    {
                        GPUInstancerManager manager = GPUInstancerManager.activeManagerList[i];
                        if (manager != null && manager.isInitialized)
                        {
                            GPUInstancerRuntimeData runtimeData = manager.GetRuntimeData(prototype);
                            if (runtimeData != null)
                            {
                                return _previewDrawer.GetPreviewForGameObject(null, new Rect(0, 0, PROTOTYPE_RECT_SIZE - 10, PROTOTYPE_RECT_SIZE - 10),
                       useCustomPreviewBackgroundColor ? previewBackgroundColor : Color.clear, runtimeData);
                            }
                        }
                    }
                }
            }
            catch (Exception e)
            {
                Debug.LogError(e);
            }
            return null;
        }

        public void DrawCameraDataFields()
        {
            EditorGUILayout.PropertyField(prop_autoSelectCamera);
            if (!prop_autoSelectCamera.boolValue)
                EditorGUILayout.PropertyField(prop_mainCamera, GPUInstancerEditorConstants.Contents.useCamera);
            DrawHelpText(GPUInstancerEditorConstants.HELPTEXT_camera);
            EditorGUILayout.PropertyField(prop_renderOnlySelectedCamera, GPUInstancerEditorConstants.Contents.renderOnlySelectedCamera);
            DrawHelpText(GPUInstancerEditorConstants.HELPTEXT_renderOnlySelectedCamera);
        }

        public virtual void DrawFloatingOriginFields()
        {

        }

        public virtual void DrawLayerMaskFields()
        {

        }


        public void DrawSceneSettingsBox()
        {
            EditorGUILayout.BeginVertical(GPUInstancerEditorConstants.Styles.box);

            Rect foldoutRect = GUILayoutUtility.GetRect(0, 20, GUILayout.ExpandWidth(true), GUILayout.ExpandHeight(false));
            foldoutRect.x += 12;
            showSceneSettingsBox = EditorGUI.Foldout(foldoutRect, showSceneSettingsBox, GPUInstancerEditorConstants.TEXT_sceneSettings, true, GPUInstancerEditorConstants.Styles.foldout);

            if (showSceneSettingsBox)
            {
                DrawSettingContents();
            }
            EditorGUILayout.EndVertical();
        }

        public abstract void DrawSettingContents();

        public virtual void DrawGPUInstancerPrototypeButton(GPUInstancerPrototype prototype, GUIContent prototypeContent, bool isSelected, UnityAction handleSelect, bool isTextMode = false)
        {
            if (isTextMode)
            {
                DrawGPUInstancerPrototypeButtonTextMode(prototype, prototypeContent, isSelected, handleSelect);
                return;
            }

            if (prototypeContent.image == null)
            {
                prototypeContent = new GUIContent(prototypeContent.text, prototypeContent.tooltip);
            }

            Rect prototypeRect = GUILayoutUtility.GetRect(PROTOTYPE_RECT_SIZE, PROTOTYPE_RECT_SIZE, GUILayout.ExpandWidth(false), GUILayout.ExpandHeight(false));

            Rect iconRect = new Rect(prototypeRect.position + PROTOTYPE_RECT_PADDING_VECTOR, PROTOTYPE_RECT_SIZE_VECTOR);

            GUI.SetNextControlName(prototypeContent.tooltip);
            Color prototypeColor;
            if (isSelected)
                prototypeColor = GPUInstancerEditorConstants.Colors.lightGreen;
            else
                prototypeColor = GUI.backgroundColor;

            GPUInstancerEditorConstants.DrawColoredButton(prototypeContent, prototypeColor, GPUInstancerEditorConstants.Styles.label.normal.textColor, FontStyle.Normal, iconRect,
                    () =>
                    {
                        if (handleSelect != null)
                            handleSelect();
                    });
        }

        public virtual void DrawGPUInstancerPrototypeButtonTextMode(GPUInstancerPrototype prototype, GUIContent prototypeContent, bool isSelected, UnityAction handleSelect)
        {
            Rect prototypeRect = GUILayoutUtility.GetRect(PROTOTYPE_TEXT_RECT_SIZE_X, PROTOTYPE_TEXT_RECT_SIZE_Y, GUILayout.ExpandWidth(false), GUILayout.ExpandHeight(false));

            Rect iconRect = new Rect(prototypeRect.position + PROTOTYPE_RECT_PADDING_VECTOR, PROTOTYPE_TEXT_RECT_SIZE_VECTOR);

            GUI.SetNextControlName(prototypeContent.tooltip);
            Color prototypeColor = isSelected ? GPUInstancerEditorConstants.Colors.lightGreen : GUI.backgroundColor;

            prototypeContent = new GUIContent(prototypeContent.tooltip);
            GPUInstancerEditorConstants.DrawColoredButton(prototypeContent, prototypeColor, GPUInstancerEditorConstants.Styles.label.normal.textColor, FontStyle.Normal, iconRect,
                    () =>
                    {
                        if (handleSelect != null)
                            handleSelect();
                    });
        }

        public virtual void DrawGPUInstancerPrototypeBox(List<GPUInstancerPrototype> selectedPrototypeList)
        {
            if (selectedPrototypeList == null || selectedPrototypeList.Count == 0)
                return;

            if (selectedPrototypeList.Count == 1)
            {
                DrawGPUInstancerPrototypeBox(selectedPrototypeList[0]);
                return;
            }

            EditorGUILayout.BeginVertical(GPUInstancerEditorConstants.Styles.box);
            // title
            Rect foldoutRect = GUILayoutUtility.GetRect(0, 20, GUILayout.ExpandWidth(true), GUILayout.ExpandHeight(false));
            foldoutRect.x += 12;
            showPrototypeBox = EditorGUI.Foldout(foldoutRect, showPrototypeBox, "Multiple Selection", true, GPUInstancerEditorConstants.Styles.foldout);

            if (showPrototypeBox)
            {
                GPUInstancerPrototype prototype0 = selectedPrototypeList[0];

                bool hasChanged = false;

                hasChanged |= DrawGPUInstancerPrototypeBeginningInfo(selectedPrototypeList);

                EditorGUI.BeginDisabledGroup(Application.isPlaying);
                hasChanged |= DrawGPUInstancerPrototypeInfo(selectedPrototypeList);
                DrawGPUInstancerPrototypeActions();
                DrawGPUInstancerPrototypeAdvancedActions();
                EditorGUI.EndDisabledGroup();

                if (hasChanged)
                {
                    for (int i = 0; i < selectedPrototypeList.Count; i++)
                    {
                        EditorUtility.SetDirty(selectedPrototypeList[i]);
                    }
                }
            }

            EditorGUILayout.EndVertical();
        }

        public virtual void DrawGPUInstancerPrototypeBox(GPUInstancerPrototype selectedPrototype)
        {
            if (selectedPrototype == null)
                return;

            EditorGUILayout.BeginVertical(GPUInstancerEditorConstants.Styles.box);
            // title
            Rect foldoutRect = GUILayoutUtility.GetRect(0, 20, GUILayout.ExpandWidth(true), GUILayout.ExpandHeight(false));
            foldoutRect.x += 12;
            showPrototypeBox = EditorGUI.Foldout(foldoutRect, showPrototypeBox, selectedPrototype.ToString(), true, GPUInstancerEditorConstants.Styles.foldout);

            if (!showPrototypeBox)
            {
                EditorGUILayout.EndVertical();
                return;
            }


            DrawPrefabField(selectedPrototype);
            EditorGUI.BeginDisabledGroup(true);
            EditorGUILayout.ObjectField(GPUInstancerEditorConstants.TEXT_prototypeSO, selectedPrototype, typeof(GPUInstancerPrototype), false);
            EditorGUI.EndDisabledGroup();

            EditorGUI.BeginChangeCheck();

            DrawGPUInstancerPrototypeBeginningInfo(selectedPrototype);



            EditorGUI.BeginDisabledGroup(Application.isPlaying);
            DrawGPUInstancerPrototypeInfo(selectedPrototype);

            if (EditorGUI.EndChangeCheck())
            {
                if (selectedPrototype != null)
                    EditorUtility.SetDirty(selectedPrototype);
            }

            DrawGPUInstancerPrototypeActions();
            DrawGPUInstancerPrototypeAdvancedActions();

            EditorGUI.EndDisabledGroup();
            EditorGUILayout.EndVertical();
        }


        public void DrawHelpText(string text, bool forceShow = false)
        {
            if (showHelpText || forceShow)
            {
                EditorGUILayout.HelpBox(text, MessageType.Info);
            }
        }

        public abstract bool DrawGPUInstancerPrototypeInfo(List<GPUInstancerPrototype> selectedPrototypeList);
        public abstract void DrawGPUInstancerPrototypeInfo(GPUInstancerPrototype selectedPrototype);
        public virtual bool DrawGPUInstancerPrototypeBeginningInfo(List<GPUInstancerPrototype> selectedPrototypeList) { return false; }
        public virtual void DrawGPUInstancerPrototypeBeginningInfo(GPUInstancerPrototype selectedPrototype) { }
        public abstract void DrawGPUInstancerPrototypeActions();
        public virtual void DrawGPUInstancerPrototypeAdvancedActions() { }
        public abstract float GetMaxDistance(GPUInstancerPrototype selectedPrototype);


        public virtual void DrawPrefabField(GPUInstancerPrototype selectedPrototype)
        {
            EditorGUI.BeginDisabledGroup(true);
            EditorGUILayout.ObjectField(GPUInstancerEditorConstants.TEXT_prefabObject, selectedPrototype.prefabObject, typeof(GameObject), false);
            EditorGUI.EndDisabledGroup();
        }

        public static bool MultiToggle(List<GPUInstancerPrototype> selectedPrototypeList, string text, bool value, bool isMixed, UnityAction<GPUInstancerPrototype, bool> prototypeAction)
        {
            bool hasChanged = false;
            EditorGUI.showMixedValue = isMixed;

            EditorGUI.BeginChangeCheck();
            value = EditorGUILayout.Toggle(text, value);
            if (EditorGUI.EndChangeCheck())
            {
                for (int i = 0; i < selectedPrototypeList.Count; i++)
                {
                    prototypeAction(selectedPrototypeList[i], value);
                }
                hasChanged = true;
            }
            EditorGUI.showMixedValue = false;

            return hasChanged;
        }

        public static bool MultiSlider(List<GPUInstancerPrototype> selectedPrototypeList, string text, float value, float leftValue, float rightValue, bool isMixed, UnityAction<GPUInstancerPrototype, float> prototypeAction)
        {
            bool hasChanged = false;
            EditorGUI.showMixedValue = isMixed;

            EditorGUI.BeginChangeCheck();
            value = EditorGUILayout.Slider(text, value, leftValue, rightValue);
            if (EditorGUI.EndChangeCheck())
            {
                for (int i = 0; i < selectedPrototypeList.Count; i++)
                {
                    prototypeAction(selectedPrototypeList[i], value);
                }
                hasChanged = true;
            }
            EditorGUI.showMixedValue = false;

            return hasChanged;
        }

        public static bool MultiMinMaxSlider(List<GPUInstancerPrototype> selectedPrototypeList, string text, float minValue, float maxValue, float minLimit, float maxLimit, bool isMixed, UnityAction<GPUInstancerPrototype, float, float> prototypeAction)
        {
            bool hasChanged = false;
            EditorGUI.showMixedValue = isMixed;

            EditorGUI.BeginChangeCheck();
            EditorGUILayout.MinMaxSlider(text, ref minValue, ref maxValue, minLimit, maxLimit);
            if (EditorGUI.EndChangeCheck())
            {
                for (int i = 0; i < selectedPrototypeList.Count; i++)
                {
                    prototypeAction(selectedPrototypeList[i], minValue, maxValue);
                }
                hasChanged = true;
            }
            EditorGUI.showMixedValue = false;

            return hasChanged;
        }

        public static bool MultiIntSlider(List<GPUInstancerPrototype> selectedPrototypeList, string text, int value, int leftValue, int rightValue, bool isMixed, UnityAction<GPUInstancerPrototype, int> prototypeAction)
        {
            bool hasChanged = false;
            EditorGUI.showMixedValue = isMixed;

            EditorGUI.BeginChangeCheck();
            value = EditorGUILayout.IntSlider(text, value, leftValue, rightValue);
            if (EditorGUI.EndChangeCheck())
            {
                for (int i = 0; i < selectedPrototypeList.Count; i++)
                {
                    prototypeAction(selectedPrototypeList[i], value);
                }
                hasChanged = true;
            }
            EditorGUI.showMixedValue = false;

            return hasChanged;
        }

        public static bool MultiVector4(List<GPUInstancerPrototype> selectedPrototypeList, string text, Vector4 value, bool isMixed, UnityAction<GPUInstancerPrototype, Vector4> prototypeAction)
        {
            bool hasChanged = false;
            EditorGUI.showMixedValue = isMixed;

            EditorGUI.BeginChangeCheck();
            value = EditorGUILayout.Vector4Field(text, value);
            if (EditorGUI.EndChangeCheck())
            {
                for (int i = 0; i < selectedPrototypeList.Count; i++)
                {
                    prototypeAction(selectedPrototypeList[i], value);
                }
                hasChanged = true;
            }
            EditorGUI.showMixedValue = false;

            return hasChanged;
        }

        public static bool MultiFloat(List<GPUInstancerPrototype> selectedPrototypeList, string text, float value, bool isMixed, UnityAction<GPUInstancerPrototype, float> prototypeAction)
        {
            bool hasChanged = false;
            EditorGUI.showMixedValue = isMixed;

            EditorGUI.BeginChangeCheck();
            if (text == null)
                value = EditorGUILayout.FloatField(value);
            else
                value = EditorGUILayout.FloatField(text, value);
            if (EditorGUI.EndChangeCheck())
            {
                for (int i = 0; i < selectedPrototypeList.Count; i++)
                {
                    prototypeAction(selectedPrototypeList[i], value);
                }
                hasChanged = true;
            }
            EditorGUI.showMixedValue = false;

            return hasChanged;
        }

        public static bool MultiColor(List<GPUInstancerPrototype> selectedPrototypeList, string text, Color value, bool isMixed, UnityAction<GPUInstancerPrototype, Color> prototypeAction)
        {
            bool hasChanged = false;
            EditorGUI.showMixedValue = isMixed;

            EditorGUI.BeginChangeCheck();
            value = EditorGUILayout.ColorField(text, value);
            if (EditorGUI.EndChangeCheck())
            {
                for (int i = 0; i < selectedPrototypeList.Count; i++)
                {
                    prototypeAction(selectedPrototypeList[i], value);
                }
                hasChanged = true;
            }
            EditorGUI.showMixedValue = false;

            return hasChanged;
        }

        public static bool MultiVector3(List<GPUInstancerPrototype> selectedPrototypeList, string text, Vector3 value, bool isMixed, bool acceptNegative, UnityAction<GPUInstancerPrototype, Vector3> prototypeAction)
        {
            bool hasChanged = false;
            EditorGUI.showMixedValue = isMixed;

            EditorGUI.BeginChangeCheck();
            value = EditorGUILayout.Vector3Field(text, value);
            if (!acceptNegative)
            {
                if (value.x < 0)
                    value.x = 0;
                if (value.y < 0)
                    value.y = 0;
                if (value.z < 0)
                    value.z = 0;
            }
            if (EditorGUI.EndChangeCheck())
            {
                for (int i = 0; i < selectedPrototypeList.Count; i++)
                {
                    prototypeAction(selectedPrototypeList[i], value);
                }
                hasChanged = true;
            }
            EditorGUI.showMixedValue = false;

            return hasChanged;
        }

        public static bool MultiPopup(List<GPUInstancerPrototype> selectedPrototypeList, string text, int value, string[] options, bool isMixed, UnityAction<GPUInstancerPrototype, int> prototypeAction)
        {
            bool hasChanged = false;
            EditorGUI.showMixedValue = isMixed;

            EditorGUI.BeginChangeCheck();
            value = EditorGUILayout.Popup(text, value, options);
            if (EditorGUI.EndChangeCheck())
            {
                for (int i = 0; i < selectedPrototypeList.Count; i++)
                {
                    prototypeAction(selectedPrototypeList[i], value);
                }
                hasChanged = true;
            }
            EditorGUI.showMixedValue = false;

            return hasChanged;
        }
    }
}
