//统一管理Unlit所有Pass的Input
#ifndef CUSTOM_LIT_INPUT_INCLUDED
#define CUSTOM_LIT_INPUT_INCLUDED

//更方便地获取属性
#define INPUT_PROP(name) UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, name)

//获取Shader Properties中一些属性
//在Shader的全局变量区定义纹理的句柄和其采样器，通过名字来匹配
TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);

//为了使用GPU Instancing，每实例数据要构建成数组,使用UNITY_INSTANCING_BUFFER_START(END)来包裹每实例数据
UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
    UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)
    UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
    UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

//用于控制Get属性时哪些会被应用
struct InputConfig
{
    float2 baseUV;
    float2 detailUV;
};

InputConfig GetInputConfig(float2 baseUV, float2 detailUV = 0.0)
{
    InputConfig c;
    c.baseUV = baseUV;
    c.detailUV = detailUV;
    return c;
}

//统一传入baseUV，即使并未实际用到
float2 TransformBaseUV(float2 baseUV)
{
    float4 baseST = INPUT_PROP(_BaseMap_ST);
    return baseUV * baseST.xy + baseST.zw;
}


float4 GetBase(InputConfig c)
{
    //获取采样纹理颜色
    //通过UNITY_ACCESS_INSTANCED_PROP获取每实例数据
    float4 map = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, c.baseUV);
    float4 color = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
    return map * color;
}

float GetCutoff(InputConfig c)
{
    return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff);
}

float GetMetallic(InputConfig c)
{
    return 0.0;
}

float GetSmoothness(InputConfig c)
{
    return 0.0;
}

//Unlit的自发光直接按BaseMap，全部发光
float3 GetEmission(InputConfig c)
{
    return GetBase(c).rgb;
}

float GetFresnel(float2 baseUV)
{
    return 0.0;
}

#endif