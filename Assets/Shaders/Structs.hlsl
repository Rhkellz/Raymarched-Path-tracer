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

struct lightinfo {
    float3 pos;
    float rad;
};

lightinfo makeEmptyLightInfo() {
    lightinfo info;
    info.pos = float3(0.0, 0.0, 0.0);
    info.rad = 0.0;
    return info;
}

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
    lightinfo Linfo;
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
    obj.Linfo = makeEmptyLightInfo();
    return obj;
}

#endif