//存储一些常用的函数，如空间变换
#ifndef CUSTOM_COMMON_INCLUDED
#define CUSTOM_COMMON_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "UnityInput.hlsl"

// float3 TransformObjectToWorld(float3 positionOS)
// {
//     return mul(unity_ObjectToWorld,float4(positionOS,1.0)).xyz;
// }
//
// float4 TransformWorldToHClip(float3 positionWS)
// {
//     return mul(unity_MatrixVP,float4(positionWS,1.0));
// }
//将Unity内置着色器变量转换为SRP库需要的变量
#define UNITY_MATRIX_M unity_ObjectToWorld
#define UNITY_MATRIX_I_M unity_WorldToObject
#define UNITY_MATRIX_V unity_MatrixV
#define UNITY_MATRIX_VP unity_MatrixVP
#define UNITY_MATRIX_P glstate_matrix_projection
//使用2021版本的坑，我们还需要定义两个PREV标识符，才不会报错，但这两个变量具体代表什么未知
#define UNITY_PREV_MATRIX_M unity_ObjectToWorld
#define UNITY_PREV_MATRIX_I_M unity_WorldToObject
//我们直接使用SRP库中已经帮我们写好的函数
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

#endif
