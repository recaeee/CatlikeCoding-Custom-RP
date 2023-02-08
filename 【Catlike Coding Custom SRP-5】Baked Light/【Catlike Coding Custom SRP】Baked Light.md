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

首先，什么是光照贴图？

光照贴图将预先计算好场景中表面的亮度，并将结果存储在其中，供以后使用。**光照贴图可以包含直接光和间接光**。

对于每一个Scene，其都有自身的全局光照配置。我使用的Unity 2021版本将**Lighting Settings**又构造成了Asset，更方便地用于配置，如下图所示。

<div align=center>

![20230207225344](https://raw.githubusercontent.com/recaeee/PicGo/main/20230207225344.png)


</div>

具体如何配置就不展开了，无论是看原教程还是官方文档都可以快速了解到每个属性的具体意义和用法。

在Lighting Settings中，**Mixed Lighting**用于烘培GI，将Lighting Mode设置为**Baked Indirect**。

参考[《官方文档——Lighting Mode》](https://docs.unity3d.com/cn/2021.3/Manual/LightMode-Mixed-BakedIndirect.html)，在Baked Indirect模式下，混合模式的光源Mixed Light行为如下：

对于混合光源照亮的**动态对象**，将接收到：
1. 混合光源的实时直接光照。
2. 根据**光照探针**得到的烘培间接光照。
3. 阴影贴图上动态对象的阴影。
4. 阴影贴图上静态对象的阴影。

对于混合光照照亮的**静态对象**，将接收到：
1. 实时直接光照。
2. 根据**光照贴图**得到的烘培间接光照。
3. 阴影贴图上动态对象的阴影。
4. 阴影贴图上静态对象的阴影。

可以看到，**混合光源的所有阴影在Baked Indirect光照模式下都是实时的**。

另外，我们将Directional Mode设置为**Non-Directional**模式，意味着在烘培光照贴图时不考虑物体的法线贴图（目前我们的管线也不支持法线贴图），Lighting视图如下图所示。

<div align=center>

![20230206235648](https://raw.githubusercontent.com/recaeee/PicGo/main/20230206235648.png)

</div>

#### 1.2 静态对象 Static Objects

为了直观地观察GI的效果，在场景中，我摆放了一些物体，如下图所示(此时并未使用GI)。

<div align=center>

![20230207233027](https://raw.githubusercontent.com/recaeee/PicGo/main/20230207233027.png)

</div>

第一步，将光源Light组件上的Mode设置为Mixed，**Mixed意味着该光源会作为实时光源在运行时加入渲染计算，也会在非运行时为GI烘培间接光照的光照贴图**。

第二步，将场景中的静态物体的MeshRenderer组件中开启Contribute Global Illumination，意味着**在GI系统计算时这些物体表面接收到的光线会被烘培到光照贴图中**。

接下来，自动或手动开始烘培，得到烘培好的光照贴图如下图所示。

<div align=center>

![20230207233915](https://raw.githubusercontent.com/recaeee/PicGo/main/20230207233915.png)

</div>

GI会为当前场景生成一张光照贴图，这张光照贴图中**存储了参与GI的光源所造成的间接光照信息**，它是场景中所有参与GI的物体共有的，每个物体表面在光照贴图上都占有其自身的一块UV。该光照贴图目前几乎只包括了蓝色，是因为**GI计算出的间接光照颜色大部分都受天空盒的蓝色环境光影响**（天空盒的环境光可以看作来自四面八方的光线，Mixed模式的方向光源也参与了GI计算，其间接光照信息被烘培了下来，但由于其颜色接近纯白，在光照贴图中难以察觉）。

**环境光Ambient Light**是场景周围存在的光，**并非来自任何特定的光源对象**。在Lighting视图中可以设置当前使用的环境光，可以看到当前Ambient Light源自天空盒。

<div align=center>

![20230208210842](https://raw.githubusercontent.com/recaeee/PicGo/main/20230208210842.png)

</div>

#### 1.3 完全烘培的光照 Fully-Baked Light

将方向光源设置成Baked模式，意味着该光源不再参与实时光照计算，只参与GI计算，但**在Baked模式中，光源带来的直接光照信息也会被烘培到光照贴图中**。如下图所示，我将方向光源颜色暂时设置为纯红色，并且设置为Baked模式，光照贴图变亮且变红，其直接光照信息被烘培到了光照贴图中。

<div align=center>

![20230207235251](https://raw.githubusercontent.com/recaeee/PicGo/main/20230207235251.png)

</div>

#### 2 采样烘培光照信息 Sampling Baked Light

我们将在这一节实现在Shader中采样光照贴图。

#### 2.1 全局光照 Global Illumination

Shader中具体实现部分不详细展开了，通过采样光照贴图，我们可以获取到片元的烘培间接光照结果，也就是片元接收到的间接光照能量。**对于这一部分间接光照能量，片元将完全以漫反射形式反射出去**。这一点是显而易见的，预计算的光照必然考虑不了摄像机的朝向，而高光Specular的计算需要根据摄像机朝向，漫反射Diffuse则是向任意方向反射相同的光能量。

#### 2.2 光照贴图坐标 Light Map Coordinates

在shader中，我们需要采样LightMap，因此需要在CPU端将每个物体在光照贴图上的UV信息传递给GPU。Unity封装好了传递光照贴图UV的方法与数据结构，相关Unity类：**DrawingSettings和PerObjectData**。

**在启用光照贴图时，Unity会启用LIGHTMAP_ON的Shader关键字**，因此我们需要在Lit.shader中定义该关键字，并使用宏定义顶点着色器、片元着色器中的GI数据，以及GI的相关代码。这些代码都通过宏控制，因为只有在LIGHTMAP_ON启用时，这些GI相关代码才需要被编译。

下图为将每个物体在光照贴图上的uv(float2)信息输出到像素的rg通道的结果。

<div align=center>

![20230208225026](https://raw.githubusercontent.com/recaeee/PicGo/main/20230208225026.png)

</div>

#### 2.3 变换光照贴图坐标 Transformed Light Map Coordinates

我们传递给GPU的光照贴图包含了所有参与GI的物体，因此每个物体在光照贴图上都拥有其独一无二的UV区域。而GPU得到的每个顶点的光照贴图UV是未经过变换的，**我们需要通过UV展开获取到每个物体每个顶点在光照贴图上独一无二的UV坐标**。因此我们需要通过将定义UV展开方式的float4数据传递给GPU，并应用于顶点的lightmapUV。另外，光照贴图技术也可以作用于GPU Instancing。

关于**UV展开**，可参考[《网格UV展开》](http://geometryhub.net/notes/uvunfold)，简单来说UV展开的作用是将三角网格与一个二维平面形成一一映射的关系，如下图所示，左边图为UV展开后的顶点坐标，右图为原Mesh，图片源自[《网格UV展开》](http://geometryhub.net/notes/uvunfold)。

<div align=center>

![20230208231455](https://raw.githubusercontent.com/recaeee/PicGo/main/20230208231455.png)

</div>

那对于整个场景中参与GI的物体的UV展开如何去做就很简单了，把整个场景中这些物体都当作一个Mesh就行了。

应用光照贴图坐标变换后，每个片元都拥有了其自身正确的光照贴图UV，可视化效果图如下所示，每个片元的颜色都不同了。

<div align=center>

![20230208231741](https://raw.githubusercontent.com/recaeee/PicGo/main/20230208231741.png)

</div>

#### 2.4 采样光照贴图 Sampling the Light Map

有了正确的光照贴图UV坐标，就可以采样光照贴图了。

采样的过程很简单，不必多言，在shader中，CPU传来的光照贴图名为**unity_Lightmap**。采样中，使用了CoreRP中的EntityLighting.hlsl与其中的SampleSingleLightmap函数，在此不做过多展开。

实现采样后，我们可以得到效果图如下。由于我们的方向光源为Baked模式，因此其直接光照也会被计算在光照贴图中，而不作用于实时光照。

<div align=center>

![20230208234638](https://raw.githubusercontent.com/recaeee/PicGo/main/20230208234638.png)

</div>

#### 2.5 关闭环境光 Disabling Environment Lighting

#### 参考

1. https://zhuanlan.zhihu.com/p/126362480
2. https://docs.unity3d.com/cn/2018.2/Manual/GIIntro.html
3. https://docs.unity3d.com/cn/2021.3/Manual/LightMode-Mixed-BakedIndirect.html
4. 所有涩图均来自wlop大大