#include "shader_engine.h"

#include <android/log.h>
#include <cstring>
#include <utility>

#define LOG_TAG "mstream/viz-bridge"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace {

// Fullscreen-triangle vertex shader. One triangle covers the entire
// NDC viewport — saves us an index buffer compared to a quad.
const char* kVertexShader = R"(#version 300 es
precision highp float;
layout(location = 0) in vec2 aPos;
void main() {
    gl_Position = vec4(aPos, 0.0, 1.0);
}
)";

// Prelude prepended to every user fragment shader. Provides the
// Shadertoy uniforms and the main() entry that delegates to the
// user's mainImage().
const char* kFragPrelude = R"(#version 300 es
precision highp float;
precision highp int;

uniform float iTime;
uniform float iTimeDelta;
uniform int   iFrame;
uniform vec3  iResolution;
uniform vec4  iMouse;
uniform sampler2D iChannel0;
uniform float iChannelTime[4];
uniform vec3  iChannelResolution[4];
uniform vec4  iDate;
uniform float iSampleRate;

out vec4 outColor;

void mainImage(out vec4 fragColor, in vec2 fragCoord);

void main() {
    vec4 col = vec4(0.0);
    mainImage(col, gl_FragCoord.xy);
    outColor = col;
}

// === user shader follows ===
)";

// Present-pass shaders. Same fullscreen-triangle vertex pass but
// also outputs uv. Fragment samples the offscreen FBO textures and
// mixes them based on mixT (0 = all old, 1 = all current).
const char* kPresentVertexShader = R"(#version 300 es
precision highp float;
layout(location = 0) in vec2 aPos;
out vec2 vUv;
void main() {
    gl_Position = vec4(aPos, 0.0, 1.0);
    vUv = (aPos + 1.0) * 0.5;
}
)";

const char* kPresentFragmentShader = R"(#version 300 es
precision highp float;
in  vec2 vUv;
out vec4 outColor;
uniform sampler2D uCurrent;
uniform sampler2D uOld;
uniform float uMixT;  // 0 = all old, 1 = all current
void main() {
    vec4 cur = texture(uCurrent, vUv);
    if (uMixT >= 1.0) {
        outColor = cur;
        return;
    }
    vec4 old = texture(uOld, vUv);
    outColor = mix(old, cur, uMixT);
}
)";

GLuint compileShader(GLenum kind, const char* src) {
    GLuint s = glCreateShader(kind);
    glShaderSource(s, 1, &src, nullptr);
    glCompileShader(s);
    GLint status = GL_FALSE;
    glGetShaderiv(s, GL_COMPILE_STATUS, &status);
    if (status != GL_TRUE) {
        GLint logLen = 0;
        glGetShaderiv(s, GL_INFO_LOG_LENGTH, &logLen);
        std::string log(static_cast<std::size_t>(logLen) + 1, '\0');
        glGetShaderInfoLog(s, logLen, nullptr, log.data());
        LOGE("shader compile error (%s):\n%s",
             kind == GL_VERTEX_SHADER ? "vert" : "frag", log.c_str());
        glDeleteShader(s);
        return 0;
    }
    return s;
}

GLuint linkProgram(GLuint vs, GLuint fs) {
    GLuint p = glCreateProgram();
    glAttachShader(p, vs);
    glAttachShader(p, fs);
    glLinkProgram(p);
    GLint linked = GL_FALSE;
    glGetProgramiv(p, GL_LINK_STATUS, &linked);
    if (linked != GL_TRUE) {
        GLint logLen = 0;
        glGetProgramiv(p, GL_INFO_LOG_LENGTH, &logLen);
        std::string log(static_cast<std::size_t>(logLen) + 1, '\0');
        glGetProgramInfoLog(p, logLen, nullptr, log.data());
        LOGE("program link error:\n%s", log.c_str());
        glDeleteProgram(p);
        return 0;
    }
    return p;
}

