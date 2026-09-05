import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/audio_stuff.dart';
import 'package:mstream_music/media/playback_backend.dart';

void main() {
  group('AudioPlayerHandler.protectsCurrentTrack', () {
    test('a playing or buffering track is left alone by an upcoming-only rebuild', () {
      for (final s in [BackendProcessingState.ready, BackendProcessingState.buffering]) {
        expect(AudioPlayerHandler.protectsCurrentTrack(upcomingOnly: true, state: s, playing: true), isTrue, reason: '$s');
      }
      expect(AudioPlayerHandler.protectsCurrentTrack(upcomingOnly: true, state: BackendProcessingState.completed, playing: false), isTrue);
    });

    test('a paused, idle or still-loading current track is rebuilt too (its URL may be the stale one)', () {
      // A queue restored at launch sits ready-but-paused on the parent's
      // proxy URL while the peer's own tunnel arrives; the reload keeps the
      // spot and stays paused.
      expect(AudioPlayerHandler.protectsCurrentTrack(upcomingOnly: true, state: BackendProcessingState.ready, playing: false), isFalse);
      for (final s in [BackendProcessingState.idle, BackendProcessingState.loading]) {
        expect(AudioPlayerHandler.protectsCurrentTrack(upcomingOnly: true, state: s, playing: true), isFalse, reason: '$s');
      }
    });

    test('a full rebuild never protects', () {
      for (final s in BackendProcessingState.values) {
        expect(AudioPlayerHandler.protectsCurrentTrack(upcomingOnly: false, state: s, playing: true), isFalse);
      }
    });
  });

  group('AudioPlayerHandler.hasLocalCopy', () {
    test('true only while the downloaded file is actually on disk', () async {
      final dir = await Directory.systemTemp.createTemp('mstream-copy');
      final f = File('${dir.path}/track.mp3')..writeAsStringSync('x');
      MediaItem item(String? lp) => MediaItem(id: 'http://127.0.0.1:1/media/a.mp3', title: 'a', extras: {'path': '/a.mp3', 'localPath': lp});
      expect(AudioPlayerHandler.hasLocalCopy(item(f.path)), isTrue);
      f.deleteSync();
      expect(AudioPlayerHandler.hasLocalCopy(item(f.path)), isFalse, reason: 'a vanished copy is not a copy');
      expect(AudioPlayerHandler.hasLocalCopy(item(null)), isFalse);
      expect(AudioPlayerHandler.hasLocalCopy(MediaItem(id: 'x', title: 'x')), isFalse);
      dir.deleteSync(recursive: true);
    });
  });
}
