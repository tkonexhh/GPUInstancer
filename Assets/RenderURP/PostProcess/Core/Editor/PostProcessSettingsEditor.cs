using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEditorInternal;
using UnityEngine.Rendering.Universal;
using Inutan.PostProcessing;

// 参考 HDRP
[CustomPropertyDrawer(typeof(PostProcessFeature.PostProcessSettings), true)]
internal class PostProcessSettingsEditor : PropertyDrawer 
{
    private SerializedProperty m_PostProcessFeatureData;

    private List<SerializedObject> m_properties = new List<SerializedObject>();

    /// This will contain a list of all available renderers for each injection point.
    private Dictionary<PostProcessInjectionPoint, List<Type>> _availableRenderers;

    /// Contains 3 Reorderable list for each settings property.
    private struct DrawerState 
    {
        public ReorderableList listBeforeRenderingDeferredLights, listAfterRenderingSkybox, listBeforeRenderingPostProcessing, listAfterRenderingPostProcessing;
    }

    /// Since the drawer is shared for multiple properties, we need to store the reorderable lists for each property by path.
    private Dictionary<string, DrawerState> propertyStates = new Dictionary<string, DrawerState>();

    /// Get the renderer name from the attached custom post-process attribute.
    private string GetName(Type type)
    {
        return Inutan.PostProcessing.PostProcessAttribute.GetAttribute(type)?.Name ?? type?.Name;
    }

    /// Intialize a reoderable list
    void InitList(ref ReorderableList reorderableList, List<string> elements, string headerName, PostProcessInjectionPoint injectionPoint, PostProcessFeature feature)
    {
        reorderableList = new ReorderableList(elements, typeof(string), true, true, true, true);

        reorderableList.drawHeaderCallback = (rect) => EditorGUI.LabelField(rect, headerName, EditorStyles.boldLabel);

        reorderableList.drawElementCallback = (rect, index, isActive, isFocused) =>
        {
            rect.height = EditorGUIUtility.singleLineHeight;
            var elemType = Type.GetType(elements[index]);
            EditorGUI.LabelField(rect, GetName(elemType), EditorStyles.boldLabel);
        };

        reorderableList.onAddCallback = (list) =>
        {
            var menu = new GenericMenu();

            foreach (var type in _availableRenderers[injectionPoint])
            {
                if (!elements.Contains(type.AssemblyQualifiedName))
                    menu.AddItem(new GUIContent(GetName(type)), false, () => 
                    {
                        Undo.RegisterCompleteObjectUndo(feature, $"Added {type.ToString()} Custom Post Process");
                        elements.Add(type.AssemblyQualifiedName);
                        forceRecreate(feature); // This is done since OnValidate doesn't get called.
                    });
            }

            if (menu.GetItemCount() == 0)
                menu.AddDisabledItem(new GUIContent("No Post Process Availble"));

            menu.ShowAsContext();
            EditorUtility.SetDirty(feature);
        };
        reorderableList.onRemoveCallback = (list) =>
        {
            Undo.RegisterCompleteObjectUndo(feature, $"Removed {list.list[list.index].ToString()} Custom Post Process");
            elements.RemoveAt(list.index);
            EditorUtility.SetDirty(feature);
            forceRecreate(feature); // This is done since OnValidate doesn't get called.
        };
        reorderableList.elementHeightCallback = _ => EditorGUIUtility.singleLineHeight + EditorGUIUtility.standardVerticalSpacing;
        reorderableList.onReorderCallback = (list) => 
        { 
            EditorUtility.SetDirty(feature); 
            forceRecreate(feature); // This is done since OnValidate doesn't get called.
        };
    }

