//用来定义光源属性
#ifndef CUSTOM_LIGHT_INCLUDED
#define CUSTOM_LIGHT_INCLUDED

//使用宏定义最大方向光源数，需要与cpu端匹配
#define MAX_DIRECTIONAL_LIGHT_COUNT 4
#define MAX_OTHER_LIGHT_COUNT 64

//用CBuffer包裹构造方向光源的两个属性，cpu会每帧传递（修改）这两个属性到GPU的常量缓冲区，对于一次渲染过程这两个值恒定
CBUFFER_START(_CustomLight)
    //当前有效光源数
    int _DirectionalLightCount;
    //注意CBUFFER中创建数组的格式,在Shader中数组在创建时必须明确其长度，创建完毕后不允许修改
    float4 _DirectionalLightColors[MAX_DIRECTIONAL_LIGHT_COUNT];
    float4 _DirectionalLightDirections[MAX_DIRECTIONAL_LIGHT_COUNT];
    //ShadowData实际是Vector2，但是依然使用Vector4包装
    float4 _DirectionalLightShadowData[MAX_DIRECTIONAL_LIGHT_COUNT];

    int _OtherLightCount;
    float4 _OtherLightColors[MAX_OTHER_LIGHT_COUNT];
    float4 _OtherLightPositions[MAX_OTHER_LIGHT_COUNT];
    float4 _OtherLightDirections[MAX_OTHER_LIGHT_COUNT];
    float4 _OtherLightSpotAngles[MAX_OTHER_LIGHT_COUNT];
    float4 _OtherLightShadowData[MAX_OTHER_LIGHT_COUNT];
CBUFFER_END

struct Light
{
    //光源颜色
    float3 color;
    //光源方向：指向光源
    float3 direction;
    //光源衰减，1表示不衰减
    float attenuation;
};

int GetDirectionalLightCount()
{
    return _DirectionalLightCount;
}

int GetOtherLightCount()
{
    return _OtherLightCount;
}

//根据光源索引和当前级联信息，对于每个片元，构造光源的ShadowData
DirectionalShadowData GetDirectionalShadowData(int lightIndex, ShadowData shadowData)
{
    DirectionalShadowData data;
    //阴影强度(考虑级联过渡的阴影强度）
    data.strength = _DirectionalLightShadowData[lightIndex].x;
    //Tile索引
    data.tileIndex = _DirectionalLightShadowData[lightIndex].y + shadowData.cascadeIndex;
    //阴影法线偏移系数
    data.normalBias = _DirectionalLightShadowData[lightIndex].z;
    //shadowmask通道索引
    data.shadowMaskChannel = _DirectionalLightShadowData[lightIndex].w;
    return data;
}

//对于每个片元，构造一个方向光源并返回，其颜色与方向取自常量缓冲区的数组中index下标处
Light GetDirectionalLight(int index, Surface surfaceWS, ShadowData shadowData)
{
    Light light;
    //float4的rgb和xyz完全等效
    light.color = _DirectionalLightColors[index].rgb;
    light.direction = _DirectionalLightDirections[index].xyz;
    //构造光源阴影信息
    DirectionalShadowData dirShadowData = GetDirectionalShadowData(index, shadowData);
    //计算片元对应的光源衰减度
    light.attenuation = GetDirectionalShadowAttenuation(dirShadowData, shadowData, surfaceWS);
    // light.attenuation = shadowData.cascadeIndex * 0.25;
    return light;
}

OtherShadowData GetOtherShadowData(int lightIndex)
{
    OtherShadowData data;
    data.strength = _OtherLightShadowData[lightIndex].x;
    data.tileIndex = _OtherLightShadowData[lightIndex].y;
    data.shadowMaskChannel = _OtherLightShadowData[lightIndex].w;
    data.isPoint = _OtherLightShadowData[lightIndex].z == 1.0;
    data.lightPositionWS = 0.0;
    data.lightDirectionWS = 0.0;
    data.spotDirectionWS = 0.0;
    return data;
}

//对于每个片元，构造一个其他光源，每个片元的光源方向都不一样（从片元位置指向光源位置）
Light GetOtherLight(int index, Surface surfaceWS, ShadowData shadowData)
{
    Light light;
    light.color = _OtherLightColors[index].rgb;
    float3 position = _OtherLightPositions[index].xyz;
    float3 ray = position - surfaceWS.position;
    light.direction = normalize(ray);
    //考虑距离对其他光源的衰减
    float distanceSqr = max(dot(ray, ray), 0.00001);
    //考虑光源作用范围造成的衰减
    float rangeAttenuation = Square(saturate(1.0 - Square(distanceSqr * _OtherLightPositions[index].w)));
    //考虑聚光灯方向造成的衰减
    float4 spotAngles = _OtherLightSpotAngles[index];
    float3 spotDirection = _OtherLightDirections[index].xyz;
    float spotAttenuation = Square(saturate(dot(spotDirection, light.direction) *
            spotAngles.x + spotAngles.y));
    //考虑阴影遮罩
    OtherShadowData otherShadowData = GetOtherShadowData(index);
    //配置光源的位置和方向，用于计算法线偏移
    otherShadowData.lightPositionWS = position;
    otherShadowData.lightDirectionWS = light.direction;
    otherShadowData.spotDirectionWS = spotDirection;
    
    light.attenuation = GetOtherShadowAttenuation(otherShadowData, shadowData, surfaceWS) * spotAttenuation * rangeAttenuation / distanceSqr;
    return light;
}



#endif
