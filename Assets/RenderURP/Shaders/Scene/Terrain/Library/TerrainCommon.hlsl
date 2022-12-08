#ifndef TERRAINBLEND_COMMON_INCLUDED
#define TERRAINBLEND_COMMON_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

float4 CalculateContrast(float contrast, float4 target)
{
    float t = 0.5 * (1.0 - contrast);
    float4x4 mat = float4x4(contrast,0,0,t, 
                            0,contrast,0,t, 
                            0,0,contrast,t, 
                            0,0,0,1);
    return mul(mat, target);
}

float2 Get_UV_Rotation(float rad, float2 uv)
{
    float2 cos_sin = float2(cos(rad), sin(rad));
    float2x2 rotation = float2x2(cos_sin.x, -cos_sin.y, cos_sin.y, cos_sin.x);

    return mul(uv - 0.5, rotation) + 0.5;
}

float2 UV_Tiling_Rotation(float2 uv, float tiling, float angle, float speed)
{
    float rad = radians(angle);
    float2 uv_ret = Get_UV_Rotation(rad, uv * tiling);
    uv_ret += _Time.x * speed;

    return uv_ret;
}

float3 GetNormalPuddle(TEXTURE2D_PARAM(normalMap, sampler_normalMap), float2 uv, float tiling, float angle, float speed, float intensity)
{
    uv = UV_Tiling_Rotation(uv, tiling, angle, speed);
    return UnpackNormalScale(SAMPLE_TEXTURE2D(normalMap, sampler_normalMap, uv), intensity);
}

float3 GetNormalPipple(TEXTURE2D_PARAM(normalMap, sampler_normalMap), float2 uv, float4 st, float intensity)
{
    uv = frac(uv) * st.xy + st.zw;
    return UnpackNormalScale(SAMPLE_TEXTURE2D(normalMap, sampler_normalMap, uv), intensity);
}

// 涟漪uv偏移
float4 GetRippleAnim_ST(float4 col_row_speed_start)
{
    float4 st = 0;

    float col = col_row_speed_start.x;
    float row = col_row_speed_start.y;
    float speed = col * row * col_row_speed_start.z;
    float speed_w = col_row_speed_start.w;
    
    st.xy = 1.0f / float2(col, row);

    // *** BEGIN Flipbook UV Animation vars ***
    float tiles = col * row;
    speed *= _Time.y;

    float current_tile_index = round(fmod(speed + speed_w, tiles));
    current_tile_index += current_tile_index < 0 ? tiles : 0;

    float idx = round(fmod(current_tile_index, col));
    float idy = round(fmod((current_tile_index - idx) / col, row));
    idy = (int)(row - 1) - idy;
    // *** END Flipbook UV Animation vars ***

    st.zw = float2(idx, idy) * st.xy;

    return st;
}

float2 voronoi_hash( float2 p )
{
    p = float2( dot( p, float2( 127.1, 311.7 ) ), dot( p, float2( 269.5, 183.3 ) ) );
    return frac( sin( p ) *43758.5453);
}

float voronoi( float2 v, float time, inout float2 id, inout float2 mr, float smoothness )
{
    float2 n = floor( v );
    float2 f = frac( v );
    float F1 = 8.0;
    float F2 = 8.0; float2 mg = 0;
    UNITY_UNROLL
    for ( int j = -1; j <= 1; j++ )
    {
        UNITY_UNROLL
        for ( int i = -1; i <= 1; i++ )
        {
            float2 g = float2( i, j );
            float2 o = voronoi_hash( n + g );
            o = ( sin( time + o * 6.2831 ) * 0.5 + 0.5 ); float2 r = f - g - o;
            float d = 0.5 * dot( r, r );
            if( d<F1 ) {
                F2 = F1;
                F1 = d; mg = g; mr = r; id = o;
            } else if( d<F2 ) {
                F2 = d;
            }
        }
    }
    return F1;
}

float Get_Roughness_Voronoi(TEXTURE2D_PARAM(tex, sampler_tex), float2 uv, float tiling, float speed, float size, float intensity)
{
    float2 uv_voronoi = uv * tiling;
    float2 id_voronoi = 0;
    float var_voronoi = 0;
    float weight_voronoi = 0.5;
    float weight_total = 0;

    float2 mr = 0;

    [unroll(2)]
    for(int iter = 0; iter < 2; iter ++)
    {
        // float2 v, float time, inout float2 id, inout float2 mr, float smoothness
        var_voronoi += weight_voronoi * voronoi(uv_voronoi, 0.001, id_voronoi, mr, 0);
        weight_total += weight_voronoi;
        uv_voronoi *= 2;
        weight_voronoi *= 0.5;
    }
    var_voronoi /= weight_total;

    uv_voronoi = _Time.y * speed + step(var_voronoi, 0.1) * id_voronoi;
    float roughness = SAMPLE_TEXTURE2D(tex, sampler_tex, uv_voronoi).g;

    roughness = saturate(roughness * step(var_voronoi, size * 0.05));
    roughness *= intensity;

    return roughness;
}


#endif // TERRAINBLEND_COMMON_INCLUDED
