#ifdef GL_ES
precision highp float;
#endif

uniform vec2 u_resolution;
uniform float u_time;

#define PI 3.14159265359
#define HALF_W 1.42
#define FLOOR_Y -1.18
#define CEIL_Y  1.24
#define FAR_T   80.0
#define REFLECTION_SAMPLES 9
#define VOLUME_STEPS 12

float saturate(float x) { return clamp(x, 0.0, 1.0); }
vec3 saturate3(vec3 x) { return clamp(x, vec3(0.0), vec3(1.0)); }
vec3 getFogColor();
vec3 applyFog(vec3 col, float dist, vec3 ro, vec3 rd);

mat2 rot(float a) {
    float s = sin(a), c = cos(a);
    return mat2(c, -s, s, c);
}

float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

float hash21(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
    float n = hash21(p);
    return vec2(n, hash21(p + n + 17.13));
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    mat2 m = mat2(0.8, 0.6, -0.6, 0.8);
    for (int i = 0; i < 5; i++) {
        v += noise(p) * a;
        p = m * p * 2.02;
        a *= 0.52;
    }
    return v;
}

float rectMask(vec2 p, vec2 b, float feather) {
    vec2 d = abs(p) - b;
    return 1.0 - smoothstep(-feather, feather, max(d.x, d.y));
}

float lineMask(vec2 p, vec2 a, vec2 b, float w) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
    return 1.0 - smoothstep(w, w + 0.012, length(pa - ba * h));
}

float lineRepeat(float x, float period, float width, float feather) {
    float f = fract(x / period);
    return 1.0 - smoothstep(width, width + feather, min(f, 1.0 - f) * period);
}

float circleMask(vec2 p, float r, float feather) {
    return 1.0 - smoothstep(r, r + feather, length(p));
}

// ------------------------------------------------------------
// Scene / trace
// IDs:
// 1 floor, 2 left wall, 3 right wall, 4 ceiling
// 5 left pipe, 6 right pipe, 7 center conduit
// ------------------------------------------------------------
float traceCylinderZ(vec3 ro, vec3 rd, vec2 c, float r) {
    vec2 oc = ro.xy - c;
    float a = dot(rd.xy, rd.xy);
    if (a < 1e-6) return -1.0;
    float b = 2.0 * dot(oc, rd.xy);
    float cc = dot(oc, oc) - r * r;
    float h = b * b - 4.0 * a * cc;
    if (h < 0.0) return -1.0;
    h = sqrt(h);

    float t1 = (-b - h) / (2.0 * a);
    float t2 = (-b + h) / (2.0 * a);

    if (t1 > 0.0) return t1;
    if (t2 > 0.0) return t2;
    return -1.0;
}

vec2 traceScene(vec3 ro, vec3 rd) {
    float bestT = FAR_T;
    float bestID = 0.0;

    float t;

    t = traceCylinderZ(ro, rd, vec2(-0.82, 1.00), 0.050);
    if (t > 0.0 && t < bestT) { bestT = t; bestID = 5.0; }

    t = traceCylinderZ(ro, rd, vec2(0.70, 1.01), 0.042);
    if (t > 0.0 && t < bestT) { bestT = t; bestID = 6.0; }

    t = traceCylinderZ(ro, rd, vec2(0.08, 0.95), 0.024);
    if (t > 0.0 && t < bestT) { bestT = t; bestID = 7.0; }

    if (abs(rd.y) > 1e-5) {
        float tf = (FLOOR_Y - ro.y) / rd.y;
        if (tf > 0.0 && tf < bestT && rd.y < 0.0) {
            vec3 p = ro + rd * tf;
            if (abs(p.x) <= HALF_W) { bestT = tf; bestID = 1.0; }
        }

        float tc = (CEIL_Y - ro.y) / rd.y;
        if (tc > 0.0 && tc < bestT && rd.y > 0.0) {
            vec3 p = ro + rd * tc;
            if (abs(p.x) <= HALF_W) { bestT = tc; bestID = 4.0; }
        }
    }

    if (abs(rd.x) > 1e-5) {
        float tl = (-HALF_W - ro.x) / rd.x;
        if (tl > 0.0 && tl < bestT && rd.x < 0.0) {
            vec3 p = ro + rd * tl;
            if (p.y >= FLOOR_Y && p.y <= CEIL_Y) { bestT = tl; bestID = 2.0; }
        }

        float tr = (HALF_W - ro.x) / rd.x;
        if (tr > 0.0 && tr < bestT && rd.x > 0.0) {
            vec3 p = ro + rd * tr;
            if (p.y >= FLOOR_Y && p.y <= CEIL_Y) { bestT = tr; bestID = 3.0; }
        }
    }

    return bestT < FAR_T ? vec2(bestT, bestID) : vec2(-1.0, 0.0);
}

void surfaceData(float id, vec3 p, out vec3 n0, out vec3 t, out vec3 b, out vec2 uv) {
    if (id < 1.5) {
        n0 = vec3(0.0, 1.0, 0.0);
        t  = vec3(1.0, 0.0, 0.0);
        b  = vec3(0.0, 0.0, 1.0);
        uv = p.xz;
    } else if (id < 2.5) {
        n0 = vec3(1.0, 0.0, 0.0);
        t  = vec3(0.0, 0.0, 1.0);
        b  = vec3(0.0, 1.0, 0.0);
        uv = vec2(p.z, p.y);
    } else if (id < 3.5) {
        n0 = vec3(-1.0, 0.0, 0.0);
        t  = vec3(0.0, 0.0, 1.0);
        b  = vec3(0.0, 1.0, 0.0);
        uv = vec2(p.z, p.y);
    } else if (id < 4.5) {
        n0 = vec3(0.0, -1.0, 0.0);
        t  = vec3(1.0, 0.0, 0.0);
        b  = vec3(0.0, 0.0, 1.0);
        uv = p.xz;
    } else {
        vec2 c = vec2(0.0);
        if (id < 5.5) c = vec2(-0.82, 1.00);
        else if (id < 6.5) c = vec2(0.70, 1.01);
        else c = vec2(0.08, 0.95);

        n0 = normalize(vec3(p.x - c.x, p.y - c.y, 0.0));
        t = vec3(0.0, 0.0, 1.0);
        b = normalize(cross(t, n0));
        uv = vec2(atan(p.y - c.y, p.x - c.x), p.z);
    }
}

