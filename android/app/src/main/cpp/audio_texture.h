// Builds the 512×2 R8 audio texture that Shadertoy-convention shaders
// sample via iChannel0. Row 0 (bottom) holds an FFT magnitude
// spectrum; row 1 (top) holds the recent raw waveform.
//
// Sampling convention (Shadertoy):
//   texture(iChannel0, vec2(freq, 0.25)).r  →  FFT at frequency bin freq
//   texture(iChannel0, vec2(t,    0.75)).r  →  Waveform sample at offset t
//
// PCM in is interleaved stereo. We mix L+R to mono and keep a 2048-
// sample ring buffer; per upload, we take the most recent 1024 samples,
// window them, FFT, and write 512 mag bins + 512 waveform samples.

#pragma once

#include <GLES3/gl3.h>
#include <cstddef>
#include <vector>

struct kiss_fftr_state;
typedef struct kiss_fftr_state* kiss_fftr_cfg;

class AudioTexture {
public:
    static constexpr int FFT_SIZE = 1024;   // power of 2, real-FFT input
    static constexpr int BINS = 512;        // FFT_SIZE / 2 — width of texture
    static constexpr int RING_SIZE = 2048;  // rolling mono buffer

    AudioTexture();
    ~AudioTexture();

    // Allocates the GL texture + FFT state. Requires a current EGL context.
    bool init();
    void dispose();

    // Push interleaved stereo PCM. Frames are L,R pairs. Thread-safe
    // against `upload()` only at the level of "atomic write index";
    // we expect the caller (render thread) to call both from the same
    // thread.
    void addPcm(const float* samples, std::size_t frameCount);

    // Run FFT on the latest window and upload the texture. Call once
    // per frame. Returns the GL texture name.
    GLuint upload();

    GLuint texture() const { return tex_; }

private:
    GLuint tex_ = 0;
    kiss_fftr_cfg fft_ = nullptr;

    // Ring buffer of mono samples (L+R mixed, /2). Older samples
    // overwritten as new ones arrive.
    float ring_[RING_SIZE]{};
    std::size_t ringHead_ = 0;

    // Scratch buffers reused per upload.
    std::vector<float> windowed_;     // FFT_SIZE
    std::vector<float> hannWindow_;   // FFT_SIZE, precomputed
    std::vector<uint8_t> texBytes_;   // BINS * 2 (one row of FFT, one of waveform)
};
