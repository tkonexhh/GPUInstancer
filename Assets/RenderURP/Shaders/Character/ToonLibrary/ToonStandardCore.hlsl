
#ifndef TOON_STANDARD_CORE_INCLUDED
#define TOON_STANDARD_CORE_INCLUDED

// ----------------------------------------------------------------
struct CalculateColors
{
    half3 Albedo;
    half3 ShadeColor;
    half3 ShadeAOColor;
    half3 FakeSSSColor;
    half3 AOColor;
    half3 SpecularColor;
    half3 FresnelColor;
    half3 FresnelShadeColor;
};

struct HeadRotations
{
    float3 rightWS;
    float3 upWS;
    float3 forwardWS;
};

// ----------------------------------------------------------------
// 和头发差异部分数据结构
#if _TOON_HAIR_ON
    struct PbrDatas
    {
        half metallic;
        half roughness;
        half perceptualRoughness;
        half3 brdfDiffuseTerm;
        half3 brdfSpecular;
    };

    struct TexInfs
    {
        half ClipMask;

        half3 DyeId;
        half DyeFade;

        half HairDiffuseThreshold;
        half HairOcc;
        half HairDetails;
        half HairStrip;

        half4 HairFlowMap;
        half PBRSpecMask;
    };
#else
    struct PbrDatas
    {
        half metallic;
        half roughness;
        half roughness2;
        half perceptualRoughness;
        half3 brdfDiffuseTerm;
        half3 brdfSpecular;
        half grazingTerm;
    };

    struct TexInfs
    {
        half ClipMask;

        half3 DyeId;
        half DyeFade;

        half MatFabric;
        half MatMetal;
        half MatAniso;
        half MatAO;

        half PbrMetal;
        half PbrOcc;
        half PbrSpecularMask;
        half PbrSmoothness;
    };
#endif

// ----------------------------------------------------------------
struct Attributes
{
    float4 positionOS       : POSITION;
    float3 normalOS         : NORMAL;
    float4 tangentOS        : TANGENT;
    float4 color            : COLOR;
    float2 texcoord0        : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2  uv0                     : TEXCOORD0;
    float3  positionWS              : TEXCOORD1;
    half3   normalWS                : TEXCOORD2;
    half4   tangentWS               : TEXCOORD3;    // xyz: tangent, w: sign

    // headDirRightWS和headDirForwardWS是给头发的高光使用的。
    // 这里本来还想存一个headDirUpWS，但不想拆分到其他的float4里面(太乱)，于是最终headDirUpWS在片元着色器中cross得到
    float4  headDirRightWS_positionYOS : TEXCOORD4; // xyz: headDirRightWS, w: positionYOS
    float4  headDirForwardWS        : TEXCOORD5;

