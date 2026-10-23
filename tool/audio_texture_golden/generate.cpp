// Golden vectors for lib/visualizer/spectrum_curve.dart, from the reference
// itself.
//
// Links android/app/src/main/cpp/audio_texture.cpp — unmodified — against the
// stub GLES in stubs/, feeds it a signal, and writes each texture it uploads.
// See README.md for how to run it.
//
// The signal is built from integer arithmetic and float operations whose
// results are exact or singly rounded, so the Dart test can generate the same
// samples bit for bit rather than reading 47 KB of them from disk; the FNV-1a
// hash in the header is how it proves it did.

#include "audio_texture.h"

#include <cstdint>
#include <cstdio>
#include <cmath>
#include <cstring>
#include <vector>

unsigned char g_uploaded[512 * 2];

namespace {

constexpr std::uint32_t kSteps = 10;
constexpr std::uint32_t kFramesPerStep = 735;  // a 60 Hz frame at 44.1 kHz
constexpr std::uint32_t kCurveChangeStep = 5;
constexpr std::uint32_t kSilentFromStep = 8;

struct Signal {
    std::uint32_t lcg = 0x2545F491u;
    std::uint32_t bass = 0, mid = 0, high = 0;

    float noise() {
        lcg = lcg * 1664525u + 1013904223u;
        return static_cast<float>(lcg >> 8) * (1.0f / 16777216.0f) * 2.0f - 1.0f;
    }

    static float triangle(std::uint32_t phase) {
        const float t = static_cast<float>(phase >> 8) * (1.0f / 16777216.0f);
        return 4.0f * std::fabs(t - 0.5f) - 1.0f;
    }

    // 60 Hz, 440 Hz and 3 kHz, as phase steps of 2^32 per cycle at 44.1 kHz.
    void frame(float* left, float* right) {
        bass += 5843493u;
        mid += 42852281u;
        high += 292174646u;
        *left = triangle(bass) * 0.5f + noise() * 0.05f;
        *right = triangle(mid) * 0.25f + triangle(high) * 0.1f + noise() * 0.05f;
    }
};

std::uint64_t fnv1a(std::uint64_t hash, float value) {
    std::uint32_t bits;
    std::memcpy(&bits, &value, sizeof bits);
    for (int i = 0; i < 4; ++i) {
        hash ^= (bits >> (8 * i)) & 0xFFu;
        hash *= 1099511628211ull;
    }
    return hash;
}

void put32(std::FILE* f, std::uint32_t v) {
    for (int i = 0; i < 4; ++i) std::fputc((v >> (8 * i)) & 0xFF, f);
}

void put64(std::FILE* f, std::uint64_t v) {
    for (int i = 0; i < 8; ++i) std::fputc((v >> (8 * i)) & 0xFF, f);
}

}  // namespace

int main(int argc, char** argv) {
    if (argc != 2) {
        std::fprintf(stderr, "usage: %s <golden.bin>\n", argv[0]);
        return 2;
    }
    AudioTexture texture;
    if (!texture.init()) return 1;

    Signal signal;
    std::uint64_t hash = 14695981039346656037ull;
    std::vector<unsigned char> uploads;
    std::vector<float> stereo(kFramesPerStep * 2);
    for (std::uint32_t step = 0; step < kSteps; ++step) {
        if (step == kCurveChangeStep) texture.setParams(-80.0f, -30.0f, 0.6f);
        for (std::uint32_t i = 0; i < kFramesPerStep; ++i) {
            float left = 0.0f, right = 0.0f;
            if (step < kSilentFromStep) signal.frame(&left, &right);
            stereo[2 * i] = left;
            stereo[2 * i + 1] = right;
            hash = fnv1a(fnv1a(hash, left), right);
        }
        texture.addPcm(stereo.data(), kFramesPerStep);
        texture.upload();
        uploads.insert(uploads.end(), g_uploaded, g_uploaded + sizeof g_uploaded);
    }

    std::FILE* out = std::fopen(argv[1], "wb");
    if (!out) return 1;
    std::fwrite("MSATGLD1", 1, 8, out);
    put32(out, kSteps);
    put32(out, kFramesPerStep);
    put64(out, hash);
    std::fwrite(uploads.data(), 1, uploads.size(), out);
    std::fclose(out);
    std::printf("wrote %u uploads, input fnv1a %016llx\n", kSteps, static_cast<unsigned long long>(hash));
    return 0;
}
