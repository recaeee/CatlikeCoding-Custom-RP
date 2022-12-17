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

更概念化地来说，**Draw Call是CPU调用图像编程接口，如OpenGL中地glDrawElements命令，以命令GPU进行渲染的操作**。我们可能会疑惑，在上一段话中我们说过Draw Call会传递顶点、纹理这些数据，但在这里我们又说Draw Call是一系列渲染命令，似乎不涉及数据的传递。

但其实我觉得两种说法都对，因为**一次Draw Call往往伴随着大量数据的传递**，这些大量的数据就是顶点、纹理这些数据。注意我说的是“伴随”，因为这些数据的传递其实是在Draw Call之前完成的。

在这里，我们梳理一下从CPU为起点，到Draw Call调用的流程。参考《Shader入门精要》，其经历了如下过程：1，把数据加载到显存中，把渲染所需的所有数据（顶点、法线、纹理坐标等）从硬盘加载到RAM，再从RAM加载到显存；2，设置渲染状态，设置着色器、光源属性、材质等；3，调用Draw Call，告诉GPU开始渲染。

由此可见，在Draw Call调用之前，我们会进行Mesh数据、材质数据、光源属性等等的传递，因此Draw Call的调用始终伴随着这些数据的传递。

总而言之，《Shader入门精要》对Draw Call进行了比较生动的解释，如果还不理解，可以看下原书。

而实际放到Unity中，我们在哪里体现出Draw Call呢？答案是，**一次DrawRenderer往往会产生一至多个Draw Call**。那我们知道，DrawRenderer这个函数是在CommandBuffer下的，那这里我们再谈回到CommandBuffer，思考这样一个问题，**为什么我们需要CommandBuffer？** 我们知道，CommandBuffer将一系列指令缓存在队列中一次提交给GPU，那为什么我们不是告诉GPU一条指令、GPU执行一条指令这样做呢？

其原因就是**Command Buffer（命令缓冲区）实现了让CPU和GPU并行工作**。命令缓冲区包含了一个命令队列，CPU向其中添加指令，GPU从中读取指令，添加和读取的过程是互相独立的。CommandBuffer中的指令有很多种，Draw Call是其中一种。

在每次调用Draw Call之前CPU都要向GPU发送许多内容（包括数据、状态、指令等），因此Draw Call的增多会使CPU压力过大，造成性能瓶颈。而为了减少Draw Call，我们就引入了**批处理（Batching）** 的方法，把多个小量Draw Call合并成一个大的Draw Call。

由此我们知道了何为Draw Call，Command Buffer的作用以及为什么我们要减少Draw Call。在这一章中，我们就会编写一系列Shader，使其支持**SRP Batcher、GPU Instancing和Dynamic Batching**这些批处理技术。

---

#### 1 着色器 Shaders

首先来唠唠Unity中的Shader吧。

我们在Unity中编写Shader使用的语法是Unity特有的**ShaderLab**，但它其实就是多种Shader语言（例如在其中可以使用HLSL、CG语言）的混合版，再加上一些特定的语法框架。

其实通常来说着色器就是Shader（在本文中也会这么认为，不做明确区分，但是还是要提一下），毕竟英文翻译过来就是这样。但是Unity对于Shader组织了一种新的数据类型，即**Shader对象**，我们在Unity中所编写的 **.shader文件**，其实是在编写**Shader类**，它和通常意义上的Shader最大的区别在于**一个Shader类之中可以定义多个通俗意义上的Shader（着色器程序）**，也就是多个**SubShader**，而这些SubShader其实才是我们通常所说的Shader。根据SubShader的官方说明，我们可以显而易见知道Unity组织Shader类这一数据结构的目的就在于**兼容不同的硬件、渲染管线和运行时设置**。在渲染管线实际运行时，Unity就会将我们编写的Shader类实例化成**Shader对象**使用。

<div align=center>

