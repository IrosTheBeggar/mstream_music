package music.mstream.now_playing_widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pure-JVM tests for the snapshot's channel decoding, its persisted form and
 * the art cache key — the parts a launcher re-render after process death
 * depends on, and the part that keeps the session token off disk.
 */
class NowPlayingSnapshotTest {
    private val artUrl = "https://nas.example.com:3000/album-art/abc.jpg?compress=l&token=SECRET"

    @Test
    fun `a channel snapshot round-trips through the store, minus the art url`() {
        val sent = NowPlayingSnapshot.fromChannel(
            mapOf(
                "hasTrack" to true, "title" to "Hear The Cry", "artist" to "Selfless",
                "album" to "Album", "artUrl" to artUrl, "playing" to true, "locale" to "de",
            ),
        )
        assertEquals(artUrl, sent.artUrl)
        assertTrue(sent.artKey.isNotEmpty())

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

        val partial = NowPlayingSnapshot.fromStore(mapOf("hasTrack" to "true", "title" to "T"))
        assertTrue(partial.hasTrack)
        assertEquals("T", partial.title)
        assertEquals("", partial.artist)
        assertEquals("", partial.subtitle)
    }

    @Test
    fun `the subtitle is the artist, else the album, else nothing`() {
        assertEquals("Selfless", NowPlayingSnapshot(artist = "Selfless", album = "A").subtitle)
        assertEquals("A", NowPlayingSnapshot(album = "A").subtitle)
        assertEquals("", NowPlayingSnapshot().subtitle)
    }

    @Test
    fun `a channel map with nulls and missing keys decodes safely`() {
        val s = NowPlayingSnapshot.fromChannel(mapOf("hasTrack" to true, "artist" to null))
        assertTrue(s.hasTrack)
        assertEquals("", s.artist)
        assertEquals("", s.artKey)
        assertEquals(NowPlayingSnapshot(), NowPlayingSnapshot.fromChannel(null))
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
