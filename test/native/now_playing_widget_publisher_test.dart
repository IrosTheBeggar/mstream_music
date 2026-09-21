import 'dart:ui' show Locale;

import 'package:audio_service/audio_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/native/now_playing_widget_publisher.dart';
import 'package:now_playing_widget/now_playing_widget.dart';
import 'package:rxdart/rxdart.dart';

void main() {
  late BehaviorSubject<MediaItem?> item;
  late BehaviorSubject<PlaybackState> state;
  late BehaviorSubject<Locale?> locale;
  late List<Map<String, Object?>> sent;
  late bool failSend;

  const debounce = Duration(milliseconds: 250);
  const settle = Duration(milliseconds: 300);
  final t0 = DateTime.utc(2026, 9, 20, 12);

  final track = MediaItem(
      id: 'https://demo/stream/1',
      title: 'Hear The Cry',
      artist: 'Selfless',
      album: 'Album',
      duration: const Duration(minutes: 3, seconds: 44),
      artUri: Uri.parse('https://demo/album-art/1.jpg?compress=l&token=abc'));
  // The handler's "No media loaded" placeholder: an empty id.
  const blank = MediaItem(id: '', title: 'No media loaded', artist: '');

  PlaybackState at(
    Duration position,
    DateTime time, {
    bool playing = true,
    AudioServiceShuffleMode shuffle = AudioServiceShuffleMode.none,
    AudioServiceRepeatMode repeat = AudioServiceRepeatMode.none,
    double speed = 1.0,
  }) =>
      PlaybackState(
          playing: playing,
          updatePosition: position,
          updateTime: time,
          shuffleMode: shuffle,
          repeatMode: repeat,
          speed: speed);

  setUp(() {
    item = BehaviorSubject<MediaItem?>.seeded(null);
    state = BehaviorSubject<PlaybackState>.seeded(
        at(Duration.zero, t0, playing: false));
    locale = BehaviorSubject<Locale?>.seeded(null);
    sent = [];
    failSend = false;
  });

  NowPlayingWidgetPublisher make() => NowPlayingWidgetPublisher(
        mediaItem: item,
        playbackState: state,
        locale: locale,
        debounce: debounce,
        send: (m) async {
          if (failSend) throw StateError('channel down');
          sent.add(m);
        },
      );

  void play(bool playing) =>
      state.add(state.value.copyWith(playing: playing));

  group('NowPlayingWidgetPublisher', () {
    test('publishes the current state once on start, as the empty state', () {
      fakeAsync((async) {
        final p = make()..listen();
        async.elapse(settle);
        expect(sent, hasLength(1));
        expect(sent.single[NowPlayingWidget.keyHasTrack], isFalse);
        expect(sent.single[NowPlayingWidget.keyPlaying], isFalse);
        expect(sent.single[NowPlayingWidget.keyTitle], '');
        expect(sent.single[NowPlayingWidget.keyDurationMs], 0);
        p.dispose();
      });
    });

    test('a track that starts playing is one publish with its fields', () {
      fakeAsync((async) {
        final p = make()..listen();
        async.elapse(settle);
        item.add(track);
        state.add(at(const Duration(seconds: 12), t0));
        async.elapse(settle);
        expect(sent, hasLength(2));
        final s = sent.last;
        expect(s[NowPlayingWidget.keyHasTrack], isTrue);
        expect(s[NowPlayingWidget.keyPlaying], isTrue);
        expect(s[NowPlayingWidget.keyTitle], 'Hear The Cry');
        expect(s[NowPlayingWidget.keyArtist], 'Selfless');
        expect(s[NowPlayingWidget.keyAlbum], 'Album');
        expect(s[NowPlayingWidget.keyArtUrl],
            'https://demo/album-art/1.jpg?compress=l&token=abc');
        expect(s[NowPlayingWidget.keyDurationMs], 224000);
        expect(s[NowPlayingWidget.keyPositionMs], 12000);
        expect(s[NowPlayingWidget.keyPositionAtMs], t0.millisecondsSinceEpoch);
        expect(s[NowPlayingWidget.keySpeed], 1.0);
        expect(s[NowPlayingWidget.keyShuffle], isFalse);
        expect(s[NowPlayingWidget.keyRepeat], 'none');
        p.dispose();
      });
    });

    test('the blank-then-null flash after a clear lands as ONE empty state',
        () {
      fakeAsync((async) {
        final p = make()..listen();
        item.add(track);
        play(true);
        async.elapse(settle);
        expect(sent, hasLength(1));
        // AudioPlayerHandler._emitCurrentMediaItem on an emptied queue.
        item.add(blank);
        item.add(null);
        play(false);
        async.elapse(settle);
        expect(sent, hasLength(2));
        expect(sent.last[NowPlayingWidget.keyHasTrack], isFalse);
        expect(sent.last[NowPlayingWidget.keyTitle], '');
        p.dispose();
      });
    });

    test('a pause republishes; a state tick that changes nothing does not',
        () {
      fakeAsync((async) {
        final p = make()..listen();
        item.add(track);
        play(true);
        async.elapse(settle);
        expect(sent, hasLength(1));
        // Buffering flips and queue-index ticks keep every drawn fact.
        state.add(state.value
            .copyWith(processingState: AudioProcessingState.buffering));
        state.add(state.value.copyWith(queueIndex: 3));
        async.elapse(settle);
        expect(sent, hasLength(1));
        play(false);
        async.elapse(settle);
        expect(sent, hasLength(2));
        expect(sent.last[NowPlayingWidget.keyPlaying], isFalse);
        p.dispose();
      });
    });

    test('playback merely running is no publish; a seek is', () {
      fakeAsync((async) {
        final p = make()..listen();
        item.add(track);
        state.add(at(Duration.zero, t0));
        async.elapse(settle);
        expect(sent, hasLength(1));
        // Five seconds later the fix says five seconds: where extrapolation
        // already puts it.
        state.add(at(const Duration(seconds: 5),
            t0.add(const Duration(seconds: 5))));
        async.elapse(settle);
        expect(sent, hasLength(1));
        // A jump to a minute in is a seek.
        state.add(at(const Duration(seconds: 60),
            t0.add(const Duration(seconds: 6))));
        async.elapse(settle);
        expect(sent, hasLength(2));
        expect(sent.last[NowPlayingWidget.keyPositionMs], 60000);
        p.dispose();
      });
    });

    test('shuffle and repeat changes publish with their values', () {
      fakeAsync((async) {
        final p = make()..listen();
        item.add(track);
        state.add(at(Duration.zero, t0));
        async.elapse(settle);
        expect(sent, hasLength(1));
        state.add(at(Duration.zero, t0, shuffle: AudioServiceShuffleMode.all));
        async.elapse(settle);
        expect(sent, hasLength(2));
        expect(sent.last[NowPlayingWidget.keyShuffle], isTrue);
        state.add(at(Duration.zero, t0,
            shuffle: AudioServiceShuffleMode.all,
            repeat: AudioServiceRepeatMode.one));
        async.elapse(settle);
        expect(sent, hasLength(3));
        expect(sent.last[NowPlayingWidget.keyRepeat], 'one');
        p.dispose();
      });
    });

    test('a language change republishes with the new tag', () {
      fakeAsync((async) {
        final p = make()..listen();
        async.elapse(settle);
        expect(sent.single[NowPlayingWidget.keyLocale], '');
        locale.add(const Locale('de'));
        async.elapse(settle);
        expect(sent, hasLength(2));
        expect(sent.last[NowPlayingWidget.keyLocale], 'de');
        p.dispose();
      });
    });

    test('a failing send is logged and the next change still publishes', () {
      fakeAsync((async) {
        final p = make()..listen();
        failSend = true;
        async.elapse(settle);
        expect(sent, isEmpty);
        failSend = false;
        item.add(track);
        async.elapse(settle);
        expect(sent, hasLength(1));
        expect(sent.single[NowPlayingWidget.keyTitle], 'Hear The Cry');
        p.dispose();
      });
    });
  });

  group('NowPlayingWidgetPublisher.snapshotFor', () {
    test('null artist / album / art become empty strings, never "null"', () {
      const bare = MediaItem(id: 'https://demo/stream/2', title: 'T');
      final s = NowPlayingWidgetPublisher.snapshotFor(
          item: bare, state: at(Duration.zero, t0), locale: null);
      expect(s[NowPlayingWidget.keyArtist], '');
      expect(s[NowPlayingWidget.keyAlbum], '');
      expect(s[NowPlayingWidget.keyArtUrl], '');
      expect(s[NowPlayingWidget.keyPlaying], isTrue);
      expect(s[NowPlayingWidget.keyDurationMs], 0);
      expect(s.values.any((v) => v == 'null'), isFalse);
    });

    test('the placeholder item counts as no track, and cannot be playing', () {
      final s = NowPlayingWidgetPublisher.snapshotFor(
          item: blank, state: at(Duration.zero, t0), locale: const Locale('pt'));
      expect(s[NowPlayingWidget.keyHasTrack], isFalse);
      expect(s[NowPlayingWidget.keyPlaying], isFalse);
      expect(s[NowPlayingWidget.keyTitle], '');
      expect(s[NowPlayingWidget.keyPositionMs], 0);
      expect(s[NowPlayingWidget.keyLocale], 'pt');
    });

    test('repeat modes map to the three names the widget draws', () {
      String repeatOf(AudioServiceRepeatMode m) =>
          NowPlayingWidgetPublisher.snapshotFor(
              item: track,
              state: at(Duration.zero, t0, repeat: m),
              locale: null)[NowPlayingWidget.keyRepeat] as String;
      expect(repeatOf(AudioServiceRepeatMode.none), 'none');
      expect(repeatOf(AudioServiceRepeatMode.all), 'all');
      expect(repeatOf(AudioServiceRepeatMode.group), 'all');
      expect(repeatOf(AudioServiceRepeatMode.one), 'one');
    });
  });

  group('NowPlayingWidgetPublisher.shouldPublish', () {
    Map<String, Object?> snap({
      bool playing = true,
      int pos = 0,
      int atMs = 0,
      double speed = 1.0,
      String title = 'T',
    }) =>
        {
          NowPlayingWidget.keyTitle: title,
          NowPlayingWidget.keyPlaying: playing,
          NowPlayingWidget.keyPositionMs: pos,
          NowPlayingWidget.keyPositionAtMs: atMs,
          NowPlayingWidget.keySpeed: speed,
        };

    test('nothing before → publish', () {
      expect(NowPlayingWidgetPublisher.shouldPublish(null, snap()), isTrue);
    });

    test('a drawn field changed → publish', () {
      expect(
          NowPlayingWidgetPublisher.shouldPublish(
              snap(), snap(title: 'Other')),
          isTrue);
    });

    test('the fix advanced as playback would have → no publish', () {
      expect(
          NowPlayingWidgetPublisher.shouldPublish(
              snap(pos: 0, atMs: 1000), snap(pos: 10000, atMs: 11000)),
          isFalse);
      // At double speed the expectation doubles too.
      expect(
          NowPlayingWidgetPublisher.shouldPublish(
              snap(pos: 0, atMs: 1000, speed: 2.0),
              snap(pos: 20000, atMs: 11000, speed: 2.0)),
          isFalse);
    });

    test('the fix jumped → publish; paused, any move beyond tolerance counts',
        () {
      expect(
          NowPlayingWidgetPublisher.shouldPublish(
              snap(pos: 0, atMs: 1000), snap(pos: 60000, atMs: 2000)),
          isTrue);
      expect(
          NowPlayingWidgetPublisher.shouldPublish(
              snap(playing: false, pos: 0, atMs: 1000),
              snap(playing: false, pos: 10000, atMs: 11000)),
          isTrue);
      expect(
          NowPlayingWidgetPublisher.shouldPublish(
              snap(playing: false, pos: 0, atMs: 1000),
              snap(playing: false, pos: 2000, atMs: 11000)),
          isFalse);
    });
  });
}
