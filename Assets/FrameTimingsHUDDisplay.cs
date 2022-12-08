
using System; 
using UnityEngine; 
using Unity.Profiling; 
public class FrameTimingsHUDDisplay : MonoBehaviour 
{ 
    GUIStyle m_Style; 
    void Awake() 
    { 
        m_Style = new GUIStyle(); 
        m_Style.fontSize = 15; 
        m_Style.normal.textColor = Color.white; 
    } 
    void OnGUI()
    { 

        FrameTimingManager.CaptureFrameTimings();
        var result = FrameTimingManager.GetGpuTimerFrequency();
        Debug.LogFormat("result: {0}", result); //logs 0
    }
}


