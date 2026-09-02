import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';

import '../media/auto_browse.dart';
import '../singletons/log_manager.dart';
import '../singletons/media.dart';

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
      default:
        throw MissingPluginException('${call.method} is not a CarPlay method');
    }
  }

  /// Debug builds only: `ext.mstream.carplay` on the VM service, so a test
  /// run can drive the car's templates (the Simulator's CarPlay window takes
  /// no synthetic taps). Params: `action=state|tap|back|upnext`, `index=<row>`.
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
