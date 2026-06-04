package com.example.mstream_music

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat

/**
 * Decodes the audio track of a media source (local file path or http URL) to
 * 16-bit PCM. Pull-based: call [read] repeatedly until it returns null (EOS).
 *
 * Part of the visualizer-cast transcode — the PCM drives the off-screen
 * visualizer and is re-encoded to AAC for the cast stream, all on one
 * presentation-time timeline so audio and the rendered video stay in sync.
 */
class AudioDecoder(source: String) {
    private val extractor = MediaExtractor()
    private val codec: MediaCodec
    private val bufferInfo = MediaCodec.BufferInfo()
    private var inputDone = false
    private var outputDone = false

    /** Actual decoded-PCM sample rate / channel count (refined from the codec's
     *  output format once known). Read after the first [read]. */
    var sampleRate: Int
        private set
    var channelCount: Int
        private set

    class Pcm(val data: ByteArray, val presentationTimeUs: Long)

    init {
        extractor.setDataSource(source)
        var trackIndex = -1
        var trackFormat: MediaFormat? = null
        for (i in 0 until extractor.trackCount) {
            val f = extractor.getTrackFormat(i)
            if (f.getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true) {
                trackIndex = i
                trackFormat = f
                break
            }
        }
        require(trackIndex >= 0 && trackFormat != null) { "no audio track in source" }
        extractor.selectTrack(trackIndex)
        sampleRate = trackFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        channelCount = trackFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
        codec = MediaCodec.createDecoderByType(trackFormat.getString(MediaFormat.KEY_MIME)!!)
        codec.configure(trackFormat, null, null, 0)
        codec.start()
    }

    /** Next PCM chunk (interleaved 16-bit LE, [channelCount] channels), or null
     *  at end of stream. */
    fun read(): Pcm? {
        while (!outputDone) {
            if (!inputDone) {
                val inIndex = codec.dequeueInputBuffer(TIMEOUT_US)
                if (inIndex >= 0) {
                    val inBuf = codec.getInputBuffer(inIndex)!!
                    val size = extractor.readSampleData(inBuf, 0)
                    if (size < 0) {
                        codec.queueInputBuffer(
                            inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        inputDone = true
                    } else {
                        codec.queueInputBuffer(inIndex, 0, size, extractor.sampleTime, 0)
                        extractor.advance()
                    }
                }
            }
            val outIndex = codec.dequeueOutputBuffer(bufferInfo, TIMEOUT_US)
            when {
                outIndex >= 0 -> {
                    val outBuf = codec.getOutputBuffer(outIndex)!!
                    val chunk = ByteArray(bufferInfo.size)
                    if (bufferInfo.size > 0) {
                        outBuf.position(bufferInfo.offset)
                        outBuf.get(chunk, 0, bufferInfo.size)
                    }
                    val pts = bufferInfo.presentationTimeUs
                    val eos = (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0
                    codec.releaseOutputBuffer(outIndex, false)
                    if (eos) outputDone = true
                    if (chunk.isNotEmpty()) return Pcm(chunk, pts)
                    if (eos) return null
                }
                outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    val out = codec.outputFormat
                    if (out.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                        sampleRate = out.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    }
                    if (out.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                        channelCount = out.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                    }
                }
            }
        }
        return null
    }

    fun release() {
        try { codec.stop() } catch (_: Throwable) {}
        try { codec.release() } catch (_: Throwable) {}
        try { extractor.release() } catch (_: Throwable) {}
    }

    companion object {
        private const val TIMEOUT_US = 10_000L
    }
}
