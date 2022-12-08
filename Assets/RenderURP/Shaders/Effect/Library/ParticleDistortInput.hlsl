#ifndef PARTICLEDISTORT_INPUT_INCLUDED
#define PARTICLEDISTORT_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

// 不支持SRP batch TODO ParticlesInstancing

TEXTURE2D(_DistortTex);
SAMPLER(sampler_DistortTex);

float4      _DistortTex_ST;
half        _DistortIntensity;
half        _DistortUVSpeedX;
half        _DistortUVSpeedY;
half        _UseCustomData;

TEXTURE2D(_GrabTexture);
SAMPLER(sampler_GrabTexture);

//--------------------------------------------------------------------------------
half3 GetNormalTS(float2 uv, float4 color, float4 customData1)
{
    float2 distortUV = TRANSFORM_TEX(uv, _DistortTex) + frac(float2(_DistortUVSpeedX, _DistortUVSpeedY) * _Time.y);
    half4 distortTex = SAMPLE_TEXTURE2D(_DistortTex, sampler_DistortTex, distortUV);

    half intensity = _DistortIntensity * lerp(1, customData1.x, _UseCustomData) * color.a;
    #if _USECUSTOMTEX_ON
        half3 normalTS = distortTex.rgb * distortTex.a * intensity;
    #else
        half3 normalTS = UnpackNormalScale(distortTex, intensity);
    #endif
    return normalTS;
}
    
half4 GetGrabColor(float2 screenUV)
{
    return SAMPLE_TEXTURE2D(_GrabTexture, sampler_GrabTexture, screenUV);
}

half4 GetGrabColor(float4 positionNDC, half3 normalTS)
{
    #if _USENORMALIZEDNDC_ON
        float2 screenUV = (positionNDC.xy + normalTS.xy) * rcp(positionNDC.w);
    #else
        float2 screenUV = (positionNDC.xy * rcp(positionNDC.w) + normalTS.xy);
    #endif
    return GetGrabColor(screenUV);
}


#endif // PARTICLEDISTORT_INPUT_INCLUDED
