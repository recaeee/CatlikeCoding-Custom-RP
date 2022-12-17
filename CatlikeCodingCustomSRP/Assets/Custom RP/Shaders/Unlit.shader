Shader "Custom RP/Unlit"
{
    Properties {}

    SubShader
    {
        Pass {
            HLSLPROGRAM
            #pragma vertex UnlitPassVertex
            #pragma fragment UnlitPassFragment
            #include "UnlitPass.hlsl"
            ENDHLSL
        }
    }
}