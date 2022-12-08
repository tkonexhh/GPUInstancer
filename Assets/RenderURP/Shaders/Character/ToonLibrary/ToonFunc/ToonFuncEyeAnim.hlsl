
#ifndef TOON_FUNC_EYEANIM_INCLUDED
#define TOON_FUNC_EYEANIM_INCLUDED

#if _F_EYE_SPECULARANIM_ON
    void CalculateEyeSpecularAnim(half2 uv, inout float4 positionOS)
    {
        half specularMask = SAMPLE_TEXTURE2D_LOD(_MainTex, sampler_MainTex, uv, 0).a;

        float3 eyePos = _EyePosition.xyz;
        float3 eyeRot = _EyeRotation.xyz;

        // input.positionOS.x > 0 flipx 左右对称
        float flip = step(positionOS.x, 0) * 2 - 1;
        eyePos.x *= flip;
        eyeRot.x *= flip;
        
        float angle = sin(_Time.y * _EyeSpecularSpeed * 100) * _EyeSpecularAngle * PI / 180;

        float3 axis = normalize(eyeRot);
        positionOS.xyz = lerp(positionOS.xyz, RotateAroundAxis(eyePos, positionOS.xyz, axis, angle), specularMask);
    }
#endif

#endif