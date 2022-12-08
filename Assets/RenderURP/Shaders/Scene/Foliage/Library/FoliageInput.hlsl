#ifndef FOLIAGE_INPUT_INCLUDED
#define FOLIAGE_INPUT_INCLUDED

// ------------------------------------------
// 自定义宏转换
#if _METALLICGLOSSUSE_TEXTURE
    #define _METALLICSPECGLOSSMAP 1
#endif

#define _ALPHATEST_ON 1
// 植物默认关闭直接光高光
// #define _SPECULARHIGHLIGHTS_OFF 1

#if _USENORMALMAP_ON
    #define _NORMALMAP 1
#endif
// ------------------------------------------

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"

#if _F_WIND_ON
    #include "FoliageWind.hlsl"
#endif

TEXTURE2D(_BumpMap);            SAMPLER(sampler_BumpMap);
TEXTURE2D(_MainTex);            SAMPLER(sampler_MainTex);
// 为了兼容材质的debug模式，需要mipinfo
// Lit材质的mipinfo为_BaseMap_MipInfo，定义在Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl里面
float4  _MainTex_TexelSize;
float4  _MainTex_MipInfo;
TEXTURE2D(_MaskMap);            SAMPLER(sampler_MaskMap);
#if _F_MATCAP_ON
    TEXTURE2D(_MatcapTex);          SAMPLER(sampler_MatcapTex);
    TEXTURE2D(_MatcapRampTex);      SAMPLER(sampler_MatcapRampTex);
#endif

// 全局参数
half4 _GLOBAL_INDIRECT_ADJUST_PARAMS;
half4 _GLOBAL_INDIRECT_DIFFUSE_COLOR;
half2 _GLOBAL_CAMERAFADE_PARAMS;

CBUFFER_START(UnityPerMaterial)
    float4  _MainTex_ST;
    half4   _Color;
    half    _Cutoff;
    half    _MetallicValue;
    half    _MetallicScale;
    half    _Glossiness;
    half    _GlossMapScale;
    half    _BumpScale;

    half    _UseLightMaskForLight;

    float3  _NormalThiefPosition;

    half4   _HueVariationColor;

    half    _VertexAOPower;
    half4   _VertexAOColor;

    float3  _CenterAOPosition;
    half    _CenterAOPower;
    half    _CenterAOStrength;
    half4   _CenterAOColor;

    half    _TransmissionScale;
    half    _TransmissionFakeRange;

    half4   _TopLerpColor;
    half    _TopLerpScale;
    half    _TopLerpOffset;
    half4   _TopLerpParams;

    //
    half    _MatcapScale;
    half    _MatcapRotation;
    half4   _MatcapRampColor;
    float   _MatcapRampTilingExp;
    half    _MatcapGlowExp;
    half    _MatcapGlowAmount;
    half    _MatcapMultiBaseColor;

    // TODO 应该改成全局的
    float4  _WindDir;
    // 这里变体会打断SRPBatcher的编译
    // #if _WINDTYPE_TREE
        half    _WindPower;
        float4  _WindTreeCenter;
    // #else
        half    _BranchStrength;
        half    _WaveStrength;
        half    _DetailStrength;
        half    _DetailFrequency;
    // #endif
CBUFFER_END

struct FoliageSurfaceData
{
    half3 albedo;
    half  metallic;
    half  smoothness;
    half3 normalTS;
    half  occlusion;
    half  alpha;
    half  ao;
};

half Alpha(half albedoAlpha, half4 color, half cutoff)
{
    half alpha = albedoAlpha * color.a;

    #if defined(_ALPHATEST_ON)
        clip(alpha - cutoff);
    #endif

    return alpha;
}

half4 SampleAlbedo(float2 uv)
{
    return half4(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv));
}

half3 SampleNormal(float2 uv, half scale = half(1.0))
{
    #ifdef _NORMALMAP
        half4 n = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uv);
        // #if BUMP_SCALE_NOT_SUPPORTED
        //     return UnpackNormal(n);
        // #else
            return UnpackNormalScale(n, scale);
        // #endif
    #else
        return half3(0.0h, 0.0h, 1.0h);
    #endif
}