    /// Initialize a drawer state for the giver property if none already exists.
    private void Init(SerializedProperty property)
    {
        var path = property.propertyPath;
        if(!propertyStates.ContainsKey(path))
        {
            var state = new DrawerState();
            var feature = property.serializedObject.targetObject as PostProcessFeature;
            InitList(ref state.listBeforeRenderingDeferredLights, feature.m_Settings.m_RenderersBeforeRenderingDeferredLights, 
                                    "BeforeRenderingDeferredLights", PostProcessInjectionPoint.BeforeRenderingDeferredLights, feature);
            InitList(ref state.listAfterRenderingSkybox, feature.m_Settings.m_RenderersAfterRenderingSkybox, 
                                    "AfterRenderingSkybox", PostProcessInjectionPoint.AfterRenderingSkybox, feature);
            InitList(ref state.listBeforeRenderingPostProcessing, feature.m_Settings.m_RenderersBeforeRenderingPostProcessing, 
                                    "BeforeRenderingPostProcessing", PostProcessInjectionPoint.BeforeRenderingPostProcessing, feature);
            InitList(ref state.listAfterRenderingPostProcessing, feature.m_Settings.m_RenderersAfterRenderingPostProcessing, 
                                    "AfterRenderingPostProcessing", PostProcessInjectionPoint.AfterRenderingPostProcessing, feature);
            propertyStates.Add(path, state);
        }
    }

    /// Present the property on the Editor GUI
    public override void OnGUI(Rect position, SerializedProperty property, GUIContent label)
    {        
        if (!m_properties.Contains(property.serializedObject))
        {
            m_PostProcessFeatureData = property.FindPropertyRelative("m_PostProcessFeatureData");
            m_properties.Add(property.serializedObject);
        }
       
        EditorGUI.PropertyField(position, m_PostProcessFeatureData);
        EditorGUILayout.Space();
        EditorGUILayout.Space();

        populateRenderers();
        EditorGUI.BeginProperty(position, label, property);
        Init(property);
        DrawerState state = propertyStates[property.propertyPath];
        EditorGUI.BeginChangeCheck();
        state.listBeforeRenderingDeferredLights.DoLayoutList();
        EditorGUILayout.Space();
        state.listAfterRenderingSkybox.DoLayoutList();
        EditorGUILayout.Space();
        state.listBeforeRenderingPostProcessing.DoLayoutList();
        EditorGUILayout.Space();
        state.listAfterRenderingPostProcessing.DoLayoutList();
        if (EditorGUI.EndChangeCheck())
        {
            property.serializedObject.ApplyModifiedProperties();
        }
        EditorGUI.EndProperty();
        EditorUtility.SetDirty(property.serializedObject.targetObject);
    }

    /// Force recreating the render feature
    private void forceRecreate(PostProcessFeature feature)
    {
        feature.Create();
    }

    /// Finds all the custom post-processing renderer classes and categorizes them by injection point
    private void populateRenderers()
    {
        if(_availableRenderers != null) return;
        _availableRenderers = new Dictionary<PostProcessInjectionPoint, List<Type>>()
        {
            { PostProcessInjectionPoint.BeforeRenderingDeferredLights, new List<Type>() },
            { PostProcessInjectionPoint.AfterRenderingSkybox         , new List<Type>() },
            { PostProcessInjectionPoint.BeforeRenderingPostProcessing, new List<Type>() },
            { PostProcessInjectionPoint.AfterRenderingPostProcessing , new List<Type>() }
        };
        foreach(var type in TypeCache.GetTypesDerivedFrom<PostProcessRenderer>())
        {
            if(type.IsAbstract) continue;
            var attributes = type.GetCustomAttributes(typeof(Inutan.PostProcessing.PostProcessAttribute), false);
            if(attributes.Length != 1) continue;
            Inutan.PostProcessing.PostProcessAttribute attribute = attributes[0] as Inutan.PostProcessing.PostProcessAttribute;
            if(attribute.InjectionPoint.HasFlag(PostProcessInjectionPoint.BeforeRenderingDeferredLights))
                _availableRenderers[PostProcessInjectionPoint.BeforeRenderingDeferredLights].Add(type);
            if(attribute.InjectionPoint.HasFlag(PostProcessInjectionPoint.AfterRenderingSkybox))
                _availableRenderers[PostProcessInjectionPoint.AfterRenderingSkybox].Add(type);
            if(attribute.InjectionPoint.HasFlag(PostProcessInjectionPoint.BeforeRenderingPostProcessing))
                _availableRenderers[PostProcessInjectionPoint.BeforeRenderingPostProcessing].Add(type);
            if(attribute.InjectionPoint.HasFlag(PostProcessInjectionPoint.AfterRenderingPostProcessing))
                _availableRenderers[PostProcessInjectionPoint.AfterRenderingPostProcessing].Add(type);
        }
    }
}
