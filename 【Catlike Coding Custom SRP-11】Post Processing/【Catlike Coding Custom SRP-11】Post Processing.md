# 【Catlike Coding Custom SRP学习之旅——10】Point and Spot Shadows
#### 写在前面
本篇来到了后处理，后处理算是渲染管线比较重要的一个部分吧，通过后处理的方式，可以极大程度地提升画面效果，常见的后处理包括色调映射、Bloom、抗锯齿等等。除了一些整体的画面效果，后处理还可以用来实现描边等各类美术效果。本篇主要涉及到的内容有：后处理堆栈、Bloom效果等。

前3章节为长篇文章，考虑到篇幅问题与工作量，从第4章节后半部分开始以及未来章节，考虑以提炼原教程为主，尽量减少篇幅与实际代码，在我的Github工程中包含了对源代码的详细注释，如需深入代码细节可以查看我的Github工程。文章写的不对的地方，欢迎大家批评斧正~

以下是原教程链接与我的Github工程（Github上会实时同步最新进度）：

[CatlikeCoding-SRP-Tutorial](https://catlikecoding.com/unity/tutorials/custom-srp/)

[我的Github工程](https://github.com/recaeee/CatlikeCoding-Custom-RP)

--- 

<div align=center>

![20230404185858](https://raw.githubusercontent.com/recaeee/PicGo/main/20230404185858.png)

</div>

#### 1 后处理堆栈 Post-FX Stack

**FX**，其全称为**Special Effects**，即**特殊效果**，通常也称为VFX(Visual Special Effects)，即**视觉特效**。

参考[维基百科](https://zh.wikipedia.org/wiki/%E8%A7%86%E8%A7%89%E6%95%88%E6%9E%9C)，视觉效果（Visual effects，简称VFX），是在电影制作中，在真人动作镜头之外创造或操纵图像的过程。利用影片和电脑生成的图像或影像合成，来创造一个看起来真实的效果或场景，可取代较为危险、昂贵、或者根本不可能实现的状况，例如使用视觉效果取代危险的爆破效果或高空场景，避免演员搏命演出。

仔细想来，游戏很多技术都会沿用影视技术上的一些技术，比如在色调映射时，可以采用ACES（电影色调映射）等。另外，我也一直好奇**为啥Special Effects叫FX**，而不是叫SE，查了下网上，似乎只是因为**FX谐音Effects**，真是不知道从哪吐槽比较好。

通常来说，因为后处理会包含很多不同的效果，如色调映射、Bloom、抗锯齿等等，因此**后处理在渲染管线中的结构往往是一个堆栈式的结构**（URP中也是如此，使用了Post Process Volume），即一步一步按顺序执行每一个后处理效果。因此在本篇中，会搭建这样一个堆栈结构，并且实现Bloom效果。

#### 1.1 配置资源 Settings Asset

首先，我们定义**PostFXSettings资源**，即Scriptable Object，将其作为**渲染管线的一项可配置属性**，这样就方便我们去配置不同的后处理堆栈，并可以方便地切换。在URP中也是使用类似的结构（Volume Profile）来实现的。

#### 1.2 栈对象 Stack Object

类似于Light和Shadows，我们同样使用一个类来存储包括Camera、ScriptableRenderContext、PostFXSettings，并在其中执行后处理堆栈。

在进行后处理前，我们首先需要获取当前摄像机画面的标识**RenderTargetIdentifier**，RenderTargetIdentifier用于**标识CommandBuffer的RenderTexture**，Identifier有很多种形式，例如RenderTexture对象、内置渲染纹理BulitinRenderTextureType、TemporaryRT等等，其结构用于一种纹理标识方式，使用隐式转换运算符，其主要的用途就是可以隐式转换**不同RT标识符**吧，避免了我们代码显式去做各种变换。在这里我们使用一个简单的int来标识sourceRT。

对于一个后处理效果而言，其实现过程说来很简单，传入一个矩形Mesh（其纹理即当前画面），使用一个Shader渲染该矩形Mesh，将其覆盖回Camera的RT上，我们通过**Blit函数**来实现该功能。Blit函数很重要，其定义为**从一个纹理经过自定义着色器处理后复制到其他纹理**。对于后处理，我们需要知道，其无非就是在**绘制一个矩形Mesh**。

#### 1.3 使用堆栈 Using the Stack

在之前，我们的摄像机RenderTarget都是FrameBuffer，而**FrameBuffer只可写，不可读**。为了在后处理前读取到摄像机的RenderTarget，我们需要创建一个**中间RT**（_CameraFrameBuffer），来存储摄像机的渲染结果，再对其进行后处理。在每一帧开始，我们会创建该临时RT，在每一帧结束，会释放该临时RT。

在实现该框架后，我们可以在截帧中看到后处理Step，如下图所示（目前只是将_CameraFrameBuffer直接复制到Frame Buffer中。

<div align=center>

![20230404200643](https://raw.githubusercontent.com/recaeee/PicGo/main/20230404200643.png)

</div>

#### 1.4 强制清除 Forced Clearing

因为我们将摄像机渲染到了中间RT上，我们虽然会在每帧结束时释放该RT空间，但是基于Unity自身对RT的管理策略，其并不会真正地清除该RT，因此我们在下一帧时，该RT中会留存上一帧的渲染结果，导致了**每一帧画面都是在前一帧的结果之上绘制的**。如果我们每一帧渲染前清理该RT，那显然没问题。但是要是设置了不正确的ClearFlag，可能会导致渲染画面异常，如下图所示，我将ClearFlag设置成了Depth Only,上一帧的Color会和当前帧重叠，产生鬼影。

<div align=center>

![20230404201715](https://raw.githubusercontent.com/recaeee/PicGo/main/20230404201715.png)

</div>

因此，我们需要手动强制设置ClearFlags。

#### 1.5 Gizmos

我们还需要在后处理前后绘制不同的Gizmos部分，这部分略~

#### 1.6 自定义绘制 Custom Drawing

使用Blit方法绘制后处理，实际上会绘制一个矩形，也就是2个三角面，即6个顶点。但我们完全可以只用一个三角面来绘制整个画面，因此我们**使用自定义的绘制函数代替Blit**。

对于这个三角面，其形状如下图所示（图源自原教程），顶点坐标如图，应该很容易明白，当然这个三角面会有一部分空间被浪费，但是其效果也比Blit好。

<div align=center>

![20230404204930](https://raw.githubusercontent.com/recaeee/PicGo/main/20230404204930.png)

</div>

在使用Blit时，在两个三角面片的接缝处，GPU会**绘制两遍这些像素**，如下图所示（图源自原教程），这也是使用一个三角面的好处之一。

<div align=center>

![20230404205047](https://raw.githubusercontent.com/recaeee/PicGo/main/20230404205047.png)

</div>

剩下便是构造该三角面的Shader，我们直接在顶点着色器中设置三角面每个顶点的CS坐标和UV坐标，并不需要在CPU端做这些操作。在实现后，我们先直接输出uv颜色，如下图所示。

<div align=center>

![20230404205228](https://raw.githubusercontent.com/recaeee/PicGo/main/20230404205228.png)

</div>

#### 1.7 屏蔽部分FX Don't Always Apply FX

目前，我们对于所有摄像机都执行了后处理。但是，我们希望只对Game视图和Scene视图摄像机进行后处理，并对不同Scene视图提供单独的开关控制。很简单，通过判断摄像机类型来屏蔽。

#### 1.8 复制 Copying

接下来，完善下Copy Pass。我们在片元着色器中，对原画面进行采样，并且由于其不存在Mip，我们可以指定mip等级0进行采样，避免一部分性能消耗。另外，Unity会存在一些情况，无法自动修正uv坐标的v轴翻转，因此我们需要手动判断下，解决v轴翻转。

#### 2 辉光 Bloom

目前，我们已经实现了后处理堆栈的框架，接下来实现一个Bloom效果。Bloom效果应该非常常见，也是经常被用于美化画面，其主要作用就是**让画面亮的区域更亮**。以前也跟着《Shader入门精要》做过一次，其实际并不复杂。

#### 2.1 Bloom金字塔 Bloom Pyramid

为了实现Bloom效果，我们需要提取画面中亮的像素，并让这些亮的像素影响周围暗的像素。因此，需要首先实现RT的**降采样**。通过降采样，我们可以很轻易地实现模糊功能。对于SourceRT，每次降低其1/2的尺寸，再使用Bilinear采样器进行采样，每次可以得到4个像素的模糊结果，由此构建出**Bloom Pyramid**。简单来说，Bloom Pyramid即将SourceRT每次降低1/2尺寸后得到的RT数组。

在实现的过程中有一点值得注意，我们在申请PropertyToID时，**Unity会将一批连续申请的标识符以顺序形式标识**，因此，我们只需知道第0层Pyramid即可索引到所有Pyramid，只要我们连续申请了这批标识符。

Bloom Pyramid效果图如下，即每次降采样一半。

<div align=center>

![20230404225650](https://raw.githubusercontent.com/recaeee/PicGo/main/20230404225650.png)

![20230404225707](https://raw.githubusercontent.com/recaeee/PicGo/main/20230404225707.png)

</div>

#### 2.2 配置辉光 Configurable Bloom

通常来说，我们并不需要降采样到很小的尺寸，因此我们将**最大降采样迭代次数**和**最小尺寸**作为可配置选项。下图为最大迭代次数为5的效果图。

<div align=center>

![20230404230409](https://raw.githubusercontent.com/recaeee/PicGo/main/20230404230409.png)

</div>

#### 2.3 高斯滤波 Gaussian Filtering

目前，我们使用双线性滤波来实现降采样，这样的结果会有很多颗粒感，因此我们可以使用**高斯滤波**，并且使用更大的高斯核函数，通过9x9的高斯滤波加上双线性采样，实现18x18的模糊效果。

理论上，**9x9的高斯滤波，对于每一个片元，需要采样81次**，但其实，相邻像素之间的采样结果是可以**复用**的，因此我们可以先横向滤波，再纵向滤波，花费18次采样达到81次的效果。但其代价是，需要使用中间RT来保存临时结果，也就是典型的空间换时间了。

最后高斯滤波的降采样效果如下（5次迭代），效果比2x2滤波强很多，虽然一次降采样会花费更多采样操作，但是我们可以降低采样迭代次数。

<div align=center>

![20230404233724](https://raw.githubusercontent.com/recaeee/PicGo/main/20230404233724.png)

</div>

#### 2.4 叠加模糊 Additive Blurring

对于Bloom的增亮，我们直接将每次降采样后的Pyramid一步步叠加到原RT上，即直接让两张不同尺寸的图片以相同尺寸采样，叠加颜色，这一步也叫**上采样**，其意为**将一个较小尺寸的RT看作较大尺寸来进行采样**。在叠加的过程中，重复利用了生成Horizontal高斯滤波的中间临时RT。这一步也很简单，具体不展开~最后效果图如下，看起来像过曝了一样，之后会处理。

<div align=cener>

![20230405111445](https://raw.githubusercontent.com/recaeee/PicGo/main/20230405111445.png)

</div>

#### 2.5 双三次上采样 Bicubic Upsampling

在上采样过程中，我们使用了双线性采样，这样可能依然会导致块状的模糊效果，因此我们可以增加**双三次采样Bicubic Sampling**的可选项，以此提供更高质量的上采样。

#### 2.6 半分辨率 Half Resolution

由于Bloom会渲染多张Pyramid，因此其消耗是比较大的，其实我们完全没必要从初始分辨率开始降采样，从**一半的分辨率开始采样**的效果也很好。

#### 2.7 阈值 Threshold

目前，我们对整个RT的每个像素都进行了增亮，这让这个画面看起来过曝了一般，但其实Bloom只需要对亮的区域增亮，本身暗的地方就不需要增亮了。因此，我们在生成半分辨率的时候，**直接将暗的像素颜色值设置为0**，这样在之后降采样过程中这些像素也就依然维持在一个较小值。并且，我们通过一个亮度阈值来筛选亮的像素，并通过**膝盖函数**来平滑过渡。膝盖函数如下图所示（图片源自原教程），增加阈值后，效果正常了很多。

<div align=center>

![20230405111747](https://raw.githubusercontent.com/recaeee/PicGo/main/20230405111747.png)

![20230405111613](https://raw.githubusercontent.com/recaeee/PicGo/main/20230405111613.png)

</div>

#### 2.8 强度 Intensity

最后，提供一个Intensity选项，控制Bloom的整体强度。在我们完成所有的上采样后，会将其结果叠加到原RT上，此时将Intensity作为权重作用到上采样结果上，以此来达到控制强度的效果，非常简单。最后给出Intensity很大的效果图。

<div align=center>

![20230405112608](https://raw.githubusercontent.com/recaeee/PicGo/main/20230405112608.png)

</div>

#### 结束语

大功告成，我们在渲染管线中增加了后处理堆栈，以及实现了一个Bloom效果，其实在做完这篇之后，我觉得这个渲染管线才算基本上达成了大部分需要的功能，也算是一个里程碑吧。虽然在后处理堆栈的编辑形式上，可能远不如URP的Volume组件来的方便。在其中，我们也实现了通过一个三角面来实现后处理，相比Blit会更高效。

#### 参考

1. https://catlikecoding.com/unity/tutorials/custom-srp/point-and-spot-shadows/
2. https://zh.wikipedia.org/wiki/%E8%A7%86%E8%A7%89%E6%95%88%E6%9E%9C
3. https://docs.unity3d.com/cn/2021.3/ScriptReference/Rendering.RenderTargetIdentifier.html
4. 题图来自Wlop大大。