// r: metallic a: smoothness (URP和HDRP在这两项上一致)
half4 SampleMaskMap(float2 uv)
{
    half spec = 0;
    half lightMask = 1;
    half transmissionMask = 1;
    half smoothness = 0;

    half4 maskMap = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, uv).rgba;
    lightMask = maskMap.g;
    transmissionMask = maskMap.b;

    #ifdef _METALLICUSE_METALLICTEXTURE
        spec = maskMap.r * _MetallicScale;
    #else
        spec = _MetallicValue;
    #endif

    #ifdef _METALLICSPECGLOSSMAP
        smoothness = maskMap.a * _GlossMapScale;
    #else // _METALLICSPECGLOSSMAP
        smoothness = _Glossiness;
    #endif

    return half4(spec, lightMask, transmissionMask, smoothness);
}

#if _F_MATCAP_ON
    half3 GetMatcapColor(half3 baseColor, half3 normalWS)
    {
        half3 normalVS = TransformWorldToViewDir(normalWS, true);

        float rad = _MatcapRotation * (-2 * PI) * rcp(360);
        float2 cos_sin = float2(cos(rad), sin(rad));
        float2x2 rotation = float2x2(cos_sin.x, -cos_sin.y, cos_sin.y, cos_sin.x);

        float2 uvMapcap = mul(normalVS.xy * _MatcapScale * 0.5, rotation) + 0.5;
        half4 matcapTex = SAMPLE_TEXTURE2D(_MatcapTex, sampler_MatcapTex, uvMapcap);

        float2 uvMatcapRamp = float2(pow(max(matcapTex.r, 0), _MatcapRampTilingExp), 0.0);
        half4 matcapRampTex = SAMPLE_TEXTURE2D(_MatcapRampTex, sampler_MatcapRampTex, uvMatcapRamp);
        matcapRampTex *= _MatcapRampColor * pow(max(matcapTex.r, 0), _MatcapGlowExp) * _MatcapGlowAmount;

        return lerp(1, baseColor, _MatcapMultiBaseColor) * matcapRampTex.rgb;
    }
#endif

inline void InitializeFoliageSurfaceData(float2 uv, half4 color, float3 positionWS, float4 centerAOColor,
                                        out FoliageSurfaceData outSurfaceData, out half lightMask, out half transmissionMask)
{
    half4 albedo = SampleAlbedo(uv);

    // ---------------------------------------------------------------------------------------
    // 色相调整
    #if _F_HUEVARIATION_ON
        half3 shiftedColor = lerp(albedo.rgb, _HueVariationColor.rgb, color.g);

        // 尽量贴近原贴图的饱和度
        half maxBase = max(albedo.r, max(albedo.g, albedo.b));
        half newMaxBase = max(shiftedColor.r, max(shiftedColor.g, shiftedColor.b));
        maxBase /= newMaxBase;
        maxBase = maxBase * 0.5f + 0.5f;
        shiftedColor.rgb *= maxBase;

        albedo.rgb = saturate(shiftedColor);
    #endif

    outSurfaceData.alpha = Alpha(albedo.a, _Color, _Cutoff);

    // 这里的AO 是对基础反射率的作用
    outSurfaceData.ao = 1.0;
    // 顶点色AO
    #if _F_VERTEXAO_ON
        float vertex_ao = SafePositivePow(color.r, _VertexAOPower);
        float4 vertex_aocolor = lerp(_VertexAOColor, 1, vertex_ao);
        albedo.rgb *= vertex_aocolor.rgb;

        outSurfaceData.ao *= vertex_ao;
    #endif

    // 中心AO 补充用
    #if _F_CENTERAO_ON
        albedo.rgb *= centerAOColor.rgb;
        outSurfaceData.ao *= centerAOColor.a;
    #endif

    // ---------------------------------------------------------------------------------------

    half4 masks = SampleMaskMap(uv);
    outSurfaceData.albedo = albedo.rgb * _Color.rgb;

    outSurfaceData.metallic = masks.r;
    lightMask = lerp(1.0, masks.g, _UseLightMaskForLight);
    transmissionMask = masks.b;
    outSurfaceData.smoothness = masks.a;
    outSurfaceData.normalTS = SampleNormal(uv, _BumpScale);
    // 植物不考虑环境光遮蔽
    outSurfaceData.occlusion = 1;
}

#endif // FOLIAGE_INPUT_INCLUDED
