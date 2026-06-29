#version 460 core

#include <flutter/runtime_effect.glsl>

// Ported from assets/shaders/04-cyber-fuji.glsl (buffera pass). Multi-pass:
// iChannel0 = music (audio texture), iChannel1 = buffera (1x1 smoothed bands,
// self-feedback). Driven by MultiPassRenderer.

uniform vec3 iResolution;
uniform float iTime;
uniform sampler2D iChannel0;
uniform sampler2D iChannel1;

out vec4 fragColor;

// Four-band smoothed audio extractor with self-feedback.
//
// IMPORTANT: our AudioTexture uses BINS=512 (Shadertoy convention),
// so at a 44.1 kHz sample rate each bin ≈ 43 Hz. The useful musical
// spectrum (under ~6 kHz) is therefore packed into x ∈ [0, 0.27].
// Earlier versions of this pass sampled out at x=0.5–0.75 expecting
// 256 bins and were reading dead-air frequencies above 10 kHz.
//
// Reads:
//   iChannel0 = music   (raw FFT, row 0; waveform row 1)
//   iChannel1 = buffera (previous frame's smoothed values, self-feedback)
//
// Writes:
//   .r = smoothed bass    (~85-515 Hz;     bins 2-12)
//   .g = smoothed low-mid (~600-1300 Hz;   bins 14-30)
//   .b = smoothed mid     (~1.5-3.7 kHz;   bins 35-85)
//   .a = smoothed treble  (~4.3-10.7 kHz;  bins 100-250)
//   Same vec4 is written to every pixel — image pass samples one.
//
// Asymmetric attack/release smoothing applied vec4-wise:
//   attack  ≈ 0.15 (snappy onsets)
//   release ≈ 0.50 (musical decay, not too dragging)

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  fragCoord.y = iResolution.y - fragCoord.y;

    // Sample 6 bins per band, averaged, then scaled to ~fit [0,1].
    // x coords below match the BINS=512 layout (see header comment).
    // Pre-scale per band. Sum-of-6-bins approach means raw values can
    // easily reach 1.5-3.0 on energetic music, so multipliers need to
    // stay small or every channel saturates at 1.0 (= constant = no
    // animation). Diagnostic confirmed all 4 channels were clamping;
    // these factors aim for peak values in [0.6, 0.9] range, leaving
    // dynamic-range headroom for the smoothing envelope to swing in.
    float rawBass = 0.0;
    for (int i = 0; i < 6; i++) {
        rawBass += texture(iChannel0, vec2(0.004 + float(i) * 0.004, 0.25)).x;
    }
    rawBass = clamp(rawBass * 0.11, 0.0, 1.0);

    float rawLowMid = 0.0;
    for (int i = 0; i < 6; i++) {
        rawLowMid += texture(iChannel0, vec2(0.028 + float(i) * 0.006, 0.25)).x;
    }
    rawLowMid = clamp(rawLowMid * 0.10, 0.0, 1.0);

    float rawMid = 0.0;
    for (int i = 0; i < 6; i++) {
        rawMid += texture(iChannel0, vec2(0.070 + float(i) * 0.020, 0.25)).x;
    }
    rawMid = clamp(rawMid * 0.26, 0.0, 1.0);

    float rawTreble = 0.0;
    for (int i = 0; i < 6; i++) {
        rawTreble += texture(iChannel0, vec2(0.13 + float(i) * 0.035, 0.25)).x;
    }
    // Real music has far less 8-11 kHz "air" than the old synth signal,
    // so sample the lower "presence" range (~3-7 kHz: cymbals, hi-hats,
    // sibilance) and boost the gain so clouds react to real audio.
    rawTreble = clamp(rawTreble * 0.17, 0.0, 1.0);

    vec4 raw  = vec4(rawBass, rawLowMid, rawMid, rawTreble);
    // NOTE: an `raw *= raw` square (mrange's "fft *= fft" trick) used to
    // sit here to claw dynamic range back out of the engine's old log1p
    // FFT curve, which clamped the low bins to an always-hot floor. The
    // audio texture now ships a normalized, dB-mapped, EMA-smoothed
    // spectrum (Web Audio / Shadertoy convention), so that square would
    // be redundant double-compression — removed. The prescales above act
    // as per-band sum→[0,1] normalizers; the visual amplitudes below are
    // sized for these (un-squared) band levels.
    vec4 prev = texture(iChannel1, vec2(0.5, 0.5));

    // Asymmetric smoothing vec4-wise: 0.15 attack (raw > prev), 0.5 release.
    // step(prev, raw) is 1 when raw >= prev (rising), else 0.
    vec4 coeff = mix(vec4(0.5), vec4(0.15), step(prev, raw));
    vec4 smoothed = clamp(mix(raw, prev, coeff), vec4(0.0), vec4(1.0));

    fragColor = smoothed;
}
