using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.UI;

public class CustomShaderGUI : ShaderGUI
{
    //存储当前折叠标签状态
    private bool showPresets;
    
    private MaterialEditor editor;
    //当前选中的material是数组形式，因为我们可以同时多选多个使用同一Shader的材质进行编辑。
    private Object[] materials;
    private MaterialProperty[] properties;

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        EditorGUI.BeginChangeCheck();
        //首先绘制材质Inspector下原本所有的GUI，例如材质的Properties等
        base.OnGUI(materialEditor, properties);
        //将editor、material、properties存储到字段中
        editor = materialEditor;
        materials = materialEditor.targets;
        this.properties = properties;
        
        //主动烘培自发光
        BakedEmission();
        
        //增加一行空行
        EditorGUILayout.Space();
        //设置折叠标签
        showPresets = EditorGUILayout.Foldout(showPresets, "Presets", true);
        if (showPresets)
        {
            //绘制各个渲染模式预设值的按钮
            OpaquePreset();
            ClipPreset();
            FadePreset();
            TransparentPreset();
        }

        if (EditorGUI.EndChangeCheck())
        {
            SetShadowCasterPass();
        }
    }

    /// <summary>
    /// 设置float类型的材质属性
    /// </summary>
    /// <param name="name">Property名字</param>
    /// <param name="value">要设定的值</param>
    bool SetProperty(string name, float value)
    {
        //ShaderGUI下的FindProperty函数，返回一个名为name的MaterialProperty,如果找不到返回null
        MaterialProperty property = FindProperty(name, properties,false);
        if (property != null)
        {
            property.floatValue = value;
            return true;
        }

        return false;
    }

    /// <summary>
    /// 对选中的所有材质设置shader关键字
    /// </summary>
    /// <param name="keyword">关键字名称</param>
    /// <param name="enabled">是否开启</param>
    void SetKeyword(string keyword, bool enabled)
    {
        if (enabled)
        {
            foreach (Material m in materials)
            {
                m.EnableKeyword(keyword);
            }
        }
        else
        {
            foreach (Material m in materials)
            {
                m.DisableKeyword(keyword);
            }
        }
    }

    /// <summary>
    /// 因为我们之前在Lit.shader中使用Toggle标签的属性来切换关键字，因此在通过代码开关关键字时也要对Toggle操作以同步
    /// </summary>
    /// <param name="name">关键字对应Toggle名字</param>
    /// <param name="keyword">关键字名字</param>
    /// <param name="value">是否开关</param>
    void SetProperty(string name, string keyword, bool value)
    {
        //设置Toggle
        if (SetProperty(name, value ? 1f : 0f))
        {
            //设置Toggle成功才设置关键字，防止找不到
            SetKeyword(keyword, value);
        }
        
    }

    private bool Clipping
    {
        set => SetProperty("_Clipping", "_CLIPPING", value);
    }

    private bool PremultiplyAlpha
    {
        set => SetProperty("_PremulAlpha", "_PREMULTIPLY_ALPHA", value);
    }

    private BlendMode SrcBlend
    {
        set => SetProperty("_SrcBlend", (float)value);
    }

    private BlendMode DstBlend
    {
        set => SetProperty("_DstBlend", (float)value);
    }

    private bool ZWrite
    {
        set => SetProperty("_ZWrite", value ? 1f : 0f);
    }

    RenderQueue RenderQueue
    {
        set
        {
            foreach (Material m in materials)
            {
                m.renderQueue = (int)value;
            }
        }
    }

    /// <summary>
    /// 在设置预设值前，为Button注册撤回操作
    /// </summary>
    /// <param name="name">Button要设置的渲染模式</param>
    /// <returns></returns>
    bool PresetButton(string name)
    {
        if (GUILayout.Button(name))
        {
            editor.RegisterPropertyChangeUndo(name);
            return true;
        }

        return false;
    }

    /// <summary>
    /// 设置为Opaque材质预设值
    /// </summary>
    void OpaquePreset()
    {
        if (PresetButton("Opaque"))
        {
            Clipping = false;
            PremultiplyAlpha = false;
            SrcBlend = BlendMode.One;
            DstBlend = BlendMode.Zero;
            ZWrite = true;
            RenderQueue = RenderQueue.Geometry;
            Shadows = ShadowMode.On;
        }
    }
    
    /// <summary>
    /// 设置为Alpha Clip材质预设值
    /// </summary>
    void ClipPreset()
    {
        if (PresetButton("Clip"))
        {
            Clipping = true;
            PremultiplyAlpha = false;
            SrcBlend = BlendMode.SrcAlpha;
            DstBlend = BlendMode.OneMinusSrcAlpha;
            ZWrite = true;
            RenderQueue = RenderQueue.AlphaTest;
            Shadows = ShadowMode.Clip;
        }
    }
    
    /// <summary>
    /// 设置为Fade(Alpha Blend,高光不完全保留)材质预设值
    /// </summary>
    void FadePreset()
    {
        if (PresetButton("Fade"))
        {
            Clipping = false;
            PremultiplyAlpha = false;
            SrcBlend = BlendMode.SrcAlpha;
            DstBlend = BlendMode.OneMinusSrcAlpha;
            ZWrite = false;
            RenderQueue = RenderQueue.Transparent;
            Shadows = ShadowMode.Dither;
        }
    }
    
    /// <summary>
    /// 设置为Transparent(开启Premultiply Alpha)材质预设值
    /// </summary>
    void TransparentPreset()
    {
        if (HasPremultiplyAlpha && PresetButton("Transparent"))
        {
            Clipping = false;
            PremultiplyAlpha = true;
            SrcBlend = BlendMode.One;
            DstBlend = BlendMode.OneMinusSrcAlpha;
            ZWrite = false;
            RenderQueue = RenderQueue.Transparent;
            Shadows = ShadowMode.Dither;
        }
    }
    
    /// <summary>
    /// 该函数判断当前材质是否包含该属性
    /// </summary>
    /// <param name="name">属性名称</param>
    /// <returns></returns>
    bool HasProperty(string name) => FindProperty(name, properties, false) != null;

    private bool HasPremultiplyAlpha => HasProperty("_PremulAlpha");

    enum ShadowMode
    {
        On,Clip,Dither,Off
    }

    ShadowMode Shadows
    {
        set
        {
            if (SetProperty("_Shadows", (float)value))
            {
                SetKeyword("_SHADOWS_CLIP", value == ShadowMode.Clip);
                SetKeyword("_SHADOWS_DITHER", value == ShadowMode.Dither);
            }
        }
    }

    void SetShadowCasterPass()
    {
        MaterialProperty shadows = FindProperty("_Shadows", properties, false);
        if (shadows == null || shadows.hasMixedValue)
        {
            return;
        }

        bool enabled = shadows.floatValue < (float)ShadowMode.Off;
        foreach (Material m in materials)
        {
            m.SetShaderPassEnabled("ShadowCaster", enabled);
        }
    }

    //主动烘培自发光
    void BakedEmission()
    {
        EditorGUI.BeginChangeCheck();
        editor.LightmapEmissionProperty();
        //让Unity识别要计算自发光的所有材质
        if (EditorGUI.EndChangeCheck())
        {
            foreach (Material m in editor.targets)
            {
                m.globalIlluminationFlags &= ~ MaterialGlobalIlluminationFlags.EmissiveIsBlack;
            }
        }
    }
    
    //复制_BaseMap和_BaseColor到_MainTex和_Color，为了支持透明材质的烘培
    void CopyLightMappingProperties()
    {
        MaterialProperty mainTex = FindProperty("_MainTex", properties, false);
        MaterialProperty baseMap = FindProperty("_BaseMap", properties, false);
        if (mainTex != null && baseMap != null)
        {
            mainTex.textureValue = baseMap.textureValue;
            mainTex.textureScaleAndOffset = baseMap.textureScaleAndOffset;
        }

        MaterialProperty color = FindProperty("_Color", properties, false);
        MaterialProperty baseColor = FindProperty("_BaseColor", properties, false);
        if (color != null && baseColor != null)
        {
            color.colorValue = baseColor.colorValue;
        }
    }
}
