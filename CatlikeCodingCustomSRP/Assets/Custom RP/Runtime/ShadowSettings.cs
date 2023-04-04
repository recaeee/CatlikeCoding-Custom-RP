using UnityEngine;

//单纯用来存放阴影配置选项的容器
[System.Serializable]
public class ShadowSettings
{
    //maxDistance决定视野内多大范围会被渲染到阴影贴图上，距离主摄像机超过maxDistance的物体不会被渲染在阴影贴图上
    //其具体逻辑猜测如下：
    //1.根据maxDistance（或者摄像机远平面）得到一个BoundingBox，这个BoundingBox（也可能是个球型）容纳了所有要渲染阴影的物体
    //2.根据这个BoundingBox（也可能是个球型）和方向光源的方向，确定渲染阴影贴图用的正交摄像机的视锥体，渲染阴影贴图
    //maxDistance不能为0，因为在阴影渐变中其作为分母
    [Min(0.001f)] public float maxDistance = 100f;
    
    //渐变距离比例(0.1表示在[0.9,1]*maxDistance的范围做渐变过渡
    [Range(0.001f, 1f)] public float distanceFade = 0.1f;

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

    /// <summary>
    /// PCF过滤等级
    /// </summary>
    public enum FilterMode
    {
        PCF2x2,PCF3x3,PCF5x5,PCF7x7
    }
    

    //定义方向光源的统一阴影贴图配置
    [System.Serializable]
    public struct Directional
    {
        public TextureSize atlasSize;

        public FilterMode filter;
        //阴影级联数
        [Range(1, 4)] public int cascadeCount;
        
        //每层级联的maxShadowDistance比例
        [Range(0f, 1f)] public float cascadeRatio1, cascadeRatio2, cascadeRatio3;

        //提供给ComputeDirectionalShadowMatricesAndCullingPrimitives方法的参数，包装成Vector3
        public Vector3 CascadeRatios => new Vector3(cascadeRatio1, cascadeRatio2, cascadeRatio3);
        
        //最大级联阴影的自然消失过渡
        [Range(0.001f, 1f)] public float cascadeFade;
        
        /// <summary>
        /// PCF不同级联交界处过渡模式
        /// </summary>
        public enum CascadeBlendMode
        {
            Hard,Soft,Dither
        }

        public CascadeBlendMode cascadeBlendMode;
    }

    //创建一个1024大小的Directional Shadow Map
    public Directional directional = new Directional()
    {
        atlasSize = TextureSize._1024,
        filter = FilterMode.PCF2x2,
        cascadeCount = 4,
        cascadeRatio1 = 0.1f,
        cascadeRatio2 = 0.25f,
        cascadeRatio3 = 0.5f,
        cascadeFade = 0.1f,
        cascadeBlendMode = Directional.CascadeBlendMode.Hard
    };
    
    //其他光源的统一阴影贴图配置
    [System.Serializable]
    public struct Other
    {
        public TextureSize atlasSize;
        public FilterMode filter;
    }

    public Other other = new Other()
    {
        atlasSize = TextureSize._1024,
        filter = FilterMode.PCF2x2
    };
}