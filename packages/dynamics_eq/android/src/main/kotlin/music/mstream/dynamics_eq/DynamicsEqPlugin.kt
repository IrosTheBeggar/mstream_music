package music.mstream.dynamics_eq

import android.content.Context
import android.media.AudioManager
import android.media.audiofx.DynamicsProcessing
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * A DynamicsProcessing effect (Android 9+) on the player's audio session,
 * used as a graphic equalizer: its pre-EQ stage with one band per cutoff
 * the Dart side sends, no compressor, no post-EQ, and a limiter stage the
 * Dart side switches on to keep boosted bands from clipping (1 ms attack,
 * 60 ms release, 10:1 above -1 dBFS, no make-up gain).
 *
 * Methods (channel "mstream/dynamics_eq"):
 *   isSupported()                              -> Boolean: API 28+ and the
 *       effect library can create one (probed once on a throwaway session)
 *   attach(sessionId, cutoffs, gains, enabled, limiter)
 *                                               -> creates the effect on that
 *       session, releasing any previous one; gains are dB, cutoffs Hz
 *   setGain(band, gain)                         -> one band, dB
 *   setEnabled(enabled)
 *   setLimiter(enabled)                         -> the limiter stage on/off
 *   release()
 *
 * The effect is released when the engine detaches, so a killed engine can
 * never strand one on the session.
 */
class DynamicsEqPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var impl: Impl? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        impl = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) Impl(binding.applicationContext) else null
        channel = MethodChannel(binding.binaryMessenger, "mstream/dynamics_eq")
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        impl?.release()
        impl = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val i = impl
        try {
            when (call.method) {
                "isSupported" -> result.success(i?.isSupported() ?: false)
                "attach" -> {
                    if (i == null) throw IllegalStateException("DynamicsProcessing needs Android 9")
                    i.attach(
                        call.argument<Int>("sessionId")!!,
                        call.argument<List<Double>>("cutoffs")!!,
                        call.argument<List<Double>>("gains")!!,
                        call.argument<Boolean>("enabled") ?: true,
                        call.argument<Boolean>("limiter") ?: false,
                    )
                    result.success(null)
                }
                "setLimiter" -> {
                    i?.setLimiter(call.argument<Boolean>("enabled") ?: false)
                    result.success(null)
                }
                "setGain" -> {
                    i?.setGain(call.argument<Int>("band")!!, call.argument<Double>("gain")!!.toFloat())
                    result.success(null)
                }
                "setEnabled" -> {
                    i?.setEnabled(call.argument<Boolean>("enabled") ?: false)
                    result.success(null)
                }
                "release" -> {
                    i?.release()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("dynamics_eq", e.toString(), null)
        }
    }

    private companion object {
        const val TAG = "DynamicsEq"
    }

    @RequiresApi(Build.VERSION_CODES.P)
    private class Impl(private val context: Context) {
        private var effect: DynamicsProcessing? = null
        private var cutoffs = FloatArray(0)
        private var supported: Boolean? = null

        // Create-and-release one on a throwaway session: the effect is
        // AOSP's, but an OEM build can ship without the library.
        fun isSupported(): Boolean {
            supported?.let { return it }
            val audio = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            val ok = try {
                val id = audio?.generateAudioSessionId() ?: AudioManager.ERROR
                if (id == AudioManager.ERROR) {
                    false
                } else {
                    DynamicsProcessing(0, id, config(1)).release()
                    true
                }
            } catch (e: Exception) {
                false
            }
            supported = ok
            return ok
        }

        fun attach(sessionId: Int, cut: List<Double>, gains: List<Double>, enabled: Boolean, limiter: Boolean) {
            release()
            val c = FloatArray(cut.size) { cut[it].toFloat() }
            val e = DynamicsProcessing(0, sessionId, config(c.size))
            for (b in c.indices) {
                val g = if (b < gains.size) gains[b].toFloat() else 0f
                e.setPreEqBandAllChannelsTo(b, DynamicsProcessing.EqBand(true, c[b], g))
            }
            e.setLimiterAllChannelsTo(limiterStage(limiter))
            e.enabled = enabled
            effect = e
            cutoffs = c
            Log.i(TAG, "attached session=$sessionId bands=${c.size} enabled=$enabled limiter=$limiter")
        }

        fun setLimiter(on: Boolean) {
            val e = effect ?: return
            e.setLimiterAllChannelsTo(limiterStage(on))
            Log.i(TAG, "limiter=$on")
        }

        // The stage is always allocated (config) and switched here, so a
        // toggle never rebuilds the effect. inUse, enabled, link group,
        // attack ms, release ms, ratio, threshold dBFS, post gain dB.
        private fun limiterStage(on: Boolean): DynamicsProcessing.Limiter =
            DynamicsProcessing.Limiter(true, on, 0, 1f, 60f, 10f, -1f, 0f)

        fun setGain(band: Int, gain: Float) {
            val e = effect ?: return
            if (band !in cutoffs.indices) return
            e.setPreEqBandAllChannelsTo(band, DynamicsProcessing.EqBand(true, cutoffs[band], gain))
        }

        fun setEnabled(on: Boolean) {
            effect?.enabled = on
        }

        fun release() {
            effect?.release()
            effect = null
        }

        // Stereo is a hint only: the framework keeps the session's real
        // channel count and the band setters apply to all channels.
        private fun config(bands: Int): DynamicsProcessing.Config =
            DynamicsProcessing.Config.Builder(
                DynamicsProcessing.VARIANT_FAVOR_FREQUENCY_RESOLUTION,
                2,
                true, bands,
                false, 0,
                false, 0,
                true,
            ).build()
    }
}
