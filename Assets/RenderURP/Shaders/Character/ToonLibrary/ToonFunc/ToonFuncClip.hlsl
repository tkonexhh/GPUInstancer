
#ifndef TOON_FUNC_CLIP_INCLUDED
#define TOON_FUNC_CLIP_INCLUDED

void CheckClip(float clipMask, float2 uv)
{
    #if __RENDERMODE_CUTOUT
        #if _USECLIPPINGMASK_ON
            clipMask = SAMPLE_TEXTURE2D(_ClippingMask, sampler_ClippingMask, TRANSFORM_TEX(uv, _ClippingMask)).r;
        #endif
        #if _INVERSECLIPPING_ON
            clipMask = 1 - clipMask;
        #endif
        clipMask = saturate(clipMask + _ClippingLevel);
        clip(clipMask - 0.5);
    #endif
}

#endif