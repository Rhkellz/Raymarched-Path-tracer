#ifndef SCENE_HLSL
#define SCENE_HLSL

#include "GeometryFuncs.hlsl"
#include "Common.hlsl"
#include "Utils.hlsl"

obj_data map(float3 p, bool keep_light) {
    int sdf_cnt = 3;
    obj_data sdfs_arr[3];
    float3 fract_col = float3(1.0, 1.0, 1.0);
    
    // --- Objects ---
    obj_data sphere_1 = make_empty_obj_data();
    sphere_1.sdf = de(p, fract_col); //sdfSphere(p, _Sphere1, 0.3);
    sphere_1.color = fract_col;
    sphere_1.p_spec = 0.5;
    sphere_1.spec_col = fract_col; //float3(1.0, 1.0, 1.0);
    sphere_1.roughness = 0.3;
    sphere_1.IOR = 1.0;
    
    obj_data torus = make_empty_obj_data();
    torus.sdf = sdfTorus(p, float2(0.018, 0.007), _Sphere2, 100);
    torus.color = float3(1.0, 0.5, 0.0);
    torus.p_spec = 1.0;
    torus.spec_col = float3(1.0, 1.0, 1.0);
    torus.roughness = 0.0;
    torus.IOR = 1.0;
    
    obj_data light_sphere = make_empty_obj_data();
    light_sphere.sdf = sdfSphere(p, _Sphere1, 0.1);
    light_sphere.emission = float3(4.0, 4.0, 4.0);
    
    light.emission = light_sphere.emission;
    light.pos = _Sphere1;
    light.rad = 0.1;
    
    sdfs_arr[0] = sphere_1;
    sdfs_arr[1] = torus;
    sdfs_arr[2] = light_sphere;

    
    obj_data result = sdfs_arr[0];
    
    for (int i = 1; i < sdf_cnt; i++) {
        
        if (length(sdfs_arr[i].emission) > 0.0) { // should cleanup
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
    
    for (int i = 0; i < 100; i++) {
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

float3 gradient(float3 p) {
    float3 e_1 = float3(1.0, 0.0, 0.0);
    float3 e_2 = float3(0.0, 1.0, 0.0);
    float3 e_3 = float3(0.0, 0.0, 1.0);
    
    return (float3(map(p + e_1 * epsilon, true).sdf,
                   map(p + e_2 * epsilon, true).sdf,
                   map(p + e_3 * epsilon, true).sdf)
          - float3(map(p - e_1 * epsilon, true).sdf,
                   map(p - e_2 * epsilon, true).sdf,
                   map(p - e_3 * epsilon, true).sdf)) / (2.0 * epsilon);
}

float local_lipschitz(float3 rd, segment seg, out obj_data d) {
    float result = -1.0;
    float3 p = seg.start;

    d = map(p, true); // return this for reuse later
    
    for (int i = 0; i <= _samples_per_segment; i++) {
        p = seg.start + (length(seg.end - seg.start) / float(_samples_per_segment)) * float(i) * rd;
        
        float coeff = abs(dot(gradient(p), rd));
        /*if (i == 0) {
            coeff = abs(dot(gradient(p, d.sdf, true), rd));
        } else {
            coeff = abs(dot(gradient(p, 0, false), rd));
        }*/
        
        result = max(result, coeff);
    }
    
    return clamp(result, 0.001, 1.0); // term is bounded above by 1.0
}
#endif