using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.Events;

namespace GPUInstancer
{
    public static class GPUInstancerEditorConstants
    {
        public static readonly string GPUI_VERSION = "GPU Instancer v1.7.0";
        public static readonly float GPUI_VERSION_NO = 1.70f;


        public static readonly string TEXT_simulateAtEditor = "Simulate At Scene Camera";
        public static readonly string TEXT_simulateAtEditorPrep = "Preparing Simulation";
        public static readonly string TEXT_simulateAtEditorStop = "Stop Simulation";
        public static readonly string TEXT_generatePrototypes = "Generate Prototypes";
        public static readonly string TEXT_prototypes = "Prototypes";
        public static readonly string TEXT_add = "Add\n<size=8>Click / Drop</size>";
        public static readonly string TEXT_addTextMode = "Add Prototype";
        public static readonly string TEXT_addMulti = "<size=8>Multi. Add</size>";
        public static readonly string TEXT_addMultiTextMode = "Add Multiple";
        public static readonly string TEXT_isFrustumCulling = "Is Frustum Culling";
        public static readonly string TEXT_frustumOffset = "Frustum Offset";
        public static readonly string TEXT_minCullingDistance = "Min. Culling Distance";
        public static readonly string TEXT_maxDistance = "Min-Max Distance";
        public static readonly string TEXT_boundsOffset = "Bounds Size Offset";
        public static readonly string TEXT_actions = "Actions";
        public static readonly string TEXT_advancedActions = "Advanced Actions";
        public static readonly string TEXT_delete = "Delete";
        public static readonly string TEXT_removeFromList = "Remove From List";

        public static readonly string TEXT_deleteConfirmation = "Delete Confirmation";
        public static readonly string TEXT_deleteAreYouSure = "Are you sure you want to remove the prototype from prototype list?";
        public static readonly string TEXT_deletePrototypeAreYouSure = "Do you wish to remove the prototype from prototype list and delete the prototype settings?";
        public static readonly string TEXT_close = "Close";
        public static readonly string TEXT_cancel = "Cancel";
        public static readonly string TEXT_enableRuntimeModifications = "Enable Runtime Modifications";
        public static readonly string TEXT_addRemoveInstancesAtRuntime = "Add/Remove Instances At Runtime";
        public static readonly string TEXT_extraBufferSize = "Extra Buffer Size";
        public static readonly string TEXT_registerPrefabsInScene = "Register Instances in Scene";
        public static readonly string TEXT_registeredPrefabs = "Registered Instances";

        public static readonly string TEXT_sceneSettings = "Scene Settings";
        public static readonly string TEXT_autoSelectCamera = "Auto Select Camera";
        public static readonly string TEXT_useCamera = "Use Camera";
        public static readonly string TEXT_renderOnlySelectedCamera = "Use Selected Camera Only";
        public static readonly string TEXT_useManagerFrustumCulling = "Use Frustum Culling";
        public static readonly string TEXT_info = "Info";
        public static readonly string TEXT_noPrefabInstanceFound = "There are no prefab instances found in the scene.";
        public static readonly string TEXT_noPrefabInstanceSelected = "Please select at least one prefab instance to import to Prefab Manager.";

        public static readonly string TEXT_prefabObject = "Prefab Object";
        public static readonly string TEXT_prototypeSO = "Prototype SO";

        public static readonly string TEXT_prefabInstancingActive = "Instancing active with ID: ";
        public static readonly string TEXT_prefabInstancingDisabled = "Instancing disabled for ID: ";
        public static readonly string TEXT_prefabInstancingNone = "Instancing has not been initialized";

        public static readonly string TEXT_importSelectedPrefabs = "Import Selected Prefabs";