    float4  color                   : TEXCOORD6;

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    float4  shadowCoord             : TEXCOORD7;
#endif
    float4  positionCS              : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

// ----------------------------------------------------------------
// 函数部分
#include "ToonFunc/ToonFuncClip.hlsl"
#include "ToonFunc/ToonFuncFresnel.hlsl"
#include "ToonFunc/ToonFuncLight.hlsl"
#include "ToonFunc/ToonFuncEulerAngles.hlsl"

// ----------------------------------------------------------------
#ifdef _F_EMISSION_ON
// 自发光 TODO uv流动
half3 GetEmissionColor(float2 uv)
{
    half4 emissionTex = SAMPLE_TEXTURE2D(_EmissionTex, sampler_EmissionTex, TRANSFORM_TEX(uv, _EmissionTex));
    half3 emissionColor = emissionTex.rgb * emissionTex.a * _EmissionColor.rgb;

    return emissionColor;
}
#endif

// matcap
#if _F_MATCAP_ON
    half3 GetMatcapColor(float2 uv, half3 N, half3 V, half diffuseShade)
    {
        half3 normalVS = TransformWorldToViewDir(N);
        #if _ORTHOMATCAP_ON
            float2 uvVS = normalVS.xy * 0.5 + 0.5;
        #else
            normalVS *=  float3(-1, -1, 1);
            half3 viewDirVS = TransformWorldToViewDir(V) * float3(-1, -1, 1) + float3(0, 0, 1);
            float3 noSknewNormalVS = viewDirVS * dot(viewDirVS, normalVS) / viewDirVS.z - normalVS;
            float2 uvVS = noSknewNormalVS.xy * 0.5 + 0.5;
        #endif

        half4 matcapColor = SAMPLE_TEXTURE2D(_MatcapTex, sampler_MatcapTex, TRANSFORM_TEX(uvVS, _MatcapTex));
        matcapColor *= _MatcapColor;

        // 第1层阴影对Matcap的遮蔽
        matcapColor *= lerp(1, diffuseShade, _MatcapShadowValue);

        // 蒙板
        half4 matcapMask = SAMPLE_TEXTURE2D(_MatcapMask, sampler_MatcapMask, TRANSFORM_TEX(uv, _MatcapMask));
        #if _INVERSEMATCAPMASK_ON
            matcapMask = 1 - matcapMask;
        #endif
        matcapMask = saturate(matcapMask + _MatcapMaskLevel);

        matcapColor *= matcapMask;

        return matcapColor.rgb;
    }
#endif

void GetConfigInfo(float2 uv, inout TexInfs infs, inout CalculateColors cals, inout half4 areaMask)
{
    uv = TRANSFORM_TEX(uv, _MainTex);
    // --------------------------------------------------------------------
    // rgb: albedo a: clipmask
    half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
    // rgb: 区域ID颜色 a: 染色渐变
    areaMask = SAMPLE_TEXTURE2D(_AreaMask, sampler_AreaMask, uv);

    // --------------------------------------------------------------------
    #if _TOON_HAIR_ON
        // r: 漫反射阈值 g: AO b: 高光遮罩 a: 高光形状
        half4 hairTex = SAMPLE_TEXTURE2D(_HairTex, sampler_HairTex, uv);
        half4 hairFlowTex = SAMPLE_TEXTURE2D(_HairFlowTex, sampler_HairFlowTex, uv);
        half pbrSpecMask = SAMPLE_TEXTURE2D(_HairPBRSpecMask, sampler_HairPBRSpecMask, uv).r;

        TexInfs Infs = {
            mainTex.a,          // ClipMask

            areaMask.rgb,       // DyeId
            areaMask.a,         // DyeFade

            hairTex.r,          // HairDiffuseThreshold
            hairTex.g,          // HairOcc
            hairTex.b,          // HairDetails
            hairTex.a,          // HairStrip

            hairFlowTex,        // HairFlowMap
            pbrSpecMask,        // PBRSpecMask
        };
    #else
        // r: 布料  g: 金属
        half4 matMask = SAMPLE_TEXTURE2D(_MatMask, sampler_MatMask, uv);
        // r: 金属度 g: AO b: 高光遮罩 a: 光滑度
        half4 pbrTex = SAMPLE_TEXTURE2D(_PBRTex, sampler_PBRTex, uv);

        TexInfs Infs = {
            mainTex.a,      // ClipMask

            areaMask.rgb,   // DyeId
            areaMask.a,     // DyeFade

            matMask.r,      // MatFabric
            matMask.g,      // MatMetal
            matMask.b,      // MatAniso
            matMask.a,      // MatAO

            pbrTex.r,       // PbrMetal
            pbrTex.g,       // PbrOcc
            pbrTex.b,       // PbrSpecularMask
            pbrTex.a,       // PbrSmoothness
        };
    #endif

    // --------------------------------------------------------------------
    CalculateColors Cals = {
        mainTex.rgb * _BaseColor.rgb,                        // Albedo
        mainTex.rgb * _ShadeColor_1.rgb,    // ShadeColor
        mainTex.rgb * _ShadeColor_1.rgb,    // ShadeAOColor
        _FakeSSSColor.rgb,                  // FakeSSSColor
        mainTex.rgb,                        // AOColor
        _SpecularColor.rgb,                 // SpecularColor
        _FresnelColor.rgb,                  // FresnelColor
        _FresnelShadeColor.rgb              // FresnelShadeColor
    };

    infs = Infs;
    cals = Cals;
}


// ----------------------------------------------------------------
// 和头发混合函数
half3 GetDiffuseColor(float NdotL, float NdotL_half, float NdotV, float HdotL,
                    TexInfs Infs, PbrDatas Data, CalculateColors Cals,
                    half shadowAttenuation, inout half diffuseShade)
{
    float diffuse = NdotL_half;

    #if _TOON_HAIR_ON
        #if _USEDIFFUSETHRESHOLD_ON
            // 漫反射动态阈值图, 作为法线细节的补充
            diffuse = saturate(diffuse + Infs.HairDiffuseThreshold * 2.0 - 1.0);
        #endif
        // 头发 都使用梯度漫反射
        half MatPbr = 0;
        half occ = Infs.HairOcc;

        half3 KD = Data.brdfDiffuseTerm;
        KD *= lerp(1 - _HairDetailsStrength, 1, Infs.HairDetails);
        // 用这个使头发的亮度匹配PBR材质
        KD *= INV_PI;
    #else
        // 主要是标记 不使用梯度漫反射的区域
        half MatPbr = 1 - Infs.MatFabric;
        half occ = Infs.MatAO;

        half3 KD = Data.brdfDiffuseTerm;
        //
        // 将DisneyDiffuse(NdotV, NdotL, HdotL, Data.perceptualRoughness)其中的Data.perceptualRoughness改为0
        // 为了解决换色时暗部不够暗的问题....
        KD *= lerp(DisneyDiffuse(NdotV, NdotL, HdotL, 0), FabricOrenNayarApproach(NdotV), Infs.MatFabric);
    #endif



    // 第一层梯度漫反射
    float diffuseRamp = smoothstep(_Shift_01, _Shift_01 + _Gradient_01, diffuse);

    // 布料区域使用梯度漫反射, 其余区域使用标准NdotL匹配PBR
    diffuseShade = lerp(diffuseRamp, NdotL, MatPbr);

    // float w = cos(PI/2 - PI/12);
    // float flippedNdotL = saturate((-diffuseShade + w) / ((1.0 + w) * (1.0 + w)));
    // diffuseColor += flippedNdotL * Cals.FakeSSSColor * KD;

    // TODO 直接光阴影 先直接加在这里
    #if _USESHADOWMAP_ON
        diffuseShade *= shadowAttenuation;
    #endif

    // 直接光部分固有色上增加一层AO 不影响间接光
    half3 albedo = lerp(Cals.AOColor, Cals.Albedo, occ);
    half3 shadeColor = lerp(Cals.ShadeAOColor.rgb, Cals.ShadeColor.rgb, occ);
    // 暗部-明部 颜色根据漫反射过度
    half3 diffuseColor = lerp(shadeColor, albedo, diffuseShade);

    #if _FAKESSS_ON
        float fakeSSS = smoothstep(_FakeSSSWidth.y, 0, diffuse - _Shift_01);
        fakeSSS *= 1 - smoothstep(0, _FakeSSSWidth.x, -(diffuse - _Shift_01));
        // 标记区域不考虑
        #if _USESHADOWMAP_ON
            fakeSSS *= shadowAttenuation;
        #endif

        diffuseColor = lerp(diffuseColor, Cals.FakeSSSColor, fakeSSS * (1 - MatPbr));
    #endif

    //
    diffuseColor *= KD;

    return diffuseColor;
}

#if _TOON_HAIR_ON
    // 头发高光
    half3 GetHairSpecularColor_Temp(float NdotV, float NdotL, float NdotH, float HdotV,
                            float3 H, float3 T, float3 B, half3 N, half3 V, float3 L,
                            TexInfs Infs, PbrDatas Data, CalculateColors Cals,
                            float3 positionWS, half diffuseShade)
    {
        float4 hairFlowMap = Infs.HairFlowMap;

        B = ShiftTangent(B, N, (hairFlowMap.a * _SpecularHairFlowIntensity - 0.5 - _SpecularHairBias));

        float specularTerm = StrandSpecular(B, H, exp2(lerp(20, 0, _SpecularHairPower)));

        // 高光遮罩 TODO
        specularTerm *= saturate(_SpecularIntensity) * diffuseShade;

        half3 specularColor = specularTerm * Cals.SpecularColor;

        return specularColor;
    }

