#ifndef SKYSCATTERING_INCLUDED
#define SKYSCATTERING_INCLUDED

#include "SkyCloudInput.hlsl"

float Scale(float inCos)
{
	float x = 1.0 - inCos;
	return 0.25 * exp(-0.00287 + x*(0.459 + x*(3.83 + x*(-6.80 + x*5.25))));
}

void ScatteringCoefficients(half3 dir, inout half3 inScatter, inout half3 outScatter)
{
	dir = normalize(half3(dir.x, max(0, dir.y), dir.z));

	float kInnerRadius2 = _kInnerRadius * _kInnerRadius;
	float kOuterRadius2 = _kOuterRadius * _kOuterRadius;
	//
	float kScale               = 1.0f / (_kOuterRadius - 1.0f);
	float kScaleOverScaleDepth = kScale / _kScaleDepth;
	//
	float3 kInvWavelength4_rgb = 1 / pow(_kWavelength_rgb, 4);

	float kMie      = 0.0020f * _MieMultiplier;
	float kRayleigh = 0.0020f * _RayleighMultiplier;
	//
	float3 kKrESun = kRayleigh * _kSunBrightness * kInvWavelength4_rgb;
	float kKmESun  = kMie * _kSunBrightness;
	//
	float3 kKr4PI = kRayleigh * 4.0f * PI * kInvWavelength4_rgb;
	float kKm4PI  = kMie * 4.0f * PI;
	//

	// Current camera position
	float3 cameraPos = float3(0, _kInnerRadius + _kCameraHeight, 0);

	// Length of the atmosphere
	float far = sqrt(kOuterRadius2 + kInnerRadius2 * dir.y * dir.y - kInnerRadius2) - _kInnerRadius * dir.y;

	// Ray starting position and its scattering offset
	float startDepth  = exp(kScaleOverScaleDepth * (-_kCameraHeight));
	float startAngle  = dot(dir, cameraPos) / (_kInnerRadius + _kCameraHeight);
	float startOffset = startDepth * Scale(startAngle);

	// Scattering loop variables
	float  sampleLength = far / float(SCATTERING_SAMPLES);
	float  scaledLength = sampleLength * kScale;
	float3 sampleRay    = dir * sampleLength;
	float3 samplePoint  = cameraPos + sampleRay * 0.5;

	float3 sunColor = float3(0.0, 0.0, 0.0);

	// Loop through the sample rays
	for (int i = 0; i < int(SCATTERING_SAMPLES); i++)
	{
		float height    = max(1, length(samplePoint));
		float invHeight = 1.0 / height;

		float depth = exp(kScaleOverScaleDepth * (_kInnerRadius - height));
		float atten = depth * scaledLength;

		float cameraAngle = dot(dir, samplePoint) * invHeight;
		float sunAngle    = dot(_LocalSunDirection,  samplePoint) * invHeight;
		float sunScatter  = startOffset + depth * (Scale(sunAngle)  - Scale(cameraAngle));

		float3 sunAtten = exp(-clamp(sunScatter, 0.0, 50) * (kKr4PI + kKm4PI));

		sunColor    += sunAtten * atten;
		samplePoint += sampleRay;
	}

	// Sun scattering
	inScatter = _DaySkyColor * sunColor * kKrESun;
	outScatter = _DaySkyColor * sunColor * kKmESun;
}

float3 FinalCombine(half3 col, half3 dir)
{
	col = max(0, col);
	// Lerp to ground color
	col = lerp(col, _GroundColor, saturate(-dir.y));

	// Adjust output color
	col = pow(col * _Brightness, _Contrast);

	return col;
}

float MiePhase(float eyeCos, float g, float p)
{
	float2 eyeCos2 = eyeCos * eyeCos;

	// Phase function
	float g2 = g * g;

	// Shader paramters 分母去掉4pi部分 系数为1.5
	float3 kBetaMie;
	kBetaMie.x = 1.5f * ((1.0f - g2) / (2.0f + g2));
	kBetaMie.y = 1.0f + g2;
	kBetaMie.z = 2.0f * g;

	return kBetaMie.x * (1.0 + eyeCos2) / max(pow(kBetaMie.y + kBetaMie.z * eyeCos, p), 1.0e-4);
}

float RayleighPhase(float eyeCos2)
{
	// 分母去掉4pi部分 系数为0.75
	return 0.75 + 0.75 * eyeCos2;
}

float3 MoonPhase(float3 positionMoonS, float3 dir)
{
	float2 uv = saturate(positionMoonS.xy / _MoonSize + 0.5);

	float4 moontex = SAMPLE_TEXTURE2D_LOD(_MoonTexture, sampler_MoonTexture, uv, 0);
	float mask = smoothstep(0, 1, moontex.a) * (positionMoonS.z < 0);

	float3 moon = _MoonColor.rgb * moontex.rgb * mask;

	float range = 1 - max(0, dot(dir, _LocalMoonDirection));
	float halo =  smoothstep(0, 1, 1 - pow(range, _MoonHaloSize));

	return (moon + halo * _MoonHaloColor.rgb) * (_LocalMoonDirection.y > 0);
}

// float3 SunPhase(float3 dir)
// {
// 	float range = 1 - max(0, dot(dir, _LocalSunDirection));

// 	float sun = smoothstep(0, 0.001, _SunSize - range);
// 	half halo = smoothstep(0, 1, 1 - pow(range, _SunHaloSize)) ;

