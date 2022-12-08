
#ifndef TOON_COMMON_INCLUDED
#define TOON_COMMON_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/BRDF.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"


half GetRampMask(half diffuse, half shift, half gradient, bool smooth)
{
    half a = shift - 0.5 * gradient;
    half b = shift + 0.5 * gradient;

    // smoothstep 拆开而已
    half l = clamp((diffuse - a)/(b - a), 0, 1);

    return smooth ? (3 - 2 * l) * l * l : l;
}

float3 RotateAroundAxis(float3 center, float3 original, float3 u, float angle)
{
    original -= center;
    float C = cos( angle );
    float S = sin( angle );
    float t = 1 - C;
    float m00 = t * u.x * u.x + C;
    float m01 = t * u.x * u.y - S * u.z;
    float m02 = t * u.x * u.z + S * u.y;
    float m10 = t * u.x * u.y + S * u.z;
    float m11 = t * u.y * u.y + C;
    float m12 = t * u.y * u.z - S * u.x;
    float m20 = t * u.x * u.z - S * u.y;
    float m21 = t * u.y * u.z + S * u.x;
    float m22 = t * u.z * u.z + C;
    float3x3 finalMatrix = float3x3(m00, m01, m02, m10, m11, m12, m20, m21, m22);
    return mul(finalMatrix, original) + center;
}

float2 Rotation2D(float rad, float2 dir)
{
    float2 cos_sin = float2(cos(rad), sin(rad));
    float2x2 rotation = float2x2(cos_sin.x, -cos_sin.y, cos_sin.y, cos_sin.x);

    return mul(dir - 0.5, rotation) + 0.5;
}


// ----------------------------------------------------------------------------------------

// Scheuermann Model 由原始 Kajiya-Kay Model 改进
// 和 D_KajiyaKay 有些差别
float StrandSpecular(float3 T, float3 H, float exponent)
{
    float dotTH = dot(T, H);
    float sinTH = sqrt(1 - dotTH * dotTH);
    float dirAtten = smoothstep(-1, 0, dotTH);

    return dirAtten * pow(sinTH, exponent);
}

// 方便自定义
void ConvertAnisotropyToRoughnessClamp(float roughness, float anisotropy, out float roughnessT, out float roughnessB)
{
    // float aspect = sqrt(1.0 - 0.9 * abs(anisotropy));

    // float aspect_rcp = rcp(aspect);
    // float sign = step(anisotropy, 0);
    // roughnessT = roughness * lerp(aspect_rcp, aspect, sign);
    // roughnessB = roughness * lerp(aspect_rcp, aspect, 1 - sign);

    ConvertValueAnisotropyToValueTB(roughness, anisotropy, roughnessT, roughnessB);

    roughnessT = max(0.001, roughnessT);
    roughnessB = max(0.001, roughnessB);
}

// https://seblagarde.wordpress.com/2011/08/17/hello-world/
float3 FresnelSchlickRoughness(float NdotV, float3 F0, float roughness)
{
    float3 r = 1.0 - roughness;
    return F0 + (max(r, F0) - F0) * pow(1.0 - NdotV, 5.0);
}

float2 EnvBRDFApprox_UE4(float roughness, float NdotV)
{
    // [ Lazarov 2013, "Getting More Physical in Call of Duty: Black Ops II" ]
    // Adaptation to fit our G term.
    const float4 c0 = { -1, -0.0275, -0.572, 0.022 };
    const float4 c1 = { 1, 0.0425, 1.04, -0.04 };
    float4 r = roughness * c0 + c1;
    float a004 = min( r.x * r.x, exp2( -9.28 * NdotV ) ) * r.x + r.y;
    float2 AB = float2( -1.04, 1.04 ) * a004 + r.zw;
    return AB;
}

float DV_InvGaussianApproach(float NdotH)
{
    float a2 = (1.0 - NdotH) * (1.0 - NdotH);
    return 0.96 * a2 + 0.057;
}

float FabricOrenNayarApproach(float NdotV)
{
    float term = 1 - saturate(0.5 * NdotV);
    return term * INV_PI;
}


// ----------------------------------------------------------------------------------------

