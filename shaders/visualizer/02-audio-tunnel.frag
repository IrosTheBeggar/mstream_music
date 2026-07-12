#version 460 core

#include <flutter/runtime_effect.glsl>

// Ported from assets/shaders/02-audio-tunnel.glsl (Shadertoy convention) to Flutter's runtime
// fragment-shader dialect: mainImage -> main(), FlutterFragCoord with a y-flip so
// the Shadertoy bottom-left origin is preserved, iParams[] baked to their preset
// defaults, and iChannel0 supplied as the audio texture (row 0 = FFT spectrum,
// row 1 = waveform) by ShaderVisualizerScreen.

uniform vec3 iResolution;     // x,y = pixels, z = pixel aspect (1.0)
uniform float iTime;
uniform sampler2D iChannel0;  // audio texture

out vec4 fragColor;

// title: Audio Tunnel
// author: mstream_music
// license: MIT
// description: A depth tunnel of rings, scrolling speed and color shift
//              react to bass / mid / treble FFT bands.
//
// Demonstrates the "sample 3 bands" pattern — useful for picking out
// rhythm sections without doing a full equalizer.
//
// params (iParams[]):
//   0 = bassSpeed (how much bass accelerates the tunnel)
//   1 = trebleGlow (treble spoke brightness)
// param: bassSpeed 0.0 2.5 0.19
// param: trebleGlow 0.0 4.0 2.53

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  fragCoord.y = iResolution.y - fragCoord.y;

    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    float r = length(uv);
    float a = atan(uv.y, uv.x);

    // Sample three bands. Frequencies are normalized [0..1] into the
    // FFT row of iChannel0.
    // AudioTexture has 512 bins, so at 44.1 kHz each bin ≈ 43 Hz:
    //   x=0.006 → bin 3  → ~130 Hz   (kick / sub bass)
    //   x=0.06  → bin 31 → ~1.3 kHz  (vocal body / lead)
    //   x=0.15  → bin 77 → ~3.3 kHz  (presence / cymbal attack)
    // Previously these were at 0.04 / 0.30 / 0.70 which translated to
    // low-mid / treble / dead air respectively — fixed.
    float bass   = texture(iChannel0, vec2(0.006, 0.25)).x;
    float mids   = texture(iChannel0, vec2(0.060, 0.25)).x;
    float treble = texture(iChannel0, vec2(0.150, 0.25)).x;

    // Tunnel rings. log(r) gives even spacing in screen space as
    // they recede; scroll outward over time, faster with bass.
    float speed = 0.4 + bass * 0.19;
    float ring = fract(log(max(r, 0.001)) * 3.0 - iTime * speed);
    float ringEdge = smoothstep(0.5, 0.42, abs(ring - 0.5));

    // Color mix shifts with the mids; spokes pop on treble hits.
    vec3 cold = vec3(0.25, 0.55, 1.0);
    vec3 warm = vec3(1.0, 0.35, 0.55);
    vec3 col = mix(cold, warm, clamp(mids, 0.0, 1.0));

    float spoke = 0.5 + 0.5 * sin(a * 12.0 + iTime * 0.6);
    col += pow(spoke, 12.0) * treble * vec3(1.0, 0.8, 0.4) * 2.53;

    // Vignette by 1/r so the center stays bright and the edges fall off.
    col *= ringEdge / max(r * 1.4, 0.18);

    fragColor = vec4(col, 1.0);
}
