using System.Collections.Generic;
using UnityEngine;

namespace GPUInstancer
{
    public class GPUInstancerGUIInfo : MonoBehaviour
    {
        public bool showRenderedAmount;
        public bool showPrototypesSeparate;
        public bool showPrefabManagers = true;

        private static List<GPUInstancerRuntimeData> singlesList = new List<GPUInstancerRuntimeData>() { null };

        private void OnGUI()
        {
            if (GPUInstancerManager.activeManagerList != null)
            {
                if (GPUInstancerManager.showRenderedAmount != showRenderedAmount)
                    GPUInstancerManager.showRenderedAmount = showRenderedAmount;

                int startPos = 0;
                int enabledCount = 0;
                string name = "";

                Color oldColor = GUI.color;
                GUI.color = Color.red;

                if (showRenderedAmount)
                {
                    GUI.Label(new Rect(10, Screen.height - 30, 700, 30),
                    "SHOWING RENDERED AMOUNTS! FRAME RATE WILL DROP!");
                    startPos += 30;
                }

                foreach (GPUInstancerManager manager in GPUInstancerManager.activeManagerList)
                {
                    enabledCount = 0;
                    if (manager is GPUInstancerPrefabManager)
                    {
                        if (!showPrefabManagers)
                            continue;
                        name = "prefab";
                        enabledCount = ((GPUInstancerPrefabManager)manager).GetEnabledPrefabCount();
                    }

                    if (showPrototypesSeparate)
                    {
                        foreach (GPUInstancerRuntimeData rd in manager.runtimeDataList)
                        {
                            singlesList[0] = rd;
                            DebugOnManagerGUI(rd.prototype.ToString(), singlesList, showRenderedAmount, startPos, enabledCount);
                            startPos += GPUInstancerConstants.DEBUG_INFO_SIZE;
                        }
                    }
                    else
                    {
                        DebugOnManagerGUI(name, manager.runtimeDataList, showRenderedAmount, startPos, enabledCount);
                        startPos += GPUInstancerConstants.DEBUG_INFO_SIZE;
                    }
                }

                GUI.color = oldColor;
            }
        }

        private void OnDisable()
        {
            if (showRenderedAmount)
                GPUInstancerManager.showRenderedAmount = false;
        }

        private static void DebugOnManagerGUI(string name, List<GPUInstancerRuntimeData> runtimeDataList, bool showRenderedAmount, int startPos, int enabledCount)
        {
            if (runtimeDataList == null || runtimeDataList.Count == 0)
            {
                GUI.Label(new Rect(10, Screen.height - startPos - 25, 700, 30),
                    "There are no " + name + " instance prototypes to render!");
                return;
            }

            int totalInstanceCount = 0;
            for (int i = 0; i < runtimeDataList.Count; i++)
            {
                totalInstanceCount += runtimeDataList[i].instanceCount;
            }

            // show instance counts
            GUI.Label(new Rect(10, Screen.height - startPos - 45, 700, 30),
                "Total " + name + " prototype count: " + runtimeDataList.Count);
            GUI.Label(new Rect(10, Screen.height - startPos - 25, 700, 30),
                "Total " + name + " instance count: " + totalInstanceCount);



            if (enabledCount > 0)
                GUI.Label(new Rect(10, Screen.height - startPos - 105, 700, 30),
                    "Instancing disabled " + name + " instance count: " + enabledCount);
        }

    }
}
