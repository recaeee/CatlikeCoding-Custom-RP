using UnityEngine;
using UnityEngine.Rendering;

public class CustomRenderPipeline : RenderPipeline
{
    //摄像机渲染器实例，用于管理所有摄像机的渲染
    private CameraRenderer renderer = new CameraRenderer();

    //构造函数，初始化管线的一些属性
    public CustomRenderPipeline()
    {
        //支持SRP Batch
        GraphicsSettings.useScriptableRenderPipelineBatching = true;
    }
    
    //必须重写Render函数，渲染管线实例每帧执行Render函数
    protected override void Render(ScriptableRenderContext context, Camera[] cameras)
    {
        //按顺序渲染每个摄像机
        foreach (var camera in cameras)
        {
            renderer.Render(context, camera);
        }
    }
}
