#version 460 core

#include <flutter/runtime_effect.glsl>

// Ported from assets/shaders/05-hex-marching.glsl (bufferb pass), multi-pass via MultiPassRenderer.

uniform vec3 iResolution;
uniform float iTime;
uniform sampler2D iChannel0;
uniform sampler2D iChannel1;

out vec4 fragColor;

// License CC0: Hex Marching
#define RESOLUTION  iResolution
#define TIME        iTime
#define ROT(a)      mat2(cos(a), sin(a), -sin(a), cos(a))

const mat2 brot = ROT(2.399);
//  simplyfied version of Dave Hoskins blur
vec3 dblur(vec2 q,float rad) {
  vec3 acc=vec3(0);
  const float m = 0.002;
  vec2 pixel=vec2(m*RESOLUTION.y/RESOLUTION.x,m);
  vec2 angle=vec2(0,rad);
  rad=1.;
  const int iter = 30;
  for (int j=0; j<iter; ++j) {  
    rad += 1./rad;
    angle*=brot;
    vec4 col=texture(iChannel1,q+pixel*(rad-1.)*angle);
    acc+=col.xyz;
  }
  return acc*(1.0/float(iter));
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  fragCoord.y = iResolution.y - fragCoord.y;

  vec2 q = fragCoord/RESOLUTION.xy;
  vec2 p = -1.0+2.0*q;
  vec4 pcol = texture(iChannel0,q);
  vec3 bcol = dblur(q, .75);
  
  vec3 col = pcol.xyz;
  col += vec3(0.9, .8, 1.2)*mix(0.5, 0.66, length(p))*(0.05+bcol);

  fragColor = vec4(col, 1.0);
}