// 	return (sun + halo) * (_LocalSunDirection.y > 0) * _SunColor.rgb;
// }

float3 NightPhase(float3 dir)
{
	dir.y = max(0, dir.y);

	return _NightSkyColor * (1.0 - 0.75 * dir.y);
}

float4 ScatteringColor(float3 positionMoonS, float3 dir, float3 inScatter, float3 outScatter)
{
	float3 resultColor = float3(0, 0, 0);

	float sunCos  = dot(_LocalSunDirection, dir);
	float sunCos2 = sunCos * sunCos;

	resultColor += NightPhase(dir);
	resultColor += MoonPhase(positionMoonS, dir);
	// resultColor += SunPhase(dir);
	resultColor += RayleighPhase(sunCos2) * inScatter;

	float eyeCos = pow(saturate(sunCos), _SunHaloSize);
	float power = pow(_SunSize, 0.65) * 10;
	resultColor += MiePhase(eyeCos, -0.99 /*-_Directionality*/, power) * saturate(outScatter) * _SunColor.rgb;
	return float4(FinalCombine(resultColor, dir), 1.0);
}

// ------------------------------------------------------------------------------------------------

float3 CloudPosition(float3 viewDir, float3 offset)
{
	float mult = 1.0 / lerp(0.1, 1.0, viewDir.y);
	return (float3(viewDir.x * mult + offset.x, 0, viewDir.z * mult + offset.z)) / _CloudSize;
}

float4 CloudUV(float3 viewDir, float3 offset)
{
	float3 cloudPos = CloudPosition(viewDir, offset);
	float2 uv1 = cloudPos.xz + _CloudWind.xz;
	float2 uv2 = mul(ROTATION_UV(radians(10.0)), cloudPos.xz) + _CloudWind.xz;
	return float4(uv1.x, uv1.y, uv2.x, uv2.y);
}

float3 CloudColor(float3 viewDir, float3 lightDir)
{
	float lerpValue = saturate(1 + 4 * lightDir.y) * saturate(dot(viewDir, lightDir) + 1.25);
	float3 cloudColor = lerp(_CloudNightColor, _CloudDayColor, lerpValue);
	return _Brightness * cloudColor;
}

float CloudPhase(float eyeCos, float eyeCos2)
{
	const float g = 0.3;
	const float g2 = g * g;
	return _CloudScattering * (1.5 * (1.0 - g2) / (2.0 + g2) * (1.0 + eyeCos2) / (1.0 + g2 - 2.0 * g * eyeCos) + g * eyeCos);
}

half3 CloudLayerDensity(TEXTURE2D_PARAM(densityTex, sampler_densityTex), float4 uv, float3 viewDir)
{
	half3 density = 0;

	const float thickness = 0.1;
	const half4 stepoffset = half4(0.0, 1.0, 2.0, 3.0) * thickness;
	const half4 sumy = half4(0.5000, 0.2500, 0.1250, 0.0625) / half4(1, 2, 3, 4);
	const half4 sumz = half4(0.5000, 0.2500, 0.1250, 0.0625);

	half2 uv1 = uv.xy + viewDir.xz * stepoffset.x;
	half2 uv2 = uv.zw + viewDir.xz * stepoffset.y;
	half2 uv3 = uv.xy + viewDir.xz * stepoffset.z;
	half2 uv4 = uv.zw + viewDir.xz * stepoffset.w;

	half4 n1 = SAMPLE_TEXTURE2D(densityTex, sampler_densityTex, uv1);
	half4 n2 = SAMPLE_TEXTURE2D(densityTex, sampler_densityTex, uv2);
	half4 n3 = SAMPLE_TEXTURE2D(densityTex, sampler_densityTex, uv3);
	half4 n4 = SAMPLE_TEXTURE2D(densityTex, sampler_densityTex, uv4);

	// Noise when marching in up direction
	half4 ny = half4(n1.r, n1.g + n2.g, n1.b + n2.b + n3.b, n1.a + n2.a + n3.a + n4.a);

	// Noise when marching in view direction
	half4 nz = half4(n1.r, n2.g, n3.b, n4.a);

	// Density when marching in up direction
	density.y += dot(ny, sumy);

	// Density when marching in view direction
	density.z += dot(nz, sumz);

	// Coverage
	half2 stepA = _CloudCoverage;
	half2 stepB = _CloudCoverage + 1 / _CloudDensity;
	half2 stepC = _CloudDensity;
	density.yz = smoothstep(stepA, stepB, density.yz) + saturate(density.yz - stepB) * stepC;

	// Opacity
	density.x = saturate(density.z);

	// Shading
	density.yz *= half2(_CloudAttenuation, _CloudSaturation);

	// Remap
	density.yz = 1.0 - exp2(-density.yz);
	

	return density;
}

half4 CloudLayerColor(TEXTURE2D_PARAM(densityTex, sampler_densityTex), float4 uv, float4 color, float3 viewDir, float3 lightDir, float3 lightCol)
{
	half3 density = CloudLayerDensity(TEXTURE2D_ARGS(densityTex, sampler_densityTex), uv, viewDir);

	half4 res = 0;
	res.a = density.x;
	res.rgb = 1.0 - density.y;
	// 固有色和天空色的混合
	res *= color;
	// 光源方向颜色
	res.rgb += saturate(1.0 - density.z) * lightCol;

	return res;
}


#endif