// ------------------------------------------------------------
// Door + sign details
// ------------------------------------------------------------
float letterE(vec2 p) {
    float m = lineMask(p, vec2(-0.10,-0.50), vec2(-0.10,0.50), 0.05);
    m = max(m, lineMask(p, vec2(-0.10,0.50), vec2(0.15,0.50), 0.05));
    m = max(m, lineMask(p, vec2(-0.10,0.00), vec2(0.10,0.00), 0.05));
    m = max(m, lineMask(p, vec2(-0.10,-0.50), vec2(0.15,-0.50), 0.05));
    return m;
}
float letterX(vec2 p) {
    float m = lineMask(p, vec2(-0.12,-0.50), vec2(0.12,0.50), 0.05);
    return max(m, lineMask(p, vec2(-0.12,0.50), vec2(0.12,-0.50), 0.05));
}
float letterI(vec2 p) {
    float m = lineMask(p, vec2(0.0,-0.50), vec2(0.0,0.50), 0.05);
    m = max(m, lineMask(p, vec2(-0.10,0.50), vec2(0.10,0.50), 0.05));
    return max(m, lineMask(p, vec2(-0.10,-0.50), vec2(0.10,-0.50), 0.05));
}
float letterT(vec2 p) {
    float m = lineMask(p, vec2(-0.15,0.50), vec2(0.15,0.50), 0.05);
    return max(m, lineMask(p, vec2(0.0,-0.50), vec2(0.0,0.50), 0.05));
}
float exitText(vec2 p) {
    float m = letterE(p - vec2(-0.65,0.0));
    m = max(m, letterX(p - vec2(-0.20,0.0)));
    m = max(m, letterI(p - vec2(0.20,0.0)));
    return saturate(max(m, letterT(p - vec2(0.58,0.0))));
}

void doorFeatures(
    float sideIdx, vec2 uv,
    out float panel, out float frame, out float window,
    out float handle, out float kickplate,
    out float signBox, out float signGlow
) {
    float period = 3.6;
    float cell = floor(uv.x / period + 0.5);
    float localZ = uv.x - cell * period;
    float seed = hash11(cell * 7.13 + sideIdx * 13.7);
    float hasDoor = step(0.24, seed);

    vec2 dp = vec2(localZ, uv.y - (FLOOR_Y + 0.56));
    float outer = rectMask(dp, vec2(0.43, 0.57), 0.01);
    float inner = rectMask(dp, vec2(0.37, 0.51), 0.01);

    frame = hasDoor * max(outer - inner, 0.0);
    panel = hasDoor * inner;

    float hasWindow = hasDoor * step(0.54, hash11(cell * 11.7 + sideIdx * 5.3));
    window = hasWindow * rectMask(vec2(localZ, uv.y - (FLOOR_Y + 0.90)), vec2(0.12, 0.08), 0.008);

    float handleSide = mix(0.23, -0.23, step(0.5, hash11(cell * 9.71)));
    vec2 hp = vec2(localZ - handleSide, uv.y - (FLOOR_Y + 0.56));
    handle = hasDoor * rectMask(hp, vec2(0.018, 0.055), 0.006);
    handle = max(handle, hasDoor * lineMask(hp, vec2(0.0,0.0), vec2(0.065 * sign(handleSide), -0.014), 0.012));

    kickplate = hasDoor * rectMask(vec2(localZ, uv.y - (FLOOR_Y + 0.09)), vec2(0.30, 0.06), 0.008);

    float hasSign = hasDoor * step(0.52, hash11(cell * 3.73 + sideIdx * 19.1));
    signBox = hasSign * rectMask(vec2(localZ, uv.y - (FLOOR_Y + 1.13)), vec2(0.28, 0.085), 0.006);

    vec2 textP = vec2((localZ + 0.02) / 0.22, (uv.y - (FLOOR_Y + 1.13)) / 0.060);
    signGlow = signBox * exitText(textP);
}

// ------------------------------------------------------------
// Ceiling fixtures / grime
// ------------------------------------------------------------
float fixtureBrightness(float cell) {
    float broken = step(0.86, hash11(cell * 4.91));
    float unstable = step(0.62, hash11(cell * 8.21)) * (1.0 - broken);

    float t1 = sin(u_time * 18.0 + cell * 7.0);
    float t2 = sin(u_time * 41.0 + cell * 13.0);

    float buzz = 0.97 + 0.03 * t1 * t2;
    float flicker = mix(1.0, 0.45 + 0.55 * step(0.12, t1), unstable);

    return (1.0 - broken) * buzz * flicker;
}

float fixtureSwing(float cell) {
    return step(0.78, hash11(cell * 6.31)) *
    sin(u_time * (0.7 + hash11(cell * 2.1) * 0.4) + cell * 1.7) * 0.028;
}

void ceilingFixture(vec2 uv, out float housing, out float diffuser, out float glow) {
    float period = 3.6;
    float cell = floor(uv.y / period + 0.5);
    float localZ = uv.y - cell * period;
    vec2 q = vec2(uv.x - fixtureSwing(cell), localZ);

    housing = rectMask(q, vec2(0.27, 0.56), 0.012);
    diffuser = housing * rectMask(q, vec2(0.205, 0.495), 0.008);

    float tubes =
    max(rectMask(vec2(q.x - 0.05, q.y), vec2(0.036, 0.425), 0.006),
        rectMask(vec2(q.x + 0.05, q.y), vec2(0.036, 0.425), 0.006));

    glow = diffuser * tubes * fixtureBrightness(cell);
}

