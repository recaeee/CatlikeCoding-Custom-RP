#ifndef CUSTOM_UNLIT_PASS_INCLUDED
#define CUSTOM_UNLIT_PASS_INCLUDED

float4 UnlitPassVertex() : SV_POSITION
{
    return 0.0;
}

float4 UnlitPassFragment() : SV_TARGET
{
    return 0.0;
}

#endif
