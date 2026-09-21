package music.mstream.now_playing_widget

import android.app.ActivityManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import java.io.File
import java.util.Locale

/**
 * The home-screen widget. The launcher calls this for its own reasons (a
 * placement, a resize, a reboot, a launcher restart); every one of those is
 * answered from the persisted snapshot, so no Dart is needed. The app's own
 * pushes come in through NowPlayingWidgetPlugin, which renders directly.
 */
class NowPlayingWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        Renderer.renderFromStore(context, manager, ids)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context, manager: AppWidgetManager, id: Int, newOptions: Bundle,
    ) {
        Renderer.renderFromStore(context, manager, intArrayOf(id))
    }
}

/** The persisted snapshot (see NowPlayingSnapshot). */
object Store {
    private const val PREFS = "now_playing_widget"

    fun load(context: Context): NowPlayingSnapshot =
        NowPlayingSnapshot.fromStore(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).all)

    fun save(context: Context, snapshot: NowPlayingSnapshot) {
        val editor = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
        snapshot.toStore().forEach { (k, v) -> editor.putString(k, v) }
        editor.apply()
    }
}

object Renderer {
    private const val TAG = "NowPlayingWidget"
    private const val AUDIO_SERVICE = "com.ryanheise.audioservice.AudioService"
    /** From this many dp of height the tall layout (bigger art, buttons on their own row). */
    private const val TALL_FROM_DP = 100

    fun component(context: Context) = ComponentName(context, NowPlayingWidgetProvider::class.java)

    fun ids(context: Context, manager: AppWidgetManager = AppWidgetManager.getInstance(context)): IntArray =
        manager.getAppWidgetIds(component(context))

    /**
     * A launcher-initiated render: the last snapshot, with `playing` trusted
     * only while audio_service's service is actually up — after a reboot or an
     * OOM kill the store still says "playing" and nothing else would ever
     * correct it. The cover comes from disk under the snapshot's art key.
     */
    fun renderFromStore(context: Context, manager: AppWidgetManager, ids: IntArray) {
        var snapshot = Store.load(context)
        if (snapshot.playing && !audioServiceRunning(context)) {
            snapshot = snapshot.copy(playing = false)
        }
        val art = ArtLoader.cached(context, snapshot.artKey)
        render(context, manager, ids, snapshot, art, source = "launcher")
    }

    fun render(
        context: Context, manager: AppWidgetManager, ids: IntArray,
        snapshot: NowPlayingSnapshot, art: File?, source: String,
    ) {
        if (ids.isEmpty()) return
        val radius = context.resources.getDimension(R.dimen.npw_art_corner)
        val bitmap = art?.let { ArtLoader.load(it, radius) }
        val ctx = localized(context, snapshot.locale)
        for (id in ids) {
            val layout = layoutFor(manager.getAppWidgetOptions(id))
            manager.updateAppWidget(id, build(ctx, layout, snapshot, bitmap))
        }
        Log.i(
            TAG, "render ($source) n=${ids.size} hasTrack=${snapshot.hasTrack} " +
                "playing=${snapshot.playing} art=${bitmap != null} title=\"${snapshot.title}\"",
        )
    }

    fun layoutFor(options: Bundle?): Int {
        val minHeight = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0) ?: 0
        return if (minHeight >= TALL_FROM_DP) R.layout.now_playing_widget_tall else R.layout.now_playing_widget
    }

    private fun build(
        context: Context, layout: Int, s: NowPlayingSnapshot, art: Bitmap?,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, layout)
        // Anywhere that is not a button opens the app.
        views.setOnClickPendingIntent(R.id.npw_root, launchIntent(context))
        if (!s.hasTrack) {
            views.setViewVisibility(R.id.npw_track, View.GONE)
            views.setViewVisibility(R.id.npw_empty, View.VISIBLE)
            views.setViewVisibility(R.id.npw_buttons, View.GONE)
            views.setTextViewText(R.id.npw_empty_title, context.getString(R.string.npw_nothing_playing))
            views.setTextViewText(R.id.npw_empty_hint, context.getString(R.string.npw_open_app))
            views.setImageViewResource(R.id.npw_art, R.drawable.npw_art_placeholder)
            return views
        }
        views.setViewVisibility(R.id.npw_track, View.VISIBLE)
        views.setViewVisibility(R.id.npw_empty, View.GONE)
        views.setViewVisibility(R.id.npw_buttons, View.VISIBLE)
        views.setTextViewText(R.id.npw_title, s.title)
        views.setTextViewText(R.id.npw_subtitle, s.subtitle)
        views.setViewVisibility(R.id.npw_subtitle, if (s.subtitle.isEmpty()) View.GONE else View.VISIBLE)
        if (art != null) {
            views.setImageViewBitmap(R.id.npw_art, art)
        } else {
            views.setImageViewResource(R.id.npw_art, R.drawable.npw_art_placeholder)
        }
        if (s.playing) {
            views.setImageViewResource(R.id.npw_play_pause, R.drawable.npw_ic_pause)
            views.setContentDescription(R.id.npw_play_pause, context.getString(R.string.npw_pause))
            views.setOnClickPendingIntent(R.id.npw_play_pause, WidgetAction.PAUSE.pendingIntent(context))
        } else {
            views.setImageViewResource(R.id.npw_play_pause, R.drawable.npw_ic_play)
            views.setContentDescription(R.id.npw_play_pause, context.getString(R.string.npw_play))
            views.setOnClickPendingIntent(R.id.npw_play_pause, WidgetAction.PLAY.pendingIntent(context))
        }
        views.setContentDescription(R.id.npw_previous, context.getString(R.string.npw_previous))
        views.setOnClickPendingIntent(R.id.npw_previous, WidgetAction.PREVIOUS.pendingIntent(context))
        views.setContentDescription(R.id.npw_next, context.getString(R.string.npw_next))
        views.setOnClickPendingIntent(R.id.npw_next, WidgetAction.NEXT.pendingIntent(context))
        return views
    }

    private fun launchIntent(context: Context): PendingIntent? {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return null
        return PendingIntent.getActivity(
            context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /** Strings in the app's language override when there is one, else the system's. */
    private fun localized(context: Context, tag: String): Context {
        if (tag.isEmpty()) return context
        val config = Configuration(context.resources.configuration).apply {
            setLocale(Locale.forLanguageTag(tag))
        }
        return context.createConfigurationContext(config)
    }

    /** Whether audio_service's foreground service is up (own-package query, no permission). */
    @Suppress("DEPRECATION")
    fun audioServiceRunning(context: Context): Boolean {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager ?: return false
        return try {
            am.getRunningServices(Int.MAX_VALUE).any { it.service.className == AUDIO_SERVICE }
        } catch (e: Exception) {
            false
        }
    }
}