float ceilingCableMask(vec2 uv) {
    float x1 = -0.22 + sin(uv.y * 0.70) * 0.030 + fbm(vec2(uv.y * 0.12, 3.2)) * 0.015;
    float x2 =  0.31 + sin(uv.y * 0.55 + 1.6) * 0.022 + fbm(vec2(uv.y * 0.10, 8.1)) * 0.012;

    float c1 = 1.0 - smoothstep(0.006, 0.016, abs(uv.x - x1));
    float c2 = 1.0 - smoothstep(0.005, 0.014, abs(uv.x - x2));

    float bracket1 = lineRepeat(uv.y + 0.18, 1.35, 0.028, 0.020);
    float bracket2 = lineRepeat(uv.y - 0.33, 1.60, 0.028, 0.020);

    c1 *= 0.78 + 0.22 * bracket1;
    c2 *= 0.78 + 0.22 * bracket2;
    return saturate(max(c1, c2));
}

float floorWet(vec2 uv) {
    float broad = smoothstep(0.36, 0.76, fbm(uv * 0.22 + vec2(4.1, -1.7)));
    float micro = smoothstep(0.52, 0.86, fbm(uv * 1.25 + vec2(-3.2, 5.1)));
    float wet = 0.16 + broad * 0.26 + micro * 0.10;

    float period = 3.6;
    float cell = floor(uv.y / period + 0.5);
    float leakX = hash11(cell * 5.3) * 0.9 - 0.45;
    float d = abs(uv.y - cell * period);
    float puddle = exp(-d * 0.95) * exp(-pow((uv.x - leakX) * 1.65, 2.0));
    puddle *= step(0.40, hash11(cell * 9.17));
    puddle *= 0.55 + 0.45 * fbm(uv * 1.7 + cell * 1.73);

    wet += puddle * 0.55;
    wet += exp(-(HALF_W - abs(uv.x)) * 4.0) * 0.08;

    return saturate(wet);
}

float floorStains(vec2 uv) {
    float stain = 0.0;
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        vec2 c = vec2(hash11(fi * 7.3) * 1.8 - 0.9,
                      hash11(fi * 11.2 + 3.0) * 24.0);

        vec2 d = uv - c;
        float r = 0.09 + hash11(fi * 3.7) * 0.25;
        float blob = length(d / r);
        blob += fbm(d * 3.0 + fi * 4.1) * 0.35;
        stain = max(stain, smoothstep(1.15, 0.62, blob) * (0.20 + 0.18 * hash11(fi * 9.1)));
    }

    float traffic = smoothstep(0.18, 0.82, fbm(vec2(uv.x * 2.0, uv.y * 0.30 + 6.0)));
    stain = max(stain, exp(-uv.x * uv.x * 1.5) * traffic * 0.16);
    stain = max(stain, exp(-(HALF_W - abs(uv.x)) * 2.0) * (0.30 + 0.55 * fbm(uv * 1.2)) * 0.24);

    return saturate(stain);
}

float floorScuffs(vec2 uv) {
    float s0 = lineRepeat(uv.x + uv.y * 0.16 + fbm(uv * 3.0) * 0.04, 0.40, 0.004, 0.003);
    float s1 = lineRepeat(uv.x * 0.65 - uv.y * 0.10 + fbm(uv * 4.0) * 0.03, 0.58, 0.003, 0.0025);
    float traffic = exp(-uv.x * uv.x * 1.25);
    return saturate((s0 * 0.6 + s1 * 0.4) * traffic * 0.30);
}

float wallGrime(vec2 uv) {
    float lowBand = 1.0 - smoothstep(FLOOR_Y + 0.12, FLOOR_Y + 0.70, uv.y);
    float drips = smoothstep(FLOOR_Y + 0.70, CEIL_Y - 0.08, uv.y);
    drips *= 1.0 - smoothstep(FLOOR_Y + 1.10, CEIL_Y - 0.04, uv.y);

    float run = fbm(vec2(uv.x * 0.22, uv.y * 3.2));
    float scuff = smoothstep(0.72, 0.92, fbm(uv * 10.0 + vec2(1.4, -2.8)));

    return saturate(lowBand * 0.45 + drips * run * 0.18 + scuff * lowBand * 0.22);
}

float ceilingStains(vec2 uv) {
    float stain = 0.0;
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        vec2 c = vec2(hash11(fi * 13.3 + 5.0) * 1.4 - 0.7,
                      hash11(fi * 9.2 + 7.0) * 20.0);

        float r = 0.24 + hash11(fi * 5.7) * 0.36;
        float d = length((uv - c) / r) + fbm(uv * 1.8 + fi * 3.0) * 0.2;
        stain = max(stain, smoothstep(1.1, 0.5, d) * 0.42);
    }
    return stain;
}

