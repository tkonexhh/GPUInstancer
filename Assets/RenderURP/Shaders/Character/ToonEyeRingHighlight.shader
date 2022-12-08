


Shader "Inutan/URP/Character/ToonEyeRingHighlight 眼睛边缘高光" {
    // --------------------------------------------
    Properties {
        // level/style/toggle/open/showlist
        [Foldout(1, 1, 0, 1)] _F_Base("基础_Foldout", float) = 1
        [HDR]_Color("颜色", Color) = (1, 1, 1, 1)
        _RoateRange("摆动范围", Range(0,0.5)) = 0.01
        [Foldout_Out(1)] _F_Base_Out("_F_Base_Foldout", float) = 1

        [Foldout(1, 1, 1, 1)] _F_HighlightPoint1("高光点1_Foldout", float) = 1
        [Enum_Switch(Circle, Star, Moon, BlobbyCross, UnevenCapsule, Heart)] _PointRenderType1("类型", float) = 0
        _PointDisAngle1("旋转角度", Range(0,1)) = 0.54
        _PointRoateSpeed1("摆动速度", Range(0,1)) = 0.1
        _PointPos1("位置", Range(0,1)) = 0.42
        _PointRadius1("半径", Vector) = (0.19, 0.4, 0.0, 0.0)
        [Foldout(2, 2, 1, 1)] _F_HighlightPoint1RoateSelf("自旋转_Foldout", float) = 0
        _Point1RoateSelf("旋转角度", Range(0,1)) = 0
        [Foldout_Out(1)] _F_HighlightPoint1RoateSelf_Out("_F_HighlightPoint1RoateSelf_Out_Foldout", float) = 1

        [Foldout_Out(1)] _F_HighlightPoint1_Out("_F_HighlightPoint1_Foldout", float) = 1

        [Foldout(1, 1, 1, 1)] _F_HighlightPoint2("高光点2_Foldout", float) = 1
        _PointDisAngle2("旋转角度", Range(0,1)) = 0.54
        _PointRoateSpeed2("摆动速度", Range(0,1)) = 0.1
        _PointPos2("位置", Range(0,1)) = 0.07
        _PointRadius2("半径", Range(0,1)) = 0.07
        [Foldout_Out(1)] _F_HighlightPoint2_Out("_F_HighlightPoint2_Foldout", float) = 1

        [Foldout(1, 1, 1, 1)] _F_HighlightPoint3("高光点3_Foldout", float) = 1
        _PointDisAngle3("旋转角度", Range(0,1)) = 0.65
        _PointRoateSpeed3("摆动速度", Range(0,1)) = 0.1001
        _PointPos3("位置", Range(0,1)) = 0.5
        _PointRadius3("半径", Range(0,1)) = 0.04
        [Foldout_Out(1)] _F_HighlightPoint3_Out("_F_HighlightPoint3_Foldout", float) = 1

        [Foldout(1, 1, 1, 1)] _F_HighlightPoint4("高光点4_Foldout", float) = 1
        _PointDisAngle4("旋转角度", Range(0,1)) = 0.668
        _PointRoateSpeed4("摆动速度", Range(0,1)) = 0.0901
        _PointPos4("位置", Range(0,1)) = 0.29
        _PointRadius4("半径", Range(0,1)) = 0.045
        [Foldout_Out(1)] _F_HighlightPoint4_Out("_F_HighlightPoint4_Foldout", float) = 1

        [Foldout(1, 1, 1, 1)] _F_Ring("边缘旋转高光_Foldout", float) = 1
        _RingDisAngle("旋转角度", Range(0,1)) = 0.142
        // x: 外圈位置
        // y: 外圈sdf半径
        // z: 内圆位置
        // w: 内圆sdf半径
        _RingParams("参数", Vector) = (-0.33, 0.82, 1.2, 0.25)


        [Foldout(1, 1, 0, 1)] _F_Debug("调试_Foldout", float) = 1
        [Toggle_Switch] _DebugShowNoAlpha("不使用透明 (调试用)", float) = 0

        // --------------------------------------------
        [Foldout_Out(1)] _F_Out("F_Out_Foldout", float) = 1
    }

    // --------------------------------------------
    SubShader {
        Tags{"RenderType" = "Transparent"  "Queue" = "AlphaTest" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True"}

        Pass {
            Name "ToonEyeRingHighlight"

            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma target 4.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _POINTRENDERTYPE1_CIRCLE _POINTRENDERTYPE1_STAR _POINTRENDERTYPE1_MOON _POINTRENDERTYPE1_BLOBBYCROSS _POINTRENDERTYPE1_UNEVENCAPSULE _POINTRENDERTYPE1_HEART
            #pragma shader_feature_local _F_HIGHLIGHTPOINT1_ON
            #pragma shader_feature_local _F_HIGHLIGHTPOINT1ROATESELF_ON
            #pragma shader_feature_local _F_HIGHLIGHTPOINT2_ON
            #pragma shader_feature_local _F_HIGHLIGHTPOINT3_ON
            #pragma shader_feature_local _F_HIGHLIGHTPOINT4_ON
            #pragma shader_feature_local _F_RING_ON
            #pragma shader_feature_local _DEBUGSHOWNOALPHA_ON

            // -------------------------------------
            // Global RenderSettings keywords
            #pragma multi_compile _ _GLOBALRENDERSETTINGSENABLEKEYWORD

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer

            #pragma vertex ToonEyeVertex
            #pragma fragment ToonEyeFragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "ToonLibrary/ToonInput/ToonInputGlobalSettings.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4   _Color;
                float   _RoateRange;
                float   _PointDisAngle1, _PointRoateSpeed1, _PointPos1;
                float4  _PointRadius1;
                float   _Point1RoateSelf;
                float   _PointDisAngle2, _PointRoateSpeed2, _PointPos2, _PointRadius2;
                float   _PointDisAngle3, _PointRoateSpeed3, _PointPos3, _PointRadius3;
                float   _PointDisAngle4, _PointRoateSpeed4, _PointPos4, _PointRadius4;

                float   _RingDisAngle;
                float4  _RingParams;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS       : POSITION;
                float2 texcoord0        : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float2  uv0                     : TEXCOORD0;
                float4  positionCS              : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            // -----------------------------------------------------------
            // Vertex
            Varyings ToonEyeVertex(Attributes input)
            {
                Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.uv0 = input.texcoord0;
                output.positionCS = vertexInput.positionCS;

                return output;
            }

            float SDFSphere(float2 center, float2 pos, float r)
            {
                return length(pos - center) - r;
            }

            // 五角星
            #if _POINTRENDERTYPE1_STAR
                float sdStar5(float2 p, float r, float rf)
                {
                    float2 k1 = float2(0.809016994375, -0.587785252292);
                    float2 k2 = float2(-k1.x,k1.y);
                    p.x = abs(p.x);
                    p -= 2.0*max(dot(k1,p),0.0)*k1;
                    p -= 2.0*max(dot(k2,p),0.0)*k2;
                    p.x = abs(p.x);
                    p.y -= r;
                    float2 ba = rf*float2(-k1.y,k1.x) - float2(0,1);
                    float h = clamp( dot(p,ba)/dot(ba,ba), 0.0, r );
                    return length(p-ba*h) * sign(p.y*ba.x-p.x*ba.y);
                }
            #endif

            // 月牙
            #if _POINTRENDERTYPE1_MOON
                float sdMoon(float2 p, float ra, float rb, float d)
                {
                    p.y = abs(p.y);
                    float a = (ra*ra - rb*rb + d*d)/(2.0*d);
                    float b = sqrt(max(ra*ra-a*a,0.0));
                    if( d*(p.x*b-p.y*a) > d*d*max(b-p.y,0.0) )
                    return length(p-float2(a,b));
                    return max( (length(p)-ra), -(length(p-float2(d,0))-rb));
                }
            #endif

            // 圆角十字
            #if _POINTRENDERTYPE1_BLOBBYCROSS
                float sdBlobbyCross(float2 pos, float he )
                {
                    pos = abs(pos);
                    pos = float2(abs(pos.x-pos.y),1.0-pos.x-pos.y)/sqrt(2.0);

                    float p = (he-pos.y-0.25/he)/(6.0*he);
                    float q = pos.x/(he*he*16.0);
                    float h = q*q - p*p*p;

                    float x;
                    if( h>0.0 )
                    {
                        float r = sqrt(h);
                        x = pow(q+r,1.0/3.0)-pow(abs(q-r),1.0/3.0)*sign(r-q);
                    }
                    else
                    {
                        float r = sqrt(p);
                        x = 2.0*r*cos(acos(q/(p*r))/3.0);
                    }
                    x = min(x,sqrt(2.0)/2.0);

                    float2 z = float2(x,he*(1.0-2.0*x*x)) - pos;
                    return length(z) * sign(z.y);
                }
            #endif

            // 水滴形
            #if _POINTRENDERTYPE1_UNEVENCAPSULE
                float sdUnevenCapsule(float2 p, float r1, float r2, float h)
                {
                    p.x = abs(p.x);
                    float b = (r1-r2)/h;
                    float a = sqrt(1.0-b*b);
                    float k = dot(p,float2(-b,a));
                    if( k < 0.0 ) return length(p) - r1;
                    if( k > a*h ) return length(p-float2(0.0,h)) - r2;
                    return dot(p, float2(a,b) ) - r1;
                }
            #endif

            // 心形
            #if _POINTRENDERTYPE1_HEART
                float sdHeart(float2 p)
                {
                    p.x = abs(p.x);

                    if( p.y+p.x>1.0 )
                    return sqrt(dot(p-float2(0.25,0.75), p-float2(0.25,0.75))) - sqrt(2.0)/4.0;
                    return sqrt(min(dot(p-float2(0.00,1.00), p-float2(0.00,1.00)),
                    dot(p-0.5*max(p.x+p.y,0.0), p-0.5*max(p.x+p.y,0.0)))) * sign(p.x-p.y);
                }
            #endif

            float SDFMin(float a, float b, float k){
                float h = clamp(0.5 + 0.5 * (a - b) / k, 0.0, 1.0);
                return lerp(a, b, h) - k * h * (1.0 - h);
            }
            float2 SDFRoate(float2 origin, float angle)
            {
                float sinA = sin(angle * 2 * PI);
                float cosA = cos(angle * 2 * PI);
                float2x2 roateMatrix = float2x2(cosA, -sinA,
                                                sinA, cosA);
                return mul(roateMatrix, origin);
            }

            float2 GetPosFromCenter(float2 center, float angle01, float distance)
            {
                float addX = sin(angle01 * 2 * PI) * distance;
                float addY = cos(angle01 * 2 * PI) * distance;
                return center + float2(addX, addY);
            }

            // 几个点状高光
            float GetPointsSDF(float2 pos)
            {
                float sdf = 1.0;
                #if _F_HIGHLIGHTPOINT1_ON
                    float angleMain = _PointDisAngle1 + sin(_Time.y * _PointRoateSpeed1 * 100) * _RoateRange;
                    float2 posMain = GetPosFromCenter(pos, angleMain, _PointPos1);

                    #if _F_HIGHLIGHTPOINT1ROATESELF_ON
                        posMain = SDFRoate(posMain, _Point1RoateSelf);
                    #endif

                    float distanceMain = 1.0;
                    #if _POINTRENDERTYPE1_CIRCLE
                        distanceMain = SDFSphere(0.0, posMain, _PointRadius1.x);
                    #elif _POINTRENDERTYPE1_STAR
                        distanceMain = sdStar5(posMain , _PointRadius1.x, _PointRadius1.y);
                    #elif _POINTRENDERTYPE1_MOON
                        distanceMain = sdMoon(posMain / _PointRadius1.x, _PointRadius1.y, _PointRadius1.z, _PointRadius1.w);
                    #elif _POINTRENDERTYPE1_BLOBBYCROSS
                        distanceMain = sdBlobbyCross(posMain / _PointRadius1.x, _PointRadius1.y);
                    #elif _POINTRENDERTYPE1_UNEVENCAPSULE
                        distanceMain = sdUnevenCapsule(posMain / _PointRadius1.x + float2(0,_PointRadius1.w*0.5), _PointRadius1.y, _PointRadius1.z, _PointRadius1.w); // 位置进行一定偏移修正
                    #elif _POINTRENDERTYPE1_HEART
                        distanceMain = sdHeart(posMain / _PointRadius1.x + float2(0,0.5)); // 位置进行一定偏移修正
                    #endif
                    sdf = SDFMin(distanceMain, sdf, 0.04);
                #endif

                #if _F_HIGHLIGHTPOINT2_ON
                    float anglePoint2 = _PointDisAngle2 + sin(_Time.y * _PointRoateSpeed2 * 100) * _RoateRange;
                    float2 posPoint2 = GetPosFromCenter(pos, anglePoint2, _PointPos2);
                    float distancePoint2 = SDFSphere(0.0, posPoint2, _PointRadius2);
                    sdf = SDFMin(distancePoint2, sdf, 0.04);
                #endif

                #if _F_HIGHLIGHTPOINT3_ON
                    float anglePoint3 = _PointDisAngle3 + sin(_Time.y * _PointRoateSpeed3 * 100) * _RoateRange;
                    float2 posPoint3 = GetPosFromCenter(pos, anglePoint3, _PointPos3);
                    float distancePoint3 = SDFSphere(0.0, posPoint3, _PointRadius3);
                    sdf = SDFMin(distancePoint3, sdf, 0.04);
                #endif

                #if _F_HIGHLIGHTPOINT4_ON
                    float anglePoint4 = _PointDisAngle4 + sin(_Time.y * _PointRoateSpeed4 * 100) * _RoateRange;
                    float2 posPoint4 = GetPosFromCenter(pos, anglePoint4, _PointPos4);
                    float distancePoint4 = SDFSphere(0.0, posPoint4, _PointRadius4);
                    sdf = SDFMin(distancePoint4, sdf, 0.04);
                #endif

                float blur = 0.001;
                float sdfFinal = smoothstep(blur, -blur, sdf);

                return sdfFinal;
            }

            // 外圈环状旋转高光
            float GetRingSDF(float2 pos)
            {
                #if _F_RING_ON
                    float2 posOut = GetPosFromCenter(pos, _RingDisAngle * 2.0, _RingParams.x);
                    float distanceOut = -SDFSphere(0.0, posOut, _RingParams.z);
                    float2 posIn = GetPosFromCenter(pos, _RingDisAngle * 2.0, _RingParams.y);
                    float distance = SDFSphere(0.0, posIn, _RingParams.w);
                    float sdfMix = SDFMin(distanceOut, distance, 0.15);

                    float blur = 0.001;
                    float sdfFinal = smoothstep(blur, -blur, sdfMix);
                    return sdfFinal;
                #else
                    return 0.0;
                #endif
            }

            // -----------------------------------------------------------
            // Fragment
            half4 ToonEyeFragment(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);

                // uv0必须是正圆形，上下左右位置顶到象限边缘
                float2 uv0 = input.uv0;
                float2 pos = uv0 * 2.0 - 1.0;

                float sdfFinal = GetRingSDF(pos);
                sdfFinal = lerp(GetPointsSDF(pos), sdfFinal, sdfFinal);

                float3 finalColor = _Color.rgb;

                float alpha = sdfFinal * _Color.a;

                // Debug 不使用透明
                #if _DEBUGSHOWNOALPHA_ON
                    finalColor = lerp(0.0, finalColor.rgb, sdfFinal);
                    alpha = 1;
                #endif

                ApplyGlobalSettings_Exposure(finalColor.rgb);

                return half4(finalColor.rgb, alpha);
            }

            ENDHLSL
        }

    }

    // --------------------------------------------
    CustomEditor "Scarecrow.SimpleShaderGUI"
}