package music.mstream.now_playing_widget

import android.app.ActivityManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.util.SizeF
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
open class NowPlayingWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        Renderer.renderFromStore(context, manager, ids)
        NowPlayingWidgetPlugin.scheduleTicks(context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context, manager: AppWidgetManager, id: Int, newOptions: Bundle,
    ) {
        Renderer.renderFromStore(context, manager, intArrayOf(id))
        NowPlayingWidgetPlugin.scheduleTicks(context)
    }
}

/**
 * The widget picker lists one entry per size (the sizes are what the user
 * asked for; a lone resizable entry hid four of them). Each is its own
 * provider with its own placement size; what a placed widget draws still
 * follows its frame ([Layout.pick]), so any of them can be resized into any
 * other. The 4x1 keeps the original class, so widgets placed before the
 * split stay valid.
 */
class NowPlayingWidgetProviderMini : NowPlayingWidgetProvider()
class NowPlayingWidgetProviderTile : NowPlayingWidgetProvider()
class NowPlayingWidgetProviderCard : NowPlayingWidgetProvider()
class NowPlayingWidgetProviderLarge : NowPlayingWidgetProvider()

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

    /** Debug builds: draw every instance with this layout whatever its size (null = by size). */
    @Volatile var forcedLayout: Layout? = null

    /** A picker entry: its cell size, its provider, and the label the launcher shows for it. */
    data class Entry(val size: String, val provider: Class<out NowPlayingWidgetProvider>, val label: Int)

    /** The five picker entries, smallest first. */
    val entries = listOf(
        Entry("2x1", NowPlayingWidgetProviderMini::class.java, R.string.npw_label_2x1),
        Entry("2x2", NowPlayingWidgetProviderTile::class.java, R.string.npw_label_2x2),
        Entry("4x1", NowPlayingWidgetProvider::class.java, R.string.npw_label_4x1),
        Entry("4x2", NowPlayingWidgetProviderCard::class.java, R.string.npw_label_4x2),
        Entry("4x3", NowPlayingWidgetProviderLarge::class.java, R.string.npw_label_4x3),
    )

    /** The entry for a size ("4x3"); the 4x1 for anything else, as before sizes existed. */
    fun entryFor(size: String?): Entry = entries.firstOrNull { it.size == size } ?: entries.first { it.size == "4x1" }

    /** The provider a pin request places: the given size's, else the 4x1's. */
    fun component(context: Context, size: String? = null) = ComponentName(context, entryFor(size).provider)

    /**
     * What Settings offers to pin: every size with its picker label, in the
     * app's language (the last snapshot's tag) so the row and the launcher's
     * own dialog read alike.
     */
    fun pinTargets(context: Context): List<Map<String, String>> {
        val ctx = localized(context, Store.load(context).locale)
        return entries.map { mapOf("size" to it.size, "label" to ctx.getString(it.label)) }
    }

    private val providers = entries.map { it.provider }

    /** Every placed widget, whichever picker entry it came from. */
    fun ids(context: Context, manager: AppWidgetManager = AppWidgetManager.getInstance(context)): IntArray =
        providers.flatMap { manager.getAppWidgetIds(ComponentName(context, it)).toList() }.toIntArray()

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
        val ctx = localized(context, snapshot.locale)
        // One decode per corner radius, shared by every instance and size.
        val bitmaps = HashMap<Boolean, Bitmap?>()
        fun bitmapFor(layout: Layout): Bitmap? = art?.let { file ->
            bitmaps.getOrPut(layout.artFillsCard) { ArtLoader.load(file, radiusFor(ctx, layout)) }
        }
        val now = System.currentTimeMillis()
        val shown = ArrayList<String>()
        for (id in ids) {
            val options = manager.getAppWidgetOptions(id)
            val forced = forcedLayout
            val views = if (forced != null) {
                shown += forced.name
                build(ctx, forced, snapshot, bitmapFor(forced), now)
            } else {
                sized(ctx, options, snapshot, ::bitmapFor, now)?.also { shown += "sized" } ?: run {
                    val layout = Layout.forOptions(options)
                    shown += layout.name
                    build(ctx, layout, snapshot, bitmapFor(layout), now)
                }
            }
            manager.updateAppWidget(id, views)
        }
        Log.i(
            TAG, "render ($source) n=${ids.size} layouts=$shown hasTrack=${snapshot.hasTrack} " +
                "playing=${snapshot.playing} art=${bitmaps.values.any { it != null }} title=\"${snapshot.title}\"",
        )
    }

    /**
     * Android 12+: one RemoteViews per size the launcher reports for this
     * widget (portrait and landscape); the launcher shows the best fit and
     * switches by itself on rotation or resize.
     */
    private fun sized(
        ctx: Context, options: Bundle?, snapshot: NowPlayingSnapshot,
        bitmapFor: (Layout) -> Bitmap?, now: Long,
    ): RemoteViews? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return null
        val sizes = Layout.sizes(options)
        if (sizes.isEmpty()) return null
        val map = LinkedHashMap<SizeF, RemoteViews>()
        for (size in sizes) {
            val layout = Layout.pick(size.width.toInt(), size.height.toInt())
            map[size] = build(ctx, layout, snapshot, bitmapFor(layout), now)
        }
        return RemoteViews(map)
    }

    /** The progress bar and elapsed time only, for the instances large enough to show them. */
    fun renderProgress(context: Context): Int {
        val s = Store.load(context)
        if (!s.hasTrack || s.durationMs <= 0) return 0
        val manager = AppWidgetManager.getInstance(context)
        val ctx = localized(context, s.locale)
        val now = System.currentTimeMillis()
        var n = 0
        for (id in ids(context, manager)) {
            if (!showsProgress(manager.getAppWidgetOptions(id))) continue
            val views = RemoteViews(ctx.packageName, Layout.LARGE.res)
            setProgress(views, s, now)
            manager.partiallyUpdateAppWidget(id, views)
            n++
        }
        return n
    }

    fun anyProgressInstance(context: Context): Boolean {
        val manager = AppWidgetManager.getInstance(context)
        return ids(context, manager).any { showsProgress(manager.getAppWidgetOptions(it)) }
    }

    private fun showsProgress(options: Bundle?): Boolean =
        forcedLayout?.hasProgress ?: Layout.candidates(options).any { it.hasProgress }

    fun build(ctx: Context, layout: Layout, s: NowPlayingSnapshot, art: Bitmap?, now: Long): RemoteViews {
        val views = RemoteViews(ctx.packageName, layout.res)
        // Anywhere that is not a button opens the app.
        views.setOnClickPendingIntent(R.id.npw_root, launchIntent(ctx))
        val accent = ctx.getColor(R.color.npw_icon)
        val secondary = ctx.getColor(R.color.npw_text_secondary)
        // Over the tile's scrim the glyphs are always light; on the large
        // play button they sit on an accent disc in the card's colour.
        val glyph = if (layout == Layout.TILE) ctx.getColor(R.color.npw_tile_icon) else accent
        val playGlyph = if (layout == Layout.LARGE) ctx.getColor(R.color.npw_background) else glyph

        if (!s.hasTrack) {
            views.setViewVisibility(R.id.npw_track, View.GONE)
            views.setViewVisibility(R.id.npw_empty, View.VISIBLE)
            views.setViewVisibility(R.id.npw_buttons, View.GONE)
            if (layout.hasProgress) views.setViewVisibility(R.id.npw_progress_group, View.GONE)
            views.setTextViewText(R.id.npw_empty_title, ctx.getString(R.string.npw_nothing_playing))
            views.setTextViewText(R.id.npw_empty_hint, ctx.getString(R.string.npw_open_app))
            views.setImageViewResource(R.id.npw_art, R.drawable.npw_art_placeholder)
            return views
        }
        views.setViewVisibility(R.id.npw_track, View.VISIBLE)
        views.setViewVisibility(R.id.npw_empty, View.GONE)
        views.setViewVisibility(R.id.npw_buttons, View.VISIBLE)
        views.setTextViewText(R.id.npw_title, s.title)
        views.setTextViewText(R.id.npw_subtitle, s.subtitle)
        views.setViewVisibility(R.id.npw_subtitle, if (s.subtitle.isEmpty()) View.GONE else View.VISIBLE)
        if (layout.hasAlbumLine) {
            // The album gets its own line only when the artist has the second.
            val album = if (s.artist.isNotEmpty()) s.album else ""
            views.setTextViewText(R.id.npw_album, album)
            views.setViewVisibility(R.id.npw_album, if (album.isEmpty()) View.GONE else View.VISIBLE)
        }
        if (art != null) {
            views.setImageViewBitmap(R.id.npw_art, art)
        } else {
            views.setImageViewResource(R.id.npw_art, R.drawable.npw_art_placeholder)
        }
        if (s.playing) {
            views.setImageViewResource(R.id.npw_play_pause, R.drawable.npw_ic_pause)
            views.setContentDescription(R.id.npw_play_pause, ctx.getString(R.string.npw_pause))
            views.setOnClickPendingIntent(R.id.npw_play_pause, WidgetAction.PAUSE.pendingIntent(ctx))
        } else {
            views.setImageViewResource(R.id.npw_play_pause, R.drawable.npw_ic_play)
            views.setContentDescription(R.id.npw_play_pause, ctx.getString(R.string.npw_play))
            views.setOnClickPendingIntent(R.id.npw_play_pause, WidgetAction.PLAY.pendingIntent(ctx))
        }
        views.setInt(R.id.npw_play_pause, "setColorFilter", playGlyph)
        if (layout.hasPrevious) {
            views.setContentDescription(R.id.npw_previous, ctx.getString(R.string.npw_previous))
            views.setOnClickPendingIntent(R.id.npw_previous, WidgetAction.PREVIOUS.pendingIntent(ctx))
            views.setInt(R.id.npw_previous, "setColorFilter", glyph)
        }
        if (layout.hasNext) {
            views.setContentDescription(R.id.npw_next, ctx.getString(R.string.npw_next))
            views.setOnClickPendingIntent(R.id.npw_next, WidgetAction.NEXT.pendingIntent(ctx))
            views.setInt(R.id.npw_next, "setColorFilter", glyph)
        }
        if (layout.hasModes) {
            views.setInt(R.id.npw_shuffle, "setColorFilter", if (s.shuffle) accent else secondary)
            views.setContentDescription(
                R.id.npw_shuffle, ctx.getString(if (s.shuffle) R.string.npw_shuffle_on else R.string.npw_shuffle_off),
            )
            views.setOnClickPendingIntent(R.id.npw_shuffle, WidgetAction.SHUFFLE.pendingIntent(ctx))
            val repeatOn = s.repeat != NowPlayingSnapshot.REPEAT_NONE
            views.setImageViewResource(
                R.id.npw_repeat,
                if (s.repeat == NowPlayingSnapshot.REPEAT_ONE) R.drawable.npw_ic_repeat_one else R.drawable.npw_ic_repeat,
            )
            views.setInt(R.id.npw_repeat, "setColorFilter", if (repeatOn) accent else secondary)
            views.setContentDescription(
                R.id.npw_repeat, ctx.getString(
                    when (s.repeat) {
                        NowPlayingSnapshot.REPEAT_ALL -> R.string.npw_repeat_all
                        NowPlayingSnapshot.REPEAT_ONE -> R.string.npw_repeat_one
                        else -> R.string.npw_repeat_off
                    },
                ),
            )
            views.setOnClickPendingIntent(R.id.npw_repeat, WidgetAction.REPEAT.pendingIntent(ctx))
        }
        if (layout.hasProgress) {
            if (s.durationMs > 0) {
                views.setViewVisibility(R.id.npw_progress_group, View.VISIBLE)
                setProgress(views, s, now)
                views.setTextViewText(R.id.npw_duration, NowPlayingSnapshot.formatTime(s.durationMs))
            } else {
                views.setViewVisibility(R.id.npw_progress_group, View.GONE)
            }
        }
        return views
    }

    /** Whole seconds: a 4 dp bar needs no finer, and an Int can hold any track. */
    private fun setProgress(views: RemoteViews, s: NowPlayingSnapshot, now: Long) {
        val position = s.positionNow(now)
        views.setProgressBar(
            R.id.npw_progress, (s.durationMs / 1000).toInt().coerceAtLeast(1),
            (position / 1000).toInt(), false,
        )
        views.setTextViewText(R.id.npw_elapsed, NowPlayingSnapshot.formatTime(position))
    }

    private fun radiusFor(ctx: Context, layout: Layout): Float =
        ctx.resources.getDimension(if (layout.artFillsCard) R.dimen.npw_corner else R.dimen.npw_art_corner)

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