        public static readonly string TEXT_settingAutoGenerateBillboards = "Auto Generate Billboards";
        public static readonly string TEXT_settingAutoShaderConversion = "Auto Shader Conversion";
        public static readonly string TEXT_settingUseOriginalMaterial = "Use Original Material When Instanced";
        public static readonly string TEXT_settingAutoShaderVariantHandling = "Auto Shader Variant Handling";
        public static readonly string TEXT_settingGenerateShaderVariant = "Generate Shader Variant Collection";
        public static readonly string TEXT_settingDisableICWarning = "Disable Instance Count Warnings";
        public static readonly string TEXT_settingMaxDetailDist = "Max Detail Distance";
        public static readonly string TEXT_settingMaxTreeDist = "Max Tree Distance";
        public static readonly string TEXT_settingMaxPrefabDist = "Max Prefab Distance";
        public static readonly string TEXT_settingMaxPrefabBuff = "Max Prefab Extra Buffer Size";
        public static readonly string TEXT_settingCustomPrevBG = "Custom Preview BG Color";
        public static readonly string TEXT_settingPrevBGColor = "Preview BG Color";
        public static readonly string TEXT_settingInstancingBoundsSize = "Instancing Bounds Size";

        public static readonly string TEXT_settingHasCustomRenderingSettings = "Use Custom Rendering Settings";
        public static readonly string TEXT_settingComputeThread = "Max. Compute Thread Count";
        public static readonly string TEXT_settingMatrixHandlingType = "Max. Compute Buffers";
        public static readonly string TEXT_settingOcclusionCullingType = "Occlusion Culling Type";

        // Editor HelpText
        public static readonly string HELPTEXT_camera = "The camera to use for GPU Instancing. When \"Auto Select Camera\" checkbox is active, GPU Instancer will use the first camera with the \"MainCamera\" tag at startup. If the checkbox is inactive, the desired camera can be set manually. GPU Instancer uses this camera for various calculations including culling operations.";
        public static readonly string HELPTEXT_renderOnlySelectedCamera = "If \"Use Selected Camera Only\" is enabled, instances will only be rendered with the selected camera. They will not be rendered in other active cameras (including the Scene View camera). This may improve performance if there are other cameras in the scene that are mainly used for camera effects, weather/water effects, reflections, etc. Using this option will make them ignore GPUI, increasing performance. Please note that the scene view during play mode will no longer show GPUI instances if this is selected.";
        public static readonly string HELPTEXT_maxDetailDistance = "\"Max Detail Distance\" defines the maximum distance from the camera within which the terrain details will be rendered. Details that are farther than the specified distance will not be visible. This setting also provides the upper limit for the maximum view distance of each detail prototype.";
        public static readonly string HELPTEXT_prototypes = "\"Prototypes\" show the list of objects that will be used in GPU Instancer. To modify a prototype, click on its icon or text. Use the \"Text Mode\" or \"Icon Mode\" button to switch between preview modes.";
        public static readonly string HELPTEXT_addprototypeprefab = "Click on \"Add\" button and select a prefab to add a prefab prototype to the manager. Note that prefab manager only accepts user created prefabs. It will not accept prefabs that are generated when importing your 3D model assets.";
        public static readonly string HELPTEXT_registerPrefabsInScene = "The \"Register Prefabs In Scene\" button can be used to register the prefab instances that are currently in the scene, so that they can be used by GPU Instancer. For adding new instances at runtime check API documentation.";

        public static readonly string HELPTEXT_maxDistance = "\"Min-Max Distance\" defines the minimum and maximum distance from the selected camera within which this prototype will be rendered.";

        public static readonly string HELPTEXT_enableRuntimeModifications = "If \"Enable Runtime Modifications\" is enabled, transform data (position, rotation, scale) for the prefab instances can be modified at runtime with API calls.";
        public static readonly string HELPTEXT_addRemoveInstancesAtRuntime = "If \"Add/Remove Instances At Runtime\" is enabled, new prefab instances can be added or existing ones can be removed at runtime with API calls or by enabling \"Automatically Add/Remove Instances\"";
        public static readonly string HELPTEXT_extraBufferSize = "\"Extra Buffer Size\" specifies the amount of prefab instances that can be added without reinitializing compute buffers at runtime. Instances can be added at runtime with API calls or by enabling \"Automatically Add/Remove Instances\".";


