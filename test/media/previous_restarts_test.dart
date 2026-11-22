import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/audio_stuff.dart';

void main() {
  group('AudioPlayerHandler.previousRestarts', () {
    final now = DateTime(2026, 11, 22, 12);
    bool restarts(Duration position, {Duration? sinceRestart}) =>
        AudioPlayerHandler.previousRestarts(
            position: position,
            now: now,
            restartedAt: sinceRestart == null ? null : now.subtract(sinceRestart));

    test('past 3 s into a song → starts it over', () {
      expect(restarts(const Duration(milliseconds: 3001)), isTrue);
      expect(restarts(const Duration(seconds: 40)), isTrue);
      expect(restarts(const Duration(minutes: 7)), isTrue);
    });

    // Media3's rule: at or under the window, Previous goes back a song.
    test('within the first 3 s → the song before', () {
      expect(restarts(Duration.zero), isFalse);
      expect(restarts(const Duration(seconds: 2)), isFalse);
      expect(restarts(const Duration(seconds: 3)), isFalse);
    });

    // A cast renderer reports the restart's new position only after the
    // seek's round trip (DLNA's poll can even bring the old one back), so
    // a quick second press must not read the old spot and restart again.
    test('pressed again right after a restart → the song before, whatever '
        'the position reads', () {
      expect(
          restarts(const Duration(minutes: 2),
              sinceRestart: const Duration(milliseconds: 300)),
          isFalse);
      expect(
          restarts(const Duration(minutes: 2),
              sinceRestart: const Duration(milliseconds: 2999)),
          isFalse);
    });

    // Once the window has passed the song has played past 3 s again (or sat
    // paused at the top, which the position rule already sends back).
    test('a restart longer ago than the window → the position decides', () {
      expect(
          restarts(const Duration(seconds: 5),
              sinceRestart: const Duration(seconds: 5)),
          isTrue);
      expect(
          restarts(Duration.zero, sinceRestart: const Duration(seconds: 10)),
          isFalse);
    });
  });
}
