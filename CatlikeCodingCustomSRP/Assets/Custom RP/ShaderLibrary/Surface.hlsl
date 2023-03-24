//定义与光照相关的物体表面属性
//HLSL编译保护机制
#ifndef CUSTOM_SURFACE_INCLUDED
#define CUSTOM_SURFACE_INCLUDED

//物体表面属性，该结构体在片元着色器中被构建
struct Surface
{
    //片元的世界坐标
    float3 position;
    //法线，在这里不明确其坐标空间，因为光照可以在任何空间下计算，在该项目中使用世界空间
    float3 normal;
    //顶点原始法线，用于阴影贴图偏移
    float3 interpolatedNormal;
    //观察方向：物体表面指向摄像机
    float3 viewDirection;
    //表面颜色
    float3 color;
    //透明度
    float alpha;
    //金属度
    float metallic;
    //遮蔽
    float occlusion;
    //光滑度
    float smoothness;
    //观察空间下的深度值(z值)
    float depth;
    //菲涅尔强度系数
    float fresnelStrength;
    //级联混合抖动值
    float dither;
};

#endif
