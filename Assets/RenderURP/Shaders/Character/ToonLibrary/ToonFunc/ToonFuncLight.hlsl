
#ifndef TOON_FUNC_LIGHT_INCLUDED
#define TOON_FUNC_LIGHT_INCLUDED

float4 GetShadowCoord(Varyings input)
{
    float4 shadowCoord = float4(0.0, 0.0, 0.0, 0.0);
    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        shadowCoord = input.shadowCoord;
    #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
        shadowCoord = TransformWorldToShadowCoord(input.positionWS);
    #endif

    return shadowCoord;
}

Light GetMainLight(Varyings input)
{
    float4 shadowCoord = GetShadowCoord(input);
    Light mainLight = GetMainLight(shadowCoord, input.positionWS, 1.0);

    #if _USERLIGHTDIRECTION_ON
        mainLight.direction = -_MainLightDirection;
    #endif
   
    // 直接光影响只考虑LDR范围的色度变化 防止过曝 
    mainLight.color = min(mainLight.color, _LightIntensityLimit * saturate(mainLight.color));

    return mainLight;
}

Light GetAdditionalLight(uint i, Varyings input)
{
    Light light = GetAdditionalLight(i, input.positionWS, 1);
    
    // 直接光影响只考虑LDR范围的色度变化 防止过曝 
    light.color = min(light.color, _LightIntensityLimit * saturate(light.color));

    return light;
}

#endif