using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using Inutan;
using GPUInstancer;

public class UI : MonoBehaviour
{
    public Slider slider;
    public Text valueText;
    public Button changeButton;
    public Text modeText;
    public Button leftModelButton;
    public Button rightModelButton;
    public Toggle cullingToggle;

    public GrassRenderer grassRenderer;
    public GPUInstancerPrefabManager gpuInstancerPrefabManager;

    public GameObject[] targets;
    public int index = 0;

    // Start is called before the first frame update
    void Start()
    {
        slider.onValueChanged.AddListener((v) =>
        {
            valueText.text = ((int)v).ToString();
        });

        valueText.text = ((int)slider.value).ToString();
        changeButton.onClick.AddListener(OnClickChange);
        leftModelButton.onClick.AddListener(OnClickLeft);
        rightModelButton.onClick.AddListener(OnClickRight);
        cullingToggle.onValueChanged.AddListener(OnCullChange);
        OnClickChange();
    }

    void OnClickChange()
    {
        grassRenderer.InitGameobject(targets[index], (int)slider.value);
        grassRenderer.gameObject.SetActive(false);

        if (gpuInstancerPrefabManager != null)
        {
            gpuInstancerPrefabManager.gameObject.SetActive(true);
            gpuInstancerPrefabManager.ClearRegisteredPrefabInstances();
            gpuInstancerPrefabManager.RegisterPrefabsInScene();
            gpuInstancerPrefabManager.InitializeRuntimeDataAndBuffers(true);
            gpuInstancerPrefabManager.gameObject.SetActive(false);
        }
        modeText.text = Mode.GameObject.ToString();
    }

    void OnClickLeft()
    {
        index--;
        if (index < 0)
        {
            index = targets.Length - 1;
        }
        OnClickChange();
    }

    void OnClickRight()
    {
        index++;
        if (index >= targets.Length)
        {
            index = 0;
        }
        OnClickChange();
    }

    void OnCullChange(bool value)
    {

    }

    public void ToGameObject()
    {
        grassRenderer.gameObject.SetActive(false);
        gpuInstancerPrefabManager?.gameObject.SetActive(false);

        modeText.text = Mode.GameObject.ToString();
    }

    public void ToIndirect()
    {

        gpuInstancerPrefabManager?.gameObject.SetActive(false);
        grassRenderer.gameObject.SetActive(true);

        modeText.text = Mode.Indirect.ToString();
    }

    public void ToGPUI()
    {
        grassRenderer.gameObject.SetActive(false);
        gpuInstancerPrefabManager?.gameObject.SetActive(true);
        modeText.text = "GPUI";
    }
}
