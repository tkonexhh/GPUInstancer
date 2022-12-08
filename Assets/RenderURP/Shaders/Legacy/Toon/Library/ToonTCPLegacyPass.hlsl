
#ifndef TOON_TCP_LEGACY_INCLUDED
#define TOON_TCP_LEGACY_INCLUDED

// ----------------------------------------------------------------
struct Attributes
{
    float4 positionOS       : POSITION;
    float3 normalOS         : NORMAL;
    float2 texcoord0        : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2  uv0                     : TEXCOORD0;
    float3  positionWS              : TEXCOORD1;
    half3   normalWS                : TEXCOORD2;

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    float4  shadowCoord             : TEXCOORD3;
#endif
    float4  positionCS              : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};


// -----------------------------------------------------------
// Vertex
Varyings ToonTCPLegacyVertex(Attributes input) 
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS);

    output.uv0 = input.texcoord0;
    output.positionWS = vertexInput.positionWS;
    output.normalWS = normalInput.normalWS;

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        output.shadowCoord = GetShadowCoord(vertexInput);
    #endif

    output.positionCS = vertexInput.positionCS;

    return output;
}

half3 GetSingleDirectColor(Light light, half3 N, half3 albedo, half3 shadowColor)
{
    half NdotL = saturate(dot(N, light.direction));
    
    half lightAttenuation = light.distanceAttenuation * light.shadowAttenuation;

    half ramp = smoothstep(_RampThreshold - _RampSmoothing * 0.5, _RampThreshold + _RampSmoothing * 0.5, NdotL);
    ramp *= lightAttenuation;

    half3 directColor = lerp(shadowColor, _HColor.rgb, ramp);

    directColor *= albedo * _Color.rgb * light.color;

    return directColor;
}

half3 GetDirectColor(Varyings input, half3 N, half3 albedo)
{
    float4 shadowCoord = float4(0.0, 0.0, 0.0, 0.0);
    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        shadowCoord = input.shadowCoord;
    #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
        shadowCoord = TransformWorldToShadowCoord(input.positionWS);
    #endif
    Light mainLight = GetMainLight(shadowCoord, input.positionWS, 1.0);

    half3 directColor = GetSingleDirectColor(mainLight, N, albedo, _SColor.rgb);
    
    #if defined(_ADDITIONAL_LIGHTS)
        #if !USE_CLUSTERED_LIGHTING
            for (uint lightIndex = 0u; lightIndex < GetAdditionalLightsCount(); ++lightIndex) 
            {
                Light light = GetAdditionalLight(lightIndex, input.positionWS, 1);
                directColor += GetSingleDirectColor(light, N, albedo, 0);
            }
        #endif
    #endif

    return directColor;
}
// -----------------------------------------------------------
// Fragment
half4 ToonTCPLegacyFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);

    float3 N = normalize(input.normalWS);

    float2 uv = TRANSFORM_TEX(input.uv0, _MainTex);
    //
    half3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv).rgb;
    half3 directColor = GetDirectColor(input, N, albedo);

    // 
    half3 inDirectColor = SampleSH(N) * albedo;

    //
    half3 finalColor = directColor + inDirectColor;

    return half4(finalColor, 1);
} 

#endif

