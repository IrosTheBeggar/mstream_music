#version 460 core

#include <flutter/runtime_effect.glsl>

// Ported from assets/shaders/04-cyber-fuji.glsl (image pass). Multi-pass:
// iChannel0 = music (audio texture), iChannel1 = buffera (1x1 smoothed bands,
// self-feedback). Driven by MultiPassRenderer.

uniform vec3 iResolution;
uniform float iTime;
uniform sampler2D iChannel0;
uniform sampler2D iChannel1;

out vec4 fragColor;

float sun(vec2 uv, float battery, float bass)
{
 	float val = smoothstep(0.3, 0.29, length(uv));
 	float bloom = smoothstep(0.7, 0.0, length(uv));
    float cut = 3.0 * sin((uv.y + iTime * 0.2 * (battery + 0.02)) * 100.0)
				+ clamp(uv.y * 14.0 + 1.0, -6.0, 6.0);
    cut = clamp(cut, 0.0, 1.0);
    // mstream: bloom coefficient scaled by bass for throbbing glow
    return clamp(val * cut, 0.0, 1.0) + bloom * (0.6 * (1.0 + bass * 0.8));
}

float grid(vec2 uv, float battery, float bass)
{
    vec2 size = vec2(uv.y, uv.y * uv.y * 0.2) * 0.01;
    // mstream: lateral sway proportional to bass — grid rocks left/right.
    // Slow sin so cycles read as a sway (~2s period), not vibration.
    float sway = sin(iTime * 3.0) * bass * 0.8;
    uv += vec2(sway, iTime * 4.0 * (battery + 0.05));
    uv = abs(fract(uv) - 0.5);
 	vec2 lines = smoothstep(size, vec2(0.0), uv);
 	lines += smoothstep(size * 5.0, vec2(0.0), uv) * 0.4 * battery;
    return clamp(lines.x + lines.y, 0.0, 3.0);
}

float dot2(in vec2 v ) { return dot(v,v); }

float sdTrapezoid( in vec2 p, in float r1, float r2, float he )
{
    vec2 k1 = vec2(r2,he);
    vec2 k2 = vec2(r2-r1,2.0*he);
    p.x = abs(p.x);
    vec2 ca = vec2(p.x-min(p.x,(p.y<0.0)?r1:r2), abs(p.y)-he);
    vec2 cb = p - k1 + k2*clamp( dot(k1-p,k2)/dot2(k2), 0.0, 1.0 );
    float s = (cb.x<0.0 && ca.y<0.0) ? -1.0 : 1.0;
    return s*sqrt( min(dot2(ca),dot2(cb)) );
}

float sdLine( in vec2 p, in vec2 a, in vec2 b )
{
    vec2 pa = p-a, ba = b-a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length( pa - ba*h );
}

float sdBox( in vec2 p, in vec2 b )
{
    vec2 d = abs(p)-b;
    return length(max(d,vec2(0))) + min(max(d.x,d.y),0.0);
}

float opSmoothUnion(float d1, float d2, float k){
	float h = clamp(0.5 + 0.5 * (d2 - d1) /k,0.0,1.0);
    return mix(d2, d1 , h) - k * h * ( 1.0 - h);
}

