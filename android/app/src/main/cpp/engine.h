// Abstract visualizer engine. Owned by the JNI bridge, called from
// the Kotlin render thread (with EGL context already current).
//
// Concrete engines:
//   * ProjectMEngine — wraps libprojectM-4.so (Milkdrop presets)
//   * ShaderEngine   — Shadertoy-style fragment shaders with our own
//                       FFT pipeline and audio texture
//
// All engine methods run on the dedicated render thread. The bridge
// guarantees the EGL context is current before calling any of them.

#pragma once

#include <cstddef>

class Engine {
public:
    virtual ~Engine() = default;

    // Called once after EGL is set up. Return false to abort init.
    virtual bool init(int width, int height) = 0;

    // Called every frame. Implementations issue GL draw calls; the
    // bridge handles eglSwapBuffers after this returns.
    virtual void renderFrame() = 0;

    // Push interleaved stereo PCM into whatever the engine uses for
    // audio reactivity. Engines are free to ignore.
    //   samples: interleaved L,R,L,R… in [-1, 1]
    //   frameCount: number of L/R pairs (so samples has 2*frameCount floats)
    virtual void addPcm(const float* samples, std::size_t frameCount) = 0;

    // Switch to a new preset/shader. Format is engine-specific:
    //   ProjectM: .milk file contents
    //   Shader:   GLSL fragment shader (Shadertoy "mainImage" convention)
    virtual void loadPreset(const char* data, bool smoothTransition) = 0;

    // Live-tune engine-specific parameters from a flat float array, pushed
    // from the in-app tuning panel. The ShaderEngine maps [0..2] → the
    // audio response curve (minDb, maxDb, smoothing) and [3..] → the
    // iParams[] uniform exposed to shaders. Default no-op: engines that
    // expose nothing tunable (e.g. ProjectM) ignore it.
    virtual void setTuning(const float* /*values*/, std::size_t /*count*/) {}
};
