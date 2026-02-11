#ifndef STRUCTS_HLSL
#define STRUCTS_HLSL

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


struct RTrayinfo {
    float dist;
    float3 normal;
    int didHit;
};

RTrayinfo makeEmptyRTrayinfo() {
    RTrayinfo info;
    info.dist = 0.0;
    info.normal = float3(0, 0, 0);
    info.didHit = 0;
    return info;
}

struct ObjData {
    float sdf;
    float3 color;
    float3 emission;
    float pSpec;
    float roughness;
    float3 specCol;
    float IOR;
    int isRT;
    RTrayinfo RTinfo;
};

ObjData makeEmptyObjData() {
    ObjData obj;
    obj.sdf = -1.0;
    obj.color = float3(0, 0, 0);
    obj.emission = float3(0, 0, 0);
    obj.pSpec = 0.0;
    obj.roughness = 0.0;
    obj.specCol = float3(0, 0, 0);
    obj.IOR = 1.0;
    obj.isRT = 0;
    obj.RTinfo = makeEmptyRTrayinfo();
    return obj;
}
#endif