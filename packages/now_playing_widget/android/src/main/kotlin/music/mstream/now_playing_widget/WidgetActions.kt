package music.mstream.now_playing_widget

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.support.v4.media.MediaBrowserCompat
import android.support.v4.media.session.MediaControllerCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.util.Log
import androidx.media.MediaBrowserServiceCompat

/**
 * The widget's buttons. A tap is a broadcast to [WidgetActionReceiver]
 * (this package only), which drives audio_service's media session through
 * its transport controls — explicit play / pause / skip / shuffle / repeat on
 * the session, the same calls the system's own media controls make.
 *
 * Why not a media-key broadcast to audio_service's MediaButtonReceiver, the
 * way a Bluetooth key arrives: audio_service tells an explicit play apart
 * from the toggle by hijacking KEYCODE_MUTE, and Android no longer counts
 * that key as a media-session key (its own notification "play" shares the
 * fate; the system player uses the session directly). A genuine PLAY key
 * would fold into the handler's toggle — wrong whenever the widget's state
 * is stale, e.g. a "Pause" left behind by a killed process would start
 * playback instead of leaving it stopped.
 *
 * Binding the MediaBrowserService starts it, so a tap on a dead app boots
 * the service headless — the Dart engine, the handler and its saved queue —
 * and the action is held until the handler is up ([Transport]).
 */
enum class WidgetAction(val intentAction: String) {
    PLAY("music.mstream.now_playing_widget.PLAY"),
    PAUSE("music.mstream.now_playing_widget.PAUSE"),
    NEXT("music.mstream.now_playing_widget.NEXT"),
    PREVIOUS("music.mstream.now_playing_widget.PREVIOUS"),
    SHUFFLE("music.mstream.now_playing_widget.SHUFFLE"),
    REPEAT("music.mstream.now_playing_widget.REPEAT");

    /** The toggles read the state the widget showed, so a tap means what the icon meant. */
    fun send(controls: MediaControllerCompat.TransportControls, shown: NowPlayingSnapshot) = when (this) {
        PLAY -> controls.play()
        PAUSE -> controls.pause()
        NEXT -> controls.skipToNext()
        PREVIOUS -> controls.skipToPrevious()
        SHUFFLE -> controls.setShuffleMode(
            if (shown.shuffle) PlaybackStateCompat.SHUFFLE_MODE_NONE else PlaybackStateCompat.SHUFFLE_MODE_ALL,
        )
        REPEAT -> controls.setRepeatMode(
            when (shown.nextRepeat) {
                NowPlayingSnapshot.REPEAT_ALL -> PlaybackStateCompat.REPEAT_MODE_ALL
                NowPlayingSnapshot.REPEAT_ONE -> PlaybackStateCompat.REPEAT_MODE_ONE
                else -> PlaybackStateCompat.REPEAT_MODE_NONE
            },
        )
    }

    fun pendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, WidgetActionReceiver::class.java).setAction(intentAction)
        return PendingIntent.getBroadcast(
            context, ordinal, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    companion object {
        fun from(intentAction: String?): WidgetAction? =
            entries.firstOrNull { it.intentAction == intentAction }
    }
}

class WidgetActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = WidgetAction.from(intent.action) ?: return
        Log.i(Transport.TAG, "tap: $action")
        Transport.send(context.applicationContext, action)
    }
}

/**
 * One action at a time against the media session: connect a MediaBrowser
 * (which starts the service when it is not running), wait until the Dart
 * handler is up, send, disconnect.
 *
 * "Up" is what makes a cold boot work. The session exists — and answers the
 * connection — as soon as the service's onCreate ran, seconds before the
 * Dart engine has attached its listener; audio_service drops a transport
 * command that arrives in that window. Two signals say the handler is
 * there: the plugin has received a publish from Dart ([dartUp], which main()
 * sends only after the handler is initialised), or the session's actions
 * carry a skip — audio_service's own baseline actions never do, the app's
 * handler always advertises both. A newer tap replaces one still waiting.
 */
object Transport {
    const val TAG = "NowPlayingWidget"
    private const val TIMEOUT_MS = 15_000L
    private const val HANDLER_ACTIONS =
        PlaybackStateCompat.ACTION_SKIP_TO_NEXT or PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS

    private val main = Handler(Looper.getMainLooper())
    private var inFlight: Connection? = null

    /** Set by the plugin once Dart has published (and cleared when its engine detaches). */
    @Volatile var dartUp: Boolean = false
        private set

    fun onDartPublished() {
        if (dartUp) return
        dartUp = true
        main.post { inFlight?.attempt() }
    }

    fun onDartDetached() {
        dartUp = false
    }

    /** The app's MediaBrowserService (audio_service's), or null in a broken build. */
    fun serviceComponent(context: Context): ComponentName? {
        val query = Intent(MediaBrowserServiceCompat.SERVICE_INTERFACE).setPackage(context.packageName)
        val info = context.packageManager.queryIntentServices(query, 0).firstOrNull()?.serviceInfo ?: return null
        return ComponentName(info.packageName, info.name)
    }

    fun send(context: Context, action: WidgetAction) {
        val service = serviceComponent(context)
        if (service == null) {
            Log.w(TAG, "$action: no media browser service in this build")
            return
        }
        // What the widget showed when it was tapped: the toggles act on it.
        val shown = Store.load(context)
        main.post {
            inFlight?.finish("superseded by $action")
            inFlight = Connection(context, service, action, shown).also { it.start() }
        }
    }

    private class Connection(
        private val context: Context,
        service: ComponentName,
        private val action: WidgetAction,
        private val shown: NowPlayingSnapshot,
    ) : MediaBrowserCompat.ConnectionCallback() {
        private val browser = MediaBrowserCompat(context, service, this, null)
        private var controller: MediaControllerCompat? = null
        private var done = false
        private val timeout = Runnable { finish("gave up waiting for the handler") }
        private val callback = object : MediaControllerCompat.Callback() {
            override fun onPlaybackStateChanged(state: PlaybackStateCompat?) = attempt()
            override fun onSessionDestroyed() = finish("session destroyed")
        }

        fun start() {
            main.postDelayed(timeout, TIMEOUT_MS)
            browser.connect()
        }

        override fun onConnected() {
            val c = try {
                MediaControllerCompat(context, browser.sessionToken)
            } catch (e: Exception) {
                finish("no controller: ${e.javaClass.simpleName}")
                return
            }
            controller = c
            c.registerCallback(callback, main)
            attempt()
        }

        override fun onConnectionFailed() = finish("connection failed")
        override fun onConnectionSuspended() = finish("connection suspended")

        fun attempt() {
            if (done) return
            val c = controller ?: return
            val actions = c.playbackState?.actions ?: 0L
            val ready = dartUp || (actions and HANDLER_ACTIONS) != 0L
            if (!ready) {
                Log.i(TAG, "$action: handler not up yet, waiting")
                return
            }
            action.send(c.transportControls, shown)
            Log.i(TAG, "$action: sent")
            finish(null)
        }

        fun finish(reason: String?) {
            if (done) return
            done = true
            if (reason != null) Log.w(TAG, "$action: $reason")
            main.removeCallbacks(timeout)
            controller?.unregisterCallback(callback)
            browser.disconnect()
            if (inFlight === this) inFlight = null
        }
    }
}
