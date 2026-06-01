package com.example.mstream_music

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.view.Surface
import java.nio.ByteBuffer

/**
 * H.264 (AVC) video encoder fed by an input [Surface].
 *
 * Part of the visualizer-cast A/V transcode pipeline: the off-screen visualizer
 * render thread draws each frame into [inputSurface] (an EGL window surface; see
 * the C++ `nativeRenderFrameAt`, which stamps the presentation time the encoder
 * reads), and encoded access units are delivered to [onOutput] when [drain] is
 * called. The compressed video is then muxed with the song's AAC audio — to a
 * local MP4 for the Phase 0a spike, and to a live MPEG-TS/HLS stream once that's
 * proven — and served to the cast renderer via LocalMediaServer.
 *
 * Lifecycle: construct (configures + starts the codec, exposes [inputSurface]),
 * call [drain] from the render loop as frames are produced, [drain(endOfStream
 * = true)] to flush, then [release].
 */
class VideoEncoder(
    width: Int,
    height: Int,
    frameRate: Int = 30,
    bitRate: Int = 4_000_000,
    private val onFormat: (MediaFormat) -> Unit,
    private val onOutput: (ByteBuffer, MediaCodec.BufferInfo) -> Unit,
) {
    private var codec: MediaCodec? = null

    /** EGL-renderable surface the visualizer draws into. Valid until [release]. */
    val inputSurface: Surface

    init {
        val format = MediaFormat.createVideoFormat(MIME, width, height).apply {
            setInteger(
                MediaFormat.KEY_COLOR_FORMAT,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface,
            )
            setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
            setInteger(MediaFormat.KEY_FRAME_RATE, frameRate)
            // 1s keyframe interval keeps HLS segmentation clean (segment on IDR).
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, I_FRAME_INTERVAL_SECONDS)
        }
        val c = MediaCodec.createEncoderByType(MIME)
        c.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        inputSurface = c.createInputSurface()
        c.start()
        codec = c
    }

    /**
     * Pull any ready encoded output and hand it to [onOutput]. Call repeatedly
     * from the render loop. Pass [endOfStream] = true once, after the last
     * frame, to signal EOS and flush the remaining buffers.
     */
    fun drain(endOfStream: Boolean = false) {
        val c = codec ?: return
        if (endOfStream) c.signalEndOfInputStream()
        val info = MediaCodec.BufferInfo()
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
        private const val MIME = MediaFormat.MIMETYPE_VIDEO_AVC
        private const val I_FRAME_INTERVAL_SECONDS = 1
        private const val TIMEOUT_US = 10_000L
    }
}
