using System;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.Events;

namespace GPUInstancer
{
    [CustomEditor(typeof(GPUInstancerPrefabManager))]
    [CanEditMultipleObjects]
    public class GPUInstancerPrefabManagerEditor : GPUInstancerManagerEditor
    {
        private GPUInstancerPrefabManager _prefabManager;

        protected SerializedProperty prop_enableMROnManagerDisable;

        protected override void OnEnable()
        {
            base.OnEnable();

            // wikiHash = "#The_Prefab_Manager";

            _prefabManager = (target as GPUInstancerPrefabManager);

            prop_enableMROnManagerDisable = serializedObject.FindProperty("enableMROnManagerDisable");
        }


        public override void OnInspectorGUI()
        {
            serializedObject.Update();

            base.OnInspectorGUI();

            DrawSceneSettingsBox();

            DrawRegisteredPrefabsBox();
            foreach (GPUInstancerPrefabPrototype prototype in _prefabManager.prototypeList)
            {
                if (prototype == null)
                    continue;

            }

            DrawGPUInstancerPrototypesBox();

            HandlePickerObjectSelection();

            serializedObject.ApplyModifiedProperties();

            base.InspectorGUIEnd();
        }

        public override void ShowObjectPicker()
        {
            base.ShowObjectPicker();

            EditorGUIUtility.ShowObjectPicker<GameObject>(null, false, "t:prefab", pickerControlID);
        }

        public override void AddPickerObject(UnityEngine.Object pickerObject, GPUInstancerPrototype overridePrototype = null)
        {
            base.AddPickerObject(pickerObject, overridePrototype);

            AddPickerObject(_prefabManager, pickerObject, overridePrototype);
        }

        public static GPUInstancerPrefabPrototype AddPickerObject(GPUInstancerPrefabManager _prefabManager, UnityEngine.Object pickerObject, GPUInstancerPrototype overridePrototype = null)
        {
            if (pickerObject == null)
                return null;

            if (pickerObject is GPUInstancerPrefabPrototype)
            {
                GPUInstancerPrefabPrototype prefabPrototype = (GPUInstancerPrefabPrototype)pickerObject;
                if (prefabPrototype.prefabObject != null)
                {
                    pickerObject = prefabPrototype.prefabObject;
                }
            }

            if (!(pickerObject is GameObject))
            {
                if (PrefabUtility.GetPrefabAssetType(pickerObject) == PrefabAssetType.Model)
                    EditorUtility.DisplayDialog(GPUInstancerConstants.TEXT_PREFAB_TYPE_WARNING_TITLE, GPUInstancerConstants.TEXT_PREFAB_TYPE_WARNING_3D, GPUInstancerConstants.TEXT_OK);
                else
                    EditorUtility.DisplayDialog(GPUInstancerConstants.TEXT_PREFAB_TYPE_WARNING_TITLE, GPUInstancerConstants.TEXT_PREFAB_TYPE_WARNING, GPUInstancerConstants.TEXT_OK);
                return null;
            }

            GameObject prefabObject = (GameObject)pickerObject;


            PrefabAssetType prefabType = PrefabUtility.GetPrefabAssetType(pickerObject);

            if (prefabType == PrefabAssetType.Regular || prefabType == PrefabAssetType.Variant)
            {
                if (PrefabUtility.IsPartOfNonAssetPrefabInstance(prefabObject))
                    prefabObject = GPUInstancerUtility.GetOutermostPrefabAssetRoot(prefabObject);
            }
            else
            {
                if (prefabType == PrefabAssetType.Model)
                    EditorUtility.DisplayDialog(GPUInstancerConstants.TEXT_PREFAB_TYPE_WARNING_TITLE, GPUInstancerConstants.TEXT_PREFAB_TYPE_WARNING_3D, GPUInstancerConstants.TEXT_OK);
                else
                    EditorUtility.DisplayDialog(GPUInstancerConstants.TEXT_PREFAB_TYPE_WARNING_TITLE, GPUInstancerConstants.TEXT_PREFAB_TYPE_WARNING, GPUInstancerConstants.TEXT_OK);
                return null;
            }
            if (prefabType == PrefabAssetType.Variant)
            {
                if (prefabObject.GetComponent<GPUInstancerPrefab>() == null &&
                    !EditorUtility.DisplayDialog("Variant Prefab Warning",
                        "Prefab is a Variant. Do you wish to add the Variant as a prototype or the corresponding Prefab?" +
                        "\n\nIt is recommended to add the Prefab, if you do not have different renderers for the Variant.",
                        "Add Variant",
                        "Add Prefab"))
                {
                    prefabObject = GPUInstancerUtility.GetCorrespongingPrefabOfVariant(prefabObject);
                }
            }


            if (_prefabManager.prefabList.Contains(prefabObject))
            {
                return prefabObject.GetComponent<GPUInstancerPrefab>().prefabPrototype;
            }

            GPUInstancerPrefab prefabScript = prefabObject.GetComponent<GPUInstancerPrefab>();
            if (prefabScript != null && prefabScript.prefabPrototype != null && prefabScript.prefabPrototype.prefabObject != prefabObject)
            {

                GPUInstancerUtility.RemoveComponentFromPrefab<GPUInstancerPrefab>(prefabObject);

                prefabScript = null;
            }

            if (prefabScript == null)
            {
                prefabScript = GPUInstancerUtility.AddComponentToPrefab<GPUInstancerPrefab>(prefabObject);

            }
            if (prefabScript == null)
                return null;

            if (prefabScript.prefabPrototype != null && _prefabManager.prototypeList.Contains(prefabScript.prefabPrototype))
            {
                return prefabScript.prefabPrototype;
            }

            Undo.RecordObject(_prefabManager, "Add prototype");

            if (!_prefabManager.prefabList.Contains(prefabObject))
            {
                _prefabManager.prefabList.Add(prefabObject);
                _prefabManager.GeneratePrototypes();
            }

            if (prefabScript.prefabPrototype != null)
            {
                if (_prefabManager.registeredPrefabs == null)
                    _prefabManager.registeredPrefabs = new List<RegisteredPrefabsData>();

                RegisteredPrefabsData data = _prefabManager.registeredPrefabs.Find(d => d.prefabPrototype == prefabScript.prefabPrototype);
                if (data == null)
                {
                    data = new RegisteredPrefabsData(prefabScript.prefabPrototype);
                    _prefabManager.registeredPrefabs.Add(data);
                }

                GPUInstancerPrefab[] scenePrefabInstances = FindObjectsOfType<GPUInstancerPrefab>();
                foreach (GPUInstancerPrefab prefabInstance in scenePrefabInstances)
                    if (prefabInstance.prefabPrototype == prefabScript.prefabPrototype)
                        data.registeredPrefabs.Add(prefabInstance);
            }
            return prefabScript.prefabPrototype;
        }

