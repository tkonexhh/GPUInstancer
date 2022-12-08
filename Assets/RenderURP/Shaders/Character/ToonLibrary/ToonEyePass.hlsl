
#ifndef TOON_EYE_INCLUDED
#define TOON_EYE_INCLUDED

#include "ToonEyeInput.hlsl"
#include "ToonEyeCore.hlsl"

// -----------------------------------------------------------
// Vertex
Varyings ToonEyeVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);

    #if _F_EYE_SPECULARANIM_ON
        CalculateEyeSpecularAnim(input.texcoord0, input.positionOS);
    #endif

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    output.uv0 = input.texcoord0;

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        output.shadowCoord = GetShadowCoord(vertexInput);
    #endif

    output.positionWS = vertexInput.positionWS;
    output.positionCS = vertexInput.positionCS;

    #if defined(_F_EYE_LIGHTING_ON)
        output.normalWS = TransformObjectToWorldNormal(input.normalOS);
    #endif

    return output;
}


// -----------------------------------------------------------
// Fragment
half4 ToonEyeFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);

    float2 uv0 = input.uv0;

    #if _F_EYE_UVANIM_ON
        CalculateUVAnim(uv0);
    #endif

    half4 finalColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, TRANSFORM_TEX(uv0, _MainTex));

    // 光照
    #if defined(_F_EYE_LIGHTING_ON)
        // TODO shadowAttenuation
        Light mainLight = GetMainLight(input);
        float halfNdotL = dot(mainLight.direction, input.normalWS) * 0.5 + 0.5;
        float diffuseShade = smoothstep(_Shift_01, _Shift_01 + _Gradient_01, halfNdotL);
        #ifdef _USESHADOWMAP_ON
            diffuseShade *= mainLight.distanceAttenuation * mainLight.shadowAttenuation;
        #endif
        finalColor.rgb *= lerp(_DarkColor.rgb, _BrightColor.rgb, diffuseShade) * mainLight.color;
    #endif

    #if _HIDESPECULAR_ON
        // 隐藏眼睛高光
        clip((1 - finalColor.a) - 1);
    #else
        // 高光强度
        finalColor.rgb *= (1 + finalColor.a * _SpecularPower);
    #endif

    ApplyGlobalSettings_Exposure(finalColor.rgb);

    return half4(finalColor.rgb, 1);
}

#endif
