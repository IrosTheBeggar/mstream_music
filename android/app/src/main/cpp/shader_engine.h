// Engine that renders Shadertoy-convention fragment shaders.
//
// loadPreset() takes a GLSL fragment shader source that defines:
//
//     void mainImage(out vec4 fragColor, in vec2 fragCoord);
//
// We wrap it with a Shadertoy-style prelude (iTime, iResolution,
// iChannel0, etc.) and a tiny main() that calls mainImage and writes
// the result.
//
// Compilation runs on a dedicated worker thread with its own EGL
// context that shares resources with the render thread's context.
// loadPreset returns immediately; the worker compiles + links, and
// the render thread picks up the new program at the top of the next
// frame. If the user cycles faster than compile time, the worker
// drops intermediate sources and only compiles the latest.
//
// Cross-fade between presets: every frame is rendered to a "current"
// FBO and then a tiny present pass blits to the window surface. On a
// program swap, the current FBO's contents are copied to an "old"
// FBO; for the next ~600ms the present pass mixes old → new before
// reverting to a plain copy. Costs one extra fullscreen quad per
// frame; the transition itself adds one texture sample during the
// crossfade window.
//
// Audio reactivity: we run a 1024-point FFT on incoming PCM and
// publish a 512×2 R8 texture bound to iChannel0 — same shape
// Shadertoy itself uses for audio channels.

#pragma once

#include <EGL/egl.h>
#include <GLES3/gl3.h>
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <memory>
#include <mutex>
#include <string>
#include <thread>

#include "audio_texture.h"
#include "engine.h"

class ShaderEngine : public Engine {
public:
    ShaderEngine() = default;
    ~ShaderEngine() override;

    bool init(int width, int height) override;
    void renderFrame() override;
    void addPcm(const float* samples, std::size_t frameCount) override;
    void loadPreset(const char* data, bool smoothTransition) override;

private:
    // Cached uniform locations for the current shader program.
    struct UniformLocs {
        GLint time = -1;
        GLint timeDelta = -1;
        GLint frame = -1;
        GLint resolution = -1;
        GLint mouse = -1;
        GLint channel0 = -1;
        GLint channelTime = -1;
        GLint channelResolution = -1;
        GLint date = -1;
        GLint sampleRate = -1;
    };

    // Render-thread work: pull any newly-linked program out of the
    // worker hand-off slot and install it as the current program.
    // Returns true if a swap happened (so the caller can start the
    // transition).
    bool adoptPendingProgramIfAny();

    // Worker thread main loop.
    void workerLoop();

    // Build vertex+fragment shaders, link a program. Returns 0 on
    // failure. Safe to call from any thread with *some* EGL context
    // current (render or shared).
    GLuint compileProgramOnCurrentContext(const std::string& fragSource);
    static UniformLocs queryUniformLocations(GLuint program);

    // FBO setup for shader-to-texture rendering + cross-fade.
    bool setupOffscreenTargets();
    void teardownOffscreenTargets();

    // Spawn / tear down the worker.
    bool setupSharedContext();
    void teardownSharedContext();

    int width_ = 0;
    int height_ = 0;

    // Active shader program currently driving the offscreen FBO.
    GLuint program_ = 0;
    UniformLocs locs_{};
    GLuint vao_ = 0;
    GLuint vbo_ = 0;

    // Present pass: samples the current (and during a transition, the
    // old) frame texture and writes to the window surface.
    GLuint presentProgram_ = 0;
    GLint  locPresentCurrent_ = -1;
    GLint  locPresentOld_ = -1;
    GLint  locPresentMixT_ = -1;

    // Offscreen render targets. fboCurrent_ is what the active shader
    // draws into every frame; fboOld_ is a captured snapshot of the
    // previous shader's last frame, used during the crossfade.
    GLuint fboCurrent_ = 0;
    GLuint texCurrent_ = 0;
    GLuint fboOld_ = 0;
    GLuint texOld_ = 0;

    std::chrono::steady_clock::time_point startTime_;
    std::chrono::steady_clock::time_point lastFrameTime_;
    int frameCount_ = 0;

    // Crossfade. transitionStart_ + kTransitionDuration == end. While
    // we're inside this window, the present pass mixes texOld_ →
    // texCurrent_; once we pass it, the present pass is a plain copy.
    std::chrono::steady_clock::time_point transitionStart_;
    bool transitioning_ = false;
    static constexpr float kTransitionDuration = 0.6f;

    AudioTexture audio_;

    // --- Worker thread state ---
    std::thread worker_;
    std::mutex queueMutex_;
    std::condition_variable queueCv_;
    std::string pendingSource_;
    bool hasPendingSource_ = false;
    std::atomic<bool> workerShutdown_{false};

    std::mutex resultMutex_;
    GLuint pendingProgram_ = 0;

    EGLDisplay workerDisplay_ = EGL_NO_DISPLAY;
    EGLContext workerCtx_ = EGL_NO_CONTEXT;
    EGLSurface workerSurface_ = EGL_NO_SURFACE;
};
