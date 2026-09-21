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
         * on a Galaxy S25 at about 140 and 68, AOSP's own minimums are 110
         * and 40 — so absolute dp thresholds cannot tell a 2x2 from a 4x3
         * across phones (a Galaxy's three rows are shorter than a Pixel's
         * two). The shape can: the aspect ratio separates one, two and three
         * or more rows for a given width, and one width cut-off separates two
         * cells from four on every launcher measured.
         */
        const val NARROW_BELOW_DP = 220
        /** Wider than this many times its height: one row. */
        const val ONE_ROW_FROM_RATIO = 2.5f
        /** Wider than this: two rows (below it, three or more). */
        const val TWO_ROWS_FROM_RATIO = 1.45f
        /** The large layout's own floor; a squarer frame that is shorter gets the card. */
        const val LARGE_MIN_HEIGHT_DP = 165
        /** A frame this tall holds the card even when it is very wide: a 4x2 or 4x3 in landscape. */
        const val CARD_FROM_HEIGHT_DP = 130

        fun pick(widthDp: Int, heightDp: Int): Layout {
            if (widthDp <= 0 || heightDp <= 0) return ROW
            val ratio = widthDp.toFloat() / heightDp
            val narrow = widthDp < NARROW_BELOW_DP
            return when {
                narrow && ratio >= TWO_ROWS_FROM_RATIO -> MINI
                narrow -> TILE
                ratio >= ONE_ROW_FROM_RATIO && heightDp < CARD_FROM_HEIGHT_DP -> ROW
                ratio >= TWO_ROWS_FROM_RATIO -> CARD
                heightDp < LARGE_MIN_HEIGHT_DP -> CARD
                else -> LARGE
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
