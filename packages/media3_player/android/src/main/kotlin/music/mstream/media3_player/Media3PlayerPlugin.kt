package music.mstream.media3_player

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The app's own Android playback engine, serving just_audio's platform
 * protocol on its own channels. The Dart side (lib/media3_player.dart) is a
 * JustAudioPlatform, so just_audio's Dart player drives a [EnginePlayer]
 * exactly as it drives its own Java one, and the app chooses per player which
 * of the two it gets.
 *
 * Methods (channel "mstream/media3_player"), the three just_audio's main
 * channel has:
 *   init(id, androidAudioEffects, useLazyPreparation, ...) -> creates the
 *       player; its own channels are "mstream/media3_player/methods/<id>"
 *       and ".../events/<id>"
 *   disposePlayer(id)
 *   disposeAllPlayers()   (what a hot restart sends first)
 *
 * Players are released when the engine detaches, so a killed engine can
 * never strand a decoder or an audio effect.
 */
class Media3PlayerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null
    private var messenger: BinaryMessenger? = null
    private val players = HashMap<String, EnginePlayer>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        messenger = binding.binaryMessenger
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        disposeAll()
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
        messenger = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> {
                val id = call.argument<String>("id")
                val ctx = context
                val msg = messenger
                if (id == null || ctx == null || msg == null) {
                    result.error("init", "no id, or the engine has detached", null)
                    return
                }
                if (players.containsKey(id)) {
                    result.error("Platform player $id already exists", null, null)
                    return
                }
                try {
                    players[id] = EnginePlayer(
                        ctx,
                        msg,
                        id,
                        call.argument<List<Any?>>("androidAudioEffects")
                            ?.filterIsInstance<Map<*, *>>() ?: emptyList(),
                        call.argument<Boolean>("useLazyPreparation") ?: true,
                    )
                    result.success(null)
                } catch (e: Exception) {
                    result.error("Error: $e", e.toString(), null)
                }
            }
            "disposePlayer" -> {
                players.remove(call.argument<String>("id"))?.dispose()
                result.success(HashMap<String, Any>())
            }
            "disposeAllPlayers" -> {
                disposeAll()
                result.success(HashMap<String, Any>())
            }
            else -> result.notImplemented()
        }
    }

    private fun disposeAll() {
        for (player in ArrayList(players.values)) player.dispose()
        players.clear()
    }

    internal companion object {
        const val CHANNEL = "mstream/media3_player"
    }
}
