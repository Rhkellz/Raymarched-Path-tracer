#ifndef GEO_HLSL
#define GEO_HLSL

#include "Common.hlsl"
#include "Utils.hlsl"

//most of these from IQ
float sdfSphere(float3 p, float3 center, float rad) {
    return length(center - p) - rad;
}

float sdfBox(float3 p, float3 center, float3 size) {
    float3 d = abs(p - center) - size;
    return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}

float2 smin(float a, float b, float k) {
    float h = 1.0 - min(abs(a - b) / (4.0 * k), 1.0);
    float w = h * h;
    float m = w * 0.5;
    float s = w * k;
    return (a < b) ? float2(a - s, m) : float2(b - s, 1.0 - m);
}

float F(float3 p0) {
    float4 p = float4(p0.x, p0.y, p0.z, 1.0);
    for (int i = 0; i < 10; i++) {
        p.xyz = fmod(p.xyz - 1., 2.) - 1.;
        p *= 1.7 / dot(p.xyz, p.xyz);
    }
    return length(p.xz / p.w) * 0.25;
}

float de(float3 p) {
    return length(.05 * cos(9. * p.y * p.x) + cos(p) - .1 * cos(9. * (p.z + .3 * p.x - p.y))) - 1.;
}
#endif