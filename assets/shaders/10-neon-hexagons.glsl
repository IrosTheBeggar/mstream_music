// title: Neon Lit Hexagons
// author: Shane
// source: https://www.shadertoy.com/view/MsVfz1
// license: no explicit license stated on Shadertoy; original (c) Shane.
//          Ported here for the mstream visualizer with attribution.
// modifications (mstream):
//   (1) iChannel0 is the audio FFT in this engine, not a stone bitmap.
//       The original tri-planar surface texture (tex3D) and bump map
//       (texBump) are replaced with a cheap procedural noise so the
//       look is preserved while iChannel0 is freed for audio.
//   (2) Optimizations, visually faithful: 6-tap normal -> 4-tap
//       tetrahedral; softShadow 32 -> 24 iters; 15 texture fetches
//       removed in favour of a cheap procedural value-noise eval.
//   (3) AUDIO REACTIVITY: the neon glow intensity pulses with bass
//       FFT energy (see gGlowGain in mainImage + its use in doColor).
//
// 3D raymarched hexagon-tile field with glowing neon slabs.

// Hexagon shape only (original also had dodecahedron/cylinder via SHAPE;
// removed here since the default scene uses hexagons).

// Surface-detail toggles from the original — left off (a touch expensive).
//#define ADD_DETAIL_GROOVE
//#define ADD_DETAIL_BOLT

// Animate the neon on/off blinking. Off by default (distracting).
//#define ANIMATE_LIGHTS

// Borg green, if that's your thing.
//#define GREEN_GLOW

// Maximum ray distance.
#define FAR 50.

// Standard 2D rotation.
mat2 r2(in float a){ float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }

// vec2 -> float hash.
float hash21(vec2 p){
    float n = dot(p, vec2(7.163, 157.247));
    return fract(sin(n)*43758.5453);
}

// vec3 -> float hash.
float hash31(vec3 p){
    float n = dot(p, vec3(13.163, 157.247, 7.951));
    return fract(sin(n)*43758.5453);
}

// Commutative smooth maximum (Tomkh / Alex Evans / Dave Smith).
float smax(float a, float b, float k){
    float f = max(0., 1. - abs(b - a)/k);
    return max(a, b) + k*.25*f*f;
}

// Concise IQ-style 3D value noise.
float noise3D(in vec3 p){
    const vec3 s = vec3(113, 157, 1);
    vec3 ip = floor(p);
    vec4 h = vec4(0., s.yz, s.y + s.z) + dot(ip, s);
    p -= ip;
    p = p*p*(3. - 2.*p);
    h = mix(fract(sin(h)*43758.5453), fract(sin(h + s.x)*43758.5453), p.x);
    h.xy = mix(h.xz, h.yw, p.y);
    return mix(h.x, h.y, p.z);
}

// Procedural greyscale "stone", replacing the bitmap iChannel0 used to
// supply (iChannel0 is the audio FFT here). Two octaves is plenty since
// the surface is darkened to 1/16 to spotlight the neon.
vec3 surfTex(in vec3 p){
    float n = noise3D(p)*0.5 + noise3D(p*2.1)*0.3 + noise3D(p*4.7)*0.2;
    return vec3(n);
}

// The camera path: a gentle horizontal sinusoid down the field.
vec2 path(in float z){
    return vec2(sin(z * 0.15)*2.4, 0);
}

// 30-60-90 helper for hexagonal tiling: sides 1, sqrt(3), 2.
const vec2 s = vec2(.866025, 1);

// Hexagonal pylon bound (estimate, not an exact field — close enough that
// shadows/normals read correctly here). The ".015" rounds the edges.
float hexPylon(vec2 p2, float pz, float r, float ht){
    vec3 p = vec3(p2.x, pz, p2.y);
    vec3 b = vec3(r, ht, r);
    p.xz = abs(p.xz);
    p.xz = vec2(p.x*.866025 + p.z*.5, p.z);
    return length(max(abs(p) - b + .015, 0.)) - .015;
}

// Neon-light IDs. Each of the four pylon groupings carries a light that
// is either on or off; these collect which sub-object won.
vec4 litID;
float svLitID;

