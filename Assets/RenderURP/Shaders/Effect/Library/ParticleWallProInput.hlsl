#ifndef PARTICLEWALLPRO_INPUT_INCLUDED
#define PARTICLEWALLPRO_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

// 不支持SRP batch TODO ParticlesInstancing
half4   _Color;
half    _Intensity;
float4  _GlobalTiling;

TEXTURE2D(_NormalTex);
SAMPLER(sampler_NormalTex);

float4  _NormalTex_ST;
half    _NormalScale;
half    _UseGlobalTiling_N;
half    _RefractionDistance;

#if _F_DETIALTEX_1_ON
    TEXTURE2D(_DetialTex_1);
    SAMPLER(sampler_DetialTex_1);

    float4  _DetialTex_1_ST;
    half    _UseScreenUV_1;
    half    _UseGlobalTiling_1;
    half    _UseAdd_1;
#endif

#if _F_DETIALTEX_2_ON
    TEXTURE2D(_DetialTex_2);
    SAMPLER(sampler_DetialTex_2);

    float4  _DetialTex_2_ST;
    half    _UseScreenUV_2;
    half    _UseGlobalTiling_2;
    half    _UseAdd_2;
#endif

#if _F_DETIALTEX_3_ON
    TEXTURE2D(_DetialTex_3);
    SAMPLER(sampler_DetialTex_3);

    float4  _DetialTex_3_ST;
    half    _UseScreenUV_3;
    half    _UseGlobalTiling_3;
    half    _UseAdd_3;
#endif

#if _F_DETIALTEX_4_ON
    TEXTURE2D(_DetialTex_4);
    SAMPLER(sampler_DetialTex_4);

    float4  _DetialTex_4_ST;
    half    _UseScreenUV_4;
    half    _UseGlobalTiling_4;
    half    _UseAdd_4;
#endif

#if _F_FADE_ON
    TEXTURE2D(_FadeTex);
    SAMPLER(sampler_FadeTex);

    float4  _FadeTex_ST;
    half    _FadeIntensity;
#endif

// dissolve
#if _F_DISSOLVE_ON
    TEXTURE2D(_DissolveTex);
    SAMPLER(sampler_DissolveTex);

    float4  _DissolveTex_ST;
    half    _UseGlobalTiling_D;
    half    _DissolveThreshold;

    TEXTURE2D(_DissolveMaskTex_1);
    SAMPLER(sampler_DissolveMaskTex_1);
    TEXTURE2D(_DissolveMaskTex_2);
    SAMPLER(sampler_DissolveMaskTex_2);

    float4  _DissolveMaskTex_1_ST;
    float4  _DissolveMaskTex_2_ST;
    half    _DissolveMaskBlend;
#endif

TEXTURE2D(_GrabTexture);
SAMPLER(sampler_GrabTexture);

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

// ---------------------
half3x3 GetTangentToWorld(float3 normalWS, float4 tangentWS)
{
    float sgn = tangentWS.w;      // should be either +1 or -1
    float3 bitangent = sgn * cross(normalWS.xyz, tangentWS.xyz);
    half3x3 tangentToWorld = half3x3(tangentWS.xyz, bitangent.xyz, normalWS.xyz);

    return tangentToWorld;
}

void GetNormal(float2 uv, float3x3 tangentToWorld, float3 scale, inout half3 normalTS, inout half3 normalWS)
{
    float4 normalTex = GetDetailTex(uv, float2(0, 0), 
                    TEXTURE2D_ARGS(_NormalTex, sampler_NormalTex), 
                    0, _UseGlobalTiling_N, _NormalTex_ST, scale);

    normalTS = UnpackNormalScale(normalTex, _NormalScale);
    normalWS = NormalizeNormalPerPixel(TransformTangentToWorld(normalTS, tangentToWorld));
}

#if _F_DISSOLVE_ON
    void ClipByDissolve(float2 uv, float3 scale)
    {
        float4 dissolve = GetDetailTex(uv, float2(0, 0), 
                        TEXTURE2D_ARGS(_DissolveTex, sampler_DissolveTex), 
                        0, _UseGlobalTiling_D, _DissolveTex_ST, scale);

        float4 dissolveMask1 = GetDetailTex(uv, float2(0, 0), 
                    TEXTURE2D_ARGS(_DissolveMaskTex_1, sampler_DissolveMaskTex_1), 
                    0, 0, _DissolveMaskTex_1_ST, scale);

        float4 dissolveMask2 = GetDetailTex(uv, float2(0, 0), 
                    TEXTURE2D_ARGS(_DissolveMaskTex_2, sampler_DissolveMaskTex_2), 
                    0, 0, _DissolveMaskTex_2_ST, scale);

        half dissolveMask = lerp(dissolveMask1.r, dissolveMask2.r, _DissolveMaskBlend);

        clip(dissolveMask + dissolve.r + _DissolveThreshold - 1);
    }
#endif

float3 GetRefractColor(float3 positionWS, float3 viewDirWS, float3 normalWS)
{
    // IOR : 1.3
    float3 refractDir = refract(-viewDirWS, normalWS, 1.3);
    float3 refractPositionWS = positionWS + refractDir * _RefractionDistance;
    float4 refractPositionCS = TransformWorldToHClip(refractPositionWS);
    float4 refractPositionNDC = ComputeScreenPos(refractPositionCS);
    float2 refractScreenUV = GetScreenUV(refractPositionNDC);
    half4 refractColor = SAMPLE_TEXTURE2D(_GrabTexture, sampler_GrabTexture, refractScreenUV);

    return refractColor.rgb;
}

#endif // PARTICLEWALLPRO_INPUT_INCLUDED
