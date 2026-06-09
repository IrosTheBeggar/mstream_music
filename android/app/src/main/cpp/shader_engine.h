// Engine that renders Shadertoy-convention fragment shaders, single
// or multi-pass.
//
// Single-pass: file is just a `void mainImage(...)` body using the
// standard Shadertoy uniforms (iTime, iResolution, iChannel0, ...).
// iChannel0 is wired to our audio texture by default.
//
// Multi-pass: file uses markers to declare passes and channel routing:
//
//   // === channel image.0 = bufferB
//   // === channel bufferB.0 = bufferA
//   // === channel bufferB.1 = bufferB
//   //
//   // === pass: common ===
//   <shared code prepended to all other passes>
//   // === pass: bufferA ===
//   <bufferA shader>
//   // === pass: bufferB ===
//   <bufferB shader>
//   // === pass: image ===
//   <image shader>
//
// Passes render in fixed order: bufferA, bufferB, bufferC, bufferD,
// image. Each buffer has ping-pong FBOs so self-feedback works (a
// buffer reading itself reads last frame's texture; reading another
// buffer that already rendered this frame reads the just-written
// texture).
//
// Compilation runs on a dedicated worker thread with its own EGL
// context that shares resources with the render thread's context.
// loadPreset returns immediately; the worker compiles all passes
// into a PassSet, atomically hands it off. If the user cycles
// faster than compile time, intermediate sources are dropped.
//
// Cross-fade between presets is unchanged: the image pass renders
// into fboCurrent_, the present pass copies it to the window
// surface, and on swap the previous fboCurrent_ is blitted to
// fboOld_ for a 600ms blend.
//
// Audio reactivity: 1024-point FFT on incoming PCM, published as a
// 512×2 R8 texture bound wherever a channel is routed to "music".

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
    void setTuning(const float* values, std::size_t count) override;

    // Number of user tuning floats exposed to shaders as `uniform float
    // iParams[NUM_PARAMS]`. The first 3 setTuning() values drive the
    // audio response curve; the remainder fill iParams.
    static constexpr int NUM_PARAMS = 8;

    // Pass slot indices: 0..3 = bufferA..D, 4 = image. Used by the
    // anonymous-namespace parser in the .cpp; exposed here so it can
    // refer to them via ShaderEngine::PASS_*.
    static constexpr int PASS_BUFFER_A = 0;
    static constexpr int PASS_BUFFER_B = 1;
    static constexpr int PASS_BUFFER_C = 2;
    static constexpr int PASS_BUFFER_D = 3;
    static constexpr int PASS_IMAGE    = 4;
    static constexpr int PASS_COUNT    = 5;  // image + 4 buffers

