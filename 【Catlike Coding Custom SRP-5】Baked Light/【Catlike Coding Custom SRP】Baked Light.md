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

目前的GI计算考虑了方向光源与天空盒的环境光，为了只关注方向光源，在Lighing Settings中将环境光强度设置为0。效果图如下，可以看到，原本映射出蓝色的一些地方不再映射蓝色了，并且整体画面变暗了一些。

<div align=center>

![20230209230608](https://raw.githubusercontent.com/recaeee/PicGo/main/20230209230608.png)

</div>

#### 3 光照探针 Light Probes

动态对象不参与GI计算，但它们可以通过光照探针被GI影响，也就是使用GI烘培结果估算其受到的间接光照。

参考[《官方文档——光照探针》](https://docs.unity3d.com/cn/2021.3/Manual/LightProbes.html)，**光照探针可以捕获并使用穿过场景空白空间的光线的相关信息**。也就是说，当一个动态物体靠近这个光照探针，光照探针就会告诉它“朝你这个方向有什么样的光线射过来”，然后动态物体表面就可以得到间接光照效果。在运行时，系统将使用距离动态物体游戏对象最近的探针的值来估算照射到这些对象的间接光。

1. 光照探针如何存储间接光照信息？

光照探针中的照明信息被编码为**球谐函数**，实际使用为L2球谐函数，其使用27个浮点值存储，每个颜色通道9个。关于球谐函数，具体可以参考[《球谐函数介绍（Spherical Harmonics）》](https://zhuanlan.zhihu.com/p/351289217)，简单来说，**球谐函数是一组基函数**，通过这一组基函数，再结合每一个基函数的系数，可以用于模拟任意函数，有点类似傅里叶变换。在规定好基函数后，在通信时只需要传递每个基函数的系数就足够了，接收方通过这些系数就可以大致模拟出原函数，有点信号处理的感觉。**基函数越多，能模拟原函数的能力越强，但同时也会导致传递的数据量（系数）增大**。而球谐函数的作用就是作为一个球面坐标系的基函数，光照探针中存储的光照信息实际上就是球面坐标系上的一个函数（任意方向都有值）。以下为球谐函数的示意图，其中每一个绿色、紫色小球的组合就是L2球谐函数的一个基函数，一共9组，给定9个系数，就可以得到右边的函数（球面光照信息）。

<div align=center>

![20230210185413](https://raw.githubusercontent.com/recaeee/PicGo/main/recaeee/PicGo20230210185413.png)

</div>

2. 如何采样光照探针？

官方给出了[《GDC 2012 使用四面体曲面细分的光照探针插值》](https://gdcvault.com/play/1015312/Light-Probe-Interpolation-Using-Tetrahedral)作为其原理的参考。关于采样光照探针的简单原理可以参考[《再谈Unity中的光照探针技术》](https://zhuanlan.zhihu.com/p/439706412)。其主要使用了**四面体插值**，简单来说，在采样空间一个点的Radiance函数值时，找到其最近的由4个光照探针组成的四面体，如果该点在四面体内部，则根据类似**四面体下的重心坐标**的算法求出4个光照探针的系数，通过这4个系数与光照探针内部存储光照值**插值**得到该点的间接光照。如果该点在四面体外部，则将该点沿四面体顶点法线方向投影到四面体上，再进行计算。

下图为截取自[GDC PDF](https://zhuanlan.zhihu.com/p/439706412)中的**四面体插值示意图**，P0、P1、P2、P3构成了一个四面体，P在四面体中，其中P = aP0 + bP1 + cP2 + dP3。下图中还包括了a、b、c、d四个值的计算公式，这四个值就是用来对四个光照探针的信息插值的。

<div align=center>

![20230209233803](https://raw.githubusercontent.com/recaeee/PicGo/main/20230209233803.png)

</div>

**通过对4个光照探针进行四面体插值，得到一个插值后的光照探针，对于一个动态物体，在渲染该物体时就只会采样这唯一一个插值后的光照探针，因此对于一个物体，只需要传递一组系数（27个）**。

#### 3.1 光照探针组

放置光照探针就不必多说了，Unity将一大批光照探针都整合到了光照探针组中，方便管理。对于一个光照探针组，Unity会自动构建出一个**四面体组Mesh**，未来渲染画面时每个片元就会只属于一个四面体内，然后使用四面体插值，原理在上面就说过了。

放置光照探针的一些要点：

1. 光照探针只需要放在动态物体会经过的地方。
2. 光照探针不能放在静态物体内部，防止光照探针接收不到任何光照。
3. 对于墙面这类结构，将光照探针紧贴其两侧，防止片元出现在穿过墙面的四面体中。

下图为我随意摆放的光照探针组。

<div align=center>

![20230210194039](https://raw.githubusercontent.com/recaeee/PicGo/main/recaeee/PicGo20230210194039.png)

</div>

#### 3.2 采样光照探针 Sampling Probes

采样光照探针的原理就是四面体插值，我们不需自己写采样函数，只需要将球谐函数的27个系数以及物体表面的发现信息传递给封装好的SampleSH9函数就行了。

注意，采样光照探针的永远是动态物体，静态物体使用的是光照贴图。并且它们采样出来的光照结果都是作为Diffuse用的，不存在Specular部分。

实现采样光照探针后，场景中的动态物体就有了间接光照作为Diffuse光照，如下图所示（小球从光照探针中获取到了间接光照）。

<div align=center>

![20230214175925](https://raw.githubusercontent.com/recaeee/PicGo/main/recaeee/PicGo20230214175925.png)

</div>

#### 3.3 光照探针代理体 Light Probe Proxy Volumes

由于对于一个物体，其最后只会使用一个插值后的光照探针，那么对于特别大的物体或者横穿一个四面体的物体而言，仅使用一个插值后的光照探针用于计算间接光照，其结果会不准确，如下图，一个长方体只使用了盒子内的四面体，导致暴露在外的部分也得到比较暗的光照（图中渲染成黄色的原因是当时代码写错了，可以把黄色当成白色，后续也请忽略）。

<div align=center>

![20230210201027](https://raw.githubusercontent.com/recaeee/PicGo/main/recaeee/PicGo20230210201027.png)

</div>

因此，对于这种超出一个四面体的特别大的物体，其解决方案是**光照探针代理体Light Probe Proxy Volumes**，简称LPPV。

参考[《官方文档——Light Probe Proxy Volume component》](https://docs.unity3d.com/cn/2021.3/Manual/class-LightProbeProxyVolume.html)，LPPV会为物体生成插值光照探针的3D网格，将网格中的插值光照探针的球谐函数系数上传到3D纹理中，用于计算该物体的间接光照。

下面为一个物体的Volumes（小球一样的东西），Volumes决定了该物体的间接光照质量。

<div align=center>

![20230210202328](https://raw.githubusercontent.com/recaeee/PicGo/main/recaeee/PicGo20230210202328.png)

</div>

#### 3.4 采样LPPVs Sampling LPPVs

类似于光照探针，我们同样需要将一系列采样LPPVs需要的数据传递给GPU，并且额外多一个**Texture3D**。具体的采样函数已经封装好，在此也不做过多深入了。

采样LPPVs效果图如下，该长方体上拥有了渐变的间接光照。

<div align=center>

![20230214180041](https://raw.githubusercontent.com/recaeee/PicGo/main/recaeee/PicGo20230214180041.png)

</div>

#### 4 元通道 Meta Pass

目前我们烘培得到的间接光照，默认所有静态物体都是纯白色的，意味着静态物体表面完全不吸收任何漫反射能量，将接收到的光能量100%地反射出去。但是物体具有Diffuse属性，意味着物体将会吸收掉一部分光能量，由此反射出的间接光RGB会变化，Unity通过**Meta Pass**来考虑烘培GI时物体的Diffuse属性。

参考[《Unity官方文档——光照贴图和着色器》](https://docs.unity3d.com/cn/2021.3/Manual/MetaPass.html)，**Meta Pass是为全局光照系统提供反射率和自发光的Pass**。它使用的值是与实时渲染中使用的值是分开的，意味着可以使用Meta Pass做一些独立于运行时的光照烘培，比如用于夸装一块区域的间接光照。

#### 4.1 Lit的输入 Unified Input

在编写GI用的Meta Pass之前，先将Lit.Shader的所有Pass统一的Input整合成一个hlsl文件，放入SubShader标签下，意味着这段代码将加入到所有Pass的开头。

#### 4.2 Unlit的统一输入 Unlit

同上，为Unlit也整合一个UnlitInput.hlsl，可以看到两个shader的ShadowCasterPass接受了不同的input，但依然都能工作，可以看出Shader的代码就是拼拼装装。

#### 4.3 元光照模式 Meta Light Mode

这一节在Shader中构建了Meta Pass的雏形，注意点在于需要关闭剔除，即使用**Cull Off**关键字，在其中，我们需要获取物体表面片元的**BRDF属性**。

#### 4.4 光照贴图坐标 Light Map Coordinates

由于我们需要将片元光照信息烘培到光照贴图中，因此我们需要知道物体表面片元在光照贴图中的坐标。因此在顶点着色器中，**需要将物体顶点转换到光照贴图上的对应UV位置**，即实现反向的UV展开。原教程中，这里比较晦涩，它把positionOS和positionCS直接拿来用了，但其值的含义并不是OS和CS下的顶点位置，而是UV位置。

#### 4.5 漫反射反射率 Diffuse Reflectivity

在这一节中，将片元的漫反射率作为片元着色器的输出，这样，就可以**让GI系统获取到烘培时使用的漫反射率**。其中，对间接光照使用的漫反射反射率进行了一定的修饰操作。对于将光能量更多以Specular形式反射但粗糙度较大的表面，也考虑其提供一定的间接光，这是挺有道理的，因为粗糙度大意味着其反射范围大，一定程度上性质接近diffuse。另外，还会对diffuse最终做一次power运算。

在实现该Meta Pass后，我们得到了很不错的GI效果，其考虑了物体表面的Diffuse属性。

<div align=center>

![20230213235251](https://raw.githubusercontent.com/recaeee/PicGo/main/20230213235251.png)

</div>

#### 5 自发光表面 Emissive Surfaces

#### 参考

1. https://zhuanlan.zhihu.com/p/126362480
2. https://docs.unity3d.com/cn/2018.2/Manual/GIIntro.html
3. https://docs.unity3d.com/cn/2021.3/Manual/LightMode-Mixed-BakedIndirect.html
4. https://docs.unity3d.com/cn/2021.3/Manual/LightProbes.html
5. https://gdcvault.com/play/1015312/Light-Probe-Interpolation-Using-Tetrahedral
6. https://zhuanlan.zhihu.com/p/439706412
7. https://docs.unity3d.com/cn/2021.3/Manual/MetaPass.html
8. 所有涩图均来自wlop大大