# 【Catlike Coding Custom SRP学习之旅——4】Directional Shadows
#### 写在前面
接下来到方向光的阴影实现了，阴影实现本身不难，难点在于其锯齿的消除以及阴影级联技术的实现，在很多实际项目中，会针对阴影贴图Shadow Map做性能优化，例如分离动静态物体渲染多张阴影图、旋转阴影图方向等等。另外，阴影也是提升游戏质感的一项重要技术，在完成这一章后，我们就能获取一个比较好的渲染效果了。另外，这一章我会尽力压缩篇幅，只提关键知识点。

以下是原教程链接与我的Github工程（Github上会实时同步最新进度）：

[CatlikeCoding-SRP-Tutorial](https://catlikecoding.com/unity/tutorials/custom-srp/)

[我的Github工程](https://github.com/recaeee/CatlikeCoding-Custom-RP)

--- 

#### 方向光阴影 Directional Shadows

在这一章，我们将实现以下多个效果：渲染和采样Shadow Maps、支持多个方向光阴影、阴影级联、混合渐变过滤阴影。

#### 1 渲染阴影 Rendering Shadows

实现阴影有很多方法，最常见的**实时阴影**技术就是**Shadow Map**（阴影贴图）了，其原理非常简单（推荐观看[《GAMES 101课程相关章节》](https://www.bilibili.com/video/BV1X7411F744/?spm_id_from=333.999.0.0)）。简单来说，就是从光源方向渲染一张深度图，然后根据这张深度图，我们就知道渲染画面用的摄像机中每一个片元处是否被光照射到了，如果没照射到，光照计算结果就是0。

[《Unity官方文档：阴影贴图》](https://docs.unity3d.com/cn/2021.3/Manual/shadow-mapping.html)中对其描述为：**阴影贴图类似于深度纹理，光源生成阴影贴图的方式与摄像机生成深度纹理的方式类似。Unity会在阴影贴图中填充与光线在射到表面之前传播的距离有关的信息（就是光线从光源出发打到物体的距离，类似于摄像机深度），然后对阴影贴图进行采样，以便计算光线射中的游戏对象的实时阴影**。

#### 1.1 阴影设置 Shadow Settings

首先创建一个序列化的ShadowSettings类来提供对阴影贴图的配置属性，主要包括两个属性，一个是**maxDistance**（阴影距离），一个是**TextureSize**（Shadow Map尺寸）。

参考[《Unity官方文档：阴影距离》](https://docs.unity3d.com/cn/2021.3/Manual/shadow-distance.html)，maxDistance决定**Unity渲染实时阴影的最大距离**（与摄像机之间的距离）。另外，**如果当前摄像机远平面小于阴影距离，Unity将使用摄像机远平面而不是maxDistance**。这也是非常合理的，毕竟超出摄像机远平面的物体本身就不会被渲染的。

ShadowSettings.cs代码如下。

```c#
using UnityEngine;

//单纯用来存放阴影配置选项的容器
[System.Serializable]
public class ShadowSettings
{
    //maxDistance决定视野内多大范围会被渲染到阴影贴图上，距离主摄像机超过maxDistance的物体不会被渲染在阴影贴图上
    //其具体逻辑猜测如下：
    //1.根据maxDistance（或者摄像机远平面）得到一个BoundingBox，这个BoundingBox容纳了所有要渲染阴影的物体
    //2.根据这个BoundingBox和方向光源的方向，确定渲染阴影贴图用的正交摄像机的视锥体，渲染阴影贴图
    [Min(0f)] public float maxDistance = 100f;

    //阴影贴图的所有尺寸，使用枚举防止出现其他数值，范围为256-8192。
    public enum TextureSize
    {
        _256 = 256,
        _512 = 512,
        _1024 = 1024,
        _2048 = 2048,
        _4096 = 4096,
        _8192 = 8192
    }

    //定义方向光源的阴影贴图配置
    [System.Serializable]
    public struct Directional
    {
        public TextureSize atlasSize;
    }

    //创建一个1024大小的Directional Shadow Map
    public Directional directional = new Directional()
    {
        atlasSize = TextureSize._1024
    };
}
```

#### 1.2 传递配置 Passing Along Settings

我们将会每帧向摄像机传递阴影相关的配置，这样我们可以在运行时实时对其进行修改（虽然教程中不会这么做）。

我们首先需要**将shadowSettings.maxDistance传递给camera的cullingParameters.shadowDistance**，同时为了实现“如果当前摄像机远平面小于阴影距离，Unity将使用摄像机远平面而不是maxDistance”，我们将取shadowSetting.maxDistance和camera.farClipPlane的较小值。

```c#
    bool Cull(float maxShadowDistance)
    {
        //获取摄像机用于剔除的参数
        if (camera.TryGetCullingParameters(out ScriptableCullingParameters p))
        {
            //实际shadowDistance取maxShadowDistance和camera.farClipPlane中较小值
            p.shadowDistance = Mathf.Min(maxShadowDistance, camera.farClipPlane);
            cullingResults = context.Cull(ref p);
            return true;
        }

        return false;
    }
```

ScriptableCullingParameters.shadowDistance即**用于剔除的阴影距离**。我们上一节说过，我们需要**根据主摄像机去生成一个用于渲染阴影贴图的Bounding Box**（要进行剔除，和常规渲染剔除不一样，远平面是shadowDistance）。

#### 1.3 阴影类 Shadows Class

我们将处理方向光阴影的逻辑都放在一个新的Shadows.cs中，然后在Lighting中创建一个Shadows的实例，在Lighting的Setup中执行shadows.Setup。

因此目前逻辑上的包含关系为**CameraRenderer->Lighting->Shadows**。

目前，我们在Shadows中什么都没干，只是获取到需要的context、cullingResult和shadowSettings。

```c#
using UnityEngine;
using UnityEngine.Rendering;

//所有Shadow Map相关逻辑，其上级为Lighting类
public class Shadows
{
    private const string bufferName = "Shadows";

    private CommandBuffer buffer = new CommandBuffer()
    {
        name = bufferName
    };

    private ScriptableRenderContext context;

    private CullingResults cullingResults;

    private ShadowSettings settings;

    public void Setup(ScriptableRenderContext context, CullingResults cullingResults,
        ShadowSettings settings)
    {
        this.context = context;
        this.cullingResults = cullingResults;
        this.settings = settings;
    }

    void ExcecuteBuffer()
    {
        context.ExecuteCommandBuffer(buffer);
        buffer.Clear();
    }
}
```

#### 1.4 支持阴影的光源 Lights with Shadows

接下来，我们需要在Shadows类中配置所有支持阴影的光源，并设置一个最大光源数，我们将其设置为1，意味着我们**最多只有一个支持阴影的方向光源**（这通常来说足够了，但注意我们依然可以有多个方向光源，只是只有一个支持阴影）。

在配置过程中，我们始终通过索引号（一个int）来标识每个光源（光源的索引号和cullingResult中光源索引号相同，非常不错~），因此我们也始终通过索引号来表示每个要配置的光源的阴影信息。

在代码中，我们主要通过**ShadowedDirectionalLight**结构体来存储**支持阴影的光源相关信息**。通过ReserveDirectionalShadows方法来配置每个支持阴影的光源，在该方法中，我们会限制光源最大数量、忽略不开启阴影或者阴影强度等于0的光源、忽略不需要渲染阴影的光源。

```c#
    //用于获取当前支持阴影的方向光源的一些信息
    struct ShadowedDirectionalLight
    {
        //当前光源的索引，猜测该索引为CullingResults中光源的索引(也是Lighting类下的光源索引，它们都是统一的，非常不错~）
        public int visibleLightIndex;
    }

    //虽然我们目前最大光源数为1，但依然用数组存储，因为最大数量可配置嘛~
    private ShadowedDirectionalLight[] ShadowedDirectionalLights =
        new ShadowedDirectionalLight[maxShadowedDirectionalLightCount];

    //当前已配置完毕的方向光源数
    private int ShadowedDirectionalLightCount;

    ...

        //每帧执行，用于为light配置shadow altas（shadowMap）上预留一片空间来渲染阴影贴图，同时存储一些其他必要信息
    public void ReserveDirectionalShadows(Light light, int visibleLightIndex)
    {
        //配置光源数不超过最大值
        //只配置开启阴影且阴影强度大于0的光源
        //忽略不需要渲染任何阴影的光源（通过cullingResults.GetShadowCasterBounds方法）
        if (ShadowedDirectionalLightCount < maxShadowedDirectionalLightCount && light.shadows != LightShadows.None && light.shadowStrength > 0f
            && cullingResults.GetShadowCasterBounds(visibleLightIndex, out Bounds b))
        {
            ShadowedDirectionalLights[ShadowedDirectionalLightCount++] = new ShadowedDirectionalLight()
            {
                visibleLightIndex = visibleLightIndex
            };
        }
    }
```

#### 1.5 创建阴影图集 Creating the Shadow Atlas

#### 参考

1. https://www.bilibili.com/video/BV1X7411F744/?spm_id_from=333.999.0.0
2. https://docs.unity3d.com/cn/2021.3/Manual/shadow-mapping.html
3. https://docs.unity3d.com/cn/2021.3/Manual/shadow-distance.html
