Shader "Custom RP/Unlit"
{
    Properties
    {
        //[可选：特性]变量名(Inspector上的文本,类型名) = 默认值
        //[optional: attribute] name("display text in Inspector", type name) = default value
        _BaseColor("Color",Color) = (1.0,1.0,1.0,1.0)
    }

    SubShader
    {
        Pass
        {
            HLSLPROGRAM
            #pragma vertex UnlitPassVertex
            #pragma fragment UnlitPassFragment
            #include "UnlitPass.hlsl"
            ENDHLSL
        }
    }
}