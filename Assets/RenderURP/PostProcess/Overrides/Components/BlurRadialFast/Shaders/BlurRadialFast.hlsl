#ifndef BLURRADIALFAST_INCLUDED
#define BLURRADIALFAST_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"

TEXTURE2D(_SourceTex);

half4 _Params;

#define _Intensity  _Params.x
#define _Center     _Params.yz

half4 FragBlurRadialFast(Varyings input) : SV_Target
{
    float2 uv = input.uv - _Center;

    float4 color = 0;

    [unroll(8)]
    for(int i = 0; i < 8; i ++)
    {
        float scale = 1.0f + float(i) * _Intensity * 0.15f;
        color += SAMPLE_TEXTURE2D(_SourceTex, sampler_LinearClamp, uv * scale + _Center);
    }
    color *= 0.125f;

    return color;
}

#endif // BLURRADIALFAST_INCLUDED
