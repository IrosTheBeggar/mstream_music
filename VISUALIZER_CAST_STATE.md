# Visualizer Cast — working state (resume doc)

Temporary working doc (delete before the final PR). Tracks the in-progress
**visualizer casting** feature so work can resume across sessions.

## Status: Phase 0b COMPLETE ✅ — proof validated on device
The app's projectM/shader visualizer is rendered off-screen, encoded to
H.264+AAC, packaged by a **hand-written MPEG-TS/HLS muxer**, served over the LAN,
and **plays live on a real Chromecast**. Confirmed working 2026-06-01.

Currently it's a **VOD** proof (transcode a ~25 s clip → cast), triggered by a
**debug** button. The remaining work is making it real-time/live, wiring the
real UI, transport, and cleanup (see "Remaining work").

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

## Remaining work (make it shippable)
1. **Make it LIVE** (next task): currently VOD (full transcode → cast). Need:
   - `TsHlsSink`: write `index.m3u8` **incrementally** after each segment as an
     EVENT playlist (no `#EXT-X-ENDLIST` until `finish()`); already VOD at finish.
   - Remove the `maxMs` cap → transcode the full track.
   - **Cast early**: return the playlist + start casting after the first ~2
     segments exist, while the transcode keeps running (background). Needs an
     `onReady` signal from the transcoder (or Dart polls the m3u8 for ≥2 segs).
   - Pace ~realtime so segments are available just in time.
2. **Real UI**: wire the cast picker's disabled "Cast visualizer" checkbox
   (`cast_picker_sheet.dart`) → when checked + a Chromecast is picked, cast the
   visualizer (via CastManager) instead of audio. Persist the choice.
3. **Transport**: play/pause/seek/track-change drive the transcode + session.
4. **Cleanup**: delete the debug actions + `visualizer_cast_spike.dart` + any
   remaining diagnostics once the real path works.
5. **Tuning**: encoder is 720p30 ~4 Mbps; tune bitrate/res/fps, latency, thermals.
   DLNA HLS is unreliable → Chromecast-first.
