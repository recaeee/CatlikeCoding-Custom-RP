//存储Shader中的一些常用的输入数据
#ifndef CUSTOM_UNITY_INPUT_INCLUDED
#define CUSTOM_UNITY_INPUT_INCLUDED

//这三个变量也使用CBUFFER，使用UnityPerDraw命名该Buffer（UnityPerDraw为Unity内置好的名字）
//UnityPerDraw每次绘制一个对象需要的信息
CBUFFER_START(UnityPerDraw)
float4x4 unity_ObjectToWorld;
float4x4 unity_WorldToObject;
//在定义（UnityPerDraw）CBuffer时，因为Unity对一组相关数据都归到一个Feature中，即使我们没用到unity_LODFade，我们也需要放到这个CBuffer中来构造一个完整的Feature
//unity_LODFade供LOD过渡使用，其x值表示当前过渡值（对于fade out的LOD，0代表开始fade out，1代表完全fade out；对于fade in的LOD，-1代表开始fade in，0代表完全fade in），y表示过渡值在16个区间划分内的值（不会使用到）
float4 unity_LODFade;
real4 unity_WorldTransformParams;
//每物体光源信息
//unity_LightData的y分量存储了该物体的有效光源总数
real4 unity_LightData;
//unity_LightIndices的每个分量存一个光源索引，因此每个物体至多有8个有效光源
real4 unity_LightIndices[2];
//遮蔽探针
float4 unity_ProbesOcclusion;
//反射探针信息，包括使用HDR还是LDR，强度
float4 unity_SpecCube0_HDR;
//光照贴图uv的变换，它们定义了一个纹理展开方式。纹理展开：将Mesh的每个三角网格映射到一个二维平面(UV坐标系)
float4 unity_LightmapST;
float4 unity_DynamicLightmapST;
//球谐函数的所有系数，一共27个，RGB通道每个9个,实际为float3, SH : Spherical Harmonics
float4 unity_SHAr;
float4 unity_SHAg;
float4 unity_SHAb;
float4 unity_SHBr;
float4 unity_SHBg;
float4 unity_SHBb;
float4 unity_SHC;
//LPPV所需信息
float4 unity_ProbeVolumeParams;
float4x4 unity_ProbeVolumeWorldToObject;
float4 unity_ProbeVolumeSizeInv;
float4 unity_ProbeVolumeMin;
CBUFFER_END

float4x4 unity_MatrixVP;
float4x4 unity_MatrixV;
float4x4 glstate_matrix_projection;

//获取内置参数：摄像机世界空间位置
float3 _WorldSpaceCameraPos;
//_ProjectionParams的X分量指示我们是否需要手动反转纹理v坐标(负值表示需要反转）
float4 _ProjectionParams;

#endif
