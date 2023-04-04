//用来在Lit中采样阴影贴图
#ifndef CUSTOM_SHADOWS_INCLUDED
#define CUSTOM_SHADOWS_INCLUDED

//使用Core RP的软阴影采样函数
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary//Shadow/ShadowSamplingTent.hlsl"

#if defined(_DIRECTIONAL_PCF3)
    //对于3x3模式，采样4次2x2模式
    #define DIRECTIONAL_FILTER_SAMPLES 4
    #define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_3x3
#elif defined(_DIRECTIONAL_PCF5)
    #define DIRECTIONAL_FILTER_SAMPLES 9
    #define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_5x5
#elif defined(_DIRECTIONAL_PCF7)
    #define DIRECTIONAL_FILTER_SAMPLES 16
    #define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_7x7
#endif

#if defined(_OTHER_PCF3)
    //对于3x3模式，采样4次2x2模式
    #define OTHER_FILTER_SAMPLES 4
    #define OTHER_FILTER_SETUP SampleShadow_ComputeSamples_Tent_3x3
#elif defined(_OTHER_PCF5)
    #define OTHER_FILTER_SAMPLES 9
    #define OTHER_FILTER_SETUP SampleShadow_ComputeSamples_Tent_5x5
#elif defined(_OTHER_PCF7)
    #define OTHER_FILTER_SAMPLES 16
    #define OTHER_FILTER_SETUP SampleShadow_ComputeSamples_Tent_7x7
#endif

//宏定义最大支持阴影的方向光源数，要与CPU端同步，为4
#define MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT 4
//定义最大支持阴影的其他光源数
#define MAX_SHADOWED_OTHER_LIGHT_COUNT 16
//宏定义最大级联数为4
#define MAX_CASCADE_COUNT 4

//接收CPU端传来的ShadowAtlas
//使用TEXTURE2D_SHADOW来明确我们接收的是阴影贴图
TEXTURE2D_SHADOW(_DirectionalShadowAtlas);
TEXTURE2D_SHADOW(_OtherShadowAtlas);
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
    //每个级联的信息
    float4 _CascadeData[MAX_CASCADE_COUNT];
    //接收CPU端传来的每个Shadow Tile(级联）的阴影变换矩阵
    float4x4 _DirectionalShadowMatrices[MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT * MAX_CASCADE_COUNT];
    float4x4 _OtherShadowMatrices[MAX_SHADOWED_OTHER_LIGHT_COUNT];
    //其他光源每个Tile的信息 w：1m距离下的纹素大小
    float4 _OtherShadowTiles[MAX_SHADOWED_OTHER_LIGHT_COUNT];
    //PCF需要的阴影贴图信息
    float4 _ShadowAtlasSize;
    //Vector2(最大阴影距离,渐变距离比例）
    float4 _ShadowDistanceFade;

CBUFFER_END

//每个方向光源的的阴影信息（包括不支持阴影的光源，不支持，其阴影强度就是0）
struct DirectionalShadowData
{
    float strength;
    int tileIndex;
    //阴影法线偏移的系数
    float normalBias;
    //使用的shadowMask通道索引，-1表示不使用shadowmask
    int shadowMaskChannel;
};

//其他光源的阴影信息
struct OtherShadowData
{
    float strength;
    int tileIndex;
    //是否是点光源
    bool isPoint;
    //使用的shadowMask通道索引，-1表示不使用shadowmask
    int shadowMaskChannel;
    //用于计算法线偏移
    float3 lightPositionWS;
    //光源方向，用于采样点光源Cubemap
    float3 lightDirectionWS;
    float3 spotDirectionWS;
};

//阴影遮罩信息
struct ShadowMask
{
    //是否使用shadowmask模式，静态物体不投射实时阴影
    bool always;
    //是否使用distance shadow mask，当_SHADOW_MASK_DISTANCE关键字开启时，该值为True
    bool distance;
    //采样阴影遮罩图的颜色结果
    float4 shadows;
};

//定义每个片元（world space surface)的级联信息
struct ShadowData
{
    //当前片元使用的级联索引
    int cascadeIndex;
    //级联混合插值
    float cascadeBlend;
    //级联阴影的强度，0阴影最淡消失，1阴影完全存在，用来控制不同距离级联阴影过渡
    float strength;
    //阴影遮罩信息
    ShadowMask shadowMask;
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
    //初始化阴影遮罩信息
    data.shadowMask.always = false;
    data.shadowMask.distance = false;
    data.shadowMask.shadows = 1.0;
    //默认级联混合插值为1，表示完全使用当前级联
    data.cascadeBlend = 1.0;
    data.strength = FadedShadowStrength(surfaceWS.depth,_ShadowDistanceFade.x,_ShadowDistanceFade.y);
    // data.strength = 1;
    int i;
    for(i=0;i<_CascadeCount;i++)
    {
        float4 sphere = _CascadeCullingSpheres[i];
        float distanceSqr = DistanceSquared(surfaceWS.position,sphere.xyz);
        if(distanceSqr < sphere.w)
        {
            float fade = FadedShadowStrength(distanceSqr, _CascadeData[i].x, _ShadowDistanceFade.z);
            //对最大级联处做特殊的过渡
            if(i==_CascadeCount - 1)
            {
                data.strength *= fade;
            }
            else
            {
                data.cascadeBlend = fade;
            }
            break;
        }
    }
    if(i==_CascadeCount && _CascadeCount > 0)
    {
        data.strength = 0.0;
    }
    #if defined(_CASCADE_BLEND_DITHER)
        //不在最后一级抖动
        //对于过渡处的片元做抖动，让不同片元抖动到不同级联等级上采样，类似于早期透明混合的棋盘算法吧，抖动算法配合后处理的AA效果很好
        else if (data.cascadeBlend < surfaceWS.dither)
        {
            i += 1;
        }
    #endif
    //在未定义软阴影过渡时，Blend设为1，不采样多个级联图
    #if !defined(_CASCADE_BLEND_SOFT)
        data.cascadeBlend = 1.0;
    #endif
    data.cascadeIndex = i;
    return data;
}

