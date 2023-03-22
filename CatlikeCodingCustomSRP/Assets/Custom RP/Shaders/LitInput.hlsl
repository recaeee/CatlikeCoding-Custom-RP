//统一管理Lit的Input，其用于所有Pass,诞生目的为加入GI用的Meta Pass相关
#ifndef CUSTOM_LIT_INPUT_INCLUDED
#define CUSTOM_LIT_INPUT_INCLUDED

//获取Shader Properties中一些属性
//在Shader的全局变量区定义纹理的句柄和其采样器，通过名字来匹配
TEXTURE2D(_BaseMap);
TEXTURE2D(_EmissionMap);
SAMPLER(sampler_BaseMap);

//为了使用GPU Instancing，每实例数据要构建成数组,使用UNITY_INSTANCING_BUFFER_START(END)来包裹每实例数据
UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
    UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)
    UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
    UNITY_DEFINE_INSTANCED_PROP(float4, _EmissionColor)
    UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
    UNITY_DEFINE_INSTANCED_PROP(float, _Metallic)
    UNITY_DEFINE_INSTANCED_PROP(float, _Smoothness)
    UNITY_DEFINE_INSTANCED_PROP(float, _Fresnel)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

//统一传入baseUV，即使并未实际用到
float2 TransformBaseUV(float2 baseUV)
{
    float4 baseST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseMap_ST);
    return baseUV * baseST.xy + baseST.zw;
}


float4 GetBase(float2 baseUV)
{
    //获取采样纹理颜色
    //通过UNITY_ACCESS_INSTANCED_PROP获取每实例数据
    float4 map = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, baseUV);
    float4 color = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
    return map * color;
}

float GetCutoff(float2 baseUV)
{
    return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff);
}

float GetMetallic(float2 baseUV)
{
    return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Metallic);
}

float GetSmoothness(float2 baseUV)
{
    return  UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Smoothness);
}

float3 GetEmission(float2 baseUV)
{
    float4 map = SAMPLE_TEXTURE2D(_EmissionMap, sampler_BaseMap, baseUV);
    float4 color = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _EmissionColor);
    return map.rgb * color.rgb;
}

float GetFresnel(float2 baseUV)
{
    return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Fresnel);
}

#endif