// ------------------------------------------------------------
// Height / normals
// ------------------------------------------------------------
float heightMap(float id, vec2 uv) {
    if (id < 1.5) {
        float grout = max(lineRepeat(uv.x, 0.62, 0.012, 0.008),
                          lineRepeat(uv.y, 0.62, 0.012, 0.008));
        vec2 tileID = floor(uv / 0.62);

        float tileWarp = fbm(uv * 1.8) * 0.0022;
        float micro = fbm(uv * 9.0 + tileID * 0.3) * 0.0035 + fbm(uv * 38.0) * 0.0015;
        float scuff = floorScuffs(uv) * 0.008;
        return (hash21(tileID) - 0.5) * 0.004 + tileWarp + micro - grout * 0.030 - scuff;
    } else if (id < 3.5) {
        float sideIdx = (id < 2.5) ? 0.0 : 1.0;
        float panel, frame, window, handle, kickplate, signBox, signGlow;
        doorFeatures(sideIdx, uv, panel, frame, window, handle, kickplate, signBox, signGlow);

        float trim = lineMask(uv, vec2(uv.x - 100.0, FLOOR_Y + 0.44), vec2(uv.x + 100.0, FLOOR_Y + 0.44), 0.012);
        float seam = lineRepeat(uv.x, 1.85, 0.008, 0.006) * 0.30;

        float h = fbm(uv * vec2(0.22, 3.2)) * 0.008 + fbm(uv * 14.0) * 0.0015;
        h += wallGrime(uv) * 0.0025;
        h += trim * 0.0035;
        h -= seam * 0.0025;

        h -= panel * 0.016;
        h += frame * 0.007;
        h += handle * 0.012;
        h += kickplate * 0.005;
        h += signBox * 0.004;

        return h;
    } else if (id < 4.5) {
        float panels = max(lineRepeat(uv.x, 0.92, 0.008, 0.008),
                           lineRepeat(uv.y, 1.1, 0.008, 0.008));
        float housing, diffuser, glow;
        ceilingFixture(uv, housing, diffuser, glow);
        float cable = ceilingCableMask(uv) * 0.006;
        return -panels * 0.012 - housing * 0.010 + diffuser * 0.002 + cable;
    } else {
        float seam = 1.0 - smoothstep(0.02, 0.07, abs(uv.x));
        float clampMask = lineRepeat(uv.y, 1.25, 0.030, 0.018);
        float rust = smoothstep(0.72, 0.96, fbm(vec2(uv.x * 3.0, uv.y * 0.35)));
        return seam * 0.002 + clampMask * 0.008 + rust * 0.002;
    }
}


float floorCenterFade(vec2 uv) {
    return exp(-abs(uv.x) * 2.2);
}

float floorTrafficMask(vec2 uv) {
    float lane = exp(-uv.x * uv.x * 1.20);
    float breakup = 0.70 + 0.30 * fbm(vec2(uv.y * 0.24, uv.x * 0.55 + 4.0));
    return lane * breakup;
}

vec2 floorFlowDir(vec2 uv) {
    float bend = (fbm(vec2(uv.y * 0.18, 1.7)) - 0.5) * 0.18;
    return normalize(vec2(0.08 + bend, 1.0));
}

vec2 floorFlowUV(vec2 uv) {
    vec2 f = floorFlowDir(uv);
    vec2 p = vec2(-f.y, f.x);
    return vec2(dot(uv, f), dot(uv, p));
}

vec3 getNormal(float id, vec3 p) {
    vec3 n0, t, b;
    vec2 uv;
    surfaceData(id, p, n0, t, b, uv);

    float e = 0.003;
    float h = heightMap(id, uv);
    vec2 grad = vec2(
        heightMap(id, uv + vec2(e, 0.0)) - h,
        heightMap(id, uv + vec2(0.0, e)) - h
    ) / e;

    vec3 n = normalize(n0 - t * grad.x * 1.6 - b * grad.y * 1.6);

    if (id < 1.5) {
        vec2 flow = floorFlowDir(uv);
        vec2 flowUV = floorFlowUV(uv);

        vec3 flowW = normalize(t * flow.x + b * flow.y);
        vec3 perpW = normalize(t * (-flow.y) + b * flow.x);

        float microA = fbm(vec2(flowUV.x * 28.0, flowUV.y * 9.0 + 3.1)) - 0.5;
        float microB = fbm(vec2(flowUV.x * 16.0 + 7.2, flowUV.y * 36.0)) - 0.5;

        vec3 microPerturb = flowW * (microA * 0.030) + perpW * (microB * 0.012);
        n = normalize(n + microPerturb);
    }

    return n;
}

