using System;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using Inutan;

namespace GPUInstancer
{
    public abstract class GPUInstancerManagerEditor : GPUInstancerEditor
    {
        private GPUInstancerManager _manager;
        protected GPUInstancerPrototype _pickerOverride;

        protected int pickerControlID = -1;
        protected bool editorDataChanged = false;

        protected override void OnEnable()
        {
            base.OnEnable();

            prototypeContents = null;
            _pickerOverride = null;

            _manager = (target as GPUInstancerManager);
            FillPrototypeList();


            showSceneSettingsBox = _manager.showSceneSettingsBox;
            showPrototypeBox = _manager.showPrototypeBox;
            showAdvancedBox = _manager.showAdvancedBox;
            showHelpText = _manager.showHelpText;
            showDebugBox = _manager.showDebugBox;
            showGlobalValuesBox = _manager.showGlobalValuesBox;
            showRegisteredPrefabsBox = _manager.showRegisteredPrefabsBox;
            showPrototypesBox = _manager.showPrototypesBox;
        }

        public override void FillPrototypeList()
        {
            prototypeList = _manager.prototypeList;

            UpdatePrototypeSelection();
        }

        public virtual void UpdatePrototypeSelection()
        {
            if (prototypeSelection == null)
                prototypeSelection = new Dictionary<GPUInstancerPrototype, bool>();
            prototypeSelection.Clear();

            if (_manager.selectedPrototypeList == null)
                _manager.selectedPrototypeList = new List<GPUInstancerPrototype>();

            foreach (GPUInstancerPrototype prototype in prototypeList)
            {
                prototypeSelection.Add(prototype, _manager.selectedPrototypeList.Contains(prototype));
            }
        }

        public override void OnInspectorGUI()
        {
            base.OnInspectorGUI();
        }

        public override void InspectorGUIEnd()
        {
            _manager.showSceneSettingsBox = showSceneSettingsBox;
            _manager.showPrototypeBox = showPrototypeBox;
            _manager.showAdvancedBox = showAdvancedBox;
            _manager.showHelpText = showHelpText;
            _manager.showDebugBox = showDebugBox;
            _manager.showGlobalValuesBox = showGlobalValuesBox;
            _manager.showRegisteredPrefabsBox = showRegisteredPrefabsBox;
            _manager.showPrototypesBox = showPrototypesBox;
            base.InspectorGUIEnd();
        }

        public virtual void ShowObjectPicker()
        {

        }

        public virtual void AddPickerObject(UnityEngine.Object pickerObject, GPUInstancerPrototype overridePrototype = null)
        {
            // if (overridePrototype != null && GPUInstancerDefines.previewCache != null)
            // {
            //     GPUInstancerDefines.previewCache.RemovePreview(overridePrototype);
            // }
        }

        public virtual void OnEditorDataChanged()
        {
            editorDataChanged = true;
        }


        public bool HandlePickerObjectSelection()
        {
            if (!Application.isPlaying && Event.current.type == EventType.ExecuteCommand && pickerControlID > 0 && Event.current.commandName == "ObjectSelectorClosed")
            {
                if (EditorGUIUtility.GetObjectPickerControlID() == pickerControlID)
                {
                    AddPickerObject(EditorGUIUtility.GetObjectPickerObject(), _pickerOverride);
                    prototypeContents = null;
                }
                pickerControlID = -1;
                return true;
            }
            return false;
        }


        public virtual void DrawRegisteredPrefabsBox()
        {
            EditorGUI.BeginDisabledGroup(Application.isPlaying);
            EditorGUILayout.BeginVertical(GPUInstancerEditorConstants.Styles.box);

            Rect foldoutRect = GUILayoutUtility.GetRect(0, 20, GUILayout.ExpandWidth(true), GUILayout.ExpandHeight(false));
            foldoutRect.x += 12;
            showRegisteredPrefabsBox = EditorGUI.Foldout(foldoutRect, showRegisteredPrefabsBox, GPUInstancerEditorConstants.TEXT_registeredPrefabs, true, GPUInstancerEditorConstants.Styles.foldout);

            if (showRegisteredPrefabsBox)
            {

                DrawRegisteredPrefabsBoxList();

                _manager.selectedPrototypeList.Clear();
                foreach (GPUInstancerPrototype prototype in _manager.prototypeList)
                {
                    if (prototypeSelection[prototype])
                        _manager.selectedPrototypeList.Add(prototype);
                }
            }

            EditorGUILayout.EndVertical();
            EditorGUI.EndDisabledGroup();
        }



