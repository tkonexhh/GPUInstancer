#ifndef PARTICLEALL_INPUT_INCLUDED
#define PARTICLEALL_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

// 不支持SRP batch TODO ParticlesInstancing

TEXTURE2D(_MainTex);
SAMPLER(sampler_MainTex);

float4      _MainTex_ST;
half        _MainIntensity;
half4       _MainColor;
half        _UseCustomData;
half        _UseUV1;
half        _PreMultiAlpha;
half        _MainUVSpeedX;
half        _MainUVSpeedY;

#if _F_UVDISTORT_ON
    TEXTURE2D(_UVDistortTex);
    SAMPLER(sampler_UVDistortTex);

    float4      _UVDistortTex_ST;
    half        _UVDistortIntensity;
    half        _UVDistortSpeedX;
    half        _UVDistortSpeedY;

    half        _UseForMainTex;
    half        _UseForDissolveTex;
    half        _UseForMaskTex;
#endif

#if _F_VERTEXNOISE_ON
    TEXTURE2D(_VertexNoiseTex);
    SAMPLER(sampler_VertexNoiseTex);

    float4      _VertexNoiseTex_ST;
    half        _VertexNoiseIntensity;
    half        _VertexNoiseUVSpeedX;
    half        _VertexNoiseUVSpeedY;
#endif

#if _F_RIM_ON
    #if _F_RIMCOLOR_ON
        half4       _RimColor;
        half        _RimRange;
        half        _RimGradient;
    #endif
    #if _F_RIMFADE_ON
        half        _RimFadeRange;
        half        _RimFadeGradient;
        half        _RimFadePower;
    #endif
#endif

#if _F_DISSOLVE_ON
    TEXTURE2D(_DissolveTex);
    SAMPLER(sampler_DissolveTex);

    float4      _DissolveTex_ST;
    half        _DissolveInvert;
    half        _DissolveUseCustomData;
    half        _DissolveThreshold;
    half        _DissolveSpread;
    half        _DissolveEdgeWidth;
    half4       _DissolveEdgeColor;
    half        _DissolveUVSpeedX;
    half        _DissolveUVSpeedY;

    half        _DissolveMultiUseCustomData;
    half        _DissolveMulti;
    half        _DissolveChannel;
#endif

#if _F_MASK_ON
    #if _F_MASK_1_ON
        TEXTURE2D(_MaskTex_1);
        SAMPLER(sampler_MaskTex_1);

        half        _Mask_1_Channel;
        half        _Mask_1_Invert;
        half        _Mask_1_Power;
        half        _Mask_1_Target;
        half        _Mask_1_UseCustomData;
        half4       _Mask_1_Tiling;
        half        _Mask_1_UVSpeedX;
        half        _Mask_1_UVSpeedY;
    #endif
    #if _F_MASK_2_ON
        TEXTURE2D(_MaskTex_2);
        SAMPLER(sampler_MaskTex_2);

        half        _Mask_2_Channel;
        half        _Mask_2_Invert;
        half        _Mask_2_Power;
        half        _Mask_2_Target;
        half        _Mask_2_UseCustomData;
        half4       _Mask_2_Tiling;
        half        _Mask_2_UVSpeedX;
        half        _Mask_2_UVSpeedY;
    #endif
    #if _F_MASK_3_ON
        TEXTURE2D(_MaskTex_3);
        SAMPLER(sampler_MaskTex_3);

        half        _Mask_3_Channel;
        half        _Mask_3_Invert;
        half        _Mask_3_Power;
        half        _Mask_3_Target;
        half        _Mask_3_UseCustomData;
        half4       _Mask_3_Tiling;
        half        _Mask_3_UVSpeedX;
        half        _Mask_3_UVSpeedY;
    #endif
    #if _USEDISSOLVEMASK_ON
        TEXTURE2D(_MaskTex_d);
        SAMPLER(sampler_MaskTex_d);

        half        _Mask_d_Channel;
        half        _Mask_d_Invert;
        half        _Mask_d_Power;
        half        _Mask_d_UseCustomData;
        half4       _Mask_d_Tiling;
        half        _Mask_d_UVSpeedX;
        half        _Mask_d_UVSpeedY;
    #endif
#endif

#if _F_CONTACT_ON
    half4       _ContantColor;
    half        _ContactFade;
    half        _ContactMaxDistance;
    half        _ContactAlphaMode;
#endif
#if _F_SCREENMAP_ON
    TEXTURE2D(_ScreenMapTex);
    SAMPLER(sampler_ScreenMapTex);

    float4      _ScreenMapTex_ST;
    half4       _ScreenMapColor;
    half        _ScreenMapUVSpeedX;
    half        _ScreenMapUVSpeedY;
#endif

TEXTURE2D_X_FLOAT(_CameraDepthTexture);     SAMPLER(sampler_CameraDepthTexture);

//--------------------------------------------------------------------------------
float Warp(float input, float a, float b)
{
    input = saturate((input - a) / (b - a));
    return input;
}

float LinearToExp(float a, float b)
{
	return exp(- a / max(b, 1e-7f));
}