        public static readonly string HELPTEXT_prefabImporterIntro = "The Scene Prefab Importer is designed to easily define prefabs from the existing prefab instances in your scenes to the GPUI Prefab Manager as prototypes. Press the \"?\" button on the top right corner to see more information.";
        public static readonly string HELPTEXT_prefabImporterImportCancel = "The \"Import Selected Prefabs\" button creates a new GPUI Prefab Manager with the selected prefabs defined as prototypes on it. The \"Cancel\" button closes this window.";
        public static readonly string HELPTEXT_prefabImporterSelectAllNone = "The \"Select All\" button selects all the prefabs in the \"Prefab Instances\" section. The \"Select None\" button deselects all the prefabs.";
        public static readonly string HELPTEXT_prefabImporterSelectOverCount = "You can choose an instance count and press the \"Select Min. Instance Count\" button to select the prefabs with the instance counts over the designated number.";
        public static readonly string HELPTEXT_prefabImporterInstanceList = "The \"Prefab Instances\" section shows the list of all the prefab instances that are in the current scene. You can select the ones you wish to import into GPUI Prefab Manager.";

        public static readonly string HELPTEXT_prefabReplacerIntro = "The Prefab Replacer is designed to easily replace GameObjects in your scene hierarchy with prefab instances. Press the \"?\" button on the top right corner to see more information.";
        public static readonly string HELPTEXT_prefabReplacerReplaceCancel = "The \"Replace Selection With Prefab\" button replaces the selected GameObjects with the prefab's instances. The \"Cancel\" button closes this window.";
        public static readonly string HELPTEXT_prefabReplacerPrefab = "The \"Prefab\" will be used to create instances that will replace the selected GameObjects.";
        public static readonly string HELPTEXT_prefabReplacerSelectedObjects = "The \"Selected GameObjects\" section shows the list of selected GameObjects that will be replaced with prefab instances.";
        public static readonly string HELPTEXT_prefabReplacerReplaceNames = "If \"Replace Names\" option is enabled, new instances will use the prefab name. If disabled, instances will have the same names with the GameObjects that are being replaced.";

        public static readonly string HELPTEXT_removeFromList = "The \"Remove From List\" button removes the prototype from this manager but keeps the settings data related to this prototype.";
        public static readonly string HELPTEXT_delete = "The \"Delete\" button deletes this prototype and removes all related data.";

        public static readonly string ERRORTEXT_cameraNotFound = "Main Camera cannot be found. GPU Instancer needs either an existing camera with the \"Main Camera\" tag on the scene to autoselect it, or a manually specified camera. If you add your camera at runtime, please use the \"GPUInstancerAPI.SetCamera(camera)\" API function.";

        public static readonly string HELPTEXT_autoGenerateBillboards = "If enabled, billboard textures will be automatically generated for known tree types when they are added to the GPUI Managers.";
        public static readonly string HELPTEXT_autoShaderConversion = "If enabled, shaders of the prefabs that are added to the GPUI Managers will be automatically converted to support GPU Instancer.";
        public static readonly string HELPTEXT_settingUseOriginalMaterial = "If enabled, GPUI will not create a copy of the materials that uses shaders that are setup for GPUI.";
        public static readonly string HELPTEXT_autoShaderVariantHandling = "If enabled, shaders variants of the prefabs that are added to the GPUI Managers will be automatically added to a ShaderVariantCollection to be included in builds.";
        public static readonly string HELPTEXT_generateShaderVariantCollection = "If enabled, a ShaderVariantCollection with reference to shaders that are used in GPUI Managers will be generated automatically inside Resources folder. This will add the GPUI shader variants automatically to your builds. These shader variants are required for GPUI to work in your builds.";
        public static readonly string HELPTEXT_disableInstanceCountWarnings = "If enabled, Prefab Manager will not show warnings for prototypes with low instance counts.";
        public static readonly string HELPTEXT_customPreviewBG = "If enabled, custom background color can be used for preview icons of the prototypes.";
        public static readonly string HELPTEXT_settingInstancingBoundsSize = "Defines the bounds parameter's size for the instanced rendering draw call.";

        public static readonly string HELPTEXT_settingHasCustomRenderingSettings = "Use Custom Rendering Settings";
        public static readonly string HELPTEXT_settingComputeThread = "Max. Compute Thread Count";
        public static readonly string HELPTEXT_settingMatrixHandlingType = "Max. Compute Buffers";
        public static readonly string HELPTEXT_settingOcclusionCullingType = "Occlusion Culling Type";


