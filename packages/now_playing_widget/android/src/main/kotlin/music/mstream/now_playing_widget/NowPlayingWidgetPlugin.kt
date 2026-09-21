package music.mstream.now_playing_widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
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
 *
 * Progress on the large layout advances natively: Dart sends a position fix,
 * and a ticker re-draws the bar and the elapsed time every few seconds while
 * a track with a known length is playing, the screen is on and a placed
 * widget is large enough to show them — a partial update, no cover, no Dart.
 */
class NowPlayingWidgetPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        appContext = context
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
            // The iOS side holds a cold-launch intent for this; Android's
            // taps never pass through Dart, so there is nothing to release.
            "ready" -> result.success(null)
            "requestPin" -> result.success(requestPin(context))
            "debugState" -> result.success(debugState(context))
            "debugForceLayout" -> {
                val name = call.arguments as? String
                Renderer.forcedLayout = if (name == null || name == "auto") null else Layout.byName(name)
                publish(context, Store.load(context))
                result.success(Renderer.forcedLayout?.name ?: "auto")
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        private const val TAG = "NowPlayingWidget"
        private const val TICK_MS = 5_000L
        /** Screen off: nothing to see; look again later rather than draw. */
        private const val IDLE_MS = 30_000L
        private val executor: ExecutorService = Executors.newSingleThreadExecutor()
        @Volatile private var generation = 0
        @Volatile private var appContext: Context? = null
        private val ticker = Handler(Looper.getMainLooper())
        private val tick = Runnable { onTick() }

        fun publish(context: Context, snapshot: NowPlayingSnapshot) {
            Store.save(context, snapshot)
            val gen = ++generation
            scheduleTicks(context)
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

        /** (Re)arm the progress ticker against the current store; safe to call often. */
        fun scheduleTicks(context: Context) {
            appContext = context.applicationContext
            ticker.removeCallbacks(tick)
            if (shouldTick(context)) ticker.postDelayed(tick, TICK_MS)
        }

        private fun onTick() {
            val ctx = appContext ?: return
            if (!shouldTick(ctx)) return
            val pm = ctx.getSystemService(Context.POWER_SERVICE) as? PowerManager
            if (pm != null && !pm.isInteractive) {
                ticker.postDelayed(tick, IDLE_MS)
                return
            }
            executor.execute { Renderer.renderProgress(ctx) }
            ticker.postDelayed(tick, TICK_MS)
        }

        private fun shouldTick(context: Context): Boolean {
            val s = Store.load(context)
            return s.hasTrack && s.playing && s.durationMs > 0 && Renderer.anyProgressInstance(context)
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
            val manager = AppWidgetManager.getInstance(context)
            val ids = Renderer.ids(context, manager)
            return mapOf(
                "instances" to ids.size,
                "layouts" to ids.map { id -> Layout.candidates(manager.getAppWidgetOptions(id)).map { it.name } },
                "sizes" to ids.map { id ->
                    val o = manager.getAppWidgetOptions(id)
                    val listed = Layout.sizes(o).map { "${it.width.toInt()}x${it.height.toInt()}" }
                    listed.ifEmpty {
                        listOf(
                            "min ${o?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) ?: 0}x" +
                                "${o?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT) ?: 0}",
                        )
                    }
                },
                "forced" to (Renderer.forcedLayout?.name ?: "auto"),
                "snapshot" to snapshot.toStore(),
                "artCached" to (ArtLoader.cached(context, snapshot.artKey) != null),
                "audioServiceRunning" to Renderer.audioServiceRunning(context),
                "dartUp" to Transport.dartUp,
                "mediaBrowserService" to Transport.serviceComponent(context)?.flattenToShortString(),
            )
        }
    }
}
