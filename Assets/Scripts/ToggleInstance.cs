using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ToggleInstance : MonoBehaviour
{
    // Start is called before the first frame update
    void Start()
    {
        Application.targetFrameRate = 99999;
        Screen.sleepTimeout = SleepTimeout.NeverSleep;
    }
}
