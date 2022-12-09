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
        protected SerializedProperty prop_isManagerFrustumCulling;
        // protected SerializedProperty prop_isManagerOcclusionCulling;
        // protected SerializedProperty prop_minCullingDistance;

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

        protected string wikiHash;
        protected string versionNo;

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
            prop_isManagerFrustumCulling = serializedObject.FindProperty("isFrustumCulling");
            // prop_isManagerOcclusionCulling = serializedObject.FindProperty("isOcclusionCulling");
            // prop_minCullingDistance = serializedObject.FindProperty("minCullingDistance");

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

            EditorGUILayout.BeginHorizontal(GPUInstancerEditorConstants.Styles.box);
            EditorGUILayout.LabelField(string.IsNullOrEmpty(versionNo) ? GPUInstancerEditorConstants.GPUI_VERSION : versionNo, GPUInstancerEditorConstants.Styles.boldLabel);
            GUILayout.FlexibleSpace();
            DrawWikiButton(GUILayoutUtility.GetRect(40, 20), wikiHash);
            GUILayout.Space(10);
            DrawHelpButton(GUILayoutUtility.GetRect(20, 20), showHelpText);
            EditorGUILayout.EndHorizontal();
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
                        if (!GPUInstancerConstants.gpuiSettings.IsStandardRenderPipeline())
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
                            if (runtimeData != null && runtimeData.instanceData != null)
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

        public Texture2D GetPreviewTextureFromTexture2D(Texture2D texture)
        {
            if (!texture)
                return null;
            try
            {
                // Create a temporary RenderTexture of the same size as the texture
                RenderTexture tempRT = RenderTexture.GetTemporary(
                                    texture.width,
                                    texture.height,
                                    0,
                                    RenderTextureFormat.Default,
                                    RenderTextureReadWrite.Linear);

                // Blit the pixels on texture to the RenderTexture
                Graphics.Blit(texture, tempRT);
                // Backup the currently set RenderTexture
                RenderTexture previous = RenderTexture.active;
                // Set the current RenderTexture to the temporary one we created
                RenderTexture.active = tempRT;
                // Create a new readable Texture2D to copy the pixels to it
#if UNITY_2017_1_OR_NEWER
                Texture2D myTexture2D = new Texture2D(texture.width, texture.height, TextureFormat.RGBAFloat, true, false);
#else
                Texture2D myTexture2D = new Texture2D(texture.width, texture.height);
#endif
                // Copy the pixels from the RenderTexture to the new Texture
                myTexture2D.ReadPixels(new Rect(0, 0, tempRT.width, tempRT.height), 0, 0);
                myTexture2D.Apply();
                // Reset the active RenderTexture
                RenderTexture.active = previous;
                // Release the temporary RenderTexture
                RenderTexture.ReleaseTemporary(tempRT);

                return myTexture2D;
            }
            catch (Exception) { }
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

        public void DrawCullingSettings(List<GPUInstancerPrototype> protoypeList)
        {
            EditorGUILayout.PropertyField(prop_isManagerFrustumCulling, GPUInstancerEditorConstants.Contents.useManagerFrustumCulling);
            DrawHelpText(GPUInstancerEditorConstants.HELPTEXT_managerFrustumCulling);
            // EditorGUILayout.PropertyField(prop_isManagerOcclusionCulling, GPUInstancerEditorConstants.Contents.useManagerOcclusionCulling);
            // DrawHelpText(GPUInstancerEditorConstants.HELPTEXT_managerOcclusionCulling);

            // #if GPUI_URP
            //             if (prop_isManagerOcclusionCulling.boolValue
            //                 && GraphicsSettings.currentRenderPipeline is UnityEngine.Rendering.Universal.UniversalRenderPipelineAsset
            //                 && !((UnityEngine.Rendering.Universal.UniversalRenderPipelineAsset)GraphicsSettings.currentRenderPipeline).supportsCameraDepthTexture)
            //                 EditorGUILayout.HelpBox("The Occlusion Culling feature requires the Depth Texture option to be enabled in the URP pipeline settings. It is currently disabled.", MessageType.Warning);
            // #endif

            // Min Culling Distance
            // EditorGUI.BeginChangeCheck();
            // float newCullingDistanceValue = EditorGUILayout.Slider(GPUInstancerEditorConstants.Contents.minManagerCullingDistance, prop_minCullingDistance.floatValue, 0, 100);

            // if (EditorGUI.EndChangeCheck())
            // {
            //     if (protoypeList != null)
            //     {
            //         foreach (GPUInstancerPrototype prototype in protoypeList)
            //         {
            //             if (prototype.minCullingDistance == prop_minCullingDistance.floatValue)
            //             {
            //                 prototype.minCullingDistance = newCullingDistanceValue;
            //                 EditorUtility.SetDirty(prototype);
            //             }
            //         }
            //     }
            //     prop_minCullingDistance.floatValue = newCullingDistanceValue;
            // }
            // DrawHelpText(GPUInstancerEditorConstants.HELPTEXT_minCullingDistance);

            // if (protoypeList != null)
            // {
            //     foreach (GPUInstancerPrototype prototype in protoypeList)
            //     {
            //         if (prototype.minCullingDistance < newCullingDistanceValue)
            //         {
            //             prototype.minCullingDistance = newCullingDistanceValue;
            //             EditorUtility.SetDirty(prototype);
            //         }
            //     }
            // }
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
                prototypeColor = string.IsNullOrEmpty(prototype.warningText) ? GPUInstancerEditorConstants.Colors.lightGreen : GPUInstancerEditorConstants.Colors.lightred;
            else
                prototypeColor = string.IsNullOrEmpty(prototype.warningText) ? GUI.backgroundColor : GPUInstancerEditorConstants.Colors.darkred;

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
            Color prototypeColor;
            if (isSelected)
                prototypeColor = string.IsNullOrEmpty(prototype.warningText) ? GPUInstancerEditorConstants.Colors.lightGreen : GPUInstancerEditorConstants.Colors.lightred;
            else
                prototypeColor = string.IsNullOrEmpty(prototype.warningText) ? GUI.backgroundColor : GPUInstancerEditorConstants.Colors.darkred;

            prototypeContent = new GUIContent(prototypeContent.tooltip);
            GPUInstancerEditorConstants.DrawColoredButton(prototypeContent, prototypeColor, GPUInstancerEditorConstants.Styles.label.normal.textColor, FontStyle.Normal, iconRect,
                    () =>
                    {
                        if (handleSelect != null)
                            handleSelect();
                    });
        }

        public virtual void DrawGPUInstancerPrototypeBox(List<GPUInstancerPrototype> selectedPrototypeList, bool isManagerFrustumCulling)
        {
            if (selectedPrototypeList == null || selectedPrototypeList.Count == 0)
                return;

            if (selectedPrototypeList.Count == 1)
            {
                DrawGPUInstancerPrototypeBox(selectedPrototypeList[0], isManagerFrustumCulling);
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
                #region Determine Multiple Values
                bool hasChanged = false;

                bool minDistanceMixed = false;
                float minDistance = prototype0.minDistance;
                bool maxDistanceMixed = false;
                float maxDistance = prototype0.maxDistance;
                bool isFrustumCullingMixed = false;
                bool isFrustumCulling = prototype0.isFrustumCulling;
                bool frustumOffsetMixed = false;
                float frustumOffset = prototype0.frustumOffset;
                // bool occlusionOffsetMixed = false;
                // float occlusionOffset = prototype0.occlusionOffset;
                // bool occlusionAccuracyMixed = false;
                // int occlusionAccuracy = prototype0.occlusionAccuracy;
                // bool minCullingDistanceMixed = false;
                // float minCullingDistance = prototype0.minCullingDistance;
                bool boundsOffsetMixed = false;
                Vector3 boundsOffset = prototype0.boundsOffset;
                for (int i = 1; i < selectedPrototypeList.Count; i++)
                {

                    if (!minDistanceMixed && minDistance != selectedPrototypeList[i].minDistance)
                        minDistanceMixed = true;
                    if (!maxDistanceMixed && maxDistance != selectedPrototypeList[i].maxDistance)
                        maxDistanceMixed = true;
                    if (!isFrustumCullingMixed && isFrustumCulling != selectedPrototypeList[i].isFrustumCulling)
                        isFrustumCullingMixed = true;
                    if (!frustumOffsetMixed && frustumOffset != selectedPrototypeList[i].frustumOffset)
                        frustumOffsetMixed = true;
                    // if (!isOcclusionCullingMixed && isOcclusionCulling != selectedPrototypeList[i].isOcclusionCulling)
                    //     isOcclusionCullingMixed = true;
                    // if (!occlusionOffsetMixed && occlusionOffset != selectedPrototypeList[i].occlusionOffset)
                    //     occlusionOffsetMixed = true;
                    // if (!occlusionAccuracyMixed && occlusionAccuracy != selectedPrototypeList[i].occlusionAccuracy)
                    //     occlusionAccuracyMixed = true;
                    // if (!minCullingDistanceMixed && minCullingDistance != selectedPrototypeList[i].minCullingDistance)
                    //     minCullingDistanceMixed = true;
                    if (!boundsOffsetMixed && boundsOffset != selectedPrototypeList[i].boundsOffset)
                        boundsOffsetMixed = true;
                }
                #endregion Determine Multiple Values

                hasChanged |= DrawGPUInstancerPrototypeBeginningInfo(selectedPrototypeList);

                #region Culling
                EditorGUILayout.BeginVertical(GPUInstancerEditorConstants.Styles.box);
                GPUInstancerEditorConstants.DrawCustomLabel(GPUInstancerEditorConstants.TEXT_culling, GPUInstancerEditorConstants.Styles.boldLabel);

                hasChanged |= MultiMinMaxSlider(selectedPrototypeList, GPUInstancerEditorConstants.TEXT_maxDistance, minDistance, maxDistance, 0.0f, GetMaxDistance(prototype0), minDistanceMixed || maxDistanceMixed, (p, vMin, vMax) => { p.minDistance = vMin; p.maxDistance = vMax; });
                EditorGUILayout.BeginHorizontal();
                hasChanged |= MultiFloat(selectedPrototypeList, " ", minDistance, minDistanceMixed, (p, v) => p.minDistance = v);
                hasChanged |= MultiFloat(selectedPrototypeList, null, maxDistance, minDistanceMixed, (p, v) => p.maxDistance = v);
                EditorGUILayout.EndHorizontal();
                DrawHelpText(GPUInstancerEditorConstants.HELPTEXT_maxDistance);
                if (isManagerFrustumCulling)
                {
                    hasChanged |= MultiToggle(selectedPrototypeList, GPUInstancerEditorConstants.TEXT_isFrustumCulling, isFrustumCulling, isFrustumCullingMixed, (p, v) => p.isFrustumCulling = v);
                    DrawHelpText(GPUInstancerEditorConstants.HELPTEXT_isFrustumCulling);

                    hasChanged |= MultiSlider(selectedPrototypeList, GPUInstancerEditorConstants.TEXT_frustumOffset, frustumOffset, 0.0f, 0.5f, frustumOffsetMixed, (p, v) => p.frustumOffset = v);
                    DrawHelpText(GPUInstancerEditorConstants.HELPTEXT_frustumOffset);
                }

                if (isManagerFrustumCulling)
                {
                    // hasChanged |= MultiSlider(selectedPrototypeList, GPUInstancerEditorConstants.TEXT_minCullingDistance, minCullingDistance, 0, 100, minCullingDistanceMixed, (p, v) => p.minCullingDistance = v);
                    // DrawHelpText(GPUInstancerEditorConstants.HELPTEXT_minCullingDistance);
                }
                hasChanged |= MultiVector3(selectedPrototypeList, GPUInstancerEditorConstants.TEXT_boundsOffset, boundsOffset, boundsOffsetMixed, false, (p, v) => p.boundsOffset = v);
                DrawHelpText(GPUInstancerEditorConstants.HELPTEXT_boundsOffset);

                EditorGUILayout.EndVertical();
                #endregion Culling

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

        public virtual void DrawGPUInstancerPrototypeBox(GPUInstancerPrototype selectedPrototype, bool isFrustumCulling)
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

            if (!string.IsNullOrEmpty(selectedPrototype.warningText))
            {
                EditorGUILayout.HelpBox(selectedPrototype.warningText, MessageType.Error);
                if (selectedPrototype.warningText.StartsWith("Can not create instanced version for shader"))
                {
                    GPUInstancerEditorConstants.DrawColoredButton(new GUIContent("Go to Unity Archive"),
                        GPUInstancerEditorConstants.Colors.darkred, Color.white, FontStyle.Bold, Rect.zero,
                        () =>
                        {
                            Application.OpenURL("https://unity3d.com/get-unity/download/archive");
                        });
                    GUILayout.Space(10);
                }
                else if (selectedPrototype.warningText.StartsWith("ShaderGraph shader does not contain"))
                {
                    GPUInstancerEditorConstants.DrawColoredButton(new GUIContent("Go to Shader Setup Documentation"),
                        GPUInstancerEditorConstants.Colors.darkred, Color.white, FontStyle.Bold, Rect.zero,
                        () =>
                        {
                            Application.OpenURL("https://wiki.gurbu.com/index.php?title=GPU_Instancer:FAQ#ShaderGraph_Setup");
                        });
                    GUILayout.Space(10);
                }
            }


            DrawPrefabField(selectedPrototype);
            EditorGUI.BeginDisabledGroup(true);
            EditorGUILayout.ObjectField(GPUInstancerEditorConstants.TEXT_prototypeSO, selectedPrototype, typeof(GPUInstancerPrototype), false);
            EditorGUI.EndDisabledGroup();

            EditorGUI.BeginChangeCheck();

            DrawGPUInstancerPrototypeBeginningInfo(selectedPrototype);



            #region Culling
            EditorGUILayout.BeginVertical(GPUInstancerEditorConstants.Styles.box);
            GPUInstancerEditorConstants.DrawCustomLabel(GPUInstancerEditorConstants.TEXT_culling, GPUInstancerEditorConstants.Styles.boldLabel);

            EditorGUILayout.MinMaxSlider(GPUInstancerEditorConstants.TEXT_maxDistance, ref selectedPrototype.minDistance, ref selectedPrototype.maxDistance, 0.0f, GetMaxDistance(selectedPrototype));
            EditorGUILayout.BeginHorizontal();
            selectedPrototype.minDistance = EditorGUILayout.FloatField(" ", selectedPrototype.minDistance);
            selectedPrototype.maxDistance = EditorGUILayout.FloatField(selectedPrototype.maxDistance);
            EditorGUILayout.EndHorizontal();
            DrawHelpText(GPUInstancerEditorConstants.HELPTEXT_maxDistance);

            if (isFrustumCulling)
            {
                selectedPrototype.isFrustumCulling = EditorGUILayout.Toggle(GPUInstancerEditorConstants.TEXT_isFrustumCulling, selectedPrototype.isFrustumCulling);
                DrawHelpText(GPUInstancerEditorConstants.HELPTEXT_isFrustumCulling);
                if (selectedPrototype.isFrustumCulling)
                {
                    selectedPrototype.frustumOffset = EditorGUILayout.Slider(GPUInstancerEditorConstants.TEXT_frustumOffset, selectedPrototype.frustumOffset, 0.0f, 0.5f);
                    DrawHelpText(GPUInstancerEditorConstants.HELPTEXT_frustumOffset);
                }
            }

            if (isFrustumCulling)
            {
                // selectedPrototype.minCullingDistance = EditorGUILayout.Slider(GPUInstancerEditorConstants.TEXT_minCullingDistance, selectedPrototype.minCullingDistance, 0, 100);
                // DrawHelpText(GPUInstancerEditorConstants.HELPTEXT_minCullingDistance);
            }
            EditorGUI.BeginDisabledGroup(Application.isPlaying);
            selectedPrototype.boundsOffset = EditorGUILayout.Vector3Field(GPUInstancerEditorConstants.TEXT_boundsOffset, selectedPrototype.boundsOffset);
            EditorGUI.EndDisabledGroup();
            if (selectedPrototype.boundsOffset.x < 0)
                selectedPrototype.boundsOffset.x = 0;
            if (selectedPrototype.boundsOffset.y < 0)
                selectedPrototype.boundsOffset.y = 0;
            if (selectedPrototype.boundsOffset.z < 0)
                selectedPrototype.boundsOffset.z = 0;
            DrawHelpText(GPUInstancerEditorConstants.HELPTEXT_boundsOffset);

            EditorGUILayout.EndVertical();
            #endregion Culling


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

        public static void DrawWikiButton(Rect buttonRect, string hash)
        {
            DrawWikiButton(buttonRect, "GPU_Instancer:GettingStarted", hash, "Wiki", GPUInstancerEditorConstants.Colors.lightBlue);
        }

        public static void DrawWikiButton(Rect buttonRect, string title, string hash, string buttonText, Color buttonColor)
        {
            GPUInstancerEditorConstants.DrawColoredButton(new GUIContent(buttonText),
                    buttonColor, Color.white, FontStyle.Bold, buttonRect,
                    () => { Application.OpenURL("https://wiki.gurbu.com/index.php?title=" + title + hash); }
                    );
        }

        public void DrawHelpButton(Rect buttonRect, bool showingHelp)
        {
            if (GUI.Button(buttonRect, new GUIContent(showHelpText ? helpIconActive : helpIcon,
                showHelpText ? GPUInstancerEditorConstants.TEXT_hideHelpTooltip : GPUInstancerEditorConstants.TEXT_showHelpTooltip), showHelpText ? GPUInstancerEditorConstants.Styles.helpButtonSelected : GPUInstancerEditorConstants.Styles.helpButton))
            {
                showHelpText = !showHelpText;
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
