//统一管理Lit的Input，其用于所有Pass,诞生目的为加入GI用的Meta Pass相关
#ifndef CUSTOM_LIT_INPUT_INCLUDED
#define CUSTOM_LIT_INPUT_INCLUDED

//更方便地获取属性
#define INPUT_PROP(name) UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, name)

//获取Shader Properties中一些属性
//在Shader的全局变量区定义纹理的句柄和其采样器，通过名字来匹配
TEXTURE2D(_BaseMap);
TEXTURE2D(_NormalMap);
TEXTURE2D(_EmissionMap);
TEXTURE2D(_MaskMap);
SAMPLER(sampler_BaseMap);
//Detail Map使用单独的采样器（即单独的UV）
TEXTURE2D(_DetailMap);
SAMPLER(sampler_DetailMap);
TEXTURE2D(_DetailNormalMap);

//为了使用GPU Instancing，每实例数据要构建成数组,使用UNITY_INSTANCING_BUFFER_START(END)来包裹每实例数据
UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
    UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)
    UNITY_DEFINE_INSTANCED_PROP(float4, _DetailMap_ST)
    UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
    UNITY_DEFINE_INSTANCED_PROP(float4, _EmissionColor)
    UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
    UNITY_DEFINE_INSTANCED_PROP(float, _Metallic)
    UNITY_DEFINE_INSTANCED_PROP(float, _Occlusion)
    UNITY_DEFINE_INSTANCED_PROP(float, _Smoothness)
    UNITY_DEFINE_INSTANCED_PROP(float, _Fresnel)
    UNITY_DEFINE_INSTANCED_PROP(float, _DetailAlbedo)
    UNITY_DEFINE_INSTANCED_PROP(float, _DetailSmoothness)
    UNITY_DEFINE_INSTANCED_PROP(float, _DetailNormalScale)
    UNITY_DEFINE_INSTANCED_PROP(float, _NormalScale)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

//用于控制Get属性时哪些会被应用
struct InputConfig
{
    float2 baseUV;
    float2 detailUV;
    //是否使用MODS Mask
    bool useMask;
    //是否使用Detail Map
    bool useDetail;
};

InputConfig GetInputConfig(float2 baseUV, float2 detailUV = 0.0)
{
    InputConfig c;
    c.baseUV = baseUV;
    c.detailUV = detailUV;
    c.useMask = false;
    c.useDetail = false;
    return c;
}

//统一传入baseUV，即使并未实际用到
float2 TransformBaseUV(float2 baseUV)
{
    float4 baseST = INPUT_PROP(_BaseMap_ST);
    return baseUV * baseST.xy + baseST.zw;
}

//Detail Map UV
float2 TransformDetailUV(float2 detailUV)
{
    float4 detailST = INPUT_PROP(_DetailMap_ST);
    return detailUV * detailST.xy + detailST.zw;
}

//值范围[-1,1]，用于增加和降低对应Property
float4 GetDetail(InputConfig c)
{
    if(c.useDetail)
    {
        float4 map = SAMPLE_TEXTURE2D(_DetailMap, sampler_DetailMap, c.detailUV);
        return map * 2.0 - 1.0;
    }
    return 0.0;
}

float4 GetMask(InputConfig c)
{
    //使用if分支，而不是关键字控制，避免分支产生，代价是一次分支判断操作，用时间换空间
    if(c.useMask)
    {
        return SAMPLE_TEXTURE2D(_MaskMap, sampler_BaseMap, c.baseUV);
    }
    return 1.0;
}

float4 GetBase(InputConfig c)
{
    //获取采样纹理颜色，RGB用作Albedo，A用作AlphaTest
    //通过UNITY_ACCESS_INSTANCED_PROP获取每实例数据
    float4 map = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, c.baseUV);
    float4 color = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);

    if(c.useDetail)
    {
        float detail = GetDetail(c).r * INPUT_PROP(_DetailAlbedo);
        //Mask的B通道为Detail贴图的遮罩
        float mask = GetMask(c).b;
        //以Detail的Albedo修正值作为权重，为baseMap的Albedo插值
        map.rgb = lerp(sqrt(map.rgb), detail < 0.0 ? 0.0 : 1.0, abs(detail) * mask);
        map.rgb *= map.rgb;
    }

    return map * color;
}

float GetCutoff(InputConfig c)
{
    return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff);
}

//在片元着色器中实际获取Metallic时会对Mask贴图无感，只需要在这里控制就行
float GetMetallic(InputConfig c)
{
    float metallic = INPUT_PROP(_Metallic);
    metallic *= GetMask(c).r;
    return metallic;
}

float GetSmoothness(InputConfig c)
{
    float smoothness = INPUT_PROP(_Smoothness);
    smoothness *= GetMask(c).a;

    if(c.useDetail)
    {
        float detail = GetDetail(c).b * INPUT_PROP(_DetailSmoothness);
        float mask = GetMask(c).b;
        smoothness = lerp(smoothness, detail < 0.0 ? 0.0 : 1.0, abs(detail) * mask);
    }
    
    return smoothness;
}

float3 GetEmission(InputConfig c)
{
    float4 map = SAMPLE_TEXTURE2D(_EmissionMap, sampler_BaseMap, c.baseUV);
    float4 color = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _EmissionColor);
    return map.rgb * color.rgb;
}

float GetFresnel(InputConfig c)
{
    return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Fresnel);
}

float GetOcclusion(InputConfig c)
{
    float strength = INPUT_PROP(_Occlusion);
    float occlusion = GetMask(c).g;
    occlusion = lerp(1.0, occlusion, strength);
    return occlusion;
}

float3 GetNormalTS(InputConfig c)
{
    //采样未解码的法线
    float4 map = SAMPLE_TEXTURE2D(_NormalMap, sampler_BaseMap, c.baseUV);
    float scale = INPUT_PROP(_NormalScale);
    float3 normal = DecodeNormal(map, scale);

    if(c.useDetail)
    {
        //采样法线细节贴图
        map = SAMPLE_TEXTURE2D(_DetailNormalMap, sampler_DetailMap, c.detailUV);
        scale = INPUT_PROP(_DetailNormalScale) * GetMask(c).b;
        float3 detail = DecodeNormal(map, scale);
        normal = BlendNormalRNM(normal, detail);
    }
    
    return normal;
}



#endif