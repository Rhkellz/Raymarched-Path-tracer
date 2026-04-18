#ifndef UTILS_HLSL
#define UTILS_HLSL
#include "Common.hlsl"


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

// or createLocalCoord
void buildOrthonormalBasis(float3 norm, inout float3 tangent, inout float3 bitangent) {
    float denom = 1.0 + norm.z;
    
    if (abs(denom) < 0.001) {
        // Degenerate case
        tangent = float3(1.0, 0.0, 0.0);
        bitangent = float3(0.0, 1.0, 0.0);
    } else {
        float3 tc = float3(1.0 + norm.z - norm.xy * norm.xy, -norm.x * norm.y) / denom;
        tangent = float3(tc.x, tc.z, -norm.x);
        bitangent = float3(tc.z, tc.y, -norm.y);
    }
}

// Samples a direction on the hemisphere with cosine-weighted distribution
float3 uniform_random_PSA(float3 norm, inout uint rngState) {
    float u = frand(rngState);
    float v = frand(rngState);
    
    float3 tangent = float3(0.0, 0.0, 0.0); // initialize first
    float3 bitangent = float3(0.0, 0.0, 0.0); // initialize first
    buildOrthonormalBasis(norm, tangent, bitangent);
    
    float a = 6.2831853 * v;
    float r = sqrt(u);
    
    float3 direction = r * cos(a) * tangent +
                       r * sin(a) * bitangent +
                       sqrt(1.0 - u) * norm;
    
    return normalize(direction);
}

float3 eval_diffuse_BRDF(obj_data hit, float3 n, float3 o, float3 i) {
    return hit.color / PI;
}

void sample_diffuse_BRDF(float3 n, float3 o, inout float3 i, inout float pdf, inout uint rng_state) {// make new random dir and give pdf
    i = uniform_random_PSA(n, rng_state);
    float cosTheta_i = dot(i, n);
    pdf = max(cosTheta_i / PI, 0.0001);
}

float diffuse_BRDF(float3 n, float3 w_i) {// pdf of a given dir
    return max(dot(n, w_i), 0.0) / PI;
}

float3 sampleLight(light_data light, inout float pdf, inout uint sampleRng) {// pdf is area measure
    float xi_1 = frand(sampleRng);
    float xi_2 = frand(sampleRng);
    
    float z = 2 * xi_1 - 1;
    float x = sqrt(1 - z * z) * cos(2 * PI * xi_2);
    float y = sqrt(1 - z * z) * sin(2 * PI * xi_2);
    
    float3 coords = float3(x, y, z);
    pdf = 1.0 / (4.0 * PI * light.rad * light.rad);
    return light.pos - coords * light.rad;
}

//https://blog.demofox.org/2020/06/14/casual-shadertoy-path-tracing-3-fresnel-rough-refraction-absorption-orbit-camera/
float FresnelReflectAmount(float n1, float n2, float3 normal, float3 incident, float f0, float f90) {
                // Schlick aproximation
    float r0 = (n1 - n2) / (n1 + n2);
    r0 *= r0;
    float cosX = -dot(normal, incident);
    if (n1 > n2) {
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

float2 random_point_on_circle(inout uint sample_rng) {
    float a = frand(sample_rng);
    float b = frand(sample_rng);
    
    a = sqrt(a);
    b = 2 * PI * b;
    return float2(a * cos(b), a * sin(b));
}
#endif