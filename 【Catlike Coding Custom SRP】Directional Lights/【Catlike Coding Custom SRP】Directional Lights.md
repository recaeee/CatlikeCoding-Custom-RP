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