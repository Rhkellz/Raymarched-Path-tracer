#include "Structs.hlsl"
#ifndef GEO_HLSL
#define GEO_HLSL

//most of these from IQ
float sdfSphere(float3 p, float3 center, float rad) {
    return length(center - p) - rad;
}
            
float sdfBox(float3 p, float3 center, float3 size) {
    float3 d = abs(p - center) - size;
    return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}

float sdfTorus(float3 p, float2 t) {
    float2 q = float2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

float2 smin(float a, float b, float k) {
    float h = 1.0 - min(abs(a - b) / (4.0 * k), 1.0);
    float w = h * h;
    float m = w * 0.5;
    float s = w * k;
    return (a < b) ? float2(a - s, m) : float2(b - s, 1.0 - m);
}

//reinder
bool box_intersect(float3 ro, float3 rd, out RTrayinfo info, float3 center, float3 rad)
{
    info.dist = 1e20;
    info.normal = float3(0, 0, 0);
    info.didHit = 0;
    float3 m = 1.0 / rd;
    float3 n = m * (ro - center);
    float3 k = abs(m) * rad;
	
    float3 t1 = -n - k;
    float3 t2 = -n + k;

    float tN = max(max(t1.x, t1.y), t1.z);
    float tF = min(min(t2.x, t2.y), t2.z);
	
    if (tN > tF || tF < 0.)
        return false;
    
    float t = tN < 0.001 ? tF : tN;
    if (t < 1e20 && t > 0.001)
    { //tmin, tmax
        info.dist = t;
        info.normal = -sign(rd) * step(t1.yzx, t1.xyz) * step(t1.zxy, t1.xyz);
                   
        info.didHit = 1;
        return true;
    }
    else
    {
        info.didHit = 0;
        return false;
    }
}
#endif