package music.mstream.dynamics_eq

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.audiofx.DynamicsProcessing
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.RequiresApi
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
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
 *   routeCurrent()                              -> {kind, name, address}: the
 *       output media plays through (the device media routes to on Android
 *       12+, the best available output below); kind is speaker / wired /
 *       bluetooth / usb / hdmi / other
 *
 * Event channel "mstream/dynamics_eq/route": the same map whenever an audio
 * device appears or goes (and once more shortly after, when routing has
 * settled), plus once on subscribe.
 *
 * The effect is released when the engine detaches, so a killed engine can
 * never strand one on the session.
 */
class DynamicsEqPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var routeChannel: EventChannel? = null
    private var routes: RouteStream? = null
    private var impl: Impl? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        impl = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) Impl(binding.applicationContext) else null
        channel = MethodChannel(binding.binaryMessenger, "mstream/dynamics_eq")
        channel?.setMethodCallHandler(this)
        impl?.let { i ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val r = RouteStream(i, binding.applicationContext)
                routes = r
                routeChannel = EventChannel(binding.binaryMessenger, "mstream/dynamics_eq/route")
                routeChannel?.setStreamHandler(r)
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        routeChannel?.setStreamHandler(null)
        routeChannel = null
        routes?.onCancel(null)
        routes = null
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
                "routeCurrent" -> result.success(i?.currentRoute())
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("dynamics_eq", e.toString(), null)
        }
    }

    private companion object {
        const val TAG = "DynamicsEq"
    }

    /** The route on every device change, settled again 800 ms later. */
    @RequiresApi(Build.VERSION_CODES.P)
    private class RouteStream(private val impl: Impl, private val context: Context) : EventChannel.StreamHandler {
        private var callback: AudioDeviceCallback? = null
        // The current subscriber: the delayed re-emit reads it at fire time,
        // so a cancel-and-resubscribe inside the window reaches the new one.
        private var sink: EventChannel.EventSink? = null
        private val main = Handler(Looper.getMainLooper())

        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            val am = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
            onCancel(null)
            sink = events
            val cb = object : AudioDeviceCallback() {
                override fun onAudioDevicesAdded(added: Array<out AudioDeviceInfo>?) = push()
                override fun onAudioDevicesRemoved(removed: Array<out AudioDeviceInfo>?) = push()
            }
            am.registerAudioDeviceCallback(cb, main)
            callback = cb
            push()
        }

        private fun push() {
            sink?.success(impl.currentRoute())
            main.postDelayed({ sink?.success(impl.currentRoute()) }, 800)
        }

        override fun onCancel(arguments: Any?) {
            sink = null
            val cb = callback ?: return
            callback = null
            (context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager)?.unregisterAudioDeviceCallback(cb)
        }
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

        fun currentRoute(): Map<String, Any?> {
            val am = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                ?: return mapOf("kind" to "speaker", "name" to "", "address" to "")
            val d = pickRoute(am)
                ?: return mapOf("kind" to "speaker", "name" to "", "address" to "")
            return mapOf(
                "kind" to kindOf(d.type),
                "name" to d.productName.toString(),
                "address" to (d.address ?: ""),
            )
        }

        // Android 13+ says where media routes (getAudioDevicesForAttributes
        // is API 33); below, the best available output is what the policy
        // would pick anyway. Nothing here may throw: the route stream calls
        // this outside any catch.
        private fun pickRoute(am: AudioManager): AudioDeviceInfo? {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    val attrs = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).build()
                    val routed = am.getAudioDevicesForAttributes(attrs)
                    if (routed.isNotEmpty()) return routed[0]
                }
                val outs = am.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                for (k in listOf("bluetooth", "usb", "wired", "hdmi", "speaker")) {
                    outs.firstOrNull { kindOf(it.type) == k }?.let { return it }
                }
                return outs.firstOrNull()
            } catch (e: Throwable) {
                Log.w(TAG, "route lookup failed: $e")
                return null
            }
        }

        // Numeric literals for the types newer than this plugin's minimum:
        // 24 = BUILTIN_SPEAKER_SAFE, 26/27/30 = BLE headset/speaker/broadcast.
        private fun kindOf(type: Int): String = when (type) {
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP, AudioDeviceInfo.TYPE_BLUETOOTH_SCO, 26, 27, 30 -> "bluetooth"
            AudioDeviceInfo.TYPE_WIRED_HEADSET, AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_LINE_ANALOG, AudioDeviceInfo.TYPE_LINE_DIGITAL -> "wired"
            AudioDeviceInfo.TYPE_USB_DEVICE, AudioDeviceInfo.TYPE_USB_HEADSET, AudioDeviceInfo.TYPE_USB_ACCESSORY -> "usb"
            AudioDeviceInfo.TYPE_HDMI, AudioDeviceInfo.TYPE_HDMI_ARC, AudioDeviceInfo.TYPE_DOCK -> "hdmi"
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER, AudioDeviceInfo.TYPE_BUILTIN_EARPIECE, 24 -> "speaker"
            else -> "other"
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
