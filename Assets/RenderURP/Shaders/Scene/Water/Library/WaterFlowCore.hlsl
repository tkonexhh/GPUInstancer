#ifndef WATERFLOW_CORE_INCLUDED
#define WATERFLOW_CORE_INCLUDED

#include "WaterPass.hlsl"

// -----------------------------------------------------------
// Fragment
half4 WaterFlowFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);

    // V
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);

    // light / shadow没有使用
    Light mainLight = GetLight(input);

    // 法线
    half3x3 tangentToWorld = GetTangentToWorld(input);
    half3 normalTS, normalWS;
    GetNormal(input.uv, tangentToWorld, normalTS, normalWS);

    // -----------------------------------------------------------------------------------
    // 折射
    half3 refractColor = GetGrabColor(input.positionNDC, normalTS);

    // TODO 可能不需要
    // specular
    half3 specularColor = GetWaterSpecular(normalWS, viewDirWS, mainLight.direction, mainLight.color,
                         _SpecularRoughness, _SpecularColor.rgb, _SpecularIntensity);

    //  surface color
    half3 surfaceColor = refractColor + specularColor;

    // 反射
    half3 reflectColor = GetReflectionCustom(viewDirWS, normalWS);

    // fresnel
    half fresnelTerm = GetWaterFresnelTerm(normalWS, viewDirWS, WaterSurfaceF0, 5.0);

    // final color
	half3 finalColor = surfaceColor + reflectColor * fresnelTerm;

    half alpha = GetMask(input.uv);

    return half4(finalColor, alpha);
}

#endif
