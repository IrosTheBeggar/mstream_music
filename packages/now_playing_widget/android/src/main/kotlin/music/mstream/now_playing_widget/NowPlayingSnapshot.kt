package music.mstream.now_playing_widget

import java.net.URLDecoder
import java.security.MessageDigest

/**
 * What the widget draws, as Dart last published it.
 *
 * Persisted as flat string pairs (the shape SharedPreferences.getAll() hands
 * back) so a launcher re-render after the process died — a reboot, a launcher
 * restart, a resize — needs no Dart. The art URL itself is never persisted:
 * it carries the server's session token, so only its cache key ([artKey],
 * the token-blind hash ArtLoader files the bytes under) is written.
 *
 * The position is a fix, not a clock: [positionMs] was true at [positionAtMs]
 * (epoch), and [positionNow] extrapolates from there at [speed] while playing,
 * so the large layout's progress advances between publishes without Dart.
 */
data class NowPlayingSnapshot(
    val hasTrack: Boolean = false,
    val title: String = "",
    val artist: String = "",
    val album: String = "",
    /** Transient: set on a snapshot that came over the channel, empty when read back. */
    val artUrl: String = "",
    val artKey: String = "",
    val playing: Boolean = false,
    /** BCP-47 tag of the app's language override, or empty to follow the system. */
    val locale: String = "",
    val durationMs: Long = 0,
    val positionMs: Long = 0,
    val positionAtMs: Long = 0,
    val speed: Float = 1f,
    val shuffle: Boolean = false,
    /** "none", "all" or "one". */
    val repeat: String = REPEAT_NONE,
) {
    /** The second line: artist, else album, else nothing (never the word "null"). */
    val subtitle: String get() = artist.ifEmpty { album }

    /** Where playback is at [nowMs]: the fix, advanced while playing, never past the end. */
    fun positionNow(nowMs: Long): Long {
        val raw = if (playing && positionAtMs > 0 && nowMs > positionAtMs) {
            positionMs + ((nowMs - positionAtMs) * speed).toLong()
        } else {
            positionMs
        }
        val cap = if (durationMs > 0) durationMs else Long.MAX_VALUE
        return raw.coerceIn(0, cap)
    }

    /** The repeat button cycles the way the player panel does: off → all → one → off. */
    val nextRepeat: String
        get() = when (repeat) {
            REPEAT_NONE -> REPEAT_ALL
            REPEAT_ALL -> REPEAT_ONE
            else -> REPEAT_NONE
        }

    fun toStore(): Map<String, String> = mapOf(
        KEY_HAS_TRACK to hasTrack.toString(),
        KEY_TITLE to title,
        KEY_ARTIST to artist,
        KEY_ALBUM to album,
        KEY_ART_KEY to artKey,
        KEY_PLAYING to playing.toString(),
        KEY_LOCALE to locale,
        KEY_DURATION_MS to durationMs.toString(),
        KEY_POSITION_MS to positionMs.toString(),
        KEY_POSITION_AT_MS to positionAtMs.toString(),
        KEY_SPEED to speed.toString(),
        KEY_SHUFFLE to shuffle.toString(),
        KEY_REPEAT to repeat,
    )

    companion object {
        const val KEY_HAS_TRACK = "hasTrack"
        const val KEY_TITLE = "title"
        const val KEY_ARTIST = "artist"
        const val KEY_ALBUM = "album"
        const val KEY_ART_URL = "artUrl"
        const val KEY_ART_KEY = "artKey"
        const val KEY_PLAYING = "playing"
        const val KEY_LOCALE = "locale"
        const val KEY_DURATION_MS = "durationMs"
        const val KEY_POSITION_MS = "positionMs"
        const val KEY_POSITION_AT_MS = "positionAtMs"
        const val KEY_SPEED = "speed"
        const val KEY_SHUFFLE = "shuffle"
        const val KEY_REPEAT = "repeat"
        const val REPEAT_NONE = "none"
        const val REPEAT_ALL = "all"
        const val REPEAT_ONE = "one"

        /** A snapshot as the Dart side sends it (`NowPlayingWidget.publish`). */
        fun fromChannel(args: Map<*, *>?): NowPlayingSnapshot {
            val a = args ?: emptyMap<Any, Any>()
            val artUrl = a.str(KEY_ART_URL)
            return NowPlayingSnapshot(
                hasTrack = a.bool(KEY_HAS_TRACK),
                title = a.str(KEY_TITLE),
                artist = a.str(KEY_ARTIST),
                album = a.str(KEY_ALBUM),
                artUrl = artUrl,
                artKey = if (artUrl.isEmpty()) "" else keyFor(artUrl),
                playing = a.bool(KEY_PLAYING),
                locale = a.str(KEY_LOCALE),
                durationMs = a.long(KEY_DURATION_MS),
                positionMs = a.long(KEY_POSITION_MS),
                positionAtMs = a.long(KEY_POSITION_AT_MS),
                speed = a.float(KEY_SPEED, 1f),
                shuffle = a.bool(KEY_SHUFFLE),
                repeat = repeatOf(a.str(KEY_REPEAT)),
            )
        }

        /** A snapshot read back from [toStore] output (or an empty / partial store). */
        fun fromStore(map: Map<String, *>): NowPlayingSnapshot = NowPlayingSnapshot(
            hasTrack = map.bool(KEY_HAS_TRACK),
            title = map.str(KEY_TITLE),
            artist = map.str(KEY_ARTIST),
            album = map.str(KEY_ALBUM),
            artKey = map.str(KEY_ART_KEY),
            playing = map.bool(KEY_PLAYING),
            locale = map.str(KEY_LOCALE),
            durationMs = map.long(KEY_DURATION_MS),
            positionMs = map.long(KEY_POSITION_MS),
            positionAtMs = map.long(KEY_POSITION_AT_MS),
            speed = map.float(KEY_SPEED, 1f),
            shuffle = map.bool(KEY_SHUFFLE),
            repeat = repeatOf(map.str(KEY_REPEAT)),
        )

        private fun repeatOf(s: String): String =
            if (s == REPEAT_ALL || s == REPEAT_ONE) s else REPEAT_NONE

        /**
         * The art cache key: the remote URL without its query, plus the
         * `compress` size — the same stable part ArtContentProvider keys its
         * own cache on — so a rotated token never re-fetches the same cover.
         * A `content://…/art?u=<remote>` wrapper (Android Auto's browse rows)
         * is keyed on the remote URL inside it.
         */
        fun keyFor(url: String): String {
            val remote = unwrap(url)
            val q = remote.indexOf('?')
            val base = if (q < 0) remote else remote.substring(0, q)
            val compress = if (q < 0) "" else remote.substring(q + 1)
                .split('&').firstOrNull { it.startsWith("compress=") } ?: ""
            return md5("$base?$compress")
        }

        /** The remote URL inside an ArtContentProvider wrapper, else [url] itself. */
        fun unwrap(url: String): String {
            if (!url.startsWith("content://")) return url
            val q = url.indexOf('?')
            if (q < 0) return url
            val inner = url.substring(q + 1).split('&')
                .firstOrNull { it.startsWith("u=") }?.substring(2) ?: return url
            return try {
                URLDecoder.decode(inner, "UTF-8")
            } catch (e: Exception) {
                url
            }
        }

        /** m:ss, or h:mm:ss from an hour up. */
        fun formatTime(ms: Long): String {
            val total = (ms / 1000).coerceAtLeast(0)
            val h = total / 3600
            val m = (total % 3600) / 60
            val s = total % 60
            return if (h > 0) "%d:%02d:%02d".format(h, m, s) else "%d:%02d".format(m, s)
        }

        private fun md5(s: String): String =
            MessageDigest.getInstance("MD5").digest(s.toByteArray())
                .joinToString("") { "%02x".format(it) }

        private fun Map<*, *>.str(key: String): String = (this[key] as? String) ?: ""

        private fun Map<*, *>.bool(key: String): Boolean = when (val v = this[key]) {
            is Boolean -> v
            is String -> v == "true"
            else -> false
        }

        private fun Map<*, *>.long(key: String): Long = when (val v = this[key]) {
            is Number -> v.toLong()
            is String -> v.toLongOrNull() ?: 0L
            else -> 0L
        }

        private fun Map<*, *>.float(key: String, default: Float): Float = when (val v = this[key]) {
            is Number -> v.toFloat()
            is String -> v.toFloatOrNull() ?: default
            else -> default
        }
    }
}
