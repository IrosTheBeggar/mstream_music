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
    // Cached uniform locations for the current program. Recomputed
    // each time we swap in a new compiled program from the worker.
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
    void adoptPendingProgramIfAny();

    // Worker thread main loop. Owns workerCtx_; pulls sources off
    // pendingSources_ and compiles them.
    void workerLoop();

    // Build vertex+fragment shaders, link a program. Returns 0 on
    // failure. Safe to call from any thread that has *some* EGL
    // context current (either the render context or the worker
    // share context).
    GLuint compileProgramOnCurrentContext(const std::string& fragSource);
    static UniformLocs queryUniformLocations(GLuint program);

    // Spawn / tear down the worker. setupSharedContext() must run on
    // the render thread (it needs the render context current to
    // create a sharing partner).
    bool setupSharedContext();
    void teardownSharedContext();

    int width_ = 0;
    int height_ = 0;

    // Active program currently driving the screen.
    GLuint program_ = 0;
    UniformLocs locs_{};
    GLuint vao_ = 0;
    GLuint vbo_ = 0;

    std::chrono::steady_clock::time_point startTime_;
    std::chrono::steady_clock::time_point lastFrameTime_;
    int frameCount_ = 0;

    AudioTexture audio_;

    // --- Worker thread state ---
    std::thread worker_;
    std::mutex queueMutex_;
    std::condition_variable queueCv_;
    std::string pendingSource_;   // only the latest queued source survives
    bool hasPendingSource_ = false;
    std::atomic<bool> workerShutdown_{false};

    // Hand-off slot from worker → render thread. Non-zero means a
    // freshly-linked program is ready to adopt. Guarded by
    // resultMutex_; the worker owns deletion of any program that
    // gets displaced before the render thread picks it up.
    std::mutex resultMutex_;
    GLuint pendingProgram_ = 0;

    // Worker EGL state (shared with the render context).
    EGLDisplay workerDisplay_ = EGL_NO_DISPLAY;
    EGLContext workerCtx_ = EGL_NO_CONTEXT;
    EGLSurface workerSurface_ = EGL_NO_SURFACE;
};
