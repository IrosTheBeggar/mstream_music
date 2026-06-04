package com.example.mstream_music

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.util.Log
import android.view.Surface
import java.nio.ByteBuffer

/**
 * H.264 (AVC) video encoder fed by an input [Surface].
 *
 * Part of the visualizer-cast A/V transcode pipeline: the off-screen visualizer
 * render thread draws each frame into [inputSurface] (an EGL window surface; see
 * the C++ `nativeRenderFrameAt`, which stamps the presentation time the encoder
 * reads), and encoded access units are delivered to [onOutput] when [drain] is
 * called. The compressed video is then muxed with the song's AAC audio into a
 * live MPEG-TS/HLS stream ([TsHlsSink]) and served to the cast renderer via
 * LocalMediaServer.
 *
 * Lifecycle: construct (configures + starts the codec, exposes [inputSurface]),
 * call [drain] from the render loop as frames are produced, [drain(endOfStream
 * = true)] to flush, then [release].
 */
class VideoEncoder(
    width: Int,
    height: Int,
    frameRate: Int = 30,
    bitRate: Int = 0, // 0 = auto from resolution (see autoBitrate)
    private val onFormat: (MediaFormat) -> Unit,
    private val onOutput: (ByteBuffer, MediaCodec.BufferInfo) -> Unit,
) {
    private var codec: MediaCodec? = null
    // Reused across drain() calls (single-threaded; dequeueOutputBuffer fully
    // overwrites it each time) instead of allocating one per drained frame.
    private val drainInfo = MediaCodec.BufferInfo()

    /** EGL-renderable surface the visualizer draws into. Valid until [release]. */
    val inputSurface: Surface

    init {
        // A flat bitrate starves higher resolutions (a 1080p frame has 2.25× the
        // pixels of 720p), so scale it with resolution unless caller overrides.
        val effectiveBitrate =
            if (bitRate > 0) bitRate else autoBitrate(width, height, frameRate)
        // Built fresh each time so we can retry without profile/level if the
        // encoder rejects High profile (MediaFormat.removeKey is API 29+).
        fun baseFormat() = MediaFormat.createVideoFormat(MIME, width, height).apply {
            setInteger(
                MediaFormat.KEY_COLOR_FORMAT,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface,
            )
            setInteger(MediaFormat.KEY_BIT_RATE, effectiveBitrate)
            setInteger(MediaFormat.KEY_FRAME_RATE, frameRate)
            // VBR spends bits where the visuals are complex instead of wasting
            // them on simple frames (better quality-per-bit). The LAN isn't
            // bitrate-constrained and the receiver buffers, so variance is fine.
            setInteger(
                MediaFormat.KEY_BITRATE_MODE,
                MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_VBR,
            )
            // Match the keyframe interval to the HLS segment length: one IDR per
            // ~2s segment. (At 1s we emitted a *second*, mid-segment keyframe that
            // HLS doesn't need — wasted encode work + bitrate, since an IDR is far
            // larger/costlier than a P-frame. TsHlsSink rotates on the IDR.)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, I_FRAME_INTERVAL_SECONDS)
        }

        var c = MediaCodec.createEncoderByType(MIME)
        // H.264 High profile is ~10–15% better quality-per-bit than the default
        // (Baseline/Main). Only request it if this encoder advertises High at a
        // level adequate for the resolution, and retry without it if configure
        // still fails — so we're never worse than the default.
        val profileLevel = highProfileLevel(c, width, height)
        val format = baseFormat()
        if (profileLevel != null) {
            format.setInteger(MediaFormat.KEY_PROFILE, profileLevel.first)
            format.setInteger(MediaFormat.KEY_LEVEL, profileLevel.second)
        }
        try {
            c.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        } catch (e: Exception) {
            Log.w(TAG, "AVC configure failed (High profile?) — retrying default", e)
            try { c.release() } catch (_: Throwable) {}
            c = MediaCodec.createEncoderByType(MIME)
            c.configure(baseFormat(), null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        }
        inputSurface = c.createInputSurface()
        c.start()
        codec = c
    }

    // The (profile, level) to request for H.264 High at this resolution, or null
    // if the encoder doesn't advertise High at an adequate level. AVC level
    // constants increase monotonically, so `>=` compares capability; we pick the
    // lowest supported level that covers the resolution so the receiver's decoder
    // isn't asked for more than the stream actually needs.
    private fun highProfileLevel(codec: MediaCodec, width: Int, height: Int): Pair<Int, Int>? {
        return try {
            val caps = codec.codecInfo.getCapabilitiesForType(MIME)
            val pixels = width.toLong() * height
            val required = when {
                pixels <= 1280L * 720 -> MediaCodecInfo.CodecProfileLevel.AVCLevel31
                pixels <= 1920L * 1080 -> MediaCodecInfo.CodecProfileLevel.AVCLevel4
                else -> MediaCodecInfo.CodecProfileLevel.AVCLevel51
            }
            val match = caps.profileLevels
                ?.filter {
                    it.profile == MediaCodecInfo.CodecProfileLevel.AVCProfileHigh &&
                        it.level >= required
                }
                ?.minByOrNull { it.level }
            match?.let { Pair(MediaCodecInfo.CodecProfileLevel.AVCProfileHigh, it.level) }
        } catch (e: Throwable) {
            null
        }
    }

    /**
     * Pull any ready encoded output and hand it to [onOutput]. Call repeatedly
     * from the render loop. Pass [endOfStream] = true once, after the last
     * frame, to signal EOS and flush the remaining buffers.
     */
    fun drain(endOfStream: Boolean = false) {
        val c = codec ?: return
        if (endOfStream) c.signalEndOfInputStream()
        val info = drainInfo
        while (true) {
            val index = c.dequeueOutputBuffer(info, if (endOfStream) TIMEOUT_US else 0)
            when {
                index == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (!endOfStream) return // nothing ready; come back next frame
                    // draining for EOS: keep polling until the EOS flag arrives
                }
                index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    // Carries csd-0/csd-1 (SPS/PPS) — the muxer adds its track here.
                    onFormat(c.outputFormat)
                }
                index >= 0 -> {
                    val buf = c.getOutputBuffer(index)
                    val isConfig =
                        (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) != 0
                    if (buf != null && info.size > 0 && !isConfig) {
                        buf.position(info.offset)
                        buf.limit(info.offset + info.size)
                        onOutput(buf, info)
                    }
                    c.releaseOutputBuffer(index, false)
                    if ((info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) return
                }
            }
        }
    }

    fun release() {
        try {
            codec?.stop()
        } catch (_: Throwable) {
        }
        try {
            codec?.release()
        } catch (_: Throwable) {
        }
        codec = null
        try {
            inputSurface.release()
        } catch (_: Throwable) {
        }
    }

    companion object {
        private const val TAG = "mstream/viz-xcode"
        private const val MIME = MediaFormat.MIMETYPE_VIDEO_AVC
        // Matches TsHlsSink.TARGET_SEG_US (one keyframe per HLS segment).
        private const val I_FRAME_INTERVAL_SECONDS = 2
        private const val TIMEOUT_US = 10_000L

        // ~0.14 bits/pixel — enough for detailed shader/Milkdrop content (sharp
        // edges, gradients, motion) without obvious H.264 artifacts; clamped to a
        // sane range. The stream is served over the LAN, so we can be generous.
        // 1080p30 ≈ 8.7 Mbps, 720p30 ≈ 3.9 Mbps, 4K30 clamps to 24 Mbps.
        private fun autoBitrate(width: Int, height: Int, frameRate: Int): Int =
            (width.toLong() * height * frameRate * 14 / 100)
                .coerceIn(2_000_000L, 24_000_000L)
                .toInt()
    }
}
