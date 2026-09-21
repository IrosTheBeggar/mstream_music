import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// The Android home-screen "Now Playing" widget.
///
/// Dart owns the state: the app pushes a snapshot of what is playing whenever
/// it changes ([publish]) and the native side persists it, fetches the art
/// and re-renders every placed widget. The widget's buttons never come back
/// through Dart — natively they drive audio_service's media session through
/// its transport controls, and binding that service starts it, so a tap on a
/// dead app cold-boots the handler headless (the action is held until the
/// handler is up) much as a Bluetooth play key would.
///
/// Every call is a no-op off Android and fail-open: a platform error can
/// never disturb playback.
class NowPlayingWidget {
  static const MethodChannel channel =
      MethodChannel('mstream/now_playing_widget');

  /// Snapshot keys the native side reads. Missing keys read as empty / false.
  static const String keyTitle = 'title';
  static const String keyArtist = 'artist';
  static const String keyAlbum = 'album';
  static const String keyArtUrl = 'artUrl';
  static const String keyPlaying = 'playing';
  static const String keyHasTrack = 'hasTrack';
  static const String keyLocale = 'locale';
  /// The track's length, 0 when unknown (the large layout then hides progress).
  static const String keyDurationMs = 'durationMs';
  /// A position FIX: [keyPositionMs] was true at [keyPositionAtMs] (epoch ms)
  /// and advances at [keySpeed] while playing. The native side extrapolates
  /// between publishes, so a fix is sent only when it jumps (a seek, a track).
  static const String keyPositionMs = 'positionMs';
  static const String keyPositionAtMs = 'positionAtMs';
  static const String keySpeed = 'speed';
  static const String keyShuffle = 'shuffle';
  /// 'none', 'all' or 'one'.
  static const String keyRepeat = 'repeat';

  /// Push the current state. [snapshot] holds the `key*` entries above; an
  /// `hasTrack: false` snapshot renders the empty state.
  static Future<void> publish(Map<String, Object?> snapshot) async {
    if (!Platform.isAndroid) return;
    try {
      await channel.invokeMethod<void>('publish', snapshot);
    } on MissingPluginException {
      // A stripped build without the plugin: nothing to draw on.
    } on PlatformException {
      // Rendering failed natively; the next publish tries again.
    }
  }

  /// Ask the launcher to place the widget (Android 8+; the launcher shows its
  /// own confirmation). False when the launcher does not support pinning.
  static Future<bool> requestPin() async {
    if (!Platform.isAndroid) return false;
    try {
      return await channel.invokeMethod<bool>('requestPin') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Debug builds: draw every placed widget with one layout regardless of
  /// its size — `mini`, `tile`, `row`, `card`, `large` — or `auto` to go back
  /// to sizing. Returns what is now in force.
  static Future<String> debugForceLayout(String name) async {
    if (!Platform.isAndroid) return 'auto';
    try {
      return await channel.invokeMethod<String>('debugForceLayout', name) ??
          'auto';
    } catch (e) {
      return 'error: $e';
    }
  }

  /// What the native side holds: the persisted snapshot, the number of placed
  /// widgets, whether art is cached. Debug tooling only.
  static Future<Map<String, Object?>> debugState() async {
    if (!Platform.isAndroid) return const {};
    try {
      final r = await channel.invokeMethod<Map<Object?, Object?>>('debugState');
      return r?.map((k, v) => MapEntry('$k', v)) ?? const {};
    } catch (e) {
      return {'error': '$e'};
    }
  }
}
