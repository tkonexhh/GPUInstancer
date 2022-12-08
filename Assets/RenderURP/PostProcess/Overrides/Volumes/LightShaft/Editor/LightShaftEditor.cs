using System.Linq;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using Inutan.PostProcessing;
using UnityEngine;
using System.Reflection;

namespace UnityEditor.Rendering.Universal
{
    [VolumeComponentEditor(typeof(LightShaft))]
    sealed class LightShaftEditor : VolumeComponentSubEditor {}
}