        public virtual void DrawRegisteredPrefabsBoxList()
        {
            if ((Application.isPlaying || _manager.isInitialized) && _manager.runtimeDataList != null && _manager.runtimeDataList.Count > 0)
            {
                int totalInsanceCount = 0;
                int totalDrawCallCount = 0;
                int totalShadowDrawCall = 0;
                foreach (GPUInstanceRenderer runtimeData in _manager.runtimeDataList)
                {
                    if (runtimeData == null || runtimeData.renderTarget == null)
                        continue;

                    int drawCallCount = 0;
                    int shadowDrawCallCount = 0;
                    if (runtimeData.instanceCount > 0)
                    {

                        for (int j = 0; j < runtimeData.renderers.Count; j++)
                        {
                            GPUInstancerRenderer gpuiRenderer = runtimeData.renderers[j];
                            // if (!GPUInstancerUtility.IsInLayer(prop_layerMask.intValue, gpuiRenderer.layer))
                            //     continue;
                            drawCallCount += gpuiRenderer.materials.Count;
                        }

                    }
                    string prototypeName = runtimeData.renderTarget.ToString();
                    GUILayout.Label(prototypeName + " Instance Count: " + String.Format("{0:n0}", runtimeData.instanceCount) +
                        //"\n" + prototypeName + " Buffer Size: " + String.Format("{0:n0}", runtimeData.bufferSize) +
                        "\n" + prototypeName + " Geometry Draw Call Count: " + drawCallCount +
                        (shadowDrawCallCount > 0 ? "\n" + prototypeName + " Shadow Draw Call Count: " + shadowDrawCallCount : ""), GPUInstancerEditorConstants.Styles.label);

                    totalInsanceCount += runtimeData.instanceCount;
                    totalDrawCallCount += drawCallCount;
                    // totalShadowDrawCall += shadowDrawCallCount;
                }

                GUILayout.Label("\nTotal Instance Count: " + String.Format("{0:n0}", totalInsanceCount) +
                    "\n\n" + "Total Geometry Draw Call Count: " + totalDrawCallCount +
                    "\n" + "Total Shadow Draw Call Count: " + totalShadowDrawCall + " (" + QualitySettings.shadowCascades + " Cascades)" +
                    "\n\n" + "Total Draw Call Count: " + (totalDrawCallCount + totalShadowDrawCall)
                    , GPUInstancerEditorConstants.Styles.boldLabel);
            }
            else
                GPUInstancerEditorConstants.DrawCustomLabel("No registered prefabs.", GPUInstancerEditorConstants.Styles.label, false);
        }