// ------------------------------------------------------------
// Materials
// ------------------------------------------------------------
void getMaterial(float id, vec2 uv, vec3 p, out vec3 albedo, out float rough, out float refl, out vec3 emit) {
    emit = vec3(0.0);

    if (id < 1.5) {
        float grout = max(lineRepeat(uv.x, 0.62, 0.012, 0.008),
                          lineRepeat(uv.y, 0.62, 0.012, 0.008));

        float wet = floorWet(uv) * (1.0 - grout);
        float stain = floorStains(uv);
        float scuffs = floorScuffs(uv);

        vec2 tileID = floor(uv / 0.62);
        float checker = mod(tileID.x + tileID.y, 2.0);

        vec2 flowUV = floorFlowUV(uv);
        float traffic = floorTrafficMask(uv);
        float puddle = smoothstep(0.18, 0.92, wet + (fbm(vec2(flowUV.x * 0.8, flowUV.y * 2.4)) - 0.5) * 0.08);
        float wear = smoothstep(0.42, 0.86, fbm(vec2(flowUV.x * 7.0, flowUV.y * 1.2 + 2.4))) * traffic;

        vec3 base = mix(vec3(0.016, 0.018, 0.020), vec3(0.031, 0.033, 0.037), checker);
        base *= 0.84 + 0.16 * hash21(tileID);
        base *= 0.96 + 0.04 * fbm(uv * 18.0);

        base = mix(base, vec3(0.026, 0.020, 0.016), stain * 0.58);
        base -= vec3(0.0045) * wear;
        base -= vec3(0.0040) * scuffs;
        base *= 1.0 - floorCenterFade(uv) * 0.05 * (1.0 - puddle);
        base *= 1.0 - exp(-(HALF_W - abs(uv.x)) * 3.0) * 0.12;

        albedo = mix(base, vec3(0.009, 0.010, 0.011), grout * 0.97);
        albedo = mix(albedo, albedo * vec3(0.88, 0.92, 1.04), puddle * 0.10);

        rough = mix(0.62, 0.008, puddle);
        rough += stain * 0.10 + scuffs * 0.045 + wear * 0.08 + fbm(uv * 24.0) * 0.020;
        rough += floorCenterFade(uv) * 0.040 * (1.0 - puddle);
        rough = clamp(rough, 0.008, 0.90);

        refl = mix(0.04, 0.56, puddle);
    }
    else if (id < 3.5) {
        float sideIdx = (id < 2.5) ? 0.0 : 1.0;
        float panel, frame, window, handle, kickplate, signBox, signGlow;
        doorFeatures(sideIdx, uv, panel, frame, window, handle, kickplate, signBox, signGlow);

        float twoTone = smoothstep(FLOOR_Y + 0.42, FLOOR_Y + 0.48, p.y);
        float grime = wallGrime(uv);
        float trim = lineMask(uv, vec2(uv.x - 100.0, FLOOR_Y + 0.44), vec2(uv.x + 100.0, FLOOR_Y + 0.44), 0.015);
        float seam = lineRepeat(uv.x, 1.85, 0.010, 0.007);

        vec3 wall = mix(vec3(0.060, 0.063, 0.068), vec3(0.096, 0.100, 0.106), twoTone);
        wall *= 0.92 + 0.14 * fbm(uv * 0.28);
        wall *= 0.96 + 0.06 * fbm(uv * 9.0);

        wall = mix(wall, vec3(0.040, 0.041, 0.044), grime * 0.52);
        wall = mix(wall, vec3(0.050, 0.052, 0.055), trim * 0.28);
        wall = mix(wall, wall * 0.88, seam * 0.14);
        wall = mix(wall, vec3(0.050, 0.052, 0.055), smoothstep(0.02, 0.0, abs(uv.y - (FLOOR_Y + 0.08))) * 0.85);

        float doorSeed = hash11(floor(uv.x / 3.6) * 3.0 + sideIdx * 5.0);
        vec3 doorCol = mix(vec3(0.050, 0.056, 0.060), vec3(0.044, 0.050, 0.054), doorSeed);
        doorCol *= 0.90 + 0.16 * fbm(uv * 4.0 + doorSeed * 10.0);

        wall = mix(wall, doorCol, panel);
        wall = mix(wall, vec3(0.034, 0.036, 0.039), frame);

        vec3 glassCol = vec3(0.018, 0.020, 0.025);
        float wire = max(lineRepeat(uv.x * 15.0, 1.0, 0.03, 0.02),
                         lineRepeat(uv.y * 15.0, 1.0, 0.03, 0.02));
        wall = mix(wall, mix(glassCol, vec3(0.012, 0.014, 0.017), wire * 0.5), window);

        vec3 handleCol = vec3(0.64, 0.56, 0.36) * (0.88 + 0.14 * noise(uv * 50.0));
        wall = mix(wall, handleCol, handle);

        vec3 kickCol = vec3(0.56, 0.56, 0.54) * (0.94 + 0.08 * noise(vec2(uv.x * 40.0, uv.y * 2.0)));
        wall = mix(wall, kickCol, kickplate);

        wall = mix(wall, vec3(0.010, 0.012, 0.012), signBox * (1.0 - signGlow));

        albedo = wall;

        rough = 0.84;
        rough = mix(rough, 0.045, handle);
        rough = mix(rough, 0.08, window);
        rough = mix(rough, 0.075, kickplate);

        refl = 0.015;
        refl = mix(refl, 0.62, handle);
        refl = mix(refl, 0.22, window);
        refl = mix(refl, 0.48, kickplate);

        emit = signGlow * vec3(0.15, 1.05, 0.28) * 3.4;
        emit += signBox * (1.0 - signGlow) * vec3(0.010, 0.040, 0.014) * 0.24;
    }
    else if (id < 4.5) {
        float baseNoise = fbm(uv * 0.65);
        float panels = max(lineRepeat(uv.x, 0.92, 0.008, 0.008),
                           lineRepeat(uv.y, 1.1, 0.008, 0.008));
        float stain = ceilingStains(uv);
        float cable = ceilingCableMask(uv);

        vec3 ceil = vec3(0.128, 0.132, 0.138) * (0.92 + 0.14 * baseNoise) * (0.95 + 0.06 * fbm(uv * 8.0));
        ceil = mix(ceil, vec3(0.060, 0.062, 0.066), panels * 0.75);
        ceil = mix(ceil, vec3(0.092, 0.078, 0.060), stain * 0.45);
        ceil = mix(ceil, vec3(0.030, 0.032, 0.036), cable * 0.70);

        float housing, diffuser, glow;
        ceilingFixture(uv, housing, diffuser, glow);

        ceil = mix(ceil, vec3(0.042, 0.044, 0.047), housing);
        ceil = mix(ceil, vec3(0.58, 0.60, 0.62), diffuser * (1.0 - glow * 0.2));

        albedo = ceil;
        rough = mix(0.86, 0.48, diffuser);
        refl = 0.012;

        float cell = floor(uv.y / 3.6 + 0.5);
        float warmth = hash11(cell * 3.0) * 0.08;
        vec3 fluoCol = mix(vec3(0.80, 0.84, 0.79), vec3(0.88, 0.84, 0.76), warmth);

        emit = fluoCol * glow * 2.2;
        emit += fluoCol * 0.14 * diffuser * fixtureBrightness(cell);
    }
    else {
        float rust = smoothstep(0.68, 0.95, fbm(vec2(uv.y * 0.30, uv.x * 3.0)));
        float damp = smoothstep(0.46, 0.84, fbm(vec2(uv.y * 0.20 + 7.0, uv.x * 2.5)));
        float seam = 1.0 - smoothstep(0.015, 0.060, abs(uv.x));
        float clampMask = lineRepeat(uv.y, 1.25, 0.032, 0.018);

        vec3 pipeBase = mix(vec3(0.22, 0.23, 0.24), vec3(0.28, 0.29, 0.30), damp * 0.55);
        pipeBase = mix(pipeBase, vec3(0.18, 0.14, 0.10), rust * 0.35);
        pipeBase = mix(pipeBase, vec3(0.17, 0.17, 0.18), seam * 0.35);
        pipeBase = mix(pipeBase, vec3(0.14, 0.145, 0.15), clampMask * 0.50);

        albedo = pipeBase;
        rough = mix(0.24, 0.15, damp);
        rough += rust * 0.20;
        rough = clamp(rough, 0.10, 0.90);

        refl = mix(0.10, 0.18, damp);
    }
}

