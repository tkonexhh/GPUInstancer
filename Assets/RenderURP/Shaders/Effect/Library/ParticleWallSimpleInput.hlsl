#ifndef PARTICLEWALLSIMPLE_INPUT_INCLUDED
#define PARTICLEWALLSIMPLE_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

// 不支持SRP batch TODO ParticlesInstancing
half4   _Color;
half    _Intensity;
float4  _GlobalTiling;

#if _F_DETIALTEX_1_ON
    TEXTURE2D(_DetialTex_1);
    SAMPLER(sampler_DetialTex_1);

    float4  _DetialTex_1_ST;
    half    _UseScreenUV_1;
    half    _UseGlobalTiling_1;
#endif

#if _F_DETIALTEX_2_ON
    TEXTURE2D(_DetialTex_2);
    SAMPLER(sampler_DetialTex_2);

    float4  _DetialTex_2_ST;
    half    _UseScreenUV_2;
    half    _UseGlobalTiling_2;
#endif

#if _F_DETIALTEX_3_ON
    TEXTURE2D(_DetialTex_3);
    SAMPLER(sampler_DetialTex_3);

    float4  _DetialTex_3_ST;
    half    _UseScreenUV_3;
    half    _UseGlobalTiling_3;
#endif

#if _F_DETIALTEX_4_ON
    TEXTURE2D(_DetialTex_4);
    SAMPLER(sampler_DetialTex_4);

    float4  _DetialTex_4_ST;
    half    _UseScreenUV_4;
    half    _UseGlobalTiling_4;
#endif

#if _F_DETIALTEX_5_ON
    TEXTURE2D(_DetialTex_5);
    SAMPLER(sampler_DetialTex_5);

    float4  _DetialTex_5_ST;
    half    _UseScreenUV_5;
    half    _UseGlobalTiling_5;
#endif

// dissolve
#if _F_DISSOLVE_ON
    TEXTURE2D(_DissolveTex);
    SAMPLER(sampler_DissolveTex);

    float4  _DissolveTex_ST;
    half    _UseGlobalTiling_D;
    half    _DissolveThreshold;
#endif

//--------------------------------------------------------------------------------

float2 GetScreenUV(float4 positionNDC)
{
    return positionNDC.xy * rcp(positionNDC.w);
}

half4 GetDetailTex(float2 uv, float2 screenUV, 
                TEXTURE2D_PARAM(tex, sampler_tex), 
                half useScreenUV, half useGlobalTiling, float4 st, float3 scale)
{
    #if _AUTOSCALEUV_ON
        float2 tiling = lerp(_GlobalTiling.xy * scale.xy, _GlobalTiling.xy, useScreenUV);
    #else
        float2 tiling = _GlobalTiling.xy;
    #endif

    uv = lerp(uv, screenUV, useScreenUV);
    uv = uv * st.xy * lerp(1, tiling, useGlobalTiling) + frac(_Time.y * st.zw);

    return SAMPLE_TEXTURE2D(tex, sampler_tex, uv);
}

float3 GetScale()
{
    return float3(length(GetObjectToWorldMatrix()._m00_m10_m20),
                    length(GetObjectToWorldMatrix()._m01_m11_m21),
                    length(GetObjectToWorldMatrix()._m02_m12_m22));
}
#endif // PARTICLEWALLSIMPLE_INPUT_INCLUDED