void DissolveFunc(half dissolveTex, half threshold, half spread, half edgeWidth, half4 edgeColor, inout half4 finalColor)
{
    spread = clamp(spread, 0.00001, 0.999999);
    threshold *= (1 + edgeWidth);

    half dissolve_1 = 2 - (threshold * (2 - spread) + dissolveTex);
    dissolve_1 = Warp(dissolve_1, spread, 1);

    half dissolve_2 = 2 - ((threshold - edgeWidth) * (2- spread) + dissolveTex);
    dissolve_2 = Warp(dissolve_2, spread, 1);

    finalColor.rgb = lerp(edgeColor.rgb, finalColor.rgb, dissolve_1);
    finalColor.a *= dissolve_2;
}

float2 GetScreenUV(float4 positionNDC)
{
    return positionNDC.xy * rcp(positionNDC.w);
}

#if _F_MASK_ON
    half GetMask(TEXTURE2D_PARAM(tex, sampler_tex), float2 uv, half4 tiling, half2 uvSpeed, 
                    half channel, half ifInvert, half power, half distortMaskUV)
    {
        float2 maskUV = uv * tiling.xy + tiling.zw + frac(uvSpeed * _Time.y);
        half4 mask = SAMPLE_TEXTURE2D(tex, sampler_tex, maskUV + distortMaskUV);
        half final = mask[(int)channel];
        final = pow(lerp(final, 1 - final, ifInvert), power);
        return final;
    }
#endif

#if _F_VERTEXNOISE_ON
    void GetVertexNoise(float2 uv, half3 normalOS, half4 vertexColor, inout float4 positionOS)
    {
        float2 vertexNoiseUV = TRANSFORM_TEX(uv, _VertexNoiseTex) + frac(float2(_VertexNoiseUVSpeedX, _VertexNoiseUVSpeedY) * _Time.y);
        float4 vertexNoise = SAMPLE_TEXTURE2D_LOD(_VertexNoiseTex, sampler_VertexNoiseTex, vertexNoiseUV, 0);
        vertexNoise *= _VertexNoiseIntensity * vertexColor.a;
        
        positionOS.xyz += normalOS * vertexNoise.xyz;
    }
#endif


#if _F_UVDISTORT_ON
    void GetDistortUVForUV(float2 uv, inout float2 mainDistortUV, inout float2 dissolveDistortUV, inout float2 maskDistortUV)
    {
        uv = TRANSFORM_TEX(uv, _UVDistortTex) + frac(float2(_UVDistortSpeedX, _UVDistortSpeedY) * _Time.y);
        float2 distortUV = SAMPLE_TEXTURE2D(_UVDistortTex, sampler_UVDistortTex, uv).xy;
        distortUV = (distortUV * 2 - 1) * _UVDistortIntensity;
        
        mainDistortUV = lerp(0, distortUV, _UseForMainTex);
        dissolveDistortUV = lerp(0, distortUV, _UseForDissolveTex);
        maskDistortUV = lerp(0, distortUV, _UseForMaskTex);
    }
#endif

half4 GetMainColor(float2 uv, float2 mainDistortUV, half4 vertexColor, float4 customData1, float4 customData2)
{
    float2 mainUV = TRANSFORM_TEX(uv, _MainTex) + frac(float2(_MainUVSpeedX, _MainUVSpeedY) * _Time.y);
    float4 mainColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, mainUV + mainDistortUV);

    mainColor *= _MainColor * vertexColor;
    mainColor.rgb *= _MainIntensity * lerp(1, customData1.x * customData2.rgb, _UseCustomData);
    mainColor.rgb *= lerp(1, mainColor.a, _PreMultiAlpha);

    return mainColor;
}

#if _F_SCREENMAP_ON
    half4 GetScreenMapColor(float2 screenUV)
    {
        float2 screenMapUV = TRANSFORM_TEX(screenUV, _ScreenMapTex) + frac(float2(_ScreenMapUVSpeedX, _ScreenMapUVSpeedY) * _Time.y);
        half4 screenMapColor = SAMPLE_TEXTURE2D(_ScreenMapTex, sampler_ScreenMapTex, screenMapUV);

        return screenMapColor * _ScreenMapColor;    
    }
#endif


#if _F_RIM_ON
    void GetRimColor(half3 normalWS, half3 viewDirWS, inout half4 finalColor)
    {
        float NdotV = abs(saturate(dot(normalWS, viewDirWS)));

        #if _F_RIMCOLOR_ON
            float rimColorValue = smoothstep(_RimRange - _RimGradient, _RimRange + _RimGradient, 1 - NdotV);
            finalColor.rgb += rimColorValue * _RimColor;
        #endif

        #if _F_RIMFADE_ON
            float rimFadeValue = pow(NdotV, _RimFadePower);
            rimFadeValue = smoothstep(_RimFadeRange - _RimFadeGradient, _RimFadeRange + _RimFadeGradient, rimFadeValue);
            finalColor.a *= rimFadeValue;
        #endif
    }
#endif