        public override void DrawSettingContents()
        {
            EditorGUILayout.Space();

            DrawCameraDataFields();

            DrawFloatingOriginFields();

            DrawLayerMaskFields();
        }

        public override void DrawLayerMaskFields()
        {
            base.DrawLayerMaskFields();
            EditorGUI.BeginDisabledGroup(Application.isPlaying);
            EditorGUILayout.PropertyField(prop_enableMROnManagerDisable, GPUInstancerEditorConstants.Contents.enableMROnManagerDisable);
            DrawHelpText(GPUInstancerEditorConstants.HELPTEXT_enableMROnManagerDisable);
            EditorGUI.EndDisabledGroup();
        }


        public static void SetRenderersEnabled(GPUInstancerPrefabPrototype prefabPrototype, bool enabled)
        {
            GameObject prefabContents = GPUInstancerUtility.LoadPrefabContents(prefabPrototype.prefabObject);

            MeshRenderer[] meshRenderers = prefabContents.GetComponentsInChildren<MeshRenderer>(true);
            if (meshRenderers != null && meshRenderers.Length > 0)
                for (int mr = 0; mr < meshRenderers.Length; mr++)
                    meshRenderers[mr].enabled = enabled;

            BillboardRenderer[] billboardRenderers = prefabContents.GetComponentsInChildren<BillboardRenderer>(true);
            if (billboardRenderers != null && billboardRenderers.Length > 0)
                for (int mr = 0; mr < billboardRenderers.Length; mr++)
                    billboardRenderers[mr].enabled = enabled;

            LODGroup lodGroup = prefabContents.GetComponent<LODGroup>();
            if (lodGroup != null)
                lodGroup.enabled = enabled;




            GPUInstancerUtility.UnloadPrefabContents(prefabPrototype.prefabObject, prefabContents, true);

            EditorUtility.SetDirty(prefabPrototype.prefabObject);
            prefabPrototype.meshRenderersDisabled = !enabled;
            EditorUtility.SetDirty(prefabPrototype);
        }



        public override void DrawAddPrototypeHelpText()
        {
            DrawHelpText(GPUInstancerEditorConstants.HELPTEXT_addprototypeprefab);
        }

