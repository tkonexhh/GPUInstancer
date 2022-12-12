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
            // GPUInstancerConstants.gpuiSettings.SetDefultBindings();

            prototypeContents = null;

            helpIcon = Resources.Load<Texture2D>(GPUInstancerConstants.EDITOR_TEXTURES_PATH + GPUInstancerEditorConstants.HELP_ICON);
            helpIconActive = Resources.Load<Texture2D>(GPUInstancerConstants.EDITOR_TEXTURES_PATH + GPUInstancerEditorConstants.HELP_ICON_ACTIVE);
            previewBoxIcon = Resources.Load<Texture2D>(GPUInstancerConstants.EDITOR_TEXTURES_PATH + GPUInstancerEditorConstants.PREVIEW_BOX_ICON);


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

                if (prototype.prefabObject != null)
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


        public virtual void DrawPrefabField(GPUInstancerPrototype selectedPrototype)
        {
            EditorGUI.BeginDisabledGroup(true);
            EditorGUILayout.ObjectField(GPUInstancerEditorConstants.TEXT_prefabObject, selectedPrototype.prefabObject, typeof(GameObject), false);
            EditorGUI.EndDisabledGroup();
        }


    }
}
