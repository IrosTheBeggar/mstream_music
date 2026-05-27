// Engine that renders Shadertoy-convention fragment shaders.
//
// loadPreset() takes a GLSL fragment shader source that defines:
//
//     void mainImage(out vec4 fragColor, in vec2 fragCoord);
//
// We wrap it with a Shadertoy-style prelude (iTime, iResolution,
// iChannel0, etc.) and a tiny main() that calls mainImage and writes
// the result. Compilation happens on loadPreset(); errors are
// logged but render falls back to the previous program (or no-op).
//
// Audio reactivity: we run a 1024-point FFT on incoming PCM and
// publish a 512×2 R8 texture bound to iChannel0 — same shape
// Shadertoy itself uses for audio channels.

#pragma once

#include <GLES3/gl3.h>
#include <chrono>
#include <memory>

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
    bool compileProgram(const char* fragSource);
    void releaseProgram();

    int width_ = 0;
    int height_ = 0;

    GLuint program_ = 0;
    GLuint vao_ = 0;
    GLuint vbo_ = 0;

    // Cached uniform locations for the current program.
    GLint locTime_ = -1;
    GLint locTimeDelta_ = -1;
    GLint locFrame_ = -1;
    GLint locResolution_ = -1;
    GLint locMouse_ = -1;
    GLint locChannel0_ = -1;
    GLint locChannelTime_ = -1;
    GLint locChannelResolution_ = -1;
    GLint locDate_ = -1;
    GLint locSampleRate_ = -1;

    std::chrono::steady_clock::time_point startTime_;
    std::chrono::steady_clock::time_point lastFrameTime_;
    int frameCount_ = 0;

    AudioTexture audio_;
};
