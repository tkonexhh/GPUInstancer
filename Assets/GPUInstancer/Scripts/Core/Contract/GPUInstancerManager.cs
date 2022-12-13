using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using System.Threading;
using Inutan;
#if UNITY_EDITOR
using UnityEditor;
#endif

namespace GPUInstancer
{
    public abstract class GPUInstancerManager : MonoBehaviour
    {
        public List<GPUInstancerPrototype> prototypeList;

        [NonSerialized]
        public List<GPUInstanceRenderer> runtimeDataList;


#if UNITY_EDITOR
        public List<GPUInstancerPrototype> selectedPrototypeList;

        public bool showSceneSettingsBox = true;
        public bool showPrototypeBox = true;
        public bool showAdvancedBox = false;
        public bool showHelpText = false;
        public bool showDebugBox = true;
        public bool showGlobalValuesBox = true;
        public bool showRegisteredPrefabsBox = true;
        public bool showPrototypesBox = true;
#endif


        [NonSerialized]
        public bool isInitialized = false;

#if UNITY_EDITOR 
        [NonSerialized]
        public PlayModeStateChange playModeState;
#endif
        [NonSerialized]
        public Dictionary<GPUInstancerPrototype, GPUInstanceRenderer> runtimeDataDictionary;

        #region MonoBehaviour Methods

        public virtual void OnEnable()
        {
            if (!Application.isPlaying)
                return;

            if (SystemInfo.supportsComputeShaders)
            {
                if (runtimeDataList == null || runtimeDataList.Count == 0)
                    InitializeRuntimeDataAndBuffers();
            }
        }

        public virtual void LateUpdate()
        {
            if (runtimeDataList == null)
                return;

            foreach (var runtimeData in runtimeDataList)
            {
                runtimeData.Render();
            }
        }

        public virtual void OnDisable() // could also be OnDestroy, but OnDestroy seems to be too late to prevent buffer leaks.
        {
            ClearInstancingData();
        }

        #endregion MonoBehaviour Methods

        #region Virtual Methods

        public virtual void ClearInstancingData()
        {
            GPUInstancerUtility.ReleaseInstanceBuffers(runtimeDataList);
            if (runtimeDataList != null)
                runtimeDataList.Clear();
            if (runtimeDataDictionary != null)
                runtimeDataDictionary.Clear();

            isInitialized = false;
        }

        public virtual void GeneratePrototypes(bool forceNew = false)
        {
            ClearInstancingData();

            if (forceNew || prototypeList == null)
                prototypeList = new List<GPUInstancerPrototype>();
            else
                prototypeList.RemoveAll(p => p == null);
        }

        public virtual void InitializeRuntimeDataAndBuffers(bool forceNew = true)
        {
            if (forceNew || !isInitialized)
            {

                GPUInstancerUtility.ReleaseInstanceBuffers(runtimeDataList);
                if (runtimeDataList != null)
                    runtimeDataList.Clear();
                else
                    runtimeDataList = new List<GPUInstanceRenderer>();

                if (runtimeDataDictionary != null)
                    runtimeDataDictionary.Clear();
                else
                    runtimeDataDictionary = new Dictionary<GPUInstancerPrototype, GPUInstanceRenderer>();

                if (prototypeList == null)
                    prototypeList = new List<GPUInstancerPrototype>();
            }
        }


        #endregion Virtual Methods
    }

}