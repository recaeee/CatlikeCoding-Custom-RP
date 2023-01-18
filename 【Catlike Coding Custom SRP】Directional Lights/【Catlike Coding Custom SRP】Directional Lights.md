# 【Catlike Coding Custom SRP学习之旅——3】Directional Lights
#### 写在前面

以下是原教程链接与我的Github工程（Github上会实时同步最新进度）：

[CatlikeCoding-SRP-Tutorial](https://catlikecoding.com/unity/tutorials/custom-srp/)

[我的Github工程](https://github.com/recaeee/CatlikeCoding-Custom-RP)

#### 方向光 Directional Lights

--- 

#### 1 光照 Lighting

如果我们想创建一个更具有真实感的场景，我们需要模拟光线和物体表面是如何交互的。因此我们需要实现一个比Unlit Shader更加复杂一些的Shader。

#### 1.1 带光照着色器 Lit Shader

首先我们复制UnlitPass.hlsl，再将其重命名为LitPass.hlsl，因为Lit和Unlit的整体框架大致是相同的，无非是在Vertex和Fragment方法、传递的数据上有所改动。

与UnlitPass.hlsl相同，在LitPass.hlsl中，我们第一步依然是**添加编译保护机制**，将开头的宏定义改为CUSTOM_LIT_PASS_INCLUDED，并且将其中的Vertex和Fragment方法的Unlit前缀替换为Lit。

其次以类似的操作复制一份Unlit.shader，再将其重命名为Lit.shader，在shader类文件内将对应Unlit替换为Lit，并将Properties中的默认颜色Color设置为(0.5,0.5,0.5,1)，大概是灰色的一个颜色。将默认颜色Color设置为灰色的原因是，如果将其改为纯白，那么使用该材质的Renderer物体大概率是非常亮的（不带纹理的情况下），因此使用灰色，URP中的Lit.shader同样也默认使用了灰色。

接下来就进入到比较关键的地方了，我们需要现在Lit.shader的Pass里增加"LightMode" = "CustomLit"的Tag（"CustomLit"这个名字是自己取的）。

```c#
Pass
        {
            //设置Pass Tags，最关键的Tag为"LightMode"
            Tags
            {
                "LightMode" = "CustomLit"
            }
            //设置混合模式
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]

            HLSLPROGRAM
            //告诉Unity启用_CLIPPING关键字时编译不同版本的Shader
            #pragma shader_feature _CLIPPING
            //这一指令会让Unity生成两个该Shader的变体，一个支持GPU Instancing，另一个不支持。
            #pragma multi_compile_instancing
            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment
            #include "LitPass.hlsl"
            ENDHLSL
        }
```

好了，进入到第一个关键知识点了。

1.何为**Pass Tags（通道标签）**？

根据[官方描述](https://docs.unity3d.com/cn/2021.3/Manual/SL-PassTags.html)，**Tag是可以分配给Pass的键值对数据**。

2.Pass Tags用来做什么？

Unity使用**预定义的标签**和值来确定如何以及何时渲染给定的Pass。（题外话，我们还可以使用自定义值创建自定义的Pass Tag，并从C#代码访问它们，这个功能我们目前应该用不上）。**最常用的预定义Pass Tag为"LightMode"**,预定义也就是意味着这个Tag的键（即"LightMode"）是Unity内置的，其用于所有渲染管线。值得一提的是，通常SubShader中我们也会赋予SubShader Tags，但SubShader Tags和Pass Tags的工作方式不同，在Pass中设置SubShader Tag是没有效果的，反之亦然。因此，**Pass Tags必须放在Pass中定义，SubShader Tags必须放在SubShader中定义**。

3.何为"LightMode"标签？

参考官方文档，"LightMode"是Unity预定义的一个Pass Tag，Unity使用它来确定是否在给定帧期间执行该Pass，在该帧期间Unity何时执行该Pass，以及Unity对输出执行哪些操作。"LightMode"是非常重要的一个Pass Tag，在Unity任何渲染管线中其都会被预定义，但其默认值会随着管线不同而不同（比如Built-in和URP，自带的LightMode值不同）。

在SRP中，我们可以为"LightMode"这一Pass Tag创建自定义值，然后通过配置DrawingSettings结构，可以利用这些自定义值在DrawRenderers期间绘制指定Pass（这个方法是很重要的，相当于我们的画笔，在很多地方我们都可以用这个方法）。另外，在SRP中，**我们可以使用SRPDefaultUnlit值来引用没有LightMode标签的通道**，这也就意味着如果一个Pass中没有定义LightMode的Pass Tag，Unity会自动将其归为"LightMode"="SRPDefaultUnlit"。（这也就是为什么我们的Unlit.shader没有定义"LightMode",但我们依然能通过"SRPDefaultUnlit"来绘制它们的原因）。

然后，我们需要在CameraRenderer.cs中增加一个代表"CustomLit"的ShaderTagId，最后在DrawVisibleGeometry()中通过drawingSettings.SetShaderPassName(1, litShaderTagId) 为drawingSettings增加一个名为"CustomLit"的可渲染的Pass。

```c#
    void DrawVisibleGeometry(bool useDynamicBatching, bool useGPUInstancing)
    {
        //决定物体绘制顺序是正交排序还是基于深度排序的配置
        var sortingSettings = new SortingSettings(camera)
        {
            criteria = SortingCriteria.CommonOpaque
        };
        //决定摄像机支持的Shader Pass和绘制顺序等的配置
        var drawingSettings = new DrawingSettings(unlitShaderTagId, sortingSettings)
        {
            //启用动态批处理
            enableDynamicBatching = useDynamicBatching,
            enableInstancing = useGPUInstancing
        };
        //增加对Lit.shader的绘制支持,index代表本次DrawRenderer中该pass的绘制优先级（0最先绘制）
        drawingSettings.SetShaderPassName(1, litShaderTagId);
        //决定过滤哪些Visible Objects的配置，包括支持的RenderQueue等
        var filteringSettings = new FilteringSettings(RenderQueueRange.opaque);
        //渲染CullingResults内不透明的VisibleObjects
        context.DrawRenderers(cullingResults, ref drawingSettings, ref filteringSettings);
        //添加“绘制天空盒”指令，DrawSkybox为ScriptableRenderContext下已有函数，这里就体现了为什么说Unity已经帮我们封装好了很多我们要用到的函数，SPR的画笔~
        context.DrawSkybox(camera);
        //渲染透明物体
        //设置绘制顺序为从后往前
        sortingSettings.criteria = SortingCriteria.CommonTransparent;
        //注意值类型
        drawingSettings.sortingSettings = sortingSettings;
        //过滤出RenderQueue属于Transparent的物体
        filteringSettings.renderQueueRange = RenderQueueRange.transparent;
        //绘制透明物体
        context.DrawRenderers(cullingResults, ref drawingSettings, ref filteringSettings);
    }
```

参考[官方文档](https://docs.unity3d.com/cn/2021.3/ScriptReference/Rendering.DrawingSettings.SetShaderPassName.html)，drawingSettings.SetShaderPassName包含两个传入参数，第一个为index，代表要使用的着色器通道的索引；第二个为shaderPassName，代表着色器通道的名称。Unity官方对这个函数的介绍非常笼统，index代表什么看官方文档是不能确定的，因此我做了一系列实验来确定drawSettings中SetShaderPassName的具体逻辑。

首先先放上最重要的结论：**drawSettings.SetShaderPassName(index,shaderTagId)中shaderTagId代表要绘制的Pass的"LightMode"Tag的值，index代表在本次DrawRenderers中不同LightMode之间的Pass的绘制顺序（0最优先）。其次，对于一个drawSettings中要绘制的"LightMode"，Unity会从SubShader中从上往下找到第一个"LightMode"为对应值的Pass，如果没有则走Fallback**。

我们首先印证最后一点结论，即对于一个drawSettings中要绘制的"LightMode"，Unity会从SubShader中从上往下找到第一个"LightMode"为对应值的Pass，如果没有则走Fallback。

在场景中我放置了一个使用Unlit材质的小球，与一个使用Lit材质的Cube。

我在Lit.shader中总共放2个Pass，两个Pass的"LightMode"都为"CustomLit"，在第一个Pass中，会返回纯红色，在第二Pass中会返回默认的灰色。然后drawSettings中index=0对应"LightMode"="SRPDefaultUnlit"的Pass（目前只有unlit.shader），index=1对应"LightMode"="CustomLit"的Pass（目前只有Lit.shader）。

Lit.shader关键代码如下。

```c#
        Pass
        {
            //设置Pass Tags，最关键的Tag为"LightMode"
            Tags
            {
                "LightMode" = "CustomLit"
            }
            //设置混合模式
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]

            HLSLPROGRAM
            //告诉Unity启用_CLIPPING关键字时编译不同版本的Shader
            #pragma shader_feature _CLIPPING
            //这一指令会让Unity生成两个该Shader的变体，一个支持GPU Instancing，另一个不支持。
            #pragma multi_compile_instancing
            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment
            #include "LitPass.hlsl"
            ENDHLSL
        }
        Pass
        {
            //测试Pass，返回纯红色
            Tags
            {
                "LightMode" = "CustomLit"
            }
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]

            HLSLPROGRAM
            #pragma shader_feature _CLIPPING
            #pragma multi_compile_instancing
            #pragma vertex LitPassVertex
            #pragma fragment test
            #include "LitPass.hlsl"

            float4 test(Varyings input) : SV_TARGET
            {
                return half4(1, 0, 0, 1);
            }
            ENDHLSL
        }
```

绘制结果为先绘制Unlit材质的小球(index=0,"LightMode"="SRPDefaultUnlit")，再绘制一次Cube（index=1，"LightMode"="CustomLit"），如下图所示，小球展现出来的颜色是灰色，这也就意味着我们走的是Lit中的第一个Pass。

<div align=center>

![20230116201438](https://raw.githubusercontent.com/recaeee/PicGo/main/recaeee/PicGo20230116201438.png)

</div>

如果我们将两个Pass代码位置互换，得到的结果就是Cube被渲染为红色。

<div align=center>

![20230116201636](https://raw.githubusercontent.com/recaeee/PicGo/main/recaeee/PicGo20230116201636.png)

</div>

由此得出：**对于一个drawSettings中要绘制的"LightMode"，Unity会从SubShader中从上往下找到第一个"LightMode"为对应值的Pass，如果没有则走Fallback**。

接下来做另一个实验来印证SetShaderPassName中的index的含义。

我在Lit.shader将返回纯红色的测试Pass的"LightMode"改为了“TestTag"，这也就意味着目前Lit.shader种包括2个不同LightMode的Pass，一个"CustomLit"（显示灰色），一个"TestTag"（显示红色）。接下来，我在DrawRenderers之前将"TestTag"以索引号2设置为drawSettings的ShaderPass。由此，索引0对应"SRPDefaultUnlit"，索引1对应"CustomLit"，索引2对应"TestTag"。

部分关键代码如下。

```c#
        //增加对Lit.shader的绘制支持,index代表本次DrawRenderer中该pass的绘制优先级（0最先绘制）
        drawingSettings.SetShaderPassName(1, litShaderTagId);//"LightMode"="CustomLit"
        drawingSettings.SetShaderPassName(2,new ShaderTagId("TestTag"));
        //决定过滤哪些Visible Objects的配置，包括支持的RenderQueue等
        var filteringSettings = new FilteringSettings(RenderQueueRange.opaque);
        //渲染CullingResults内不透明的VisibleObjects
        context.DrawRenderers(cullingResults, ref drawingSettings, ref filteringSettings);
```

最后结果Cube呈现红色，也就意味着"CustomLit"先被绘制，接着是"TestTag"绘制红色，然后覆盖掉了灰色。使用FrameDebugger查看绘制顺序，也印证了该猜想。

<div align=center>

![20230117225833](https://raw.githubusercontent.com/recaeee/PicGo/main/20230117225833.png)

</div>

由此得出结论：**drawSettings.SetShaderPassName(index,shaderTagId)中shaderTagId代表要绘制的Pass的"LightMode"Tag的值，index代表在本次DrawRenderers中不同LightMode之间的Pass的绘制顺序（0最优先）**。但是SetShaderPass的索引只会控制同一物体不同Pass之间绘制顺序，其优先级低于物体离摄像机的距离，如果场景里有物体A和物体B都需要绘制，那会先绘制物体A的"CustomLit"，再绘制物体A的"TestLit"，再绘制物体B的"CustomLit",最后绘制物体B的"TestLit"，而不是A-CustomLit，B-CustomLit，A-TestTag，B-TestTag。此外，其优先级更加低于批处理合批操作，可以说每个合批内部才会考虑Pass的Index。

到此，我们应该算了解了Pass Tag的作用以及SetShaderPassName方法的内部逻辑。接下来回到教程，我们可以创建一个名为Opaque的材质，使用上Lit.shader。

#### 1.2 法线 Normal Vectors

一个光照的物体在绘制时需要考虑很多因素，包括物体表面和光线之间的夹角，我们通过法线表示物体表面的朝向，法线通常是一个**顶点信息，其被定义在模型空间，同时是单位向量（即长度为1）**。因此，我们在LitPass.hlsl的Attributes结构体（顶点着色器输入）中增加**模型空间下的法线**这一数据。

```c#
//使用结构体定义顶点着色器的输入，一个是为了代码更整洁，一个是为了支持GPU Instancing（获取object的index）
struct Attributes
{
    float3 positionOS:POSITION;
    //顶点法线信息，用于光照计算，OS代表Object Space，即模型空间
    float3 normalOS:NORMAL;
    float2 baseUV:TEXCOORD0;
    //定义GPU Instancing使用的每个实例的ID，告诉GPU当前绘制的是哪个Object
    UNITY_VERTEX_INPUT_INSTANCE_ID
};
```

同时，我们会在片元着色器中计算光照（顶点着色器当然也可以，但是质量不如片元着色器），因此我们在Varings结构体（片元着色器输入）中也增加**世界空间下的法线**这一数据，这也就意味着我们会在世界空间下计算光照。

```c#
//为了在片元着色器中获取实例ID，给顶点着色器的输出（即片元着色器的输入）也定义一个结构体
//命名为Varings是因为它包含的数据可以在同一三角形的片段之间变化
struct Varyings
{
    float4 positionCS:SV_POSITION;
    //世界空间下的法线信息
    float3 normalWS:VAR_NORMAL;
    float2 baseUV:VAR_BASE_UV;
    //定义每一个片元对应的object的唯一ID
    UNITY_VERTEX_INPUT_INSTANCE_ID
};
```

接下来我们在顶点着色器中使用**TransformObjectToWorldNormal**来将法线从模型空间转换到世界空间。我们使用TransformObjectToWorldNormal而不是TransformObjectToWorld的原因是假如物体的Scale不是(1,1,1)，使用TransformObjectToWorld会得到错误的法线，另外TransformObjectToWorld处理的是点变换，而TransformObjectToWorldNormal内部会调用TransformObjectToWorldDir，处理的是向量变换（因为法线是向量，不考虑Translation）。当物体的Scale不是(1,1,1)时，TransformObjectToWorldNormal内部会将法线与UNITY_MATRIX_I_M相乘进行矫正，但其也就意味着**使用TransformObjectToWorldNormal会将每个物体的UNITY_MATRIX_I_M作为一个矩阵数组传递给GPU**，增大显存的占用。如果说我们明确要渲染的物体的Scale都为(1,1,1)，我们可以通过在shader中增加#pragma instancing_options assumeuniformscaling指令来去掉UNITY_MATRIX_I_M的传递，这时候使用TransformObjectToWorldNormal则会省去IM矩阵这一步，可以当作一种优化方法。

顶点着色器代码如下。

```c#
Varyings LitPassVertex(Attributes input)
{
    Varyings output;
    //从input中提取实例的ID并将其存储在其他实例化宏所依赖的全局静态变量中
    UNITY_SETUP_INSTANCE_ID(input);
    //将实例ID传递给output
    UNITY_TRANSFER_INSTANCE_ID(input,output);
    float3 positionWS = TransformObjectToWorld(input.positionOS);
    output.positionCS = TransformWorldToHClip(positionWS);
    //使用TransformObjectToWorldNormal将法线从模型空间转换到世界空间，注意不能使用TransformObjectToWorld
    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
    //应用纹理ST变换
    float4 baseST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_BaseMap_ST);
    output.baseUV = input.baseUV * baseST.xy + baseST.zw;
    return output;
}
```

为了验证我们是否在片元着色器中是否正确获取到了世界空间下的法线，我们可以将normalWS作为颜色在片元着色器中输出（这也是我们调试Shader的很重要的一个手段，即当作颜色输出）。显示结果如下，结果符合预期（黑色区域是因为法线向量的负值部分在转到Color时会自动被Clamp到0。

<div align=center>

![20230117235201](https://raw.githubusercontent.com/recaeee/PicGo/main/20230117235201.png)

</div>

#### 1.3 插值法线 Interpolated Normals

虽然我们在顶点着色器中计算出的世界空间的顶点法线是单位长度的，但是经过线性插值器传递到片元属性时，**其长度就会发生变化**。我们可以在片元着色器中输出片元着色器中插值后的法线长度与1的插值。其结果如下图所示。

<div align=center>

![20230118220740](https://raw.githubusercontent.com/recaeee/PicGo/main/20230118220740.png)

</div>

其原因从教程中的原图很直观的就可以看出，就是线性插值造成的结果。

<div align=center>

![20230118220938](https://raw.githubusercontent.com/recaeee/PicGo/main/20230118220938.png)

</div>

为了消除片元着色器中法线的长度问题，我们在片元着色器中对其进行normalize操作得到归一化的法线向量。

#### 1.4 表面属性 Surface Properties

由于光照模拟的是光线与物体表面的相互作用，因此我们需要设置物体表面的一系列与光照相关的属性。为了更方便地管理，我们创建一个新的Surface.hlsl文件来定义物体表面属性。

```c#
//定义与光照相关的物体表面属性
//HLSL编译保护机制
#ifndef CUSTOM_SURFACE_INCLUDED
#define CUSTOM_SURFACE_INCLUDED

//物体表面属性，该结构体在片元着色器中被构建
struct Surface
{
    //顶点法线，在这里不明确其坐标空间，因为光照可以在任何空间下计算，在该项目中使用世界空间
    float3 normal;
    //表面颜色
    float3 color;
    //透明度
    float alpha;
};

#endif
```

在定义完Surface之后，我们就需要在片元着色器中构建Surface用于计算光照（别忘记我们是在片元着色器中计算光照）。部分代码如下。

```c#
float4 LitPassFragment(Varyings input) : SV_TARGET
{
    //从input中提取实例的ID并将其存储在其他实例化宏所依赖的全局静态变量中
    UNITY_SETUP_INSTANCE_ID(input);
    //获取采样纹理颜色
    float4 baseMap = SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,input.baseUV);
    //通过UNITY_ACCESS_INSTANCED_PROP获取每实例数据
    float4 baseColor =  UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
    float4 base = baseMap * baseColor;

    //只有在_CLIPPING关键字启用时编译该段代码
    #if defined(_CLIPPING)
    //clip函数的传入参数如果<=0则会丢弃该片元
    clip(base.a - UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff));
    #endif

    //在片元着色器中构建Surface结构体，即物体表面属性，构建完成之后就可以在片元着色器中计算光照
    Surface surface;
    surface.normal = normalize(input.normalWS);
    surface.color = base.rgb;
    surface.alpha = base.a;
    
    return float4(surface.color,surface.alpha);
}
```

这种多行的赋值看起来可能比较不舒服，但是Shader在编译的时候会生成高度优化的程序，相当于完全重写我们的代码，因此shader代码怎么方便怎么来就行。我们可以通过shader类的Inspector视图下的Compile and show code按钮查看编译后的代码(看起来有点像汇编？但是有些强者可能能够从这些指令几乎反推出Shader写法？）。

<div align=center>

![20230118222541](https://raw.githubusercontent.com/recaeee/PicGo/main/20230118222541.png)

![20230118222628](https://raw.githubusercontent.com/recaeee/PicGo/main/20230118222628.png)

</div>

#### 1.5 计算光照 Calculating Lighting

为了计算光照，我们需要创建一个名为GetLighting的方法，该方法传入一个Surface参数，目前我们暂且让其输出Surface.normal.y。因为这是用来处理光照的方法，因此我们将其放在一个单独的Lighting.hlsl文件中。（hlsl文件逐渐多了起来，虽然确实容易管理了，但我觉得在实际阅读的时候也挺不方便的。）

Lighting.hlsl代码如下。

```c#
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
    return surface.normal.y;
}

#endif
```

就如代码中注释所说，我们所有的include操作都会放在LitPass.hlsl中（一是容易展示依赖性，二是方便未来替换hlsl文件），因为在Lighting.hlsl中我们是假设我们定义过Surface的，所以在include Lighting.hlsl之前我们需要include Surface.hlsl（是不是和上一章Common.hlsl为SRPCore做一些预定义有点像？）。

现在，我们就可以在片元着色器中调用GetLighting方法来获取光照（目前我们返回的是法线的y值），我们将其返回值作为颜色输出，得到下图效果(看起来仿佛有盏从上垂直向下照射的灯，虽然只是看起来像）。

<div align=center>

![20230118224154](https://raw.githubusercontent.com/recaeee/PicGo/main/20230118224154.png)

</div>

目前，我们可以将GetLighting的结果作为从上往下照射的光线在物体表面形成的漫反射部分，也就是说，我们将surface.normal.y当作**物体表面接收到的光能量**，我们再让其乘以surface.color，surface.color可以理解为物体的**albedo（反射率）** 部分（即物体不吸收并反射出去的光能量），吸收的光能量乘以表面反射率就构成了**Diffuse**部分。

Albedo在拉丁语中是白色的意思，它衡量多少光被表面漫反射。如果反射率不是全白，则部分光能量会被吸收而不是反射。

通常来说，**Albedo就作为材质的MainTex，一个材质的表现效果很大程度依赖于Albedo，它很大程度决定了物体表面呈现出的颜色**。

Lighting.hlsl部分代码如下。

```c#
float3 GetLighting(Surface surface)
{
    //物体表面接收到的光能量 * 物体表面Albedo（反射率）
    return surface.normal.y * surface.color;
}
```

此时，不同于上一张效果图，我们因为乘以了一个albedo（默认为0.5,0.5,0.5)，意味着**有一半的光能量会被吸收而不是反射出来**，因此摄像机看到物体的颜色会变暗一些，如下图所示。

<div align=center>

![20230118233619](https://raw.githubusercontent.com/recaeee/PicGo/main/20230118233619.png)

</div>

#### 2 光线 Lights
