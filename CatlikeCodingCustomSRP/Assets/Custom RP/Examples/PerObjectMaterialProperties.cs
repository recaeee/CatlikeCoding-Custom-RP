using UnityEngine;

//特性：不允许同一物体挂多个该组件
[DisallowMultipleComponent]
public class PerObjectMaterialProperties : MonoBehaviour
{
    //获取名为"_BaseColor"的Shader属性（全局）
    private static int baseColorId = Shader.PropertyToID("_BaseColor"),
        cutoffId = Shader.PropertyToID("_Cutoff"),
        metallicId = Shader.PropertyToID("_Metallic"),
        smoothnessId = Shader.PropertyToID("_Smoothness"),
        emissionColorId = Shader.PropertyToID("_EmissionColor");
    
    //每个物体自己的颜色
    [SerializeField] Color baseColor = Color.white;
    //每个物体的AlphaTest阈值
    [SerializeField, Range(0f, 1f)] private float cutoff = 0.5f, metallic = 0f, smoothness = 0.5f;
    //HDR的自发光颜色
    [SerializeField, ColorUsage(false,true)] Color emissionColor = Color.black;
    //MaterialPropertyBlock用于给每个物体设置材质属性，将其设置为静态，所有物体使用同一个block
    private static MaterialPropertyBlock block;

    //每当设置脚本的属性时都会调用 OnValidate（Editor下）
    private void OnValidate()
    {
        if (block == null)
        {
            block = new MaterialPropertyBlock();
        }

        //设置block中的baseColor属性(通过baseCalorId索引)为baseColor
        block.SetColor(baseColorId, baseColor);
        block.SetFloat(cutoffId, cutoff);
        block.SetFloat(metallicId, metallic);
        block.SetFloat(smoothnessId, smoothness);
        block.SetColor(emissionColorId, emissionColor);
        //将物体的Renderer中的颜色设置为block中的颜色
        GetComponent<Renderer>().SetPropertyBlock(block);
    }

    //Runtime时也执行
    private void Awake()
    {
        OnValidate();
    }
}