// Pylon + neon-slab distance. id: 0 = main hexagon, 1 = neon slab.
float objDist(vec2 p, float pH, float r, float ht, inout float id, float dir){
    const float s = 1./16.;

    // Main hexagon pylon.
    float h1 = hexPylon(p, pH, r, ht);

    #ifdef ADD_DETAIL_GROOVE
    h1 = max(h1, -hexPylon(p, pH + ht, r - .06, s/4.));
    #endif
    #ifdef ADD_DETAIL_BOLT
    h1 = min(h1, hexPylon(p, pH, .1, ht + s/4.));
    #endif

    // Thin slab just below the pylon top — the lit (neon) portion.
    float h2 = hexPylon(p, pH + ht - s, r + .01, s/3.);

    id = h1 < h2 ? 0. : 1.;
    return min(h1, h2);
}

// Per-hexagon height. Any cheap flowing field works.
float hexHeight(vec2 p){
    return dot(sin(p*2. - cos(p.yx*1.4)), vec2(.25)) + .5;
}

// Returns nearest hexagon distance + its lit-ID, plus that cell's centre
// (used as a unique per-hexagon random seed). Two interleaved hex lattices
// cover the plane, hence the doubled-up evaluation.
vec4 getHex(vec2 p, float pH){
    vec4 hC  = floor(vec4(p, p - vec2(0, .5))/s.xyxy) + vec4(0, 0, 0, .5);
    vec4 hC2 = floor(vec4(p - vec2(.5, .25), p - vec2(.5, .75))/s.xyxy) + vec4(.5, .25, .5, .75);

    vec4 h  = vec4(p - (hC.xy + .5)*s,  p - (hC.zw + .5)*s);
    vec4 h2 = vec4(p - (hC2.xy + .5)*s, p - (hC2.zw + .5)*s);

    vec4 ht = vec4(hexHeight(hC.xy), hexHeight(hC.zw), hexHeight(hC2.xy), hexHeight(hC2.zw));
    // Quantize to five levels (the .02 nudge kills lights on ground tiles).
    ht = floor(ht*4.99)/4./2. + .02;

    const float r = .25;
    vec4 obj = vec4(objDist(h.xy,  pH, r, ht.x, litID.x,  1.), objDist(h.zw,  pH, r, ht.y, litID.y, -1.),
                    objDist(h2.xy, pH, r, ht.z, litID.z, -1.), objDist(h2.zw, pH, r, ht.w, litID.w,  1.));

    h  = obj.x < obj.y ? vec4(h.xy,  hC.xy)  : vec4(h.zw,  hC.zw);
    h2 = obj.z < obj.w ? vec4(h2.xy, hC2.xy) : vec4(h2.zw, hC2.zw);

    vec2 oH  = obj.x < obj.y ? vec2(obj.x, litID.x) : vec2(obj.y, litID.y);
    vec2 oH2 = obj.z < obj.w ? vec2(obj.z, litID.z) : vec2(obj.w, litID.w);

    return oH.x < oH2.x ? vec4(oH, h.zw) : vec4(oH2, h2.zw);
}

// Unique hexagon-centre seed + the winning lit-ID, set by heightMap.
vec2 v2Rnd, svV2Rnd;
float gLitID;

float heightMap(in vec3 p){
    const float sc = 1.;
    vec4 h = getHex(p.xz*sc, -p.y*sc);
    v2Rnd = h.zw;
    gLitID = h.y;
    return h.x/sc;
}

float map(vec3 p){
    return heightMap(p)*.7;
}

// Global glow accumulator, and the audio-driven gain applied to it.
vec3 glow;
float gGlowGain = 1.;

// Whether a given hexagon's neon is lit.
float getRndID(vec2 p){
    #ifdef ANIMATE_LIGHTS
    float rnd = hash21(p);
    return smoothstep(.5, .875, sin(rnd*6.283 + iTime));
    #else
    return hash21(p) - .75;
    #endif
}

