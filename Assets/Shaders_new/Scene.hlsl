#ifndef SCENE_HLSL
#define SCENE_HLSL

#include "GeometryFuncs.hlsl"
#include "Common.hlsl"
#include "Utils.hlsl"

obj_data map(float3 p, bool keep_light) {
    int sdf_cnt = 8;
    obj_data sdfs_arr[8];
    
    // --- Cornell Box Walls ---
    obj_data floor_obj = make_empty_obj_data();
    floor_obj.sdf = sdfBox(p, float3(0.0, -0.5, 0.0), float3(1.0, 0.01, 1.0));
    floor_obj.color = float3(0.8, 0.8, 0.8);
    floor_obj.spec_col = float3(0.8, 0.8, 0.8);
    
    obj_data ceiling_obj = make_empty_obj_data();
    ceiling_obj.sdf = sdfBox(p, float3(0.0, 1.5, 0.0), float3(1.0, 0.01, 1.0));
    ceiling_obj.color = float3(0.8, 0.8, 0.8);
    ceiling_obj.spec_col = float3(0.8, 0.8, 0.8);
    
    obj_data back_wall = make_empty_obj_data();
    back_wall.sdf = sdfBox(p, float3(0.0, 0.5, -1.0), float3(1.0, 1.0, 0.01));
    back_wall.color = float3(0.8, 0.8, 0.8);
    back_wall.spec_col = float3(0.8, 0.8, 0.8);
    
    obj_data left_wall = make_empty_obj_data();
    left_wall.sdf = sdfBox(p, float3(-1.0, 0.5, 0.0), float3(0.01, 1.0, 1.0));
    left_wall.color = float3(0.8, 0.2, 0.2); // red
    left_wall.spec_col = float3(0.8, 0.2, 0.2);
    
    obj_data right_wall = make_empty_obj_data();
    right_wall.sdf = sdfBox(p, float3(1.0, 0.5, 0.0), float3(0.01, 1.0, 1.0));
    right_wall.color = float3(0.2, 0.8, 0.2); // green
    right_wall.spec_col = float3(0.2, 0.8, 0.2);

    // --- Objects ---
    obj_data sphere_1 = make_empty_obj_data();
    sphere_1.sdf = sdfSphere(p, _Sphere1, 0.3);
    sphere_1.color = float3(1.0, 0.0, 0.0);
    sphere_1.p_spec = 0.5;
    sphere_1.spec_col = float3(1.0, 0.0, 0.0);
    sphere_1.roughness = 0.0;
    sphere_1.IOR = 1.5;
    
    obj_data sphere_2 = make_empty_obj_data();
    sphere_2.sdf = sdfSphere(p, _Sphere2, 0.3);
    sphere_2.color = float3(0.0, 0.0, 1.0);
    sphere_2.p_spec = 1.0;
    sphere_2.spec_col = float3(0.0, 0.0, 1.0);
    sphere_2.roughness = 0.5;
    sphere_2.IOR = 1.5;
    
    obj_data light_sphere = make_empty_obj_data();
    light_sphere.sdf = sdfSphere(p, float3(0.0, 1.3, 0.0), 0.2);
    light_sphere.emission = float3(5.0, 5.0, 5.0);
    
    light.emission = light_sphere.emission;
    light.pos = float3(0.0, 1.3, 0.0);
    light.rad = 0.2;
    
    sdfs_arr[0] = floor_obj;
    sdfs_arr[1] = ceiling_obj;
    sdfs_arr[2] = back_wall;
    sdfs_arr[3] = left_wall;
    sdfs_arr[4] = right_wall;
    sdfs_arr[5] = sphere_1;
    sdfs_arr[6] = sphere_2;
    sdfs_arr[7] = light_sphere;
    
    obj_data result = sdfs_arr[0];
    
    for (int i = 1; i < sdf_cnt; i++) {
        
        if (length(sdfs_arr[i].emission) > 0.0) {// should cleanup
            if (!keep_light) {
                continue;
            }
            if (sdfs_arr[i].sdf < result.sdf) {
                result = sdfs_arr[i];
                continue;
            }
            continue;
        }
        float2 sblend = smin(result.sdf, sdfs_arr[i].sdf, _Smoothing);
        
        result.sdf = sblend.x;
        result.color = lerp(result.color, sdfs_arr[i].color, sblend.y);
        result.p_spec = lerp(result.p_spec, sdfs_arr[i].p_spec, sblend.y);
        result.roughness = lerp(result.roughness, sdfs_arr[i].roughness, sblend.y);
        result.spec_col = lerp(result.spec_col, sdfs_arr[i].spec_col, sblend.y);
        result.IOR = lerp(result.IOR, sdfs_arr[i].IOR, sblend.y);
    }
    
    return result;
}

float3 estimateNormal(float3 p) {
    float e = 0.0005;
    float3 n = float3(
                    map(p + float3(e, 0, 0), true).sdf - map(p - float3(e, 0, 0), true).sdf,
                    map(p + float3(0, e, 0), true).sdf - map(p - float3(0, e, 0), true).sdf,
                    map(p + float3(0, 0, e), true).sdf - map(p - float3(0, 0, e), true).sdf
                );
    return normalize(n);
}

bool isVisible(float3 pos, float3 dest, inout uint sample_rng) {
    float3 sd = normalize(dest - pos);
    float3 so = pos + sd * 0.01;
    float dist = length(dest - pos);
    float t = 0.0;
    
    for (int i = 0; i < 64; i++) {
        if (t >= dist)
            return true;
        
        float3 p = so + sd * t;
        obj_data hit = map(p, false);
        
        if (hit.sdf < 0.0001)
            return false;

        t += hit.sdf;

    }
    return true;
}
#endif