// Allocate a color-only RGBA8 texture + FBO at the given size.
// Returns true on success.
bool createColorFbo(int w, int h, GLuint* fbo, GLuint* tex) {
    glGenTextures(1, tex);
    glBindTexture(GL_TEXTURE_2D, *tex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, w, h, 0, GL_RGBA,
                  GL_UNSIGNED_BYTE, nullptr);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    glGenFramebuffers(1, fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, *fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                            GL_TEXTURE_2D, *tex, 0);
    const GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        LOGE("FBO incomplete: 0x%x", status);
        glDeleteFramebuffers(1, fbo);
        glDeleteTextures(1, tex);
        *fbo = 0;
        *tex = 0;
        return false;
    }
    return true;
}

} // namespace

ShaderEngine::~ShaderEngine() {
    // Stop the worker first so it doesn't try to touch GL during
    // teardown. Worker may have a context-current state that needs
    // unwinding cleanly.
    workerShutdown_ = true;
    {
        std::lock_guard<std::mutex> lock(queueMutex_);
        queueCv_.notify_all();
    }
    if (worker_.joinable()) worker_.join();
    teardownSharedContext();

    {
        std::lock_guard<std::mutex> lock(resultMutex_);
        if (pendingProgram_) {
            glDeleteProgram(pendingProgram_);
            pendingProgram_ = 0;
        }
    }

    teardownOffscreenTargets();
    if (presentProgram_) glDeleteProgram(presentProgram_);
    if (program_) glDeleteProgram(program_);
    if (vao_) glDeleteVertexArrays(1, &vao_);
    if (vbo_) glDeleteBuffers(1, &vbo_);
    audio_.dispose();
}

bool ShaderEngine::init(int width, int height) {
    width_ = width;
    height_ = height;
    startTime_ = std::chrono::steady_clock::now();
    lastFrameTime_ = startTime_;
    transitionStart_ = startTime_;
    frameCount_ = 0;

    // Fullscreen-triangle VBO/VAO — shared by the user shader pass
    // and the present pass.
    const float verts[] = {
        -1.0f, -1.0f,
         3.0f, -1.0f,
        -1.0f,  3.0f,
    };
    glGenVertexArrays(1, &vao_);
    glGenBuffers(1, &vbo_);
    glBindVertexArray(vao_);
    glBindBuffer(GL_ARRAY_BUFFER, vbo_);
    glBufferData(GL_ARRAY_BUFFER, sizeof(verts), verts, GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, nullptr);
    glBindVertexArray(0);

    if (!audio_.init()) {
        LOGE("audio texture init failed");
        return false;
    }

    if (!setupOffscreenTargets()) {
        LOGE("offscreen target setup failed");
        return false;
    }

    // Compile the present-pass program once at init.
    {
        GLuint vs = compileShader(GL_VERTEX_SHADER, kPresentVertexShader);
        GLuint fs = compileShader(GL_FRAGMENT_SHADER, kPresentFragmentShader);
        if (!vs || !fs) {
            if (vs) glDeleteShader(vs);
            if (fs) glDeleteShader(fs);
            LOGE("present shader compile failed");
            return false;
        }
        presentProgram_ = linkProgram(vs, fs);
        glDeleteShader(vs);
        glDeleteShader(fs);
        if (!presentProgram_) return false;
        locPresentCurrent_ = glGetUniformLocation(presentProgram_, "uCurrent");
        locPresentOld_ = glGetUniformLocation(presentProgram_, "uOld");
        locPresentMixT_ = glGetUniformLocation(presentProgram_, "uMixT");
    }

    if (!setupSharedContext()) {
        LOGE("shared EGL context setup failed — compile will fall back to sync");
        // Fail soft: the engine still works, just synchronously.
    } else {
        worker_ = std::thread(&ShaderEngine::workerLoop, this);
    }

    LOGI("ShaderEngine init ok %dx%d", width, height);
    return true;
}

bool ShaderEngine::setupOffscreenTargets() {
    if (!createColorFbo(width_, height_, &fboCurrent_, &texCurrent_)) {
        return false;
    }
    if (!createColorFbo(width_, height_, &fboOld_, &texOld_)) {
        // Free the first if the second failed.
        glDeleteFramebuffers(1, &fboCurrent_);
        glDeleteTextures(1, &texCurrent_);
        fboCurrent_ = 0;
        texCurrent_ = 0;
        return false;
    }
    // Initialise both to black so the first frame doesn't sample
    // undefined memory.
    glBindFramebuffer(GL_FRAMEBUFFER, fboCurrent_);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    glBindFramebuffer(GL_FRAMEBUFFER, fboOld_);
    glClear(GL_COLOR_BUFFER_BIT);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    return true;
}