        public override void DrawRegisteredPrefabsBoxButtons()
        {
            GPUInstancerEditorConstants.DrawColoredButton(GPUInstancerEditorConstants.Contents.registerPrefabsInScene, GPUInstancerEditorConstants.Colors.darkBlue, Color.white, FontStyle.Bold, Rect.zero,
                    () =>
                    {
                        Undo.RecordObject(_prefabManager, "Register prefabs in scene");
                        _prefabManager.RegisterPrefabsInScene();



                    });
            DrawHelpText(GPUInstancerEditorConstants.HELPTEXT_registerPrefabsInScene);

            // if (!GPUInstancerConstants.gpuiSettings.disableInstanceCountWarning)
            // {
            //     bool hasLowInstanceCounts = false;
            //     if (!Application.isPlaying && _prefabManager.registeredPrefabs.Count > 0)
            //     {
            //         foreach (RegisteredPrefabsData rpd in _prefabManager.registeredPrefabs)
            //         {
            //             int count = rpd.prefabPrototype.isTransformsSerialized ? rpd.prefabPrototype.serializedTransformDataCount : rpd.registeredPrefabs.Count;
            //             if (count > 0 && count < 10)
            //                 hasLowInstanceCounts = true;
            //         }
            //     }
            // }
        }

        public override void DrawRegisteredPrefabsBoxList()
        {
            if (!Application.isPlaying && _prefabManager.registeredPrefabs.Count > 0)
            {
                Color defaultColor = GPUInstancerEditorConstants.Styles.label.normal.textColor;
                foreach (RegisteredPrefabsData rpd in _prefabManager.registeredPrefabs)
                {
                    int count = rpd.registeredPrefabs.Count;
                    if (count > 0 && count < 10)
                        GPUInstancerEditorConstants.Styles.label.normal.textColor = Color.red;
                    else
                        GPUInstancerEditorConstants.Styles.label.normal.textColor = defaultColor;
                    if (prototypeSelection.ContainsKey(rpd.prefabPrototype))
                        prototypeSelection[rpd.prefabPrototype] = EditorGUILayout.ToggleLeft(rpd.prefabPrototype.ToString() + " Instance Count: " +
                            count, prototypeSelection[rpd.prefabPrototype], GPUInstancerEditorConstants.Styles.label);
                }

                GPUInstancerEditorConstants.Styles.label.normal.textColor = defaultColor;
            }
            else
            {
                base.DrawRegisteredPrefabsBoxList();
            }
        }

        public override bool DrawGPUInstancerPrototypeInfo(List<GPUInstancerPrototype> selectedPrototypeList)
        {
            return DrawGPUInstancerPrototypeInfo(selectedPrototypeList, (string t) => { DrawHelpText(t); });
        }

        public static bool DrawGPUInstancerPrototypeInfo(List<GPUInstancerPrototype> selectedPrototypeList, UnityAction<string> DrawHelpText)
        {
            GPUInstancerPrefabPrototype prototype0 = (GPUInstancerPrefabPrototype)selectedPrototypeList[0];
            #region Determine Multiple Values
            bool hasChanged = false;

            bool meshRenderersDisabledMixed = false;
            bool meshRenderersDisabled = prototype0.meshRenderersDisabled;
            for (int i = 1; i < selectedPrototypeList.Count; i++)
            {
                GPUInstancerPrefabPrototype prototypeI = (GPUInstancerPrefabPrototype)selectedPrototypeList[i];

                if (!meshRenderersDisabledMixed && meshRenderersDisabled != prototypeI.meshRenderersDisabled)
                    meshRenderersDisabledMixed = true;
            }
            #endregion Determine Multiple Values



            return hasChanged;
        }

        public override void DrawGPUInstancerPrototypeInfo(GPUInstancerPrototype selectedPrototype)
        {
            // DrawGPUInstancerPrototypeInfo(selectedPrototype, (string t) => { DrawHelpText(t); });
        }

        public override void DrawGPUInstancerPrototypeActions()
        {
            if (Application.isPlaying)
                return;
            GUILayout.Space(10);
            //GPUInstancerEditorConstants.DrawCustomLabel(GPUInstancerEditorConstants.TEXT_actions, GPUInstancerEditorConstants.Styles.boldLabel, false);

            DrawDeleteButton(false);
            DrawDeleteButton(true);
        }

        public override void DrawGPUInstancerPrototypeAdvancedActions()
        {

        }

        public override float GetMaxDistance(GPUInstancerPrototype selectedPrototype)
        {
            return GPUInstancerConstants.gpuiSettings.MAX_PREFAB_DISTANCE;
        }
    }
}