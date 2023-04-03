# 【Catlike Coding Custom SRP学习之旅——9】Point and Spot Lights
#### 写在前面
本篇来到了点光源与聚光灯，在我们实现完方向光之后，其实这两者就非常简单了，无非是光照的规律不太一样导致一些细节上的变化。本篇实现的主要内容包括：实时点光源与聚光灯、对应的烘培光照与烘培阴影、每物体光源。

前3章节为长篇文章，考虑到篇幅问题与工作量，从第4章节后半部分开始以及未来章节，考虑以提炼原教程为主，尽量减少篇幅与实际代码，在我的Github工程中包含了对源代码的详细注释，如需深入代码细节可以查看我的Github工程。文章写的不对的地方，欢迎大家批评斧正~

以下是原教程链接与我的Github工程（Github上会实时同步最新进度）：

[CatlikeCoding-SRP-Tutorial](https://catlikecoding.com/unity/tutorials/custom-srp/)

[我的Github工程](https://github.com/recaeee/CatlikeCoding-Custom-RP)

--- 

<div align=center>

![20230403170150](https://raw.githubusercontent.com/recaeee/PicGo/main/20230403170150.png)

</div>

#### 1 点光源 Point Lights

点光源想必大家都很熟悉了，它也非常简单，其相比方向光源的主要区别包括：**具有一个Position属性、具有一定的可照射范围、对于任意方向光照强度相同**。在本章节，我们首先会实现其实时光照，并不会涉及点光源的实时阴影（由于考虑到光源特性，点光源的阴影需要使用CubeMap，在下一篇会实现）。

#### 1.1 其他光源数据 Other Light Data

类似于方向光源，我们同样在CPU端先定义需要传递给GPU的数组，其包括有效光源数量、光源颜色、光源位置。值得一提的是，**Unity会限制每帧的有效光源数量，而不会限制场景中的有效光源数量**。当一帧内可能有效的光源数量大于上限时，Unity会根据光源的重要程度进行排序，忽略掉重要度低的光源。为了避免Unity忽略光源导致的频闪，将有效光源最大值设置为64，保证支持足够多的光源。

#### 1.2 点光源设置 Point Light Setup

同方向光源，在CPU端首先准备好点光源信息的数组，这里再提醒一遍，VisibleLight结构体占用空间很大，因此为了节约内存，使用ref关键字传递VisibleLight。

#### 1.3 着色 Shading

同理，在GPU端构造属于每个片元的其他光源信息，不同于方向光，**对于每个片元，其他光源照射到片元的方向都不一样**，其方向为片元位置指向光源位置。另外，在写shader函数时，尽量避免同一个迭代变量名出现在一个函数中，防止shader warnings的出现。

到了这一步，我们对于点光源的模拟已经有了初步成效，如下图（也是多亏于光源结构写得好）。

<div align=center>

![20230403142851](https://raw.githubusercontent.com/recaeee/PicGo/main/20230403142851.png)

</div>

#### 1.4 距离衰减 Distance Attenuation

对于点光源，其有一个特性是，**当光源距离照射到的物体表面越远，光能量衰减程度越大**，这也是不同于方向光源的一点。我们需要考虑距离对于光能量的衰减，这点也在GAMES 101里提到，我们**假定点光源在一个球壳表面上的能量分布均匀，且不同半径球壳上的总能量相等，并且认为光源的强度为光源在半径为1m的球壳表面上的总能量**。因此，片元接收到的光源能量与片元到光源的距离的平方成反比。考虑到这点后，效果如图所示。

<div align=center>

![20230403143603](https://raw.githubusercontent.com/recaeee/PicGo/main/20230403143603.png)

</div>

#### 1.5 光源作用范围 Light Range

虽然应用了距离衰减，但是距离平方倒数会永远大于0，这意味着**无论光源与片元距离多远，光源都会对该片元造成影响，即使是个很小很小的值**。因此，我们为每个光源定义一个最大作用范围Range，并且对最大范围处做一个过渡处理。

#### 2 聚光灯 Spot Lights

处理完点光源后，接下来来实现聚光灯Spot Light。聚光灯与点光源的主要区别是，点光源作用范围是球体，而聚光灯作用范围是个圆锥体。其实我们完全可以将聚光灯作为点光源来看待。

#### 2.1 方向 Direction

对于聚光灯而言，我们需要传递其方向信息，即**其圆锥体的中轴方向**。我们将聚光灯的方向性考虑成光源衰减，通过将光源到片元的方向与聚光灯方向做点积来判断片元是否处于聚光灯圆锥体方向内，若不是，则光能量完全衰减。简单示意图如下。

<div align=center>

![20230403145804](https://raw.githubusercontent.com/recaeee/PicGo/main/20230403145804.png)

</div>

#### 2.2 聚光灯角度 Spot Angle

对于聚光灯作用的圆锥体而言，我们还需要一个**Outer Angle**角度来定义其几何形状，该角度为圆锥体中轴与其表面的夹角。并且，对于聚光灯的光源特性而言，**当物体表面与聚光灯方向夹角角度不同时，距离造成光能量衰减不同**，这个夹角阈值定义为**Inner Angle**。因此，我们需要定义这两个值，并将其传递给GPU。其衰竭函数如下所示（图取自原教程）。

<div align=center>

![20230403150720](https://raw.githubusercontent.com/recaeee/PicGo/main/20230403150720.png)

</div>

最后效果图如下。

<div align=center>

![20230403151200](https://raw.githubusercontent.com/recaeee/PicGo/main/20230403151200.png)

</div>

#### 2.3 配置内角 Configuring Inner Angles

由于Spot Light的内角配置是自URP以来新增的可配置属性，因此在默认的Light Inspector上不会提供其编辑功能，因此我们需要自己写一个Editor脚本，来扩充其配置（Unity自己写好了大部分配置的函数）。效果图如下。

<div align=center>

![20230403152013](https://raw.githubusercontent.com/recaeee/PicGo/main/20230403152013.png)

</div>

不同内外角的聚光灯效果图如下。

<div align=center>

![20230403152043](https://raw.githubusercontent.com/recaeee/PicGo/main/20230403152043.png)

</div>

#### 3 烘培光照与阴影 Baked Light and Shadows

在本篇，不会实现点光源和聚光灯的实时阴影，但接下来会先实现其烘培光照与阴影。

#### 3.1 完全烘培 Fully Baked

对于点光源和聚光灯的烘培，其实只需要将其Mode设置为Baked就行，但是默认的效果亮度非常大，因为其对光源衰减计算的过程是错误的（使用了LegacyRP的计算方式）。其效果图如下。

<div align=center>

![20230403153240](https://raw.githubusercontent.com/recaeee/PicGo/main/20230403153240.png)

</div>

#### 3.2 光源委托 Lights Delegate

为了让Unity的GI正确烘培点光源和聚光灯，我们需要通过自定义一个委托，在Unity执行GI计算前执行该委托的函数，来构造正确的光源信息LightDataGI。具体的实现就跳过啦~效果图如下。

<div align=center>

![20230403155309](https://raw.githubusercontent.com/recaeee/PicGo/main/20230403155309.png)

</div>

#### 3.3 阴影遮罩 Shadow Mask

对于点光源和聚光灯的阴影遮罩计算，和方向光源差不多。唯一的区别在于，因为点光源和聚光灯往往都只有小区域的作用范围，因此**ShadowMask上的一个通道可以存多个光源的阴影遮罩信息**，只需要这几个光源没有重叠的作用区域。但是，对于一块物体表面（阴影遮罩上的一个片元），最多只能存储4个光源的阴影信息。

在点光源和聚光灯的阴影遮罩烘培上，我们需要另外编写代码来在GPU端实现，其原理和方向光源的阴影遮罩相同。其烘培处的阴影遮罩图如下。

<div align=center>

![20230403161537](https://raw.githubusercontent.com/recaeee/PicGo/main/20230403161537.png)

</div>

#### 4 每物体光源 Lights Per Object

目前，我们对于一个片元，依然会遍历所有的光源来计算其光照计算结果，但是对于点光源和聚光灯，因为其作用范围往往很小，这些光源并不会对所有片元都产生作用。因此，我们可以通过**Unity的PerObject的光源索引来获取作用于一个物体的所有光源的索引**。但它其实也不完美，并且可能有一些Bug，因此将其作为管线的可选配置项。

#### 4.1 每物体光源数据 Per-Object Light Data

首先，我们通过激活**PerObjectData.LightData和LightIndices**来让Unity完成CPU端的工作。

#### 4.2 过滤光源索引 Sanitizing Light Indices

Unity会对每个物体构建一个有效光源的列表，其包括了所有光源（无论是否可见，以及包括了方向光源），我们需要过滤掉不可见光源，并且忽略掉所有方向光源。我们通过构造**IndexMap**来实现它。

IndexMap数据属于CullingResults，**其映射了VisibleLight索引到每个物体的内部光源列表的索引**，因此为了实现PerObjectLights，我们需要自己构建这个IndexMap。

另外，我们会创建新的Shader变体来使用PerObjectLights的这套逻辑。

#### 4.3 使用索引 Using the Indices

最后在GPU端使用新的索引来累积光照结果。我们通过UnityPerDraw Buffer段下的unity_LightData和unity_LightIndices来获取每个物体的有效光源数和它们的索引。注意，**每个物体至多被8个光源所影响**。

最后，**LightsPerObject会对GPU Instancing造成负优化**，因为只有有效光源数和光源索引列表相同的物体才能被合批，但是对SRP Batcher没什么影响。

#### 结束语

本篇也算是比较简单吧，主要实现了点光源和聚光灯的实时光照、烘培光照和阴影。在实现的过程中，不会改变很大的代码结构，这也主要得益于Shader部分代码写的很好吧，也了解到了一些延迟渲染的思路。

#### 参考

1. https://catlikecoding.com/unity/tutorials/custom-srp/point-and-spot-lights/
2. 题图来自Wlop大大。