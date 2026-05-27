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

    // Free any program that arrived just before shutdown and never
    // got adopted by the render thread.
    {
        std::lock_guard<std::mutex> lock(resultMutex_);
        if (pendingProgram_) {
            glDeleteProgram(pendingProgram_);
            pendingProgram_ = 0;
        }
    }

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
    frameCount_ = 0;

    // Fullscreen-triangle VBO/VAO.
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

    if (!setupSharedContext()) {
        LOGE("shared EGL context setup failed — compile will fall back to sync");
        // Fail soft: the engine still works, just synchronously.
    } else {
        worker_ = std::thread(&ShaderEngine::workerLoop, this);
    }

    LOGI("ShaderEngine init ok %dx%d", width, height);
    return true;
}

bool ShaderEngine::setupSharedContext() {
    EGLDisplay display = eglGetCurrentDisplay();
    EGLContext mainCtx = eglGetCurrentContext();
    if (display == EGL_NO_DISPLAY || mainCtx == EGL_NO_CONTEXT) {
        LOGE("no current EGL display/context — cannot share");
        return false;
    }

    // Choose a config compatible with the main context that also
    // supports PBuffer surfaces (the worker needs *some* surface to
    // make its context current, even if it never renders to one).
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

    GLuint p = glCreateProgram();
    glAttachShader(p, vs);
    glAttachShader(p, fs);
    glLinkProgram(p);
    glDeleteShader(vs);
    glDeleteShader(fs);

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

        // Make sure the program object is fully realized before the
        // render thread tries to use it from the other context.
        glFlush();

        // Hand off. If a previous program is still waiting to be
        // adopted, the render thread missed its window — free it
        // here so it doesn't leak.
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

void ShaderEngine::adoptPendingProgramIfAny() {
    GLuint adopt = 0;
    {
        std::lock_guard<std::mutex> lock(resultMutex_);
        if (pendingProgram_ != 0) {
            adopt = pendingProgram_;
            pendingProgram_ = 0;
        }
    }
    if (!adopt) return;

    // Free the old current program. Programs are shared between the
    // worker and render contexts (created via shared context), so
    // we can delete from either side.
    if (program_) glDeleteProgram(program_);
    program_ = adopt;
    locs_ = queryUniformLocations(program_);
    LOGI("adopted new shader program=%u", program_);
}

void ShaderEngine::renderFrame() {
    adoptPendingProgramIfAny();

    if (!program_) {
        // No shader loaded yet — clear to black so the user sees
        // *something* and the surface isn't undefined.
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        return;
    }

    const GLuint audioTex = audio_.upload();

    auto now = std::chrono::steady_clock::now();
    const float elapsed =
        std::chrono::duration<float>(now - startTime_).count();
    const float delta =
        std::chrono::duration<float>(now - lastFrameTime_).count();
    lastFrameTime_ = now;

    glViewport(0, 0, width_, height_);
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

    ++frameCount_;
}

void ShaderEngine::addPcm(const float* samples, std::size_t frameCount) {
    audio_.addPcm(samples, frameCount);
}

void ShaderEngine::loadPreset(const char* data, bool /*smoothTransition*/) {
    if (!data) return;

    // If the worker thread couldn't be started (shared context
    // failed), fall back to compiling synchronously on the render
    // thread — slower but correct.
    if (!worker_.joinable()) {
        GLuint newProgram =
            compileProgramOnCurrentContext(std::string(data));
        if (newProgram == 0) return;
        if (program_) glDeleteProgram(program_);
        program_ = newProgram;
        locs_ = queryUniformLocations(program_);
        return;
    }

    // Queue the source. We only keep the LATEST source — if the user
    // taps faster than compile time, intermediate selections are
    // dropped. The worker drains exactly one source per cycle.
    {
        std::lock_guard<std::mutex> lock(queueMutex_);
        pendingSource_ = data;
        hasPendingSource_ = true;
    }
    queueCv_.notify_one();
}
