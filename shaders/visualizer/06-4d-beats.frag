#version 460 core

#include <flutter/runtime_effect.glsl>

// Ported from assets/shaders/06-4d-beats.glsl (mrange, CC0). Single-pass 4D
// raymarch. The original packs the loop into one comma-operator expression with a
// non-standard for-header (declares r, tests i, increments z) — both of which the
// Skia/SkSL backend rejects. Rewritten here into a plain counting loop with
// statement body. iChannelTime[0] (audio clock) -> iTime; iParams[0] (tempo) baked.

uniform vec3 iResolution;
uniform float iTime;
uniform sampler2D iChannel0; // unused by this preset, kept for the shared interface

out vec4 fragColor;

void main() {
  vec2 C = FlutterFragCoord().xy;
  C.y = iResolution.y - C.y;

  vec4 o = vec4(0.0), p, P, U = vec4(1, 2, 3, 0);
  float z = 0.0, d = 0.0, k;
  // Beat clock: floor(T)+sqrt(F) gives the beat-synced speed-up.
  float T = iTime * 1.9, F = fract(T), t = floor(T) + sqrt(F);
  // Rotation matrix spun by the beat clock (mat2 from 4 scalars — SkSL-safe).
  vec4 cs = cos(t * .1 + 11. * U.wxzw);
  mat2 R = mat2(cs.x, cs.y, cs.z, cs.w);
  vec3 r = iResolution;

  // Original: ++i < 77. from i = 0 -> 76 iterations.
  for (int n = 0; n < 76; n++) {
    p = vec4(z * normalize(vec3(C - .5 * r.xy, r.y)), .2);
    p.z -= 3.;
    p.xw *= R;
    p.yw *= R;
    p.zw *= R;
    k = 9. / dot(p, p); // @mla inversion
    p *= k;
    p -= .5 * t;
    P = p;
    p = abs(p - round(p)); // fold to the unit cell
    d = abs(
          min(
            min(
              min(min(length(p.xz), length(p.yz)), length(p.xy)),
              length(p) - .2
            ),
            min(p.w, min(p.x, min(p.z, p.y))) + .05)
        ) / k;
    p = 1. + sin(P.z + log2(k) + U.wxyw);
    o += U * exp(.7 * k - 6. * F) + p.w * p / max(d, 1e-3);
    z += .8 * d + 1e-3;
  }

  fragColor = tanh(o / 1e4) / .9; // tanh tone-map with a slight clip
}
