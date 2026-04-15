#ifndef COMMON_HLSL
#define COMMON_HLSL

#define PI 3.14159265359

RWTexture2D<float4> Result;
Texture2D<float4> _PreviousFrame;
SamplerState samplerLinear;

float4x4 _CameraToWorld;
float4x4 _CameraInverseProjection;

uint _FrameIndex;
uint _Width;
uint _Height;
uint _SAMPLES;
uint _BOUNCES;
uint _sceneMoving;
uint _Param;
uint _useAccumulation;
float _CurrentSample;
float3 _Sphere1;
float3 _Sphere2;
float _Smoothing;

struct obj_data {
    float sdf;
    float3 color;
    float3 emission;
    float p_spec;
    float roughness;
    float3 spec_col;
    float IOR;
};

struct light_data {
    float3 emission;
    float3 pos;
    float rad;
};

light_data light;

obj_data make_empty_obj_data() {
    obj_data data;
    data.sdf = 0.0;
    data.color = float3(0.0, 0.0, 0.0);
    data.emission = float3(0.0, 0.0, 0.0);
    data.p_spec = 0.0;
    data.roughness = 1.0;
    data.spec_col = float3(0.0, 0.0, 0.0);
    data.IOR = 0.0;
    return data;
}

#endif