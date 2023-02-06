# 【Catlike Coding Custom SRP学习之旅——5】Baked Light
#### 写在前面
在实时渲染管线中，为了达到更好的性能与间接光照效果，可以利用光照烘培来非实时地预计算并生成LightMap等静态光照信息。通过本章节的学习，可以对Unity全局光照系统、光照贴图、光照探针有一定了解，并能够使用这些技术来提高游戏的光照质量。

前3章节为长篇文章，考虑到篇幅问题与工作量，从第4章节后半部分开始以及未来章节，考虑以提炼原教程为主，尽量减少篇幅与实际代码，在我的Github工程中包含了对源代码的详细注释，如需深入代码细节可以查看我的Github工程。

以下是原教程链接与我的Github工程（Github上会实时同步最新进度）：

[CatlikeCoding-SRP-Tutorial](https://catlikecoding.com/unity/tutorials/custom-srp/)

[我的Github工程](https://github.com/recaeee/CatlikeCoding-Custom-RP)

--- 

<div align=center>

![20230206232622](https://raw.githubusercontent.com/recaeee/PicGo/main/20230206232622.png)

</div>

#### 1 烘培静态光照 Baking Static Light

烘培静态光照指在非运行时计算出一些场景中始终不会变化的光照信息并离线存储，在运行时就可以使用这些预先计算好的光照信息来渲染物体。烘培静态光照最主要的两个烘培对象是光照贴图Light Map与光照探针Light Probes，这些光照信息包括了直接光照和间接光照。

在谈具体的烘培静态光照之前，首先来简单看下**全局光照Global Illumination**（简称GI）这个概念吧。

关于GI，我主要参考了[Kerry的《写给美术看的Unity全局光照技术(理论篇)》](https://zhuanlan.zhihu.com/p/126362480)，该文章详细生动地讲解了Unity GI系统，强烈建议感兴趣的同学阅读。

1. 何为全局光照？

全局光照是一个用于模拟**直接从光源照射到表面的光**（直射光）与从**表面反射到其他表面的光**（间接光）的**系统**。简单来说，全局光照 = 直接光照 + 间接光照。另外，间接光照Indirect Lighting的定义为**自光源发射，至少击中场景表面两次，最终到达摄像机的光线**。

2. 全局光照的作用？

通常实时渲染管线中只会实时计算**直接光照**部分，导致的结果就是场景中一块区域如果没有被任何光照射到，其就是纯黑色的，但根据物理学，这块区域会被其他物体表面反射的间接光所照射，从而会被照亮一些。而间**接光照的计算非常复杂**，几乎只能用于非实时渲染，比如CG动画电影。间接光照能极大程度地提升画面的质量，因此，为了在实时管线中也使用上全局光照，我们为事先已知不会移动的**静态对象和表面**计算间接光照，来让这些被烘培的静态物体上获得间接光照，得到高质量的渲染结果。简单来说，全局光照主要实现了实时计算很难实现的间接光照效果，但需要注意，它不只是间接光照，其包括了直接光照和间接光照。

3. 全局光照的局限？

很显然，全局光照只会对静态对象进行光照信息的预计算，因此这些**静态对象不能将光反射到动态对象上**，反之亦然。虽然可以通过光照探针Light Probes来模拟动态对象接收到的间接光照，但其质量依然相对较差。

好了，以上就是全局光照的一些主要概念，而烘培静态光照Baking Static Light指的就是预计算场景中全局光照的信息。

#### 1.1 场景光照设置 Scene Lighting Settings

我们要做的第一件事是为场景中的静态对象烘培光照贴图。

对于每一个Scene，其都有自身的全局光照配置。我使用的Unity 2021版本将Lighting Settings又构造成了Asset，更方便地用于配置。

具体如何配置就不展开了，无论是看原教程还是官方文档都可以快速了解到每个属性的具体意义和用法。

在Lighting Settings中，我们将Directional Mode设置为Non-Directional模式，意味着在烘培光照贴图时不考虑物体的法线贴图（目前我们的管线也不支持法线贴图），Lighting视图如下图所示。

<div align=center>

![20230206235648](https://raw.githubusercontent.com/recaeee/PicGo/main/20230206235648.png)

</div>

#### 1.2 静态对象 Static Objects



#### 参考

1. https://zhuanlan.zhihu.com/p/126362480
2. https://docs.unity3d.com/cn/2018.2/Manual/GIIntro.html
3. 所有涩图均来自wlop大大