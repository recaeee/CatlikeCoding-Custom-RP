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

#### 1.2 探测阴影遮罩 Detecting a Shadow Mask





#### 参考

