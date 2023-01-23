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

#### 2 光源 Lights

目前，我们已经有了物体表面的属性，为了正确表现光照，我们还需要知道光源的属性。在教程中，我们目前只会考虑方向光Directional Lights。一个方向光代表其光源位置距离我们足够远以至于其无需具体的位置信息，对于方向光来说，只通过一个方向信息表示它。这是一种简化模型，但它已经足够用来模拟比如太阳照射到地球上的光或者其他单向光的情况。

#### 2.1 光源数据结构 Light Structure

对于光源的数据结构，我们参考Surface（物体表面属性）也使用一个结构体来存储它。目前，我们对于方向光需要两个信息：**光源颜色和光源方向**。我们将该结构也定义在一个Light.hlsl文件中，同时定义一个GetDirectionalLight方法来返回一个方向光（该方向光的属性由代码写死），其颜色为纯白色，方向为（0，1，0）。注意这里有一个关键点，对于方向光的方向，我们对其的定义是**光线从哪来的**，也就是说**光源方向永远指向光源本身**（也就是和光线射出的方向相反），这么做的原因是因为这会方便之后的光照计算。

Light.hlsl代码如下。

```c#
//用来定义光源属性
#ifndef CUSTOM_LIGHT_INCLUDED
#define CUSTOM_LIGHT_INCLUDED

struct Light
{
    //光源颜色
    float3 color;
    //光源方向：指向光源
    float3 direction;
};

//返回一个配置好的光源，初始化为Color白色，光线从上垂直向下投射（不明确坐标系，但由于教程中在世界空间下计算光照，因此这里多半指的是世界空间）
Light GetDirectionalLight()
{
    Light light;
    light.color = 1.0;
    light.direction = float3(0.0,1.0,0.0);
    return light;
}

#endif
```

接下来在LitPass.hlsl中include Lighting.hlsl文件之前include Light.hlsl。到了这里，我们在Lighting文件之前include了2个其依赖的文件：Surface.hlsl（物体表面信息）和Light.hlsl（光源信息）。其依赖关系非常明确，获取到Surface和Light信息后，我们就可以在Lighting.hlsl中进行光照计算。

```c#
#include "../ShaderLibrary/Surface.hlsl"
#include "../ShaderLibrary/Light.hlsl"
#include "../ShaderLibrary/Lighting.hlsl"
```

#### 2.2 光照函数 Lighting Function

在Lighting.hlsl中，我们首先定义一个IncomingLight方法用来获取物体表面接受到了多少光能量。**对于任何方向投射来的方向光线，我们都通过物体表面法线与光源方向的点积结果作为物体表面接收到的光能量**。这也是最普遍且符合光学原理的，同时我们让其乘以光源颜色，因为光源颜色在物理意义上代表了光源射出RGB三种光线的强度，最后得到的结果就是一个Vector3，RGB值代表物体表面接收到的RGB光能量。

在这里，我们使用到了物体表面法线与光源方向的点积，但是其值可能出现负数的情况（光源照射表面内测），我们是不想出现负值的，因此使用**saturate函数将其clamp到[0,1]区间内**。这样，当照射到表面内侧时，点积结果为0，也就意味着物体表面没有接收到任何光能量。

