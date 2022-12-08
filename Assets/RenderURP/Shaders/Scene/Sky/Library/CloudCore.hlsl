#ifndef CLOUD_CORE_INCLUDED
#define CLOUD_CORE_INCLUDED

#include "SkyScattering.hlsl"

struct Attributes
{
    float4 positionOS   : POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
	float4 uv 				: TEXCOORD0;
	float4 baseColor  		: TEXCOORD1;
	float3 lightColor		: TEXCOORD2;
	float3 viewDir    		: TEXCOORD3;
	float4 positionCS   	: SV_POSITION;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

// -----------------------------------------------------------
// Vertex
Varyings CloudVertex(Attributes input)
{
	Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

	output.positionCS = vertexInput.positionCS;

	half3 viewDir = normalize(input.positionOS.xyz);
	output.viewDir = viewDir;

	output.uv = CloudUV(viewDir, 0);


	float3 positionWS = vertexInput.positionWS;
	float3 positionMoonS = mul(_WorldToMoonMatrix, float4(positionWS, 1)).xyz;
	
	half3 inScatterColor, outScatterColor;
	ScatteringCoefficients(viewDir, inScatterColor, outScatterColor);

	// 云固有色
	half3 cloudColor = CloudColor(viewDir, _LocalSunDirection);

	float sunCos  = dot(_LocalSunDirection, viewDir);
	float sunCos2 = sunCos * sunCos;
	// 天空颜色
	float3 nightScattering    = NightPhase(viewDir);
	float3 rayleighScattering = RayleighPhase(sunCos2) * inScatterColor;
	// 光源方向颜色
	float3 moonScattering     = MoonPhase(positionMoonS, viewDir) * _CloudScattering;
	float3 sunScattering 	  = 0;// SunPhase(o.viewDir); 顶点阶段计算太阳精度不够 
	float3 mieScattering      = MiePhase(sunCos, -0.7, 1.5) * CloudPhase(sunCos, sunCos2) * saturate(outScatterColor) * _SunColor.rgb;

	half3 dirColor  = FinalCombine(moonScattering + mieScattering + sunScattering, viewDir);
	half3 baseColor = FinalCombine(nightScattering + rayleighScattering, viewDir);

	float fade = clamp(500 * viewDir.y * viewDir.y, 0.0, 1.00001);
	// 光源方向颜色
	output.lightColor  = dirColor;
	// 固有色和天空颜色渐变
	output.baseColor.rgb = _CloudBrightness * lerp(baseColor * _CloudSkyColorIntensity, cloudColor, _CloudColoring);
	output.baseColor.a   = _CloudOpacity * fade * (viewDir.y > _CloudClip);

	return output;
}
	
// -----------------------------------------------------------
// Fragment
half4 CloudFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);

	half4 color = CloudLayerColor(TEXTURE2D_ARGS(_CloudTexture, sampler_CloudTexture), 
			input.uv, input.baseColor, input.viewDir, _LocalSunDirection, input.lightColor);

	return color;
}

#endif
