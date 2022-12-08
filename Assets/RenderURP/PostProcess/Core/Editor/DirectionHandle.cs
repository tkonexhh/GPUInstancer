using System.Linq;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using Inutan.PostProcessing;
using UnityEngine;
using System;
using System.Collections.Generic;
using System.Reflection;
using UnityEngine.Assertions;

namespace UnityEditor.Rendering
{
    [VolumeParameterDrawer(typeof(Inutan.PostProcessing.DirectionParameter))]
    sealed class DirectionParameterDrawer : VolumeParameterDrawer
    {
        public override bool OnGUI(SerializedDataParameter parameter, GUIContent title)
        {
            var value = parameter.value;

            if (value.propertyType != SerializedPropertyType.Vector4)
                return false;

            bool showHandle = value.vector4Value.w > 0;
            GUI.color = (showHandle && parameter.overrideState.boolValue) ? Color.green : Color.white;

            float w = EditorGUILayout.Toggle(title, showHandle) ? 1f : -1f;
            Vector3 vec = EditorGUILayout.Vector3Field(GUIContent.none, new Vector3(value.vector4Value.x, value.vector4Value.y, value.vector4Value.z));
            value.vector4Value = new Vector4(vec.x, vec.y, vec.z, w);

            GUI.color = Color.white;

            return true;
        }
    }
}

namespace UnityEditor.Rendering.Universal
{
    public interface IDirectionHandle
    {
        public SerializedDataParameter UnpackPublic(SerializedProperty property);
    }
    public class VolumeComponentSubEditor : VolumeComponentEditor, IDirectionHandle
    {
        public SerializedDataParameter UnpackPublic(SerializedProperty property)
        {
            return Unpack(property);
        }

        DirectionHandleMgr m_HandleMgr;
        public override void OnEnable()
        {
            base.OnEnable();
            m_HandleMgr = new DirectionHandleMgr(this);
        }

        public override void OnInspectorGUI()
        {
            base.OnInspectorGUI();
            m_HandleMgr.Update();
        }
    }

    public class DirectionHandleMgr
    {
        List<DirectionHandle> m_Handle = new List<DirectionHandle>();

        public DirectionHandleMgr(VolumeComponentSubEditor volumeComp)
        {
            m_Handle.Clear();

            var fields = volumeComp.target.GetType()
                .GetFields(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);

            foreach (var field in fields)
            {
                if (field.FieldType.IsSubclassOf(typeof(VolumeParameter)))
                {
                    if ((field.GetCustomAttributes(typeof(Inutan.PostProcessing.DirectHandleAttribute), false).Length > 0))
                    {
                        var t = volumeComp.serializedObject.FindProperty(field.Name);
                        var k = (volumeComp as IDirectionHandle).UnpackPublic(t);
                        m_Handle.Add(new DirectionHandle(k, volumeComp.serializedObject));
                    }
                }
            }
        }

        public void Update()
        {
            foreach(var handle in m_Handle)
            {
                handle.Update();
            }
        }

    }
    public class DirectionHandle
    {
        bool m_IsEditor = false;
        bool m_IsStartEditor = true;
        GameObject m_SelectGameObj;
        Vector3 m_Position = Vector3.zero;
        Quaternion m_Rotation = Quaternion.identity;

        SerializedDataParameter m_Property;
        SerializedObject m_SerializedObject;
        public DirectionHandle(SerializedDataParameter property, SerializedObject serializedObject)
        {
            m_Property = property;
            m_SerializedObject = serializedObject;
        }

        private void CreateHandle(Vector3 value)
        {
            m_SelectGameObj = Selection.activeGameObject;

            Ray ray = SceneView.lastActiveSceneView.camera.ViewportPointToRay(new Vector3(0.5f,0.5f,0));
            m_Position = ray.origin + ray.direction * 10.0f;

            m_Rotation = Quaternion.Euler(value);
            
            SceneView.duringSceneGui += HandleDraw;
            SceneView.RepaintAll();

            m_IsStartEditor = false;
        }

        private void DeleteHandle()
        {
            m_SelectGameObj = null;
            SceneView.duringSceneGui -= HandleDraw;
            SceneView.RepaintAll();
            m_IsStartEditor = true;
        }

        private void HandleDraw(SceneView sceneView)
        {
            if (m_SelectGameObj == null || m_SelectGameObj != Selection.activeGameObject)
            {
                DeleteHandle();
                m_IsEditor = false;
                return;
            }
            m_Rotation = Handles.RotationHandle(m_Rotation, m_Position);

            Handles.color = Color.green;
            float size = HandleUtility.GetHandleSize(m_Position);
            Handles.ConeHandleCap(0, m_Position, m_Rotation.normalized, size, EventType.Repaint);

            m_Property.value.vector4Value = new Vector4(m_Rotation.eulerAngles.x, m_Rotation.eulerAngles.y, m_Rotation.eulerAngles.z, 1f);
            m_SerializedObject.ApplyModifiedProperties();
        }

        public void Update()
        {
            m_IsEditor = m_Property.overrideState.boolValue && m_Property.value.vector4Value.w > 0;

            if (m_IsEditor && m_IsStartEditor)
            {
                Vector4 var = m_Property.value.vector4Value;
                CreateHandle(new Vector3(var.x, var.y, var.z));
            }
            else if (!m_IsEditor && !m_IsStartEditor)
                DeleteHandle();
        }
    }
}
