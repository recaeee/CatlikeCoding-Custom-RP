# 【Catlike Coding Custom SRP-6】Shadow Masks
#### 写在前面
在

前3章节为长篇文章，考虑到篇幅问题与工作量，从第4章节后半部分开始以及未来章节，考虑以提炼原教程为主，尽量减少篇幅与实际代码，在我的Github工程中包含了对源代码的详细注释，如需深入代码细节可以查看我的Github工程。

以下是原教程链接与我的Github工程（Github上会实时同步最新进度）：

[CatlikeCoding-SRP-Tutorial](https://catlikecoding.com/unity/tutorials/custom-srp/)

[我的Github工程](https://github.com/recaeee/CatlikeCoding-Custom-RP)

--- 

<div align=center>

![20230215211956](https://raw.githubusercontent.com/recaeee/PicGo/main/20230215211956.png)

</div>

#### 1 烘培阴影 Baking Shadows

GI在Baked Indirect模式下，只会烘培出一张光照贴图存储间接光照，所有静态物体的阴影不会被烘培。但是，我们当然可以让光源造成的阴影也在GI中烘培出来，这样做的好处是无论物体离得多远，都可以低成本地为其渲染阴影，但坏处是阴影是**完全静态**的，不能实时变化。一种比较好的阴影方案是**对于摄像机maxShadowDistance内的物体使用实时光照造成的阴影，对于该距离以外的物体使用光照贴图中的阴影**。**阴影遮罩Shadow Mask**用于实现该方案。

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

#### 1.4 遮蔽探针 Occlusion Probes



#### 参考

1. https://catlikecoding.com/unity/tutorials/custom-srp/shadow-masks/