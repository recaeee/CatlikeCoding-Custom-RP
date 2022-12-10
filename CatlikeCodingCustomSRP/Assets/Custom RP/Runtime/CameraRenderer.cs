using UnityEngine;
using UnityEngine.Rendering;

public partial class CameraRenderer
{
    //定义Command Buffer的名字，FrameDebugger会捕捉到它，由此可见FrameDebugger会以Command Buffer为单位去抓取一帧内的渲染过程
    private const string bufferName = "Render Camera";
    //获取ShaderId，用于告诉渲染器我们支持渲染哪些ShaderPasses
    private static ShaderTagId unlitShaderTagId = new ShaderTagId("SRPDefaultUnlit");
    
    
    

    private CommandBuffer buffer = new CommandBuffer()
    {
        name = bufferName
    };
    //存放当前渲染上下文
    private ScriptableRenderContext context;

    //存放摄像机渲染器当前应该渲染的摄像机
    private Camera camera;

    //存放摄像机剔除结果
    private CullingResults cullingResults;

    //摄像机渲染器的渲染函数，在当前渲染上下文的基础上渲染当前摄像机
    public void Render(ScriptableRenderContext context, Camera camera)
    {
        //设定当前上下文和摄像机
        this.context = context;
        this.camera = camera;
        
        PrepareBuffer();
        PrepareForSceneWindow();
        
        if (!Cull())
        {
            return;
        }
        
        Setup();
        DrawVisibleGeometry();
        DrawUnsupportedShaders();
        DrawGizmos();
        Submit();
    }

    void Setup()
    {
        //把当前摄像机的信息告诉上下文，这样shader中就可以获取到当前帧下摄像机的信息，比如VP矩阵等
        //同时也会设置当前的Render Target，这样ClearRenderTarget可以直接清除Render Target中的数据，而不是通过绘制一个全屏的quad来达到同样效果（比较费）
        context.SetupCameraProperties(camera);
        CameraClearFlags flags = camera.clearFlags;
        //清除当前摄像机Render Target中的内容,包括深度和颜色，ClearRenderTarget内部会Begin/EndSample(buffer.name)
        buffer.ClearRenderTarget(flags <= CameraClearFlags.Depth, flags == CameraClearFlags.Color,
            flags == CameraClearFlags.Color ? camera.backgroundColor.linear : Color.clear);
        //在Profiler和Frame Debugger中开启对Command buffer的监测
        buffer.BeginSample(SampleName);
        // context.SetupCameraProperties(camera);
        //提交CommandBuffer并且清空它，在Setup中做这一步的作用应该是确保在后续给CommandBuffer添加指令之前，其内容是空的。
        ExecuteBuffer();
    }
    void DrawVisibleGeometry()
    {
        //决定物体绘制顺序是正交排序还是基于深度排序的配置
        var sortingSettings = new SortingSettings(camera)
        {
            criteria = SortingCriteria.CommonOpaque
        };
        //决定摄像机支持的Shader Pass和绘制顺序等的配置
        var drawingSettings = new DrawingSettings(unlitShaderTagId, sortingSettings);
        //决定过滤哪些Visible Objects的配置，包括支持的RenderQueue等
        var filteringSettings = new FilteringSettings(RenderQueueRange.opaque);
        //渲染CullingResults内不透明的VisibleObjects
        context.DrawRenderers(cullingResults, ref drawingSettings, ref filteringSettings);
        //添加“绘制天空盒”指令，DrawSkybox为ScriptableRenderContext下已有函数，这里就体现了为什么说Unity已经帮我们封装好了很多我们要用到的函数，SPR的画笔~
        context.DrawSkybox(camera);
        //渲染透明物体
        //设置绘制顺序为从后往前
        sortingSettings.criteria = SortingCriteria.CommonTransparent;
        //注意值类型
        drawingSettings.sortingSettings = sortingSettings;
        //过滤出RenderQueue属于Transparent的物体
        filteringSettings.renderQueueRange = RenderQueueRange.transparent;
        //绘制透明物体
        context.DrawRenderers(cullingResults, ref drawingSettings, ref filteringSettings);
        
    }

    void Submit()
    {
        //在Proiler和Frame Debugger中结束对Command buffer的监测
        buffer.EndSample(SampleName);
        //提交CommandBuffer并且清空它
        ExecuteBuffer();
        //提交当前上下文中缓存的指令队列，执行指令队列
        context.Submit();
    }

    void ExecuteBuffer()
    {
        //我们默认在CommandBuffer执行之后要立刻清空它，如果我们想要重用CommandBuffer，需要针对它再单独操作（不使用ExecuteBuffer），舒服的方法给常用的操作~
        context.ExecuteCommandBuffer(buffer);
        buffer.Clear();
    }

    bool Cull()
    {
        //获取摄像机用于剔除的参数
        if (camera.TryGetCullingParameters(out ScriptableCullingParameters p))
        {
            cullingResults = context.Cull(ref p);
            return true;
        }

        return false;
    }
}
