#version 460 core

// Pure-Flutter audio spectrum visualizer (desktop). Renders 64 frequency bars
// with a soft cap-glow over a dark gradient, tinted by the app's accent colour.
// Uniforms are set per-frame by _VizPainter in shader_visualizer_screen.dart —
// keep the declaration ORDER in sync (setFloat is by flat index).

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;        // floats 0,1  — canvas size in pixels
uniform float uTime;       // float  2    — seconds since start
uniform vec3 uAccent;      // floats 3,4,5 — theme accent (0..1 RGB)
uniform float uBands[64];  // floats 6..69 — smoothed magnitude per band (0..1)

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  float yUp = 1.0 - uv.y; // 0 at the bottom, 1 at the top

  // Band magnitude for this column. Constant-index loop so the array access is
  // GLSL-ES safe (no dynamic indexing of a uniform array).
  float bandPos = uv.x * 64.0;
  int idx = int(bandPos);
  float v = 0.0;
  for (int i = 0; i < 64; i++) {
    if (i == idx) v = uBands[i];
  }
  v = clamp(v, 0.0, 1.0);

  // Bar occupies the centre ~72% of each band slot.
  float xin = fract(bandPos);
  float barMask = smoothstep(0.12, 0.16, xin) * smoothstep(0.88, 0.84, xin);

  // Lit below the bar top, plus a soft glow at the cap.
  float lit = smoothstep(v + 0.004, v - 0.004, yUp) * barMask;
  float glow = exp(-abs(yUp - v) * 18.0) * barMask;

  // Dark vertical-gradient background.
  vec3 bg = mix(vec3(0.015, 0.02, 0.04), vec3(0.04, 0.03, 0.07), uv.y);

  // Bar colour: darker accent at the base brightening toward the top.
  float grad = clamp(yUp / max(v, 0.001), 0.0, 1.0);
  vec3 barCol = mix(uAccent * 0.35, uAccent, grad);

  vec3 col = bg;
  col = mix(col, barCol, lit);
  col += uAccent * glow * 0.9;

  // Gentle shimmer so the scene still breathes on quiet frames.
  col *= 0.92 + 0.08 * sin(uTime * 1.5 + uv.x * 8.0);

  fragColor = vec4(col, 1.0);
}
