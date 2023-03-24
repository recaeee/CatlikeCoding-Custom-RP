#ifndef CUSTOM_UNLIT_PASS_INCLUDED
#define CUSTOM_UNLIT_PASS_INCLUDED


//使用Core RP Library的CBUFFER宏指令包裹材质属性，让Shader支持SRP Batcher，同时在不支持SRP Batcher的平台自动关闭它。
//CBUFFER_START后要加一个参数，参数表示该C buffer的名字(Unity内置了一些名字，如UnityPerMaterial，UnityPerDraw。
// CBUFFER_START(UnityPerMaterial)
// float4 _BaseColor;
// CBUFFER_END

//使用结构体定义顶点着色器的输入，一个是为了代码更整洁，一个是为了支持GPU Instancing（获取object的index）
struct Attributes
{
    float3 positionOS:POSITION;
    float2 baseUV:TEXCOORD0;
    //定义GPU Instancing使用的每个实例的ID，告诉GPU当前绘制的是哪个Object
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

//为了在片元着色器中获取实例ID，给顶点着色器的输出（即片元着色器的输入）也定义一个结构体
//命名为Varings是因为它包含的数据可以在同一三角形的片段之间变化
struct Varyings
{
    float4 positionCS:SV_POSITION;
    float2 baseUV:VAR_BASE_UV;
    //定义每一个片元对应的object的唯一ID
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

Varyings UnlitPassVertex(Attributes input)
{
    Varyings output;
    //从input中提取实例的ID并将其存储在其他实例化宏所依赖的全局静态变量中
    UNITY_SETUP_INSTANCE_ID(input);
    //将实例ID传递给output
    UNITY_TRANSFER_INSTANCE_ID(input,output);
    float3 positionWS = TransformObjectToWorld(input.positionOS);
    output.positionCS = TransformWorldToHClip(positionWS);
    //应用纹理ST变换
    output.baseUV = TransformBaseUV(input.baseUV);
    return output;
}

float4 UnlitPassFragment(Varyings input) : SV_TARGET
{
    //从input中提取实例的ID并将其存储在其他实例化宏所依赖的全局静态变量中
    UNITY_SETUP_INSTANCE_ID(input);

    InputConfig config = GetInputConfig(input.baseUV);
    //获取采样纹理颜色
    //通过UNITY_ACCESS_INSTANCED_PROP获取每实例数据
    float4 base = GetBase(config);

    //只有在_CLIPPING关键字启用时编译该段代码
    #if defined(_CLIPPING)
    //clip函数的传入参数如果<=0则会丢弃该片元
    clip(base.a - GetCutoff(config));
    #endif
    
    return base;
}

#endif