        public virtual void DrawGPUInstancerPrototypesBox()
        {
            EditorGUILayout.BeginVertical(GPUInstancerEditorConstants.Styles.box);

            EditorGUILayout.BeginHorizontal();
            Rect foldoutRect = GUILayoutUtility.GetRect(0, 20, GUILayout.ExpandWidth(true), GUILayout.ExpandHeight(false));
            foldoutRect.x += 12;
            showPrototypesBox = EditorGUI.Foldout(foldoutRect, showPrototypesBox, GPUInstancerEditorConstants.TEXT_prototypes, true, GPUInstancerEditorConstants.Styles.foldout);


            EditorGUILayout.EndHorizontal();

            if (showPrototypesBox)
            {
                int prototypeRowCount = Mathf.FloorToInt((EditorGUIUtility.currentViewWidth - 30f) / (PROTOTYPE_TEXT_RECT_SIZE_X));
                DrawHelpText(GPUInstancerEditorConstants.HELPTEXT_prototypes);


                if (prototypeContents == null || prototypeContents.Length != _manager.prototypeList.Count)
                    GeneratePrototypeContents();

                int i = 0;
                EditorGUILayout.BeginHorizontal();
                foreach (GPUInstancerPrototype prototype in _manager.prototypeList)
                {
                    if (i != 0 && i % prototypeRowCount == 0)
                    {
                        EditorGUILayout.EndHorizontal();
                        EditorGUILayout.BeginHorizontal();
                    }

                    if (prototype == null)
                        continue;

                    DrawGPUInstancerPrototypeButton(prototype, prototypeContents[i]);
                    i++;
                }

                if (i != 0 && i % prototypeRowCount == 0)
                {
                    EditorGUILayout.EndHorizontal();
                    EditorGUILayout.BeginHorizontal();
                }
                if (!Application.isPlaying)
                {

                    DrawGPUInstancerPrototypeAddButtonTextMode();
                    i++;
                    if (i != 0 && i % prototypeRowCount == 0)
                    {
                        EditorGUILayout.EndHorizontal();
                        EditorGUILayout.BeginHorizontal();
                    }


                }

                EditorGUILayout.EndHorizontal();

                GPUInstancerEditorConstants.DrawCustomLabel("<size=10><i>*Ctrl+Clict to select multiple, Shift+Click to select adjacent items.</i></size>",
                    GPUInstancerEditorConstants.Styles.richLabel, false);

                DrawGPUInstancerPrototypeBox(_manager.selectedPrototypeList);
            }
            EditorGUILayout.EndVertical();
        }



        public void DrawGPUInstancerPrototypeButton(GPUInstancerPrototype prototype, GUIContent prototypeContent)
        {
            base.DrawGPUInstancerPrototypeButton(prototype, prototypeContent, _manager.selectedPrototypeList.Contains(prototype), () =>
            {
                if (_manager.selectedPrototypeList.Count == 1 && Event.current.shift)
                {
                    int oldIndex = prototypeList.IndexOf(_manager.selectedPrototypeList[0]);
                    int newIndex = prototypeList.IndexOf(prototype);
                    for (int i = (oldIndex < newIndex ? oldIndex : newIndex); i <= (oldIndex < newIndex ? newIndex : oldIndex); i++)
                    {
                        if (!_manager.selectedPrototypeList.Contains(prototypeList[i]))
                            _manager.selectedPrototypeList.Add(prototypeList[i]);
                    }
                }
                else if (Event.current.control)
                {
                    if (_manager.selectedPrototypeList.Contains(prototype))
                        _manager.selectedPrototypeList.Remove(prototype);
                    else
                        _manager.selectedPrototypeList.Add(prototype);
                }
                else
                {
                    _manager.selectedPrototypeList.Clear();
                    _manager.selectedPrototypeList.Add(prototype);
                }

                UpdatePrototypeSelection();
                GUI.FocusControl(prototypeContent.tooltip);
            });
        }


        public void DrawGPUInstancerPrototypeAddButtonTextMode()
        {
            Rect prototypeRect = GUILayoutUtility.GetRect(PROTOTYPE_TEXT_RECT_SIZE_X, PROTOTYPE_TEXT_RECT_SIZE_Y, GUILayout.ExpandWidth(false), GUILayout.ExpandHeight(false));

            Rect iconRect = new Rect(prototypeRect.position + PROTOTYPE_RECT_PADDING_VECTOR, PROTOTYPE_TEXT_RECT_SIZE_VECTOR);

            GPUInstancerEditorConstants.DrawColoredButton(GPUInstancerEditorConstants.Contents.addTextMode, GPUInstancerEditorConstants.Colors.lightBlue, Color.white, FontStyle.Bold, iconRect,
                () =>
                {
                    _pickerOverride = null;
                    pickerControlID = EditorGUIUtility.GetControlID(FocusType.Passive) + 100;
                    ShowObjectPicker();
                },
                true, true,
                (o) =>
                {
                    AddPickerObject(o);
                });
        }
    }
}
