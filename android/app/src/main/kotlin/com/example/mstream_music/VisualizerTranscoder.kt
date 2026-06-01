package com.example.mstream_music

import android.media.MediaCodec
import android.media.MediaFormat
import android.media.MediaMuxer
import android.util.Log
import android.view.Surface
import java.nio.ByteBuffer

/**
 * Phase 0a spike: transcode a track into an MP4 of the app's visualizer
 * reacting to it, to validate the on-device A/V pipeline before wiring it to
 * casting.
 *
 * Pipeline (all on this thread, which owns the EGL context via the native
 * bridge): decode the source audio to PCM → that PCM both drives an off-screen
 * visualizer engine (rendering into an H.264 encoder's input Surface, stamped
 * from the audio clock) and is re-encoded to AAC → both elementary streams are
 * muxed to an MP4 at [outputPath]. Audio is best-effort: if the AAC encoder
 * can't be set up the result is a silent (video-only) MP4 rather than a failure.
 *
 * Reports completion via [onDone] (success, errorMessage?) — invoked on this
 * thread, so the caller should hop to the main thread before touching UI.
 */
class VisualizerTranscoder(
    private val source: String,
    private val outputPath: String,
    private val width: Int,
    private val height: Int,
    private val engineKind: Int,
    private val fps: Int,
    private val maxDurationUs: Long,
    private val presetData: String?,
    private val tuning: FloatArray?,
    private val initEncoder: (Surface, Int, Int, Int) -> Long,
    private val renderAt: (Long, Long) -> Unit,
    private val addPcm: (Long, FloatArray) -> Unit,
    private val loadPreset: (Long, String, Boolean) -> Unit,
    private val setTuning: (Long, FloatArray) -> Unit,
    private val dispose: (Long) -> Unit,
    private val onDone: (Boolean, String?) -> Unit,
) : Thread("mstream-viz-transcode") {

    @Volatile private var cancelled = false
    fun cancelTranscode() { cancelled = true }

    // Muxer has two tracks but can't start until both encoders report their
    // output format; samples produced before then are buffered in [pending].
    private var muxer: MediaMuxer? = null
    private var videoTrack = -1
    private var audioTrack = -1
    private var videoFormat: MediaFormat? = null
    private var audioFormat: MediaFormat? = null
    private var audioEnabled = false
    private var muxerStarted = false
    private val pending = ArrayList<Sample>()

    private class Sample(
        val isVideo: Boolean,
        val bytes: ByteArray,
        val ptsUs: Long,
        val flags: Int,
    )

    override fun run() {
        var decoder: AudioDecoder? = null
        var video: VideoEncoder? = null
        var aac: AacEncoder? = null
        var ctx = 0L
        try {
            decoder = AudioDecoder(source)
            val firstChunk =
                decoder.read() ?: throw IllegalStateException("no audio decoded")
            val startPtsUs = firstChunk.presentationTimeUs

            muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

            video = VideoEncoder(
                width = width,
                height = height,
                frameRate = fps,
                onFormat = { f -> videoFormat = f; maybeStartMuxer() },
                onOutput = { buf, info -> writeSample(true, buf, info) },
            )
            ctx = initEncoder(video.inputSurface, width, height, engineKind)
            if (ctx == 0L) throw IllegalStateException("nativeInitEncoder failed")
            presetData?.let { loadPreset(ctx, it, false) }
            // Push tuning (global audio-response curve + per-shader iParams
            // defaults) exactly like the on-screen path. Without it a shader's
            // iParams read 0, so the visuals render but don't react to audio.
            tuning?.let { if (it.isNotEmpty()) setTuning(ctx, it) }

            try {
                aac = AacEncoder(
                    sampleRate = decoder.sampleRate,
                    channelCount = decoder.channelCount,
                    onFormat = { f -> audioFormat = f; maybeStartMuxer() },
                    onOutput = { buf, info -> writeSample(false, buf, info) },
                )
                audioEnabled = true
            } catch (e: Throwable) {
                Log.w(TAG, "AAC encoder init failed — producing video-only MP4", e)
            }

            val frameDurUs = 1_000_000L / fps
            var nextFrameUs = 0L
            var pcm: AudioDecoder.Pcm? = firstChunk
            while (!cancelled) {
                val c = pcm ?: break
                val tUs = c.presentationTimeUs - startPtsUs
                if (tUs > maxDurationUs) break
                addPcm(ctx, toStereoFloat(c.data, decoder.channelCount))
                aac?.encode(c.data, tUs)
                // Render enough video frames to keep pace with the audio clock.
                while (nextFrameUs <= tUs && !cancelled) {
                    renderAt(ctx, nextFrameUs * 1000L) // µs → ns
                    video.drain(false)
                    nextFrameUs += frameDurUs
                }
                pcm = decoder.read()
            }

            aac?.finish()
            video.drain(true) // signal EOS + flush remaining video
            maybeStartMuxer()
            flushPending()
            if (muxerStarted) muxer?.stop()
            onDone(
                !cancelled && muxerStarted,
                when {
                    cancelled -> "cancelled"
                    !muxerStarted -> "no output produced"
                    else -> null
                },
            )
        } catch (e: Throwable) {
            Log.e(TAG, "transcode failed", e)
            onDone(false, e.message ?: e.toString())
        } finally {
            try { if (ctx != 0L) dispose(ctx) } catch (_: Throwable) {}
            try { aac?.release() } catch (_: Throwable) {}
            try { video?.release() } catch (_: Throwable) {}
            try { muxer?.release() } catch (_: Throwable) {}
            try { decoder?.release() } catch (_: Throwable) {}
        }
    }

    // Start the muxer once the video format (and the audio format, if audio is
    // enabled) is known, then flush anything buffered before start.
    private fun maybeStartMuxer() {
        if (muxerStarted) return
        val vf = videoFormat ?: return
        if (audioEnabled && audioFormat == null) return
        val mux = muxer ?: return
        videoTrack = mux.addTrack(vf)
        audioFormat?.let { audioTrack = mux.addTrack(it) }
        mux.start()
        muxerStarted = true
        flushPending()
    }

    private fun writeSample(isVideo: Boolean, buf: ByteBuffer, info: MediaCodec.BufferInfo) {
        if (info.size <= 0) return
        if (muxerStarted) {
            val track = if (isVideo) videoTrack else audioTrack
            if (track >= 0) muxer?.writeSampleData(track, buf, info)
        } else {
            // The codec recycles `buf` after we return, so copy the bytes.
            val bytes = ByteArray(info.size)
            buf.position(info.offset)
            buf.get(bytes, 0, info.size)
            pending.add(Sample(isVideo, bytes, info.presentationTimeUs, info.flags))
        }
    }

    private fun flushPending() {
        if (!muxerStarted || pending.isEmpty()) return
        val mux = muxer ?: return
        val info = MediaCodec.BufferInfo()
        for (s in pending) {
            val track = if (s.isVideo) videoTrack else audioTrack
            if (track < 0) continue
            info.set(0, s.bytes.size, s.ptsUs, s.flags)
            mux.writeSampleData(track, ByteBuffer.wrap(s.bytes), info)
        }
        pending.clear()
    }

    // Decoder PCM is interleaved 16-bit LE; the visualizer wants interleaved
    // stereo float. Take channels 0/1 (duplicate mono), ignore any extras.
    private fun toStereoFloat(pcm: ByteArray, channels: Int): FloatArray {
        if (channels < 1) return FloatArray(0)
        val stride = channels * 2
        val frames = pcm.size / stride
        val out = FloatArray(frames * 2)
        for (f in 0 until frames) {
            val base = f * stride
            val l = readS16(pcm, base) / 32768f
            val r = if (channels >= 2) readS16(pcm, base + 2) / 32768f else l
            out[f * 2] = l
            out[f * 2 + 1] = r
        }
        return out
    }

    private fun readS16(b: ByteArray, i: Int): Int =
        ((b[i].toInt() and 0xff) or (b[i + 1].toInt() shl 8)).toShort().toInt()

    companion object {
        private const val TAG = "mstream/viz-xcode"
    }
}
