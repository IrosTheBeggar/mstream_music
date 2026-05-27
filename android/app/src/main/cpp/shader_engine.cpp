#include "shader_engine.h"

#include <android/log.h>
#include <cstring>
#include <string>

#define LOG_TAG "mstream/viz-bridge"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace {

// Vertex shader — a fullscreen triangle. Coordinates chosen so that a
// single triangle covers the entire viewport without needing a quad
// (saves us an index buffer).
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
    releaseProgram();
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

    // Fullscreen-triangle VBO/VAO. Three vertices covering NDC.
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

    LOGI("ShaderEngine init ok %dx%d", width, height);
    return true;
}

bool ShaderEngine::compileProgram(const char* fragSource) {
    GLuint vs = compileShader(GL_VERTEX_SHADER, kVertexShader);
    if (!vs) return false;

    std::string fullFrag(kFragPrelude);
    fullFrag.append(fragSource ? fragSource : "");
    GLuint fs = compileShader(GL_FRAGMENT_SHADER, fullFrag.c_str());
    if (!fs) {
        glDeleteShader(vs);
        return false;
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
        return false;
    }

    releaseProgram();
    program_ = p;

    locTime_ = glGetUniformLocation(p, "iTime");
    locTimeDelta_ = glGetUniformLocation(p, "iTimeDelta");
    locFrame_ = glGetUniformLocation(p, "iFrame");
    locResolution_ = glGetUniformLocation(p, "iResolution");
    locMouse_ = glGetUniformLocation(p, "iMouse");
    locChannel0_ = glGetUniformLocation(p, "iChannel0");
    locChannelTime_ = glGetUniformLocation(p, "iChannelTime[0]");
    locChannelResolution_ =
        glGetUniformLocation(p, "iChannelResolution[0]");
    locDate_ = glGetUniformLocation(p, "iDate");
    locSampleRate_ = glGetUniformLocation(p, "iSampleRate");

    LOGI("shader program linked ok program=%u", program_);
    return true;
}

void ShaderEngine::releaseProgram() {
    if (program_) {
        glDeleteProgram(program_);
        program_ = 0;
    }
}

void ShaderEngine::renderFrame() {
    if (!program_) {
        // No shader loaded yet — clear to black so the user sees
        // *something* and the surface isn't undefined.
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        return;
    }

    // Push the latest audio frame into iChannel0.
    const GLuint audioTex = audio_.upload();

    // Compute timing uniforms.
    auto now = std::chrono::steady_clock::now();
    const float elapsed =
        std::chrono::duration<float>(now - startTime_).count();
    const float delta =
        std::chrono::duration<float>(now - lastFrameTime_).count();
    lastFrameTime_ = now;

    glViewport(0, 0, width_, height_);
    glUseProgram(program_);

    if (locTime_       >= 0) glUniform1f(locTime_, elapsed);
    if (locTimeDelta_  >= 0) glUniform1f(locTimeDelta_, delta);
    if (locFrame_      >= 0) glUniform1i(locFrame_, frameCount_);
    if (locResolution_ >= 0) glUniform3f(locResolution_,
        static_cast<float>(width_),
        static_cast<float>(height_),
        static_cast<float>(width_) / static_cast<float>(height_));
    if (locMouse_      >= 0) glUniform4f(locMouse_, 0.0f, 0.0f, 0.0f, 0.0f);
    if (locDate_       >= 0) glUniform4f(locDate_, 0.0f, 0.0f, 0.0f, 0.0f);
    if (locSampleRate_ >= 0) glUniform1f(locSampleRate_, 44100.0f);

    if (locChannelTime_ >= 0) {
        const float times[4] = { elapsed, elapsed, elapsed, elapsed };
        glUniform1fv(locChannelTime_, 4, times);
    }
    if (locChannelResolution_ >= 0) {
        const float res[12] = {
            static_cast<float>(AudioTexture::BINS), 2.0f, 1.0f,
            0.0f, 0.0f, 0.0f,
            0.0f, 0.0f, 0.0f,
            0.0f, 0.0f, 0.0f,
        };
        glUniform3fv(locChannelResolution_, 4, res);
    }

    if (locChannel0_ >= 0) {
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, audioTex);
        glUniform1i(locChannel0_, 0);
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
    // We don't currently animate a transition between shaders — the
    // swap is instant. smoothTransition is accepted for API parity
    // with ProjectMEngine.
    compileProgram(data);
}
