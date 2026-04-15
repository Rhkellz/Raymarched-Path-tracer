#ifndef SCENE_HLSL
#define SCENE_HLSL
#include "Structs.hlsl"
#include "GeometryFuncs.hlsl"

ObjData map(float3 p) {
    ObjData SDFs[3];
    uint SDFs_len = 3;
    
    ObjData s1 = makeEmptyObjData();;
    s1.sdf = sdfSphere(p, _Sphere1, 0.3);
    s1.color = float3(1.0, 1.0, 1.0);
    s1.emission = float3(0.0, 0.0, 0.0);
    s1.pSpec = 0.5;
    s1.roughness = 0.0;
    s1.specCol = float3(1.0, 1.0, 1.0);
    s1.IOR = 1.0;
    
    ObjData s2 = makeEmptyObjData();;
    s2.sdf = sdfSphere(p, _Sphere2, 0.3);
    s2.color = float3(1.0, 1.0, 1.0);
    s2.emission = float3(0.0, 0.0, 0.0);
    s2.pSpec = 1.0;
    s2.roughness = 0.5;
    s2.specCol = float3(1.0, 1.0, 1.0);
    s2.IOR = 1.0;
    
    ObjData s3 = makeEmptyObjData();;
    s3.sdf = sdfSphere(p, float3(0, 1.1, 0), 0.2);
    s3.color = float3(0.0, 0.0, 0.0);
    s3.emission = float3(5.0, 5.0, 5.0);
    
    SDFs[0] = s1;
    SDFs[1] = s2;
    SDFs[2] = s3;
    
    //assumes SDFs.len >= 2
    ObjData res = SDFs[0];

    for (uint i = 1; i < SDFs_len; i++) {
        
        if (length(SDFs[i].emission) > 0.0001) {
            if (min(res.sdf, SDFs[i].sdf) == SDFs[i].sdf) {
                res.emission = SDFs[i].emission;
                res.sdf = SDFs[i].sdf;
            }
            continue;
        }
        float2 smoothBlend = smin(res.sdf, SDFs[i].sdf, _Smoothing);

        res.sdf = smoothBlend.x;
        res.color = lerp(res.color, SDFs[i].color, smoothBlend.y);
        res.pSpec = lerp(res.pSpec, SDFs[i].pSpec, smoothBlend.y);
        res.roughness = lerp(res.roughness, SDFs[i].roughness, smoothBlend.y);
        res.specCol = lerp(res.specCol, SDFs[i].specCol, smoothBlend.y);
        res.IOR = lerp(res.IOR, SDFs[i].IOR, smoothBlend.y);
    }
        return res;
}

ObjData raytraceScene(float3 ro, float3 rd)
{
    ObjData res = makeEmptyObjData();
    res.isRT = 1;
    res.RTinfo.dist = 1e20; // Start with max distance

    RTrayinfo tempInfo = makeEmptyRTrayinfo();

                // Back wall
    float3 center = float3(0, 0, 1.5);
    float3 rad = float3(1.5, 1.5, 1e-4);
    if (box_intersect(ro, rd, tempInfo, center, rad))
    {
        if (tempInfo.dist < res.RTinfo.dist)
        {
            res.RTinfo = tempInfo;
            res.color = float3(1, 1, 1);
        }
    }
    
                // Floor
    center = float3(0, -1.5, 0);
    rad = float3(1.5, 1e-4, 1.5);
    if (box_intersect(ro, rd, tempInfo, center, rad))
    {
        if (tempInfo.dist < res.RTinfo.dist)
        {
            res.RTinfo = tempInfo;
            res.color = float3(1, 1, 1);
        }
    }
    
                // Ceiling
    center = float3(0, 1.5, 0);
    rad = float3(1.5, 1e-4, 1.5);
    if (box_intersect(ro, rd, tempInfo, center, rad))
    {
        if (tempInfo.dist < res.RTinfo.dist)
        {
            res.RTinfo = tempInfo;
            res.color = float3(1, 1, 1);
        }
    }

    /*
    center = float3(0, 1.49, 0);
    rad = float3(0.5, 1e-4, 0.5);
    if (box_intersect(ro, rd, tempInfo, center, rad))
    {
        if (tempInfo.dist < res.RTinfo.dist)
        {
            res.RTinfo = tempInfo;
            res.color = float3(0.0, 0.0, 0.0);
            res.emission = float3(5.0, 5.0, 5.0);
            res.specCol = float3(1.0, 1.0, 1.0);
        }
    }*/
    
                // Left wall (red)
    center = float3(-1.5, 0, 0);
    rad = float3(0, 1.5, 1.5);
    if (box_intersect(ro, rd, tempInfo, center, rad))
    {
        if (tempInfo.dist < res.RTinfo.dist)
        {
            res.RTinfo = tempInfo;
            res.color = float3(1, 0, 0);
            res.pSpec = 0.0;
        }
    }
    
                // Right wall (green)
    center = float3(1.5, 0, 0);
    rad = float3(1e-4, 1.5, 1.5);
    if (box_intersect(ro, rd, tempInfo, center, rad))
    {
        if (tempInfo.dist < res.RTinfo.dist)
        {
            res.RTinfo = tempInfo;
            res.color = float3(0, 1, 0);
            res.pSpec = 0.0;
        }
    }

    return res;
}

#endif