// ------------------------------------------------------------
// Lighting / shadows
// ------------------------------------------------------------
float D_GGX(float NoH, float rough) {
    float a = rough * rough;
    float a2 = a * a;
    float d = NoH * NoH * (a2 - 1.0) + 1.0;
    return a2 / max(PI * d * d, 1e-5);
}

float G_SchlickGGX(float NoV, float rough) {
    float r = rough + 1.0;
    float k = (r * r) * 0.125;
    return NoV / max(NoV * (1.0 - k) + k, 1e-5);
}

float G_Smith(float NoV, float NoL, float rough) {
    return G_SchlickGGX(NoV, rough) * G_SchlickGGX(NoL, rough);
}

vec3 fresnelSchlick(float VoH, vec3 F0) {
    return F0 + (1.0 - F0) * pow(1.0 - VoH, 5.0);
}

float traceVisibility(vec3 p, vec3 n, vec3 lPos) {
    vec3 dir = lPos - p;
    float dist = length(dir);
    dir /= max(dist, 1e-5);

    vec2 h = traceScene(p + n * 0.03, dir);
    if (h.x > 0.0 && h.x < dist - 0.05) return 0.0;
    return 1.0;
}

vec3 pbrLight(
    vec3 p, vec3 n, vec3 V,
    vec3 albedo, float rough, float refl,
    vec3 lPos, vec3 lCol, float intensity,
    vec3 spotDir, float spotInner, float spotOuter,
    float shadow
) {
    vec3 L = lPos - p;
    float dist = length(L);
    L /= max(dist, 1e-5);

    vec3 H = normalize(V + L);

    float cone = 1.0;
    if (spotInner > 0.0) {
        float d = dot(normalize(p - lPos), normalize(spotDir));
        cone = smoothstep(spotOuter, spotInner, d);
        cone *= cone;
    }

    float atten = intensity / (1.0 + dist * 0.24 + dist * dist * 0.07);

    float NoV = max(dot(n, V), 0.0);
    float NoL = max(dot(n, L), 0.0);
    float NoH = max(dot(n, H), 0.0);
    float VoH = max(dot(V, H), 0.0);

    vec3 F0 = vec3(0.02 + refl * 0.18);
    vec3 F = fresnelSchlick(VoH, F0);
    float D = D_GGX(NoH, rough);
    float G = G_Smith(NoV, NoL, rough);

    vec3 spec = (D * G * F) / max(4.0 * NoV * NoL, 1e-4);
    vec3 kd = (1.0 - F);
    vec3 diff = kd * albedo / PI;

    return (diff + spec) * lCol * NoL * atten * cone * shadow;
}

// ------------------------------------------------------------
// Surface shading
// ------------------------------------------------------------
vec3 shadeSurface(vec3 p, vec3 n, float id, vec3 ro, vec3 rd, vec3 lPos, vec3 lDir) {
    vec3 n0, t, b;
    vec2 uv;
    surfaceData(id, p, n0, t, b, uv);

    vec3 albedo, emit;
    float rough, refl;
    getMaterial(id, uv, p, albedo, rough, refl, emit);

    vec3 V = normalize(ro - p);

    float ao = 1.0;
    float wd = HALF_W - abs(p.x);

    if (id < 1.5) ao *= 1.0 - 0.42 * exp(-wd * 6.2);
    else if (id < 3.5) {
        ao *= 1.0 - 0.28 * exp(-(p.y - FLOOR_Y) * 5.0);
        ao *= 1.0 - 0.12 * exp(-(CEIL_Y - p.y) * 4.6);
    } else if (id < 4.5) ao *= 1.0 - 0.24 * exp(-wd * 4.0);
    else ao *= 0.92;

    float hemi = dot(n, vec3(0.0, 1.0, 0.0)) * 0.5 + 0.5;
    vec3 ambient = mix(vec3(0.005, 0.006, 0.008),
                       vec3(0.017, 0.019, 0.024), hemi) * albedo * ao;

                       if (id < 1.5) ambient *= 0.68;
                       if (id > 4.5) ambient *= 0.88;

                       if (id < 1.5) {
                           float cell = floor(p.z / 3.6 + 0.5);
                           float br = fixtureBrightness(cell);
                           ambient += albedo * vec3(0.72, 0.75, 0.72) * br * exp(-abs(p.z - cell * 3.6) * 0.6) * 0.038;
                       }

                       vec3 col = ambient + emit;

                       {
                           float shadow = traceVisibility(p, n, lPos);
                           float flicker = 0.97 + 0.02 * sin(u_time * 17.0) + 0.012 * sin(u_time * 39.0);
                           vec3 fc = vec3(1.0, 0.95, 0.88) * flicker;

                           col += pbrLight(p, n, V, albedo, rough, refl, lPos, fc, 3.2, lDir, 0.993, 0.81, shadow);
                           col += pbrLight(p, n, V, albedo, rough, refl, lPos, fc * 0.22, 1.4, lDir, 0.82, 0.46, shadow) * 0.6;
                       }

                       float baseCell = floor(p.z / 3.6 + 0.5);
                       for (int i = -1; i <= 1; i++) {
                           float cell = baseCell + float(i);
                           float br = fixtureBrightness(cell);
                           if (br > 0.01) {
                               vec3 lp = vec3(fixtureSwing(cell), CEIL_Y - 0.02, cell * 3.6);
                               float warmth = hash11(cell * 3.0) * 0.08;
                               vec3 lc = mix(vec3(0.78, 0.82, 0.78), vec3(0.86, 0.83, 0.76), warmth) * br;
                               float shadow = traceVisibility(p, n, lp);

                               col += pbrLight(p, n, V, albedo, rough, refl, lp, lc, 1.7, vec3(0.0, -1.0, 0.0), 0.92, 0.34, shadow);
                           }
                       }

                       for (int side = 0; side < 2; side++) {
                           float sIdx = float(side);
                           for (int i = -1; i <= 1; i++) {
                               float cell = baseCell + float(i);
                               float hasDoor = step(0.24, hash11(cell * 7.13 + sIdx * 13.7));
                               float hasSign = hasDoor * step(0.52, hash11(cell * 3.73 + sIdx * 19.1));
                               if (hasSign > 0.5) {
                                   float sx = (side == 0) ? -HALF_W + 0.01 : HALF_W - 0.01;
                                   vec3 sp = vec3(sx, FLOOR_Y + 1.13, cell * 3.6);
                                   vec3 sd = (side == 0) ? vec3(1.0, 0.0, 0.0) : vec3(-1.0, 0.0, 0.0);
                                   vec3 sc = vec3(0.12, 0.95, 0.22);
                                   float shadow = traceVisibility(p, n, sp);
                                   col += pbrLight(p, n, V, albedo, rough, refl, sp, sc, 0.90, sd, 0.75, 0.08, shadow) * 0.55;
                               }
                           }
                       }

                       return col;
}

