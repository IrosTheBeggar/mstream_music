package music.mstream.now_playing_widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Which layout a widget size gets, on the launchers measured: a Pixel-style
 * grid (emulator: 4 cells ≈ 360 dp wide, a row ≈ 104 dp), One UI on a Galaxy
 * S25 (4 cells = 312 dp, a row 72, two rows 168, three 264) and AOSP's
 * minimum sizes (70n − 30 dp).
 */
class LayoutTest {
    @Test
    fun `a Pixel-style grid`() {
        assertEquals(Layout.ROW, Layout.pick(360, 104))
        assertEquals(Layout.MINI, Layout.pick(172, 104))
        assertEquals(Layout.TILE, Layout.pick(172, 224))
        assertEquals(Layout.TILE, Layout.pick(172, 344))
        // Two rows are 224 dp here: tall enough for the large layout.
        assertEquals(Layout.LARGE, Layout.pick(360, 224))
        assertEquals(Layout.LARGE, Layout.pick(360, 344))
        assertEquals(Layout.LARGE, Layout.pick(360, 464))
        // Three cells wide reads as wide; a 3x1 is still a row.
        assertEquals(Layout.ROW, Layout.pick(270, 104))
    }

    @Test
    fun `One UI on a Galaxy S25`() {
        assertEquals(Layout.ROW, Layout.pick(312, 72))
        assertEquals(Layout.MINI, Layout.pick(152, 72))
        assertEquals(Layout.TILE, Layout.pick(152, 168))
        // The 3x2 and the 4x2 both draw the large layout — the request that
        // made the height, not the width, decide.
        assertEquals(Layout.LARGE, Layout.pick(232, 168))
        assertEquals(Layout.LARGE, Layout.pick(312, 168))
        assertEquals(Layout.LARGE, Layout.pick(312, 264))
    }

    @Test
    fun `AOSP minimum sizes, the cells older launchers report`() {
        assertEquals(Layout.ROW, Layout.pick(250, 40))
        assertEquals(Layout.MINI, Layout.pick(110, 40))
        assertEquals(Layout.TILE, Layout.pick(110, 110))
        // 110 dp is too short for the large layout: the card.
        assertEquals(Layout.CARD, Layout.pick(250, 110))
        assertEquals(Layout.LARGE, Layout.pick(250, 180))
    }

    @Test
    fun `landscape frames, short but wide, get the card from two rows up`() {
        assertEquals(Layout.ROW, Layout.pick(624, 62))
        assertEquals(Layout.CARD, Layout.pick(624, 135))
        assertEquals(Layout.LARGE, Layout.pick(624, 208))
        assertEquals(Layout.ROW, Layout.pick(306, 62))
        assertEquals(Layout.CARD, Layout.pick(306, 135))
    }

    @Test
    fun `a wide frame too short for the large layout gets the card, and no size is unanswered`() {
        assertEquals(Layout.CARD, Layout.pick(230, 160))
        assertEquals(Layout.ROW, Layout.pick(0, 0))
    }

    @Test
    fun `only the large layout has the album line, progress and the mode pair`() {
        for (l in Layout.entries) {
            assertEquals(l == Layout.LARGE, l.hasProgress)
            assertEquals(l == Layout.LARGE, l.hasModes)
            assertEquals(l == Layout.LARGE, l.hasAlbumLine)
        }
        assertFalse(Layout.MINI.hasNext)
        assertTrue(Layout.TILE.hasNext)
        assertFalse(Layout.TILE.hasPrevious)
        assertTrue(Layout.TILE.artFillsCard)
    }

    @Test
    fun `layouts resolve by name for the debug hook`() {
        assertEquals(Layout.LARGE, Layout.byName("large"))
        assertEquals(Layout.TILE, Layout.byName("Tile"))
        assertNull(Layout.byName("auto"))
        assertNull(Layout.byName(null))
    }
}
