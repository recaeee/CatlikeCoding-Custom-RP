Shader "Custom RP/Lit"
{
    Properties
    {
        //[可选：特性]变量名(Inspector上的文本,类型名) = 默认值
        //[optional: attribute] name("display text in Inspector", type name) = default value

        //"white"为默认纯白贴图，{}在很久之前用于纹理的设置
        _BaseMap("Texture", 2D) = "white"{}
        _BaseColor("Color",Color) = (0.5,0.5,0.5,1.0)
        //透明度测试阈值
        _Cutoff("Alpha Cutoff",Range(0.0,1.0)) = 0.5
        //Clip的Shader关键字，启用该Toggle会将_Clipping关键字添加到该材质的活动关键字列表中，而禁用该Toggle会将其删除
        [Toggle(_CLIPPING)] _Clipping("Alpha Clipping",Float) = 0
        //是否接收阴影
        [Toggle(_RECEIVE_SHADOWS)] _ReceiveShadows("Receive Shadows",Float) = 1
        //阴影投射模式
        [KeywordEnum(On,Clip,Dither,Off)] _Shadows("Shadows",Float) = 0
        //是否使用MODS Map
        [Toggle(_MASK_MAP)]_MaskMapToggle("Mask Map",Float) = 0
        //MODS贴图 Metallic Occlusion Details Smoothness
        [NoScaleOffset]_MaskMap("Mask (MODS)", 2D) = "white"{}
        //PBR模型下Metallic Workflow的两个物体表面参数
        //金属度系数
        _Metallic("Metallic",Range(0,1)) = 0
        //遮蔽系数
        _Occlusion("Occlusion",Range(0,1)) = 1
        //光滑度系数
        _Smoothness("Smoothness",Range(0,1)) = 0.5
        //菲涅尔系数
        _Fresnel("Fresnel",Range(0,1)) = 1
        //是否启用法线贴图
        [Toggle(_NORMAL_MAP)]_NormalMapToggle("Normal Map", Float) = 0
        //法线贴图，注意默认值为bump
        [NoSacleOffset]_NormalMap("Normals",2D) = "bump"{}
        //法线偏移系数
        _NormalScale("Normal Scale",Range(0,1)) = 1
        //自发光纹理，使用的变换同BaseMap
        [NoScaleOffset]_EmissionMap("Emission",2D) = "white"{}
        //自发光颜色，使用HDR颜色
        [HDR]_EmissionColor("Emission",Color) = (0.0,0.0,0.0,0.0)
        //是否使用Detail Map
        [Toggle(_DETAIL_MAP)]_DetailMapToggle("Detail Maps",Float) = 0
        //细节贴图，R通道存Albedo的修改，G通道存Smoothness的修改
        _DetailMap("Details",2D) = "linearGrey"{}
        //法线细节贴图
        [NoScaleOffset]_DetailNormalMap("Detail Normals",2D) = "bump"{}
        //细节贴图Albedo系数
        _DetailAlbedo("Detail Albedo",Range(0,1)) = 1
        //细节贴图Smoothness系数
        _DetailSmoothness("Detail Smoothness",Range(0,1)) = 1
        //法线细节贴图系数
        _DetailNormalScale("Detail Normal Scale",Range(0,1)) = 1
        //Premultiply Alpha的关键字
        [Toggle(_PREMULTIPLY_ALPHA)]_PremulAlpha("Premultiply Alpha",Float) = 0

        //混合模式使用的值，其值应该是枚举值，但是这里使用float
        //特性用于在Editor下更方便编辑
        [Enum(UnityEngine.Rendering.BlendMode)]_SrcBlend("Src Blend",Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)]_DstBlend("Dst Blend",Float) = 0
        //深度写入模式
        [Enum(Off,0,On,1)] _ZWrite("Z Write",Float) = 1
        
        //烘培透明材质用的_MainTex和_Color
        [HideInInspector]_MainTex("Texture for Lightmap", 2D) = "white"{}
        [HideInInspector]_Color("Color for Lightmap", Color) = (0.5,0.5,0.5,1.0)
    }

    SubShader
    {
        //Meta Pass相关，需要加入所有Pass，所以放在SubShader标签下
        HLSLINCLUDE
        #include "../ShaderLibrary/Common.hlsl"
        #include "LitInput.hlsl"
        ENDHLSL
        Pass
        {
            //设置Pass Tags，最关键的Tag为"LightMode"
            Tags
            {
                "LightMode" = "CustomLit"
            }
            //设置混合模式
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]

            HLSLPROGRAM
            //不生成OpenGL ES 2.0等图形API的着色器变体，其不支持可变次数的循环与线性颜色空间
            #pragma target 3.5
            //告诉Unity启用_CLIPPING关键字时编译不同版本的Shader
            #pragma shader_feature _CLIPPING
            //定义是否接收阴影关键字
            #pragma shader_feature _RECEIVE_SHADOWS
            //定义diffuse项是否使用Premultiplied alpha的关键字
            #pragma shader_feature _PREMULTIPLY_ALPHA
            //定义PCF关键字,无关键字为2
            #pragma multi_compile _ _DIRECTIONAL_PCF3 _DIRECTIONAL_PCF5 _DIRECTIONAL_PCF7
            //定义级联混合的关键字
            #pragma multi_compile _ _CASCADE_BLEND_SOFT _CASCADE_BLEND_DITHER
            //定义是否启用阴影遮罩，当光源的lightMode为ShadowMask且光源lightmapBakeType为Mixed时开启该关键字，并根据ShadowmaskMode决定开启哪个关键字
            #pragma multi_compile _ _SHADOW_MASK_ALWAYS _SHADOW_MASK_DISTANCE
            //定义光照贴图的关键字，启用光照贴图时，Unity会自动使用开启该关键字的着色器变体
            #pragma multi_compile _ LIGHTMAP_ON
            //是否启用法线贴图
            #pragma shader_feature _NORMAL_MAP
            //是否使用MODS贴图
            #pragma shader_feature _MASK_MAP
            //是否使用Detail Map
            #pragma shader_feature _DETAIL_MAP
            //是否使用PerObjectLights
            #pragma multi_complie _ _LIGHTS_PER_OBJECTS
            //其他光源使用的软阴影模式
            #pragma multi_compile _ _OTHER_PCF3 _OTHER_PCF5 _OTHER_PCF7
            //这一指令会让Unity生成两个该Shader的变体，一个支持GPU Instancing，另一个不支持。
            #pragma multi_compile_instancing
            //生成LOD过渡使用的变体，主Pass和阴影Pass都需要
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment
            #include "LitPass.hlsl"
            ENDHLSL
        }

        //渲染阴影的Pass
        Pass
        {
            //阴影Pass的LightMode为ShadowCaster
            Tags
            {
                "LightMode" = "ShadowCaster"
            }
            //因为只需要写入深度，关闭对颜色通道的写入
            ColorMask 0

            HLSLPROGRAM
            //支持的最低平台
            #pragma target 3.5
            //阴影投射模式
            #pragma shader_feature _ _SHADOWS_CLIP _SHADOWS_DITHER
            //定义diffuse项是否使用Premultiplied alpha的关键字
            #pragma multi_compile_instancing
            //生成LOD过渡使用的变体，主Pass和阴影Pass都需要
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma vertex ShadowCasterPassVertex
            #pragma fragment ShadowCasterPassFragment
            //阴影相关方法写在ShadowCasterPass.hlsl
            #include "ShadowCasterPass.hlsl"
            ENDHLSL
        }

        //GI相关的Meta Pass(Meta Pass是为全局光照系统提供反射率和自发光的Pass)
        Pass
        {
            Tags
            {
                "LightMode" = "Meta"
            }
            //关闭剔除
            Cull Off

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex MetaPassVertex
            #pragma fragment MetaPassFragment

            #ifndef CUSTOM_META_PASS_INCLUDED
            #define CUSTOM_META_PASS_INCLUDED

            //为了获取BRDF.hlsl，需要编译其依赖代码
            #include "../ShaderLibrary/Surface.hlsl"
            #include "../ShaderLibrary/Shadows.hlsl"
            #include "../ShaderLibrary/Light.hlsl"
            #include "../ShaderLibrary/BRDF.hlsl"

            struct Attributes
            {
                float3 positionOS:POSITION;
                float2 baseUV:TEXCOORD0;
                //片元对应光照贴图的坐标，需要烘培到该坐标对应像素
                float2 lightMapUV:TEXCOORD1;
            };

            struct Varyings
            {
                float4 positionCS:SV_POSITION;
                float2 baseUV:VAR_BASE_UV;
            };

            //用于控制metea Pass生成的数据
            bool4 unity_MetaFragmentControl;
            //提亮diffuse所用内置值
            float unity_OneOverOutputBoost;
            float unity_MaxOutputValue;

            Varyings MetaPassVertex(Attributes input)
            {
                Varyings output;
                //这里input.positionOS和CS不再代表模型、裁剪空间下顶点位置，而是代表顶点在UV坐标系下的位置
                input.positionOS.xy = input.lightMapUV * unity_LightmapST.xy + unity_LightmapST.zw;
                input.positionOS.z = input.positionOS.z > 0.0 ? FLT_MIN : 0.0;
                output.positionCS = TransformWorldToHClip(input.positionOS);
                output.baseUV = TransformBaseUV(input.baseUV);
                return output;
            }

            float4 MetaPassFragment(Varyings input):SV_TARGET
            {
                InputConfig config = GetInputConfig(input.baseUV);
                //获取Diffuse
                float4 base = GetBase(config);
                //构造Surface
                Surface surface;
                //将Surface中的所有数据成员初始化为0值
                ZERO_INITIALIZE(Surface,surface);
                surface.color = base.rgb;
                surface.metallic = GetMetallic(config);
                surface.smoothness = GetSmoothness(config);
                BRDF brdf = GetBRDF(surface);
                float4 meta = 0.0;
                //x控制漫反射
                if(unity_MetaFragmentControl.x)
                {
                    meta = float4(brdf.diffuse, 1.0);
                    //高度反射specular并且高度粗糙的物体表面也提供部分间接光照
                    meta.rgb += brdf.specular * brdf.roughness * 0.5;
                    //再提升点亮度
                    meta.rgb = min(PositivePow(meta.rgb, unity_OneOverOutputBoost), unity_MaxOutputValue);
                }
                //y控制自发光
                else if(unity_MetaFragmentControl.y)
                {
                    meta = float4(GetEmission(config),1.0);
                }
                return meta;
            }
            
            #endif
            ENDHLSL
        }
    }

    //告诉Unity编辑器使用CustomShaderGUI类的一个实例来为使用Lit.shader的材质绘制Inspector窗口
    CustomEditor "CustomShaderGUI"
}