    half3 GetHairSpecularColor(float3 T, float3 B, half3 N, half3 V, float3 L,
                            HeadRotations headRotations, TexInfs Infs, PbrDatas Data, CalculateColors Cals,
                            float3 positionWS, half diffuseShade)
    {
        float3 upWS = headRotations.upWS;
        float NdotV = dot(N, V);

        // 使用球形切线
        #if _SPECULARHAIRUSESN_ON
            float3 rightWS = headRotations.rightWS;
            float3 forwardWS = headRotations.forwardWS;
            float3 rootPos = _FaceDirPosition.xyz;
            float3 specularHairSNOffset = rootPos.xyz + _SpecularHairSNOffset.x * rightWS.xyz + _SpecularHairSNOffset.y * upWS.xyz + _SpecularHairSNOffset.z * forwardWS.xyz;
            N = lerp(N, normalize(positionWS - specularHairSNOffset), 1);
            B = normalize(cross(N, cross(N, upWS)));
            T = normalize(cross(N, B));
        #endif

        // 在角色头顶方向向量的量
        half upDistance = dot(V, upWS);
        // ProjectOnPlane, 投影到法向量为upWS的平面上
        // 投影函数可以简化成这样的前提是参与计算的都是归一矢量
        half3 planeV = V - upDistance * upWS;
        // 在角色头顶方向进行视角的限位
        V = normalize(planeV + upWS * max(upDistance * 0.5, -0.2));

        half specularHairBias = _SpecularHairBias;
        // 让高光在最上面的时候不会缩成一坨
        specularHairBias = lerp(specularHairBias, specularHairBias - 1.0, saturate(dot(V, upWS)));
        // 高光在两边稍微往上抬一点点
        specularHairBias += 0.3 * (pow(1.0 - saturate(NdotV), 2));

        B = ShiftTangent(B, N, (0.5 - specularHairBias));

        // 高光形状 根据视角缩放
        // 将原公式的dot(N, H)改为dot(N, V)， 取消光照影响
        float pow10NdotV = pow(saturate(NdotV), 10);
        float strip = saturate(Infs.HairStrip * lerp(0.6, 1, pow10NdotV));
        // 将视角中央的部分范围压小
        strip *= max(1.0 - pow10NdotV * pow10NdotV, 0.69);

        float specularTerm = StrandSpecular(B, V, exp2(lerp(20, 0, _SpecularHairPower * strip)));
        specularTerm *= any(saturate(strip - 0.1));
        // cell
        specularTerm = smoothstep(0, 0.001, specularTerm);
        // 高光遮罩
        float lerpedDiffuseShade = lerp(0.1, 1, diffuseShade);
        specularTerm *= lerpedDiffuseShade * saturate(_SpecularIntensity);

        // 将视角后面的一部分消隐掉
        specularTerm *= saturate(dot(N, V) - 0.5);

        // PBR高光
        float nl = saturate(dot(N, L));
        half nv = abs(NdotV);
        float3 halfDir = SafeNormalize (L + V);
        float nh = saturate(dot(N, halfDir));
        float hv = saturate(dot(halfDir, V));
        float DV = DV_SmithJointGGX(nh, nl, nv, Data.roughness);
        half3 F = F_Schlick(Data.brdfSpecular, hv);
        half3 specularTermPBR = F * DV;
        // 用lerpedDiffuseShade使得背光也有一点点，用step(0.001, NdotV)遮挡反面像素防止闪光
        specularTermPBR *= step(0.001, NdotV) * lerpedDiffuseShade * _SpecularPBRIntensity * Infs.PBRSpecMask;

        half3 specularColor = specularTerm * Cals.SpecularColor + specularTermPBR * Cals.SpecularColor;

        return specularColor;
    }
#else
    float3 GetBRDFSpecualrTerm(float NdotV, float NdotL, float NdotH, float HdotV,
                    float3 H, float3 T, float3 B, float3 L, half3 V,
                    TexInfs Infs, PbrDatas Data, inout half3 F)
    {
        half roughness = Data.roughness;
        half3 brdfSpecular = Data.brdfSpecular;

        // F inout
        F = F_Schlick(brdfSpecular, HdotV);

        // float DV = DV_SmithJointGGX(NdotH, abs(NdotL), NdotV, roughness);

        float TdotH = dot(T, H);
        float BdotH = dot(B, H);
        float TdotL = dot(T, L);
        float BdotL = dot(B, L);
        float TdotV = dot(T, V);
        float BdotV = dot(B, V);

        float roughnessT, roughnessB;
        ConvertAnisotropyToRoughnessClamp(roughness, Infs.MatAniso * _SpecularAnisotropic, roughnessT, roughnessB);

        float DV = DV_SmithJointGGXAniso(TdotH, BdotH, NdotH, TdotV, BdotV, NdotV, TdotL, BdotL, abs(NdotL), roughnessT, roughnessB);
        float3 specularTerm = F * DV;

        return specularTerm;
    }

