using System.Collections;
using System.Collections.Generic;
using UnityEngine;



public static class PlatformHelper
{
    public static bool IsEditor()
    {
#if UNITY_EDITOR
        return true;
#endif
        return false;
    }

    public static bool IsAndroid()
    {
#if UNITY_ANDROID
            return true;
#endif
        return false;
    }

    public static bool IsMobile()
    {
#if UNITY_ANDROID
            return true;
#endif

#if UNITY_IOS
            return true;
#endif
        return false;
    }
}

