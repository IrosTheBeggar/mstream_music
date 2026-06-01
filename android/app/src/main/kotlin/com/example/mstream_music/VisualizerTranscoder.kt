package com.example.mstream_music

import android.util.Log
import android.view.Surface

/**
 * Transcodes a track into an A/V program of the app's visualizer reacting to
 * it. Decodes the source audio to PCM; that PCM both drives an off-screen
 * visualizer engine (rendering into an H.264 encoder's input Surface, stamped
 * from the audio clock) and is re-encoded to AAC. The two elementary streams
 * are handed to an [AvSink] — [Mp4Sink] for an on-phone MP4, or [TsHlsSink] for
 * MPEG-TS/HLS segments to cast.
 *
 * Runs on its own thread (owns the EGL context via the native bridge). Audio is
 * best-effort: if the AAC encoder can't be set up, the output is video-only.
 * Reports completion via [onDone] (success, then the playable path or an error)
 * on this thread, so the caller should hop to the main thread for UI.
 */
class VisualizerTranscoder(
    private val source: String,
    private val sink: AvSink,
    private val width: Int,
    private val height: Int,
    private val engineKind: Int,
    private val fps: Int,
    private val maxDurationUs: Long,
    private val pace: Boolean,
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

            video = VideoEncoder(
                width = width,
                height = height,
                frameRate = fps,
                onFormat = { f -> sink.onVideoFormat(f) },
                onOutput = { buf, info -> sink.writeVideo(buf, info) },
            )
            ctx = initEncoder(video.inputSurface, width, height, engineKind)
            if (ctx == 0L) throw IllegalStateException("nativeInitEncoder failed")
            presetData?.let { loadPreset(ctx, it, false) }
            // Push tuning (global audio-response curve + per-shader iParams
            // defaults) like the on-screen path; without it shader iParams read
            // 0 and the visuals render but don't react to audio.
            tuning?.let { if (it.isNotEmpty()) setTuning(ctx, it) }

            var audioEnabled = false
            try {
                aac = AacEncoder(
                    sampleRate = decoder.sampleRate,
                    channelCount = decoder.channelCount,
                    onFormat = { f -> sink.onAudioFormat(f) },
                    onOutput = { buf, info -> sink.writeAudio(buf, info) },
                )
                audioEnabled = true
            } catch (e: Throwable) {
                Log.w(TAG, "AAC encoder init failed — video only", e)
            }
            sink.init(audioEnabled)

            val frameDurUs = 1_000_000L / fps
            var nextFrameUs = 0L
            var pcm: AudioDecoder.Pcm? = firstChunk
            val startWallNs = System.nanoTime()
            while (!cancelled) {
                val c = pcm ?: break
                val tUs = c.presentationTimeUs - startPtsUs
                if (maxDurationUs > 0 && tUs > maxDurationUs) break // <=0 = whole track
                addPcm(ctx, toStereoFloat(c.data, decoder.channelCount))
                aac?.encode(c.data, tUs)
                // Render enough video frames to keep pace with the audio clock.
                while (nextFrameUs <= tUs && !cancelled) {
                    renderAt(ctx, nextFrameUs * 1000L) // µs → ns
                    video.drain(false)
                    nextFrameUs += frameDurUs
                }
                // Live cast: throttle to ~realtime so we don't transcode the whole
                // track in one CPU/thermal burst. Keep at most PACING_LEAD_US of
                // media ahead of wall-clock — the initial lead bursts out fast (so
                // casting can start on the first segments), then we run ~realtime.
                if (pace) {
                    val elapsedUs = (System.nanoTime() - startWallNs) / 1000L
                    val sleepUs = (tUs - elapsedUs) - PACING_LEAD_US
                    if (sleepUs > 0) {
                        try {
                            sleep(sleepUs / 1000L, ((sleepUs % 1000L) * 1000L).toInt())
                        } catch (_: InterruptedException) {
                            // woken to re-check `cancelled`
                        }
                    }
                }
                pcm = decoder.read()
            }

            aac?.finish()
            video.drain(true) // signal EOS + flush remaining video
            val out = sink.finish()
            onDone(!cancelled, if (cancelled) "cancelled" else out)
        } catch (e: Throwable) {
            Log.e(TAG, "transcode failed", e)
            onDone(false, e.message ?: e.toString())
        } finally {
            try { if (ctx != 0L) dispose(ctx) } catch (_: Throwable) {}
            try { aac?.release() } catch (_: Throwable) {}
            try { video?.release() } catch (_: Throwable) {}
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
        // When pacing a live cast, stay at most this far ahead of realtime.
        private const val PACING_LEAD_US = 5_000_000L
    }
}