    float3 GetFabricSpecualrTerm(float NdotV, float NdotL, float NdotH,
                    half perceptualRoughness)
    {
        perceptualRoughness = lerp(0.5, 1, perceptualRoughness);
        half roughness = perceptualRoughness * perceptualRoughness;


        float3 specularTerm = 0;

        /*
        // D
        float D = D_Charlie(NdotH, roughness);

        // V
        // Non-Metal: Cotton, deim, flax and common fabrics
        // Cotton: Roughness of 1.0 (unless wet) - Fuzz rim - specular color is white but is looked like desaturated.
        // Metal: Silk, satin, velvet, nylon and polyester
        // Silk: Roughness 0.3 - 0.7 - anisotropic - varying specular color
        float V = V_Ashikhmin(NdotL, NdotV);

        specularTerm = D * V;
        */

        // 几种布料高光形状会导致峰值过黑 这个拟合版本比较平滑
        specularTerm = DV_InvGaussianApproach(NdotH);

        return specularTerm;

    }

    // --------------------------------------------
    // 默认高光
    half3 GetSpecularColor(float NdotV, float NdotL, float NdotH, float HdotV,
                            float3 H, float3 T, float3 B, float3 L, half3 V,
                            TexInfs Infs, PbrDatas Data, CalculateColors Cals,
                            float diffuseShade)
    {

        float3 F;
        // Standard PBR
        float3 specularTerm = GetBRDFSpecualrTerm(NdotV, NdotL, NdotH, HdotV, H, T, B, L, V, Infs, Data, F);

        // 布料区域高光
        #if _USEFABRICMASK_ON
            float3 fabricSpecularTerm = GetFabricSpecualrTerm(NdotV, NdotL, NdotH, Data.perceptualRoughness);

            // silk
            float3 silkSpecularTerm = specularTerm + fabricSpecularTerm * F;
            fabricSpecularTerm = lerp(fabricSpecularTerm, silkSpecularTerm, Infs.MatAniso > 0);
            // cotton
            specularTerm = lerp(specularTerm, fabricSpecularTerm, Infs.MatFabric);
        #endif

        // 高光遮罩
        specularTerm *= saturate(Infs.PbrSpecularMask + _SpecularIntensity) * diffuseShade;

        half3 specularColor = specularTerm * Cals.SpecularColor;

        return specularColor;
    }
#endif

#if _TOON_HAIR_ON
#else
    half3 EnvironmentBRDFSpecular(PbrDatas pbrData, half fresnelTerm)
    {
        float surfaceReduction = 1.0 / (pbrData.roughness2 + 1.0);
        return half3(surfaceReduction * lerp(pbrData.brdfSpecular, pbrData.grazingTerm, fresnelTerm));
    }
#endif

// 间接光
half3 GetIndirectColor(float3 B, float3 T, half3 N, half3 V,
                        TexInfs Infs, PbrDatas Data, CalculateColors Cals)
{
    half roughness = Data.perceptualRoughness;

    #if _TOON_HAIR_ON
    #else
        UNITY_BRANCH
        if(Infs.MatAniso > 0)
        {
            half3 iblN; half iblPerceptualRoughness;
            GetGGXAnisotropicModifiedNormalAndRoughness(B, T, N, V, _SpecularAnisotropic, roughness, iblN, iblPerceptualRoughness);
            N = iblN; roughness = iblPerceptualRoughness;
        }
    #endif

    float NdotV = saturate(dot(N, V));

    float3 R = reflect(-V, N);
    half mip = roughness *(1.7 - 0.7 * roughness) * UNITY_SPECCUBE_LOD_STEPS;

    // -------------------------- 反射
    half4 reflection = SAMPLE_TEXTURE2D_LOD(unity_SpecCube0, samplerunity_SpecCube0, R, mip);
    // 间接光镜面反射采样的预过滤环境贴图
	#if !defined(UNITY_USE_NATIVE_HDR)
        half3 envSpecularPrefilted = DecodeHDREnvironment(reflection, unity_SpecCube0_HDR);
    #endif

    #if _TOON_HAIR_ON
        half hasIndirctSpecular = 1;
        half occ = Infs.HairOcc; // TODO 间接光遮蔽怎么处理
    #else
        // 金属部分独立的CubeMap
        half4 reflectionMetal = SAMPLE_TEXTURECUBE_LOD(_MetalReflectCubemap, sampler_MetalReflectCubemap, R, mip);
        envSpecularPrefilted = lerp(envSpecularPrefilted, reflectionMetal.rgb * reflectionMetal.a, Infs.MatMetal);

        half MatFabric = Infs.MatFabric;
        half hasIndirctSpecular = lerp(1, lerp(0, 1, Infs.MatAniso > 0), Infs.MatFabric);
        half occ = Infs.PbrOcc;
    #endif
    // -------------------------- 反射

    #if _TOON_HAIR_ON
        half3 specularIndirect = 0;
    #else
        half fresnelTerm = Pow4(1.0 - NdotV) * (1.0 - NdotV);
        half3 specularIndirect = envSpecularPrefilted * EnvironmentBRDFSpecular(Data, fresnelTerm);
    #endif

    // 布料区域 去除间接镜面反射
    specularIndirect = lerp(0, specularIndirect, hasIndirctSpecular);

    half3 irradianceSH = SampleSH(N);


    half3 albedo = Cals.Albedo;
    #if _F_DYE_ON
        #if _TOON_HAIR_ON
            albedo = Cals.Albedo;
        #else
            // 由于换色，对于衣服来说，这里把固有色AO和albedo(纯色)混合在一起当作固有色。
            albedo = lerp(Cals.AOColor, Cals.Albedo, Infs.MatAO);
        #endif
    #endif
    #if _DEBUGNOTUSEENVTOALBEDO_ON
    half3 diffuseIndirect = irradianceSH * albedo * Data.brdfDiffuseTerm;
    #else
    half3 diffuseIndirect = lerp(irradianceSH, INV_PI, NdotV * NdotV) * albedo * Data.brdfDiffuseTerm;
    #endif

    //
    half3 indirectColor = (diffuseIndirect + specularIndirect * _InDirectSpecularIntensity) * _InDirectIntensity;
    // AO
    indirectColor = max(0, indirectColor) * LerpWhiteTo(occ, _IndirectAOIntensity);

    return indirectColor;
}

#if _F_DYE_ON
    // TODO 后续外部预处理
    half3 GetDyeColor(half3 albedo, TexInfs Infs, float positionYOS)
    {
        // TODO 染色区域颜色列表 外部传入
        const half3 colorList[8] = {
            lerp(albedo, _DyeColor0.rgb, _F_DyeColor0),
            lerp(albedo, _DyeColor1.rgb, _F_DyeColor1),
            lerp(albedo, _DyeColor2.rgb, _F_DyeColor2),
            lerp(albedo, _DyeColor3.rgb, _F_DyeColor3),
            lerp(albedo, _DyeColor4.rgb, _F_DyeColor4),
            lerp(albedo, _DyeColor5.rgb, _F_DyeColor5),
            lerp(albedo, _DyeColor6.rgb, _F_DyeColor6),
            lerp(albedo, _DyeColor7.rgb, _F_DyeColor7)
        };
        const half3 fadeColorList[8] = {
            lerp(albedo, _DyeColorFade0.rgb, _F_DyeColor0),
            lerp(albedo, _DyeColorFade1.rgb, _F_DyeColor1),
            lerp(albedo, _DyeColorFade2.rgb, _F_DyeColor2),
            lerp(albedo, _DyeColorFade3.rgb, _F_DyeColor3),
            lerp(albedo, _DyeColorFade4.rgb, _F_DyeColor4),
            lerp(albedo, _DyeColorFade5.rgb, _F_DyeColor5),
            lerp(albedo, _DyeColorFade6.rgb, _F_DyeColor6),
            lerp(albedo, _DyeColorFade7.rgb, _F_DyeColor7)
        };


        int id, idNear;
        half fade;
        CalculateDyeColorId(Infs.DyeId, id, idNear, fade);

        half3 color = lerp(colorList[id], colorList[idNear], fade);
        half3 fadeColor = lerp(fadeColorList[id], fadeColorList[idNear], fade);

        // 无边界模式
        #if _DEBUGSHOWDYEPOINT_ON
            color = colorList[id];
        #endif

        #if _F_DYEENTIRETYFADE_ON
            // 区间映射
            half range = lerp(_DyeEntiretyFadeData.x, _DyeEntiretyFadeData.y, _DyeEntiretyFadeShift);
            half k = smoothstep(1, 0, _DyeEntiretyFadeData.z * (positionYOS - range) + 0.5);
            k = lerp(k, 1 - k, _DyeEntiretyFadeInvert);
            color = lerp(color, _DyeEntiretyFadeColor, k);
        #endif

        // 渐变
        #if _DYEFADEOVERLAY_ON
            fadeColor = ColorBlendOverlay(color, fadeColor);
        #endif
        color = lerp(color, fadeColor, Infs.DyeFade);

        return color;
    }

