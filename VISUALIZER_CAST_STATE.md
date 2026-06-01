# Visualizer Cast — working state (resume doc)

Temporary working doc (delete before the final PR). Tracks the in-progress
**visualizer casting** feature so work can resume across sessions.

## Status: Phase 0b COMPLETE ✅ — proof validated on device
The app's projectM/shader visualizer is rendered off-screen, encoded to
H.264+AAC, packaged by a **hand-written MPEG-TS/HLS muxer**, served over the LAN,
and **plays live on a real Chromecast**. Confirmed working 2026-06-01.

**LIVE validated (2026-06-01):** now streams a **full track live** — incremental
EVENT playlist, cast-early (transcode runs in the background, Dart polls the
growing playlist then casts), no duration cap. A full song played end-to-end on
the Chromecast. At end-of-track the receiver shows its **idle screen** — this is
EXPECTED (single-track stream ended); continuing to the next song needs
track-change handling (see Remaining work #3). Still a **debug** button.

**Hardening pass (2026-06-01, after an audit):** the prototype is now safe to
leave running. Changes:
- **~realtime pacing** (`VisualizerTranscoder`, `pace` flag, on for HLS only):
  keeps at most `PACING_LEAD_US` (5 s) of media ahead of wall-clock — the first
  few segments still burst out fast so casting starts quickly, then it throttles
  to realtime instead of transcoding the whole track in one CPU/thermal burst.
  The MP4 spike stays unpaced (`pace=false`) so it's still quick.
- **Transcoder-identity fix** (`VisualizerBridge.handleStartTranscode`): the
  completion callback now only nulls `transcoder` if it still points at *its own*
  transcode (`transcoder === created`); a fast re-cast no longer orphans the new
  transcode so `stopTranscode` can always cancel it.
- **Stale-segment cleanup** (`TsHlsSink.init`): deletes leftover `*.ts` /
  `index.m3u8(.tmp)` from a previous run before writing the new one.
- **Cast-end teardown** (`visualizer_cast_spike`): watches the cast session and
  on disconnect calls `stopTranscode` + `LocalMediaServer.stop()` — no more
  encoding/serving after the user stops casting.

Remaining: real UI, transport/track-change, cleanup, device tuning.

## Branch / PRs
- Branch: `feature/visualizer-cast`, stacked on `feature/casting-v2` (**PR #28**,
  base master). casting v1 = **PR #27** (merged). Push order: #28 must merge
  before this branch.
- This feature is NOT yet a PR. Many small commits; latest adds AUD NALs.

## How to test
1. Phone + Chromecast on the same Wi-Fi.
2. Play a track in mStream → **More (⋮) → "Cast visualizer to TV (spike)"**.
3. ~20 s render, then it casts to the TV.
- Debug device: `192.168.1.141:38307` (wireless adb; **port rotates** on
  reconnect — ask user for the new `IP:port` if it refuses).
- Output on device: `…/Android/data/mstream.music/files/viz_hls/` (index.m3u8 +
  segN.ts). `viz_spike.mp4` is the older MP4-only spike.

## Architecture (the transcode pipeline)
Decode audio → that PCM drives BOTH (a) an off-screen visualizer engine
rendering into an H.264 encoder Surface and (b) an AAC encoder → samples go to
an **AvSink**. All on one thread that owns the EGL context.

Native (`android/app/src/main/kotlin/com/example/mstream_music/`):
- `VisualizerBridge.kt` — MethodChannel `mstream/visualizer`; `handleStartTranscode`
  builds the sink (mp4|hls) + `VisualizerTranscoder`, runs it, replies the
  playable path. Also the on-screen visualizer (RenderThread).
- `VisualizerTranscoder.kt` — orchestrates decode→render→encode→sink; reuses
  native fns via refs (initEncoder/renderAt/addPcm/loadPreset/setTuning/dispose).
- `AudioDecoder.kt` (MediaExtractor+MediaCodec → PCM), `VideoEncoder.kt`
  (MediaCodec AVC, input Surface), `AacEncoder.kt` (MediaCodec AAC-LC).
- `AvSink.kt` — interface + `Mp4Sink` (MediaMuxer, on-phone MP4).
- `TsHlsSink.kt` — **the hand-written MPEG-TS/HLS muxer** (PAT/PMT+CRC, PES,
  PCR, ADTS, segmenting, m3u8).
- `cpp/visualizer_bridge.cpp` — `nativeInitEncoder` (EGL surface on encoder
  input, skips setBuffersGeometry), `nativeRenderFrameAt` (render + eglPresentationTimeANDROID).

Dart:
- `lib/native/visualizer_bridge.dart` — `startTranscode({source, output, preset,
  engine, w, h, fps, maxMs, tuning, mode})`, `stopTranscode`. mode 'mp4'|'hls'.
- `lib/media/local_media_server.dart` — dart:io HTTP server. Serves single files
  (registerFile) AND directories (registerDirectory, for HLS). Range support,
  **CORS headers** (required for Cast HLS), HLS MIME types.
- `lib/media/visualizer_cast_spike.dart` — DEBUG: `castVideoToFirstChromecast`
  (discover → session → loadMedia). Throwaway.
- `lib/widgets/more_actions_sheet.dart` — DEBUG actions `_runVisualizerSpike`
  (→ MP4 on disk) and `_castVisualizerToTv` (→ HLS → Chromecast). Forces the
  spectrum-bars shader (`assets/shaders/01-spectrum-bars.glsl`) + its tuning.

## ⚠️ Hard-won fixes — DO NOT regress (each cost a debug round)
Found via byte-level analysis of `viz_hls/seg0.ts` (PowerShell TS parser; see
git history of this session). All in `TsHlsSink.kt` unless noted:
1. **PPS**: AVC config is split across `csd-0` (SPS) AND `csd-1` (PPS) — read
   BOTH in `onVideoFormat`. (Only SPS → decoder can't decode.)
2. **A/V alignment**: the video encoder has more latency than audio, so audio
   is produced before the first keyframe opens a segment. Buffer that audio
   (`pendingAudio`) and flush on first segment, else audio starts ~0.5 s after
   video and the receiver stalls.
3. **CORS** (`local_media_server.dart`): Cast plays HLS via MSE (fetches), so
   responses need `Access-Control-Allow-Origin: *` etc. (MP4 via <video> didn't).
4. **AUD NALs**: prepend `00 00 00 01 09 F0` to every access unit — the receiver's
   transmuxer (mux.js) needs AUDs to find AU boundaries. (THIS was the final fix.)
- Verified-good: PMT CRC (MPEG CRC-32), video PTS 0/+3000, audio PTS ~0, PCR 0,
  ADTS sync FFF1, PIDs PAT=0/PMT=0x1000/video=0x100/audio=0x101.

## Debugging tips
- **dart:developer logs (castLog) do NOT appear in `adb logcat`.** Use a FILE
  (we logged HLS requests to `viz_hls/_access.log` and receiver status to
  `_status.log` — being removed in cleanup; re-add if needed).
- Native Kotlin `Log.*` (tags `mstream/viz-xcode`, `mstream/viz-bridge`) DO show.
- TS inspection: `adb pull viz_hls/seg0.ts` then parse 188-byte packets (sync
  0x47, PID = ((b1&0x1F)<<8)|b2, PUSI = b1&0x40). PTS at PES+9.

## Production wiring (2026-06-01) — picker → real backend ✅ (untested on device)
The visualizer cast now runs through the **real cast path**, not the debug spike:
- **Picker checkbox** (`cast_picker_sheet.dart`) is enabled + persisted
  (`SettingsManager.castVisualizerEnabled`). Checked + pick a Chromecast →
  `CastManager.selectTarget(t, visualizer: true)`.
- **Flag flow**: `CastManager` (`_activeVisualizer`, `selectTarget({visualizer})`,
  `onTargetSelected(target, visualizer)`) → `audio_stuff` `_doSwitchToTarget` →
  `ChromecastPlaybackBackend(deviceId:, visualizer: true)`. Visualizer is honoured
  only for Chromecast targets (DLNA/local ignore it).
- **Backend visualizer mode** (`chromecast_playback_backend.dart`): when
  `_visualizer`, `_loadIndex` calls `_resolveVisualizerUri` instead of
  `_resolveUri` — stop any prior transcode, `startTranscode(mode:hls, maxMs:0)`
  into `<ext>/viz_cast`, poll for ≥2 segments, serve via `registerDirectory`
  (cache-busted `?v=N` per load), `loadMedia` with HLS contentType + generic
  metadata. **Track-change comes for free**: end-of-track → `_onTrackEnded` →
  `_loadIndex(next)` → a fresh transcode. `dispose` stops the transcode; the
  handler stops `LocalMediaServer` on switch-to-local.
- **Cast config** (`visualizer_cast_config.dart`): mirrors the visualizer screen —
  uses `SettingsManager.visualizerEngine` + a **random** preset of that kind
  (`VisualizerPresets.randomData`, no on-screen side effects) + shader tuning
  (global curve from settings + per-shader defaults). NOTE: default engine is
  **Milkdrop**, so a default cast renders projectM — the validated path was
  shader/spectrum-bars, so projectM-in-encoder needs a device check.

**Not yet validated on device.** Build + analyze clean only. The debug spike
(`visualizer_cast_spike.dart` + More-menu actions) is **kept for now** as an A/B
fallback until the picker path is confirmed on real hardware.

## Remaining work (make it shippable)
0. ~~Make it LIVE~~ ✅ · ~~Real UI / picker wiring~~ ✅ (above; needs device test).
1. **Transport polish**: play/pause work (receiver-side); **seek is limited** —
   a live transcode starts at 0, so seeking within a track is best-effort and
   `startAt` is ignored on (re)load. Track-change works via `_loadIndex`.
2. ~~**Concurrency hardening**~~ ✅ DONE — each track now transcodes into its own
   `viz_cast/<n>` subdir, so a just-stopped transcode can't race the next on the
   same files. Cleanup: first load drops the prior session's tree, later loads
   drop the previous track's, `dispose` drops the last (bounds disk to ~1 track).
   `_resolveVisualizerUri` also now **fails fast** (throws) if ≥2 segments don't
   appear in ~20 s, so a wedged transcode falls back instead of casting an empty
   playlist. (Still untested on device.)
   - ~~audio-only fallback~~ ✅ DONE — if the transcode fails, the backend keeps
     the song on the TV as **plain audio** (latched `_visualizerFellBack`) + a
     toast (`CastManager.reportCastInfo`) instead of dropping to the phone. A
     genuine device failure (audio load also fails) still drops to local.
3. **Cleanup**: delete the debug actions + `visualizer_cast_spike.dart` + this
   state doc once the picker path is confirmed.
4. **Tuning** (in progress): cast now renders + encodes at **1080p30** (was 720p),
   and `VideoEncoder` **scales bitrate with resolution** (~0.14 bpp → 1080p30
   ≈ 8.7 Mbps, clamped 2–24 Mbps) instead of a flat 4 Mbps — fixes soft/low-detail
   shaders (e.g. hex-marching) on a TV. The MP4 spike stays 720p. Possible
   follow-ups: a **Cast quality setting** (720p / 1080p / 4K — 4K only helps on
   4K-capable Chromecasts and ~4× the encode load), 60 fps option, watch thermals
   on long sessions (pacing keeps it ~realtime, so sustained load is bounded).
   DLNA HLS is unreliable → Chromecast-first.