// Raymarch with inline volumetric glow accumulation near lit slabs.
float trace(vec3 ro, vec3 rd){
    float t = hash31(ro + rd)*.25, d, ad;
    glow = vec3(0);

    for (int i = 0; i < 80; i++){
        d = map(ro + rd*t);
        ad = abs(d);
        if(ad < .001*(t*.125 + 1.) || t > FAR) break;

        const float gd = .1;
        float rnd = getRndID(v2Rnd);
        if(rnd > 0. && gLitID == 1. && ad < gd){
            float gl = .2*(gd - ad)/gd/(1. + ad*ad/gd/gd*8.);
            glow += gl;
        }
        t += d;
    }
    return min(t, FAR);
}

// Soft shadows. 24 iters (was 32) — the clamped stepping still reaches the
// nearby light, and shadows here are softened/lightened so the cut is hidden.
float softShadow(vec3 ro, vec3 lp, float k){
    const int maxIterationsShad = 24;

    vec3 rd = (lp - ro);
    float shade = 1.0;
    float dist = 0.01;
    float end = max(length(rd), 0.001);
    rd /= end;

    for (int i = 0; i < maxIterationsShad; i++){
        float h = map(ro + rd*dist);
        shade = min(shade, smoothstep(0.0, 1.0, k*h/dist));
        dist += clamp(h, .02, .25);
        if (h < 0. || dist > end) break;
    }
    return min(max(shade, 0.) + .05, 1.);
}

// Tetrahedral normal — 4 map calls instead of the symmetric 6-tap version.
vec3 getNormal(in vec3 p){
    vec2 e = vec2(.0025, -.0025);
    return normalize(
        e.xyy * map(p + e.xyy) +
        e.yyx * map(p + e.yyx) +
        e.yxy * map(p + e.yxy) +
        e.xxx * map(p + e.xxx));
}

// Ambient occlusion (IQ).
float calcAO(in vec3 p, in vec3 n){
    float sca = 4., occ = 0.0;
    for(int i = 1; i < 6; i++){
        float hr = float(i)*.125/5.;
        float dd = map(p + hr*n);
        occ += (hr - dd)*sca;
        sca *= .75;
    }
    return clamp(1. - occ, 0., 1.);
}

// Procedural bump from the surfTex height field (replaces the 12-tap
// tri-planar texBump). Four scalar samples, gradient projected onto n.
vec3 doBump(in vec3 p, in vec3 n, float bf){
    const vec2 e = vec2(.001, 0);
    const vec3 lum = vec3(.299, .587, .114);
    float ref = dot(surfTex(p), lum);
    vec3 g = (vec3(dot(surfTex(p - e.xyy), lum),
                   dot(surfTex(p - e.yxy), lum),
                   dot(surfTex(p - e.yyx), lum)) - ref)/e.x;
    g -= n*dot(n, g);
    return normalize(n + g*bf);
}

// Fake environment reflection — a little fBm tinted blue/purple.
vec3 envMap(vec3 p){
    p *= 3.;
    float n3D2 = noise3D(p*3.);
    float c = noise3D(p)*.57 + noise3D(p*2.)*.28 + noise3D(p*4.)*.15;
    c = smoothstep(.25, 1., c);
    p = vec3(c, c*c, c*c*c);
    return mix(p, p.zyx, n3D2*.25 + .75);
}

vec3 getObjectColor(vec3 p, vec3 n){
    float sz0 = 1./2.;

    // Procedural surface (was a tri-planar bitmap lookup).
    vec3 col = surfTex(p*sz0);
    col = smoothstep(-.0, .5, col);
    col = mix(col, vec3(1)*dot(col, vec3(.299, .587, .114)), .5);
    // Darken hard to bring attention to the neon.
    col /= 16.;

    float rnd = getRndID(svV2Rnd);

    // Object glow: a vertical gradient on each lit slab.
    float oGlow = 0.;
    if(rnd > 0. && svLitID == 1.){
        float ht = hexHeight(svV2Rnd);
        ht = floor(ht*4.99)/4./2. + .02;
        const float s = 1./4./2.*.5;
        oGlow = mix(1., 0., clamp((abs(p.y - (ht - s)))/s*3., 0., 1.));
        oGlow = smoothstep(0., 1., oGlow);
    }

    // Blend the smooth object glow with a portion of the volumetric glow.
    glow = mix(glow, vec3(oGlow), .75);

    // Colorize the glow (firey orange, with pink/blue swirls).
    glow = pow(vec3(1.5, 1, 1)*glow, vec3(1, 3, 6));
    glow = mix(glow, glow.xzy, dot(sin(p*4. - cos(p.yzx*4.)), vec3(.166)) + .5);
    glow = mix(glow, glow.zyx, dot(cos(p*2. - sin(p.yzx*2.)), vec3(.166)) + .5);

    #ifdef GREEN_GLOW
    glow = glow.yxz;
    #endif

    return col;
}