        public static readonly string HELPTEXT_layerMask = "Can be used to discard specific Mesh Renderers of the prototypes. When a Layer is not rendered by GPUI, it will be rendered by the Unity Mesh Renderer component. GPUI will also not enable/disable the Mesh Renderers of the discarded Layer when using Prefab Manager. This allows you to disable GPUI for a specific child Mesh Renderer of a prefeb.";
        public static readonly string HELPTEXT_enableMROnManagerDisable = "If enabled, Prefab Manager will automatically re-enable the Mesh Renderers of the instances when the manager is disabled.";

        public static readonly string WARNINGTEXT_instanceCounts = "When using the Prefab Manager in your scene, the best practice is to add the distinctively repeating prefabs in the scene to the manager as prototypes. Using GPUI for prototypes with very low instance counts is not recommended.";

        public static readonly string HELP_ICON = "help_gpui";
        public static readonly string HELP_ICON_ACTIVE = "help_gpui_active";
        public static readonly string DROP_ICON = "drop";
        public static readonly string PREVIEW_BOX_ICON = "previewBox";

        public static class Contents
        {

            public static GUIContent removeFromList = new GUIContent(TEXT_removeFromList);
            public static GUIContent delete = new GUIContent(TEXT_delete);
            public static GUIContent registerPrefabsInScene = new GUIContent(TEXT_registerPrefabsInScene);

            public static GUIContent add = new GUIContent(TEXT_add);
            public static GUIContent addTextMode = new GUIContent(TEXT_addTextMode);
            public static GUIContent addMulti = new GUIContent(TEXT_addMulti);
            public static GUIContent addMultiTextMode = new GUIContent(TEXT_addMultiTextMode);
            public static GUIContent useCamera = new GUIContent(TEXT_useCamera);
            public static GUIContent renderOnlySelectedCamera = new GUIContent(TEXT_renderOnlySelectedCamera, TEXT_renderOnlySelectedCamera);


            public static GUIContent importSelectedPrefabs = new GUIContent(TEXT_importSelectedPrefabs);
            public static GUIContent cancel = new GUIContent(TEXT_cancel);


            public static GUIContent disableMeshRenderers = new GUIContent("Disable Mesh Renderers");
            public static GUIContent enableMeshRenderers = new GUIContent("Enable Mesh Renderers");
            public static GUIContent serializeRegisteredInstances = new GUIContent("Serialize Registered Instances");
            public static GUIContent deserializeRegisteredInstances = new GUIContent("Deserialize Registered Instances");

            public static GUIContent settingAutoGenerateBillboards = new GUIContent(TEXT_settingAutoGenerateBillboards, HELPTEXT_autoGenerateBillboards);
            public static GUIContent settingAutoShaderConversion = new GUIContent(TEXT_settingAutoShaderConversion, HELPTEXT_autoShaderConversion);
            public static GUIContent settingUseOriginalMaterial = new GUIContent(TEXT_settingUseOriginalMaterial, HELPTEXT_settingUseOriginalMaterial);
            public static GUIContent settingAutoShaderVariantHandling = new GUIContent(TEXT_settingAutoShaderVariantHandling, HELPTEXT_autoShaderVariantHandling);
            public static GUIContent settingGenerateShaderVariant = new GUIContent(TEXT_settingGenerateShaderVariant, HELPTEXT_generateShaderVariantCollection);
            public static GUIContent settingDisableICWarning = new GUIContent(TEXT_settingDisableICWarning, HELPTEXT_disableInstanceCountWarnings);
            public static GUIContent settingMaxDetailDist = new GUIContent(TEXT_settingMaxDetailDist, HELPTEXT_maxDetailDistance);
            public static GUIContent settingMaxPrefabDist = new GUIContent(TEXT_settingMaxPrefabDist, HELPTEXT_maxDistance);
            public static GUIContent settingMaxPrefabBuff = new GUIContent(TEXT_settingMaxPrefabBuff, HELPTEXT_extraBufferSize);
            public static GUIContent settingCustomPrevBG = new GUIContent(TEXT_settingCustomPrevBG, HELPTEXT_customPreviewBG);
            public static GUIContent settingPrevBGColor = new GUIContent(TEXT_settingPrevBGColor, HELPTEXT_customPreviewBG);
            public static GUIContent settingInstancingBoundsSize = new GUIContent(TEXT_settingInstancingBoundsSize, HELPTEXT_settingInstancingBoundsSize);
            public static GUIContent settingHasCustomRenderingSettings = new GUIContent(TEXT_settingHasCustomRenderingSettings, HELPTEXT_settingHasCustomRenderingSettings);
            public static GUIContent settingComputeThread = new GUIContent(TEXT_settingComputeThread, HELPTEXT_settingComputeThread);
            public static GUIContent[] settingComputeThreadOptions = new GUIContent[] { new GUIContent("64"), new GUIContent("128"), new GUIContent("256"), new GUIContent("512"), new GUIContent("1024") };
            public static GUIContent settingMatrixHandlingType = new GUIContent(TEXT_settingMatrixHandlingType, HELPTEXT_settingMatrixHandlingType);
            public static GUIContent[] settingMatrixHandlingTypeOptions = new GUIContent[] { new GUIContent("Unlimited"), new GUIContent("1 Compute Buffer"), new GUIContent("None") };