void CalculateDyeColorId(half3 dyeId, inout int id, inout int idNear, inout half fade)
{
    // 四舍五入取整数
    int3 _round = round(dyeId);

    // 掩码计算 r * 2^2 + g * 2^1 + b * 2^0
    // 边界过度处以0.5作为界限区分
    id = dot(_round, int3(4, 2, 1));

    // 向上向下取整
    int3 _ceil = ceil(dyeId);
    int3 _floor = floor(dyeId);

    // 边界过度处 临近的id颜色
    int3 dyeNear = (1 - _round) * _ceil + _floor;
    // 边界过度处 临近的id
    idNear = dot(dyeNear, int3(4, 2, 1));

    // 找到过度处 颜色id 三个通道中不相等的通道 (即描述过度阈值的单通道)
    float r = any(_ceil.r - _floor.r);
    float g = any(_ceil.g - _floor.g);
    float b = any(_ceil.b - _floor.b);
    fade = r ? dyeId.r : (g ? dyeId.g : (b ? dyeId.b : 1));

    // 等于 round(fade) < 1 ? fade : 1 - fade) 小于0.5的部分和大于0.5部分的过度相反
    fade = lerp(fade, 1 - fade, step(1, round(fade)));
}

half3 HsvTransMultiPower(half3 hsv, half satScale, half lumScale, half lumPower, out half3 ref)
{
    hsv.y = saturate(hsv.y * satScale);
    hsv.z = saturate(pow(saturate(hsv.z), lumPower) * lumScale);

    ref = hsv;

    return HsvToRgb(hsv);
}

half3 HsvTransMulti(half3 hsv, half satScale, half lumScale)
{
    hsv.y = saturate(hsv.y * satScale);
    hsv.z = saturate(hsv.z * lumScale);

    return HsvToRgb(hsv);
}

half3 HsvTransAdd(half3 hsv, half satAdd, half lumAdd)
{
    hsv.y = saturate(hsv.y + satAdd);
    hsv.z = saturate(hsv.z + lumAdd);

    return HsvToRgb(hsv);
}

half3 HsvTransAddHair(half3 hsv, half satAdd, half lumAdd)
{
    hsv.y = saturate(hsv.y + (hsv.y > 0.5 ? -1 : 1) * satAdd);
    hsv.z = saturate(hsv.z + lumAdd);

    return HsvToRgb(hsv);
}


// PS 颜色混合
// https://www.adobe.com/content/dam/acom/en/devnet/pdf/pdfs/pdf_reference_archives/blend_modes.pdf
// https://en.wikipedia.org/wiki/Blend_modes
// http://www.pegtop.net/delphi/articles/blendmodes/surveybright.htm
half3 ColorBlendOverlay(half3 a, half3 b)
{
    // a = LinearToGammaSpace(a);
    // b = LinearToGammaSpace(b);
    half3 color = 0;
    // 叠加
    color.r = a.r <= 0.5 ? 2 * a.r * b.r : 1 - 2 * (1 - a.r) * (1 - b.r);
    color.g = a.g <= 0.5 ? 2 * a.g * b.g : 1 - 2 * (1 - a.g) * (1 - b.g);
    color.b = a.b <= 0.5 ? 2 * a.b * b.b : 1 - 2 * (1 - a.b) * (1 - b.b);

    // 线性光
    // color = a + 2 * b - 1;
    // 变亮
    // color = max(a, b);
    // 滤色
    // color = 1 - (1 - a) * (1 - b);
    // 线性减淡
    // color = a + b;
    // 柔光
    // color.r = b.r <= 0.5 ? 2 * a.r * b.r + a.r * a.r * (1 - 2 * b.r) : 2 * a.r * (1 - b.r) + (2 * b.r - 1) * sqrt(a.r);
    // color.g = b.g <= 0.5 ? 2 * a.g * b.g + a.g * a.g * (1 - 2 * b.g) : 2 * a.g * (1 - b.g) + (2 * b.g - 1) * sqrt(a.g);
    // color.b = b.b <= 0.5 ? 2 * a.b * b.b + a.b * a.b * (1 - 2 * b.b) : 2 * a.b * (1 - b.b) + (2 * b.b - 1) * sqrt(a.b);
    // 强光
    // color.r = b.r <= 0.5 ? 2 * a.r * b.r : 1 - 2 * (1 - a.r) * (1 - b.r);
    // color.g = b.g <= 0.5 ? 2 * a.g * b.g : 1 - 2 * (1 - a.g) * (1 - b.g);
    // color.b = b.b <= 0.5 ? 2 * a.b * b.b : 1 - 2 * (1 - a.b) * (1 - b.b);
    // 点光
    // color.r = b.r <= 0.5 ? min(a.r, 2 * b.r) : max(a.r, 2 * b.r - 1);
    // color.g = b.g <= 0.5 ? min(a.g, 2 * b.g) : max(a.g, 2 * b.g - 1);
    // color.b = b.b <= 0.5 ? min(a.b, 2 * b.b) : max(a.b, 2 * b.b - 1);
    // color = GammaToLinearSpace(color);
    return color;
}



#endif