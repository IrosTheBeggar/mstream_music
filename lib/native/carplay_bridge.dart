import 'dart:async' show StreamSubscription, unawaited;
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';

import '../media/auto_browse.dart';
import '../singletons/log_manager.dart';
import '../singletons/media.dart';
import '../singletons/server_list.dart';

/// CarPlay ⇄ Dart. The Swift CarPlay scene (ios/Runner/CarPlay.swift) renders
/// whatever this hands back: the browse tree Android Auto already uses
/// (AutoBrowse — headless-safe, never throws), serialised as plain maps, plus
/// the live queue for the Now Playing screen's "Queue" list. Playback itself
/// goes through the audio handler like every other entry point, so CarPlay
/// gets Auto DJ, the Quick Connect tunnel and the offline copies for free.
class CarPlayBridge {
  static const MethodChannel _channel = MethodChannel('mstream/carplay');

  /// What Swift asks for as the top level; mapped onto audio_service's root.
  static const String rootId = 'root';

  static bool _started = false;
  static StreamSubscription<dynamic>? _playbackSub;
  static StreamSubscription<dynamic>? _customSub;

  /// Registers the handler and tells the native side Dart is up (it may have
  /// been showing "Loading…" to the car since before main() ran). iOS only;
  /// a no-op everywhere else and when the binary has no bridge.
  static Future<void> init() async {
    if (!Platform.isIOS || _started) return;
    _started = true;
    _channel.setMethodCallHandler(_handle);
    if (kDebugMode) _registerDebugExtension();
    try {
      await _channel.invokeMethod<void>('ready');
      _watchModes();
    } on MissingPluginException {
      // No CarPlay scene in this binary (tests, a stripped build): nothing to drive.
    } catch (e) {
      appLog('[carplay] ready handshake failed: $e');
    }
  }

  static Future<dynamic> _handle(MethodCall call) async {
    switch (call.method) {
      case 'getChildren':
        final id = call.arguments as String;
        final items = await AutoBrowse.children(
            id == rootId ? AudioService.browsableRootId : id);
        appLog('[carplay] children($id): ${items.length}');
        return items.map(encodeItem).toList();
      case 'play':
        final id = call.arguments as String;
        appLog('[carplay] play($id)');
        // Fire-and-forget: the handler's play() future completes only when
        // playback later pauses or stops (just_audio semantics), and the car
        // wants the row's completion — and its Now Playing screen — at once.
        // AutoBrowse.play logs its own failures.
        unawaited(AutoBrowse.play(id));
        return null;
      case 'getQueue':
        final handler = MediaManager().audioHandler;
        return {
          'items': handler.queue.value.map(encodeItem).toList(),
          'index': handler.playbackState.value.queueIndex ?? -1,
        };
      case 'skipToQueueItem':
        final index = call.arguments as int;
        appLog('[carplay] skipToQueueItem($index)');
        await MediaManager().audioHandler.skipToQueueItem(index);
        return null;
      // ── Now Playing buttons: the same toggles as the player panel and the
      // queue header, so the car and the phone never disagree on what a tap
      // means. The new state reaches the car through the modes push below.
      case 'toggleShuffle':
        final handler = MediaManager().audioHandler;
        final on = handler.playbackState.value.shuffleMode ==
            AudioServiceShuffleMode.all;
        appLog('[carplay] shuffle → ${on ? 'off' : 'on'}');
        await handler.setShuffleMode(
            on ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all);
        return null;
      case 'cycleRepeat':
        final handler = MediaManager().audioHandler;
        final next = nextRepeatMode(handler.playbackState.value.repeatMode);
        appLog('[carplay] repeat → ${next.name}');
        await handler.setRepeatMode(next);
        return null;
      case 'toggleAutoDJ':
        final handler = MediaManager().audioHandler;
        if (handler.autoDJServer != null) {
          appLog('[carplay] Auto DJ → off');
          unawaited(handler.customAction('setAutoDJ', {'autoDJServer': null}));
          return null;
        }
        final server = ServerManager().currentServer;
        if (server == null) {
          appLog('[carplay] Auto DJ: no server to run it on');
          return null;
        }
        appLog('[carplay] Auto DJ → on (${server.localname})');
        // Not awaited: on an empty queue this starts random play, whose
        // play() future only completes when playback later pauses.
        unawaited(handler.customAction('setAutoDJ', {'autoDJServer': server}));
        return null;
      default:
        throw MissingPluginException('${call.method} is not a CarPlay method');
    }
  }

