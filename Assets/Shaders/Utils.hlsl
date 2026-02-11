#include "Structs.hlsl"
#include "GeometryFuncs.hlsl"
#include "Scene.hlsl"
#ifndef UTILS_HLSL
#define UTILS_HLSL
// https://www.shadertoy.com/view/XlGcRh
uint NextRandom(inout uint state) {
    state = state * 747796405u + 2891336453u;
    uint result = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    result = (result >> 22u) ^ result;
    return result;
}

float frand(inout uint state) {
    return float(NextRandom(state)) / 4294967295.0; // 2^32 - 1
}

//https://blog.demofox.org/2020/06/14/casual-shadertoy-path-tracing-3-fresnel-rough-refraction-absorption-orbit-camera/
float FresnelReflectAmount(float n1, float n2, float3 normal, float3 incident, float f0, float f90) {
                // Schlick aproximation
    float r0 = (n1 - n2) / (n1 + n2);
    r0 *= r0;
    float cosX = -dot(normal, incident);
    if (n1 > n2)
    {
        float n = n1 / n2;
        float sinT2 = n * n * (1.0 - cosX * cosX);
                    // Total internal reflection
        if (sinT2 > 1.0)
            return f90;
        cosX = sqrt(1.0 - sinT2);
    }
    float x = 1.0 - cosX;
    float ret = r0 + (1.0 - r0) * x * x * x * x * x;
 
                // adjust reflect multiplier for object reflectivity
    return lerp(f0, f90, ret);
}

// Lambertian BRDF
float3 getBRDF(float3 pos, float3 norm, float3 rd, inout uint rngState) {
    float u = frand(rngState);
    float v = frand(rngState);
    
    float denom = 1.0 + norm.z;
    if (abs(denom) < 0.001)
    {
                    // Degenerate case: normal pointing at (0,0,-1) or (0,0,1)
        float3 uu = float3(1.0, 0.0, 0.0);
        float3 vv = float3(0.0, 1.0, 0.0);
        float a = 6.2831853 * v;
        return normalize(sqrt(u) * (cos(a) * uu + sin(a) * vv) + sqrt(1.0 - u) * norm);
    }
    
                // Build tangent space basis
    float3 tc = float3(1.0 + norm.z - norm.xy * norm.xy, -norm.x * norm.y) / denom;
    float3 uu = float3(tc.x, tc.z, -norm.x);
    float3 vv = float3(tc.z, tc.y, -norm.y);
    
    float a = 6.2831853 * v;
    return normalize(sqrt(u) * (cos(a) * uu + sin(a) * vv) + sqrt(1.0 - u) * norm);
}

float3 estimateNormal(float3 p) {
    float e = 0.0005;
    float3 n = float3(
                    map(p + float3(e, 0, 0)).sdf - map(p - float3(e, 0, 0)).sdf,
                    map(p + float3(0, e, 0)).sdf - map(p - float3(0, e, 0)).sdf,
                    map(p + float3(0, 0, e)).sdf - map(p - float3(0, 0, e)).sdf
                );
    return normalize(n);
}
#endif