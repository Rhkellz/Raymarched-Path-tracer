#ifndef SCENE_HLSL
#define SCENE_HLSL
#include "Structs.hlsl"
#include "GeometryFuncs.hlsl"
ObjData map(float3 p) {
    ObjData res = makeEmptyObjData();
    
                // Sphere 1
    ObjData s1;
    s1.sdf = sdfSphere(p, _Sphere1, 0.2);
    s1.color = float3(1.0, 0.3, 0.0);
    s1.emission = float3(0.0, 0.0, 0.0);
    s1.pSpec = 0.5;
    s1.roughness = 0.0;
    s1.specCol = float3(1.0, 1.0, 1.0);
    s1.IOR = 1.0;
    
                // Sphere 2
    ObjData s2;
    s2.sdf = sdfSphere(p, _Sphere2, 0.2);
    s2.color = float3(0.0, 0.2, 1.0);
    s2.emission = float3(0.0, 0.0, 0.0);
    s2.pSpec = 1.0;
    s2.roughness = 0.5;
    s2.specCol = float3(1.0, 1.0, 1.0);
    s2.IOR = 1.0;
    
                

    float2 smoothBlend = smin(s1.sdf, s2.sdf, _Smoothing);
    res.sdf = smoothBlend.x;
    res.color = lerp(s1.color, s2.color, smoothBlend.y);
    res.emission = float3(0, 0, 0);
    res.pSpec = lerp(s1.pSpec, s2.pSpec, smoothBlend.y);
    res.roughness = lerp(s1.roughness, s2.roughness, smoothBlend.y);
    res.specCol = lerp(s1.specCol, s2.specCol, smoothBlend.y);
    res.IOR = lerp(s1.IOR, s2.IOR, smoothBlend.y);

    return res;
}

ObjData raytraceScene(float3 ro, float3 rd)
{
    ObjData res = makeEmptyObjData();
    res.isRT = 1;
    res.RTinfo.dist = 1e20; // Start with max distance

    RTrayinfo tempInfo = makeEmptyRTrayinfo();

                // Back wall
    float3 center = float3(0, 0, 0.75);
    float3 rad = float3(0.75, 0.75, 1e-4);
    if (box_intersect(ro, rd, tempInfo, center, rad))
    {
        if (tempInfo.dist < res.RTinfo.dist)
        {
            res.RTinfo = tempInfo;
            res.color = float3(1, 1, 1);
        }
    }
    
                // Floor
    center = float3(0, -0.75, 0);
    rad = float3(0.75, 1e-4, 0.75);
    if (box_intersect(ro, rd, tempInfo, center, rad))
    {
        if (tempInfo.dist < res.RTinfo.dist)
        {
            res.RTinfo = tempInfo;
            res.color = float3(1, 1, 1);
        }
    }
    
                // Ceiling
    center = float3(0, 0.75, 0);
    rad = float3(0.75, 1e-4, 0.75);
    if (box_intersect(ro, rd, tempInfo, center, rad))
    {
        if (tempInfo.dist < res.RTinfo.dist)
        {
            res.RTinfo = tempInfo;
            res.color = float3(1, 1, 1);
        }
    }

                //Light
    center = float3(0, 0.74, 0);
    rad = float3(0.25, 1e-4, 0.25);
    if (box_intersect(ro, rd, tempInfo, center, rad))
    {
        if (tempInfo.dist < res.RTinfo.dist)
        {
            res.RTinfo = tempInfo;
            res.color = float3(0.0, 0.0, 0.0);
            res.emission = float3(5.0, 5.0, 5.0);
            res.specCol = float3(1.0, 1.0, 1.0);
        }
    }
    
                // Left wall (red)
    center = float3(-0.75, 0, 0);
    rad = float3(0, 0.75, 0.75);
    if (box_intersect(ro, rd, tempInfo, center, rad))
    {
        if (tempInfo.dist < res.RTinfo.dist)
        {
            res.RTinfo = tempInfo;
            res.color = float3(1, 1, 1);
            res.pSpec = 1.0;
        }
    }
    
                // Right wall (green)
    center = float3(0.75, 0, 0);
    rad = float3(1e-4, 0.75, 0.75);
    if (box_intersect(ro, rd, tempInfo, center, rad))
    {
        if (tempInfo.dist < res.RTinfo.dist)
        {
            res.RTinfo = tempInfo;
            res.color = float3(1, 1, 1);
            res.pSpec = 1.0;
        }
    }

    return res;
}

#endif