    void GetCalculateColors(TexInfs Infs, inout CalculateColors Cals, float positionYOS)
    {
        // 渐变叠加后作为固有色
        Cals.Albedo = GetDyeColor(Cals.Albedo, Infs, positionYOS);

        half3 originHSV = RgbToHsv(Cals.Albedo);
        //
        half3 shadeHSV;
        Cals.ShadeColor = HsvTransMultiPower(originHSV, _DyeShadeSat, _DyeShadeLum, _DyeShadeLumPower, shadeHSV);
        //
        Cals.FakeSSSColor = HsvTransMulti(shadeHSV, _DyeSSSSat, _DyeSSSLum);

        // 这里shadeHSV只是起一个占位功能，下面不再使用
        Cals.ShadeAOColor = HsvTransMultiPower(originHSV, _DyeAOSat * _DyeShadeSat, _DyeAOLum * _DyeShadeLum, _DyeShadeLumPower, shadeHSV);

        Cals.AOColor = HsvTransMulti(originHSV, _DyeAOSat, _DyeAOLum);

        #if _TOON_HAIR_ON
            // 之前是使用HsvTransAddHair，现在改成天使环用这个更适合
            Cals.SpecularColor = HsvTransAdd(originHSV, _DyeSpecularSat, _DyeSpecularLum) * _SpecularColor.rgb;
        #else
            // 只有布料区域控制染色高光颜色
            half3 specularColor = HsvTransAdd(originHSV, _DyeSpecularSat, _DyeSpecularLum);
            Cals.SpecularColor *= lerp(1, specularColor, Infs.MatFabric);
        #endif

        // 边缘光在固有色明度比较低的情况下 降低
        half3 fresnelK = 1 - 1 / (25 * originHSV.z + 1.2);
        Cals.FresnelColor *= fresnelK;
        Cals.FresnelShadeColor *= fresnelK;
    }
#endif

PbrDatas GetPbrDatas(TexInfs Infs, CalculateColors Cals)
{
    #if _TOON_HAIR_ON
        PbrDatas data;
        data.metallic = 0;
        data.roughness = 1;
        data.perceptualRoughness = 1;
        data.brdfDiffuseTerm = 1 - half3(0.0465, 0.0465, 0.0465); // Hair is IOR 1.55
        // data.brdfSpecular = lerp(kDieletricSpec.rgb, Cals.Albedo, metallic);
        // 头发没有金属度输入，所以这里不用lerp
        data.brdfSpecular = kDieletricSpec.rgb;
    #else
        PbrDatas data;
        half smoothness = _Smoothness;

        #if _USESMOOTHNESSMASK_ON
            smoothness *= Infs.PbrSmoothness;
        #endif
        // roughness
        half perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(smoothness);// 1 - _Smoothness

        data.perceptualRoughness = perceptualRoughness;
        data.roughness = max(PerceptualRoughnessToRoughness(perceptualRoughness), HALF_MIN_SQRT);
        data.roughness2 = max(data.roughness * data.roughness, HALF_MIN);

        // metallic
        float metallic = Infs.PbrMetal * _Metallic;
        data.metallic = metallic;
        half oneMinusReflectivity = OneMinusReflectivityMetallic(metallic);
        half reflectivity = half(1.0) - oneMinusReflectivity;
        data.brdfDiffuseTerm = oneMinusReflectivity;
        data.brdfSpecular = lerp(kDieletricSpec.rgb, Cals.Albedo, metallic);

        // grazingTerm
        data.grazingTerm = saturate(smoothness + reflectivity);
    #endif

    return data;
}

half3 GetNormal(float2 uv, half3x3 tangentToWorld, half3 normalWS)
{
    half3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, TRANSFORM_TEX(uv, _NormalTex)), _NormalScale);
    half3 normalBumpWS = NormalizeNormalPerPixel(TransformTangentToWorld(normalTS, tangentToWorld));

    return normalBumpWS;
}