            public static GUIContent useFloatingOriginHandler = new GUIContent("Use Floating Origin");
            public static GUIContent floatingOriginTransform = new GUIContent("Transform of Floating Origin");
            public static GUIContent applyFloatingOriginRotationAndScale = new GUIContent("Apply Rotation and Scale of Floating Origin");

            public static GUIContent disableLightProbes = new GUIContent("Disable Light Probes");

            public static GUIContent layerMask = new GUIContent("Layer Mask");
            public static GUIContent enableMROnManagerDisable = new GUIContent("Enable MR on Disable", "Enable Mesh Renderers when Manager is Disabled");
        }

        public static class Styles
        {
            public static GUIStyle label = new GUIStyle("Label");
            public static GUIStyle boldLabel = new GUIStyle("BoldLabel");
            public static GUIStyle button = new GUIStyle("Button");
            public static GUIStyle foldout = new GUIStyle("Foldout");
            public static GUIStyle box = new GUIStyle("Box");
            public static GUIStyle richLabel = new GUIStyle("Label");
            public static GUIStyle helpButton = new GUIStyle("Button")
            {
                padding = new RectOffset(2, 2, 2, 2)
            };
            public static GUIStyle helpButtonSelected = new GUIStyle("Button")
            {
                padding = new RectOffset(2, 2, 2, 2),
                normal = helpButton.active
            };
        }

        public static class Colors
        {
            public static Color lightBlue = new Color(0.5f, 0.6f, 0.8f, 1);
            public static Color darkBlue = new Color(0.07f, 0.27f, 0.35f, 1);
            public static Color lightGreen = new Color(0.2f, 1f, 0.2f, 1);
            public static Color green = new Color(0, 0.4f, 0, 1);
            public static Color lightred = new Color(0.4f, 0, 0, 1);
            public static Color darkred = new Color(0.8f, 0.2f, 0.2f, 1);
            public static Color gainsboro = new Color(220 / 255f, 220 / 255f, 220 / 255f);
            public static Color dimgray = new Color(105 / 255f, 105 / 255f, 105 / 255f);
            public static Color darkyellow = new Color(153 / 255f, 153 / 255f, 0);
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


        [MenuItem("Tools/GPU Instancer/Shaders/Clear Shader Bindings", validate = false, priority = 201)]
        public static void ClearShaderBindings()
        {
            GPUInstancerShaderBindings shaderBindings = GPUInstancerDefines.GetGPUInstancerShaderBindings();
            if (shaderBindings != null && shaderBindings.shaderInstances != null && shaderBindings.shaderInstances.Count > 0)
            {
                if (EditorUtility.DisplayDialog("Clear Shader bindings", "This operation will clear references for GPUI compatible shaders and they will be recreated when needed.\n\nDo you wish to continue?",
                    "Yes", "No"))
                {

                    if (EditorUtility.DisplayDialog("Delete GPUI Shaders", "Do you want to delete the auto generated GPUI shaders? They will be recreated when needed.",
                        "Yes", "No"))
                    {
                        foreach (ShaderInstance si in shaderBindings.shaderInstances)
                        {
                            if (!si.isOriginalInstanced)
                                AssetDatabase.DeleteAsset(AssetDatabase.GetAssetPath(si.instancedShader));
                        }
                    }
                    shaderBindings.shaderInstances.Clear();
                    EditorUtility.SetDirty(shaderBindings);
                    AssetDatabase.SaveAssets();
                    AssetDatabase.Refresh();
                }
            }
        }

