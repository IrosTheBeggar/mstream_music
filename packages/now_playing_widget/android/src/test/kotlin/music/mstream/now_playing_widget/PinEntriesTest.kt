package music.mstream.now_playing_widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Test

/** The picker entries a Settings pin request can name. */
class PinEntriesTest {
    @Test
    fun `each size maps to its own provider`() {
        assertSame(NowPlayingWidgetProviderMini::class.java, Renderer.entryFor("2x1").provider)
        assertSame(NowPlayingWidgetProviderTile::class.java, Renderer.entryFor("2x2").provider)
        assertSame(NowPlayingWidgetProvider::class.java, Renderer.entryFor("4x1").provider)
        assertSame(NowPlayingWidgetProviderCard::class.java, Renderer.entryFor("4x2").provider)
        assertSame(NowPlayingWidgetProviderLarge::class.java, Renderer.entryFor("4x3").provider)
    }

    @Test
    fun `an unknown or missing size is the 4x1, as before sizes existed`() {
        assertSame(NowPlayingWidgetProvider::class.java, Renderer.entryFor(null).provider)
        assertSame(NowPlayingWidgetProvider::class.java, Renderer.entryFor("9x9").provider)
    }

    @Test
    fun `the entries run smallest first, one per picker label`() {
        assertEquals(listOf("2x1", "2x2", "4x1", "4x2", "4x3"), Renderer.entries.map { it.size })
        assertEquals(Renderer.entries.size, Renderer.entries.map { it.label }.toSet().size)
    }
}
