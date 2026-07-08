package music.mstream.wifi_lock_shim

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Holds an Android WifiLock while the Dart side says audio is streaming.
 *
 * One method: setHeld(bool). The lock is created from the application
 * context, so it works with no activity alive (background playback), and is
 * released defensively when the engine detaches so a killed engine can never
 * strand it.
 */
class WifiLockShimPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var lock: WifiManager.WifiLock? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val wifi = binding.applicationContext
            .getSystemService(Context.WIFI_SERVICE) as? WifiManager
        // WIFI_MODE_FULL_HIGH_PERF is what ExoPlayer's WAKE_MODE_NETWORK
        // holds, and it is the strongest option the platform offers anywhere:
        // - API <= 33: works as intended — keeps the radio out of power-save
        //   with the screen off. This covers the fleet the "playback stops"
        //   reports came from (Galaxy S20 FE caps at Android 13).
        // - API 34+: the OS silently converts the acquire into a
        //   WIFI_MODE_FULL_LOW_LATENCY lock (WifiManager.java, android-34),
        //   which is only active while the app is FOREGROUND with the SCREEN
        //   ON — i.e. inert for screen-off streaming. No public API restores
        //   the old behavior there; the lock is harmless but ineffective, and
        //   modern Android relies on the FGS media exemption instead. Keep
        //   that in mind before blaming this shim for a stall on 14+.
        @Suppress("DEPRECATION")
        lock = wifi?.createWifiLock(
            WifiManager.WIFI_MODE_FULL_HIGH_PERF, "mstream:streaming"
        )?.apply { setReferenceCounted(false) }
        channel = MethodChannel(binding.binaryMessenger, "mstream/wifi_lock")
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        lock?.takeIf { it.isHeld }?.release()
        lock = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setHeld" -> {
                val want = call.arguments as? Boolean ?: false
                val l = lock
                if (l != null) {
                    if (want && !l.isHeld) l.acquire()
                    else if (!want && l.isHeld) l.release()
                }
                result.success(l?.isHeld ?: false)
            }
            else -> result.notImplemented()
        }
    }
}
