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

  final track = MediaItem(
      id: 'https://demo/stream/1',
      title: 'Hear The Cry',
      artist: 'Selfless',
      album: 'Album',
      artUri: Uri.parse('https://demo/album-art/1.jpg?compress=l&token=abc'));
  // The handler's "No media loaded" placeholder: an empty id.
  const blank = MediaItem(id: '', title: 'No media loaded', artist: '');

  setUp(() {
    item = BehaviorSubject<MediaItem?>.seeded(null);
    state = BehaviorSubject<PlaybackState>.seeded(PlaybackState());
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
        p.dispose();
      });
    });

    test('a track that starts playing is one publish with its fields', () {
      fakeAsync((async) {
        final p = make()..listen();
        async.elapse(settle);
        item.add(track);
        play(true);
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
        // Position / buffering updates keep playing == true.
        state.add(state.value
            .copyWith(updatePosition: const Duration(seconds: 5)));
        state.add(state.value
            .copyWith(processingState: AudioProcessingState.buffering));
        async.elapse(settle);
        expect(sent, hasLength(1));
        play(false);
        async.elapse(settle);
        expect(sent, hasLength(2));
        expect(sent.last[NowPlayingWidget.keyPlaying], isFalse);
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
          item: bare, playing: true, locale: null);
      expect(s[NowPlayingWidget.keyArtist], '');
      expect(s[NowPlayingWidget.keyAlbum], '');
      expect(s[NowPlayingWidget.keyArtUrl], '');
      expect(s[NowPlayingWidget.keyPlaying], isTrue);
      expect(s.values.any((v) => v == 'null'), isFalse);
    });

    test('the placeholder item counts as no track, and cannot be playing', () {
      final s = NowPlayingWidgetPublisher.snapshotFor(
          item: blank, playing: true, locale: const Locale('pt'));
      expect(s[NowPlayingWidget.keyHasTrack], isFalse);
      expect(s[NowPlayingWidget.keyPlaying], isFalse);
      expect(s[NowPlayingWidget.keyTitle], '');
      expect(s[NowPlayingWidget.keyLocale], 'pt');
    });
  });
}
