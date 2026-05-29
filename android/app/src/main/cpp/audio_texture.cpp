#include "audio_texture.h"

#include "kissfft/kiss_fftr.h"

#include <android/log.h>
#include <cmath>
#include <cstring>

#define LOG_TAG "mstream/viz-bridge"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Response-curve note (see AudioTexture::upload and the minDb_/maxDb_/
// smoothing_ fields): the spectrum bytes are produced by normalize FFT
// magnitude to source amplitude → EMA-smooth (linear domain) → map a dB
// window to [0,1]. This mirrors the Web Audio AnalyserNode / Shadertoy
// convention the bundled shaders were authored against. The three knobs
// are runtime-tunable via setParams() (the in-app tuning panel):
//   minDb / maxDb : dB window mapped onto [0,1]. Lower minDb surfaces more
//                   low-level detail; raise maxDb if loud passages clip to
//                   white. (0 dB == a full-scale tone in a single bin.)
//   smoothing     : temporal EMA. 0 = raw (flickery), 0.8 = Web Audio
//                   default. Higher = smoother but laggier bars.

AudioTexture::AudioTexture()
    : windowed_(FFT_SIZE, 0.0f),
      hannWindow_(FFT_SIZE, 0.0f),
      texBytes_(BINS * 2, 0),
      smoothedMag_(BINS, 0.0f) {
    // Precompute the Hann window. Used to taper the FFT input so we
    // don't get spectral leakage from the rectangular edges.
    for (int i = 0; i < FFT_SIZE; ++i) {
        hannWindow_[i] =
            0.5f * (1.0f - std::cos(2.0f * 3.14159265358979f *
                                     static_cast<float>(i) /
                                     static_cast<float>(FFT_SIZE - 1)));
        windowSum_ += hannWindow_[i];
    }
    // Maps raw |X[k]| to the source amplitude A (see header). Guard the
    // degenerate window so we never divide by zero.
    normScale_ = (windowSum_ > 0.0f) ? (2.0f / windowSum_) : 1.0f;
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
    // Seed with the zero-initialized byte buffer so the texture has
    // defined (silent) contents before the first PCM arrives — upload()
    // now skips frames with no new audio, so frame 0 may sample this.
    glTexImage2D(GL_TEXTURE_2D, 0, GL_R8, BINS, 2, 0, GL_RED,
                  GL_UNSIGNED_BYTE, texBytes_.data());
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
    dirty_ = true;
}

void AudioTexture::setParams(float minDb, float maxDb, float smoothing) {
    // Reject an inverted/zero window (would divide by zero or flip the
    // mapping); leave the previous values in place if so.
    if (maxDb > minDb) {
        minDb_ = minDb;
        maxDb_ = maxDb;
    }
    smoothing_ = smoothing < 0.0f ? 0.0f
               : (smoothing > 0.99f ? 0.99f : smoothing);
}

GLuint AudioTexture::upload() {
    if (!tex_ || !fft_) return 0;

    // No new PCM since the last upload? The texture already holds the
    // current spectrum/waveform — skip the FFT and the re-upload.
    if (!dirty_) return tex_;
    dirty_ = false;

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

    // Spectrum row → 0..255. Normalize the raw FFT magnitude to source
    // amplitude (normScale_), EMA-smooth it in the linear domain so the
    // bars don't strobe, then map a dB window onto [0,1]. dB compression
    // spreads musical dynamics perceptually and — unlike the old
    // log1p(mag*4)*0.4 — leaves headroom so loud low bins no longer peg
    // to white. This matches the Web Audio / Shadertoy convention, so the
    // bundled shaders see the response curve they were authored for.
    const float dbRange = maxDb_ - minDb_;
    for (int i = 0; i < BINS; ++i) {
        const float re = out[i].r;
        const float im = out[i].i;
        const float mag = std::sqrt(re * re + im * im) * normScale_;
        smoothedMag_[i] =
            smoothing_ * smoothedMag_[i] + (1.0f - smoothing_) * mag;
        const float db = 20.0f * std::log10(std::fmax(smoothedMag_[i], 1e-7f));
        float v = (db - minDb_) / dbRange;
        v = v < 0.0f ? 0.0f : (v > 1.0f ? 1.0f : v);
        texBytes_[i] = static_cast<uint8_t>(v * 255.0f);
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