saturate函数非常之重要，无论是在写任何shader中，我们都会非常频繁使用它（除了saturate，还有lerp、step、smoothstep、clamp等常用的shader数学函数）。在此给出saturate函数的定义：**saturate(x): 当x小于0时，返回0；当x属于[0,1]时，返回x；当x大于1时，返回1**。在此，也给出一篇参考文章[《常用Shader内置函数及使用总结(持续更新)》](https://zhuanlan.zhihu.com/p/353434000)，包括了一系列常用Shader内置函数的定义。

IncomingLight方法代码如下。

```c#
//计算物体表面接收到的光能量
float3 IncomingLight(Surface surface,Light light)
{
    return saturate(dot(surface.normal,light.direction)) * light.color;
}
```

到了这里，我们就可以获取到物体表面接收到的光能量，让其与surface.color相乘就能得到物体最终反射出来的光能量（即漫反射部分）。好了，在这里我再梳理一遍漫反射的计算过程，首先光源有一个color属性代表光源发射出RGB三种光的能量，当光线与物体表面相交，我们通过物体表面法线与光源方向的点积结果（并与light.color相乘）作为物体表面接收到的光能量。然后因为物体表面有一个color属性，表示物体不会吸收且反射出来的光能量，与之相乘结果就是最终的Diffuse部分。

我们再次创建一个同名的GetLighting方法（重载）用来得到以上流程的计算结果。

```c#
//新增的GetLighting方法，传入surface和light，返回真正的光照计算结果，即物体表面最终反射出的RGB光能量
float3 GetLighting(Surface surface,Light light)
{
    return IncomingLight(surface,light) * surface.color;
}
```

最后，改写下之前只传入一个surface的GetLighting方法，之前只是简单写死了从上往下投射的光源，在这里我们调用Light.hlsl中的GetDirectionalLight方法来获取方向光源，再调用GetLighting(Surface surface,Light light)来计算光照结果。

在此给出Lighting.hlsl的完整代码，注意函数之间的顺序不能反（不像C#代码那么随便，用到的方法一定要先被编译），它们具有前后依赖关系。

```c#
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
    return saturate(dot(surface.normal,light.direction)) * light.color;
}

//新增的GetLighting方法，传入surface和light，返回真正的光照计算结果，即物体表面最终反射出的RGB光能量
float3 GetLighting(Surface surface,Light light)
{
    return IncomingLight(surface,light) * surface.color;
}

//GetLighting返回光照结果，这个GetLighting只传入一个surface
float3 GetLighting(Surface surface)
{
    //光源从Light.hlsl的GetDirectionalLight获取
    return GetLighting(surface,GetDirectionalLight());
}

#endif
```

#### 2.3 将光源数据传递给GPU Sending Light Data to the GPU

到目前为止，我们的GetDirectionalLight返回的依然还只是一个我们自己创建的一个方向光源，接下来我们需要支持场景里当前正在使用的方向光源。对于Unity默认创建出来的场景，其中会包含一个代表太阳的方向光源，其颜色值味FFF4D6，Rotation为(50,-30,0)。因此，我们需要将场景中的光源数据传递给GPU供Shader使用。

为了确保方向光能被Shader获取，我们需要创建uniform变量（shader中的全局变量），**通过CBUFFER（Constant Buffer）包裹从Cpu发送过来的两个光源属性（即一个color值和一个方向），CBUFFER名为_CustomLight**。

在第二章《Draw Call》中我们使用CBUFFER来实现批处理技术SRP Batch，在这里再回忆一下CBuffer的含义。CBuffer，即Constant Buffer，常量缓冲区，用于存放在GPU进行一次Draw Call指令的渲染操作内保持不变的数据，访问速度很快，但内存总量也很小。CPU可以在每次发出Draw Call指令前对常量缓冲区进行修改，在这里也就是每一帧cpu可以修改常量缓冲区中的光源属性（光源是可实时变化的）。

我们将该CBuffer段放在Light.hlsl的开头。紧接着，在GetDirectionalLight方法中，将传来的这两个值赋值给light。

Light.hlsl部分代码如下。

```c#
//用CBuffer包裹构造方向光源的两个属性，cpu会每帧传递（修改）这两个属性到GPU的常量缓冲区，对于一次渲染过程这两个值恒定
CBUFFER_START(_CustomLight)
    float3 _DirectionalLightColor;
    float3 _DirectionalLightDirection;
CBUFFER_END

...

//返回一个方向光源，其颜色与方向取自常量缓冲区，cpu每帧会对该缓冲区赋值或修改
Light GetDirectionalLight()
{
    Light light;
    light.color = _DirectionalLightColor;
    light.direction = _DirectionalLightDirection;
    return light;
}
```

到了这里，我们只完成了GPU接收方的工作，接下来我们需要完成CPU这一发送方的工作，那当然就需要编写cs脚本了。首先，我们将建一个Lighting的cs类。在这个Lighting类中，我们做的工作主要就是**获取当前场景中的方向光源（一般只有最重要的一个），然后在DrawCall前将其传递给GPU**。Lighting.cs代码如下所示。

```c#
using UnityEngine;
using UnityEngine.Rendering;

//用于把场景中的光源信息通过cpu传递给gpu
public class Lighting
{
    private const string bufferName = "Lighting";

    //获取CBUFFER中对应数据名称的Id，CBUFFER就可以看作Shader的全局变量吧
    private static int dirLightColorId = Shader.PropertyToID("_DirectionalLightColor"),
        dirLightDirectionId = Shader.PropertyToID("_DirectionalLightDirection");

    private CommandBuffer buffer = new CommandBuffer()
    {
        name = bufferName
    };

    public void Setup(ScriptableRenderContext context)
    {
        //对于传递光源数据到GPU的这一过程，我们可能用不到CommandBuffer下的指令（其实用到了buffer.SetGlobalVector），但我们依然使用它来用于Debug
        buffer.BeginSample(bufferName);
        SetupDirectionalLight();
        buffer.EndSample(bufferName);
        //再次提醒这里只是提交CommandBuffer到Context的指令队列中，只有等到context.Submit()才会真正依次执行指令
        context.ExecuteCommandBuffer(buffer);
        buffer.Clear();
    }

    void SetupDirectionalLight()
    {
        //通过RenderSettings.sun获取场景中默认的最主要的一个方向光，我们可以在Window/Rendering/Lighting Settings中显式配置它。
        Light light = RenderSettings.sun;
        //使用CommandBuffer.SetGlobalVector将光源信息传递给GPU
        //该方法传递的永远是Vector4，即使我们传递的是Vector3，在传递过程中也会隐式转换成Vector4,然后在Shader读取时自动屏蔽掉最后一个分量
        buffer.SetGlobalVector(dirLightColorId, light.color.linear * light.intensity);
        //注意光源方向要取反再传递过去
        buffer.SetGlobalVector(dirLightDirectionId,-light.transform.forward);
    }
}

```

在其中，我们通过**RenderSettings.sun**来获取当前场景中默认的最主要的一个方向光。参考[《官方文档](https://docs.unity3d.com/cn/2021.3/ScriptReference/RenderSettings.html)对RenderSettings的描述，**其包含了场景中一系列视觉元素的值，例如雾效和环境光**。另外，每个Scene都有对应的RenderSettings。RenderSettings.sun为程序化天空盒使用的光照，如果没有，则使用最亮的方向光。RenderSettings.sun的类型为Unity内置的**Light类**，该类为Light组件的脚本接口，其值与光照组件在Inspector中显示的值完全匹配。如下图所示，展示了其Inspector下的属性。

<div align=center>

![20230123221810](https://raw.githubusercontent.com/recaeee/PicGo/main/20230123221810.png)

</div>

通过RenderSettings.sun获取到方向光源后，接下来就是如何将其传递给GPU了。由于我们在Light.hlsl中将待传入的两个光源属性（颜色和方向）放入了CBUFFER（常量缓冲区中），而CBUFFER可以看作Shader全局Uniform常量（一次渲染操作过程中，也可以说是一帧中，其值对于GPU不变），因此我们可以通过**CommandBuffer.SetGlobalVector**将光源颜色和方向（两个Vector3）传递给GPU。

这里详细说下CommandBuffer.SetGlobalVector这个方法，**不管我们实际传递给GPU的是几维Vector，其传递的Vector是恒为Vector4的**。在这里，虽然我们的光源颜色和方向都为Vector3，但是在传递到GPU的过程中，其会被隐式转换成Vector4，并在着色器程序读取该值时自动屏蔽掉最后一个分量。这里就涉及到了如何充分地利用好该函数了，我们要尽可能高效地传递数据。另外参考[官方文档](https://docs.unity3d.com/cn/2021.3/ScriptReference/Rendering.CommandBuffer.SetGlobalVector.html)，CommandBuffer.SetGlobalVector是**添加“设置全局着色器向量属性”命令**（这里添加命令再次体现了CPU和GPU异步执行指令的思想）。在文档中另外还提到了**该方法效果与调用Shader.SetGlobalVector相同**，但是吧，虽然不能完全一口咬定，但我还是建议我们使用CommandBuffer而不是Shader，因为之前听说过CommandBuffer和Graphics接口下效果相同的函数，会因为Unity底层实现原理不同，导致性能不同，CommandBuffer下的指令效率会更高些（Shader不确定），因此我的建议是**能用CommandBuffer就用CommandBuffer**。

最后还有一小点需要提一下，这里我们**在CPU中就直接将光源方向取反再传递给GPU**，原因之前提到过啦~

到了这里，我们场景中的方向光就真正被GPU所使用了，得到了史诗级的画质提升~

<div align=center>

![20230123223322](https://raw.githubusercontent.com/recaeee/PicGo/main/20230123223322.png)

</div>

#### 2.4 当前起效的光源 Visible Lights

**当进行视锥体裁剪（Culling）时，Unity也会找到影响当前可视范围的光源（Unity官方叫做可见光源，但我觉得说是起效的光源更合理）**。我们可以使用这一信息，而不是通过RenderSettings.sun这一全局信息。所以，第一步我们要在Lighting.cs中获取到Culling Results，因此在Setup函数中增加一个传入参数CullingResults（并将其存储为Lighting.cs下的一个字段以方便使用）。同时，由于使用CullingResults下的光源信息，我们可以**支持多个光源**，因此，我们创建并使用SetLights方法代替原来的SetupDirectionalLight。

在SetLights方法中，我们使用**NativeArray**类型局部变量来接收cullingResults.visibleLights。NaviteArray是一个类似于数组的结构，但是**提供了与Native Memory buffer（本机内存缓冲区）的连接，从而无任何编组成本，它使得托管C#数组与Native Unity引擎代码更高效地共享数据**。在[官方文档](https://docs.unity3d.com/cn/2021.3/ScriptReference/Unity.Collections.NativeArray_1.html)中提到，在后台，NativeArrays提供的系统允许将它们安全地用于作业，并自动跟踪内存泄漏。

对于NativeArray这一类型，网上有人说它只是强调了使用的是值类型的数组而不是对象数组，但从官方文档已经可以看出来显然不单单是这样了。这篇[论坛文章《What is NatveArray》](https://forum.unity.com/threads/what-is-nativearray.725156/)中提到，**NativeArray只是个容器，不包含任何数据或内存，但它包含指向本机堆上的C++端创建的本机C++对象的句柄或指针**。所以实际的数组不在托管内存中，不受GC影响，NativeArray本质上包含对本机对象的内部阴影，如果没有正确处理它们，这些对象就会丢失引用。因此，**NativeArray实际指向了原生的C++数组**。此外，在Unity JobSystem、ECS体系中也会使用到NativeArray。简单来说，NativeArray的好处就是：分配C++数组，不需要GC，生成销毁成本低等。

在下一节中，我们将通过NativeArray完成多光照的支持。

2.5 多个方向光源 Multiple Directional Lights

使用cullingResults.visibleLights可以支持多个方向光源，但我们需要通过两个Vector4数组和一个代表当前传递的光源数量的Int类型传递给GPU。此外我们还会定义方向光源的最大数量，使用该值来初始化两个Vector4 Buffer。我们将最大值设置为4，通常来说4完全足够了。

cs代码这里就不多说了，都是些很简单的操作，代码中也详细写了注释，主要是构建dirLightColors和dirLightDiections两个数组，然后通过CommandBuffer.SetGlobalVectorArray传递给GPU。主要提的一点是这里在将VisibleLight这一结构体当参数传递时也使用了**ref关键字**，防止了结构体copy的内存分配，VisibleLight这一结构体的内存算比较大的，因此用时间换空间收益比较大。

```c#
using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;

//用于把场景中的光源信息通过cpu传递给gpu
public class Lighting
{
    private const string bufferName = "Lighting";
    //最大方向光源数量
    private const int maxDirLightCount = 4;

    //获取CBUFFER中对应数据名称的Id，CBUFFER就可以看作Shader的全局变量吧
    // private static int dirLightColorId = Shader.PropertyToID("_DirectionalLightColor"),
    //     dirLightDirectionId = Shader.PropertyToID("_DirectionalLightDirection");
    //改为传递Vector4数组+当前传递光源数
    private static int dirLightCountId = Shader.PropertyToID("_DirectionalLightCount"),
        dirLightColorsId = Shader.PropertyToID("_DirectionalLightColors"),
        dirLightDirectionsId = Shader.PropertyToID("_DirectionalLightDirections");

    private static Vector4[] dirLightColors = new Vector4[maxDirLightCount],
        dirLightDirections = new Vector4[maxDirLightCount];

    private CommandBuffer buffer = new CommandBuffer()
    {
        name = bufferName
    };
    
    

    //主要使用到CullingResults下的光源信息
    private CullingResults cullingResults;

    //传入参数context用于注入CmmandBuffer指令，cullingResults用于获取当前有效的光源信息
    public void Setup(ScriptableRenderContext context, CullingResults cullingResults)
    {
        //存储到字段方便使用
        this.cullingResults = cullingResults;
        //对于传递光源数据到GPU的这一过程，我们可能用不到CommandBuffer下的指令（其实用到了buffer.SetGlobalVector），但我们依然使用它来用于Debug
        buffer.BeginSample(bufferName);
        // SetupDirectionalLight();
        //传递cullingResults下的有效光源
        SetupLights();
        buffer.EndSample(bufferName);
        //再次提醒这里只是提交CommandBuffer到Context的指令队列中，只有等到context.Submit()才会真正依次执行指令
        context.ExecuteCommandBuffer(buffer);
        buffer.Clear();
    }

    //配置Vector4数组中的单个属性
    //传进的visibleLight添加了ref关键字，防止copy整个VisibleLight结构体（该结构体空间很大）
    void SetupDirectionalLight(int index,ref VisibleLight visibleLight)
    {
        //VisibleLight.finalColor为光源颜色（实际是光源颜色*光源强度，但是默认不是线性颜色空间，需要将Graphics.lightsUseLinearIntensity设置为true）
        dirLightColors[index] = visibleLight.finalColor;
        //光源方向为光源localToWorldMatrix的第三列，这里也需要取反
        dirLightDirections[index] = -visibleLight.localToWorldMatrix.GetColumn(2);
    }

    void SetupLights()
    {
        NativeArray<VisibleLight> visibleLights = cullingResults.visibleLights;
        //循环配置两个Vector数组
        int dirLightCount = 0;
        for (int i = 0; i < visibleLights.Length; i++)
        {
            VisibleLight visibleLight = visibleLights[i];
            
            //只配置方向光源
            if (visibleLight.lightType == LightType.Directional)
            {
                //设置数组中单个光源的属性
                SetupDirectionalLight(dirLightCount++, ref visibleLight);
                if (dirLightCount >= maxDirLightCount)
                {
                    //最大不超过4个方向光源
                    break;
                }
            }
        }
        
        //传递当前有效光源数、光源颜色Vector数组、光源方向Vector数组。
        buffer.SetGlobalInt(dirLightCountId, visibleLights.Length);
        buffer.SetGlobalVectorArray(dirLightColorsId, dirLightColors);
        buffer.SetGlobalVectorArray(dirLightDirectionsId, dirLightDirections);
    }
}
```

虽然这一段的代码挺无聊的，但在这里我发现了**特别有意思的一点**！！！我代码写到这一步，在Shader中其实是没有去获取这些Vector数组的，Shader中用的还是原来的单个光源的CBUFFER去渲染。**但此时无论是编辑器下还是运行模式，小球依然会按照之前CBUFFER中遗留的那个单光源的CBUFFER去渲染**！！！也就是说，那个sun光源的属性还在GPU的CBUFFER中，没有被清除，hhhhh，这就是GPU上的常量缓冲区，还是挺有意思的。

#### 2.6 Shader循环 Shader Loop

这一节就是在Shader中接收CPU传来的当前有效光源数（int）和两个Vector数组了。

我们首先使用宏在Shader定义最大光源数（使用宏的原因应该是最大光源数在编译前就确定啦~），然后在名为_CustomLight的CBUFFER中定义当前有效光源数和两个float4数组，注意这里定义数组的格式，同时在Shader中数组在创建时必须明确其长度，创建完毕后不允许修改。Light.hlsl代码如下。

```c#
//用来定义光源属性
#ifndef CUSTOM_LIGHT_INCLUDED
#define CUSTOM_LIGHT_INCLUDED

//使用宏定义最大方向光源数，需要与cpu端匹配
#define MAX_DIRECTIONAL_LIGHT_COUNT 4

//用CBuffer包裹构造方向光源的两个属性，cpu会每帧传递（修改）这两个属性到GPU的常量缓冲区，对于一次渲染过程这两个值恒定
CBUFFER_START(_CustomLight)
    //当前有效光源数
    int _DirectionalLightCount;
    //注意CBUFFER中创建数组的格式,在Shader中数组在创建时必须明确其长度，创建完毕后不允许修改
    float4 _DirectionalLightColors[MAX_DIRECTIONAL_LIGHT_COUNT];
    float4 _DirectionalLightDirections[MAX_DIRECTIONAL_LIGHT_COUNT];
CBUFFER_END

struct Light
{
    //光源颜色
    float3 color;
    //光源方向：指向光源
    float3 direction;
};

int GetDirectionalLightCount()
{
    return _DirectionalLightCount;
}

//构造一个方向光源并返回，其颜色与方向取自常量缓冲区的数组中index下标处
Light GetDirectionalLight(int index)
{
    Light light;
    //float4的rgb和xyz完全等效
    light.color = _DirectionalLightColors[index].rgb;
    light.direction = _DirectionalLightDirections[index].xyz;
    return light;
}

#endif
```
最后，在Lighting.hlsl中的GetLighting(Surface surface)中使用循环来累积所有有效方向光源的光照计算结果。其代码如下。

```c#
//GetLighting返回光照结果，这个GetLighting只传入一个surface
float3 GetLighting(Surface surface)
{
    //使用循环，累积所有有效方向光源的光照计算结果
    float3 color = 0.0;
    for(int i=0;i<GetDirectionalLightCount();i++)
    {
        color += GetLighting(surface,GetDirectionalLight(i));
    }
    return color;
}
```

好了，这一章终于终于完成了一半了！虽然工作内容都很简单，但是抵不住量大吖。最后试试看效果吧，我们的画质又有了一次史诗级的提升！！！（PUA自己还是可以的）

<div align=center>

![20230124012235](https://raw.githubusercontent.com/recaeee/PicGo/main/20230124012235.png)

</div>

如果说实际使用的项目一定只有一个方向光源，那么我们可以去掉这些循环，或者制作着色器变体。但是在该教程中并不会这么做（还是通用为主~）。最好的性能表现总是通过针对具体项目而言去掉所有不需要的东西来实现的。


#### 参考

1. https://zhuanlan.zhihu.com/p/353434000
2. https://forum.unity.com/threads/what-is-nativearray.725156/