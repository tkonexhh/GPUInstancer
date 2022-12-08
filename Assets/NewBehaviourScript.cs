using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class NewBehaviourScript : MonoBehaviour
{
    public Text text = null;

    private int _FrameCounter = 0;
    private float _TimeCounter = 0f;
    private float _LastFramerate = 0; //平均帧数
    private float _RealFramerate = 0; //实时帧数
    public float RefreshTime = 0.2f;

    void Awake()
    {
        Screen.SetResolution(1280, 720, Screen.fullScreenMode);
    }
    // Start is called before the first frame update
    void Start()
    {

    }

    // Update is called once per frame
    void Update()
    {
        if (_TimeCounter < RefreshTime)
        {
            _TimeCounter += Time.unscaledDeltaTime;
            ++_FrameCounter;
        }
        else
        {
            _LastFramerate = (float)_FrameCounter / _TimeCounter;
            _RealFramerate = 1f / Time.unscaledDeltaTime;
            _FrameCounter = 0;
            _TimeCounter = 0f;

            //游戏帧数
            text.text = _LastFramerate.ToString(); ;
        }

    }
}
