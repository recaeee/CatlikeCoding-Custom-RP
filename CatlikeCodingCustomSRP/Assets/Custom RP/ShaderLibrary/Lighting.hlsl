//用来存放计算光照相关的方法
//HLSL编译保护机制
#ifndef CUSTOM_LIGHTING_INCLUDE
#define CUSTON_LIGHTING_INCLUDE

//第一次写的时候这里的Surface会标红，因为只看这一个hlsl文件，我们并未定义Surface
//但在include到整个Lit.shader中后，编译会正常，至于IDE还标不标红就看IDE造化了...
//另外，我们需要在include该文件之前include Surface.hlsl，因为依赖关系
//所有的include操作都放在LitPass.hlsl中

//计算物体表面接收到的光能量
float3 IncomingLight(Surface surface,Light light)
{
    //考虑了阴影带来的光源衰减
    return saturate(dot(surface.normal,light.direction)) * light.attenuation * light.color;
}

//新增的GetLighting方法，传入surface和light，返回真正的光照计算结果，即物体表面最终反射出的RGB光能量
float3 GetLighting(Surface surface,BRDF brdf,Light light)
{
    return IncomingLight(surface,light) * DirectBRDF(surface,brdf,light);
}

//GetLighting返回光照结果，这个GetLighting只入一个surface、一个BRDF、一个GI
float3 GetLighting(Surface surfaceWS,BRDF brdf, GI gi)
{
    //计算片元的级联阴影信息
    ShadowData shadowData = GetShadowData(surfaceWS);
    //从GI中获取阴影遮罩信息
    shadowData.shadowMask = gi.shadowMask;
    //光照结果初始化为烘培好的gi光照结果
    float3 color = IndirectBRDF(surfaceWS, brdf, gi.diffuse, gi.specular);
    //使用循环，累积所有有效方向光源的光照计算结果
    for(int i=0;i<GetDirectionalLightCount();i++)
    {
        Light light = GetDirectionalLight(i,surfaceWS,shadowData);
        color += GetLighting(surfaceWS,brdf,light);
    }
    //同理，累积其他光源（注意迭代变量使用不重复的j，防止shader warnings）
    #if defined(_LIGHTS_PER_OBJECT)
        for(int j=0;j<min(unity_LightData.y,8);j++)
        {
            int lightIndex = unity_LightIndices[(uint)j/4][(uint)j%4];
            Light light = GetOtherLight(lightIndex, surfaceWS, shadowData);
            color += GetLighting(surfaceWS, brdf, light);
        }
    #else
        for(int j=0;j<GetOtherLightCount();j++)
        {
            Light light = GetOtherLight(j, surfaceWS, shadowData);
            color += GetLighting(surfaceWS, brdf, light);
        }
    #endif
    return color;
}

#endif