        // [MenuItem("Tools/GPU Instancer/Shaders/Edit Shader Variants", validate = false, priority = 301)]
        // public static void EditShaderVariants()
        // {
        //     ShaderVariantCollection shaderVariantCollection = GPUInstancerDefines.GetShaderVariantCollection();
        //     if (shaderVariantCollection != null)
        //         Selection.activeObject = shaderVariantCollection;
        // }

        [MenuItem("Tools/GPU Instancer/Reimport Packages", validate = false, priority = 401)]
        public static void ReimportPackages()
        {
            GPUInstancerDefines.ImportPackages(true);
        }


        [SettingsProvider]
        public static SettingsProvider PreferencesGPUInstancerGUI()
        {
            var provider = new SettingsProvider("Preferences/GPU Instancer", SettingsScope.User)
            {
                label = "GPU Instancer",
                guiHandler = (searchContext) =>
                {
                    DrawGPUISettings();
                },
                keywords = new HashSet<string>(new[] { "GPU", "Instancer", "GPUI" })
            };

            return provider;
        }


        private static bool _loadedSettings;
        private static bool _hasCustomRenderingSettings;
        private static int _threadCountSelection;
        private static int _matrixHandlingTypeSelection;
        private static bool _customRenderingSettingsChanged;

        public static void DrawGPUISettings()
        {
            GPUInstancerSettings gPUInstancerSettings = GPUInstancerConstants.gpuiSettings;

            if (!gPUInstancerSettings)
                return;


            float previousLabelWight = EditorGUIUtility.labelWidth;
            EditorGUIUtility.labelWidth = previousLabelWight + 75f;
            EditorGUI.BeginChangeCheck();

            EditorGUILayout.BeginVertical(Styles.box);
            DrawCustomLabel("Constants", Styles.boldLabel);
            GUILayout.Space(5);


            gPUInstancerSettings.MAX_PREFAB_DISTANCE = EditorGUILayout.IntField(Contents.settingMaxPrefabDist, (int)gPUInstancerSettings.MAX_PREFAB_DISTANCE);
            gPUInstancerSettings.instancingBoundsSize = EditorGUILayout.IntSlider(Contents.settingInstancingBoundsSize, gPUInstancerSettings.instancingBoundsSize, 1, 10000);

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

            if (EditorGUI.EndChangeCheck())
            {
                EditorUtility.SetDirty(gPUInstancerSettings);
            }

            bool updateExists = false;

            EditorGUILayout.BeginVertical(Styles.box);
            GUILayout.Space(5);
            DrawCustomLabel("Update Jobs", Styles.boldLabel);



            if (!updateExists)
                EditorGUILayout.HelpBox("No actions required for the current version.", MessageType.Info);

            GUILayout.Space(5);
            EditorGUILayout.EndVertical();


            EditorGUILayout.BeginVertical(Styles.box);
            GUILayout.Space(5);
            DrawCustomLabel("Package Definitions", Styles.boldLabel);

            // EditorGUI.BeginDisabledGroup(true);

            // EditorGUILayout.Toggle("ShaderGraph Loaded", gPUInstancerSettings.isShaderGraphPresent);
            // EditorGUI.EndDisabledGroup();

            DrawColoredButton(new GUIContent("Reload Packages"), Colors.green, Color.white, FontStyle.Bold, Rect.zero,
            () =>
            {
                gPUInstancerSettings.packagesLoaded = false;
                GPUInstancerDefines.LoadPackageDefinitions();
            });

            GUILayout.Space(5);
            EditorGUILayout.EndVertical();


            EditorGUIUtility.labelWidth = previousLabelWight;
        }
    }
}