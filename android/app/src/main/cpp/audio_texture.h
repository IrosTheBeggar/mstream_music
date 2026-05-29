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
//
// The spectrum row follows the Web Audio AnalyserNode / Shadertoy
// convention the bundled shaders were authored against: the FFT
// magnitude is normalized to source amplitude (so it's independent of
// FFT size / window), EMA-smoothed in the linear domain to stop the
// bars strobing, then mapped through a dB window to [0,1]. This
// replaces the old uncalibrated log1p() curve that clipped the low
// bins to white and forced every shader to pre-attenuate. Tuning
// constants live at the top of audio_texture.cpp.

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

    // Live-tune the spectrum response curve (see upload()). Safe to call
    // from a thread other than upload()'s — these are plain float writes
    // and a torn read just means one stale frame, which is fine for a
    // visual control. Invalid windows (maxDb <= minDb) are ignored.
    void setParams(float minDb, float maxDb, float smoothing);

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
    std::vector<float> smoothedMag_;  // BINS — EMA of normalized magnitude (linear)

    // Amplitude normalization derived from the window (computed in ctor).
    // |X[k]| for a tone of amplitude A is A/2 · Σw, so 2/Σw recovers A
    // (0 dB == full-scale single-bin tone), independent of FFT_SIZE.
    float windowSum_ = 0.0f;          // Σ hannWindow_
    float normScale_ = 0.0f;          // 2 / windowSum_

    // Set by addPcm(), cleared by upload(); lets upload() skip the FFT
    // when no new PCM arrived (render ~60 Hz outpaces PCM ~30 Hz, so
    // this elides about half the FFTs).
    bool dirty_ = false;

    // Response-curve params, tunable at runtime via setParams(). Defaults
    // are the Web Audio / Shadertoy-style curve we calibrated; the in-app
    // tuning panel overrides them. See upload() for how they're applied.
    float minDb_ = -69.7f;
    float maxDb_ = -20.7f;
    float smoothing_ = 0.27f;
};
