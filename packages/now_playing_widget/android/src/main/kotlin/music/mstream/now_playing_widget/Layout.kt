package music.mstream.now_playing_widget

import android.appwidget.AppWidgetManager
import android.os.Build
import android.os.Bundle
import android.util.SizeF

/**
 * One resizable widget, five layouts. Which one a placed widget gets follows
 * its shape in launcher cells: two cells wide is the narrow pair (a 2x1 mini,
 * a 2x2 tile the cover fills), wider is the row (one cell high), the card
 * (two) or the large one (three and up, with the album line, progress and the
 * shuffle / repeat pair) — see [pick] for how cells are read off a size. On
 * Android 12+ the launcher is handed one RemoteViews per size it reports and
 * picks the best fit itself (rotation included); below that the portrait
 * minimum decides and a resize re-renders.
 */
enum class Layout(
    val res: Int,
    val hasPrevious: Boolean,
    val hasNext: Boolean,
    val hasModes: Boolean,
    val hasProgress: Boolean,
    val hasAlbumLine: Boolean,
    /** The cover fills the card, so it is rounded at the card's radius. */
    val artFillsCard: Boolean,
) {
    MINI(R.layout.now_playing_widget_mini, false, false, false, false, false, false),
    TILE(R.layout.now_playing_widget_tile, false, true, false, false, false, true),
    ROW(R.layout.now_playing_widget, true, true, false, false, false, false),
    CARD(R.layout.now_playing_widget_tall, true, true, false, false, false, false),
    LARGE(R.layout.now_playing_widget_large, true, true, true, true, true, false);

    companion object {
        /**
         * Launchers disagree on what a cell measures — a Pixel-style grid
         * draws a 2-cell width at about 170 dp and a row at 104 dp, One UI
         * on a Galaxy S25 at 152 and 72 (two rows: 168), AOSP's own minimums
         * are 110 and 40 — so a layout cannot be read off a cell count. The
         * frame itself decides: two cells wide is the narrow pair, told apart
         * by shape; a wide frame gets the large layout as soon as it is tall
         * enough to hold it (a Galaxy's two rows already are, a Pixel's two
         * rows too), the card between one row and that, and the row when it
         * is a strip.
         */
        const val NARROW_BELOW_DP = 220
        /** Narrow and wider than this many times its height: the mini, else the tile. */
        const val MINI_FROM_RATIO = 1.45f
        /** A wide frame at least this tall holds the large layout. */
        const val LARGE_FROM_HEIGHT_DP = 165
        /** A strip: much wider than tall and shorter than this gets the row. */
        const val ROW_FROM_RATIO = 2.5f
        const val ROW_BELOW_HEIGHT_DP = 130

        fun pick(widthDp: Int, heightDp: Int): Layout {
            if (widthDp <= 0 || heightDp <= 0) return ROW
            val ratio = widthDp.toFloat() / heightDp
            val narrow = widthDp < NARROW_BELOW_DP
            return when {
                narrow && ratio >= MINI_FROM_RATIO -> MINI
                narrow -> TILE
                ratio >= ROW_FROM_RATIO && heightDp < ROW_BELOW_HEIGHT_DP -> ROW
                heightDp >= LARGE_FROM_HEIGHT_DP -> LARGE
                else -> CARD
            }
        }

        /** The layout for a widget's options (portrait minimum); the row when the launcher gave none. */
        fun forOptions(options: Bundle?): Layout {
            val w = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0) ?: 0
            val h = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0) ?: 0
            if (w <= 0 && h <= 0) return ROW
            return pick(w, h)
        }

        /** Android 12+: every size the launcher may show this widget at (portrait and landscape). */
        @Suppress("DEPRECATION")
        fun sizes(options: Bundle?): List<SizeF> {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || options == null) return emptyList()
            return options.getParcelableArrayList<SizeF>(AppWidgetManager.OPTION_APPWIDGET_SIZES) ?: emptyList()
        }

        /** The layouts a widget can be shown at, from its sizes, else its portrait minimum. */
        fun candidates(options: Bundle?): Set<Layout> {
            val sizes = sizes(options)
            if (sizes.isEmpty()) return setOf(forOptions(options))
            return sizes.map { pick(it.width.toInt(), it.height.toInt()) }.toSet()
        }

        fun byName(name: String?): Layout? = entries.firstOrNull { it.name.equals(name, ignoreCase = true) }
    }
}
