using UnityEditor;
using UnityEngine;

namespace GPUInstancer
{
    [CustomEditor(typeof(GPUInstancerPrefab)), CanEditMultipleObjects]
    public class GPUInstancerPrefabEditor : Editor
    {
        private GPUInstancerPrefab[] _prefabScripts;

        protected void OnEnable()
        {
            Object[] monoObjects = targets;
            _prefabScripts = new GPUInstancerPrefab[monoObjects.Length];
            for (int i = 0; i < monoObjects.Length; i++)
            {
                _prefabScripts[i] = monoObjects[i] as GPUInstancerPrefab;
            }
        }

        public override void OnInspectorGUI()
        {
            if (_prefabScripts != null)
            {

                if (_prefabScripts.Length >= 1 && _prefabScripts[0] != null && _prefabScripts[0].prefabPrototype != null)
                {
                    bool isPrefab = _prefabScripts[0].prefabPrototype.prefabObject == _prefabScripts[0].gameObject;

                    if (_prefabScripts.Length == 1)
                    {
                        EditorGUI.BeginDisabledGroup(true);
                        EditorGUILayout.ObjectField(GPUInstancerEditorConstants.TEXT_prototypeSO, _prefabScripts[0].prefabPrototype, typeof(GPUInstancerPrefabPrototype), false);
                        EditorGUI.EndDisabledGroup();

                        if (!isPrefab)
                        {
                            if (Application.isPlaying)
                            {

                                GPUInstancerEditorConstants.DrawCustomLabel(GPUInstancerEditorConstants.TEXT_prefabInstancingNone, GPUInstancerEditorConstants.Styles.boldLabel);
                            }
                        }
                    }

                    if (isPrefab && !Application.isPlaying)
                    {


                        EditorGUILayout.BeginHorizontal();
                        if (_prefabScripts[0].prefabPrototype.meshRenderersDisabled)
                        {
                            GPUInstancerEditorConstants.DrawColoredButton(GPUInstancerEditorConstants.Contents.enableMeshRenderers, GPUInstancerEditorConstants.Colors.green, Color.white, FontStyle.Bold, Rect.zero,
                                () =>
                                {
                                    foreach (GPUInstancerPrefab prefabScript in _prefabScripts)
                                    {
                                        if (prefabScript != null && prefabScript.prefabPrototype != null)
                                        {
                                            GPUInstancerPrefabManagerEditor.SetRenderersEnabled(prefabScript.prefabPrototype, true);
                                        }
                                    }
                                });
                            //_prefabScripts[0].prefabPrototype.meshRenderersDisabledSimulation = EditorGUILayout.Toggle(GPUInstancerEditorConstants.TEXT_disableMeshRenderersSimulation, _prefabScripts[0].prefabPrototype.meshRenderersDisabledSimulation);
                        }

                        EditorGUILayout.EndHorizontal();
                    }
                }
            }
        }


    }
}