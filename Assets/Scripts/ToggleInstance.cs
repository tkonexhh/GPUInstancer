using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ToggleInstance : MonoBehaviour
{
    // Start is called before the first frame update
    void Start()
    {
        // Screen.SetResolution(1280, 720, Screen.fullScreenMode);
        Application.targetFrameRate = 60;
        Screen.sleepTimeout = SleepTimeout.NeverSleep;
    }
}
