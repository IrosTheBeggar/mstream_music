import 'dart:async' show StreamSubscription;
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'dart:ui' show Locale;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode, mapEquals;
import 'package:now_playing_widget/now_playing_widget.dart';
import 'package:rxdart/rxdart.dart';

import '../singletons/log_manager.dart';
import '../singletons/media.dart';
import '../singletons/settings.dart';

/// Feeds the Android home-screen widget (packages/now_playing_widget).
///
/// One direction only: the current item, whether it is playing and the app's
/// language become a snapshot the native side persists and draws. The
/// widget's buttons drive audio_service's media session natively, so they
/// reach the handler — dead process included — without Dart. Debounced,
/// so the blank-then-null flash the handler emits when the queue empties
/// lands as one empty state, and deduped, so a position tick that changes
/// nothing never crosses the channel.
class NowPlayingWidgetPublisher {
  NowPlayingWidgetPublisher({
    required this.mediaItem,
    required this.playbackState,
    required this.locale,
    required this.send,
    this.debounce = const Duration(milliseconds: 250),
  });

  final Stream<MediaItem?> mediaItem;
  final Stream<PlaybackState> playbackState;
  final Stream<Locale?> locale;
  final Future<void> Function(Map<String, Object?> snapshot) send;
  final Duration debounce;

  StreamSubscription<Map<String, Object?>>? _sub;
  Map<String, Object?>? _last;

  /// The last snapshot sent (tests, the debug hook).
  Map<String, Object?>? get last => _last;

  static NowPlayingWidgetPublisher? _app;

  /// The app's instance: the audio handler, the language setting and the
  /// plugin. Android only; a no-op everywhere else and on a second call.
  static Future<void> start() async {
    if (!Platform.isAndroid || _app != null) return;
    final handler = MediaManager().audioHandler;
    _app = NowPlayingWidgetPublisher(
      mediaItem: handler.mediaItem,
      playbackState: handler.playbackState,
      locale: SettingsManager().localeStream,
      send: NowPlayingWidget.publish,
    )..listen();
    if (kDebugMode) _registerDebugExtension();
  }

  void listen() {
    _sub ??= Rx.combineLatest3<MediaItem?, bool, Locale?, Map<String, Object?>>(
      mediaItem,
      playbackState.map((s) => s.playing).distinct(),
      locale,
      (item, playing, locale) =>
          snapshotFor(item: item, playing: playing, locale: locale),
    ).debounceTime(debounce).listen(_publish);
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  Future<void> _publish(Map<String, Object?> snapshot) async {
    if (mapEquals(_last, snapshot)) return;
    _last = snapshot;
    // The title is what the smoke script matches against the launcher; the
    // art URL (a session token inside) is deliberately not logged.
    appLog('[widget] publish hasTrack=${snapshot[NowPlayingWidget.keyHasTrack]} '
        'playing=${snapshot[NowPlayingWidget.keyPlaying]} '
        'title="${snapshot[NowPlayingWidget.keyTitle]}"');
    try {
      await send(snapshot);
    } catch (e) {
      appLog('[widget] publish failed: $e');
    }
  }

  /// Pure: the snapshot for a state. An item with an empty id is the
  /// handler's "No media loaded" placeholder — no track, like null.
  static Map<String, Object?> snapshotFor({
    required MediaItem? item,
    required bool playing,
    required Locale? locale,
  }) {
    final hasTrack = item != null && item.id.isNotEmpty;
    return {
      NowPlayingWidget.keyHasTrack: hasTrack,
      NowPlayingWidget.keyTitle: hasTrack ? item.title : '',
      NowPlayingWidget.keyArtist: hasTrack ? (item.artist ?? '') : '',
      NowPlayingWidget.keyAlbum: hasTrack ? (item.album ?? '') : '',
      NowPlayingWidget.keyArtUrl: hasTrack ? (item.artUri?.toString() ?? '') : '',
      NowPlayingWidget.keyPlaying: hasTrack && playing,
      NowPlayingWidget.keyLocale: locale?.toLanguageTag() ?? '',
    };
  }

  /// Debug builds only: `ext.mstream.widget` on the VM service, so the smoke
  /// script can place the widget, read what the native side holds, and push
  /// a cover through the whole fetch chain (`art&url=<image on a configured
  /// host>` republishes the last snapshot with that art; the next real
  /// change puts the widget right again). Params: `action=state|pin|art`.
  static void _registerDebugExtension() {
    developer.registerExtension('ext.mstream.widget',
        (String method, Map<String, String> params) async {
      try {
        final action = params['action'] ?? 'state';
        final dynamic r = switch (action) {
          'pin' => await NowPlayingWidget.requestPin(),
          'art' => await _debugPublishArt(params['url'] ?? ''),
          _ => {
              'native': await NowPlayingWidget.debugState(),
              'last': _app?.last,
            },
        };
        return developer.ServiceExtensionResponse.result(
            jsonEncode({'ok': true, 'result': r}));
      } catch (e) {
        return developer.ServiceExtensionResponse.result(
            jsonEncode({'ok': false, 'error': '$e'}));
      }
    });
  }

  static Future<bool> _debugPublishArt(String url) async {
    final base = _app?.last ??
        snapshotFor(item: null, playing: false, locale: null);
    final title = base[NowPlayingWidget.keyTitle] as String? ?? '';
    await NowPlayingWidget.publish({
      ...base,
      NowPlayingWidget.keyHasTrack: true,
      NowPlayingWidget.keyTitle: title.isEmpty ? 'Art check' : title,
      NowPlayingWidget.keyArtUrl: url,
    });
    return true;
  }
}
