//用来存放计算光照相关的方法
//HLSL编译保护机制
#ifndef CUSTOM_LIGHTING_INCLUDE
#define CUSTON_LIGHTING_INCLUDE

//第一次写的时候这里的Surface会标红，因为只看这一个hlsl文件，我们并未定义Surface
//但在include到整个Lit.shader中后，编译会正常，至于IDE还标不标红就看IDE造化了...
//另外，我们需要在include该文件之前include Surface.hlsl，因为依赖关系
//所有的include操作都放在LitPass.hlsl中
float3 GetLighting(Surface surface)
{
    //物体表面接收到的光能量 * 物体表面Albedo（反射率）
    return surface.normal.y * surface.color;
}

//计算物体表面接收到的光能量
float3 IncomingLight(Surface surface,Light light)
{
    return dot(surface.normal,light.direction) * light.color;
}

#endif