  /// Debug builds only: `ext.mstream.carplay` on the VM service, so a test
  /// run can drive the car's templates (the Simulator's CarPlay window takes
  /// no synthetic taps). Params: `action=state|tap|back|upnext|button`, `index=<row or button>`.
  static void _registerDebugExtension() {
    developer.registerExtension('ext.mstream.carplay',
        (String method, Map<String, String> params) async {
      try {
        final action = params['action'] ?? 'state';
        final dynamic r = switch (action) {
          'tap' => await _channel.invokeMethod<dynamic>(
              'debugTap', int.parse(params['index'] ?? '0')),
          'back' => await _channel.invokeMethod<dynamic>('debugBack'),
          'upnext' => await _channel.invokeMethod<dynamic>('debugUpNext'),
          'button' => await _channel.invokeMethod<dynamic>(
              'debugButton', int.parse(params['index'] ?? '0')),
          _ => await _channel.invokeMethod<dynamic>('debugState'),
        };
        return developer.ServiceExtensionResponse.result(
            jsonEncode({'ok': true, 'result': r}));
      } catch (e) {
        return developer.ServiceExtensionResponse.result(
            jsonEncode({'ok': false, 'error': '$e'}));
      }
    });
  }

  /// Pushes shuffle / repeat / Auto DJ to the car whenever one changes (and
  /// once on start): CarPlay draws its shuffle and repeat buttons from the
  /// remote command center's mode types, which the Swift side sets from this.
  static void _watchModes() {
    final handler = MediaManager().audioHandler;
    _playbackSub ??= handler.playbackState
        .map((s) => (s.shuffleMode, s.repeatMode))
        .distinct()
        .listen((_) => _pushModes());
    _customSub ??= handler.customState.listen((_) => _pushModes());
    _pushModes();
  }

  static Future<void> _pushModes() async {
    final handler = MediaManager().audioHandler;
    final state = handler.playbackState.value;
    try {
      await _channel.invokeMethod<void>(
          'modes',
          encodeModes(
              shuffle: state.shuffleMode == AudioServiceShuffleMode.all,
              repeat: state.repeatMode,
              autoDJ: handler.autoDJServer != null));
    } catch (e) {
      appLog('[carplay] modes push failed: $e');
    }
  }

  /// The repeat button's cycle: off → all → one → off (the player panel's
  /// order; 'group' has no meaning here and is treated as 'all').
  static AudioServiceRepeatMode nextRepeatMode(AudioServiceRepeatMode m) =>
      switch (m) {
        AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
        AudioServiceRepeatMode.all ||
        AudioServiceRepeatMode.group =>
          AudioServiceRepeatMode.one,
        AudioServiceRepeatMode.one => AudioServiceRepeatMode.none,
      };

  /// What the car is told about the three toggles.
  static Map<String, Object?> encodeModes({
    required bool shuffle,
    required AudioServiceRepeatMode repeat,
    required bool autoDJ,
  }) =>
      {
        'shuffle': shuffle,
        'repeat': switch (repeat) {
          AudioServiceRepeatMode.one => 'one',
          AudioServiceRepeatMode.all || AudioServiceRepeatMode.group => 'all',
          AudioServiceRepeatMode.none => 'none',
        },
        'autoDJ': autoDJ,
      };

  /// The subset of a MediaItem the car needs, as plain values. `notice` marks
  /// AutoBrowse's informational rows (no server, load failed, empty list) so
  /// the car shows them disabled instead of as a broken folder.
  static Map<String, Object?> encodeItem(MediaItem m) => {
        'id': m.id,
        'title': m.title,
        'subtitle': m.artist ?? m.album,
        'artUri': m.artUri?.toString(),
        'playable': m.playable ?? true,
        'notice': m.id == AutoBrowse.noticeId,
      };
}
