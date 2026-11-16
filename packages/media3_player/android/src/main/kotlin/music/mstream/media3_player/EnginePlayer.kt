package music.mstream.media3_player

import android.content.Context
import android.media.audiofx.AudioEffect
import android.media.audiofx.Equalizer
import android.media.audiofx.LoudnessEnhancer
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.OptIn
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaLibraryInfo
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.common.Timeline
import androidx.media3.common.util.UnstableApi
import androidx.media3.common.util.Util
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlaybackException
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.NoSampleRenderer
import androidx.media3.exoplayer.RenderersFactory
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import androidx.media3.exoplayer.source.ShuffleOrder
import androidx.media3.extractor.DefaultExtractorsFactory
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Random
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * One ExoPlayer behind just_audio's per-player protocol.
 *
 * The client is just_audio's own Dart player, and the app above it is tuned
 * to that player's behaviour down to its quirks, so this class answers each
 * call the way just_audio's AudioPlayer.java (0.10.6) does: the same
 * processing states at the same moments, the same position bookkeeping
 * (updatePosition / updateTime pairs the Dart side extrapolates from), the
 * same "playlist grew after the end" continuation, the same error shape
 * (code = ExoPlaybackException.type, message = its message). Where a line
 * here looks arbitrary, that file is why.
 *
 * It parts from that file in four places, each on purpose:
 *  - a load that replaces one still in flight answers the old call with the
 *    abort code and nothing else. just_audio also publishes the abort as a
 *    playback error, which the app's recovery then reads as a failed track.
 *  - a load at an index past the end is refused before ExoPlayer sees it.
 *    ExoPlayer throws from the middle of setMediaSources there, with its
 *    playlist already swapped and an operation it will wait on forever.
 *  - a seek to an item the playlist does not have is answered at once.
 *    ExoPlayer drops such a seek without a state change, so there would be
 *    nothing to answer it on.
 *  - an audio effect remembers what it was last told (on/off, band levels),
 *    so one rebuilt for a new session id comes back as it was.
 *
 * And one place where it must NOT part from it, though it looks like an
 * oversight there: a seek is answered when the player next becomes ready,
 * and only then. Not when it errors, and not when it is released. The Dart
 * side resumes its own seek() on that answer, and with playback still wanted
 * and the platform just torn down by the error, what it does next is start a
 * new native player on its own — under the app's recovery, which is loading
 * one too. The two interrupt each other inside just_audio's activation
 * window and the player is wedged until a stop (emulator, 2026-11-16: server
 * down mid-seek, three "Loading interrupted" retries, then silence). Left
 * unanswered, that seek() simply never returns, which is what the app has
 * always had.
 *
 * Not served (the app plays plain file and http(s) URLs): DASH, HLS, silence,
 * clipping, looping and nested playlists; ICY metadata; a custom load
 * control or offload preferences. Such a source fails its load with a
 * message naming the type.
 *
 * Everything runs on the main thread: Flutter delivers calls there and the
 * ExoPlayer is built on it.
 */