// ------------------------------------------------------------
// Floor reflections
// ------------------------------------------------------------
vec3 shadeWithReflections(vec3 p, vec3 n, float id, vec3 ro, vec3 rd, vec3 lPos, vec3 lDir) {
    vec3 col = shadeSurface(p, n, id, ro, rd, lPos, lDir);
    if (id > 1.5) return col;

    vec3 n0, t, b;
    vec2 fUV;
    surfaceData(id, p, n0, t, b, fUV);

    vec3 alb, emit;
    float rough, refl;
    getMaterial(id, fUV, p, alb, rough, refl, emit);

    float grout = max(lineRepeat(fUV.x, 0.62, 0.012, 0.008),
                      lineRepeat(fUV.y, 0.62, 0.012, 0.008));

    float wet = floorWet(fUV) * (1.0 - grout * 0.82);

    vec2 flow = floorFlowDir(fUV);
    vec2 flowUV = floorFlowUV(fUV);

    vec3 flowW = normalize(t * flow.x + b * flow.y);
    vec3 perpW = normalize(t * (-flow.y) + b * flow.x);

    float asym = (fbm(vec2(flowUV.y * 1.7 + 5.2, flowUV.x * 0.25)) - 0.5) * 0.10;
    float puddle = smoothstep(0.18, 0.92, wet + asym);
    if (puddle < 0.02) return col;

    vec3 reflN = normalize(n + flowW * asym * 0.05);

    vec3 V = normalize(ro - p);
    float NoV = max(dot(reflN, V), 0.0);
    float fres = mix(0.06, 1.0, pow(1.0 - NoV, 5.0));

    vec3 reflDir = reflect(rd, reflN);

    float blurAlong = mix(0.080, 0.009, puddle);
    float blurAcross = mix(0.024, 0.0045, puddle);
    blurAlong *= mix(1.14, 0.76, NoV);
    blurAcross *= mix(1.08, 0.80, NoV);

    vec3 accum = vec3(0.0);
    float wsum = 0.0;

    for (int i = 0; i < REFLECTION_SAMPLES; i++) {
        float fi = float(i);
        float w = (i == 0) ? 3.0 : 1.0;

        vec2 xi = hash22(vec2(fi + floor(flowUV.x * 3.0), floor(flowUV.y * 7.0) + 11.0)) - 0.5;
        vec3 rj = normalize(reflDir + flowW * xi.x * blurAlong + perpW * xi.y * blurAcross);

        vec2 h = traceScene(p + reflN * 0.02, rj);
        vec3 rc = getFogColor() * 0.40;

        if (h.x > 0.0) {
            vec3 rp = p + reflN * 0.02 + rj * h.x;
            vec3 rn = getNormal(h.y, rp);

            rc = shadeSurface(rp, rn, h.y, p, rj, lPos, lDir);
            float rcPeak = max(rc.r, max(rc.g, rc.b));
            rc *= 1.0 / (1.0 + rcPeak * 0.16);
            rc = mix(rc, getFogColor(), saturate(h.x * 0.016));
            rc *= mix(0.90, 0.99, puddle);
        }

        accum += rc * w;
        wsum += w;
    }

    vec3 reflCol = accum / max(wsum, 1e-4);

    col *= 1.0 - puddle * 0.08;
    col += reflCol * puddle * (0.28 + 1.08 * fres);

    vec3 L = normalize(lPos - p);
    vec3 H = normalize(V + L);
    float flash = pow(max(dot(reflN, H), 0.0), mix(18.0, 56.0, puddle));
    float cone = smoothstep(0.82, 0.996, dot(normalize(p - lPos), lDir));
    float dist = length(lPos - p);
    float atten = 2.2 / (1.0 + dist * 0.25 + dist * dist * 0.07);
    col += vec3(1.0, 0.97, 0.93) * flash * puddle * cone * atten * 0.24;

    return col;
}