![20221217135637](https://raw.githubusercontent.com/recaeee/PicGo/main/20221217135637.png)

*一个.shader文件*

</div>

而**一个SubShader的组成通常来说是一到多个Pass（也就是通道）**，而**一个Pass就是Shader对象中的最小单位**。官方对Pass的定义如下，**Pass是Shader对象的基本元素，它包含设置GPU状态的指令，以及在GPU上运行的着色器程序**。在一个Pass中，我们就会去定义我们最熟悉不过的**顶点着色器**（vertex函数）和**片元着色器**（fragment函数）。那如果大家编写过一些OpenGL，我们可能会感到诧异，因为在OpenGL中，我们会将Vertex Shader和Fragment Shader这些**着色器程序**定义为一个着色器，这么看来，在Unity中其实是一个Pass相当于一个完整的“着色器”（不是SubShader）？虽然说早期我也一直这么认为（认为一个Pass其实相当于一套Shader），的确很有道理，但其实这样的思想有些许欠妥。

对于这块的解释，且听我胡扯一番。我们首先看一下官方对Pass说过这样一句话，**简单的Shader对象可能只包括一个通道，但更复杂的着色器可以包含多个通道**。我们举一个很简单的例子就可以打破“Pass就是一套通俗意义上Shader”的思想。我们举例一个所谓的“简单的只包括一个Pass”的Shader对象，一个UnlitShader，在这个Pass中，我们让物体绘制成纯红色。简单思考一下，这个Pass里的vertex和fragment函数很简单吧，并且只要一个Pass就够了吧。那我们再举例一个“更复杂”的Shader对象，在这个SubShader中，我们还是把物体绘制成纯红色，**但是我们还希望这个物体能投射阴影**。这时候再思考一下，在这个Shader中，我们总共需要一个Pass来绘制纯红色，**还需要一个Pass来让物体渲染在阴影贴图上**，意味着在这个SubShader中我们需要定义2个Pass。通过这样一个例子（纯色渲染、纯色渲染+投射阴影），我们就能区分一个SubShader和一个Pass的区别，**SubShader决定了我们在整个渲染管线流程中渲染这个物体的所有行为（一个物体可能被渲染多次，可能一次屏幕上，一次阴影贴图上）**，而**一个Pass决定了我们对这个物体的一次渲染行为**。而在理解这点后，我们就会发现，如何理解SubShader和Pass就取决于我们对通俗意义上的Shader的理解，如果认为Shader确定了一次对物体的渲染行为（走一个顶点着色器，再走一个片元着色器），那Pass就是Shader；如果认为Shader确定了在整套渲染流程中物体的所有渲染行为，那SubShader就是Shader。曾经我更倾向前者，现在我更倾向后者。

好了，唠了这么多，大家是否对**通俗意义上的Shader、Unity中的Shader类、Shader对象、SubShader、Pass**这几个概念和它们之间的关系有了一定理解呢？

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

好了，到了这里，我们基本上对一个材质的必要组成有所了解（Double Sided Global Illumination目前可忽略），总的来说，**一个材质必须有其使用的Shader，以及一个Render Queue的值**。接下来，我们回到Shader代码中，看一下一个Shader的必要组成部分（再次贴上Shader的代码）。

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

Shader的第一行首先为**Shader**的关键字，后面的字符串定义了该Shader的目录以及名字。在Shader中我们首先声明**Properties**关键字，**Properties代码块为Shader对象定义材质属性的信息**，具体定义和语法格式可以看下[官方文档](https://docs.unity3d.com/cn/2021.3/Manual/SL-Properties.html)，我们可以在材质的Inspector窗口中编辑这些值（主要目的），当然也可以通过代码设置其值。我们先不展开，在后续实际编写Shader的时候，我们自然而然就理解这些概念了。

声明完Properties之后，我们会声明**一至多个**SubShader。在一个SubShader中我们会声明**一至多个**Pass。更多的概念，我们从实际编写Shader时一点点理解。

#### 1.2 HLSL程序 HLSL Programs

HLSL的全称为High-Level Shading Language，在Unity中编写Shader类时，对于所有HLSL程序，我们都比u使用**HLSLPROGRAM**和**ENDHLSL**关键字来包裹HLSL代码，其原因是在一个Pass中我们可能还会使用其他语言（如CG）。在本教程中，我们会使用HLSL语言，而不是CG语言，一点原因是CG语言已经过时啦，它已经不更新了，HLSL可以说是现在的主流吧。

#### 参考

1. 《Shader入门精要》——冯乐乐
2. https://qxsoftware.github.io/Unity-Rendering-Order.html