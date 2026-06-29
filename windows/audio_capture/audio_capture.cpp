// WASAPI loopback capture for the desktop visualizer.
//
// Opens the default render endpoint in loopback mode on a background thread,
// downmixes whatever is playing to mono float, and keeps the most recent samples
// in a ring buffer. ac_read() copies the latest N mono samples for the
// visualizer's FFT (shaders) / addPcm (projectM) feed. Pure C ABI for dart:ffi.
//
// Device loopback captures the whole output endpoint, so other apps' audio mixes
// in — fine for v1, since the user's music is what's playing. No microphone
// permission is involved (loopback taps a render endpoint, not a capture device).
// Windows-only; the Dart side gates on Platform.isWindows.

#define WIN32_LEAN_AND_MEAN
#define NOMINMAX // keep windows.h's min/max macros from clobbering std::min/max
#include <windows.h>
#include <mmdeviceapi.h>
#include <audioclient.h>
#include <mmreg.h>

#include <algorithm>
#include <atomic>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

namespace {

// ~340 ms at 48 kHz — far more than any single read window (1024), so reads
// never starve while playback is active.
constexpr size_t kRingSamples = 1u << 14; // 16384

std::thread g_thread;
std::atomic<bool> g_running{false};
std::atomic<bool> g_initDone{false};
std::atomic<bool> g_initOk{false};

std::mutex g_mutex; // guards the ring, sample rate, and error string
std::vector<float> g_ring(kRingSamples, 0.0f);
size_t g_writePos = 0;
size_t g_filled = 0; // total samples ever written (caps how much read can return)
int g_sampleRate = 0;
std::string g_error;

void setError(const std::string& e) {
  std::lock_guard<std::mutex> lk(g_mutex);
  g_error = e;
}

void pushMono(const float* mono, size_t n) {
  std::lock_guard<std::mutex> lk(g_mutex);
  for (size_t i = 0; i < n; ++i) {
    g_ring[g_writePos] = mono[i];
    g_writePos = (g_writePos + 1) % kRingSamples;
  }
  g_filled += n;
}

// The KSDATAFORMAT_SUBTYPE_* GUIDs encode the format tag in Data1 (1 = PCM,
// 3 = IEEE float), so we read that instead of linking the GUID symbols.
WORD effectiveFormatTag(const WAVEFORMATEX* fmt) {
  if (fmt->wFormatTag == WAVE_FORMAT_EXTENSIBLE) {
    const auto* ext = reinterpret_cast<const WAVEFORMATEXTENSIBLE*>(fmt);
    return static_cast<WORD>(ext->SubFormat.Data1);
  }
  return fmt->wFormatTag;
}

void downmixAndPush(const BYTE* data, UINT32 frames, const WAVEFORMATEX* fmt,
                    bool silent) {
  const int ch = fmt->nChannels > 0 ? fmt->nChannels : 1;
  std::vector<float> mono(frames, 0.0f);
  if (!silent && data != nullptr) {
    const WORD tag = effectiveFormatTag(fmt);
    if (tag == WAVE_FORMAT_IEEE_FLOAT && fmt->wBitsPerSample == 32) {
      const auto* f = reinterpret_cast<const float*>(data);
      for (UINT32 i = 0; i < frames; ++i) {
        float sum = 0.0f;
        for (int c = 0; c < ch; ++c) sum += f[i * ch + c];
        mono[i] = sum / ch;
      }
    } else if (tag == WAVE_FORMAT_PCM && fmt->wBitsPerSample == 16) {
      const auto* s = reinterpret_cast<const int16_t*>(data);
      for (UINT32 i = 0; i < frames; ++i) {
        int sum = 0;
        for (int c = 0; c < ch; ++c) sum += s[i * ch + c];
        mono[i] = static_cast<float>(sum) / (ch * 32768.0f);
      }
    }
    // Any other format → left as zeros (shared-mode mix is virtually always
    // 32-bit float, so this is a defensive fallback, not a hot path).
  }
  pushMono(mono.data(), frames);
}

HRESULT setupClient(IMMDeviceEnumerator** outEnum, IMMDevice** outDev,
                    IAudioClient** outClient, IAudioCaptureClient** outCap,
                    WAVEFORMATEX** outFmt, std::string& err) {
  HRESULT hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                                __uuidof(IMMDeviceEnumerator),
                                reinterpret_cast<void**>(outEnum));
  if (FAILED(hr)) { err = "CoCreateInstance(MMDeviceEnumerator) failed"; return hr; }

  hr = (*outEnum)->GetDefaultAudioEndpoint(eRender, eConsole, outDev);
  if (FAILED(hr)) { err = "GetDefaultAudioEndpoint(eRender) failed"; return hr; }

