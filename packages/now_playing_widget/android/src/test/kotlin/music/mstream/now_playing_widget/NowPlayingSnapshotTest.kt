package music.mstream.now_playing_widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pure-JVM tests for the snapshot's channel decoding, its persisted form, the
 * art cache key, the position fix and the mode cycle — the parts a launcher
 * re-render after process death depends on, and the part that keeps the
 * session token off disk.
 */
class NowPlayingSnapshotTest {
    private val artUrl = "https://nas.example.com:3000/album-art/abc.jpg?compress=l&token=SECRET"

    @Test
    fun `a channel snapshot round-trips through the store, minus the art url`() {
        val sent = NowPlayingSnapshot.fromChannel(
            mapOf(
                "hasTrack" to true, "title" to "Hear The Cry", "artist" to "Selfless",
                "album" to "Album", "artUrl" to artUrl, "playing" to true, "locale" to "de",
                // Dart ints arrive as Int or Long, doubles as Double.
                "durationMs" to 224000, "positionMs" to 12000L, "positionAtMs" to 1789950000000L,
                "speed" to 1.25, "shuffle" to true, "repeat" to "one",
            ),
        )
        assertEquals(artUrl, sent.artUrl)
        assertTrue(sent.artKey.isNotEmpty())
        assertEquals(224000L, sent.durationMs)
        assertEquals(12000L, sent.positionMs)
        assertEquals(1789950000000L, sent.positionAtMs)
        assertEquals(1.25f, sent.speed)
        assertTrue(sent.shuffle)
        assertEquals("one", sent.repeat)

        val stored = sent.toStore()
        assertFalse("the token must never be persisted", stored.values.any { it.contains("SECRET") })
        assertFalse(stored.containsKey(NowPlayingSnapshot.KEY_ART_URL))

        val back = NowPlayingSnapshot.fromStore(stored)
        assertEquals(sent.copy(artUrl = ""), back)
    }

    @Test
    fun `an empty or partial store reads as the empty state, never as the word null`() {
        val empty = NowPlayingSnapshot.fromStore(emptyMap<String, String>())
        assertFalse(empty.hasTrack)
        assertFalse(empty.playing)
        assertEquals("", empty.title)
        assertEquals("", empty.subtitle)
        assertEquals(0L, empty.durationMs)
        assertEquals(1f, empty.speed)
        assertEquals("none", empty.repeat)

        val partial = NowPlayingSnapshot.fromStore(mapOf("hasTrack" to "true", "title" to "T", "repeat" to "bogus"))
        assertTrue(partial.hasTrack)
        assertEquals("T", partial.title)
        assertEquals("", partial.artist)
        assertEquals("", partial.subtitle)
        assertEquals("none", partial.repeat)
    }

    @Test
    fun `the subtitle is the artist, else the album, else nothing`() {
        assertEquals("Selfless", NowPlayingSnapshot(artist = "Selfless", album = "A").subtitle)
        assertEquals("A", NowPlayingSnapshot(album = "A").subtitle)
        assertEquals("", NowPlayingSnapshot().subtitle)
    }

    @Test
    fun `a channel map with nulls and missing keys decodes safely`() {
        val s = NowPlayingSnapshot.fromChannel(mapOf("hasTrack" to true, "artist" to null, "durationMs" to null))
        assertTrue(s.hasTrack)
        assertEquals("", s.artist)
        assertEquals("", s.artKey)
        assertEquals(0L, s.durationMs)
        assertEquals(NowPlayingSnapshot(), NowPlayingSnapshot.fromChannel(null))
    }

    @Test
    fun `the position advances from its fix while playing, stands still paused, stops at the end`() {
        val fix = NowPlayingSnapshot(hasTrack = true, playing = true, durationMs = 200_000, positionMs = 10_000, positionAtMs = 1_000_000)
        assertEquals(10_000L, fix.positionNow(1_000_000))
        assertEquals(15_000L, fix.positionNow(1_005_000))
        assertEquals(20_000L, fix.copy(speed = 2f).positionNow(1_005_000))
        assertEquals(200_000L, fix.positionNow(9_000_000))
        assertEquals(10_000L, fix.copy(playing = false).positionNow(1_005_000))
        // No fix time (an old store): the position is what it says.
        assertEquals(10_000L, fix.copy(positionAtMs = 0).positionNow(1_005_000))
        // A clock that went backwards never yields a negative position.
        assertEquals(10_000L, fix.positionNow(900_000))
    }

    @Test
    fun `repeat cycles off, all, one, off — the player panel's order`() {
        assertEquals("all", NowPlayingSnapshot(repeat = "none").nextRepeat)
        assertEquals("one", NowPlayingSnapshot(repeat = "all").nextRepeat)
        assertEquals("none", NowPlayingSnapshot(repeat = "one").nextRepeat)
    }

    @Test
    fun `times format as the player panel shows them`() {
        assertEquals("0:00", NowPlayingSnapshot.formatTime(0))
        assertEquals("0:09", NowPlayingSnapshot.formatTime(9_400))
        assertEquals("3:44", NowPlayingSnapshot.formatTime(224_000))
        assertEquals("1:02:03", NowPlayingSnapshot.formatTime(3_723_000))
        assertEquals("0:00", NowPlayingSnapshot.formatTime(-5))
    }

    @Test
    fun `the art key ignores the token but not the size or the file`() {
        val rotated = "https://nas.example.com:3000/album-art/abc.jpg?compress=l&token=OTHER"
        assertEquals(NowPlayingSnapshot.keyFor(artUrl), NowPlayingSnapshot.keyFor(rotated))
        assertNotEquals(
            NowPlayingSnapshot.keyFor(artUrl),
            NowPlayingSnapshot.keyFor("https://nas.example.com:3000/album-art/abc.jpg?compress=s&token=SECRET"),
        )
        assertNotEquals(
            NowPlayingSnapshot.keyFor(artUrl),
            NowPlayingSnapshot.keyFor("https://nas.example.com:3000/album-art/xyz.jpg?compress=l&token=SECRET"),
        )
    }

    @Test
    fun `an ArtContentProvider wrapper is keyed on the remote url inside it`() {
        val wrapped = "content://mstream.music.plus.art/art?u=" +
            java.net.URLEncoder.encode(artUrl, "UTF-8")
        assertEquals(artUrl, NowPlayingSnapshot.unwrap(wrapped))
        assertEquals(NowPlayingSnapshot.keyFor(artUrl), NowPlayingSnapshot.keyFor(wrapped))
        assertEquals("file:///x/y.jpg", NowPlayingSnapshot.unwrap("file:///x/y.jpg"))
    }
}