#if _F_DISSOLVE_ON
    void GetDissolveColor(float2 uv, float2 dissolveDistortUV, float2 maskDistortUV, float4 customData1, inout half4 finalColor)
    {
        float2 dissolveUV = TRANSFORM_TEX(uv, _DissolveTex) + frac(float2(_DissolveUVSpeedX, _DissolveUVSpeedY) * _Time.y);
        float dissolveTex = SAMPLE_TEXTURE2D(_DissolveTex, sampler_DissolveTex, dissolveUV + dissolveDistortUV)[(int)_DissolveChannel];

        dissolveTex *= lerp(_DissolveMulti, customData1.y, _DissolveMultiUseCustomData);
        dissolveTex = lerp(dissolveTex, 1 - dissolveTex, _DissolveInvert);

        half dissolveThreshold = lerp(_DissolveThreshold, customData1.y, _DissolveUseCustomData);

        // dissolve mask
        #if _USEDISSOLVEMASK_ON && _F_MASK_ON
            _Mask_d_Tiling.zw = lerp(_Mask_d_Tiling.zw, customData1.zw, _Mask_d_UseCustomData);
            float m = GetMask(TEXTURE2D_ARGS(_MaskTex_d, sampler_MaskTex_d), uv, _Mask_d_Tiling, float2(_Mask_d_UVSpeedX, _Mask_d_UVSpeedY), 
                            _Mask_d_Channel, _Mask_d_Invert, _Mask_d_Power, maskDistortUV);
            dissolveThreshold = lerp(dissolveThreshold, 0, m);
        #endif
        DissolveFunc(dissolveTex, dissolveThreshold, _DissolveSpread, _DissolveEdgeWidth, _DissolveEdgeColor, finalColor);
    }
#endif

#if _F_MASK_ON
    void GetMask(float2 uv, float2 maskDistortUV, float4 customData1, inout half4 finalColor)
    {
        #if _F_MASK_1_ON
            _Mask_1_Tiling.zw = lerp(_Mask_1_Tiling.zw, customData1.zw, _Mask_1_UseCustomData);
            float mask_1 = GetMask(TEXTURE2D_ARGS(_MaskTex_1, sampler_MaskTex_1), uv, _Mask_1_Tiling, float2(_Mask_1_UVSpeedX, _Mask_1_UVSpeedY), 
                        _Mask_1_Channel, _Mask_1_Invert, _Mask_1_Power, maskDistortUV);
            finalColor.rgb *= lerp(mask_1, 1, _Mask_1_Target);
            finalColor.a *= lerp(1, mask_1, _Mask_1_Target);
        #endif
        #if _F_MASK_2_ON
            _Mask_2_Tiling.zw = lerp(_Mask_2_Tiling.zw, customData1.zw, _Mask_2_UseCustomData);
            float mask_2 = GetMask(TEXTURE2D_ARGS(_MaskTex_2, sampler_MaskTex_2), uv, _Mask_2_Tiling, float2(_Mask_2_UVSpeedX, _Mask_2_UVSpeedY), 
                        _Mask_2_Channel, _Mask_2_Invert, _Mask_2_Power, maskDistortUV);
            finalColor.rgb *= lerp(mask_2, 1, _Mask_2_Target);
            finalColor.a *= lerp(1, mask_2, _Mask_2_Target);
        #endif
        #if _F_MASK_3_ON
            _Mask_3_Tiling.zw = lerp(_Mask_3_Tiling.zw, customData1.zw, _Mask_3_UseCustomData);
            float mask_3 = GetMask(TEXTURE2D_ARGS(_MaskTex_3, sampler_MaskTex_3), uv, _Mask_3_Tiling, float2(_Mask_3_UVSpeedX, _Mask_3_UVSpeedY), 
                        _Mask_3_Channel, _Mask_3_Invert, _Mask_3_Power, maskDistortUV);
            finalColor.rgb *= lerp(mask_3, 1, _Mask_3_Target);
            finalColor.a *= lerp(1, mask_3, _Mask_3_Target);
        #endif
    }
#endif

#if _F_CONTACT_ON
    void GetContactColor(float2 screenUV, float4 positionNDC, inout half4 finalColor)
    {
        // sceneZ
	    float rawDepth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV);
        float sceneZ = (unity_OrthoParams.w == 0) ? LinearEyeDepth(rawDepth, _ZBufferParams) : LinearDepthToEyeDepth(rawDepth);
        // fade
        float thisZ = positionNDC.w; // LinearEyeDepth(positionNDC.z / positionNDC.w, _ZBufferParams);
        float fade = min(sceneZ - thisZ, _ContactMaxDistance);

        float fadeExp = saturate(1 - LinearToExp(fade, _ContactFade));

        finalColor.a = lerp(finalColor.a, lerp(0, finalColor.a, fadeExp), _ContactAlphaMode);
        finalColor.rgb = lerp(lerp(_ContantColor.rgb, finalColor.rgb, fadeExp), finalColor.rgb, _ContactAlphaMode);
    }
#endif



#endif // PARTICLEALL_INPUT_INCLUDED
