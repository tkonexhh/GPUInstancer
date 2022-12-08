using System.Collections;
using System.Collections.Generic;
using Sirenix.OdinInspector;
using UnityEngine;
using UnityEngine.UI;

[ExecuteInEditMode]
public class ScreenCaptureBlur : MonoBehaviour
{
    //────────────────────────────────────────────────────────────────────────────────────────────────────── 参数配置
    [Title("图片目标")]
    public RawImage TargetRawImage;

    //────────────────────────────────────────────────────────────────────────────────────────────────────── 截取图片
    [HorizontalGroup][Button("截取原始图片", ButtonSizes.Large)]
    public void DoCaptureOriginalTexture()
    {
        StartCoroutine(CaptureBlur(false));
    }

    [HorizontalGroup][Button("截取模糊图片", ButtonSizes.Large)]
    public void DoCaptureBlurTexture()
    {
        StartCoroutine(CaptureBlur(true));
    }

    //────────────────────────────────────────────────────────────────────────────────────────────────────── 清除图片
    [HorizontalGroup][Button("清除图片", ButtonSizes.Large)]
    public void Clear()
    {
        if (_RenderTextureBuffer != null)
        {
            RenderTexture.ReleaseTemporary(_RenderTextureBuffer);
            _RenderTextureBuffer = null;
        }
        RefreshTexture(null);
    }

    IEnumerator CaptureBlur(bool blur)
    {
        // https://docs.unity3d.com/ScriptReference/WaitForEndOfFrame.html
        yield return new WaitForEndOfFrame();

        Clear(); //截图前先清理缓存图片
        RenderTexture rt = DoCapture();
        rt = DoFlip(rt);
        rt = blur ? DoBlur(rt) : rt;
        RefreshTexture(rt);
    }

    //────────────────────────────────────────────────────────────────────────────────────────────────────── 刷新图片
    private void RefreshTexture(RenderTexture rt)
    {
        if (TargetRawImage != null)
        {
            TargetRawImage.texture = rt;

            var color = TargetRawImage.color;
            color.a = TargetRawImage.texture == null ? 0f : 1f;
            TargetRawImage.color = color;
        }
    }

    //────────────────────────────────────────────────────────────────────────────────────────────────────── 相机截图
    private RenderTexture _RenderTextureBuffer;
    private RenderTexture DoCapture()
    {
        if (_RenderTextureBuffer == null)
            _RenderTextureBuffer = RenderTexture.GetTemporary(Screen.width, Screen.height, 0);

        // 由于UGUI overlay模式没法获取到RT 只能整体截屏 (或者用 ReadPixels)
        // 这个接口有flip y的问题 shader中有对应处理
        // 另外如果用 Texture2D.ReadPixels 的方式获取的是Texture2D 不知道底层是否被拿到了CPU中 如果是就太浪费了
        ScreenCapture.CaptureScreenshotIntoRenderTexture(_RenderTextureBuffer);

        return _RenderTextureBuffer;
    }

    private string ShaderName = "Hidden/PostProcessing/Inutan/ScreenCaptureBlur";
    private int _Offset = Shader.PropertyToID("_Offset");

    private RenderTexture[] m_Pyramid_Down;
    private RenderTexture[] m_Pyramid_Up;

    [Title("模糊")]
    public Shader BlurShader;
    private Material BlurMaterial;

    // 几个用于调节参数的中间变量 (TODO 遗留)
    public static int ChangeValue;
    public static float ChangeValue2;
    public static int ChangeValue3;

    // 降采样次数
    [Range(1, 6), Tooltip("[降采样次数]向下采样的次数。此值越大,则采样间隔越大,需要处理的像素点越少,运行速度越快。")]
    public int DownSampleNum = 3;
    // 模糊扩散度
    [Range(0f, 20f), Tooltip("[模糊扩散度]进行高斯模糊时,相邻像素点的间隔。此值越大相邻像素间隔越远,图像越模糊。但过大的值会导致失真。")]
    public float BlurSpreadSize = 8f;
    // 迭代次数
    [Range(1, 8), Tooltip("[迭代次数]此值越大,则模糊操作的迭代次数越多,模糊效果越好。")]
    public int BlurIterations = 2;

