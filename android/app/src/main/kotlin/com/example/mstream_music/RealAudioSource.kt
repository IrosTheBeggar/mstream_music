// Captures live audio output via android.media.audiofx.Visualizer and
// hands chunks of interleaved-stereo Float PCM to a callback. Used by
// the visualizer's "Real audio" mode.
//
// We attach to audio session 0 (system mix) so we get whatever's
// currently playing through the OS mixer — typically the just_audio
// stream coming out of mstream_music itself, but if the user's
// playing music in another app while our visualizer is open, that
// works too.
//
// Android requires the RECORD_AUDIO permission for any Visualizer
// instance even when capturing your own app's output. The permission
// flow lives in the Settings screen; this class assumes it has
// already been granted and fails soft if not.

package com.example.mstream_music

import android.media.audiofx.Visualizer
import android.util.Log

private const val TAG = "mstream/viz-realaudio"

class RealAudioSource(
    // Audio session to attach the Visualizer to. Pass the app's own
    // player session — session 0 (global output mix) is blocked for
    // normal apps on modern Android (it needs the privileged
    // CAPTURE_AUDIO_OUTPUT permission).
    private val sessionId: Int,
    // Called whenever a fresh waveform chunk arrives. The Float array
    // is interleaved stereo (L,R,L,R,…) in [-1, 1]; size = 2 *
    // captureSize. Same shape as what the synthesized source emits.
    private val onSamples: (FloatArray) -> Unit
) {
    private var visualizer: Visualizer? = null

    /**
     * Returns true if the Visualizer was successfully attached. False
     * means we couldn't start (permission revoked, session 0 not
     * accessible on this OS version, etc.) and the caller should
     * fall back to a synthesized source.
     */
    fun start(): Boolean {
        try {
            val v = Visualizer(sessionId)
            // Largest capture size the device supports (typically 1024).
            val sizeRange = Visualizer.getCaptureSizeRange()
            v.captureSize = sizeRange[1]
            val captureSize = v.captureSize

            v.setDataCaptureListener(
                object : Visualizer.OnDataCaptureListener {
                    // Note: API 36 dropped the trailing 'd' from
                    // these method names. If we ever target an older
                    // SDK that still has *Captured, this will need
                    // a compileSdk-conditional shim.
                    override fun onWaveFormDataCapture(
                        unused: Visualizer,
                        waveform: ByteArray,
                        samplingRate: Int
                    ) {
                        // Android docs: "8-bit unsigned PCM data,
                        // where 0x80 (128) represents zero." Map to
                        // [-1, 1] float and duplicate to stereo so
                        // the downstream FFT pipeline (which expects
                        // interleaved stereo) doesn't have to change.
                        val n = waveform.size
                        val out = FloatArray(n * 2)
                        for (i in 0 until n) {
                            val s = ((waveform[i].toInt() and 0xff) - 128) / 128f
                            out[i * 2] = s
                            out[i * 2 + 1] = s
                        }
                        onSamples(out)
                    }

                    override fun onFftDataCapture(
                        unused: Visualizer,
                        fft: ByteArray,
                        samplingRate: Int
                    ) {
                        // We do our own FFT in C++ off the waveform;
                        // ignore the OS-computed FFT.
                    }
                },
                // Capture rate in milliHertz. Use ~30 Hz to match our
                // synthesized push rate (didn't want to flood the
                // bridge queue).
                30_000.coerceAtMost(Visualizer.getMaxCaptureRate()),
                /* waveform = */ true,
                /* fft      = */ false
            )
            v.enabled = true
            visualizer = v
            Log.i(TAG, "Visualizer attached: captureSize=$captureSize")
            return true
        } catch (e: Throwable) {
            // RuntimeException for permission, UnsupportedOperationException
            // for hardware quirks. Either way, fail soft.
            Log.w(TAG, "Visualizer setup failed: ${e.message}")
            release()
            return false
        }
    }

    fun stop() = release()

    private fun release() {
        try {
            visualizer?.enabled = false
        } catch (_: Throwable) {}
        try {
            visualizer?.release()
        } catch (_: Throwable) {}
        visualizer = null
    }
}
