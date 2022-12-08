using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using Sirenix.OdinInspector;
#if UNITY_EDITOR
using Sirenix.OdinInspector.Editor;
using Sirenix.Utilities.Editor;
using UnityEditor;
#endif


[CreateAssetMenu(menuName = "游戏系统/SkyAssetOpt")]
public class SkyAssetOpt : ScriptableObject
{
    [LabelText("时间"), Range(0, 24)]
    public float Hour = 12.0f;
    //
    [FoldoutGroup("大气")]
    [FoldoutGroup("大气/散射"), LabelText("瑞利散射系数"), Range(0, 100)]
    public float RayleighMultiplier = 1;
    [FoldoutGroup("大气/散射"), LabelText("米氏散射系数"), Range(0, 10)]
    public float MieMultiplier = 1;
    // [FoldoutGroup("大气/散射"), LabelText("米氏散射 G"), Range(0, 0.999f)]
    // public float Directionality = 0.7f;
    [FoldoutGroup("大气/散射"), LabelText("曲线"), Range(0, 5)]
    public float Contrast = 1;
    [FoldoutGroup("大气/散射"), LabelText("强度"), Range(0, 5)]
    public float Brightness = 1;

    //
    [FoldoutGroup("大气/白天"), LabelText("白天天空颜色")]
    public Color DaySkyColor = Color.white;
    [FoldoutGroup("大气/白天"), LabelText("白天底部颜色")]
    public Color DayGroundColor = Color.grey;
    [FoldoutGroup("大气/白天"), LabelText("太阳光晕大小"), Range(1, 10)]
    public float SunHaloSize = 1;
    [FoldoutGroup("大气/白天"), LabelText("太阳颜色"), ColorUsageAttribute(false, true)]
    public Color SunColor = Color.white;
    [FoldoutGroup("大气/白天"), LabelText("太阳本体大小"), Range(0, 1)]
    public float SunSize = 1;
    // 
    [FoldoutGroup("大气/晚上"), LabelText("晚上天空颜色")]
    public Color NightSkyColor = Color.black;
    [FoldoutGroup("大气/晚上"), LabelText("晚上底部颜色")]
    public Color NightGroundColor = Color.grey;
    [FoldoutGroup("大气/晚上"), LabelText("月亮光晕大小"), Range(0, 1)]
    public float MoonHaloSize = 1;
    [FoldoutGroup("大气/晚上"), LabelText("月亮光晕颜色"), ColorUsageAttribute(false, true)]
    public Color MoonHaloColor = Color.white;
    [FoldoutGroup("大气/晚上"), LabelText("月亮本体颜色"), ColorUsageAttribute(false, true)]
    public Color MoonColor = Color.white;
    [FoldoutGroup("大气/晚上"), LabelText("月亮本体大小"), Range(0.1f, 1)]
    public float MoonSize = 1;

    //
    [FoldoutGroup("云"), LabelText("风角度"), Range(0, 360)]
    public float CloudWindDegrees = 0;
    [FoldoutGroup("云"), LabelText("风速度")]
    public float CloudWindSpeed = 0;
    [FoldoutGroup("云"), LabelText("白天云颜色")]
    public Color CloudDayColor = Color.white;
    [FoldoutGroup("云"), LabelText("晚上云颜色")]
    public Color CloudNightColor = Color.white;
    [FoldoutGroup("云"), LabelText("天空颜色和云颜色渐变"), Range(0, 1)]
    public float CloudColoring = 1;
    [FoldoutGroup("云"), LabelText("(特殊) 放大天空颜色"), Range(0, 10)]
    public float CloudSkyColorIntensity = 1;
    [FoldoutGroup("云"), LabelText("云透射强度"), Range(0, 10)]
    public float CloudScattering = 1;
    [FoldoutGroup("云"), LabelText("云整体强度"), Range(0, 10)]
    public float CloudBrightness = 1;
    
    [FoldoutGroup("云"), LabelText("云半透"), Range(0, 1)]
    public float CloudOpacity = 1;
    [FoldoutGroup("云"), LabelText("云大小"), Range(0, 5)]
    public float CloudSize = 0.5f;
    [FoldoutGroup("云"), LabelText("云密度"), Range(0, 1)]
    public float CloudCoverage = 0.5f;
    [FoldoutGroup("云"), LabelText("云厚度"), Range(0, 1)]
    public float CloudDensity = 0.5f;
    [FoldoutGroup("云"), LabelText("云暗部强度"), Range(0, 1)]
    public float CloudAttenuation = 0.5f;
    [FoldoutGroup("云"), LabelText("透射区域暗部强度"), Range(0, 1)]
    public float CloudSaturation = 0.5f;
    [FoldoutGroup("云"), LabelText("高度裁切"), Range(0, 1)]
    public float CloudClip = 0.08f;

    //
    [FoldoutGroup("星星"), LabelText("星星亮度"), Range(0, 10)]
    public float StarBrightness = 0;
    [FoldoutGroup("星星"), LabelText("星星大小"), Range(0, 10)]
    public float StarSize = 0;
}
