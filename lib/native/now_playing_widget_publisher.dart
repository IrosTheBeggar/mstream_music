import 'dart:async' show StreamSubscription;
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'dart:ui' show Locale;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:now_playing_widget/now_playing_widget.dart';
import 'package:rxdart/rxdart.dart';

import '../singletons/log_manager.dart';
import '../singletons/media.dart';
import '../singletons/settings.dart';

/// Feeds the Android home-screen widget (packages/now_playing_widget).
///
/// One direction only: the current item, the playback state (playing,
/// shuffle, repeat, a position fix) and the app's language become a snapshot
/// the native side persists and draws. The widget's buttons drive
/// audio_service's media session natively, so they reach the handler — dead
/// process included — without Dart. Debounced, so the blank-then-null flash
/// the handler emits when the queue empties lands as one empty state, and
/// deduped, so a state broadcast that changes nothing never crosses the
/// channel — the position included: the native side advances it between
/// fixes, so only a jump (a seek, a new track) is worth a publish.
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
    _sub ??= Rx.combineLatest3<MediaItem?, PlaybackState, Locale?,
        Map<String, Object?>>(
      mediaItem,
      playbackState.distinct((a, b) => facts(a) == facts(b)),
      locale,
      (item, state, locale) =>
          snapshotFor(item: item, state: state, locale: locale),
    ).debounceTime(debounce).listen(_publish);
  }

  /// The parts of a state the widget draws; two states with equal facts are
  /// one publish (buffering flips, queue index ticks and the like are not).
  static (bool, AudioServiceShuffleMode, AudioServiceRepeatMode, int, int,
      double) facts(PlaybackState s) => (
        s.playing,
        s.shuffleMode,
        s.repeatMode,
        s.updatePosition.inMilliseconds,
        s.updateTime.millisecondsSinceEpoch,
        s.speed,
      );

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  Future<void> _publish(Map<String, Object?> snapshot) async {
    if (!shouldPublish(_last, snapshot)) return;
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

  /// A seek moves the fix further than this from where the last fix says
  /// playback should be by now; anything closer is playback merely running.
  static const Duration positionTolerance = Duration(seconds: 3);

  /// Pure: whether [next] is worth sending after [last]. Any field but the
  /// position fix differing is; the fix alone only when it jumped.
  static bool shouldPublish(
      Map<String, Object?>? last, Map<String, Object?> next) {
    if (last == null) return true;
    for (final k in next.keys) {
      if (k == NowPlayingWidget.keyPositionMs ||
          k == NowPlayingWidget.keyPositionAtMs) {
        continue;
      }
      if (last[k] != next[k]) return true;
    }
    final lastPos = last[NowPlayingWidget.keyPositionMs] as int? ?? 0;
    final lastAt = last[NowPlayingWidget.keyPositionAtMs] as int? ?? 0;
    final nextPos = next[NowPlayingWidget.keyPositionMs] as int? ?? 0;
    final nextAt = next[NowPlayingWidget.keyPositionAtMs] as int? ?? 0;
    final playing = last[NowPlayingWidget.keyPlaying] == true;
    final speed = (last[NowPlayingWidget.keySpeed] as num?)?.toDouble() ?? 1.0;
    final expected = playing && nextAt > lastAt
        ? lastPos + ((nextAt - lastAt) * speed).round()
        : lastPos;
    return (nextPos - expected).abs() > positionTolerance.inMilliseconds;
  }

  /// Pure: the snapshot for a state. An item with an empty id is the
  /// handler's "No media loaded" placeholder — no track, like null.
  static Map<String, Object?> snapshotFor({
    required MediaItem? item,
    required PlaybackState state,
    required Locale? locale,
  }) {
    final hasTrack = item != null && item.id.isNotEmpty;
    return {
      NowPlayingWidget.keyHasTrack: hasTrack,
      NowPlayingWidget.keyTitle: hasTrack ? item.title : '',
      NowPlayingWidget.keyArtist: hasTrack ? (item.artist ?? '') : '',
      NowPlayingWidget.keyAlbum: hasTrack ? (item.album ?? '') : '',
      NowPlayingWidget.keyArtUrl: hasTrack ? (item.artUri?.toString() ?? '') : '',
      NowPlayingWidget.keyPlaying: hasTrack && state.playing,
      NowPlayingWidget.keyLocale: locale?.toLanguageTag() ?? '',
      NowPlayingWidget.keyDurationMs:
          hasTrack ? (item.duration?.inMilliseconds ?? 0) : 0,
      NowPlayingWidget.keyPositionMs:
          hasTrack ? state.updatePosition.inMilliseconds : 0,
      NowPlayingWidget.keyPositionAtMs:
          hasTrack ? state.updateTime.millisecondsSinceEpoch : 0,
      NowPlayingWidget.keySpeed: state.speed,
      NowPlayingWidget.keyShuffle:
          state.shuffleMode != AudioServiceShuffleMode.none,
      NowPlayingWidget.keyRepeat: switch (state.repeatMode) {
        AudioServiceRepeatMode.one => 'one',
        AudioServiceRepeatMode.all || AudioServiceRepeatMode.group => 'all',
        AudioServiceRepeatMode.none => 'none',
      },
    };
  }

  /// Debug builds only: `ext.mstream.widget` on the VM service, so the smoke
  /// script can place the widget, read what the native side holds, and push
  /// a cover through the whole fetch chain (`art&url=<image on a configured
  /// host>` republishes the last snapshot with that art; the next real
  /// change puts the widget right again), or force one size's layout on
  /// every placed widget (`layout&name=mini|tile|row|card|large|auto`).
  /// Params: `action=state|pin|art|layout`.
  static void _registerDebugExtension() {
    developer.registerExtension('ext.mstream.widget',
        (String method, Map<String, String> params) async {
      try {
        final action = params['action'] ?? 'state';
        final dynamic r = switch (action) {
          'pin' => await NowPlayingWidget.requestPin(),
          'art' => await _debugPublishArt(params['url'] ?? ''),
          'layout' =>
            await NowPlayingWidget.debugForceLayout(params['name'] ?? 'auto'),
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
        snapshotFor(item: null, state: PlaybackState(), locale: null);
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