half3 GetSingleDirectColor(Light light, half3 N, half3 bumpN, float3 T, float3 B, half3 V,
                    float3 positionWS, HeadRotations headRotations, TexInfs Infs, CalculateColors Cals, PbrDatas Data,
                    inout half diffuseShade, inout half shadowAttenuation)
{
    float3 L = light.direction;
    float3 H = normalize(V + L);

    // float NdotV = abs(dot(bumpN, V));
    float NdotV = max(dot(bumpN, V), 0.0001); // Approximately 0.0057 degree bias

    float NdotL = saturate(dot(bumpN, L));
    float NdotL_half = dot(bumpN, L) * 0.5 + 0.5;
    float HdotL = saturate(dot(H, L));
    float NdotH = saturate(dot(bumpN, H));
    float HdotV = saturate(dot(H, V));

    half lightAttenuation = light.distanceAttenuation * light.shadowAttenuation;
    shadowAttenuation = lightAttenuation;

    // 漫反射
    half3 diffuseColor = GetDiffuseColor(NdotL, NdotL_half, NdotV, HdotL,
                    Infs, Data, Cals,
                    lightAttenuation, diffuseShade);
    // 调试用
    diffuseColor = lerp(0, diffuseColor, _F_Diffuse);

    #if _TOON_HAIR_ON
        // 头发高光
        half3 specularColor = GetHairSpecularColor(T, B, N, V, L,
                        headRotations, Infs, Data, Cals,
                        positionWS, diffuseShade);

        // half3 specularColor = GetHairSpecularColor_Temp(NdotV, NdotL, NdotH, HdotV, H, T, B, N, V, L,
        //                 Infs, Data, Cals,
        //                 positionWS, diffuseShade);
    #else
        // 高光
        half3 specularColor = GetSpecularColor(NdotV, NdotL, NdotH, HdotV, H, T, B, L, V,
                        Infs, Data, Cals,
                        diffuseShade);
    #endif
    // 调试用
    specularColor = lerp(0, specularColor, _F_Specular);

    half3 directColor = (diffuseColor + specularColor) * light.color;
    return directColor;
}