//采样ShadowAtlas，传入positionSTS（STS是Shadow Tile Space，即阴影贴图对应Tile像素空间下的片元坐标）
float SampleDirectionalShadowAtlas(float3 positionSTS)
{
    //使用特定宏来采样阴影贴图
    return SAMPLE_TEXTURE2D_SHADOW(_DirectionalShadowAtlas,SHADOW_SAMPLER,positionSTS);
}

//使用PCF采样软阴影
float FilterDirectionalShadow(float3 positionSTS)
{
    #if defined(DIRECTIONAL_FILTER_SETUP)
        //out:每个采样结果的权重
        float weights[DIRECTIONAL_FILTER_SAMPLES];
        //out:每个采样的坐标
        float2 positions[DIRECTIONAL_FILTER_SAMPLES];
        //in：texelSizeX,texelSizeY,AtlasSizeX,AtlasSizeY
        float4 size = _ShadowAtlasSize.yyxx;
        //获取所有待采样点的坐标和权重
        DIRECTIONAL_FILTER_SETUP(size,positionSTS.xy,weights,positions);
        float shadow = 0;
        //采样并加权
        for(int i=0;i<DIRECTIONAL_FILTER_SAMPLES;i++)
        {
            shadow += weights[i] * SampleDirectionalShadowAtlas(float3(positions[i].xy,positionSTS.z));
        }
        return shadow;
    #else
        return SampleDirectionalShadowAtlas(positionSTS);
    #endif
}

//采样ShadowAtlas，传入positionSTS（STS是Shadow Tile Space，即阴影贴图对应Tile像素空间下的片元坐标）
float SampleOtherShadowAtlas(float3 positionSTS, float3 bounds)
{
    positionSTS.xy = clamp(positionSTS.xy, bounds.xy, bounds.xy + bounds.z);
    //使用特定宏来采样阴影贴图
    return SAMPLE_TEXTURE2D_SHADOW(_OtherShadowAtlas,SHADOW_SAMPLER,positionSTS);
}

//使用PCF采样软阴影
float FilterOtherShadow(float3 positionSTS, float3 bounds)
{
    //out:每个采样结果的权重
    #if defined(OTHER_FILTER_SETUP)
    float weights[OTHER_FILTER_SAMPLES];
    //out:每个采样的坐标
    float2 positions[OTHER_FILTER_SAMPLES];
    //in：texelSizeX,texelSizeY,AtlasSizeX,AtlasSizeY
    float4 size = _ShadowAtlasSize.wwzz;
    //获取所有待采样点的坐标和权重
    OTHER_FILTER_SETUP(size,positionSTS.xy,weights,positions);
    float shadow = 0;
    //采样并加权
    for(int i=0;i<OTHER_FILTER_SAMPLES;i++)
    {
        shadow += weights[i] * SampleOtherShadowAtlas(float3(positions[i].xy,positionSTS.z), bounds);
    }
    return shadow;
    #else
    return SampleOtherShadowAtlas(positionSTS, bounds);
    #endif
}

//计算实时阴影
float GetCascadedShadow(DirectionalShadowData directional, ShadowData global, Surface surfaceWS)
{
    //计算法线偏移
    float3 normalBias = surfaceWS.interpolatedNormal * (directional.normalBias * _CascadeData[global.cascadeIndex].y);
    //根据对应Tile阴影变换矩阵和(经过法线偏移后)片元的世界坐标计算Tile上的像素坐标STS
    float3 positionSTS = mul(_DirectionalShadowMatrices[directional.tileIndex], float4(surfaceWS.position+normalBias,1.0)).xyz;
    //采样Tile得到阴影强度值
    float shadow = FilterDirectionalShadow(positionSTS);
    //考虑级联混合，采样下一级别的级联并混合而得到阴影强度值
    if(global.cascadeBlend < 1.0)
    {
        normalBias = surfaceWS.interpolatedNormal * (directional.normalBias * _CascadeData[global.cascadeIndex + 1].y);
        positionSTS = mul(_DirectionalShadowMatrices[directional.tileIndex + 1],float4(surfaceWS.position + normalBias,1.0)).xyz;
        shadow = lerp(FilterDirectionalShadow(positionSTS),shadow,global.cascadeBlend);
    }
    return shadow;
}

