//存储Shader中的一些常用的输入数据
#ifndef CUSTOM_UNITY_INPUT_INCLUDED
#define CUSTOM_UNITY_INPUT_INCLUDED

//这三个变量也使用CBUFFER，使用UnityPerDraw命名该Buffer
CBUFFER_START(UnityPerDraw)
float4x4 unity_ObjectToWorld;
float4x4 unity_WorldToObject;
//一组“相关”数据需要被定义到一个组中，即使我们没用到unity_LODFade，我们也需要放到这个CBuffer中（可能unity_LODFade与这几个数值有关联，但我不太清楚）
//如果不加这个unity_LODFade，不能支持SRP Batcher
float4 unity_LODFade;
real4 unity_WorldTransformParams;
CBUFFER_END

float4x4 unity_MatrixVP;
float4x4 unity_MatrixV;
float4x4 glstate_matrix_projection;

#endif
