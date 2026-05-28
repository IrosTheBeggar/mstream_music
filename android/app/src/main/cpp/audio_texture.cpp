#include "audio_texture.h"

#include "kissfft/kiss_fftr.h"

#include <android/log.h>
#include <cmath>
#include <cstring>

#define LOG_TAG "mstream/viz-bridge"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

AudioTexture::AudioTexture()
    : windowed_(FFT_SIZE, 0.0f),
      hannWindow_(FFT_SIZE, 0.0f),
      texBytes_(BINS * 2, 0) {
    // Precompute the Hann window. Used to taper the FFT input so we
    // don't get spectral leakage from the rectangular edges.
    for (int i = 0; i < FFT_SIZE; ++i) {
        hannWindow_[i] =
            0.5f * (1.0f - std::cos(2.0f * 3.14159265358979f *
                                     static_cast<float>(i) /
                                     static_cast<float>(FFT_SIZE - 1)));
    }
}

AudioTexture::~AudioTexture() {
    dispose();
}

bool AudioTexture::init() {
    fft_ = kiss_fftr_alloc(FFT_SIZE, 0 /*inverse=false*/, nullptr, nullptr);
    if (!fft_) {
        LOGE("kiss_fftr_alloc failed");
        return false;
    }

    glGenTextures(1, &tex_);
    glBindTexture(GL_TEXTURE_2D, tex_);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_R8, BINS, 2, 0, GL_RED,
                  GL_UNSIGNED_BYTE, nullptr);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);
    return true;
}

void AudioTexture::dispose() {
    if (tex_) {
        glDeleteTextures(1, &tex_);
        tex_ = 0;
    }
    if (fft_) {
        kiss_fftr_free(fft_);
        fft_ = nullptr;
    }
}

void AudioTexture::addPcm(const float* samples, std::size_t frameCount) {
    if (!samples || frameCount == 0) return;
    // Mix L+R to mono and write into the ring.
    for (std::size_t i = 0; i < frameCount; ++i) {
        const float mono = 0.5f * (samples[2 * i] + samples[2 * i + 1]);
        ring_[ringHead_] = mono;
        ringHead_ = (ringHead_ + 1) % RING_SIZE;
    }
}

GLuint AudioTexture::upload() {
    if (!tex_ || !fft_) return 0;

    // Pull the most recent FFT_SIZE samples from the ring (in order).
    // ringHead_ points at the next write slot, so the newest sample is
    // at (ringHead_ - 1) and the oldest of the FFT window is at
    // (ringHead_ - FFT_SIZE).
    const std::size_t start = (ringHead_ + RING_SIZE - FFT_SIZE) % RING_SIZE;
    for (int i = 0; i < FFT_SIZE; ++i) {
        const float s = ring_[(start + i) % RING_SIZE];
        windowed_[i] = s * hannWindow_[i];
    }

    // Real FFT — outputs FFT_SIZE/2 + 1 complex bins. We use the first
    // BINS (== FFT_SIZE/2), drop the DC bin convention's mirroring.
    kiss_fft_cpx out[BINS + 1];
    kiss_fftr(fft_, windowed_.data(), out);

    // Magnitude → 0..255. Empirical scale to spread typical music
    // amplitudes across the byte range without aggressive clipping;
    // shaders can scale up further. log1p compresses dynamic range
    // similar to what Shadertoy's audio channel does.
    for (int i = 0; i < BINS; ++i) {
        const float re = out[i].r;
        const float im = out[i].i;
        const float mag = std::sqrt(re * re + im * im);
        const float compressed = std::log1p(mag * 4.0f) * 0.4f;
        const float clamped = compressed > 1.0f ? 1.0f : compressed;
        texBytes_[i] = static_cast<uint8_t>(clamped * 255.0f);
    }

    // Waveform row — most recent BINS samples mapped from [-1,1] to [0,255].
    const std::size_t waveStart =
        (ringHead_ + RING_SIZE - BINS) % RING_SIZE;
    for (int i = 0; i < BINS; ++i) {
        const float s = ring_[(waveStart + i) % RING_SIZE];
        const float n = 0.5f + 0.5f * (s > 1.0f ? 1.0f : (s < -1.0f ? -1.0f : s));
        texBytes_[BINS + i] = static_cast<uint8_t>(n * 255.0f);
    }

    glBindTexture(GL_TEXTURE_2D, tex_);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, BINS, 2, GL_RED,
                     GL_UNSIGNED_BYTE, texBytes_.data());
    return tex_;
}
