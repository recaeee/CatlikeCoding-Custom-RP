//用来采样阴影贴图
#ifndef CUSTOM_SHADOWS_INCLUDED
#define CUSTOM_SHADOWS_INCLUDED

//宏定义最大支持阴影的方向光源数，要与CPU端同步，为4
#define MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT 4
//宏定义最大级联数为4
#define MAX_CASCADE_COUNT 4

//接收CPU端传来的ShadowAtlas
//使用TEXTURE2D_SHADOW来明确我们接收的是阴影贴图
TEXTURE2D_SHADOW(_DirectionalShadowAtlas);
//阴影贴图只有一种采样方式，因此我们显式定义一个阴影采样器状态（不需要依赖任何纹理），其名字为sampler_linear_clamp_compare(使用宏定义它为SHADOW_SAMPLER)
//由此，对于任何阴影贴图，我们都可以使用SHADOW_SAMPLER这个采样器状态
//sampler_linear_clamp_compare这个取名十分有讲究，Unity会将这个名字翻译成使用Linear过滤、Clamp包裹的用于深度比较的采样器
#define SHADOW_SAMPLER sampler_linear_clamp_compare
SAMPLER_CMP(SHADOW_SAMPLER);

//接收CPU端传来的级联信息、阴影变换举证
CBUFFER_START(_CustomShadows)
    //级联数
    int _CascadeCount;
    //最多4个级联球信息
    float4 _CascadeCullingSpheres[MAX_CASCADE_COUNT];
    //接收CPU端传来的每个Shadow Tile(级联）的阴影变换矩阵
    float4x4 _DirectionalShadowMatrices[MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT * MAX_CASCADE_COUNT];
    //Vector2(最大阴影距离,渐变距离比例）
    float4 _ShadowDistanceFade;
CBUFFER_END

//每个方向光源的的阴影信息（包括不支持阴影的光源，不支持，其阴影强度就是0）
struct DirectionalShadowData
{
    float strength;
    int tileIndex;
};

//采样ShadowAtlas，传入positionSTS（STS是Shadow Tile Space，即阴影贴图对应Tile像素空间下的片元坐标）
float SampleDirectionalShadowAtlas(float3 positionSTS)
{
    //使用特定宏来采样阴影贴图
    return SAMPLE_TEXTURE2D_SHADOW(_DirectionalShadowAtlas,SHADOW_SAMPLER,positionSTS);
}

//计算阴影衰减值，返回值[0,1]，0代表阴影衰减最大（片元完全在阴影中），1代表阴影衰减最少，片元完全被光照射。而[0,1]的中间值代表片元有一部分在阴影中
float GetDirectionalShadowAttenuation(DirectionalShadowData data, Surface surfaceWS)
{
    //忽略不开启阴影和阴影强度为0的光源
    if(data.strength <= 0.0)
    {
        return 1.0;
    }
    //根据对应Tile阴影变换矩阵和片元的世界坐标计算Tile上的像素坐标STS
    float3 positionSTS = mul(_DirectionalShadowMatrices[data.tileIndex], float4(surfaceWS.position,1.0)).xyz;
    //采样Tile得到阴影强度值
    float shadow = SampleDirectionalShadowAtlas(positionSTS);
    //考虑光源的阴影强度，strength为0，依然没有阴影
    return lerp(1.0,shadow,data.strength);
}

//定义每个片元（world space surface)的级联信息
struct ShadowData
{
    //当前片元使用的级联索引
    int cascadeIndex;
    //级联阴影的强度，0阴影最淡消失，1阴影完全存在，用来控制不同距离级联阴影过渡
    float strength;
};

/**
 * \brief 计算考虑渐变的级联阴影强度
 * \param distance 当前片元深度
 * \param scale 1/maxDistance 将当前片元深度缩放到 [0,1]内
 * \param fade 渐变比例，值越大，开始衰减的距离越远，衰减速度越大
 * \return 级联阴影强度
 */
float FadedShadowStrength(float distance,float scale,float fade)
{
    //saturate抑制了近处的级联阴影强度到1
    return saturate((1.0 - distance * scale) * fade);
}

//计算给定片元将要使用的级联信息
ShadowData GetShadowData(Surface surfaceWS)
{
    ShadowData data;
    data.strength = FadedShadowStrength(surfaceWS.depth,_ShadowDistanceFade.x,_ShadowDistanceFade.y);
    // data.strength = 1;
    int i;
    for(i=0;i<_CascadeCount;i++)
    {
        float4 sphere = _CascadeCullingSpheres[i];
        float distanceSqr = DistanceSquared(surfaceWS.position,sphere.xyz);
        if(distanceSqr < sphere.w)
        {
            //对最大级联处做特殊的过渡
            if(i==_CascadeCount - 1)
            {
                data.strength *= FadedShadowStrength(distanceSqr, 1.0 / sphere.w, _ShadowDistanceFade.z);
            }
            break;
        }
    }
    if(i==_CascadeCount)
    {
        data.strength = 0.0;
    }
    data.cascadeIndex = i;
    return data;
}

#endif
