// Which native engine plays on-device audio on Android: the choice, and the
// switch that carries it out.
//
// just_audio's Dart player never talks to Android directly. Each time it
// needs a native player — the first load, and every load after a stop or an
// error, since it disposes the native side when it goes idle — it asks
// JustAudioPlatform.instance to make one. PlaybackEngineSwitch is installed
// as that instance and hands the request to one of two platforms:
// just_audio's own (its Java ExoPlayer wrapper) or the in-repo Media3 engine
// (packages/media3_player), which answers the same protocol.
//
// So the choice is made per native player and takes effect at the next one.
// Everything above stays just_audio's Dart player — its playlist, its idle
// stub and load interruption, its position clock — which is the behaviour
// LocalPlaybackBackend and the handler are tuned against. Swapping the
// engine underneath keeps all of that; writing a second PlaybackBackend
// would have meant re-earning it.
//
// The handler moves a live player across (AudioPlayerHandler
// .setPlaybackEngine); this file only decides who makes the next one.

import 'dart:io' show Platform;

import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:media3_player/media3_player.dart';

import '../singletons/log_manager.dart';

/// just_audio's platform, split across two engines.
class PlaybackEngineSwitch extends JustAudioPlatform {
  PlaybackEngineSwitch({
    required this._justAudio,
    required this._media3,
    this.useMedia3 = false,
    this._log,
  });

  final JustAudioPlatform _justAudio;
  final JustAudioPlatform _media3;
  final void Function(String line)? _log;

  /// The engine the NEXT native player is made on. One already made stays on
  /// its own until just_audio disposes it.
  bool useMedia3;

  // Who made each live native player, so its teardown goes back to the
  // engine that holds it — the choice may have changed since.
  final Map<String, JustAudioPlatform> _owners = {};

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    if (useMedia3) {
      try {
        final player = await _media3.init(request);
        _owners[request.id] = _media3;
        return player;
      } catch (e) {
        // An engine that cannot even make a player must not take playback
        // down with it: this one player goes to just_audio, and the log says
        // so. The choice stands, so the next player tries again.
        _log?.call('[audio] media3 engine could not make a player ($e) — '
            'this one runs on just_audio');
      }
    }
    final player = await _justAudio.init(request);
    _owners[request.id] = _justAudio;
    return player;
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(DisposePlayerRequest request) =>
      (_owners.remove(request.id) ?? _justAudio).disposePlayer(request);

  /// just_audio sends this once, un-awaited, right before its first `init`,
  /// to clear out native players a hot restart left running — which may be on
  /// either engine. Both calls are therefore SENT before this returns, not
  /// chained: a dispose-all that left after the awaited reply of the other
  /// would reach its engine behind that first `init` and tear down the
  /// player it just made.
  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
      DisposeAllPlayersRequest request) {
    _owners.clear();
    final media3 = _media3
        .disposeAllPlayers(request)
        .then<void>((_) {}, onError: (Object _) {});
    final justAudio = _justAudio.disposeAllPlayers(request);
    return media3.then((_) => justAudio);
  }
}

/// The app's handle on the engine choice. Static, like
/// DynamicsEqualizer.supported: decided in main.dart before the handler
/// builds its player, and read wherever the answer matters.
abstract final class PlaybackEngine {
  static PlaybackEngineSwitch? _switch;

  /// Whether there is a choice to make: Android, with the switch installed.
  /// Elsewhere just_audio's own platform code is the only engine.
  static bool get selectable => _switch != null;

  /// Whether new native players are made on the Media3 engine.
  static bool get usesMedia3 => _switch?.useMedia3 ?? false;
  static set usesMedia3(bool value) => _switch?.useMedia3 = value;

  /// Put the switch in front of just_audio's platform. Call once, before the
  /// first player is constructed; a no-op off Android and on a second call.
  static void install({required bool useMedia3}) {
    if (!Platform.isAndroid || _switch != null) return;
    final engine = PlaybackEngineSwitch(
      justAudio: JustAudioPlatform.instance,
      media3: Media3JustAudio(),
      useMedia3: useMedia3,
      log: appLog,
    );
    JustAudioPlatform.instance = engine;
    _switch = engine;
    appLog('[audio] playback engine: ${useMedia3 ? 'media3' : 'just_audio'}');
  }
}
