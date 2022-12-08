
#ifndef TOON_STANDARD_DYE_INCLUDED
#define TOON_STANDARD_DYE_INCLUDED

#include "ToonStandardInput.hlsl"
#include "ToonStandardCore.hlsl"
#include "ToonLightFades.hlsl"

// -----------------------------------------------------------
// Vertex
Varyings ToonStandardVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    output.uv0 = input.texcoord0;
    output.positionWS = vertexInput.positionWS;
    output.normalWS = normalInput.normalWS;

    real sign = input.tangentOS.w * GetOddNegativeScale();
    output.tangentWS = half4(normalInput.tangentWS.xyz, sign);

    // 通过欧拉角获取头部旋转矩阵
    #if _TOON_HAIR_ON
        float3x3 eulerMatrix = EulerToMartix(_FaceDirRotation.xyz);
        output.headDirRightWS_positionYOS.xyz = mul(eulerMatrix, float3(1,0,0));
        output.headDirForwardWS.xyz = mul(eulerMatrix, float3(0,0,1));
    #endif

    #if _F_DYEENTIRETYFADE_ON
        output.headDirRightWS_positionYOS.w = Rotation2D(PI * _DyeEntiretyFadeAngle / 180, input.positionOS.xy).y;
    #endif

    output.color = input.color;

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        output.shadowCoord = GetShadowCoord(vertexInput);
    #endif

    output.positionCS = vertexInput.positionCS;

    return output;
}

// -----------------------------------------------------------
// Fragment
half4 ToonStandardFragment(Varyings input, FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);

    //是否为正面
    bool isFront = IS_FRONT_VFACE(cullFace, true, false);
    if(isFront == false)
    {
        input.normalWS *= -1;
    }
    float2 uv0 = input.uv0;

    float3 N = normalize(input.normalWS);
    float3 T = normalize(input.tangentWS.xyz);
    float3 B = normalize(input.tangentWS.w * cross(N, T));
    half3x3 tangentToWorld = half3x3(T, B, N);

    // 法线
    half3 bumpN = GetNormal(uv0, tangentToWorld, N);
    #if _DEBUGSHOWNORMAL_ON
        return half4(bumpN, 1);
    #endif

    half3 V = GetWorldSpaceNormalizeViewDir(input.positionWS);

    // --------------------------------------------------------------------
    TexInfs Infs; CalculateColors Cals;
    half4 areaMask;
    GetConfigInfo(uv0, Infs, Cals, areaMask);

    #if _TOON_HAIR_ON
        #if _USEFLOWMAP_ON
            // 这个计算是错的，待修复
            T = normalize(cross(N, normalize(Infs.HairFlowMap.xyz * 2 - 1)));
            B = normalize(cross(N, T));
        #endif
    #endif

    // 由于我们要兼容各向异性和standard材质，所以直接用GGX的各向异性版本，需要这里的T和B。
    // 加入法线贴图之后需要用Orthonormalize函数重新计算世界空间的切线
    // T = normalize(cross(bumpN, B)); （注意需要normalize）基本与这个等效，除非T N输出时就不正交
    T = Orthonormalize(T, bumpN);
    // HDRP中是在需要各向异性时重算B，
    // FillMaterialAnisotropy(surfaceData.anisotropy, surfaceData.tangentWS, cross(surfaceData.normalWS, surfaceData.tangentWS), bsdfData);
    // 我们由于兼容各向异性和standard材质，直接算出来
    B = cross(bumpN, T);

    #if _DEBUGSHOWAREAMASK_ON
        return half4(areaMask.rgb, 1);
    #endif

    // 染色
    #if _F_DYE_ON
        GetCalculateColors(Infs, Cals, input.headDirRightWS_positionYOS.w);
    #endif

    // --------------------------------------------------------------------
    CheckClip(Infs.ClipMask, uv0);

    // 摄像机关于FOV和距离的缩放
    float cameraDisFade = GetCameraFade(input.positionWS.xyz);

    // --------------------------------------------------------------------
    // -> roughness perceptualRoughness F0
    PbrDatas Data = GetPbrDatas(Infs, Cals);

    // --------------------------------------------------------------------
    Light mainLight;
    half diffuseShade = 1;
    half shadowAttenuation = 1;
    half3 directColor = GetDirectColor(input, N, bumpN, T, B, V, input.positionWS, Infs, Cals, Data, mainLight, diffuseShade, shadowAttenuation);

    // --------------------------------------------------------------------
    // 边缘光 可以合并到主光源中
    half3 fresnelColor = 0;
    #if _F_FRESNEL_ON
        #if _DEBUGFRESNEL_ON
            half fresnelDebug = 0;
            GetFresnelColor(uv0, N, N, V, mainLight.direction, Cals, fresnelDebug);
            return fresnelDebug;
        #else
            fresnelColor = GetFresnelColor(uv0, N, N, V, mainLight.direction, Cals) * mainLight.color;
            fresnelColor *= 1.0 - cameraDisFade;
        #endif
    #endif

    // 直接光部分
    half3 finalColor = directColor + fresnelColor;

    // 间接光部分
    #if _F_INDIRECT_ON
        finalColor += GetIndirectColor(B, T, bumpN, V, Infs, Data, Cals);
    #endif

    // matcap
    #if _F_MATCAP_ON
        finalColor += GetMatcapColor(uv0, N, V, diffuseShade);
    #endif

    // 自发光
    #if _F_EMISSION_ON
        finalColor += GetEmissionColor(uv0);
    #endif

    #if _DEBUGOUTLINEMASK_ON
        return half4(SAMPLE_TEXTURE2D(_OutlineMask, sampler_OutlineMask, uv0));
    #endif

    // 如果不使用阴影，不应该在压黑的时候处理阴影区域。
    #ifndef _USESHADOWMAP_ON
        shadowAttenuation = 1.0;
    #endif

    // 压黑
    DoCharacterDark(input.positionWS, cameraDisFade, shadowAttenuation, finalColor);

    ApplyGlobalSettings_Exposure(finalColor);

    return half4(finalColor, 1);
}

#endif
