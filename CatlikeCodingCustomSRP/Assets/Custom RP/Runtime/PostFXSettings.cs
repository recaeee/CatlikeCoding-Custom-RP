using UnityEngine;

//后处理配置资源，类似于URP的VolumeProfile
[CreateAssetMenu(menuName = "Rendering/Custom Post FX Settings")]
public class PostFXSettings : ScriptableObject
{
    [SerializeField] private Shader shader = default;
    
    //运行时创建材质
    [System.NonSerialized] private Material material;
    public Material Material
    {
        get
        {
            if (material == null && shader != null)
            {
                material = new Material(shader);
                material.hideFlags = HideFlags.HideAndDontSave;
            }

            return material;
        }
    }
    
    //Bloom配置
    [System.Serializable]
    public struct BloomSettings
    {
        //最大降采样迭代次数
        [Range(0f, 16f)] public int maxIterations;
        //最小Pyramid尺寸
        [Min(1f)] public int downScaleLimit;
        //是否使用双三次上采样
        public bool bicubicUpsampling;
        //亮度阈值
        [Min(0f)] public float threshold;
        //平滑过渡值
        [Range(0f, 1f)] public float thresholdKnee;
        //强度
        [Min(0f)] public float intensity;
    }

    [SerializeField] private BloomSettings bloom = default;

    public BloomSettings Bloom => bloom;
}
