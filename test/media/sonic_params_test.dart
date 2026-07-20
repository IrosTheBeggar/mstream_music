import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/audio_stuff.dart';

// The pure helpers behind Auto DJ's sonic-similarity mode: the rolling
// anchor ring buffer and the `similarTo`/`minSimilarity` fields it turns
// into for the random-songs body (mirrors webapp/alpha/auto-dj.js
// pushSonicHistory / buildSonicParams).

void main() {
  group('AudioPlayerHandler.pushSonicHistory', () {
    test('appends normalized paths, most recent last', () {
      var h = AudioPlayerHandler.pushSonicHistory(const [], '/music/a.mp3');
      h = AudioPlayerHandler.pushSonicHistory(h, 'music/b.mp3');
      expect(h, ['music/a.mp3', 'music/b.mp3']);
    });

    test('a re-pick moves to most-recent instead of duplicating', () {
      var h = const ['music/a.mp3', 'music/b.mp3', 'music/c.mp3'];
      h = AudioPlayerHandler.pushSonicHistory(h, '/music/a.mp3');
      // No duplicate — a doubled path would double-weight the server's
      // session centroid.
      expect(h, ['music/b.mp3', 'music/c.mp3', 'music/a.mp3']);
    });

    test('caps at the limit, evicting oldest first', () {
      var h = const <String>[];
      for (final p in ['a', 'b', 'c', 'd', 'e', 'f']) {
        h = AudioPlayerHandler.pushSonicHistory(h, 'music/$p.mp3');
      }
      expect(h, [
        'music/b.mp3',
        'music/c.mp3',
        'music/d.mp3',
        'music/e.mp3',
        'music/f.mp3',
      ]);
    });

    test('ignores null and empty paths', () {
      const h = ['music/a.mp3'];
      expect(AudioPlayerHandler.pushSonicHistory(h, null), same(h));
      expect(AudioPlayerHandler.pushSonicHistory(h, '/'), same(h));
    });
  });

  group('AudioPlayerHandler.sonicParams', () {
    test('null when the mode is off, even with anchors available', () {
      expect(
        AudioPlayerHandler.sonicParams(
          enabled: false,
          history: const ['music/a.mp3'],
          currentPath: '/music/b.mp3',
          minSimilarity: 0.55,
        ),
        isNull,
      );
    });

    test('history wins over the current track (rolling session centroid)',
        () {
      final p = AudioPlayerHandler.sonicParams(
        enabled: true,
        history: const ['music/a.mp3', 'music/b.mp3'],
        currentPath: '/music/current.mp3',
        minSimilarity: 0.6,
      );
      expect(p, {
        'similarTo': ['music/a.mp3', 'music/b.mp3'],
        'minSimilarity': 0.6,
      });
    });

    test('falls back to the playing track for the first pick, normalized',
        () {
      final p = AudioPlayerHandler.sonicParams(
        enabled: true,
        history: const [],
        currentPath: '/music/current.mp3',
        minSimilarity: 0.55,
      );
      expect(p, {
        'similarTo': ['music/current.mp3'],
        'minSimilarity': 0.55,
      });
    });

    test('explicit seed beats the playing track, loses to history', () {
      // First pick of a session: the user-picked seed defines the vibe,
      // not whatever happens to be playing. Normalized like every seed.
      final first = AudioPlayerHandler.sonicParams(
        enabled: true,
        history: const [],
        seedPath: '/music/seed.mp3',
        currentPath: '/music/current.mp3',
        minSimilarity: 0.55,
      );
      expect(first?['similarTo'], ['music/seed.mp3']);

      // Once the session has picks, the rolling centroid takes over.
      final later = AudioPlayerHandler.sonicParams(
        enabled: true,
        history: const ['music/pick1.mp3'],
        seedPath: '/music/seed.mp3',
        currentPath: '/music/current.mp3',
        minSimilarity: 0.55,
      );
      expect(later?['similarTo'], ['music/pick1.mp3']);
    });

    test('explicit seed alone can start an empty-queue session', () {
      final p = AudioPlayerHandler.sonicParams(
        enabled: true,
        history: const [],
        seedPath: 'music/seed.mp3',
        currentPath: null,
        minSimilarity: 0.4,
      );
      expect(p, {
        'similarTo': ['music/seed.mp3'],
        'minSimilarity': 0.4,
      });
    });

    test('null on a cold start with no anchor at all', () {
      expect(
        AudioPlayerHandler.sonicParams(
          enabled: true,
          history: const [],
          currentPath: null,
          minSimilarity: 0.55,
        ),
        isNull,
      );
    });

    test('returned similarTo is a copy — later history pushes cannot mutate '
        'an in-flight request body', () {
      final history = ['music/a.mp3'];
      final p = AudioPlayerHandler.sonicParams(
        enabled: true,
        history: history,
        currentPath: null,
        minSimilarity: 0.55,
      )!;
      history.add('music/b.mp3');
      expect(p['similarTo'], ['music/a.mp3']);
    });
  });
}
