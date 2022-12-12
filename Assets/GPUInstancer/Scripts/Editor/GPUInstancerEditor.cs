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
        // public static readonly Vector2 PROTOTYPE_RECT_SIZE_VECTOR = new Vector2(PROTOTYPE_RECT_SIZE - PROTOTYPE_RECT_PADDING * 2, PROTOTYPE_RECT_SIZE - PROTOTYPE_RECT_PADDING * 2);

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

        // protected Texture2D helpIcon;
        // protected Texture2D helpIconActive;
        // protected Texture2D previewBoxIcon;

        protected GUIContent[] prototypeContents = null;

        protected List<GPUInstancerPrototype> prototypeList;
        protected Dictionary<GPUInstancerPrototype, bool> prototypeSelection;

        private GameObject _redirectObject;

        protected virtual void OnEnable()
        {

            prototypeContents = null;
        }

        protected virtual void OnDisable()
        {
            prototypeContents = null;
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
                prototypeContents[i] = new GUIContent("", prototypeList[i].ToString());
            }
        }

        public virtual void DrawGPUInstancerPrototypeButton(GPUInstancerPrototype prototype, GUIContent prototypeContent, bool isSelected, UnityAction handleSelect)
        {
            DrawGPUInstancerPrototypeButtonTextMode(prototype, prototypeContent, isSelected, handleSelect);
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
