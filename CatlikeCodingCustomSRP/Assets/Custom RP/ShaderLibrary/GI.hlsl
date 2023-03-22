//管理全局光照GI
#ifndef CUSTOM_GI_INCLUDED
#define CUSTOM_GI_INCLUDED

//用于获取光源信息
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"
//用于获取roughness对应mip level
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"

//GPU接收到的光照贴图名为unity_Lightmap
TEXTURE2D(unity_Lightmap);
SAMPLER(samplerunity_Lightmap);

//GPU接受阴影遮罩和其采样器
TEXTURE2D(unity_ShadowMask);
SAMPLER(samplerunity_ShadowMask);

//LPPV的3D纹理
TEXTURE3D_FLOAT(unity_ProbeVolumeSH);
SAMPLER(sampler_unity_ProbeVolumeSH);

//环境光贴图（默认是Skybox）
TEXTURECUBE(unity_SpecCube0);
SAMPLER(samplerunity_SpecCube0);

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
    //片元接收到的GI Specular部分，包括环境光照
    float3 specular;
    //阴影遮罩信息，存储到GI是因为阴影遮罩属于烘培光照数据的一部分
    ShadowMask shadowMask;
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

//采样阴影遮罩纹理，返回阴影衰减度
float4 SampleBakedShadows(float2 lightMapUV, Surface surfaceWS)
{
    //阴影遮罩只对使用光照贴图的表面起作用，因此直接使用LIGHTMAP_ON关键字
    #if defined(LIGHTMAP_ON)
        //这里可以看到使用的uv坐标和光照贴图是同一套
        return SAMPLE_TEXTURE2D(unity_ShadowMask, samplerunity_ShadowMask, lightMapUV);
    #else
        //未使用光照贴图，意味着是动态物体，使用遮蔽探针或者遮蔽LPPV
        if(unity_ProbeVolumeParams.x)
        {
            return SampleProbeOcclusion(TEXTURE3D_ARGS(unity_ProbeVolumeSH, sampler_unity_ProbeVolumeSH),
                surfaceWS.position,unity_ProbeVolumeWorldToObject,
                unity_ProbeVolumeParams.y, unity_ProbeVolumeParams.z,
                unity_ProbeVolumeMin.xyz, unity_ProbeVolumeSizeInv.xyz);
        }
        else
        {
            return unity_ProbesOcclusion;
        }
    #endif
}

//采样光照探针
float3 SampleLightProbe(Surface surfaceWS)
{
    #if defined(LIGHTMAP_ON)
        return 0.0;
    #else
        if(unity_ProbeVolumeParams.x)
        {
            //采样LPPVs,具体函数不深入
            return SampleProbeVolumeSH4(TEXTURE3D_ARGS(unity_ProbeVolumeSH,sampler_unity_ProbeVolumeSH),
                surfaceWS.position, surfaceWS.normal,
                unity_ProbeVolumeWorldToObject,
                unity_ProbeVolumeParams.y, unity_ProbeVolumeParams.z,
                unity_ProbeVolumeMin.xyz, unity_ProbeVolumeSizeInv.xyz);
        }
        else
        {
            //采样单个插值光照探针
            float4 coefficients[7];
            coefficients[0]=unity_SHAr;
            coefficients[1]=unity_SHAg;
            coefficients[2]=unity_SHAb;
            coefficients[3]=unity_SHBr;
            coefficients[4]=unity_SHBg;
            coefficients[5]=unity_SHBb;
            coefficients[6]=unity_SHC;
            //四面体插值采样，SH : Spherical Harmonics
            return max(0.0,SampleSH9(coefficients,surfaceWS.normal));
        }
    #endif
}

//采样环境光（高光）
float3 SampleEnvironment(Surface surfaceWS, BRDF brdf)
{
    //采样贴图的uvw方向为摄像机到物体表面的出射方向
    float3 uvw = reflect(-surfaceWS.viewDirection, surfaceWS.normal);
    //获取roughness对应mip level
    float mip = PerceptualRoughnessToMipmapLevel(brdf.perceptualRoughness);
    //最后一个参数为mip level
    float4 environment = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, uvw, mip);
    return DecodeHDREnvironment(environment, unity_SpecCube0_HDR);
}

//得到片元的GI结果，传入当前片元在光照贴图上的UV，传入表面片元
GI GetGI(float2 lightMapUV, Surface surfaceWS, BRDF brdf)
{
    GI gi;
    //初始化阴影遮罩信息
    gi.shadowMask.always = false;
    gi.shadowMask.distance = false;
    gi.shadowMask.shadows = 1.0;

    //采样光照贴图作为表面片元接收到GI上的diffuse光照
    //采样光照探针作为表面片元接收到GI上的diffuse光照
    //两者只得一
    gi.diffuse = SampleLightMap(lightMapUV) + SampleLightProbe(surfaceWS);
    gi.specular = SampleEnvironment(surfaceWS, brdf);

    //两种阴影遮罩模式
    #if defined(_SHADOW_MASK_ALWAYS)
        gi.shadowMask.always = true;
        gi.shadowMask.shadows = SampleBakedShadows(lightMapUV, surfaceWS);
    #elif defined(_SHADOW_MASK_DISTANCE)
        gi.shadowMask.distance = true;
        //采样阴影遮罩图
        gi.shadowMask.shadows = SampleBakedShadows(lightMapUV, surfaceWS);
    #endif
    return gi;
}
#endif