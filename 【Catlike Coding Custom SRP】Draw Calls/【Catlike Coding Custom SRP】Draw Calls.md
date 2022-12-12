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

其原因就是**Command Buffer（命令缓冲区）实现了让CPU和GPU并行工作**。

最后再明确一点，CommandBuffer中的指令有很多种，Draw Call是其中一种。

---

#### 参考

1. 《Shader入门精要》——冯乐乐