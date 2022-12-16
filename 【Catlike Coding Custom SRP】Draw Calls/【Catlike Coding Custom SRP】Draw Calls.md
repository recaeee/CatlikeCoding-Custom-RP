# 【Catlike Coding Custom SRP学习之旅——2】Draw Calls
#### 写在前面
很高兴第一章有许多人看，因此我也不能懈怠，抓紧时间开始弄第二章。同时，这两天还在考虑毕设选题的事情，我在犹豫是搭建SRP+风格化渲染还是在URP的基础上直接着重开展风格化渲染（渲染的风格偏PBR+NPR的结合。前者由于搭建SRP会花大量的时间，所以工作量会比较大，而后者直接使用URP，但这样对管线的改造可能就会比较少，更多的时间会花在制作材质上。关于这方面我也问了大佬前辈，目前考虑的还是前者，肝起来肝起来~

以下是原教程链接与我的Github工程（Github上会实时同步最新进度）：

[CatlikeCoding-SRP-Tutorial](https://catlikecoding.com/unity/tutorials/custom-srp/)

[我的Github工程](https://github.com/recaeee/CatlikeCoding-Custom-RP)

废话少说，开始撕第二章吧！

--- 

![20221212230835](https://raw.githubusercontent.com/recaeee/PicGo/main/20221212230835.png)

#### Draw Calls

在第二章，我们的主题是DrawCalls，那还是首先唠唠什么是Draw Call吧。不管怎么说，Draw Call的含义比第一章的“自定义渲染管线”的含义理解起来容易多了。这里就直接参考《Shader入门精要》中对Draw Call的解释，**CPU通过调用Draw Call来告诉GPU开始一个渲染过程。一个Draw Call会指向本次调用需要渲染的图元列表**。

从这两句解释中，我们可以获得这些信息：1，Draw Call这个命令的发起方是CPU，接收方是GPU；2，Draw Call中传递的信息为“需要渲染的图元列表”。而**图元列表**其实就是一系列顶点、材质、纹理、着色器等数据。

更概念化地来说，**Draw Call是CPU调用图像编程接口，如OpenGL中地glDrawElements命令，以命令GPU进行渲染的操作。我们可能会疑惑，在上一段话中我们说过Draw Call会传递顶点、纹理这些数据，但在这里我们又说Draw Call是一系列渲染命令，似乎不涉及数据的传递。

但其实我觉得两种说法都对，因为**一次Draw Call往往伴随着大量数据的传递**，这些大量的数据就是顶点、纹理这些数据。注意我说的是“伴随”，因为这些数据的传递其实是在Draw Call之前完成的。

在这里，我们梳理一下从CPU为起点，到Draw Call调用的流程。参考《Shader入门精要》，其经历了如下过程：1，把数据加载到显存中，把渲染所需的所有数据（顶点、法线、纹理坐标等）从硬盘加载到RAM，再从RAM加载到显存；2，设置渲染状态，设置着色器、光源属性、材质等；3，调用Draw Call，告诉GPU开始渲染。

由此可见，在Draw Call调用之前，我们会进行Mesh数据、材质数据、光源属性等等的传递，因此Draw Call的调用始终伴随着这些数据的传递。

总而言之，《Shader入门精要》对Draw Call进行了比较生动的解释，如果还不理解，可以看下原书。

而实际放到Unity中，我们在哪里体现出Draw Call呢？答案是，**一次DrawRenderer往往会产生一至多个Draw Call**。那我们知道，DrawRenderer这个函数是在CommandBuffer下的，那这里我们再谈回到CommandBuffer，思考这样一个问题，**为什么我们需要CommandBuffer？** 我们知道，CommandBuffer将一系列指令缓存在队列中一次提交给GPU，那为什么我们不是告诉GPU一条指令、GPU执行一条指令这样做呢？

其原因就是**Command Buffer（命令缓冲区）实现了让CPU和GPU并行工作**。命令缓冲区包含了一个命令队列，CPU向其中添加指令，GPU从中读取指令，添加和读取的过程是互相独立的。CommandBuffer中的指令有很多种，Draw Call是其中一种。

在每次调用Draw Call之前CPU都要向GPU发送许多内容（包括数据、状态、指令等），因此Draw Call的增多会使CPU压力过大，造成性能瓶颈。而为了减少Draw Call，我们就引入了**批处理（Batching）**的方法，把多个小量Draw Call合并成一个大的Draw Call。

由此我们知道了何为Draw Call，Command Buffer的作用以及为什么我们要减少Draw Call。在这一章中，我们就会编写一系列Shader，使其支持**SRP Batcher、GPU Instancing和Dynamic Batching**这些批处理技术。

---

#### 1 着色器 Shaders

在渲染中，Mesh意味着绘制什么，而Shader决定了怎么绘制它。在我的理解中，Shader就相当于着色器上的一些小程序，在其中我们会定义顶点着色器、片元着色器来决定绘制的方法，而且其通常也需要获取到物体的变换矩阵和一些材质属性。

我想对于Shader的最好的学习方式，无非就是自己去写一些Shader，有时候说得再多都不如自己动手感受下直观。而通过这一章的学习，我们就会对Shader的基本组成和运作方式有一定理解。废话少说，开始写代码~

#### 1.1 无光照着色器 Unlit Shader

我们要写的第一个Shader是最简单的UnlitColor，也就是使用一个固定的颜色渲染一个mesh，通过编写这样一个简单的Shader，我们会去了解Shader的整体结构。

```c#
Shader "Custom RP/Unlit"
{
    Properties {}

    SubShader
    {
        Pass {}
    }
}
```

以上就是能编译通过的最最简单的Shader，在它的内部没有做任何事，只是写了一些关键字。但通过这个Shader，我们已经能够知道许多关于Shader的重要知识，因为通过它我们就可以知道Shader中所有必不可少的组成部分（因为它就是最简单的Shader了）。

先从结果来看，如果我们使用这个Shader创建一个材质，然后赋给一个物体，那么我们会看到这个物体变成了纯白色（有人或许会问为什么是纯白色，我也想知道，可能是默认的颜色？）。但我们更需要先看的是这个材质的Inspector视图。

<div align=center>

![![20221216225449](httpsraw.githubusercontent.comrecaeeePicGomain20221216225449.png)](https://raw.githubusercontent.com/recaeee/PicGo/main/!%5B20221216225449%5D(httpsraw.githubusercontent.comrecaeeePicGomain20221216225449.png).png)

</div>

首先，我创建的这个材质命名为Unlit，Shader使用了上一步创建的Custom RP/Unlit，因此我们得知第一点，**每一个材质都需要其对应的Shader**（也就是说材质的创建依赖于Shader）。在我看来，Shader就好比定义一个C#类，而材质就是这个类的实例，在Shader中我们往往会定义一些参数，而在材质中我们需要赋予和确定这些参数的值。

其次，我们可以看到对于一个材质，它会拥有一个**Render Queue**的属性，其默认值是2000（From Shader意味着采用了Shader中的默认值，因为我们的Shader中没有设定这个默认值，所以Unity给它赋了个默认值2000）。

**Render Queue代表了此材质的渲染队列**，简单来说，**Render Queue意味着使用这个材质的物体在渲染管线中被渲染的顺序**。[官方文档](https://docs.unity3d.com/cn/2021.3/ScriptReference/Material-renderQueue.html)中说到，**Render Queue的值应该处于[0,5000]，或者为-1使用着色器的渲染队列**。

好了，说完了“简单来说”，接下来就是“复杂来说”了。

首先来具体了解一下Unity内置的渲染队列吧，这里直接引用了[这篇文章](https://qxsoftware.github.io/Unity-Rendering-Order.html)中对渲染队列的整理，感兴趣也可以去看下原文。从图中可以直观看出，Render Queue的值越大，渲染越靠后。

<div align=center>

![20221216235314](https://raw.githubusercontent.com/recaeee/PicGo/main/20221216235314.png)

</div>

对于物体的渲染顺序，我们在第一章中知道了我们可以通过在DrawSettings中设置一次DrawRenderers中物体的渲染顺序（例如对于Opaque通常从前往后，对于Transparent通常从后往前）。那结合上图来看，Render Queue设置的渲染顺序和DrawSettings设置的渲染顺序之间的层级关系就显而易见了，**Render Queue确定了不同材质之间的渲染顺序（比如先渲染2000的Opaque物体再渲染3000的Transparent物体），而DrawSettings确定了同一Render Queue下的材质的渲染顺序（比如对于所有Render Queue=2000的Opaque物体从前往后渲染）**。

在[原文](https://qxsoftware.github.io/Unity-Rendering-Order.html)中还讲了一些其他决定渲染顺序的参数以及它们之间的层级关系，在此不多展开，有兴趣的可以看下原文。

好了，到了这里，我们基本上对一个材质的必要组成有所了解（Double Sided Global Illumination目前可忽略），总的来说**材质必须有其使用的Shader，以及一个Render Queue的值**。接下来，我们回到Shader代码中，看一下一个Shader的必要组成部分。

#### 参考

1. 《Shader入门精要》——冯乐乐
2. https://qxsoftware.github.io/Unity-Rendering-Order.html