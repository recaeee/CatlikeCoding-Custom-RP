# 【Catlike Coding Custom SRP学习之旅——8】Complex Maps
#### 写在前面
本篇来到了贴图篇，主要涉及到了PBR材质下的各个贴图的使用及其实现，包括MODS贴图、细节贴图、法线贴图等。纵观这一章， 其实涵盖的知识点很少，很多也很简单，可能也只有切线空间这一比较重要的知识点了，但是通过本章节（原教程）的学习，我们可以了解到编写Shader代码的一种策略吧（感觉是比较偏技术美术向），因此对于本章节，实践的意义大于理论。

前3章节为长篇文章，考虑到篇幅问题与工作量，从第4章节后半部分开始以及未来章节，考虑以提炼原教程为主，尽量减少篇幅与实际代码，在我的Github工程中包含了对源代码的详细注释，如需深入代码细节可以查看我的Github工程。文章写的不对的地方，欢迎大家批评斧正~

以下是原教程链接与我的Github工程（Github上会实时同步最新进度）：

[CatlikeCoding-SRP-Tutorial](https://catlikecoding.com/unity/tutorials/custom-srp/)

[我的Github工程](https://github.com/recaeee/CatlikeCoding-Custom-RP)

--- 

<div align=center>

![20230324185946](https://raw.githubusercontent.com/recaeee/PicGo/main/20230324185946.png)

</div>

#### 1 电路材质 Circuitry Material

到目前为止，我们实现了PBR材质，但目前该材质非常简单，只采样了一张baseMap用于AlphaTest以及赋予片元基础Color，对于GI还使用了一张Emission贴图作为自发光贴图。在本章节，会实现一个电路材质，通过实现该材质来了解到各类贴图的使用。

#### 1.1 反射率贴图 Albedo

首先是Albedo贴图（贴图均源自[原教程](https://catlikecoding.com/unity/tutorials/custom-srp/complex-maps/)）。

<div align=center>

![20230323152103](https://raw.githubusercontent.com/recaeee/PicGo/main/20230323152103.png)

</div>

Albedo贴图可以理解为传统的baseMap，提供了物体表面的漫反射颜色信息。效果图如下。

<div align=center>

![20230323152500](https://raw.githubusercontent.com/recaeee/PicGo/main/20230323152500.png)

</div>

#### 1.2 自发光贴图 Emission

接下来，增加我们已实现的Emission贴图。

<div align=center>

![20230323152653](https://raw.githubusercontent.com/recaeee/PicGo/main/20230323152653.png)

</div>

效果图如下。

<div align=center>

![20230323152757](https://raw.githubusercontent.com/recaeee/PicGo/main/20230323152757.png)

</div>

#### 2 遮罩贴图 Mask Map

对于PBR材质，我们还需要控制物体表面的金属度Metallic以及光滑度Smoothness。

#### 2.1 MODS贴图 MODS

**MODS**贴图，MODS全称为**Metallic、Occlusion、Detail、Smoothness**。该贴图格式和HDRP使用的格式相同，显然，MODS贴图为RGBA格式，每个通道存储一个Property，并且需要**关闭贴图的sRGB选项**（该选项会让GPU对该贴图执行Gamma到Linear的转换，会得到错误的采样结果）。MODS贴图如下。

<div align=center>

![20230323153654](https://raw.githubusercontent.com/recaeee/PicGo/main/20230323153654.png)

</div>

#### 2.2 遮罩输入 Mask Input

在Shader中创建MaskMap的Property，这里比较简单了。

#### 2.3 金属度 Metallic

我们在之前通过LitInput.hlsl来定义一系列Get Properties的函数，我们只需要在这里去采样MODS贴图，并且将结果附加到Metallic上返回，这样，我们在Shader实际计算PBR的地方就会对MODS贴图无感了。将MODS贴图的R通道乘到GetMetallic上，其效果图如下（将Metallic和Smoothness属性都设置为了1）。图中，黄褐色的部分金属度为1，而绿色的部分金属度接近0。

<div align=center>

![20230323154652](https://raw.githubusercontent.com/recaeee/PicGo/main/20230323154652.png)

</div>

#### 2.4 光滑度 Smoothness

同样的方法处理A通道的Smoothness。效果图如下，其中黄色部分Smoothness为1，绿色部分接近0。

<div align=center>

![20230323155207](https://raw.githubusercontent.com/recaeee/PicGo/main/20230323155207.png)

</div>

#### 2.5 遮蔽 Occlusion

接下来到了MODS贴图的G通道，即遮蔽Occlusion，更多被称为**环境光遮蔽**。根据我个人的理解，对于**一些狭长并且凹进去的区域**，因为结构的原因，**射进这些地方的间接光线（非直射光）很难在多次反弹过后再射出**，因此这些区域经常会显得比较暗。当然，光直射进去，我们依然看得见这些区域很亮。因此，遮蔽通常指环境光遮蔽，即在这些区域，环境光很难被反射出来。

由此可见，Occlusion值当然也只针对于间接光照（环境光），同时我们可以用一个系数来控制环境光遮蔽的强度。效果图如下（绿色的区域变暗，可以将这些地方理解为凹下去的区域）。

<div align=center>

![20230323160951](https://raw.githubusercontent.com/recaeee/PicGo/main/20230323160951.png)

</div>

#### 3 细节贴图 Detail Map

下一步，使用Detail Map为材质增加一些细节，**Detail Map**为一张RG通道有效的RGB贴图，其中R通道存储了Albedo的修改，B通道存储了Smoothness的修改（在HDRP中，会额外使用BA两个通道存储法线的修改）。Detail Map如下图所示。

<div align=center>

![20230323202227](https://raw.githubusercontent.com/recaeee/PicGo/main/20230323202227.png)

</div>

#### 3.1 细节UV坐标 Detail UV coordinates

在这里，我们为Detail Map使用单独的一套UV坐标，这样给予了其最大程度的灵活性，并且不依赖于BaseMap。

#### 3.2 细节处理后的反射率 Detailed Albedo

通过Detail Map的R通道值，我们可以根据其调节BaseMap得到的Albedo值，并且通过MODS Map的G通道（Detail Mask）值作为遮罩，控制哪些区域会应用Detail Map的Albedo调整。最后，同样也增加一个系数来控制Detail Map对Albedo调整的强度。效果图如下。

<div align=center>

![20230323212933](https://raw.githubusercontent.com/recaeee/PicGo/main/20230323212933.png)

</div>

#### 3.3 细节处理后的光滑度 Detailed Smoothness

同样对Smoothness做类似的实现。当Smoothness Detail作用强度为1，效果图如下。

<div align=center>

![20230323213839](https://raw.githubusercontent.com/recaeee/PicGo/main/20230323213839.png)

</div>

#### 3.4 渐变细节 Fading Details

Detail Map用作补充材质细节，因此其主要使用场景在摄像机离物体特别近时，当摄像机离物体远时，这些补充的细节不会增加画面质量，反而会导致像素无法承载过多的信息而变成噪点。Unity默认会对远处的片元采用较高等级的Mip(等级越高，Mip尺寸越小)，但我们还可以使用Unity自带的**Fadeout Mip Map**功能。其会在一定Mip等级区间内，让Mip与纯灰（0.5）进行插值，来让远处的采样结果接近0.5来屏蔽细节。注意，Fadeout Mip Map需要贴图开启Trilinear过滤模式。效果图如下。

<div align=center>

![20230323214851](https://raw.githubusercontent.com/recaeee/PicGo/main/20230323214851.png)

</div>

#### 4 法线贴图 Normal Maps

接下来到了法线贴图Normal Maps，通常当把高模烘培成低模时，会将高模的法线存储到低模的法线贴图里，来保持高模的几何细节。法线贴图应用切线空间，表示法线在切线空间上的偏移，切线空间的Z分量存储在B通道中，右侧和前向XY轴存储在RG通道中，同样，0.5作为其值的中点。使用切线空间的另一好处是，法线贴图不会受顶点动画影响，总是会保持正确。对于法线不产生偏移的地方，RG值为0，因此法线贴图上会展现大量的蓝色。

#### 4.1 采样法线贴图 Sampling Normals

对于法线贴图，由于其采用了特殊的存储方式（使用切线空间），并且由于平台的不同，法线贴图会使用不同的bits数存储各通道信息，因此我们使用Core RP库自带的函数来解码采样法线贴图得到的结果。

#### 4.2 切线空间 Tangent Space

关于切线空间，可以参考[《为什么要有切线空间（Tangent Space），它的作用是什么？》](https://www.zhihu.com/question/23706933/answer/958094336)

在切线空间中，坐标原点是顶点，其中Z轴（Normal轴）指向**顶点法线**，XY轴是该顶点切平面上任意两条互相垂直的轴，但是通常来说，我们会规定使用**模型在该顶点上的纹理坐标方向作为X轴**（Tangent轴），该信息会存储在顶点信息中，而最后一个Y轴（Bitangent）就可以通过XZ轴叉乘得到，也就不需要存储。因此，**构建出一个顶点的切线空间，只需要存储一个Vector3用来表示顶点的切线方向即可**。

将Normal Map构建在切线空间中的好处是，其记录的是法线相对偏移，并且只和纹理相关（Tangent轴），**和模型无关**，因此可以将一张纹理和Normal Map放在任何模型身上。同理，根据该特性，也可以知道，该方法也方便我们进行UV动画，并且可以进行模型顶点动画。

应用法线贴图后，效果图如下。

<div align=center>

![20230324175228](https://raw.githubusercontent.com/recaeee/PicGo/main/20230324175228.png)

</div>

#### 4.3 阴影贴图插值法线 Interpolated Normal for Shadow Bias

对于阴影贴图使用的Normal Bias，我们仍然使用顶点原始法线插值后的结果，并且可以省去对其的向量标准化，其造成的影响不会很大。

#### 4.4 法线细节 Detailed Normals

同Albedo、Smoothness一样，我们也可以为Normal增加补充细节的贴图。

<div align=center>

![20230324180319](https://raw.githubusercontent.com/recaeee/PicGo/main/20230324180319.png)

</div>

使用Detail Normal Map后的效果图如下。

<div align=center>

![20230324181431](https://raw.githubusercontent.com/recaeee/PicGo/main/20230324181431.png)

</div>

#### 5 可选贴图 Optional Maps

不是所有材质都需要这么多贴图，因此，我们通过关键字去生成不同的变体，避免不必要的Shader运算。

#### 5.1 法线贴图 Normal Maps

首先对法线贴图通过关键字控制，很简单，值得一提的是，如果我们在Shader中没有任何地方使用到一个顶点属性(Attribute)，我们的Shader在编译后会自动消去它，并且不会让其传递到片元着色器。

#### 5.2 可选配置 Input Config

为了更统一地控制每个可选项，我们定义一个结构体来存储当前材质的配置。后续其实都比较简单，看一下原教程的代码，实现起来很方便。主要还是思路上的学习吧，对于一个Shader的所有输入，归类到一个Input.hlsl文件，并通过配置一个结构体来控制可选项，而在Shader计算中对这些可选操作无感。后续几个小节为几个配置的具体实现，为了保持和原教程一样的目录，因此简单写了几句，可以忽略。

#### 5.3 可选遮罩贴图 Optional Mask Map

很简单，定义一个_MASK_MAP关键字来控制是否使用MODS贴图。

#### 5.4 可选细节贴图 Optional Detail

同上。

最后附上材质的最后效果图吧，还是非常强大的，同样PBR材质的通用性和扩展性也非常大。

<div align=center>

![20230324190235](https://raw.githubusercontent.com/recaeee/PicGo/main/20230324190235.png)

</div>

#### 结束语

本篇主要涉及到了MODS贴图、细节贴图、法线贴图等，其实这章节内容非常简单，但是通过实现其代码，我们可以了解到一种关于Shader代码编写的思路，亲身体会其代码的实现会对Shader代码实现思路有非常大的帮助，因此建议自己跟着原教程去实现一遍。

#### 参考

1. https://catlikecoding.com/unity/tutorials/custom-srp/complex-maps/
2. https://www.zhihu.com/question/23706933/answer/958094336
3. 题图来自Wlop大大。