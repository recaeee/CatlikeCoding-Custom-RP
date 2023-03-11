# 【Catlike Coding Custom SRP学习之旅——6】Shadow Masks
#### 写在前面
本篇到了阴影遮罩了，阴影遮罩这一章相对来说知识点比较少，主要涉及到了ShadowMask存储了什么信息，以及两个ShadowMask模式的特点等。另外主要还提到了一种比较好的阴影渲染方案，即近处使用实时阴影，远处使用烘培阴影，在教程中也实现了这一点。

前3章节为长篇文章，考虑到篇幅问题与工作量，从第4章节后半部分开始以及未来章节，考虑以提炼原教程为主，尽量减少篇幅与实际代码，在我的Github工程中包含了对源代码的详细注释，如需深入代码细节可以查看我的Github工程。文章写的不对的地方，欢迎大家批评斧正~

以下是原教程链接与我的Github工程（Github上会实时同步最新进度）：

[CatlikeCoding-SRP-Tutorial](https://catlikecoding.com/unity/tutorials/custom-srp/)

[我的Github工程](https://github.com/recaeee/CatlikeCoding-Custom-RP)

--- 

<div align=center>

![20230215211956](https://raw.githubusercontent.com/recaeee/PicGo/main/20230215211956.png)

</div>

#### 1 烘培阴影 Baking Shadows

GI在Baked Indirect模式下，只会烘培出一张光照贴图存储间接光照，所有静态物体的阴影不会被烘培。但是，我们当然可以让光源造成的阴影也在GI中烘培出来，这样做的好处是无论物体离得多远，都可以低成本地为其渲染阴影，但坏处是阴影是**完全静态**的，不能实时变化。一种比较好的阴影方案是**对于摄像机maxShadowDistance内的物体使用实时光照造成的阴影，对于该距离以外的物体使用光照贴图中的阴影**。**阴影遮罩Shadow Mask**用于实现该方案。

首先来谈谈我在本节学习ShadowMask的一些疑惑点和我对其的解答吧。

1. **ShadowMask是什么？**
   
   ShadowMask是一张**RGBA格式的纹理**（类似于Lightmap，并且**与Lightmap共用一套UV**），**其存储了场景中每个区域是否处于阴影中的信息**。具体来说，对于一个光源，如果场景中的一块区域被该光源照射到了，ShadowMask纹理上该位置的值就是1，反之就是0，中间值会形成软阴影。

   在运行时，我们无需计算一块区域是否处于阴影中（即进行一系列变换，采样阴影贴图等），直接通过采样ShadowMask就能知道这一块区域是否在阴影中，当然这只考虑了静态情况。

2. **ShadowMask每个通道（一共RGBA4个通道）都会分别存一个光源的阴影信息嘛？**
   
   如果简单来说，是的。但是如果两个光源造成的阴影在ShadowMask纹理上完全不重合，那么这两个光源造成的阴影就可以合并到一个通道里。因此理论上，一个通道可以存无数个光源的阴影信息，只要它们造成的光源完全不重合，但是实际这点很难做到。因此，简单可以理解成1个通道存1个光源。

#### 1.1 距离阴影遮罩 Distance Shadow Mask

首先将GI中的Lighting Mode设置为Shadowmask，ShadowMask模式与Baked Indirect模式非常类似，它们都会为场景中参与GI的静态物体烘培一张光照贴图来存储间接光照信息。不同点在于,Shadowmask模式会额外为场景中参与GI的静态物体烘培一张**阴影遮罩纹理**，在其中存储烘培光源的遮挡信息。

<div align=center>

![20230216201422](https://raw.githubusercontent.com/recaeee/PicGo/main/recaeee/PicGo20230216201422.png)

</div>

阴影遮罩纹理如下图所示。

<div align=center>

![20230216201545](https://raw.githubusercontent.com/recaeee/PicGo/main/recaeee/PicGo20230216201545.png)

</div>

#### 1.2 启用阴影遮罩 Detecting a Shadow Mask

首先处理CPU端，我们需要在光源启用阴影遮罩时，启用一个_SHADOW_MASK_DISTANCE关键字，告诉GPU目前使用到了阴影遮罩。

对于每个光源，其拥有一个**LightBakingOutput**结构体成员，该结构体包含了当前光源的全局光照烘培效果，其中包含一个**LightmapBakeType**枚举值，LightmapBakeType包括3种可能值：
1. Realtime：该光源只贡献实时光照和阴影
2. Baked：该光源只会贡献到光照贴图和光照探针中，不提供实时光照
3. Mixed：根据LightBakingOutput的**MixedLightMode**，允许光源同时贡献实时光照和烘培光照，这类光源**无法移动**，但可以**实时改变颜色和强度**，但这些改变只会影响到实时光照部分，**不会影响烘培光照部分**。

当光源的LightBakingOutput.LightmapBakeType为Mixed并且MixedLightMode为Shadowmask时，启用Shader关键字_SHADOW_MASK_DISTANCE。

#### 1.3 阴影遮罩数据 Shadow Mask Data

在CPU端，我们需要给perObjectData添加**PerObjectData.ShadowMask**来告诉Unity把阴影遮罩数据传递给GPU，这一点和光照贴图、光照探针类似。

在GPU端，我们需要接收一个名为**unity_ShadowMask**的贴图，同样也接收其采样器samplerunity_ShadowMask。值得注意的一点是，阴影遮罩贴图的UV坐标和光照贴图使用的是同一样，即我们在采样shadowMask时，直接使用ligntMapUV就行了。

将ShadowMask采样结果直接输出效果图如下（有点P5的感觉，很酷哈哈哈）。

<div align=center>

![20230309205557](https://raw.githubusercontent.com/recaeee/PicGo/main/recaeee/PicGo20230309205557.png)

</div>

在图中可以看到，动态物体的返回值为白色，这是因为**在绘制每个动态物体时，LIGHTMAP_ON关键字被关闭**，我们在shader代码中将关闭LIGHTMAP_ON关键字时采样阴影遮罩的结果返回为全1（即白色）。

绘制动态物体时关键字状态如下所示，可以看到没有LIGHTMAP_ON。

<div align=center>

![20230309210630](https://raw.githubusercontent.com/recaeee/PicGo/main/recaeee/PicGo20230309210630.png)

</div>

而绘制参与全局光照的物体时，关键字状态如下所示，包含了LIGHTMAP_ON。

<div align=center>

![20230309210724](https://raw.githubusercontent.com/recaeee/PicGo/main/recaeee/PicGo20230309210724.png)

</div>

从这一点，我们可以获得很关键的一个信息，**在一帧内，关键字LIGHTMAP_ON在绘制每个物体时都可能发生变化**，其取决于要绘制的物体是否参与全局光照计算。这也联系上了一点，我们是通过PerObjectData.Lightmaps来让CPU端传递光照贴图信息。


另外，官方教程中提到，只要当我们对涉及metaPass的hlsl文件代码进行了改动，那么就会导致Unity重新烘培光照，这一点可以通过关闭Auto Generate来避免（懒如我就不用了）。

#### 1.4 遮挡探针 Occlusion Probes

对于**动态物体**，其不会从ShadowMask上获取烘培好的阴影，但是可以通过遮挡探针Occlusion Probes来接收烘培阴影，同ShadowMask，其也属于PerObjectData。并且在GPU端，需要在UnityPerDraw中接收一个名为unity_ProbesOcclusion的Vector4数据。

对于动态物体，如果其完全不处于阴影中，unity_ProbeOcclusion则返回纯白色；如果其完全处于阴影中，则返回天青色。如下图所示。

<div align=center>

![20230311173328](https://raw.githubusercontent.com/recaeee/PicGo/main/20230311173328.png)

</div>

#### 1.5 遮挡探针代理体 LPPVs

和光照探针类似，对于遮挡探针，也可以使用**LPPVs**来处理那些特别大的物体接收到的烘培阴影，其**实现和光照探针代理体类似**，在采样过程中，其信息被存储在光照探针代理体的同一张贴图上，并且需要相同的参数，不过不需要法线信息。

采样LPPVs之后效果如下。

<div align=center>

![20230311174434](https://raw.githubusercontent.com/recaeee/PicGo/main/20230311174434.png)

</div>

#### 1.6 程序化生成 Mesh Ball

对于DrawMeshInstanced生成的小球，和LPPV一样，我们也可以传递所有遮挡探针给GPU，用于其计算整个MeshBall范围内的遮挡探针代理体。

#### 2 混合阴影 Mixing Shadows

目前，我们已经可以获取到ShadowMask的静态阴影了，接下来就是实现其与实时阴影的结合使用，也就是**超出maxShadowDistance的地方使用ShadowMask**。

#### 2.1 使用烘培阴影 Use Baked when Available

这个结合方案的思路很简单，实现当然也很简单，没什么特别好说的。首先做的第一步是将实时阴影的计算和烘培阴影的计算分离开来。

#### 2.2 切换到烘培阴影 Transitioning to Baked

切换烘培阴影的时机是根据使用的级联强度决定的，因为级联强度取决于片元与maxShadowDistance的距离，因此可以直接拿来用。在级联强度为0的时候，表示完全不使用级联阴影（实时阴影），则此时使用烘培阴影，具体会使用lerp来做插值过渡。

效果图如下，其中，实时阴影考虑到了AlphaTest的物体，而烘培阴影未考虑到AlphaTest物体，可以作为判别依据。

<div align=center>

![20230311211207](https://raw.githubusercontent.com/recaeee/PicGo/main/20230311211207.png)

</div>

#### 2.3 完全烘培阴影 Only Baked Shadows

在原教程的阴影系统中，如果所有物体都超出了maxShadowDistance，则会直接跳过实时阴影的渲染，而烘培阴影只有在实时阴影存在时才生效，因此对烘培阴影做特殊处理，即在不渲染任何实时阴影时，也要获取到烘培阴影并使用。

此时，当不渲染任何实时阴影时，会完全采用烘培阴影，效果如下图所示。

<div align=center>

![20230311212807](https://raw.githubusercontent.com/recaeee/PicGo/main/20230311212807.png)

</div>

#### 2.4 完全使用阴影遮罩 Always use the Shadow Mask

在Project Settings中，还有一种Shadow Mask Mode为**Shadowmask**（前面用的都是Distance Shadowmask），该模式下，静态物体只会投射烘培阴影，而不投射实时阴影。该模式存在的思想在于，能用烘培阴影的地方，就用烘培阴影，不要去算实时阴影了，这样渲染压力就小了，但是其代价就是**摄像机近处的烘培阴影质量会比较低**。同样，我们需要在管线中支持该模式。

具体实现不展开了，最后其效果如下图所示。

<div align=center>

![20230311222033](https://raw.githubusercontent.com/recaeee/PicGo/main/20230311222033.png)

</div>

#### 3 多光源 Multiple Lights

Shadowmap具有4个通道，参考[《官方文档》](https://docs.unity3d.com/cn/2021.3/Manual/LightMode-Mixed-Shadowmask.html)，**每个通道可以记录任意个阴影完全不重合的混合光源的阴影信息**，因此**理论上**一个通道可以记录无数个混合（实时+烘培）光源的阴影信息，只要它们造成的阴影没有一点重叠，但这个几乎很难做到，因此，很多时候最多支持4个光源。其中，最重要的光源会被记录在R通道中，以此类推。当**重叠混合光源**超过4个时，多余的光源会回退至Baked Lighting，也就是光源只参与Lightmap的计算。

#### 3.1 阴影遮罩通道 Shadow Mask Channels

以开启2个Mix方向光源为例，ShadowMask会在RG两个通道中分别记录两个光源的阴影信息，如下图所示。

<div align=center>

![20230311231120](https://raw.githubusercontent.com/recaeee/PicGo/main/20230311231120.png)

</div>

其中，只被第一个光源照射到的部分为红色，只被第二个光源照射到的地方为绿色，被两者都照射到的地方为黄色。

我们需要告诉GPU当前光源使用了哪个Shadowmask通道，该信息可以从lightBakingOutput.occlusionMaskChannel中获取。

#### 3.2 选择通道 Selecting the Appropriate Channel

因为采样得到的ShadowMask结果为RGBA数据，因此在计算烘培阴影时，只需要用正确的索引去获取RGBA下对应值就行了。

原教程中还提到了我们是否应该使用点积操作来获取RGBA对应索引下的值，而不是直接用[index]索引来获取。其中说到了，如果我们通过下标索引来获取一个Vector中对应位置的值，编译器会自动使用一个遮罩向量来与该Vector向量进行点积操作，以此来更高效地获取到对应值。

文末还提到了Subtractive的光照模式，该光照模式可以参考[《写给美术看的Unity全局光照技术(理论篇)》](https://zhuanlan.zhihu.com/p/126362480)。该模式是一种仅使用单个光照贴图来组合烘培光照和阴影的模式，并且是**唯一会将主光源对动态物体的实时阴影投射到静态物体上**的模式，它会对。但其具有非常大的局限性，包括仅适用于无法改变的单一方向光，渐渐光照可能产生不正确的结果等，因此原教程也不建议使用这个模式。

#### 结束语

害~本文拖了很久，主要是因为最近在工作中尝试一些抗锯齿方案，包括TAA、FXAA、SMAA等（也算深入学习了很多抗锯齿算法），但每个方案都有一定瑕疵，很难有一个特别理想的方案，也是搞得比较emo，所以这段时间都在通过打游戏排解压力哈哈哈哈。并且，这篇文章跨度比较久，可能写的也不是很理想吧，后面希望能找回状态！

#### 参考

1. https://catlikecoding.com/unity/tutorials/custom-srp/shadow-masks/
2. https://zhuanlan.zhihu.com/p/126362480
3. https://docs.unity3d.com/cn/2021.3/Manual/LightMode-Mixed-Subtractive.html
4. https://docs.unity3d.com/cn/2021.3/Manual/LightMode-Mixed-Shadowmask.html
5. 题图来自Wlop大大。