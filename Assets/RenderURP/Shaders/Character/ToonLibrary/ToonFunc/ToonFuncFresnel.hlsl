
#ifndef TOON_FUNC_FRESNEL_INCLUDED
#define TOON_FUNC_FRESNEL_INCLUDED

// --------------------------------------------
// 边缘光
float GetFresnelTerm(float NdotV, half fresnelPow)
{
    float fresnelTerm = pow((1 - saturate(NdotV)), exp2(lerp(3, 0, fresnelPow)));

    #if _FRES_FUNC_DEFAULT
        fresnelTerm = (fresnelTerm - _FresnelInnerRange) / (1.0 - _FresnelInnerRange);
    #elif _FRES_FUNC_CEL
        float w = fwidth(fresnelTerm);
        fresnelTerm = smoothstep(-w, w, fresnelTerm - _FresnelInnerRange);
    #endif

    return saturate(fresnelTerm);
}

half3 GetFresnelColor(float2 uv, half3 N, half3 NBump, half3 V, float3 L,
                     CalculateColors Cals
                #if _DEBUGFRESNEL_ON
                    , inout float fresnelDebug
                #endif
                     )
{

    // 限制光照角度范围
    L.y *= _FresnelLightRange;
    L = normalize(L);

    #if _NORMALTOFRESNEL_ON
        float NdotV = dot(NBump, V);
    #else
        float NdotV = dot(N, V);
    #endif

    // abs为了解决双面材质反面看过去时，法线应该反过来的问题
    // 这里NdotV应该是-1~1， abs(NdotV)为0~1
    float fresnelTerm = GetFresnelTerm(abs(NdotV), _FresnelPow);
    #if _DEBUGFRESNEL_ON
        fresnelDebug = fresnelTerm;
    #endif

    half3 fresnelColor = Cals.FresnelColor;

    // 暗部边缘光遮蔽
    #if _FRES_SHADE_MASK_ON
        // 这里不用考虑法线贴图, 只是用来确定暗部区域
        #if _FRES_FUNC_DEFAULT
            // 可能有问题
            float NdotL_half = 0.5 + 0.5 * dot(N, L);
            float bias = NdotL_half - _FresnelShadeMaskIntensity;
        #elif _FRES_FUNC_CEL
            float NdotL_half = dot(N, L);
            float bias = smoothstep(0, 0.01, NdotL_half - 0.5 - _FresnelShadeMaskIntensity);
        #endif

        fresnelTerm = saturate(fresnelTerm - (1 - bias));
        #if _DEBUGFRESNEL_ON
            fresnelDebug = fresnelTerm;
        #endif

        fresnelColor *= fresnelTerm;

        #if _FRES_SHADE_ON
            float fresnelTermShade = GetFresnelTerm(NdotV, _FresnelShadePow);

            fresnelTermShade = saturate(fresnelTermShade - bias);
            #if _DEBUGFRESNEL_ON
                fresnelDebug = saturate(fresnelDebug + fresnelTermShade);
            #endif

            float3 fresnelShadeColor = Cals.FresnelShadeColor * fresnelTermShade;

            fresnelColor += fresnelShadeColor;
        #endif
    #else
        fresnelColor *= fresnelTerm;
    #endif

    // 边缘光遮罩 A通道+参数调节 TODO 遮罩纹理采样合并
    half fresnelMask = SAMPLE_TEXTURE2D(_FresnelMask, sampler_FresnelMask, TRANSFORM_TEX(uv, _FresnelMask)).a;
    fresnelColor *= saturate(fresnelMask + _FresnelIntensity);
    #if _DEBUGFRESNEL_ON
        fresnelDebug *= saturate(fresnelMask + _FresnelIntensity);
    #endif

    return fresnelColor;
}


#endif