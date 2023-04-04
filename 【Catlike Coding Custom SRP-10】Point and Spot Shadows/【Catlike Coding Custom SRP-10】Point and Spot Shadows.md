# 【Catlike Coding Custom SRP学习之旅——10】Point and Spot Shadows
#### 写在前面
本篇来到了点光源与聚光灯的实时阴影，相对来说也比较简单吧。对于点光源和聚光灯的实时阴影，我们依然会采用阴影贴图的方式，但相对于方向光源会有一些不同，比如采用透视投影、不同的Normal Bias策略、Cubemap等。本篇实现的主要内容包括：混合点光源与聚光灯的实时阴影和烘培阴影、增加第二张阴影图集、透视投影采样阴影、自定义Cubemaps。

前3章节为长篇文章，考虑到篇幅问题与工作量，从第4章节后半部分开始以及未来章节，考虑以提炼原教程为主，尽量减少篇幅与实际代码，在我的Github工程中包含了对源代码的详细注释，如需深入代码细节可以查看我的Github工程。文章写的不对的地方，欢迎大家批评斧正~

以下是原教程链接与我的Github工程（Github上会实时同步最新进度）：

[CatlikeCoding-SRP-Tutorial](https://catlikecoding.com/unity/tutorials/custom-srp/)

[我的Github工程](https://github.com/recaeee/CatlikeCoding-Custom-RP)

--- 

<div align=center>

![20230404185858](https://raw.githubusercontent.com/recaeee/PicGo/main/20230404185858.png)

</div>

#### 1 聚光灯阴影 Spot Light Shadows

首先是实现聚光灯的实时阴影。对于聚光灯的实时阴影，我们使用和方向光源类似的方法，创建一张阴影图集，然后分块渲染每个光源的阴影贴图Tile。对于聚光灯的阴影贴图，其与方向光源的不同点在于**使用透视投影，而非正交投影**。这一点可以带来一系列好处吧，其满足了近大越小的特点，因此**纹素的尺寸相比正交投影更加合理**（正交投影会使用阴影级联的方式来解决这一点问题）。

#### 1.1 混合阴影 Shadow Mixing

首先实现Spot Shadow的实时阴影（暂时返回1.0）与静态阴影的混合。对于混合的方式，我们同样使用方向光源时的maxDistance和distanceFade来控制。代码很简单，这里不再多提。

#### 1.2 其他实时阴影 Other Realtime Shadows

对于其他光源的实时阴影，我们需要创建一张新的阴影图集，并且最多支持将其分为16块，即最多支持16个带阴影的其他光源。对于不提供阴影的其他光源，如果其属于烘培光源，那么依然支持采样烘培阴影。

#### 1.3 两张图集 Two Atlases

对于其他光源的阴影，类似于方向光源，我们为其增加一个统一的阴影配置属性，控制其阴影图集的尺寸、软阴影模式。开辟阴影贴图的方式不多说了，基本可以拷贝渲染方向光源阴影图集的代码。

#### 1.4 渲染聚光灯阴影 Rendering Spot Shadows

渲染聚光灯阴影的方式和渲染方向光源阴影方式几乎完全一样。具体代码就忽略啦，很简单。这里直接上渲染4个聚光灯阴影贴图的效果图。

<div align=center>

![20230403210243](https://raw.githubusercontent.com/recaeee/PicGo/main/20230403210243.png)

</div>

#### 1.5 无阴影平坠 No Pancaking

在渲染方向光源的阴影时，Unity采用了阴影平坠Shadow Pancaking的技术，尽可能地压缩了光源地阴影裁剪长方体，因此会对部分物体可能Clamp其顶点。而对于聚光灯来说，我们采用了透视投影矩阵来渲染阴影贴图，已经满足了近大远小的需求，因此没有必要进行Pancaking的操作。因此，在渲染聚光灯的阴影贴图时，我们可以关闭Pancaking的操作。

#### 1.6 采样聚光灯阴影 Sampling Spot Shadows

对于聚光灯阴影贴图来说，并不存在级联，一个Tile就对应一个聚光灯，因此，采样阴影贴图相比方向光源更加简单。在采样阴影贴图时，值得注意的是，由于使用了透视投影，因此在变换到聚光灯空间下的坐标后，需要除以w分量，转化成**标准齐次坐标**，再进行阴影贴图的采样。去除环境光后，效果图如下。

<div align=center>

![20230403231112](https://raw.githubusercontent.com/recaeee/PicGo/main/20230403231112.png)

</div>

#### 1.7 法线偏移 Normal Bias

目前，对于聚光灯的实时阴影，我们可以明显地看到阴影痤疮，如下图所示。

<div align=center>

![20230404000535](https://raw.githubusercontent.com/recaeee/PicGo/main/20230404000535.png)

</div>

对于这些痤疮的消除，我们采用Normal Bias的方法，其原理同方向光源的Normal Bias，即**在采样阴影贴图时根据片元法线方向移动一个阴影贴图纹素的距离**。但是不同于方向光源的是，由于聚光灯渲染阴影贴图时使用了透视投影而非正交投影，因此不同深度下对应的纹素大小并不相同。具体表现就是，与聚光灯垂直距离近的阴影痤疮比较密集，而远处比较稀疏。

但是，**其纹素的大小是随着片元到聚光灯距离线性增加的**，因此我们只要知道1m距离下的纹素大小，就可以推出任意距离下的纹素大小了。1m距离下的纹素大小计算方法很简单，高中的三角函数知识即可，如下图所示（图源自原教程），其纹素大小为**2tanθ**。（具体计算使用到了P矩阵的第一个元素，其倒数正好是tanθ*aspect）。

<div align=center>

![20230404000935](https://raw.githubusercontent.com/recaeee/PicGo/main/20230404000935.png)

</div>

最后，放上相同Normal Bias值的对比图，下图为采取固定距离法线偏移的效果。

<div align=center>

![20230404001122](https://raw.githubusercontent.com/recaeee/PicGo/main/20230404001122.png)

</div>

下图为计算不同距离法线偏移的效果图。

<div align=center>

![20230404001202](https://raw.githubusercontent.com/recaeee/PicGo/main/20230404001202.png)

</div>

#### 1.8 钳制采样 Clamped Sampling

对于聚光灯阴影贴图来说，**其渲染的阴影裁剪长方体是紧密贴合其圆锥体的，因此在应用法线偏移后，可能会出现采样越界**（即超出其自身Tile）的问题。因此，最简单的解决方法是将采样坐标永远Clamp到其Tile的坐标内。因此，在CPU端，传递每个Tile的最小纹理坐标与其尺寸，这样就可以得到该Tile的边界，在GPU端直接Clamp就行， 非常简单。

#### 2 点光源阴影 Point Light Shadows

对于点光源阴影而言，其与聚光灯的不同点在于渲染阴影的范围不再局限在一个圆锥体里，而是一个球体，因此我们需要**渲染一张Cubemap作为其阴影贴图**。渲染Cubemap，实际上是渲染正方体6个面上的阴影贴图，因此对于一个产生阴影的点光源，其需要6个Tile，我们可以直接将1个点光源简单视为6个聚光灯，而因为我们的ShadowAtlas最多分成16个Tile，所以我们至多支持2个带阴影的点光源。

#### 2.1 六个Tile Six Tiles for One Light

在CPU端，我们直接将1个点光源视为6个光源去渲染Tile，并且使用一个float来标识每个其他光源是否是点光源。

#### 2.2 渲染点光源阴影贴图 Rendering Point Shadows

第一步做的事情就是渲染点光源的阴影贴图Cubemap了，即以90Fov渲染6次不同方向的阴影贴图。渲染结果图如下所示。

<div align=center>

![20230404125304](https://raw.githubusercontent.com/recaeee/PicGo/main/20230404125304.png)

</div>

#### 2.3 采样点光源阴影 Sampling Point Shadows

接下来实现采样点光源的6个Tile组成的Cubemap，因为我们并不是直接生成Cubemap，因此需要在Shader中根据片元到光源的方向手动求得应该采样哪个Tile。最后效果图如下所示。

<div align=center>

![20230404163628](https://raw.githubusercontent.com/recaeee/PicGo/main/20230404163628.png)

</div>

#### 2.4 绘制正确面 Drawing the Correct Faces

Unity在渲染点光源的阴影贴图时，**会将其以世界空间y轴颠倒来进行绘制**，因此改变了三角形的顶点顺序，其目的在于防止阴影痤疮的生成（具体原理尚不清楚），但是该方法会导致漏光。因此我们直接在渲染阴影贴图之前将V矩阵的第二行取反，让其按正常方式渲染。但这时会产生一定的阴影痤疮，需要手动调整Normal Bias来消除。

另外，对于透明材质和Clip的材质，其Mesh Renderer可以使用Two Sided模式来产生更好的阴影投射结果。

#### 2.5 FOV偏移 Field of View Bias

当采样阴影贴图时跨越Tile，会发生一些不自然的过渡，如下图所示。这是因为**立方体贴图的面之间存在不连续性**，常规的立方体贴图在采样时会通过插值不同面来避免该问题，但是因为我们自己实现的采样Tile会出现该问题。

<div align=center>

![20230404165303](https://raw.githubusercontent.com/recaeee/PicGo/main/20230404165303.png)

</div>

我们通过在渲染阴影时稍微**增加摄像机的FOV**来减轻该问题，当增大摄像机FOV后，我们就不会在Tile的边缘外进行采样，效果图如下。

<div align=center>

![20230404165608](https://raw.githubusercontent.com/recaeee/PicGo/main/20230404165608.png)

</div>

#### 结束语

本篇主要实现了聚光灯和点光源的实时阴影，也算比较简单吧。在其中也有一些关键点吧，这两者的阴影贴图相比于方向光源的一个区别在于，这两者使用透视投影，而方向光源使用正交投影。对于正交投影，我们不能满足近处的TexelSize小，远处的TexelSize大，所以会采用阴影级联的方式，而透视投影则无该问题，但同时会带来TexelSize大小不一致的问题，因此需要对Normal Bias做不同程度的偏移。而点光源的重点在于，我们会直接渲染6个Tile的阴影贴图，而非真正的Cubemap（事实上Cubemap也就是由6个Tile组成罢了），在采样时需要手动找到正确的Tile。

#### 参考

1. https://catlikecoding.com/unity/tutorials/custom-srp/point-and-spot-shadows/
2. 题图来自Wlop大大。