void ShaderEngine::teardownOffscreenTargets() {
    if (fboCurrent_) { glDeleteFramebuffers(1, &fboCurrent_); fboCurrent_ = 0; }
    if (texCurrent_) { glDeleteTextures(1, &texCurrent_); texCurrent_ = 0; }
    if (fboOld_) { glDeleteFramebuffers(1, &fboOld_); fboOld_ = 0; }
    if (texOld_) { glDeleteTextures(1, &texOld_); texOld_ = 0; }
}

bool ShaderEngine::setupSharedContext() {
    EGLDisplay display = eglGetCurrentDisplay();
    EGLContext mainCtx = eglGetCurrentContext();
    if (display == EGL_NO_DISPLAY || mainCtx == EGL_NO_CONTEXT) {
        LOGE("no current EGL display/context — cannot share");
        return false;
    }

    const EGLint configAttrs[] = {
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
        EGL_SURFACE_TYPE,    EGL_PBUFFER_BIT,
        EGL_RED_SIZE,   8,
        EGL_GREEN_SIZE, 8,
        EGL_BLUE_SIZE,  8,
        EGL_ALPHA_SIZE, 8,
        EGL_NONE,
    };
    EGLConfig config = nullptr;
    EGLint numConfigs = 0;
    if (!eglChooseConfig(display, configAttrs, &config, 1, &numConfigs)
        || numConfigs < 1) {
        LOGE("worker eglChooseConfig failed: 0x%x", eglGetError());
        return false;
    }

    const EGLint pbAttrs[] = { EGL_WIDTH, 1, EGL_HEIGHT, 1, EGL_NONE };
    workerSurface_ = eglCreatePbufferSurface(display, config, pbAttrs);
    if (workerSurface_ == EGL_NO_SURFACE) {
        LOGE("worker eglCreatePbufferSurface failed: 0x%x", eglGetError());
        return false;
    }

    const EGLint ctxAttrs[] = { EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE };
    workerCtx_ = eglCreateContext(display, config, mainCtx, ctxAttrs);
    if (workerCtx_ == EGL_NO_CONTEXT) {
        LOGE("worker eglCreateContext (shared) failed: 0x%x", eglGetError());
        eglDestroySurface(display, workerSurface_);
        workerSurface_ = EGL_NO_SURFACE;
        return false;
    }

    workerDisplay_ = display;
    return true;
}

void ShaderEngine::teardownSharedContext() {
    if (workerDisplay_ == EGL_NO_DISPLAY) return;
    if (workerCtx_ != EGL_NO_CONTEXT) {
        eglDestroyContext(workerDisplay_, workerCtx_);
        workerCtx_ = EGL_NO_CONTEXT;
    }
    if (workerSurface_ != EGL_NO_SURFACE) {
        eglDestroySurface(workerDisplay_, workerSurface_);
        workerSurface_ = EGL_NO_SURFACE;
    }
    workerDisplay_ = EGL_NO_DISPLAY;
}

ShaderEngine::UniformLocs ShaderEngine::queryUniformLocations(GLuint program) {
    UniformLocs u;
    u.time = glGetUniformLocation(program, "iTime");
    u.timeDelta = glGetUniformLocation(program, "iTimeDelta");
    u.frame = glGetUniformLocation(program, "iFrame");
    u.resolution = glGetUniformLocation(program, "iResolution");
    u.mouse = glGetUniformLocation(program, "iMouse");
    u.channel0 = glGetUniformLocation(program, "iChannel0");
    u.channelTime = glGetUniformLocation(program, "iChannelTime[0]");
    u.channelResolution = glGetUniformLocation(program, "iChannelResolution[0]");
    u.date = glGetUniformLocation(program, "iDate");
    u.sampleRate = glGetUniformLocation(program, "iSampleRate");
    return u;
}