// ------------------------------------------------------------
// Atmosphere / glow
// ------------------------------------------------------------
vec3 getFogColor() {
    return vec3(0.0035, 0.0050, 0.0080);
}

vec3 applyFog(vec3 col, float dist, vec3 ro, vec3 rd) {
    float heightBoost = 1.0 + 0.18 * saturate(1.0 - (ro.y + rd.y * dist * 0.5 - FLOOR_Y) * 0.35);
    float density = 0.028 * heightBoost;
    float fog = 1.0 - exp(-dist * density);

    vec3 fc = mix(vec3(0.008, 0.010, 0.013),
                  vec3(0.0036, 0.0048, 0.0072),
                  saturate(dist * 0.020));

    return mix(col, fc, fog);
}

vec3 volumetrics(vec3 ro, vec3 rd, float maxT, vec3 lPos, vec3 lDir) {
    vec3 acc = vec3(0.0);
    float jitter = hash21(rd.xy * 900.0 + fract(u_time) * 50.0);

    for (int i = 0; i < VOLUME_STEPS; i++) {
        float f = (float(i) + jitter) / float(VOLUME_STEPS);
        float t = maxT * f * f;
        vec3 pos = ro + rd * t;

        vec3 toL = pos - lPos;
        float d = length(toL);
        vec3 dir = toL / max(d, 1e-5);
        float cone = smoothstep(0.78, 0.995, dot(dir, lDir));
        float dust = 0.024 + 0.014 * noise(pos.xz * 0.6 + u_time * 0.02);
        acc += vec3(0.92, 0.90, 0.86) * cone * dust * exp(-d * 0.18);

        float cell = floor(pos.z / 3.6 + 0.5);
        float br = fixtureBrightness(cell);
        if (br > 0.1) {
            vec3 lp = vec3(fixtureSwing(cell), CEIL_Y - 0.02, cell * 3.6);
            vec3 dl = pos - lp;
            float ld = length(dl);
            float down = max(-dl.y / max(ld, 1e-5), 0.0);
            vec3 lc = vec3(0.76, 0.79, 0.76);
            acc += lc * br * down * down * exp(-ld * 0.34) * 0.012;
        }
    }

    return acc * maxT * 0.0068;
}

vec3 sceneGlow(vec3 ro, vec3 rd) {
    vec3 g = vec3(0.0);
    float baseCell = floor(ro.z / 3.6 + 0.5);

    for (int i = -1; i <= 2; i++) {
        float cell = baseCell + float(i);
        float br = fixtureBrightness(cell);
        if (br > 0.01) {
            vec3 lp = vec3(fixtureSwing(cell), CEIL_Y - 0.02, cell * 3.6);
            vec3 toL = lp - ro;
            float t = max(dot(toL, rd), 0.0);
            float d = length(lp - (ro + rd * t));
            vec3 lc = vec3(0.72, 0.76, 0.73) * br;

            g += lc * exp(-d * d * 36.0) * exp(-t * 0.048) * 0.62;
            g += lc * exp(-d * d * 10.0) * exp(-t * 0.060) * 0.18;
        }
    }

    return g;
}

// ------------------------------------------------------------
// Tone map
// ------------------------------------------------------------
vec3 aces(vec3 x) {
    return saturate3((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14));
}

// ------------------------------------------------------------
// Render
// ------------------------------------------------------------
vec3 render(vec2 fragCoord) {
    vec2 uv = (fragCoord * 2.0 - u_resolution.xy) / min(u_resolution.x, u_resolution.y);

    float walk = u_time * 1.95;
    float bob = sin(u_time * 5.3) * 0.020 + sin(u_time * 2.7) * 0.008;
    float sway = sin(u_time * 1.55) * 0.010 + sin(u_time * 0.8) * 0.005;

    vec3 ro = vec3(sway, -0.16 + bob + sin(u_time * 3.7) * 0.003, walk);

    float r2 = dot(uv, uv);
    uv *= 1.0 + r2 * 0.008;

    vec3 rd = normalize(vec3(uv.x, uv.y * 0.965, 1.52));
    rd.yz = rot(-0.040 + sin(u_time * 0.68) * 0.006) * rd.yz;
    rd.xz = rot(sin(u_time * 0.42) * 0.012) * rd.xz;

    vec3 lPos = ro + vec3(0.030, -0.020, 0.0);
    vec3 lDir = normalize(vec3(0.030 + 0.010 * sin(u_time * 0.85), -0.014, 1.0));

    vec2 hit = traceScene(ro, rd);
    float t = hit.x > 0.0 ? hit.x : FAR_T;

    vec3 col = vec3(0.0);
    vec3 glow = sceneGlow(ro, rd);

    col += volumetrics(ro, rd, min(t, 24.0), lPos, lDir);
    col += glow * 0.42;

    if (hit.x > 0.0) {
        vec3 p = ro + rd * hit.x;
        vec3 n = getNormal(hit.y, p);
        col += shadeWithReflections(p, n, hit.y, ro, rd, lPos, lDir);
        col = applyFog(col, hit.x, ro, rd);
    } else {
        col += getFogColor();
    }

    float vig = length(uv * vec2(0.92, 1.0));
    col *= 1.0 - vig * vig * 0.16;

    float grain = hash21(fragCoord + fract(u_time) * 100.0) - 0.5;
    float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col += grain * mix(0.0035, 0.0015, saturate(lum * 3.0));

    col = aces(col * 1.00);
    col = pow(max(col, vec3(0.0)), vec3(0.4545));

    col = mix(vec3(dot(col, vec3(0.3333))), col, 1.02);
    col = mix(col, col * vec3(0.97, 0.985, 1.015), 0.08);

    return saturate3(col);
}

void main() {
    gl_FragColor = vec4(render(gl_FragCoord.xy), 1.0);
}
