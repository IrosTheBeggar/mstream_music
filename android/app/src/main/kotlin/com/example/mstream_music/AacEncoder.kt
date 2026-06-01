package com.example.mstream_music

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import java.nio.ByteBuffer

/**
 * AAC-LC encoder for the visualizer-cast transcode: feed interleaved 16-bit PCM
 * (the same PCM that drives the visualizer) with a presentation time, and
 * encoded AAC access units are delivered to [onOutput]. [onFormat] fires once
 * with the output format (carries csd) — the muxer adds its audio track there.
 */
class AacEncoder(
    private val sampleRate: Int,
    private val channelCount: Int,
    bitRate: Int = 128_000,
    private val onFormat: (MediaFormat) -> Unit,
    private val onOutput: (ByteBuffer, MediaCodec.BufferInfo) -> Unit,
) {
    private val codec: MediaCodec
    private val info = MediaCodec.BufferInfo()
    private val bytesPerFrame = channelCount * 2 // 16-bit

    init {
        val fmt = MediaFormat.createAudioFormat(MIME, sampleRate, channelCount).apply {
            setInteger(
                MediaFormat.KEY_AAC_PROFILE,
                MediaCodecInfo.CodecProfileLevel.AACObjectLC,
            )
            setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
            setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 64 * 1024)
        }
        codec = MediaCodec.createEncoderByType(MIME)
        codec.configure(fmt, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        codec.start()
    }

    /** Encode [pcm] (interleaved 16-bit LE, [channelCount] channels) at
     *  [ptsUs]; splits across input buffers, stamping each sub-chunk. */
    fun encode(pcm: ByteArray, ptsUs: Long) {
        var offset = 0
        while (offset < pcm.size) {
            val inIndex = codec.dequeueInputBuffer(TIMEOUT_US)
            if (inIndex < 0) {
                drain(false) // let the encoder make progress, then retry
                continue
            }
            val inBuf = codec.getInputBuffer(inIndex)!!
            inBuf.clear()
            val n = minOf(inBuf.capacity(), pcm.size - offset)
            inBuf.put(pcm, offset, n)
            val subPts = ptsUs + framesToUs(offset / bytesPerFrame)
            codec.queueInputBuffer(inIndex, 0, n, subPts, 0)
            offset += n
            drain(false)
        }
    }

    /** Flush: queue end-of-stream and drain the remaining output. */
    fun finish() {
        val inIndex = codec.dequeueInputBuffer(TIMEOUT_US)
        if (inIndex >= 0) {
            codec.queueInputBuffer(
                inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
        }
        drain(true)
    }

    private fun drain(endOfStream: Boolean) {
        while (true) {
            val outIndex =
                codec.dequeueOutputBuffer(info, if (endOfStream) TIMEOUT_US else 0)
            when {
                outIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> if (!endOfStream) return
                outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> onFormat(codec.outputFormat)
                outIndex >= 0 -> {
                    val buf = codec.getOutputBuffer(outIndex)
                    val isConfig =
                        (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) != 0
                    if (buf != null && info.size > 0 && !isConfig) {
                        buf.position(info.offset)
                        buf.limit(info.offset + info.size)
                        onOutput(buf, info)
                    }
                    codec.releaseOutputBuffer(outIndex, false)
                    if ((info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) return
                }
            }
        }
    }

    private fun framesToUs(frames: Int): Long = frames.toLong() * 1_000_000L / sampleRate

    fun release() {
        try { codec.stop() } catch (_: Throwable) {}
        try { codec.release() } catch (_: Throwable) {}
    }

    companion object {
        private const val MIME = MediaFormat.MIMETYPE_AUDIO_AAC
        private const val TIMEOUT_US = 10_000L
    }
}