GLuint ShaderEngine::compileProgramOnCurrentContext(
        const std::string& fragSource) {
    GLuint vs = compileShader(GL_VERTEX_SHADER, kVertexShader);
    if (!vs) return 0;

    std::string full(kFragPrelude);
    full.append(fragSource);
    GLuint fs = compileShader(GL_FRAGMENT_SHADER, full.c_str());
    if (!fs) {
        glDeleteShader(vs);
        return 0;
    }

    GLuint p = linkProgram(vs, fs);
    glDeleteShader(vs);
    glDeleteShader(fs);
    return p;
}

void ShaderEngine::workerLoop() {
    if (!eglMakeCurrent(workerDisplay_, workerSurface_, workerSurface_,
                         workerCtx_)) {
        LOGE("worker eglMakeCurrent failed: 0x%x — exiting worker",
             eglGetError());
        return;
    }
    LOGI("shader compile worker ready");

    while (true) {
        std::string source;
        {
            std::unique_lock<std::mutex> lock(queueMutex_);
            queueCv_.wait(lock, [this] {
                return workerShutdown_.load() || hasPendingSource_;
            });
            if (workerShutdown_.load()) break;
            source = std::move(pendingSource_);
            hasPendingSource_ = false;
        }

        GLuint newProgram = compileProgramOnCurrentContext(source);
        if (newProgram == 0) continue;

        glFlush();

        GLuint orphan = 0;
        {
            std::lock_guard<std::mutex> lock(resultMutex_);
            orphan = pendingProgram_;
            pendingProgram_ = newProgram;
        }
        if (orphan) glDeleteProgram(orphan);
    }

    eglMakeCurrent(workerDisplay_, EGL_NO_SURFACE, EGL_NO_SURFACE,
                    EGL_NO_CONTEXT);
    LOGI("shader compile worker exited");
}

bool ShaderEngine::adoptPendingProgramIfAny() {
    GLuint adopt = 0;
    {
        std::lock_guard<std::mutex> lock(resultMutex_);
        if (pendingProgram_ != 0) {
            adopt = pendingProgram_;
            pendingProgram_ = 0;
        }
    }
    if (!adopt) return false;

    // Capture the current frame into the "old" FBO before swapping
    // shaders. glBlitFramebuffer is the fastest way to copy texture
    // contents between two FBOs of the same size.
    if (program_ && fboCurrent_ && fboOld_) {
        glBindFramebuffer(GL_READ_FRAMEBUFFER, fboCurrent_);
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, fboOld_);
        glBlitFramebuffer(0, 0, width_, height_,
                           0, 0, width_, height_,
                           GL_COLOR_BUFFER_BIT, GL_NEAREST);
        glBindFramebuffer(GL_READ_FRAMEBUFFER, 0);
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
    }

    if (program_) glDeleteProgram(program_);
    program_ = adopt;
    locs_ = queryUniformLocations(program_);
    LOGI("adopted new shader program=%u", program_);

    // Start the crossfade. If this is the very first preset (no old
    // program), skip the transition — there's nothing to fade from.
    transitionStart_ = std::chrono::steady_clock::now();
    transitioning_ = (fboOld_ != 0);
    return true;
}

