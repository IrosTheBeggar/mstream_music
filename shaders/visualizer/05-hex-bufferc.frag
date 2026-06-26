#version 460 core

#include <flutter/runtime_effect.glsl>

// Ported from assets/shaders/05-hex-marching.glsl (bufferc pass), multi-pass via MultiPassRenderer.

uniform vec3 iResolution;
uniform float iTime;
uniform sampler2D iChannel0;
uniform sampler2D iChannel1;

out vec4 fragColor;

// Bass onset detector (mstream addition). Writes one value to every pixel;
// the image pass samples a single texel.
//   iChannel0 = music   (FFT spectrum row, y=0.25)
//   iChannel1 = bufferc  (self-feedback: previous frame's {pulse, baseline})
// Output: .r = pulse (0..1, flares on kicks, ~0 between), .g = bass baseline.
//
// Buffers are RGBA8, so the feedback EMA only resolves ~1/255 per step. We
// keep the baseline time-constant moderate and add a small dead-zone on the
// onset so 8-bit quantization noise can't leak through as a constant glow.
void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  fragCoord.y = iResolution.y - fragCoord.y;

  // Current bass = mean of the lowest 4 bins (kick / sub-bass,
  // ~85-345 Hz at the 512-bin, 44.1 kHz layout).
  float bass = 0.0;
  for (int i = 0; i < 4; i++) {
    bass += texture(iChannel0, vec2(float(i) * 0.004 + 0.004, 0.25)).x;
  }
  bass *= 0.25;

  vec4 prev = texture(iChannel1, vec2(0.5, 0.5));
  // Baseline inertia (0.89): follows sustained bass, lags transients.
  float baseline = mix(bass, prev.y, 0.89);

  // Onset = bass above baseline, past a dead-zone (0.023) that eats
  // the ~1/255 quantization band. ~0 in steady state; spikes on a kick.
  // 9.4 = sensitivity (onset gain).
  float onset = clamp((bass - baseline - 0.023) * 9.4, 0.0, 1.0);
  // Instant attack; 0.86 = release (flash decay per frame).
  float pulse = max(onset, prev.x * 0.86);

  fragColor = vec4(pulse, baseline, 0.0, 1.0);
}
