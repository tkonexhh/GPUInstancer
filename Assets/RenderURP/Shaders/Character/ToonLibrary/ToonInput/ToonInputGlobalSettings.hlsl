
#ifndef TOON_INPUT_EXPOSURE_INCLUDED
#define TOON_INPUT_EXPOSURE_INCLUDED

half _CharacterExposureMulti;

void ApplyGlobalSettings_Exposure(inout half3 color)
{
    #if _GLOBALRENDERSETTINGSENABLEKEYWORD
        color *= _CharacterExposureMulti;
    #endif
}

#endif