//计算混合用的烘培阴影
float GetBakedShadow(ShadowMask mask, int channel)
{
    float shadow = 1.0;
    if(mask.always || mask.distance)
    {
        if(channel >= 0)
        {
            shadow = mask.shadows[channel];
        }
        
    }
    return shadow;
}

//无论何时都可用的获取烘培阴影，传入的strength用于控制静态阴影强度
float GetBakedShadow(ShadowMask mask, int channel, float strength)
{
    if(mask.always || mask.distance)
    {
        return lerp(1.0, GetBakedShadow(mask, channel), strength);
    }
    return 1.0;
}

//混合实时阴影和静态阴影，如果使用ShadowMask则完全使用烘培阴影，其中传入的shadow为实时阴影衰减度
float MixBakedAndRealtimeShadows(ShadowData global, float shadow, int shadowMaskChannel, float strength)
{
    float baked = GetBakedShadow(global.shadowMask, shadowMaskChannel);
    if(global.shadowMask.always)
    {
        shadow = lerp(1.0, shadow, global.strength);
        shadow = min(baked, shadow);
        return lerp(1.0, shadow, strength);
    }
    if(global.shadowMask.distance)
    {
        //global.strength表示阴影级联的强度，0表示最大级联，即无阴影，因此完全使用烘培阴影，其余则过渡。
        shadow = lerp(baked, shadow, global.strength);
        return lerp(1.0,shadow, strength);
    }
    return lerp(1.0, shadow, strength * global.strength);
}

//计算阴影衰减值，返回值[0,1]，0代表阴影衰减最大（片元完全在阴影中），1代表阴影衰减最少，片元完全被光照射。而[0,1]的中间值代表片元有一部分在阴影中
float GetDirectionalShadowAttenuation(DirectionalShadowData directional, ShadowData global, Surface surfaceWS)
{
    //考虑不接受阴影
    #if !defined(_RECEIVE_SHADOWS)
        return 1.0;
    #endif
    //忽略不开启阴影和阴影强度为0的光源
    float shadow;
    if(directional.strength * global.strength <= 0.0)
    {
        shadow =  GetBakedShadow(global.shadowMask, directional.shadowMaskChannel, abs(directional.strength));
    }
    else
    {
        shadow = GetCascadedShadow(directional,global,surfaceWS);
        //考虑光源的阴影强度，strength为0，依然没有阴影
        shadow = MixBakedAndRealtimeShadows(global, shadow, directional.shadowMaskChannel, directional.strength);
    }
    return shadow;
}

//点光源6个Tile面法线，从面指向圆心
static const float3 pointShadowPlanes[6] = {
    float3(-1.0, 0.0, 0.0),
    float3(1.0, 0.0, 0.0),
    float3(0.0, -1.0, 0.0),
    float3(0.0, 1.0, 0.0),
    float3(0.0, 0.0, -1.0),
    float3(0.0, 0.0, 1.0)
};

float GetOtherShadow(OtherShadowData other, ShadowData global, Surface surfaceWS)
{
    float tileIndex = other.tileIndex;
    float3 lightPlane = other.spotDirectionWS;
    if(other.isPoint)
    {
        //找到片元属于的那一面Cubemap
        float faceOffset = CubeMapFaceID(-other.lightDirectionWS);
        tileIndex += faceOffset;
        //找到该面的法线（指向圆心）
        lightPlane = pointShadowPlanes[faceOffset];
    }
    float4 tileData = _OtherShadowTiles[tileIndex];
    float3 surfaceToLight = other.lightPositionWS - surfaceWS.position;
    //计算片元到聚光灯中心的垂直距离
    float distanceToLightPlane = dot(surfaceToLight, lightPlane);
    //获取距离为1的法线偏移
    float3 normalBias = surfaceWS.interpolatedNormal * (distanceToLightPlane * tileData.w);
    float4 positionSTS = mul(_OtherShadowMatrices[tileIndex], float4(surfaceWS.position + normalBias, 1.0));
    return FilterOtherShadow(positionSTS.xyz / positionSTS.w, tileData.xyz);
}

//计算阴影衰减值，返回值[0,1]，0代表阴影衰减最大（片元完全在阴影中），1代表阴影衰减最少，片元完全被光照射。而[0,1]的中间值代表片元有一部分在阴影中
float GetOtherShadowAttenuation(OtherShadowData other, ShadowData global, Surface surfaceWS)
{
    #if !defined(_RECEIVE_SHADOWS)
        return 1.0;
    #endif

    float shadow;
    if(other.strength * global.strength <= 0.0)
    {
        shadow = GetBakedShadow(global.shadowMask, other.shadowMaskChannel, abs(other.strength));
    }
    else
    {
        shadow = GetOtherShadow(other, global, surfaceWS);
        shadow = MixBakedAndRealtimeShadows(global, shadow, other.shadowMaskChannel, other.strength);
    }
    return shadow;
}





#endif