vec3 doColor(in vec3 sp, in vec3 rd, in vec3 sn, in vec3 lp, in float t){
    vec3 sceneCol = vec3(0);

    if(t < FAR){
        // Procedural bump (was tri-planar texBump on iChannel0).
        sn = doBump(sp, sn, .016);

        float sh = softShadow(sp, lp, 12.);
        float ao = calcAO(sp, sn);
        sh = min(sh + ao*.3, 1.);

        vec3 ld = lp - sp;
        float lDist = max(length(ld), .001);
        ld /= lDist;

        float atten = 1.5/(1. + lDist*.1 + lDist*lDist*.02);
        float diff = max(dot(sn, ld), 0.);
        float spec = pow(max(dot(reflect(-ld, sn), -rd), 0.0), 32.);
        float fres = clamp(1.0 + dot(rd, sn), 0.0, 1.0);

        vec3 objCol = getObjectColor(sp, sn);

        sceneCol = objCol*(diff + vec3(1, .6, .3)*spec*4. + .5*ao + vec3(.3, .5, 1)*fres*fres*2.);
        sceneCol += pow(sceneCol, vec3(1.))*envMap(reflect(rd, sn))*4.;
        sceneCol *= atten*sh*ao;

        // Glow layered on top (unaffected by shadow/AO), scaled by audio.
        sceneCol += (objCol*6. + 1.)*glow*gGlowGain;
    }

    return sceneCol;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ){
    vec2 uv = (fragCoord - iResolution.xy*.5) / iResolution.y;

    // AUDIO REACTIVITY (mstream): drive the neon glow intensity from low
    // frequency FFT energy. iChannel0's row y=0.25 is the FFT, matching
    // the other presets in this app.
    float aud = 0.;
    for(int i = 0; i < 8; i++){
        aud += texture(iChannel0, vec2((float(i) + .5)/128., .25)).x;
    }
    aud = clamp(pow(aud/8., 1.3)*1.6, 0., 1.);
    // Keep a dim floor at silence; punch up on bass hits.
    gGlowGain = mix(0.7, 1.9, aud);

    // Camera down the winding field.
    vec3 lk = vec3(0, 1.25, iTime*1.);
    vec3 ro = lk + vec3(0, .175, -.25);
    vec3 lp = ro + vec3(0, 1, 4);

    lk.xy += path(lk.z);
    ro.xy += path(ro.z);
    lp.xy += path(lp.z);

    float FOV = 3.14159/3.;
    vec3 forward = normalize(lk - ro);
    vec3 right = normalize(vec3(forward.z, 0., -forward.x));
    vec3 up = cross(forward, right);
    vec3 rd = normalize(forward + FOV*uv.x*right + FOV*uv.y*up);

    // Single pass (the original's reflection pass was already disabled).
    float t = trace(ro, rd);
    svV2Rnd = v2Rnd;
    svLitID = gLitID;

    float fog = smoothstep(0., FAR - 1., t);
    ro += rd*t;
    vec3 sn = getNormal(ro);

    vec3 sceneColor = doColor(ro, rd, sn, lp, t);
    sceneColor = mix(sceneColor, vec3(0), fog);

    // Square vignette.
    uv = fragCoord/iResolution.xy;
    sceneColor = min(sceneColor, 1.)*pow(16.*uv.x*uv.y*(1. - uv.x)*(1. - uv.y), .0625);

    fragColor = vec4(sqrt(clamp(sceneColor, 0.0, 1.0)), 1.0);
}
