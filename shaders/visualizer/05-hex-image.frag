#version 460 core

#include <flutter/runtime_effect.glsl>

// Ported from assets/shaders/05-hex-marching.glsl (image pass), multi-pass via MultiPassRenderer.

uniform vec3 iResolution;
uniform float iTime;
uniform sampler2D iChannel0;
uniform sampler2D iChannel1;

out vec4 fragColor;

// License CC0: Hex Marching
//  Results from saturday afternoon tinkering
#define TIME iTime
void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  fragCoord.y = iResolution.y - fragCoord.y;

  vec2 q = fragCoord/iResolution.xy;

  vec4 pcol = texture(iChannel0, q);
  vec3 col = pcol.xyz;
  col = clamp(col, 0.0, 1.0);
  col *= smoothstep(0.0, 2.0, TIME);

  // mstream: flash on bass onsets. bufferC (iChannel1) outputs a pulse in
  // .r that spikes when bass rises above its recent baseline and decays to
  // ~0 between hits — a transient flash, NOT a constant brightness boost
  // (the constant boost is what made the old level-based mod peg).
  float pulse = texture(iChannel1, vec2(0.5, 0.5)).x;
  col *= 1.0 + pulse * 1.76;   // 1.76 = flash strength

  col = sqrt(col);
  fragColor = vec4(col, 1.0);
}
