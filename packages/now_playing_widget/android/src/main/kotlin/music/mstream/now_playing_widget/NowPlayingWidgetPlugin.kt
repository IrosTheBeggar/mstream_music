package music.mstream.now_playing_widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * `mstream/now_playing_widget`: Dart pushes a snapshot ("publish"), this
 * persists it and re-renders every placed widget — at once with whatever
 * cover is already on disk, then again once a missing cover has been fetched.
 * Rendering runs off the platform thread (the art fetch blocks on the
 * network); a newer publish cancels an older one's second pass.
 */
class NowPlayingWidgetPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "mstream/now_playing_widget")
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        Transport.onDartDetached()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "publish" -> {
                val snapshot = NowPlayingSnapshot.fromChannel(call.arguments as? Map<*, *>)
                publish(context, snapshot)
                // main() publishes only once the audio handler is initialised:
                // a button tap that was waiting for it may go out now.
                Transport.onDartPublished()
                result.success(null)
            }
            "requestPin" -> result.success(requestPin(context))
            "debugState" -> result.success(debugState(context))
            else -> result.notImplemented()
        }
    }

    companion object {
        private const val TAG = "NowPlayingWidget"
        private val executor: ExecutorService = Executors.newSingleThreadExecutor()
        @Volatile private var generation = 0

        fun publish(context: Context, snapshot: NowPlayingSnapshot) {
            Store.save(context, snapshot)
            val gen = ++generation
            executor.execute {
                val manager = AppWidgetManager.getInstance(context)
                val ids = Renderer.ids(context, manager)
                if (ids.isEmpty()) {
                    Log.i(TAG, "publish: no widget placed (hasTrack=${snapshot.hasTrack} playing=${snapshot.playing})")
                    return@execute
                }
                val cached = ArtLoader.cached(context, snapshot.artKey)
                Renderer.render(context, manager, ids, snapshot, cached, source = "publish")
                if (cached != null || snapshot.artUrl.isEmpty() || !snapshot.hasTrack) {
                    Log.i(TAG, "art: ${if (cached != null) "cached" else "none"}")
                    return@execute
                }
                val fetched = ArtLoader.fetch(context, snapshot.artUrl)
                if (fetched == null) {
                    Log.i(TAG, "art: unavailable")
                    return@execute
                }
                // Only the newest snapshot may draw; an older fetch that lands
                // after a skip would put the previous cover on the new track.
                if (gen != generation) return@execute
                Renderer.render(context, manager, ids, snapshot, fetched, source = "art")
            }
        }

        fun requestPin(context: Context): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
            val manager = AppWidgetManager.getInstance(context)
            if (!manager.isRequestPinAppWidgetSupported) return false
            return try {
                manager.requestPinAppWidget(Renderer.component(context), null, null)
            } catch (e: Exception) {
                Log.w(TAG, "requestPin failed: ${e.javaClass.simpleName}")
                false
            }
        }

        fun debugState(context: Context): Map<String, Any?> {
            val snapshot = Store.load(context)
            return mapOf(
                "instances" to Renderer.ids(context).size,
                "snapshot" to snapshot.toStore(),
                "artCached" to (ArtLoader.cached(context, snapshot.artKey) != null),
                "audioServiceRunning" to Renderer.audioServiceRunning(context),
                "dartUp" to Transport.dartUp,
                "mediaBrowserService" to Transport.serviceComponent(context)?.flattenToShortString(),
            )
        }
    }
}