void ShaderEngine::renderFrame() {
    adoptPendingProgramIfAny();

    auto now = std::chrono::steady_clock::now();
    const float elapsed =
        std::chrono::duration<float>(now - startTime_).count();
    const float delta =
        std::chrono::duration<float>(now - lastFrameTime_).count();
    lastFrameTime_ = now;

    // === Pass 1: user shader → fboCurrent_ ===
    glBindFramebuffer(GL_FRAMEBUFFER, fboCurrent_);
    glViewport(0, 0, width_, height_);

    if (!program_) {
        // No shader compiled yet — clear the FBO so present has
        // something defined to sample.
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
    } else {
        const GLuint audioTex = audio_.upload();

        glUseProgram(program_);

        if (locs_.time       >= 0) glUniform1f(locs_.time, elapsed);
        if (locs_.timeDelta  >= 0) glUniform1f(locs_.timeDelta, delta);
        if (locs_.frame      >= 0) glUniform1i(locs_.frame, frameCount_);
        if (locs_.resolution >= 0) glUniform3f(locs_.resolution,
            static_cast<float>(width_),
            static_cast<float>(height_),
            static_cast<float>(width_) / static_cast<float>(height_));
        if (locs_.mouse      >= 0) glUniform4f(locs_.mouse, 0.0f, 0.0f, 0.0f, 0.0f);
        if (locs_.date       >= 0) glUniform4f(locs_.date, 0.0f, 0.0f, 0.0f, 0.0f);
        if (locs_.sampleRate >= 0) glUniform1f(locs_.sampleRate, 44100.0f);

        if (locs_.channelTime >= 0) {
            const float times[4] = { elapsed, elapsed, elapsed, elapsed };
            glUniform1fv(locs_.channelTime, 4, times);
        }
        if (locs_.channelResolution >= 0) {
            const float res[12] = {
                static_cast<float>(AudioTexture::BINS), 2.0f, 1.0f,
                0.0f, 0.0f, 0.0f,
                0.0f, 0.0f, 0.0f,
                0.0f, 0.0f, 0.0f,
            };
            glUniform3fv(locs_.channelResolution, 4, res);
        }

        if (locs_.channel0 >= 0) {
            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, audioTex);
            glUniform1i(locs_.channel0, 0);
        }

        glBindVertexArray(vao_);
        glDrawArrays(GL_TRIANGLES, 0, 3);
        glBindVertexArray(0);
    }

    // === Pass 2: present (texCurrent_ ± texOld_) → window surface ===
    float mixT = 1.0f;
    if (transitioning_) {
        const float t = std::chrono::duration<float>(now - transitionStart_)
                            .count() / kTransitionDuration;
        if (t >= 1.0f) {
            transitioning_ = false;
            mixT = 1.0f;
        } else {
            // Smoothstep ease — feels more natural than linear.
            mixT = t * t * (3.0f - 2.0f * t);
        }
    }

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glViewport(0, 0, width_, height_);
    glUseProgram(presentProgram_);

    if (locPresentCurrent_ >= 0) {
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, texCurrent_);
        glUniform1i(locPresentCurrent_, 0);
    }
    if (locPresentOld_ >= 0) {
        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, texOld_);
        glUniform1i(locPresentOld_, 1);
    }
    if (locPresentMixT_ >= 0) glUniform1f(locPresentMixT_, mixT);

    glBindVertexArray(vao_);
    glDrawArrays(GL_TRIANGLES, 0, 3);
    glBindVertexArray(0);

    ++frameCount_;
}

void ShaderEngine::addPcm(const float* samples, std::size_t frameCount) {
    audio_.addPcm(samples, frameCount);
}

void ShaderEngine::loadPreset(const char* data, bool /*smoothTransition*/) {
    if (!data) return;

    // If the worker thread couldn't be started, compile synchronously
    // on the render thread (slow but correct).
    if (!worker_.joinable()) {
        GLuint newProgram =
            compileProgramOnCurrentContext(std::string(data));
        if (newProgram == 0) return;

        // Snapshot the current frame into the "old" FBO so the
        // crossfade has something to fade from. Same as the async path.
        if (program_ && fboCurrent_ && fboOld_) {
            glBindFramebuffer(GL_READ_FRAMEBUFFER, fboCurrent_);
            glBindFramebuffer(GL_DRAW_FRAMEBUFFER, fboOld_);
            glBlitFramebuffer(0, 0, width_, height_,
                               0, 0, width_, height_,
                               GL_COLOR_BUFFER_BIT, GL_NEAREST);
            glBindFramebuffer(GL_READ_FRAMEBUFFER, 0);
            glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
        }

        if (program_) glDeleteProgram(program_);
        program_ = newProgram;
        locs_ = queryUniformLocations(program_);
        transitionStart_ = std::chrono::steady_clock::now();
        transitioning_ = (fboOld_ != 0);
        return;
    }

    // Async path: queue the source. Only the LATEST source survives.
    {
        std::lock_guard<std::mutex> lock(queueMutex_);
        pendingSource_ = data;
        hasPendingSource_ = true;
    }
    queueCv_.notify_one();
}
