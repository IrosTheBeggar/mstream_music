// PreviewPlayer.resumesSong: whether the song a preview clip paused comes
// back when the clip's flow ends. Only when nobody touched the song since
// (same transport number, track and cast target, not already playing), and
// only for the ends that leave the user listening in the app.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/cast_target.dart';
import 'package:mstream_music/media/preview_player.dart';

void main() {
  const SongHold held =
      (key: 'home\u0000/Music/Tidewater.mp3', epoch: 7, target: 'tv-1');

  bool resumes(
    PreviewEnd reason, {
    int epochNow = 7,
    String? keyNow = 'home\u0000/Music/Tidewater.mp3',
    String targetNow = 'tv-1',
    bool songPlaying = false,
    bool casting = false,
  }) =>
      PreviewPlayer.resumesSong(
          reason: reason,
          held: held,
          epochNow: epochNow,
          keyNow: keyNow,
          targetNow: targetNow,
          songPlaying: songPlaying,
          casting: casting);

  group('PreviewPlayer.resumesSong, nobody touched the song', () {
    test('the ends that leave the user here resume it', () {
      for (final r in [
        PreviewEnd.completed,
        PreviewEnd.stopped,
        PreviewEnd.sheetClosed,
        PreviewEnd.backgrounded,
        PreviewEnd.failed,
      ]) {
        expect(resumes(r), isTrue, reason: r.name);
        expect(resumes(r, casting: true), isTrue, reason: '${r.name} cast');
      }
    });

    test('a store link, a call, or the song itself moving never does', () {
      for (final r in [
        PreviewEnd.leftApp,
        PreviewEnd.interrupted,
        PreviewEnd.songStarted,
        PreviewEnd.songTouched,
      ]) {
        expect(resumes(r), isFalse, reason: r.name);
        expect(resumes(r, casting: true), isFalse, reason: '${r.name} cast');
      }
    });

    // The handler's own becoming-noisy rule: the phone's headphones coming
    // out says nothing about a TV that is playing the song.
    test('the output dropping resumes a cast only', () {
      expect(resumes(PreviewEnd.outputLost), isFalse);
      expect(resumes(PreviewEnd.outputLost, casting: true), isTrue);
    });

    test('every reason is decided', () {
      expect(PreviewEnd.values, hasLength(10));
      for (final r in PreviewEnd.values) {
        expect(() => resumes(r), returnsNormally);
      }
    });
  });

  group('PreviewPlayer.resumesSong, the song was touched', () {
    test('already playing again: never started twice', () {
      for (final r in PreviewEnd.values) {
        expect(resumes(r, songPlaying: true, casting: true), isFalse,
            reason: r.name);
      }
    });

    test('any transport command since the hold: the sleep timer wins', () {
      expect(resumes(PreviewEnd.completed, epochNow: 8), isFalse);
      expect(resumes(PreviewEnd.sheetClosed, epochNow: 12), isFalse);
    });

    test('a different track is current', () {
      expect(resumes(PreviewEnd.completed, keyNow: 'home\u0000/Other.mp3'),
          isFalse);
      expect(resumes(PreviewEnd.completed, keyNow: null), isFalse);
    });

    test('the cast target changed or the renderer was lost', () {
      expect(resumes(PreviewEnd.completed, targetNow: CastTarget.localId),
          isFalse);
      expect(resumes(PreviewEnd.outputLost, targetNow: 'tv-2', casting: true),
          isFalse);
    });
  });
}
