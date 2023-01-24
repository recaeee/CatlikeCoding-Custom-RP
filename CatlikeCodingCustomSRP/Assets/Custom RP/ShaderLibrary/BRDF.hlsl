//定义BRDF函数需要传入的参数BRDF
#ifndef CUSTOM_BRDF_INCLUDED
#define CUSTOM_BRDF_INCLUDED

//宏定义最小高光反射率
#define MIN_REFLECTIVITY 0.04

float OneMinusReflectivity(float metallic)
{
    //将漫反射反射率控制在[0,0.96]内
    float range = 1.0 - MIN_REFLECTIVITY;
    return range - metallic * range;
}

struct BRDF
{
    //物体表面漫反射颜色
    float3 diffuse;
    //物体表面高光颜色
    float3 specular;
    //物体表面粗糙度
    float3 roughness;
};

BRDF GetBRDF(Surface surface)
{
    BRDF brdf;

    //Reflectivity表示Specular反射率，oneMinusReflectivity表示Diffuse反射率
    float oneMinusReflectivity = OneMinusReflectivity(surface.metallic);
    //diffuse等于物体表面不吸收的光能量color*（1-高光反射率）
    brdf.diffuse = surface.color * oneMinusReflectivity;
    //高光占比(specular)应该等于surface.color(物体不吸收的光能量，即用于反射的所有光能量)-brdf.diffuse（漫反射占比）
    //同时，高光占比越高，高光颜色越接近物体本身反射颜色，高光占比越低，高光颜色越接近白色，因此使用lerp
    brdf.specular = lerp(MIN_REFLECTIVITY,surface.color,surface.metallic);
    brdf.roughness = 1.0;
    return brdf;
}

#endif
