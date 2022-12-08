#ifndef TOON_FUNC_EULERANGLES_INCLUDED
#define TOON_FUNC_EULERANGLES_INCLUDED

// 在顶点着色器调用
float3x3 EulerToMartix(float3 eulerAngles)
{
    // *= Mathf.Deg2Rad， 这个和Unity的Quaternion.cs中eulerAngles.Set同样操作，转单位
    // https://github.com/Unity-Technologies/UnityCsReference/blob/master/Runtime/Export/Math/Quaternion.cs
    eulerAngles *= 0.017453292;
    float cosP = cos(eulerAngles.x);
    float sinP = sin(eulerAngles.x);
    float cosH = cos(eulerAngles.y);
    float sinH = sin(eulerAngles.y);
    float cosB = cos(eulerAngles.z);
    float sinB = sin(eulerAngles.z);
    float3x3 matrixOut = float3x3(cosH*cosB+sinH*sinP*sinB, cosB*sinH*sinP-sinB*cosH,  cosP*sinH,
                                    cosP*sinB, cosB*cosP, -sinP,
                                    sinB*cosH*sinP-sinH*cosB, sinH*sinB+cosB*cosH*sinP, cosP*cosH);
    return matrixOut;
}

#endif