import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// The home-screen "Now Playing" widget.
///
/// Dart owns the state: the app pushes a snapshot of what is playing whenever
/// it changes ([publish]) and the native side persists it, fetches the art
/// and re-renders every placed widget. On Android the buttons never come back
/// through Dart — natively they drive audio_service's media session through
/// its transport controls, and binding that service starts it, so a tap on a
/// dead app cold-boots the handler headless (the action is held until the
/// handler is up) much as a Bluetooth play key would. On iOS the buttons are
/// App Intents the system runs in the app's process; they arrive here as
/// `action` calls ([onAction]) once the app has said it is [ready].
///
/// Every call is a no-op on other platforms and fail-open: a platform error
/// can never disturb playback.
class NowPlayingWidget {
  static const MethodChannel channel =
      MethodChannel('mstream/now_playing_widget');

  static bool get _supported => Platform.isAndroid || Platform.isIOS;

  /// A transport action from the widget: `play`, `pause`, `next`, `previous`,
  /// `shuffle`, `repeat`. iOS only today (Android never routes through Dart).
  static void Function(String action)? onAction;

  /// Tell the native side the app is up and [onAction] is set, so an action
  /// it held from a cold launch can go out.
  static Future<void> ready() async {
    if (!_supported) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'action') onAction?.call('${call.arguments}');
      return null;
    });
    try {
      await channel.invokeMethod<void>('ready');
    } catch (_) {
      // A build without the plugin, or a native side with no handshake.
    }
  }

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
    if (!_supported) return;
    try {
      await channel.invokeMethod<void>('publish', snapshot);
    } on MissingPluginException {
      // A stripped build without the plugin: nothing to draw on.
    } on PlatformException {
      // Rendering failed natively; the next publish tries again.
    }
  }

  /// Ask the launcher to place the widget (Android 8+; the launcher shows its
  /// own confirmation) — one of the sizes [pinTargets] lists (`2x1` … `4x3`),
  /// the 4x1 when none is given. False when the launcher does not support
  /// pinning.
  static Future<bool> requestPin({String? size}) async {
    if (!Platform.isAndroid) return false;
    try {
      return await channel.invokeMethod<bool>('requestPin', size) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// The sizes a pin request can place, each with the label the launcher's
  /// own picker shows for it (in the app's language), and whether this
  /// launcher takes pin requests at all. Android only; empty elsewhere.
  static Future<PinTargets> pinTargets() async {
    if (!Platform.isAndroid) return PinTargets.none;
    try {
      return PinTargets.parse(await channel.invokeMethod<Object?>('pinTargets'));
    } catch (_) {
      return PinTargets.none;
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
    if (!_supported) return const {};
    try {
      final r = await channel.invokeMethod<Map<Object?, Object?>>('debugState');
      return r?.map((k, v) => MapEntry('$k', v)) ?? const {};
    } catch (e) {
      return {'error': '$e'};
    }
  }
}

/// One of the widget's picker entries: its cell size and the launcher's label.
class PinTarget {
  const PinTarget({required this.size, required this.label});

  /// `2x1`, `2x2`, `4x1`, `4x2` or `4x3`.
  final String size;

  /// What the launcher's picker (and its pin dialog) calls it.
  final String label;

  @override
  String toString() => 'PinTarget($size, $label)';
}

/// What [NowPlayingWidget.pinTargets] reports.
class PinTargets {
  const PinTargets({required this.supported, required this.targets});

  /// Whether the launcher takes pin requests (Android 8+, and its say).
  final bool supported;

  /// The sizes on offer, smallest first.
  final List<PinTarget> targets;

  static const none = PinTargets(supported: false, targets: []);

  /// The native reply: `{supported: bool, targets: [{size, label}, …]}`;
  /// anything malformed is [none].
  static PinTargets parse(Object? reply) {
    if (reply is! Map) return none;
    final raw = reply['targets'];
    final targets = <PinTarget>[];
    if (raw is List) {
      for (final t in raw) {
        if (t is! Map) continue;
        final size = t['size'], label = t['label'];
        if (size is String && size.isNotEmpty && label is String) {
          targets.add(PinTarget(size: size, label: label));
        }
      }
    }
    return PinTargets(supported: reply['supported'] == true, targets: targets);
  }
}
