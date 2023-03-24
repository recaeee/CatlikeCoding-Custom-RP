#ifndef CUSTOM_LIT_PASS_INCLUDED
#define CUSTOM_LIT_PASS_INCLUDED

#include "../ShaderLibrary/Surface.hlsl"
#include "../ShaderLibrary/Shadows.hlsl"
#include "../ShaderLibrary/Light.hlsl"
#include "../ShaderLibrary/BRDF.hlsl"
#include "../ShaderLibrary/GI.hlsl"
#include "../ShaderLibrary/Lighting.hlsl"

//使用Core RP Library的CBUFFER宏指令包裹材质属性，让Shader支持SRP Batcher，同时在不支持SRP Batcher的平台自动关闭它。
//CBUFFER_START后要加一个参数，参数表示该C buffer的名字(Unity内置了一些名字，如UnityPerMaterial，UnityPerDraw。
// CBUFFER_START(UnityPerMaterial)
// float4 _BaseColor;
// CBUFFER_END

//使用结构体定义顶点着色器的输入，一个是为了代码更整洁，一个是为了支持GPU Instancing（获取object的index）
struct Attributes
{
    float3 positionOS:POSITION;
    //顶点法线信息，用于光照计算，OS代表Object Space，即模型空间
    float3 normalOS:NORMAL;
    //顶点切线，用于构建切线空间
    float4 tangentOS:TANGENT;
    float2 baseUV:TEXCOORD0;
    //使用宏定义光照贴图信息
    GI_ATTRIBUTE_DATA
    //定义GPU Instancing使用的每个实例的ID，告诉GPU当前绘制的是哪个Object
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

//为了在片元着色器中获取实例ID，给顶点着色器的输出（即片元着色器的输入）也定义一个结构体
//命名为Varings是因为它包含的数据可以在同一三角形的片段之间变化
struct Varyings
{
    float4 positionCS:SV_POSITION;
    float3 positionWS:VAR_POSITION;
    //世界空间下的法线信息
    float3 normalWS:VAR_NORMAL;
    #if defined(_NORMAL_MAP)
    float4 tangentWS:VAR_TANGENT;
    #endif
    float2 baseUV:VAR_BASE_UV;
    #if defined(_DETAIL_MAP)
    float2 detailUV:VAR_DETAIL_UV;
    #endif
    //接收顶点光照贴图信息
    GI_VARYINGS_DATA
    //定义每一个片元对应的object的唯一ID
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

Varyings LitPassVertex(Attributes input)
{
    Varyings output;
    //从input中提取实例的ID并将其存储在其他实例化宏所依赖的全局静态变量中
    UNITY_SETUP_INSTANCE_ID(input);
    //将实例ID传递给output
    UNITY_TRANSFER_INSTANCE_ID(input,output);
    //将顶点的光照贴图信息传递给output
    TRANSFER_GI_DATA(input,output);
    output.positionWS = TransformObjectToWorld(input.positionOS);
    output.positionCS = TransformWorldToHClip(output.positionWS);
    //使用TransformObjectToWorldNormal将法线从模型空间转换到世界空间，注意不能使用TransformObjectToWorld
    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
    #if defined(_NORMAL_MAP)
    //将模型空间下的切线方向转换到世界空间
    output.tangentWS = float4(TransformObjectToWorldDir(input.tangentOS.xyz), input.tangentOS.w);
    #endif
    //应用纹理ST变换
    output.baseUV = TransformBaseUV(input.baseUV);
    #if defined(_DETAIL_MAP)
    output.detailUV = TransformDetailUV(input.baseUV);
    #endif
    return output;
}

float4 LitPassFragment(Varyings input) : SV_TARGET
{
    //从input中提取实例的ID并将其存储在其他实例化宏所依赖的全局静态变量中
    UNITY_SETUP_INSTANCE_ID(input);
    //LOD过渡
    #if defined(LOD_FADE_CROSSFADE)
    ClipLOD(input.positionCS.xy,unity_LODFade.x);
    #endif
    InputConfig config = GetInputConfig(input.baseUV);
    #if defined(_MASK_MAP)
        config.useMask = true;
    #endif
    #if defined(_DETAIL_MAP)
        config.detailUV = input.detailUV;
        config.useDetail = true;
    #endif
    //获取采样纹理颜色
    //通过UNITY_ACCESS_INSTANCED_PROP获取每实例数据
    float4 base = GetBase(config);

    //只有在_CLIPPING关键字启用时编译该段代码
    #if defined(_CLIPPING)
    //clip函数的传入参数如果<=0则会丢弃该片元
    clip(base.a - GetCutoff(config));
    #endif

    //在片元着色器中构建Surface结构体，即物体表面属性，构建完成之后就可以在片元着色器中计算光照
    Surface surface;
    surface.position = input.positionWS;
    //考虑法线贴图
    #if defined(_NORMAL_MAP)
    surface.normal = NormalTangentToWorld(GetNormalTS(config), input.normalWS, input.tangentWS);
    //片元原始法线，用于Shadow Bias，这里可以不用向量标准化，不会有太多影响
    surface.interpolatedNormal = input.normalWS;
    #else
    surface.normal = normalize(input.normalWS);
    surface.interpolatedNormal = surface.normal;
    #endif
    surface.viewDirection = normalize(_WorldSpaceCameraPos - input.positionWS);
    //计算观察空间的片元深度值时需要取反，（可能因为观察空间z轴指向摄像机正后方）
    surface.depth = -TransformWorldToView(input.positionWS).z;
    surface.color = base.rgb;
    surface.alpha = base.a;
    surface.metallic = GetMetallic(config);
    surface.occlusion = GetOcclusion(config);
    surface.smoothness = GetSmoothness(config);
    surface.fresnelStrength = GetFresnel(config);
    //根据片元CS坐标计算抖动值
    surface.dither = InterleavedGradientNoise(input.positionCS.xy,0);
    #if defined(_PREMULTIPLY_ALPHA)
        BRDF brdf = GetBRDF(surface,true);
    #else
        BRDF brdf = GetBRDF(surface);
    #endif
    //传入宏定义的片元GI信息，得到烘培好的GI光照结果
    GI gi = GetGI(GI_FRAGMENT_DATA(input), surface, brdf);
    
    float3 color = GetLighting(surface,brdf,gi);
    //考虑自发光
    color += GetEmission(config);
    return float4(color,surface.alpha);
}

#endif