@OptIn(UnstableApi::class)
internal class EnginePlayer(
    private val context: Context,
    messenger: BinaryMessenger,
    private val id: String,
    private val rawAudioEffects: List<Map<*, *>>,
    useLazyPreparation: Boolean,
) : MethodChannel.MethodCallHandler, Player.Listener {

    // The ordinals are the protocol's ProcessingStateMessage values.
    private enum class State { IDLE, LOADING, BUFFERING, READY, COMPLETED }

    private val handler = Handler(Looper.getMainLooper())
    private val methods =
        MethodChannel(messenger, "${Media3PlayerPlugin.CHANNEL}/methods/$id")
    private val events = EventStream(messenger, "${Media3PlayerPlugin.CHANNEL}/events/$id")
    private val random = Random()

    private var state = State.IDLE
    private var updatePositionMs = 0L
    private var updateTimeMs = 0L
    private var bufferedPositionMs = 0L
    private var seekPosMs: Long? = null
    private var prepareReply: Reply? = null
    private var playReply: Reply? = null
    private var seekReply: Reply? = null
    private var pendingAttributes: AudioAttributes? = null
    private var lastPlaylistLength = 0
    private var pendingEvent: Map<String, Any?>? = null
    private var sessionId: Int? = null
    private var errorCode: Int? = null
    private var errorMessage: String? = null
    private var currentIndex: Int? = null
    private var released = false

    private val effects = HashMap<String, AudioEffect>()
    private val effectEnabled = HashMap<String, Boolean>()
    private val equalizerLevels = HashMap<Short, Short>()
    private var loudnessTargetMb: Int? = null

    private val extractors = buildExtractors(null)
    private val dataSources: DataSource.Factory by lazy { buildDataSources(null) }

    private val player: ExoPlayer

    // Polls the buffered position while there is something buffering or
    // playing, and publishes it when it moved: nothing else tells the Dart
    // side how far ahead the stream has been fetched.
    private val bufferWatch = object : Runnable {
        override fun run() {
            if (released) return
            if (player.bufferedPosition != bufferedPositionMs) broadcastNow()
            when (player.playbackState) {
                Player.STATE_BUFFERING -> handler.postDelayed(this, 200)
                Player.STATE_READY ->
                    handler.postDelayed(this, if (player.playWhenReady) 500 else 1000)
                else -> {}
            }
        }
    }

    init {
        val renderers = RenderersFactory { eventHandler, video, audio, text, metadata ->
            DefaultRenderersFactory(context)
                .createRenderers(eventHandler, video, audio, text, metadata) +
                PositionObserver()
        }
        player = ExoPlayer.Builder(context, renderers)
            .setUseLazyPreparation(useLazyPreparation)
            .build()
        setSessionId(player.audioSessionId)
        player.addListener(this)
        methods.setMethodCallHandler(this)
        Log.i(TAG, "player $id on Media3 ${MediaLibraryInfo.VERSION}")
    }

    // ── Calls ──────────────────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val reply = Reply(result)
        if (released) {
            reply.ok()
            return
        }
        try {
            when (call.method) {
                "load" -> load(call, reply)
                "play" -> play(reply)
                "pause" -> {
                    pause()
                    reply.ok()
                }
                "setVolume" -> {
                    player.volume = call.double("volume").toFloat()
                    reply.ok()
                }
                "setSpeed" -> {
                    setSpeed(call.double("speed").toFloat())
                    reply.ok()
                }
                "setPitch" -> {
                    setPitch(call.double("pitch").toFloat())
                    reply.ok()
                }
                "setSkipSilence" -> {
                    player.skipSilenceEnabled = call.argument<Boolean>("enabled") == true
                    reply.ok()
                }
                "setLoopMode" -> {
                    // 0 off, 1 one, 2 all on both sides of the channel.
                    player.repeatMode = call.argument<Int>("loopMode") ?: Player.REPEAT_MODE_OFF
                    reply.ok()
                }
                "setShuffleMode" -> {
                    player.shuffleModeEnabled = call.argument<Int>("shuffleMode") == 1
                    reply.ok()
                }
                "setShuffleOrder" -> {
                    val source = call.argument<Map<*, *>>("audioSource")
                    if (source != null && source["id"] == "") applyShuffleOrder(source["shuffleOrder"])
                    reply.ok()
                }
                // iOS/macOS options; nothing to do here.
                "setAutomaticallyWaitsToMinimizeStalling",
                "setCanUseNetworkResourcesForLiveStreamingWhilePaused",
                "setPreferredPeakBitRate",
                "setAllowsExternalPlayback" -> reply.ok()
                "seek" -> seek(
                    call.long("position")?.div(1000) ?: C.TIME_UNSET,
                    call.argument<Int>("index"),
                    reply,
                )
                "concatenatingInsertAll" -> {
                    requireRootPlaylist(call)
                    player.addMediaSources(
                        call.argument<Int>("index") ?: player.mediaItemCount,
                        decodeSources(call.argument<Any>("children")),
                    )
                    applyShuffleOrder(call.argument<Any>("shuffleOrder"))
                    reply.ok()
                }
                "concatenatingRemoveRange" -> {
                    requireRootPlaylist(call)
                    player.removeMediaItems(
                        call.argument<Int>("startIndex") ?: 0,
                        call.argument<Int>("endIndex") ?: 0,
                    )
                    applyShuffleOrder(call.argument<Any>("shuffleOrder"))
                    reply.ok()
                }
                "concatenatingMove" -> {
                    requireRootPlaylist(call)
                    player.moveMediaItem(
                        call.argument<Int>("currentIndex") ?: 0,
                        call.argument<Int>("newIndex") ?: 0,
                    )
                    applyShuffleOrder(call.argument<Any>("shuffleOrder"))
                    reply.ok()
                }
                "setAndroidAudioAttributes" -> {
                    setAudioAttributes(
                        call.argument<Int>("contentType") ?: C.AUDIO_CONTENT_TYPE_MUSIC,
                        call.argument<Int>("flags") ?: 0,
                        call.argument<Int>("usage") ?: C.USAGE_MEDIA,
                    )
                    reply.ok()
                }
                "audioEffectSetEnabled" -> {
                    val type = call.argument<String>("type") ?: ""
                    val enabled = call.argument<Boolean>("enabled") == true
                    effect(type).enabled = enabled
                    effectEnabled[type] = enabled
                    reply.ok()
                }
                "androidLoudnessEnhancerSetTargetGain" -> {
                    // dB on the channel, millibels on the effect.
                    val mb = (call.double("targetGain") * 100.0).roundToInt()
                    (effect(LOUDNESS) as LoudnessEnhancer).setTargetGain(mb)
                    loudnessTargetMb = mb
                    reply.ok()
                }
                "androidEqualizerGetParameters" -> reply.ok(equalizerParameters())
                "androidEqualizerBandSetGain" -> {
                    val band = (call.argument<Int>("bandIndex") ?: 0).toShort()
                    val level = (call.double("gain") * 100.0).roundToInt().toShort()
                    (effect(EQUALIZER) as Equalizer).setBandLevel(band, level)
                    equalizerLevels[band] = level
                    reply.ok()
                }
                "dispose" -> {
                    dispose()
                    reply.ok()
                }
                else -> result.notImplemented()
            }
        } catch (e: IllegalStateException) {
            Log.e(TAG, "${call.method} failed", e)
            reply.fail("Illegal state: ${e.message}", e.toString())
        } catch (e: Exception) {
            Log.e(TAG, "${call.method} failed", e)
            reply.fail("Error: $e", e.toString())
        } finally {
            broadcastPending()
        }
    }

    private fun load(call: MethodCall, reply: Reply) {
        val source = call.argument<Map<*, *>>("audioSource")
            ?: throw IllegalArgumentException("load: no audioSource")
        val sources = decodeSources(source["children"])
        val order = decodeShuffleOrder(source["shuffleOrder"], sources.size)
        val startMs = call.long("initialPosition")?.div(1000) ?: C.TIME_UNSET
        val startIndex = call.argument<Int>("initialIndex")

        currentIndex = startIndex ?: 0
        when (state) {
            State.IDLE -> {}
            State.LOADING -> {
                abortLoad()
                player.stop()
            }
            else -> player.stop()
        }
        if (sources.isNotEmpty() && (startIndex ?: 0) !in sources.indices) {
            // Fail it as a load that never started: stopped, empty, idle. The
            // Dart side has already taken the new list as its own, so keeping
            // the old one loaded here would leave the two disagreeing. The
            // state goes out before the answer, as it does for any failed
            // load (onPlayerError): the Dart side tears the platform down on
            // the one and reports the failure on the other, in that order.
            player.clearMediaItems()
            state = State.IDLE
            updatePosition()
            broadcastNow()
            val e = IllegalArgumentException(
                "load: index $startIndex is outside a list of ${sources.size}")
            Log.e(TAG, "load refused", e)
            reply.fail("Error: $e", e.toString())
            return
        }
        prepareReply = reply
        updatePosition()
        state = State.LOADING
        clearError()
        enqueueEvent()
        player.setMediaSources(sources, startIndex ?: 0, startMs)
        if (order != null) player.setShuffleOrder(order)
        player.prepare()
    }

    private fun play(reply: Reply) {
        if (player.playWhenReady) {
            reply.ok()
            return
        }
        // The call stays open while playback runs: just_audio's play() future
        // is this reply, and it completes on pause, on the end, or on release.
        playReply?.ok()
        playReply = reply
        player.playWhenReady = true
        updatePosition()
        if (state == State.COMPLETED) finishPlay()
    }

    private fun pause() {
        if (!player.playWhenReady) return
        player.playWhenReady = false
        updatePosition()
        enqueueEvent()
        finishPlay()
    }

    private fun setSpeed(speed: Float) {
        val params = player.playbackParameters
        if (params.speed == speed) return
        player.playbackParameters = PlaybackParameters(speed, params.pitch)
        if (player.playWhenReady) updatePosition()
        enqueueEvent()
    }

    private fun setPitch(pitch: Float) {
        val params = player.playbackParameters
        if (params.pitch == pitch) return
        player.playbackParameters = PlaybackParameters(params.speed, pitch)
        enqueueEvent()
    }

    private fun seek(positionMs: Long, index: Int?, reply: Reply) {
        if (state == State.IDLE || state == State.LOADING) {
            reply.ok()
            return
        }
        val target = index ?: player.currentMediaItemIndex
        if (player.mediaItemCount > 0 && target >= player.mediaItemCount) {
            // ExoPlayer drops a seek to an item it does not have without a
            // state change, so there would be nothing to answer this on.
            reply.ok()
            return
        }
        // A newer seek answers the one before it.
        finishSeek()
        seekPosMs = positionMs
        seekReply = reply
        try {
            player.seekTo(target, positionMs)
        } catch (e: RuntimeException) {
            seekReply = null
            seekPosMs = null
            throw e
        }
    }

    private fun setAudioAttributes(contentType: Int, flags: Int, usage: Int) {
        val attributes = AudioAttributes.Builder()
            .setContentType(contentType)
            .setFlags(flags)
            .setUsage(usage)
            .build()
        // Never focus: the Dart side asks for it through audio_session and
        // pauses or resumes this player itself. And never mid-load, where a
        // change of attributes makes ExoPlayer glitch.
        if (state == State.LOADING) {
            pendingAttributes = attributes
        } else {
            player.setAudioAttributes(attributes, false)
        }
    }

    // ── Player events ──────────────────────────────────────────────────────

    override fun onAudioSessionIdChanged(audioSessionId: Int) {
        if (released) return
        setSessionId(audioSessionId)
        broadcastPending()
    }

    override fun onPositionDiscontinuity(
        oldPosition: Player.PositionInfo,
        newPosition: Player.PositionInfo,
        reason: Int,
    ) {
        if (released) return
        updatePosition()
        when (reason) {
            Player.DISCONTINUITY_REASON_AUTO_TRANSITION,
            Player.DISCONTINUITY_REASON_SEEK -> updateCurrentIndex()
        }
        broadcastNow()
    }

    override fun onTimelineChanged(timeline: Timeline, reason: Int) {
        if (released) return
        if (updateCurrentIndex()) broadcastNow()
        if (player.playbackState == Player.STATE_ENDED) {
            // The playlist changed under a finished player. Playing: carry
            // on into what was added (an Auto DJ pick landing after the last
            // track ended). Paused: back to the top of the current item, so
            // the next play has something to play.
            try {
                if (player.playWhenReady) {
                    if (lastPlaylistLength == 0 && player.mediaItemCount > 0) {
                        player.seekTo(0, 0L)
                    } else if (player.hasNextMediaItem()) {
                        player.seekToNextMediaItem()
                    }
                } else if (player.currentMediaItemIndex < player.mediaItemCount) {
                    player.seekTo(player.currentMediaItemIndex, 0L)
                }
            } catch (e: Exception) {
                Log.w(TAG, "could not continue after the playlist changed", e)
            }
        }
        lastPlaylistLength = player.mediaItemCount
    }

    override fun onPlaybackStateChanged(playbackState: Int) {
        if (released) return
        when (playbackState) {
            Player.STATE_READY -> {
                if (player.playWhenReady) updatePosition()
                state = State.READY
                clearError()
                broadcastNow()
                finishPrepare()
                finishSeek()
            }
            Player.STATE_BUFFERING -> {
                updatePositionIfChanged()
                if (state != State.BUFFERING && state != State.LOADING) {
                    state = State.BUFFERING
                    clearError()
                    broadcastNow()
                }
                handler.removeCallbacks(bufferWatch)
                handler.post(bufferWatch)
            }
            Player.STATE_ENDED -> {
                if (state != State.COMPLETED) {
                    updatePosition()
                    state = State.COMPLETED
                    clearError()
                    broadcastNow()
                }
                finishPrepare()
                finishPlay()
            }
            // STATE_IDLE: reached through stop() inside a load, which sets
            // the state itself, or through an error, which onPlayerError
            // has already published.
            else -> {}
        }
    }

    override fun onPlayerError(error: PlaybackException) {
        if (released) return
        // The detail goes to logcat only. What the Dart side gets is the
        // type and ExoPlayer's own one-line message ("Source error"), which
        // is what the app's retry-or-skip heuristics were written against.
        val code = if (error is ExoPlaybackException) {
            val cause = when (error.type) {
                ExoPlaybackException.TYPE_SOURCE -> error.sourceException
                ExoPlaybackException.TYPE_RENDERER -> error.rendererException
                ExoPlaybackException.TYPE_UNEXPECTED -> error.unexpectedException
                else -> error.cause
            }
            Log.e(TAG, "playback error type=${error.type} ${error.errorCodeName}: " +
                "${cause?.javaClass?.simpleName}: ${cause?.message}")
            error.type
        } else {
            Log.e(TAG, "playback error ${error.errorCodeName}: ${error.message}")
            error.errorCode
        }
        val message = error.message
        events.error(code.toString(), message, hashMapOf("index" to currentIndex))
        errorCode = code
        errorMessage = message
        state = State.IDLE
        broadcastNow()
        prepareReply?.fail(code.toString(), message, hashMapOf("index" to currentIndex))
        prepareReply = null
        // A pending seek stays unanswered: see the class comment.
    }

    // Enabled for every track selection (a renderer with no track type
    // always is), so render() runs on each pass of the playback loop with
    // the position the renderers are at. When that position has sat still
    // and then moves, playback has just started or resumed after a stall
    // the player state never showed, and the pair the Dart side extrapolates
    // from is stale by however long the stall lasted: refresh it.
    private inner class PositionObserver : NoSampleRenderer() {
        private var lastPositionUs = 0L
        private var stillFor = 0

        override fun render(positionUs: Long, elapsedRealtimeUs: Long) {
            if (positionUs == lastPositionUs) {
                stillFor++
            } else {
                if (stillFor >= 3) {
                    handler.post {
                        if (updatePositionIfChanged()) broadcastNow()
                    }
                }
                stillFor = 0
            }
            lastPositionUs = positionUs
        }

        override fun getName(): String = "PositionObserver"
    }

    // ── Position and events ────────────────────────────────────────────────

    private fun currentPositionMs(): Long {
        val seeking = seekPosMs
        return when {
            state == State.IDLE || state == State.LOADING ->
                max(0L, player.currentPosition)
            seeking != null && seeking != C.TIME_UNSET -> seeking
            else -> player.currentPosition
        }
    }

    private fun durationMs(): Long =
        if (released || state == State.IDLE || state == State.LOADING) {
            C.TIME_UNSET
        } else {
            player.duration
        }

    private fun updatePosition() {
        updatePositionMs = currentPositionMs()
        updateTimeMs = System.currentTimeMillis()
    }

    private fun updatePositionIfChanged(): Boolean {
        if (released) return false
        if (!player.playWhenReady || state != State.READY) {
            if (currentPositionMs() == updatePositionMs) return false
        }
        updatePosition()
        return true
    }

    private fun updateCurrentIndex(): Boolean {
        val index = player.currentMediaItemIndex
        if (index == currentIndex) return false
        currentIndex = index
        return true
    }

    private fun clearError() {
        errorCode = null
        errorMessage = null
    }

    // Times are microseconds on the channel, milliseconds in ExoPlayer.
    private fun createEvent(): Map<String, Any?> {
        val duration = durationMs()
        bufferedPositionMs = if (released) 0L else player.bufferedPosition
        return hashMapOf(
            "processingState" to state.ordinal,
            "updatePosition" to 1000 * updatePositionMs,
            "updateTime" to updateTimeMs,
            "bufferedPosition" to 1000 * max(updatePositionMs, bufferedPositionMs),
            "icyMetadata" to HashMap<String, Any>(),
            "duration" to if (duration == C.TIME_UNSET) null else 1000 * duration,
            "currentIndex" to currentIndex,
            "androidAudioSessionId" to sessionId,
            "errorCode" to errorCode,
            "errorMessage" to errorMessage,
        )
    }

    // Queued events ride out with the reply of the call that caused them
    // (onMethodCall's finally), at most one per call; a callback from the
    // player sends its own at once.
    private fun enqueueEvent() {
        pendingEvent = createEvent()
    }

    private fun broadcastPending() {
        val event = pendingEvent ?: return
        pendingEvent = null
        events.send(event)
    }

    private fun broadcastNow() {
        enqueueEvent()
        broadcastPending()
    }

    private fun finishPrepare() {
        val reply = prepareReply ?: return
        prepareReply = null
        val duration = durationMs()
        reply.ok(hashMapOf<String, Any?>(
            "duration" to if (duration == C.TIME_UNSET) null else 1000 * duration))
        pendingAttributes?.let {
            pendingAttributes = null
            player.setAudioAttributes(it, false)
        }
    }

    private fun finishPlay() {
        playReply?.ok()
        playReply = null
    }

    private fun finishSeek() {
        seekPosMs = null
        seekReply?.ok()
        seekReply = null
    }

    private fun abortLoad() {
        prepareReply?.fail(ERROR_ABORT.toString(), "Connection aborted")
        prepareReply = null
    }

    // ── Sources ────────────────────────────────────────────────────────────

    private fun requireRootPlaylist(call: MethodCall) {
        val playlist = call.argument<String>("id")
        if (!playlist.isNullOrEmpty()) {
            throw IllegalArgumentException("nested playlists are not supported")
        }
    }

    private fun decodeSources(json: Any?): List<MediaSource> {
        val list = json as? List<*> ?: throw IllegalArgumentException("List expected: $json")
        return list.map { decodeSource(it as? Map<*, *>) }
    }

    private fun decodeSource(map: Map<*, *>?): MediaSource {
        val type = map?.get("type") as? String
        if (map == null || type != "progressive") {
            throw IllegalArgumentException("Unsupported AudioSource type: $type")
        }
        val uri = map["uri"] as? String
            ?: throw IllegalArgumentException("progressive source without a uri")
        val headers = map["headers"] as? Map<*, *>
        val options = map["options"] as? Map<*, *>
        return ProgressiveMediaSource.Factory(
            if (headers.isNullOrEmpty()) dataSources else buildDataSources(headers),
            if (options == null) extractors else buildExtractors(options),
        ).createMediaSource(
            MediaItem.Builder().setUri(Uri.parse(uri)).setTag(map["id"]).build())
    }

    // DefaultHttpDataSource on purpose: it is HttpURLConnection underneath,
    // and that stack's process-wide socket factory is where the full
    // flavor's "allow self-signed" bridge (InsecureTls) hooks in.
    private fun buildDataSources(headers: Map<*, *>?): DataSource.Factory {
        val properties = HashMap<String, String>()
        headers?.forEach { (key, value) ->
            if (key is String && value is String) properties[key] = value
        }
        val userAgent = properties.remove("User-Agent")
            ?: properties.remove("user-agent")
            ?: Util.getUserAgent(context, "mstream_music")
        val http = DefaultHttpDataSource.Factory()
            .setUserAgent(userAgent)
            .setAllowCrossProtocolRedirects(true)
        if (properties.isNotEmpty()) http.setDefaultRequestProperties(properties)
        return DefaultDataSource.Factory(context, http)
    }

    private fun buildExtractors(options: Map<*, *>?): DefaultExtractorsFactory {
        val android = options?.get("androidExtractorOptions") as? Map<*, *>
        return DefaultExtractorsFactory()
            .setConstantBitrateSeekingEnabled(
                android?.get("constantBitrateSeekingEnabled") as? Boolean ?: true)
            .setConstantBitrateSeekingAlwaysEnabled(
                android?.get("constantBitrateSeekingAlwaysEnabled") as? Boolean ?: false)
            .setMp3ExtractorFlags(android?.get("mp3Flags") as? Int ?: 0)
    }

    // The Dart side owns the shuffle order and sends it whole with every
    // playlist change. ExoPlayer refuses an order of the wrong length, which
    // the two can only disagree on after a load that failed part-way; skip
    // it then, the next load brings a matching one.
    private fun decodeShuffleOrder(json: Any?, length: Int): ShuffleOrder? {
        val list = json as? List<*> ?: return null
        if (list.size != length) return null
        val indices = IntArray(length) { (list[it] as Number).toInt() }
        return ShuffleOrder.DefaultShuffleOrder(indices, random.nextLong())
    }

    private fun applyShuffleOrder(json: Any?) {
        decodeShuffleOrder(json, player.mediaItemCount)?.let { player.setShuffleOrder(it) }
    }

    // ── Audio effects (the five-band equalizer path) ───────────────────────

    private fun setSessionId(id: Int) {
        sessionId = if (id == C.AUDIO_SESSION_ID_UNSET) null else id
        releaseEffects()
        val session = sessionId
        if (session != null) {
            for (raw in rawAudioEffects) {
                val type = raw["type"] as? String ?: continue
                try {
                    val effect = createEffect(type, raw, session)
                    if (effectEnabled[type] ?: (raw["enabled"] == true)) effect.enabled = true
                    effects[type] = effect
                } catch (e: RuntimeException) {
                    // Playback goes on without it; the Dart side hears about
                    // it when it next addresses the effect.
                    Log.e(TAG, "audio effect $type failed on session $session", e)
                }
            }
        }
        enqueueEvent()
    }

    private fun createEffect(type: String, raw: Map<*, *>, session: Int): AudioEffect =
        when (type) {
            LOUDNESS -> LoudnessEnhancer(session).also {
                val initial = ((raw["targetGain"] as? Number)?.toDouble() ?: 0.0) * 100.0
                it.setTargetGain(loudnessTargetMb ?: initial.roundToInt())
            }
            EQUALIZER -> Equalizer(0, session).also {
                for ((band, level) in equalizerLevels) it.setBandLevel(band, level)
            }
            else -> throw IllegalArgumentException("Unknown AudioEffect type: $type")
        }

    private fun effect(type: String): AudioEffect =
        effects[type] ?: throw IllegalStateException("no $type on this player")

    // Frequencies are millihertz and levels millibels on the effect; the
    // channel carries hertz and decibels.
    private fun equalizerParameters(): Map<String, Any> {
        val equalizer = effect(EQUALIZER) as Equalizer
        val bands = ArrayList<Map<String, Any>>()
        for (i in 0 until equalizer.numberOfBands) {
            val band = i.toShort()
            val range = equalizer.getBandFreqRange(band)
            bands.add(hashMapOf(
                "index" to i,
                "lowerFrequency" to range[0] / 1000.0,
                "upperFrequency" to range[1] / 1000.0,
                "centerFrequency" to equalizer.getCenterFreq(band) / 1000.0,
                "gain" to equalizer.getBandLevel(band) / 100.0,
            ))
        }
        val levels = equalizer.bandLevelRange
        return hashMapOf(
            "parameters" to hashMapOf(
                "minDecibels" to levels[0] / 100.0,
                "maxDecibels" to levels[1] / 100.0,
                "bands" to bands,
            ),
        )
    }

    private fun releaseEffects() {
        for (effect in effects.values) {
            try {
                effect.release()
            } catch (e: RuntimeException) {
                Log.w(TAG, "audio effect release failed", e)
            }
        }
        effects.clear()
    }

    // ── Teardown ───────────────────────────────────────────────────────────

    fun dispose() {
        if (released) return
        if (state == State.LOADING) abortLoad()
        finishPlay()
        // Dropped, not answered: see the class comment.
        seekReply = null
        seekPosMs = null
        handler.removeCallbacks(bufferWatch)
        releaseEffects()
        player.removeListener(this)
        player.release()
        released = true
        state = State.IDLE
        broadcastNow()
        events.close()
        // Unhooked, not left answering: the messenger keeps a handler (and
        // through it this object and the released player) for as long as it
        // is registered, and the Dart side makes a new id for every load
        // after a stop.
        methods.setMethodCallHandler(null)
        Log.i(TAG, "player $id released")
    }

    private companion object {
        const val TAG = "Media3Engine"
        const val EQUALIZER = "AndroidEqualizer"
        const val LOUDNESS = "AndroidLoudnessEnhancer"

        // just_audio's Dart side reads this code as "this load was replaced
        // by a newer one" (PlayerInterruptedException), not as a failure.
        const val ERROR_ABORT = 10000000
    }
}

