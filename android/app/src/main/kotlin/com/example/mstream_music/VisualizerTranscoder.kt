package com.example.mstream_music

import android.media.MediaCodec
import android.media.MediaMuxer
import android.util.Log
import android.view.Surface

/**
 * Phase 0a spike: transcode a track into an MP4 of the app's visualizer
 * reacting to it, to validate the on-device A/V pipeline before wiring it to
 * casting.
 *
 * Pipeline (all on this thread, which owns the EGL context via the native
 * bridge): decode the source audio to PCM → drive an off-screen visualizer
 * engine that renders into an H.264 encoder's input Surface (timestamped from
 * the audio clock) → mux the encoded video to [outputPath].
 *
 * This first cut writes **video only** (a silent MP4) so the render→encode→mux
 * path and visual quality can be judged on the phone with no Chromecast. Audio
 * (AAC) muxing and live HLS streaming build on top of this.
 *
 * Reports completion via [onDone] (success, errorMessage?) — invoked on this
 * thread, so the caller should hop back to the main thread to touch UI.
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
    private val initEncoder: (Surface, Int, Int, Int) -> Long,
    private val renderAt: (Long, Long) -> Unit,
    private val addPcm: (Long, FloatArray) -> Unit,
    private val loadPreset: (Long, String, Boolean) -> Unit,
    private val dispose: (Long) -> Unit,
    private val onDone: (Boolean, String?) -> Unit,
) : Thread("mstream-viz-transcode") {

    @Volatile private var cancelled = false
    fun cancelTranscode() { cancelled = true }

    override fun run() {
        var decoder: AudioDecoder? = null
        var video: VideoEncoder? = null
        var muxer: MediaMuxer? = null
        var ctx = 0L
        var videoTrack = -1
        var started = false
        try {
            decoder = AudioDecoder(source)
            // First chunk establishes the clock and confirms the source decodes.
            val firstChunk =
                decoder.read() ?: throw IllegalStateException("no audio decoded")

            muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            val mux = muxer
            video = VideoEncoder(
                width = width,
                height = height,
                frameRate = fps,
                onFormat = { fmt ->
                    if (videoTrack < 0) {
                        videoTrack = mux.addTrack(fmt)
                        mux.start()
                        started = true
                    }
                },
                onOutput = { buf, info ->
                    // MediaCodec always emits the format change before the first
                    // sample, so `started` is true by the time samples arrive.
                    if (started && info.size > 0) mux.writeSampleData(videoTrack, buf, info)
                },
            )

            ctx = initEncoder(video.inputSurface, width, height, engineKind)
            if (ctx == 0L) throw IllegalStateException("nativeInitEncoder failed")
            presetData?.let { loadPreset(ctx, it, false) }

            val frameDurUs = 1_000_000L / fps
            var nextFrameUs = 0L
            val startPtsUs = firstChunk.presentationTimeUs

            var pcm: AudioDecoder.Pcm? = firstChunk
            while (!cancelled) {
                val c = pcm ?: break
                val tUs = c.presentationTimeUs - startPtsUs
                if (tUs > maxDurationUs) break
                addPcm(ctx, toStereoFloat(c.data, decoder.channelCount))
                // Render enough video frames to keep pace with the audio clock.
                while (nextFrameUs <= tUs && !cancelled) {
                    renderAt(ctx, nextFrameUs * 1000L) // µs → ns
                    video.drain(false)
                    nextFrameUs += frameDurUs
                }
                pcm = decoder.read()
            }

            video.drain(true) // signal EOS + flush
            if (started) mux.stop()
            onDone(!cancelled, if (cancelled) "cancelled" else null)
        } catch (e: Throwable) {
            Log.e(TAG, "transcode failed", e)
            onDone(false, e.message ?: e.toString())
        } finally {
            try { if (ctx != 0L) dispose(ctx) } catch (_: Throwable) {}
            try { video?.release() } catch (_: Throwable) {}
            try { muxer?.release() } catch (_: Throwable) {}
            try { decoder?.release() } catch (_: Throwable) {}
        }
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
