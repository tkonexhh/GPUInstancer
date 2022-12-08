
#ifndef TOON_INPUT_CLIP_TEX_INCLUDED
#define TOON_INPUT_CLIP_TEX_INCLUDED

#if __RENDERMODE_CUTOUT
    #if _USECLIPPINGMASK_ON
        TEXTURE2D(_ClippingMask);
        SAMPLER(sampler_ClippingMask);
    #endif
#endif

#endif