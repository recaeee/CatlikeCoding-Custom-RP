using UnityEngine;
using UnityEngine.Rendering;

public partial class PostFXStack
{
    private const string bufferName = "Post FX";

    private CommandBuffer buffer = new CommandBuffer()
    {
        name = bufferName
    };

    private ScriptableRenderContext context;

    private Camera camera;

    private PostFXSettings settings;
    
    //后处理各Pass名
    enum Pass
    {
        BloomHorizontal,
        BloomVertical,
        BloomCombine,
        BloomPrefilter,
        Copy
    }
    
    //Bloom
    //Bloom降采样最大次数
    private const int maxBloomPyramidLevels = 16;
    //第一张降采样RT，后续直接数组索引++
    private int bloomPyramidId;

    private int bloomBicubicUpsamplingId = Shader.PropertyToID("_BloomBicubicUpsampling"),
        //Bloom半分辨率初始RT
        bloomPrefilterId = Shader.PropertyToID("_BloomPrefilter"),
        //亮度阈值
        bloomThresholdId = Shader.PropertyToID("_BloomThreshold"),
        //Bloom强度
        bloomIntensityId = Shader.PropertyToID("_BloomIntensity"),
        fxSourceId = Shader.PropertyToID("_PostFXSource"),
        fxSource2Id = Shader.PropertyToID("_PostFXSource2");

    //控制后处理堆栈是否激活，如果Settings资源为null，则跳过后处理阶段
    public bool IsActive => settings != null;

    public PostFXStack()
    {
        //构造时连续请求所有BloomPyramid标识符
        bloomPyramidId = Shader.PropertyToID("_BloomPyramid0");
        for (int i = 1; i < maxBloomPyramidLevels * 2; i++)
        {
            Shader.PropertyToID("_BloomPyramid" + i);
        }
    }

    public void Setup(ScriptableRenderContext context, Camera camera, PostFXSettings settings)
    {
        this.context = context;
        this.camera = camera;
        //只对Game和Scene摄像机起作用
        this.settings = camera.cameraType <= CameraType.SceneView ? settings : null;
        //对不同Scene窗口摄像机提供开关
        ApplySceneViewState();
    }

    public void Render(int sourceId)
    {
        // buffer.Blit(sourceId, BuiltinRenderTextureType.CameraTarget);
        //用单个三角面片实现后处理
        //Bloom
        DoBloom(sourceId);
        context.ExecuteCommandBuffer(buffer);
        buffer.Clear();
    }

    void Draw(RenderTargetIdentifier from, RenderTargetIdentifier to, Pass pass)
    {
        buffer.SetGlobalTexture(fxSourceId, from);
        buffer.SetRenderTarget(to, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
        buffer.DrawProcedural(Matrix4x4.identity, settings.Material, (int)pass, MeshTopology.Triangles, 3);
    }

    //Bloom后处理
    void DoBloom(int sourceId)
    {
        buffer.BeginSample("Bloom");
        //获取Bloom配置
        PostFXSettings.BloomSettings bloom = settings.Bloom;
        //将相机的各维度像素数减半
        int width = camera.pixelWidth / 2, height = camera.pixelHeight / 2;
        
        //是否需要阻断Bloom
        if (bloom.maxIterations == 0 || bloom.intensity <= 0f ||
            height < bloom.downScaleLimit * 2 || width < bloom.downScaleLimit * 2)
        {
            Draw(sourceId, BuiltinRenderTextureType.CameraTarget, Pass.Copy);
            buffer.EndSample("Bloom");
            return;
        }
        
        RenderTextureFormat format = RenderTextureFormat.Default;
        //计算亮度阈值
        Vector4 threshold;
        threshold.x = Mathf.GammaToLinearSpace(bloom.threshold);
        threshold.y = threshold.x * bloom.thresholdKnee;
        threshold.z = 2f * threshold.y;
        threshold.w = 0.25f / (threshold.y + 0.00001f);
        threshold.y -= threshold.x;
        buffer.SetGlobalVector(bloomThresholdId, threshold);
        //初始状态为半分辨率
        buffer.GetTemporaryRT(bloomPrefilterId, width, height, 0, FilterMode.Bilinear, format);
        Draw(sourceId, bloomPrefilterId, Pass.BloomPrefilter);
        width /= 2;
        height /= 2;
        int fromId = bloomPrefilterId, toId = bloomPyramidId + 1;
        //生成所有Pyramid
        int i;
        for (i = 0; i < bloom.maxIterations; i++)
        {
            if (height < bloom.downScaleLimit || width < bloom.downScaleLimit)
            {
                break;
            }
            //构造中间RT，用于存储横向高斯滤波结果
            int midId = toId - 1;
            buffer.GetTemporaryRT(midId, width, height, 0, FilterMode.Bilinear, format);
            buffer.GetTemporaryRT(toId, width, height, 0, FilterMode.Bilinear, format);
            //横向
            Draw(fromId, midId, Pass.BloomHorizontal);
            //纵向
            Draw(midId, toId, Pass.BloomVertical);
            fromId = toId;
            toId += 2;
            width /= 2;
            height /= 2;
        }
        //释放半分辨率RT
        buffer.ReleaseTemporaryRT(bloomPrefilterId);
        //是否使用双三次上采样
        buffer.SetGlobalFloat(bloomBicubicUpsamplingId, bloom.bicubicUpsampling ? 1f : 0f);
        //强度，在上采样时混合权重为1
        buffer.SetGlobalFloat(bloomIntensityId, 1f);
        //叠加不同Pyramid颜色——上采样
        if (i > 1)
        {
            //先释放最上层的HorizonMidRT
            buffer.ReleaseTemporaryRT(fromId - 1);
            toId -= 5;
            //释放Pyramid内存
            for (i -= 1; i > 0; i--)
            {
                buffer.SetGlobalTexture(fxSource2Id, toId + 1);
                Draw(fromId, toId, Pass.BloomCombine);
                buffer.ReleaseTemporaryRT(fromId);
                buffer.ReleaseTemporaryRT(toId + 1);
                fromId = toId;
                toId -= 2;
            }
        }
        else
        {
            buffer.ReleaseTemporaryRT(bloomPyramidId);
        }

        buffer.SetGlobalFloat(bloomIntensityId, bloom.intensity);
        buffer.SetGlobalTexture(fxSource2Id, sourceId);
        //最后叠加时，使用intensity作为混合系数
        Draw(fromId, BuiltinRenderTextureType.CameraTarget, Pass.BloomCombine);
        buffer.ReleaseTemporaryRT(fromId);
        
        buffer.EndSample("Bloom");
    }
}
