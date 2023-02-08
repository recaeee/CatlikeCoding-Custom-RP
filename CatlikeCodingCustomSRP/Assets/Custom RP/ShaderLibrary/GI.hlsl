//管理全局光照GI
#ifndef CUSTOM_GI_INCLUDED
#define CUSTOM_GI_INCLUDED

//用于获取光源信息
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"

//GPU接收到的光照贴图名为unity_Lightmap
TEXTURE2D(unity_Lightmap);
SAMPLER(samplerunity_Lightmap);

//使用宏定义GI数据和相关函数
#if defined(LIGHTMAP_ON)
    //顶点光照贴图UV信息从第二个TEXCOORD通道提供，第一个通道提供顶点baseUV
    #define GI_ATTRIBUTE_DATA float2 lightMapUV:TEXCOORD1;
    #define GI_VARYINGS_DATA float2 lightMapUV:VAR_LIGNT_MAP_UV;
    #define TRANSFER_GI_DATA(input,output) \
        output.lightMapUV = input.lightMapUV * \
        unity_LightmapST.xy + unity_LightmapST.zw;
    #define GI_FRAGMENT_DATA(input) input.lightMapUV
#else
    //不开启LIGHTMAP_ON关键字时，相关代码不参与编译
    #define GI_ATTRIBUTE_DATA
    #define GI_VARYINGS_DATA
    #define TRANSFER_GI_DATA(input,output)
    #define GI_FRAGMENT_DATA(input) 0.0
#endif

//场景中一块表面片元的GI信息
struct GI
{
    //片元接收到的GI光照结果，该光照结果为光照贴图上采样得到，这部分光照能量会被全部以漫反射形式在表面反射出去。
    float3 diffuse;
};

//采样光照贴图
float3 SampleLightMap(float2 lightMapUV)
{
    #if defined(LIGHTMAP_ON)
        //传入光照贴图、采样器、UV、UVST（已事先处理，因此不做变换）、光照贴图是否压缩、解码式
        return SampleSingleLightmap(TEXTURE2D_ARGS(unity_Lightmap, samplerunity_Lightmap), lightMapUV,
            float4(1.0,1.0,0.0,0.0),
            //光照贴图是否被压缩，不对其开启HDR时为压缩模式
            #if defined(UNITY_LIGHTMAP_FULL_HDR)
                false,
            #else
                true,
            #endif
            //光照贴图的解码float4
            float4(LIGHTMAP_HDR_MULTIPLIER, LIGHTMAP_HDR_EXPONENT, 0.0, 0.0)
            );
    #else
        return 0.0;
    #endif
}

//得到片元的GI结果，传入当前片元在光照贴图上的UV
GI GetGI(float2 lightMapUV)
{
    GI gi;
    //采样光照贴图作为表面片元接收到GI上的diffuse光照
    gi.diffuse = SampleLightMap(lightMapUV);
    return gi;
}
#endif