  hr = (*outDev)->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                           reinterpret_cast<void**>(outClient));
  if (FAILED(hr)) { err = "Activate(IAudioClient) failed"; return hr; }

  hr = (*outClient)->GetMixFormat(outFmt);
  if (FAILED(hr)) { err = "GetMixFormat failed"; return hr; }

  // Shared-mode + loopback: capture exactly what the endpoint is rendering.
  hr = (*outClient)->Initialize(AUDCLNT_SHAREMODE_SHARED,
                                AUDCLNT_STREAMFLAGS_LOOPBACK,
                                2000000 /*200ms buffer, 100ns units*/, 0, *outFmt,
                                nullptr);
  if (FAILED(hr)) { err = "IAudioClient::Initialize(loopback) failed"; return hr; }

  hr = (*outClient)->GetService(__uuidof(IAudioCaptureClient),
                                reinterpret_cast<void**>(outCap));
  if (FAILED(hr)) { err = "GetService(IAudioCaptureClient) failed"; return hr; }

  return S_OK;
}

void captureThread() {
  const HRESULT comHr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  const bool comInit = SUCCEEDED(comHr);

  IMMDeviceEnumerator* enumerator = nullptr;
  IMMDevice* device = nullptr;
  IAudioClient* client = nullptr;
  IAudioCaptureClient* capture = nullptr;
  WAVEFORMATEX* fmt = nullptr;
  std::string err;

  HRESULT hr = setupClient(&enumerator, &device, &client, &capture, &fmt, err);
  if (SUCCEEDED(hr)) {
    {
      std::lock_guard<std::mutex> lk(g_mutex);
      g_sampleRate = static_cast<int>(fmt->nSamplesPerSec);
    }
    hr = client->Start();
  }

  if (FAILED(hr)) {
    setError(err.empty() ? "IAudioClient::Start failed" : err);
    g_initOk.store(false);
    g_initDone.store(true);
  } else {
    g_initOk.store(true);
    g_initDone.store(true);

    while (g_running.load()) {
      UINT32 packet = 0;
      if (FAILED(capture->GetNextPacketSize(&packet))) break;
      while (packet > 0) {
        BYTE* data = nullptr;
        UINT32 frames = 0;
        DWORD flags = 0;
        if (FAILED(capture->GetBuffer(&data, &frames, &flags, nullptr, nullptr)))
          break;
        const bool silent = (flags & AUDCLNT_BUFFERFLAGS_SILENT) != 0;
        downmixAndPush(data, frames, fmt, silent);
        capture->ReleaseBuffer(frames);
        if (FAILED(capture->GetNextPacketSize(&packet))) break;
      }
      Sleep(8); // poll cadence — loopback isn't event-driven by default
    }
    client->Stop();
  }

  if (capture) capture->Release();
  if (client) client->Release();
  if (device) device->Release();
  if (enumerator) enumerator->Release();
  if (fmt) CoTaskMemFree(fmt);
  if (comInit) CoUninitialize();
}

} // namespace

extern "C" {

// Start loopback capture. Returns 0 on success, non-zero on failure (see
// ac_last_error). Idempotent: a second call while running is a no-op success.
__declspec(dllexport) int ac_start() {
  if (g_running.load()) return 0;
  g_initDone.store(false);
  g_initOk.store(false);
  g_running.store(true);
  g_thread = std::thread(captureThread);
  for (int i = 0; i < 200 && !g_initDone.load(); ++i) Sleep(5); // wait up to ~1s
  if (!g_initOk.load()) {
    g_running.store(false);
    if (g_thread.joinable()) g_thread.join();
    return 1;
  }
  return 0;
}

// Stop capture and clear the ring. Safe to call when not running.
__declspec(dllexport) void ac_stop() {
  if (!g_running.exchange(false)) return;
  if (g_thread.joinable()) g_thread.join();
  std::lock_guard<std::mutex> lk(g_mutex);
  g_writePos = 0;
  g_filled = 0;
  std::fill(g_ring.begin(), g_ring.end(), 0.0f);
}

// Copy the most recent up-to [maxSamples] mono samples (~[-1,1]) into [out], in
// chronological order. Returns the count written (may be < maxSamples until the
// ring has filled). Leaves the remainder of [out] untouched.
__declspec(dllexport) int ac_read(float* out, int maxSamples) {
  if (out == nullptr || maxSamples <= 0) return 0;
  std::lock_guard<std::mutex> lk(g_mutex);
  const size_t avail = std::min(g_filled, kRingSamples);
  const size_t n = std::min(static_cast<size_t>(maxSamples), avail);
  const size_t start = (g_writePos + kRingSamples - n) % kRingSamples;
  for (size_t i = 0; i < n; ++i) {
    out[i] = g_ring[(start + i) % kRingSamples];
  }
  return static_cast<int>(n);
}

// Endpoint mix-format sample rate (e.g. 48000), or 0 before capture starts.
__declspec(dllexport) int ac_sample_rate() {
  std::lock_guard<std::mutex> lk(g_mutex);
  return g_sampleRate;
}

// Last error message (diagnostic). Valid until the next ac_start.
__declspec(dllexport) const char* ac_last_error() {
  return g_error.c_str();
}

} // extern "C"
