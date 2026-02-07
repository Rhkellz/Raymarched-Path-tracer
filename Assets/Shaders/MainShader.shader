Shader "Custom/PathTracing"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Cull Off ZWrite Off ZTest Always
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };
            
            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 viewVector : TEXCOORD1;
            };
            
            // float4x4 _CameraToWorld;
            float4x4 _CameraInverseProjection;
            float3 _Sphere1;
            float3 _Sphere2;
            int _SAMPLES;
            int _BOUNCES;
            int _FrameIndex;
            float _Smoothing;
            sampler2D _PreviousFrame;
            float _CurrentSample;
            int _UseAccumulation;
            int _Param;
            int _sceneMoving;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                
                // Calculate view ray direction
                float3 viewVector = mul(_CameraInverseProjection, float4(v.uv * 2 - 1, 0, -1));
                o.viewVector = mul(unity_CameraToWorld, float4(viewVector, 0));
                
                return o;
            }
            struct RTrayinfo {
                float dist;
                float3 normal;
                int didHit;
            };

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
            };

            float ScalarTriple(float3 u, float3 v, float3 w) {
                return dot(cross(u, v), w);
            }

            
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
                float r0 = (n1-n2) / (n1+n2);
                r0 *= r0;
                float cosX = -dot(normal, incident);
                if (n1 > n2)
                {
                    float n = n1/n2;
                    float sinT2 = n*n*(1.0-cosX*cosX);
                    // Total internal reflection
                    if (sinT2 > 1.0)
                        return f90;
                    cosX = sqrt(1.0-sinT2);
                }
                float x = 1.0-cosX;
                float ret = r0+(1.0-r0)*x*x*x*x*x;
 
                // adjust reflect multiplier for object reflectivity
                return lerp(f0, f90, ret);
            }

            // Cosine-weighted hemisphere sampling (BRDF)
            float3 getBRDF(float3 pos, float3 norm, float3 rd, inout uint rngState) {
                float u = frand(rngState);
                float v = frand(rngState);
    
                float denom = 1.0 + norm.z;
                if (abs(denom) < 0.001) {
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

            // Smooth minimum function
            float2 smin(float a, float b, float k) {
                float h = 1.0 - min(abs(a - b) / (6.0 * k), 1.0);
                float w = h * h * h;
                float m = w * 0.5;
                float s = w * k;
                return (a < b) ? float2(a - s, m) : float2(b - s, 1.0 - m);
            }

            // SDF Functions
            float sdfSphere(float3 p, float3 center, float rad) {
                return length(center - p) - rad;
            }
            
            float sdfBox(float3 p, float3 center, float3 size) {
                float3 d = abs(p - center) - size;
                return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
            }

            float sdfTorus( float3 p, float2 t ) {
              float2 q = float2(length(p.xz)-t.x,p.y);
              return length(q)-t.y;
            }

            //reinder
            bool box_intersect(float3 ro, float3 rd, out RTrayinfo info, float3 center, float3 rad) {
                info.dist = 1e20;
                info.normal = float3(0, 0, 0);
                info.didHit = 0;
                float3 m = 1.0 / rd;
                float3 n = m * (ro - center);
                float3 k = abs(m) * rad;
	
                float3 t1 = -n - k;
                float3 t2 = -n + k;

	            float tN = max(max( t1.x, t1.y ), t1.z );
	            float tF = min(min( t2.x, t2.y ), t2.z );
	
	            if( tN > tF || tF < 0.) return false;
    
                float t = tN < 0.001 ? tF : tN;
                if (t < 1e20 && t > 0.001) {//tmin, tmax
                    info.dist = t;
		            info.normal = -sign(rd)*step(t1.yzx,t1.xyz)*step(t1.zxy,t1.xyz);
                   
                    info.didHit = 1;
	                return true;
                } else {
                    info.didHit = 0;
                    return false;
                }
            }

            // Scene definition
            ObjData map(float3 p) {
                ObjData res;
    
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
    
                // Light Panel (emissive)
                ObjData lightPanel;
                lightPanel.sdf = sdfBox(p, float3(0.0, 0.74, 0.0), float3(0.25, 0.001, 0.25));
                lightPanel.color = float3(0.0, 0.0, 0.0);
                lightPanel.emission = float3(10.0, 10.0, 10.0);
                lightPanel.pSpec = 0.0;
                lightPanel.roughness = 0.0;
                lightPanel.specCol = float3(1.0, 1.0, 1.0);
                lightPanel.IOR = 1.0;

                float2 smoothBlend = smin(s1.sdf, s2.sdf, _Smoothing);
                res.sdf = smoothBlend.x;
                res.color = lerp(s1.color, s2.color, smoothBlend.y);
                res.emission = float3(0.0, 0.0, 0.0);
                res.pSpec = lerp(s1.pSpec, s2.pSpec, smoothBlend.y);
                res.roughness = lerp(s1.roughness, s2.roughness, smoothBlend.y);
                res.specCol = lerp(s1.specCol, s2.specCol, smoothBlend.y);
                res.IOR = lerp(s1.IOR, s2.IOR, smoothBlend.y);

                if (lightPanel.sdf < res.sdf)
                    res = lightPanel;

                res.isRT = 0;
                res.RTinfo.dist = 0;
                res.RTinfo.normal = float3(0, 0, 0);
                res.RTinfo.didHit = 0;
                return res;
            }

            // Normal estimation
            float3 estimateNormal(float3 p) {
                float e = 0.0005;
                float3 n = float3(
                    map(p + float3(e, 0, 0)).sdf - map(p - float3(e, 0, 0)).sdf,
                    map(p + float3(0, e, 0)).sdf - map(p - float3(0, e, 0)).sdf,
                    map(p + float3(0, 0, e)).sdf - map(p - float3(0, 0, e)).sdf
                );
                return normalize(n);
            }

            ObjData raytraceScene(float3 ro, float3 rd) {
                ObjData res;
                res.isRT = 1;
                res.RTinfo.didHit = 0;
                res.RTinfo.dist = 1e20;  // Start with max distance
                res.RTinfo.normal = float3(0, 0, 0);
                res.color = float3(1, 1, 1);
                res.emission = float3(0, 0, 0);
                res.pSpec = 0.0;
                res.roughness = 0.0;
                res.specCol = float3(1, 1, 1);
                res.IOR = 1.0;
                res.sdf = 0.0;

                RTrayinfo tempInfo;

                // Back wall
                float3 center = float3(0, 0, 0.75);
                float3 rad = float3(0.75, 0.75, 1e-4);
                if (box_intersect(ro, rd, tempInfo, center, rad)) {
                    if (tempInfo.dist < res.RTinfo.dist) {
                        res.RTinfo = tempInfo;
                        res.color = float3(1, 1, 1);
                    }
                }
    
                // Floor
                center = float3(0, -0.75, 0);
                rad = float3(0.75, 1e-4, 0.75);
                if (box_intersect(ro, rd, tempInfo, center, rad)) {
                    if (tempInfo.dist < res.RTinfo.dist) {
                        res.RTinfo = tempInfo;
                        res.color = float3(1, 1, 1);
                    }
                }
    
                // Ceiling
                center = float3(0, 0.75, 0);
                rad = float3(0.75, 1e-4, 0.75);
                if (box_intersect(ro, rd, tempInfo, center, rad)) {
                    if (tempInfo.dist < res.RTinfo.dist) {
                        res.RTinfo = tempInfo;
                        res.color = float3(1, 1, 1);
                    }
                }
    
                // Left wall (red)
                center = float3(-0.75, 0, 0);
                rad = float3(0, 0.75, 0.75);
                if (box_intersect(ro, rd, tempInfo, center, rad)) {
                    if (tempInfo.dist < res.RTinfo.dist) {
                        res.RTinfo = tempInfo;
                        res.color = float3(1, 1, 1);
                        res.pSpec = 1.0;
                    }
                }
    
                // Right wall (green)
                center = float3(0.75, 0, 0);
                rad = float3(1e-4, 0.75, 0.75);
                if (box_intersect(ro, rd, tempInfo, center, rad)) {
                    if (tempInfo.dist < res.RTinfo.dist) {
                        res.RTinfo = tempInfo;
                        res.color = float3(1, 1, 1);
                        res.pSpec = 1.0;
                    }
                }

                return res;
            }

            // Ray marching
            ObjData raymarch(float3 ro, float3 rd, inout float3 pos, inout int cnt) {
                pos = float3(0, 0, 0);
                
                ObjData RTdata = raytraceScene(ro, rd);
                float t = 0.0;
                for (int i = 0; i < 500; i++) {
                    cnt++;
                    float3 p = ro + rd * t;
                    ObjData d = map(p);
                    
                    if (d.sdf < 0.0005) {
                        if (RTdata.RTinfo.didHit == 1 && RTdata.RTinfo.dist < t) {
                            pos = ro + rd * RTdata.RTinfo.dist;
                            RTdata.sdf = RTdata.RTinfo.dist;
                            return RTdata; 
                        }
                        pos = p;
                        d.sdf = t;
                        return d;
                    }
                    
                    t += d.sdf;
                    
                    if (t > 50) {
                        break;
                    }
                }

                //pos = ro + rd * 100.0;
                if (RTdata.RTinfo.didHit == 1) {
                    pos = ro + rd * RTdata.RTinfo.dist;
                    RTdata.sdf = RTdata.RTinfo.dist;  //set sdf so its not -1
                    return RTdata; 
                }
                // Return miss
                ObjData empty;
                empty.sdf = -1.0;
                empty.color = float3(0.0, 0.0, 0.0);
                empty.emission = float3(0.0, 0.0, 0.0);
                empty.pSpec = 0.0;
                empty.roughness = 0.0;
                empty.specCol = float3(0.0, 0.0, 0.0);
                return empty;
            }

            // Path tracing color calculation
            float3 calcColor(float3 ro, float3 rd, inout uint rngState, inout int cnt) {
                float3 totalCol = float3(0.0, 0.0, 0.0);
                
                for (int sample = 0; sample < _SAMPLES; sample++) {
                    uint sampleRng = rngState ^ (sample * 0x9E3779B9u);
                    float3 ro_ = ro;
                    float3 rd_ = rd;
                    float3 throughput = float3(1.0, 1.0, 1.0);
                    
                    for (int bounce = 0; bounce < _BOUNCES + 1; bounce++) {
                        float3 pos;
                        ObjData hit = raymarch(ro_, rd_, pos, cnt);
                        
                        //Ray missed
                        if (hit.sdf < 0.0) {
                            totalCol += throughput * float3(0.1, 0.1, 0.1);
                            break;
                        }

                        float3 normal;
                        if (hit.isRT == 1) {
                            normal = hit.RTinfo.normal;
                            if (dot(normal, rd_) > 0.0) {
                                normal = -normal;
                            }
                        } else {
                            normal = estimateNormal(pos);
                        }
                        
                        //Hit emissive surface
                        if (length(hit.emission) > 0.0) {
                            totalCol += throughput * hit.emission;
                            break;
                        }

                        float3 diffuse = getBRDF(pos, normal, rd_, sampleRng);

                        //Apply fresnel
                        
                        float specularChance = hit.pSpec;
                        if (specularChance > 0.0) {
                            specularChance = FresnelReflectAmount(1.0, hit.IOR, rd_, normal, hit.pSpec, 1.0);
                        }
                        float doSpecular = (frand(sampleRng) < specularChance) ? 1.0 : 0.0;

                        float rayProbability = (doSpecular == 1.0) ? specularChance : 1.0 - specularChance;
                        rayProbability = max(rayProbability, 0.001);


                        float3 specularRayDir = reflect(rd_, normal);
                        specularRayDir = normalize(lerp(specularRayDir, diffuse, hit.roughness * hit.roughness));
                        rd_ = lerp(diffuse, specularRayDir, doSpecular);

                        float cosTheta = max(dot(normal, rd_), 0.0);
                        throughput *= hit.color * cosTheta;
                        ro_ = pos + normal * 0.001;
                        throughput /= rayProbability;
                        //Russian roulette
                        float p = max(throughput.x, max(throughput.y, throughput.z));
        	            if (frand(sampleRng) > p) { break; }

        	            throughput *= 1.0 / p; 
                    }
                }
                
                return totalCol / float(_SAMPLES);
            }

            float4 frag (v2f i) : SV_Target {
                uint2 numPixels = _ScreenParams.xy;
				uint2 pixCoord = i.uv * numPixels;//stop redef later
				uint pixelIndex = pixCoord.y * numPixels.x + pixCoord.x;
				uint rngState = pixelIndex + _FrameIndex * 719393;
    
                // Add jittering for anti-aliasing
                float2 jitter = float2(frand(rngState), frand(rngState)) - 0.5;
                float2 pixelCoord = i.uv * _ScreenParams.xy; // uv to pixel coordinates
                float2 pixel = pixelCoord + jitter;
                float2 jitteredUV = pixel / _ScreenParams.xy; // back to UV
    
                // Recalculate view ray with jittered UV
                float3 viewVector = mul(_CameraInverseProjection, float4(jitteredUV * 2 - 1, 0, -1));
                float3 viewVectorWorld = mul(unity_CameraToWorld, float4(viewVector, 0));
    
                float3 ro = unity_CameraToWorld._m03_m13_m23;
                float3 rd = normalize(viewVectorWorld);
                int cnt = 0;
                float3 col = calcColor(ro, rd, rngState, cnt);

                if (_Param > 0) {
                    float3 testCol = (float(cnt) / 150).xxx;
                    if (cnt > 150) {
                        testCol = float3(1, 0, 1);
                    }
                    col = testCol;
                }

                if (_UseAccumulation > 0 && _CurrentSample > 0) {
                    float3 prev = tex2D(_PreviousFrame, i.uv).rgb;
                    float blend = 1.0 / (_CurrentSample + 1.0);
                    if (_sceneMoving == 1) {
                        blend = 1.0;
                    }
                    col = lerp(prev, col, blend);
                }
                
                return float4(col, 1.0);
                //TODO: sdf bounding boxes for raytracing, PBR, MIS, better pipeline for sdfs
            }
            ENDCG
        }
    }
}