private:

    // Channel input source identifiers. 0 = unbound (sampling returns 0).
    enum ChannelSource : int {
        CHAN_NONE    = 0,
        CHAN_AUDIO   = 1,
        CHAN_BUFFER_A = 2,
        CHAN_BUFFER_B = 3,
        CHAN_BUFFER_C = 4,
        CHAN_BUFFER_D = 5,
    };

    struct UniformLocs {
        GLint time = -1;
        GLint timeDelta = -1;
        GLint frame = -1;
        GLint resolution = -1;
        GLint mouse = -1;
        GLint channel[4] = {-1, -1, -1, -1};
        GLint channelTime = -1;
        GLint channelResolution = -1;
        GLint date = -1;
        GLint sampleRate = -1;
        GLint params = -1;   // iParams[NUM_PARAMS] — user tuning knobs
    };

    struct Pass {
        GLuint program = 0;
        UniformLocs locs{};
        // Source for each of the 4 iChannel uniforms in this pass.
        ChannelSource channelSrc[4] = {CHAN_NONE, CHAN_NONE, CHAN_NONE, CHAN_NONE};
        // Requested render size for this pass's target, 0 = full window res.
        // Only honored for buffer passes (A..D); the image pass always
        // renders at full res so the present pass can sample it 1:1. Lets a
        // shader declare e.g. an audio-analysis buffer that writes one
        // constant value as `1x1`, instead of paying a full-screen pass to
        // produce a single texel. See the `// === size <pass> = WxH` marker.
        int renderW = 0;
        int renderH = 0;
    };

    // A complete set of compiled passes for one shader preset.
    struct PassSet {
        Pass passes[PASS_COUNT];
        bool hasPass[PASS_COUNT] = {false, false, false, false, false};
    };

    // Ping-pong FBO+texture pair for a buffer pass.
    struct BufferTarget {
        GLuint fbo[2] = {0, 0};
        GLuint tex[2] = {0, 0};
        int writeIdx = 0;
        bool allocated = false;
        // Size the textures were allocated at, so a preset swap that
        // re-requests this buffer slot at a different size reallocates.
        int w = 0;
        int h = 0;
    };

    // === Render-thread methods ===
    void adoptPendingPassSetIfAny();
    void renderPass(int idx, const Pass& p, GLuint targetFbo,
                     int targetW, int targetH,
                     float elapsed, float delta, GLuint audioTex);
    GLuint channelTextureFor(ChannelSource src, int currentPassIdx,
                              GLuint audioTex) const;
    bool ensureBufferTarget(int idx);
    void releaseBufferTarget(int idx);
    void releaseAllBufferTargets();
    void clearCurrentSet();
    // Upload the uniforms that are constant for a program's lifetime (or
    // change only on setTuning): iChannelResolution, iSampleRate, iMouse,
    // iDate, the iChannel sampler-unit bindings, and iParams. Called once
    // when a PassSet is adopted, instead of re-uploading them every frame in
    // renderPass. Uniform values live in the program object, so they persist
    // across the glUseProgram switches between passes.
    void primeConstantUniforms(PassSet* set);
    // Re-upload just iParams to the current set's programs (after setTuning).
    void applyParamsToCurrentSet();

    // === Worker-thread methods ===
    void workerLoop();
    // Compile a complete PassSet from a parsed source. Returns null on failure.
    // Must be called with a current EGL context.
    PassSet* compilePassSet(const std::string& source);
    static UniformLocs queryUniformLocations(GLuint program);
    static GLuint compileSingleProgram(const std::string& fragSource);
    void freePassSet(PassSet* set);

    // === Bridge between worker and render threads ===
    PassSet* currentSet_ = nullptr;
    PassSet* pendingSet_ = nullptr;

    // === Offscreen + present (unchanged from previous design) ===
    bool setupOffscreenTargets();
    void teardownOffscreenTargets();

    bool setupSharedContext();
    void teardownSharedContext();

    int width_ = 0;
    int height_ = 0;

    GLuint vao_ = 0;
    GLuint vbo_ = 0;

    // Present-pass program (samples fboCurrent_ + optionally fboOld_).
    GLuint presentProgram_ = 0;
    GLint  locPresentCurrent_ = -1;
    GLint  locPresentOld_ = -1;
    GLint  locPresentMixT_ = -1;

    // Final-image FBO (the image pass renders here) + held-old FBO for crossfade.
    GLuint fboCurrent_ = 0;
    GLuint texCurrent_ = 0;
    GLuint fboOld_ = 0;
    GLuint texOld_ = 0;

    // Per-buffer ping-pong targets (only allocated for buffers a preset uses).
    BufferTarget bufferTargets_[4];

    // 1×1 black fallback texture for unbound channels.
    GLuint blackTex_ = 0;

    std::chrono::steady_clock::time_point startTime_;
    std::chrono::steady_clock::time_point lastFrameTime_;
    int frameCount_ = 0;

    std::chrono::steady_clock::time_point transitionStart_;
    bool transitioning_ = false;
    static constexpr float kTransitionDuration = 0.6f;

    AudioTexture audio_;

    // User tuning knobs pushed via setTuning(), bound to the iParams[]
    // uniform each frame. Defaults to 0; the UI pushes each shader's
    // declared defaults on load, so shaders that read iParams[i] always
    // see a sensible value.
    float params_[NUM_PARAMS] = {0.0f};
    // Set by setTuning(), cleared once the new params_ have been pushed to the
    // current set's programs. Lets renderFrame skip the per-frame iParams
    // re-upload when tuning hasn't changed.
    bool paramsDirty_ = false;

    // --- Worker thread state ---
    std::thread worker_;
    std::mutex queueMutex_;
    std::condition_variable queueCv_;
    std::string pendingSource_;
    bool hasPendingSource_ = false;
    std::atomic<bool> workerShutdown_{false};

    std::mutex resultMutex_;
    PassSet* pendingResult_ = nullptr;

    EGLDisplay workerDisplay_ = EGL_NO_DISPLAY;
    EGLContext workerCtx_ = EGL_NO_CONTEXT;
    EGLSurface workerSurface_ = EGL_NO_SURFACE;
};