half3 GetDirectColor(Varyings input, half3 N, half3 bumpN, float3 T, float3 B, half3 V,
                    float3 positionWS, TexInfs Infs, CalculateColors Cals, PbrDatas Data,
                    inout Light mainLight, inout half diffuseShade, inout half shadowAttenuation)
{
    mainLight = GetMainLight(input);


        HeadRotations headRotations = (HeadRotations)0;
    #if _TOON_HAIR_ON
        headRotations.rightWS = input.headDirRightWS_positionYOS.xyz;
        headRotations.forwardWS = input.headDirForwardWS.xyz;
        headRotations.upWS = cross(input.headDirForwardWS.xyz, input.headDirRightWS_positionYOS.xyz);
    #endif
    half3 directColor = GetSingleDirectColor(mainLight, N, bumpN, T, B, V, input.positionWS, headRotations, Infs, Cals, Data, diffuseShade, shadowAttenuation);

    #if _USEADDITIONALLIGHT_ON && defined(_ADDITIONAL_LIGHTS)
        #if !USE_CLUSTERED_LIGHTING
            for (uint lightIndex = 0u; lightIndex < GetAdditionalLightsCount(); ++lightIndex)
            {
                half shade = 1;
                half shadowAttenuationTemp = 1;
                Light light = GetAdditionalLight(lightIndex, input);
                directColor += GetSingleDirectColor(light, N, bumpN, T, B, V, input.positionWS, headRotations, Infs, Cals, Data, shade, shadowAttenuationTemp);
            }
        #endif
    #endif

    return directColor;
}

#endif // TOON_STANDARD_CORE_INCLUDED