/** A method reply that can be given once; later answers are dropped. */
private class Reply(private val result: MethodChannel.Result) {
    private var sent = false

    fun ok(value: Any? = HashMap<String, Any>()) {
        if (sent) return
        sent = true
        result.success(value)
    }

    fun fail(code: String, message: String?, details: Any? = null) {
        if (sent) return
        sent = true
        result.error(code, message, details)
    }
}

/** An event channel that drops events while nobody listens. */
private class EventStream(messenger: BinaryMessenger, name: String) :
    EventChannel.StreamHandler {
    private val channel = EventChannel(messenger, name)
    private var sink: EventChannel.EventSink? = null

    init {
        channel.setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    fun send(event: Any?) {
        sink?.success(event)
    }

    fun error(code: String, message: String?, details: Any?) {
        sink?.error(code, message, details)
    }

    fun close() {
        sink?.endOfStream()
        sink = null
        channel.setStreamHandler(null)
    }
}

// Dart sends an int as Integer or Long by size, and a double always as one.
private fun MethodCall.long(name: String): Long? = (argument<Any>(name) as? Number)?.toLong()

private fun MethodCall.double(name: String): Double =
    (argument<Any>(name) as? Number)?.toDouble()
        ?: throw IllegalArgumentException("$method: no $name")
