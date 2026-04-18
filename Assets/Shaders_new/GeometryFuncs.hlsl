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

float3x3 rotateX(float angle) {
    float s = sin(angle), c = cos(angle);
    return float3x3(
        1, 0, 0,
        0, c, -s,
        0, s, c
    );
}

float3x3 rotateZ(float angle) {
    float s = sin(angle), c = cos(angle);
    return float3x3(
        c, -s, 0,
        s, c, 0,
        0, 0, 1
    );
}

float sdfTorus(float3 p, float2 t, float3 center, float angle) {
    float3 localP = mul(rotateZ(-70), mul(rotateX(angle), p - center));
    float2 q = float2(length(localP.xz) - t.x, localP.y);
    return length(q) - t.y;
}

float2 smin(float a, float b, float k) {
    float h = 1.0 - min(abs(a - b) / (4.0 * k), 1.0);
    float w = h * h;
    float m = w * 0.5;
    float s = w * k;
    return (a < b) ? float2(a - s, m) : float2(b - s, 1.0 - m);
}


float de1(float3 p) {
    return length(.05 * cos(9. * p.y * p.x) + cos(p) - .1 * cos(9. * (p.z + .3 * p.x - p.y))) - 1.;
}

float de3(float3 p, inout float3 fract_col) {
    float s = 2., l = 0.;
    p = abs(p);
    
    float sphere_trap = 1e10;
    float sphere_trap1 = 1e10;
    float sphere_trap2 = 1e10;
    
    for (int j = 0; j++ < 8;) {
        p = 1. - abs(abs(p - 2.) - 1.),
      p *= l = 1.2 / dot(p, p), s *= l;
        
        sphere_trap = min(sphere_trap, abs(length(p - _orbit_1) - _rad_1));
        sphere_trap1 = min(sphere_trap1, abs(length(p - _orbit_2) - _rad_2));
        sphere_trap2 = min(sphere_trap2, abs(length(p - _orbit_3) - _rad_3));
        
    }

    float w0 = exp(-_orbit_sharp * sphere_trap);
    float w1 = exp(-_orbit_sharp * sphere_trap1);
    float w2 = exp(-_orbit_sharp * sphere_trap2);
    float wSum = w0 + w1 + w2 + 1e-6;

    fract_col = (w0 * _color_1 + w1 * _color_2 + w2 * _color_3) / wSum;
    
    return dot(p, normalize(float3(3, -2, -1))) / s;
}

	

float de(float3 p0, inout float3 fract_col) {//menger-y
    float4 p = float4(p0 / 10., 1.);
    float sphere_trap = 1e10;
    float sphere_trap1 = 1e10;
    float sphere_trap2 = 1e10;

    //escape = 0.;
    p = abs(p);
    if (p.x < p.z)
        p.xz = p.zx;
    if (p.z < p.y)
        p.zy = p.yz;
    if (p.y < p.x)
        p.yx = p.xy;
    for (int i = 0; i < 6; i++) {
        if (p.x < p.z)
            p.xz = p.zx;
        if (p.z < p.y)
            p.zy = p.yz;
        if (p.y < p.x)
            p.yx = p.xy;
        p = abs(p);
        p *= (2. / clamp(dot(p.xyz, p.xyz), 0.1, 1.));
        p.xyz -= float3(0.9, 1.9, 0.9);
        
        sphere_trap = min(sphere_trap, abs(length(p - _orbit_1) - _rad_1));
        sphere_trap1 = min(sphere_trap1, abs(length(p - _orbit_2) - _rad_2));
        sphere_trap2 = min(sphere_trap2, abs(length(p - _orbit_3) - _rad_3));
    }
    float m = 1.5;
    p.xyz -= clamp(p.xyz, -m, m);
    
    float w0 = exp(-_orbit_sharp * sphere_trap);
    float w1 = exp(-_orbit_sharp * sphere_trap1);
    float w2 = exp(-_orbit_sharp * sphere_trap2);
    float wSum = w0 + w1 + w2 + 1e-6;

    fract_col = (w0 * _color_1 + w1 * _color_2 + w2 * _color_3) / wSum;
    
    return (length(p.xyz) / p.w) * 10.;
}

float de4(float3 p, inout float3 fract_col) {
    p.xz = abs(.5 - fmod(p.xz, 1.)) + .01;
    float DEfactor = 1.0;
    
    float sphere_trap = 1e10;
    float sphere_trap1 = 1e10;
    float sphere_trap2 = 1e10;
    
    for (int i = 0; i < 14; i++) {
        p = abs(p) - float3(0., 2., 0.);
        float r2 = dot(p, p);
        float sc = 2. / clamp(r2, 0.4, 1.);
        p *= sc;
        DEfactor *= sc;
        p = p - float3(0.5, 1., 0.5);
        
        sphere_trap = min(sphere_trap, abs(length(p - _orbit_1) - _rad_1));
        sphere_trap1 = min(sphere_trap1, abs(length(p - _orbit_2) - _rad_2));
        sphere_trap2 = min(sphere_trap2, abs(length(p - _orbit_3) - _rad_3));
    }
    
    float w0 = exp(-_orbit_sharp * sphere_trap);
    float w1 = exp(-_orbit_sharp * sphere_trap1);
    float w2 = exp(-_orbit_sharp * sphere_trap2);
    float wSum = w0 + w1 + w2 + 1e-6;

    fract_col = (w0 * _color_1 + w1 * _color_2 + w2 * _color_3) / wSum;
    
    return length(p) / DEfactor - .0005;
}

#endif