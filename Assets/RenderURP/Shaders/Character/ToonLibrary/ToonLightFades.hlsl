#ifndef TOON_LIGHTFADES_INCLUDED
#define TOON_LIGHTFADES_INCLUDED


float blendColorBurnSingleChannel(float base, float blend) {
	return (blend==0.0)?blend:max((1.0-((1.0-base)/blend)),0.0);
}

float3 blendColorBurn(float3 base, float3 blend) {
	return float3(blendColorBurnSingleChannel(base.r,blend.r),blendColorBurnSingleChannel(base.g,blend.g),blendColorBurnSingleChannel(base.b,blend.b));
}

float3 blendColorBurn(float3 base, float3 blend, float opacity) {
	return (blendColorBurn(base, blend) * opacity + base * (1.0 - opacity));
}

float GetCameraFade(float3 positionWS)
{
	float weightFOV = 0.02;
	float FOV = 2.0 * atan(1.0f / unity_CameraProjection._m11 ) * (180 * INV_PI) * weightFOV;
    float distFromCamera = IsPerspectiveProjection() ?  length(positionWS - GetCurrentViewPosition()) : 1;
    return lerp( 0, 1, saturate(FOV + (smoothstep(15, 50, distFromCamera))));
}

void DoCharacterDark(float3 positionWS, float cameraDisFade, float shadowAttenuation, inout half3 finalColor)
{
	// 脸部不使用压黑功能
	#ifndef _FACE_SHADE_ON
		float heightDark = smoothstep(_CharDarkParams.x, _CharDarkParams.y, positionWS.y - _FaceDirPosition.y);
		// 加上相机fade
		heightDark = lerp(1, heightDark, cameraDisFade);

		finalColor *= heightDark;

		if(_DebugUseOldShadowDark > 0.5)
		{
			float shadowDark = lerp(_CharDarkParams.w, 1, shadowAttenuation);
			finalColor *= shadowDark;
		}
		else{
			finalColor = lerp(blendColorBurn(finalColor, _CharDarkColor, 1.0 - _CharDarkParams.w), finalColor, shadowAttenuation);
		}
	#endif

}
#endif