    private Material material
    {
        get
        {
            if (BlurMaterial == null)
            {
                BlurMaterial = new Material(BlurShader);
                BlurMaterial.hideFlags = HideFlags.HideAndDontSave;
            }
            return BlurMaterial;
        }
    }

    // Dual Filtering 迭代次数增加到一定程度，采样的像素量级基本不再变化
    // https://community.arm.com/cfs-file/__key/communityserver-blogs-components-weblogfiles/00-00-00-20-66/siggraph2015_2D00_mmg_2D00_marius_2D00_notes.pdf
    private RenderTexture DoBlur(RenderTexture sourceTexture)
    {
        if (BlurShader == null)
            return sourceTexture;

        int tw = (int) (sourceTexture.width / DownSampleNum);
        int th = (int) (sourceTexture.height / DownSampleNum);

        float widthMod = 1f / (1f * (1 << DownSampleNum));
        material.SetFloat(_Offset, BlurSpreadSize * widthMod);

        m_Pyramid_Down = new RenderTexture[BlurIterations];
        m_Pyramid_Up = new RenderTexture[BlurIterations];

        RenderTexture lastDown = sourceTexture;
        for (int i = 0; i < BlurIterations; i++)
        {
            RenderTexture mipDown = RenderTexture.GetTemporary(tw, th, 0, sourceTexture.format);
            RenderTexture mipUp = RenderTexture.GetTemporary(tw, th, 0, sourceTexture.format);
            m_Pyramid_Down[i] = mipDown;
            m_Pyramid_Up[i] = mipUp;

            Graphics.Blit(lastDown, mipDown, material, 0);

            lastDown = mipDown;
            tw = Mathf.Max(tw / 2, 1);
            th = Mathf.Max(th / 2, 1);
        }

        // Upsample
        RenderTexture lastUp = m_Pyramid_Down[BlurIterations - 1];
        for (int i = BlurIterations - 2; i >= 0; i--)
        {
            RenderTexture mipUp = m_Pyramid_Up[i];

            Graphics.Blit(lastUp, mipUp, material, 1);
            lastUp = mipUp;
        }

        Graphics.Blit(lastUp, sourceTexture, material, 1);

        // Cleanup
        for (int i = 0; i < BlurIterations; i++)
        {
            RenderTexture.ReleaseTemporary(m_Pyramid_Down[i]);
            RenderTexture.ReleaseTemporary(m_Pyramid_Up[i]);
        }
        m_Pyramid_Down = null;
        m_Pyramid_Up = null;

        return sourceTexture;
    }

    // 处理对ScreenCapture的y翻转
    private RenderTexture DoFlip(RenderTexture sourceTexture)
    {
        if (BlurShader == null)
            return sourceTexture;

        RenderTexture temp = RenderTexture.GetTemporary(Screen.width, Screen.height, 0, sourceTexture.format);
        Graphics.Blit(sourceTexture, temp, material, 2);

        RenderTexture.ReleaseTemporary(sourceTexture);
        sourceTexture = temp;

        return sourceTexture;
    }

    private void OnDestroy()
    {
        Clear();
        if (BlurMaterial != null)
        {
            DestroyImmediate(BlurMaterial);
            BlurMaterial = null;
        }
    }

    #if UNITY_EDITOR
    private void Start()
    {
        ChangeValue = DownSampleNum;
        ChangeValue2 = BlurSpreadSize;
        ChangeValue3 = BlurIterations;

        if (BlurShader == null) BlurShader = Shader.Find(ShaderName);
    }

    private void OnValidate()
    {
        if (TargetRawImage == null) TryGetComponent<RawImage>(out TargetRawImage);
        RefreshTexture(null);

        ChangeValue = DownSampleNum;
        ChangeValue2 = BlurSpreadSize;
        ChangeValue3 = BlurIterations;
    }

    private void Update()
    {
        if (Application.isPlaying)
        {
            DownSampleNum = ChangeValue;
            BlurSpreadSize = ChangeValue2;
            BlurIterations = ChangeValue3;
        }
        else
        {
            if (BlurShader == null) BlurShader = Shader.Find(ShaderName);
        }
    }
    #endif
}