# 【Catlike Coding Custom SRP学习之旅——7】LOD and Reflections
#### 写在前面
本篇来到了LOD和环境光反射，这两项技术在实际项目中，往往都起到了非常重要的作用，LOD减轻了渲染上的压力，并且可以避免一个像素需要呈现过多的信息。而反射探针带来的环境光反射，使我们的光照模型更加完善，并且得到画质上的很大提升，因为通常来说，环境光是画面效果提升的很大一个关键点。本章主要涉及内容：LOD、不同LOD过渡、反射探针实现环境光、菲涅尔反射。

前3章节为长篇文章，考虑到篇幅问题与工作量，从第4章节后半部分开始以及未来章节，考虑以提炼原教程为主，尽量减少篇幅与实际代码，在我的Github工程中包含了对源代码的详细注释，如需深入代码细节可以查看我的Github工程。文章写的不对的地方，欢迎大家批评斧正~

以下是原教程链接与我的Github工程（Github上会实时同步最新进度）：

[CatlikeCoding-SRP-Tutorial](https://catlikecoding.com/unity/tutorials/custom-srp/)

[我的Github工程](https://github.com/recaeee/CatlikeCoding-Custom-RP)

--- 

<div align=center>

![20230321211249](https://raw.githubusercontent.com/recaeee/PicGo/main/20230321211249.png)

</div>

#### 1 LOD组 LOD Groups

**1. 什么是LOD？**

参考[《百度百科：LOD》](https://baike.baidu.com/item/LOD/7671950)LOD，其全称为**Levels of Details**，意为**多细节层次**。LOD技术指根据物体模型在摄像机视锥体中的位置以及画面上的占比，决定物体渲染的资源分配，降低非重要物体的三角面数和细节度，从而获得高效率的渲染运算。

简单来说，LOD技术就是让画面上占据像素越少的物体使用更粗糙的模型。

**2. 为什么要用LOD？**

就如定义所说，LOD最主要的功能就是，**通过减少不必要的三角面数，从而获取高效率的渲染运算**。三角面数通常会被用来衡量一帧画面的渲染压力，在商业项目中，往往会对一个模型去构建不同数量级面数的Mesh，作为不同的LOD等级，如下图所示（图源自[《Unity官方文档——LOD》](https://docs.unity3d.com/cn/2021.3/Manual/LevelOfDetail.html)）。

<div align=center>

![20230321193203](https://raw.githubusercontent.com/recaeee/PicGo/main/20230321193203.png)

</div>

另外，LOD还有一个作用，就是可以**防止一个像素需要呈现过多的信息**，这一点当然也很重要。这一点其实和摩尔纹（像素和纹素的不匹配）的产生原因很类似，**一个像素能呈现出的视觉信息是有限的**，当一个像素需要呈现出过多的信息，这个像素往往会变成**噪点**，其承载的信息变得无效，并且会污染画面。举个例子来说，比如一个像素只覆盖了一个简单的三角面，那很好，它只需要呈现这个三角面上对应位置的颜色就行；但如果一个像素覆盖了100个三角面（有特别多的顶点在这个像素的范围内），那这个像素必然就无法呈现出100个三角面的信息，从而这个像素携带的信息就失效，变为噪点了。

**3 如何使用LOD？**

怎么使用LOD，那就是接下来的几小节的内容啦~

#### 1.1 LOD组组件 LOD Group Component

Unity以组件形式提供了对LOD的支持，该组件名为**LOD Group**，参考[《Unity官方文档——LOD》](https://docs.unity3d.com/cn/2021.3/Manual/LevelOfDetail.html)，**LOD Group组件提供了相应控件来定义LOD在此游戏对象上的行为方式，并会引用Unity为每个LOD级别显示或隐藏的游戏对象**。简单来说，LOD Group会帮我们判断当前应该用哪一级LOD，并且会帮我们自动显示对应的LOD，并且隐藏其他的LOD，而每一级的LOD具体的模型是我们自己设定的。

在这里需要提醒官方文档中容易**误导人**的一点，官方文档中说：当游戏对象使用LOD时，Unity将根据**游戏对象与摄像机的距离**来显示该游戏对象的相应LOD级别。这里所说的“游戏对象与摄像机的距离”**并不是**指GameObject的Position与摄像机的距离，而更偏向于模型Mesh在世界空间下的各个顶点坐标与摄像机的距离（这么说可能也不准确，因为顶点也只是我的猜想）。理论上来说，**决定最终使用哪个LOD，取决于该物体占据画面的比例**。而这个比例怎么衡量，我目前尚不清楚，反正不是物体的position，因为使用position显然也不合理，即使物体position离摄像机很远，但如果这个物体的模型非常巨大，实际占据画面很大一部分，显然这是有可能的，比如远处的山之类的。当然这点也很容易验证，自己尝试缩放物体的Scale，而保持其位置不变，来查看其使用的LOD就行了，这里就不贴效果图了。

接下来到解释LOD Group组件的一些主要参数了，其实非常简单，官方文档写的也很明确。

通常来说，LOD Group会包含**4个LOD级别**，LOD0、1、2以及Culled（完全被剔除），并且每个级别对应一个**比例值**，**该比例值决定了当物体占画面多少比例时使用该LOD级别**，如下图所示。

<div align=center>

![20230321202857](https://raw.githubusercontent.com/recaeee/PicGo/main/20230321202857.png)

</div>

而在原教程中，说明了通常**根据物体在画面中垂直方向上的占比**来估算物体占据画面的比例。

另外，还有一个**LOD Bias**的参数，其相当于**LOD比例值的系数的倒数**。打个比方，如果LOD bias为2，LOD 0对应的比例值（即画面占比）为60%，那么实际上，在物体占据画面30%（60% * 0.5）以上时，才会使用LOD 0。

最后，还有一个**Maximum LOD**，其用于**从构建中排除高于指定LOD级别的网格**。简单来说，其决定了**能显示的最精细的LOD等级**。同样，官方文档在这里也很容易**误导人**，其说到排除高级别LOD，**高级别指的是模型细节程度**，也就是LOD X的**X越小**。例如，设置Maximum为1，意味着LOD 0永远不会参与LOD的计算，也不会显示。

最后就是每个LOD对应的**Renderers列表**了，其意味着为此LOD级别保存网格的游戏对象，注意其是一个List，意味着，一个LOD下可以显示多个MeshRenderer。

如下图所示展现了LOD Group的效果，其中黄色代表LOD 0，青色代表LOD 1，红色代表LOD 2。

<div align=center>

![20230321203745](https://raw.githubusercontent.com/recaeee/PicGo/main/20230321203745.png)

</div>

而当我将Maximum LOD调整为2，意味着LOD 0和LOD 1不参与LOD计算，物体就只能显示剩下LOD 2的红色了，如下图所示。

<div align=center>

![20230321203919](https://raw.githubusercontent.com/recaeee/PicGo/main/20230321203919.png)

</div>

#### 1.2 额外LOD Groups Additive LOD Groups

另外，上一节中提到了，每一个LOD对应维护了一个Renderers List，意味着每个LOD级别可以显示不同数量的Mesh。在这里，我在LOD0中放置了3个不同大小的Cube，而在LOD1中放置2个，在LOD2中只放置一个，其配置如下图所示。

<div align=center>

![20230321210306](https://raw.githubusercontent.com/recaeee/PicGo/main/20230321210306.png)

</div>

其在3个LOD级别下的效果图分别如下。

<div align=center>

![20230321210431](https://raw.githubusercontent.com/recaeee/PicGo/main/20230321210431.png)

</div>

这点也可以用于配置不同LOD下的模型细节。

另外，原教程中提到了我们可以为LOD Group参与GI的计算，其中会默认使用LOD 0的Renderers来参与Lightmap的计算，其他LOD级别也可以从Lightmap上采样得到间接光照，但是其他LOD级别无法提供间接光照给场景中的其他物体。我们也可以让LOD0使用Lightmap，而其他LOD使用光照探针。

#### 1.3 LOD过渡 LOD Transitions

突然的LOD切换往往会显得不自然，因此，我们会使用到**Cross Fade**模式的LOD过渡，来让不同LOD淡入淡出（意味着过渡时，会同时渲染两个LOD下的Renderers）。

当开启Cross Fade模式后，每个LOD会维护一个**Fade Transition Width**，其值范围为[0,1]，其决定了**从多少比例开始当前LOD开始过渡到下一级LOD**（更粗糙的LOD），0表示完全不过渡，1表示立刻开始过渡。打个比方，当LOD0对应比例值为60%（100%~60%使用LOD0），而其Fade Transition Width为0.25，意味着从70%（60%+40%*0.25）开始进行LOD的淡入淡出的过渡。Fade Transition Width如下图所示。

<div align=center>

![20230321213909](https://raw.githubusercontent.com/recaeee/PicGo/main/20230321213909.png)

</div>

另外，虽然说我们开启了Cross Fade，但目前我们仍然看不到淡入淡出的效果，这是因为Unity只为我们实现了CPU端的工作（将unity_LODFade值传入UnityPerDraw Buffer段），我们需要自己在GPU端去实现淡入淡出，具体代码如何实现就不展开了，主要就是去围绕unity_LODFade这个值去做淡入淡出。

#### 1.4 抖动过渡 Dithering

抖动过渡的具体代码不展开了，其主要是根据unity_LODFade.x的值确定当前物体的fade值，再根据抖动算法施加一个dither，最后根据抖动值Clip像素。其效果如下所示（从黄色过渡到青色）。

<div align=center>

![20230321215835](https://raw.githubusercontent.com/recaeee/PicGo/main/20230321215835.png)

</div>

#### 1.5 基于时间的动画过渡 Animated Cross-Fading

另外，LOD切换过渡显然是具有短时性的，如果我们正好处于物体LOD过渡的摄像机距离，我们肯定不希望物体永远处于过渡状态，即如上图中维持一半黄、一半青，即使摄像机不动了，我们也希望在短时间后完全切换到下一LOD去显示。

因此，我们需要开启**Animate Crss-fading**，其意味着Unity执行**基于时间的过渡**，我猜测其主要帮助我们完成了CPU段unity_LODFade的时间过渡，即假如CPU端已知开始执行过渡了，就将unity_LODFade值在一定时间内完成0~1的传递，随后完全转入下一LOD。

#### 2 反射 Refections

环境光照是组成画面细节很重要的一个部分，需要注意的是，**物体表面反射的环境光照属于Specular高光部分**，而目前由于我们并未实现环境光照，因此Metallic高的物体往往会呈现大范围的黑色。

#### 2.1 间接BRDF Indirect BRDF

目前我们的GI只考虑了Diffuse部分，因此首先第一步是将Specular部分也考虑进GI。在实现中，注意一点，Specular部分会受Roughness影响，当Roughness较大时，会使反射出的Specular能量整体减少。

#### 2.2 采样环境光 Sampling the Environment

首先要做的就是采样Skybox造成的环境高光，Skybox是一张Cubemap，因此我们需要一个float3的方向来采样它，而由于其为高光，那很容易知道，我们的采样方向与摄像机的朝向有关，即**以摄像机朝向为入射光方向、物体表面法线为法线的出射光方向为采样Skybox的方向**。

另外，为了使GPU端接收到Skybox Cubemap，我们需要激活**PerObjectData.ReflectionProbes**（目前只用到Skybox，但反射探针不止Skybox）。

当我们成功采样Skybox Cubemap，Metallic高的物体呈现效果如下。

<div align=center>

![20230322112840](https://raw.githubusercontent.com/recaeee/PicGo/main/20230322112840.png)

</div>

当然，环境高光肯定不仅仅要考虑skybox，还需要考虑物体周围的物体，之后会实现这些。

#### 2.3 粗糙反射 Rough Reflections

此外，我们还需要考虑Roughness对高光的影响，因为Roughness高时，会使高光变得模糊，我们通过**采样Cubemap的高Mip等级**（高Mip意味着尺寸越小的mip）来实现这点。

不同Roughness对环境高光的效果如下图所示。

<div align=center>

![20230322121856](https://raw.githubusercontent.com/recaeee/PicGo/main/20230322121856.png)

</div>

#### 2.4 菲涅尔反射 Fresnel Reflection

推荐观看Games 101课程相关章节，里面详细解释了**菲涅尔反射**，在这里就不指路了。简单来说，**当观察角度与物体表面夹角越小（掠射角），物体表面会更多呈现环境光的反射**。在本节中，使用了菲涅尔项的近似估计，将菲涅尔强度可视化如下图所示（越白表示菲涅尔强度越高）。

<div align=center>

![20230322124017](https://raw.githubusercontent.com/recaeee/PicGo/main/20230322124017.png)

</div>

#### 2.5 菲涅尔系数 Fresnel Slider

由于我们使用的使菲涅尔的近似估计，因此当其值估计正确且环境光贴图正确时，效果很好，但是在一些情况下（如水下），菲涅尔项会变得奇怪，因此我们添加一个菲涅尔项的系数来整体去控制菲涅尔项。

#### 2.6 反射探针 Reflection Probes

前面提到，我们目前的环境光贴图只包括了Skybox，因此我们需要通过**反射探针**来实现将场景里的其他物体加入环境光贴图。

参考[《官方文档——反射探针》](https://docs.unity3d.com/cn/2021.3/Manual/ReflectionProbes.html)，**反射探针类似一个捕捉周围各个方向的球形视图的摄像机，其将捕捉的图像存储为Cubemap，供具有反射材质的对象使用**。我们可以在给定场景中放置多个反射探针。

其原理很简单，我们在空间中一个位置放置了一个反射探针，那么我们就可以知道这个位置接收到各个方向的光照计算结果（类似于在这个位置放置一个摄像机渲染，只不过大多时候只渲染一次，也可以预烘培），那么其附近的物体就可以用这个Cubemap近似其接收到的环境光照。

反射探针烘培的Cubemap如下图所示。

<div align=center>

![20230322131943](https://raw.githubusercontent.com/recaeee/PicGo/main/20230322131943.png)

</div>

通常来说，我们只会预烘培或者在游戏运行初期执行一次反射探针Cubemap的计算，因为其相当于摄像机渲染，所以其消耗很昂贵，很少会选择每帧渲染它。

另外要注意，每个对象只能使用一个反射探针，并且使用不同反射探针会打断GPU Batching，如下图所示。

<div align=center>

![20230322132150](https://raw.githubusercontent.com/recaeee/PicGo/main/20230322132150.png)

</div>

并且，当反射探针的模式为**Baked**时，需要在GO上勾选Reflection Probe Static来让物体被渲染到反射探针上，而**Realtime**模式不用考虑这个问题。

#### 2.7 Decoding Probes

最后，在GPU端需要解码PerObject的反射探针信息，包括反射探针使用HDR还是LDR，反射探针的强度。

最后效果图如下。

<div align=center>

![20230322132538](https://raw.githubusercontent.com/recaeee/PicGo/main/20230322132538.png)

</div>

#### 结束语

LOD和反射探针算是两个比较使用的技术，关于反射探针，更详细的信息可以去参考官方文档，内容也比较多，很多信息属于用到的时候再查就行的类型，因此本文没有涉及更多知识。害，后续我会加快进度了！

#### 参考

1. https://catlikecoding.com/unity/tutorials/custom-srp/lod-and-reflections/
2. https://baike.baidu.com/item/LOD/7671950
3. https://docs.unity3d.com/cn/2021.3/Manual/LevelOfDetail.html
4. https://docs.unity3d.com/cn/2021.3/Manual/ReflectionProbes.html
5. 题图来自Wlop大大。