float sdCloud(in vec2 p, in vec2 a1, in vec2 b1, in vec2 a2, in vec2 b2, float w)
{
	//float lineVal1 = smoothstep(w - 0.0001, w, sdLine(p, a1, b1));
    float lineVal1 = sdLine(p, a1, b1);
    float lineVal2 = sdLine(p, a2, b2);
    vec2 ww = vec2(w*1.5, 0.0);
    vec2 left = max(a1 + ww, a2 + ww);
    vec2 right = min(b1 - ww, b2 - ww);
    vec2 boxCenter = (left + right) * 0.5;
    //float boxW = right.x - left.x;
    float boxH = abs(a2.y - a1.y) * 0.5;
    //float boxVal = sdBox(p - boxCenter, vec2(boxW, boxH)) + w;
    float boxVal = sdBox(p - boxCenter, vec2(0.04, boxH)) + w;

    float uniVal1 = opSmoothUnion(lineVal1, boxVal, 0.05);
    float uniVal2 = opSmoothUnion(lineVal2, boxVal, 0.05);

    return min(uniVal1, uniVal2);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  fragCoord.y = iResolution.y - fragCoord.y;

    vec2 uv = (2.0 * fragCoord.xy - iResolution.xy)/iResolution.y;
    float battery = 1.0;
    //if (iMouse.x > 1.0 && iMouse.y > 1.0) battery = iMouse.y / iResolution.y;
    //else battery = 0.8;

    // mstream: read smoothed audio amplitudes from buffer A.
    //   .r = bass    → sun bloom
    //   .g = low-mid → mountain width
    //   .b = mid     → grid sway
    //   .a = treble  → cloud Y bounce
    vec4 audio = texture(iChannel1, vec2(0.5, 0.5));
    float mstreamBass   = audio.r;
    float mstreamLowMid = audio.g;
    float mstreamMid    = audio.b;
    float mstreamTreble = audio.a;

    //if (abs(uv.x) < (9.0 / 16.0))
    {
        // Grid
        float fog = smoothstep(0.1, -0.02, abs(uv.y + 0.2));
        vec3 col = vec3(0.0, 0.1, 0.2);
        if (uv.y < -0.2)
        {
            uv.y = 3.0 / (abs(uv.y + 0.2) + 0.05);
            uv.x *= uv.y * 1.0;
            float gridVal = grid(uv, battery, mstreamMid);
            col = mix(col, vec3(1.0, 0.5, 1.0), gridVal);
        }
        else
        {
            float fujiD = min(uv.y * 4.5 - 0.5, 1.0);
            uv.y -= battery * 1.1 - 0.51;

            vec2 sunUV = uv;
            vec2 fujiUV = uv;

            // Sun
            sunUV += vec2(0.75, 0.2);
            //uv.y -= 1.1 - 0.51;
            col = vec3(1.0, 0.2, 1.0);
            float sunVal = sun(sunUV, battery, mstreamBass);

            col = mix(col, vec3(1.0, 0.4, 0.1), sunUV.y * 2.0 + 0.2);
            col = mix(vec3(0.0, 0.0, 0.0), col, sunVal);

            // fuji  —  mstream: width multiplier reacts to smoothed
            // low-mid energy so the mountain bulges with the body of
            // the song rather than just kicks.
            float mstreamWidthMul = 1.0 + mstreamLowMid * 0.4;
            float fujiVal = sdTrapezoid( uv  + vec2(-0.75+sunUV.y * 0.0, 0.5), (1.75 + pow(uv.y * uv.y, 2.1)) * mstreamWidthMul, 0.2, 0.5);
            // mstream: snow line traces the live audio waveform, with a
            // 1/d glow line drawn on top (neon oscilloscope style).
            // iChannel0 row y=0.75 is the time-domain waveform (512 samples,
            // centered at 0.5). Map a WIDER range than the snow line so
            // the waveform extends past the mountain at any bulge state
            // (step(fujiVal,0) mask clips it cleanly to the mountain shape).
            // Box-blur over 7 samples for a continuous line shape.
            float texX = (uv.x - 0.25);  // uv.x ∈ [0.25, 1.25] → texX ∈ [0, 1]
            float audioWave = 0.0;
            for (int i = -3; i <= 3; i++) {
                audioWave += texture(iChannel0, vec2(clamp(texX + float(i) * 0.005, 0.0, 1.0), 0.75)).x;
            }
            audioWave /= 7.0;
            // waveVal is a signed altitude relative to the wave line.
            // Positive above the line (snow fill), abs(waveVal) is the
            // distance from the line itself (oscilloscope render).
            float waveVal = uv.y + (audioWave - 0.5) * 0.15 + 0.2;
            float wave_width = smoothstep(0.0,0.01,(waveVal));

            // fuji color
            col = mix( col, mix(vec3(0.0, 0.0, 0.25), vec3(1.0, 0.0, 0.5), fujiD), step(fujiVal, 0.0));
            // fuji top snow
            col = mix( col, vec3(1.0, 0.5, 1.0), wave_width * step(fujiVal, 0.0));
            // mstream: 1/d glow line traced ON the waveform boundary.
            // intensity = thickness / (abs(dist) + eps), capped at 4.0,
            // additively blended over the snow fill so the line reads
            // as a bright neon glow rather than a flat strip.
            // Pattern reference: 3dGGDy by ncote — see
            // shader_research/cyber-fuji-reactivity-notes.md.
            float lineGlow = 0.004 / (abs(waveVal) + 0.001);
            lineGlow = min(lineGlow, 4.0);
            col += vec3(1.0, 1.0, 1.0) * lineGlow * step(fujiVal, 0.0);
            // fuji outline
            col = mix( col, vec3(1.0, 0.5, 1.0), 1.0-smoothstep(0.0,0.01,abs(fujiVal)) );
            //col = mix( col, vec3(1.0, 1.0, 1.0), 1.0-smoothstep(0.03,0.04,abs(fujiVal)) );
            //col = vec3(1.0, 1.0, 1.0) *(1.0-smoothstep(0.03,0.04,abs(fujiVal)));

            // horizon color
            col += mix( col, mix(vec3(1.0, 0.12, 0.8), vec3(0.0, 0.0, 0.2), clamp(uv.y * 3.5 + 3.0, 0.0, 1.0)), step(0.0, fujiVal) );

            // cloud
            vec2 cloudUV = uv;
            cloudUV.x = mod(cloudUV.x + iTime * 0.1, 4.0) - 2.0;
            float cloudTime = iTime * 0.5;
            // mstream: cloud Y bounces with treble (positive offset on this layer)
            float cloudY = -0.5 + mstreamTreble * 0.40;
            float cloudVal1 = sdCloud(cloudUV,
                                     vec2(0.1 + sin(cloudTime + 140.5)*0.1,cloudY),
                                     vec2(1.05 + cos(cloudTime * 0.9 - 36.56) * 0.1, cloudY),
                                     vec2(0.2 + cos(cloudTime * 0.867 + 387.165) * 0.1,0.25+cloudY),
                                     vec2(0.5 + cos(cloudTime * 0.9675 - 15.162) * 0.09, 0.25+cloudY), 0.075);
            // mstream: second cloud layer bounces counter-direction (treble)
            cloudY = -0.6 - mstreamTreble * 0.40;
            float cloudVal2 = sdCloud(cloudUV,
                                     vec2(-0.9 + cos(cloudTime * 1.02 + 541.75) * 0.1,cloudY),
                                     vec2(-0.5 + sin(cloudTime * 0.9 - 316.56) * 0.1, cloudY),
                                     vec2(-1.5 + cos(cloudTime * 0.867 + 37.165) * 0.1,0.25+cloudY),
                                     vec2(-0.6 + sin(cloudTime * 0.9675 + 665.162) * 0.09, 0.25+cloudY), 0.075);

            float cloudVal = min(cloudVal1, cloudVal2);

            //col = mix(col, vec3(1.0,1.0,0.0), smoothstep(0.0751, 0.075, cloudVal));
            col = mix(col, vec3(0.0, 0.0, 0.2), 1.0 - smoothstep(0.075 - 0.0001, 0.075, cloudVal));
            col += vec3(1.0, 1.0, 1.0)*(1.0 - smoothstep(0.0,0.01,abs(cloudVal - 0.075)));
        }

        col += fog * fog * fog;
        col = mix(vec3(col.r, col.r, col.r) * 0.5, col, battery * 0.7);

        fragColor = vec4(col,1.0);
    }
    //else fragColor = vec4(0.0);


}
