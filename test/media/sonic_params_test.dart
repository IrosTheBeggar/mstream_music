import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/audio_stuff.dart';
import 'package:mstream_music/singletons/auto_dj_manager.dart';

// The pure helpers behind Auto DJ's sonic-similarity mode: the rolling
// anchor ring buffer and the `similarTo`/`minSimilarity` fields it turns
// into for the random-songs body (mirrors webapp/alpha/auto-dj.js
// pushSonicHistory / buildSonicParams); and, for a session across several
// servers, which playing track anchors it and what locked mode pins.

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

    test('locked mode returns the pin, ignoring history / seed / current',
        () {
      final p = AudioPlayerHandler.sonicParams(
        enabled: true,
        mode: SonicAnchorMode.locked,
        lockedAnchor: '/music/pin.mp3', // normalized like every seed
        history: const ['music/pick.mp3'],
        seedPath: 'music/seed.mp3',
        currentPath: '/music/current.mp3',
        minSimilarity: 0.5,
      );
      expect(p, {
        'similarTo': ['music/pin.mp3'],
        'minSimilarity': 0.5,
      });
    });

    test('locked mode without a pin sends no sonic constraint', () {
      // The caller pins lazily; until it resolves the pick stays plain
      // random (and the next call pins to it via the playing track).
      expect(
        AudioPlayerHandler.sonicParams(
          enabled: true,
          mode: SonicAnchorMode.locked,
          lockedAnchor: null,
          history: const ['music/pick.mp3'],
          seedPath: 'music/seed.mp3',
          currentPath: '/music/current.mp3',
          minSimilarity: 0.5,
        ),
        isNull,
      );
    });

    test('rolling mode ignores a stale locked pin', () {
      final p = AudioPlayerHandler.sonicParams(
        enabled: true,
        // mode defaults to rolling.
        lockedAnchor: 'music/stale-pin.mp3',
        history: const ['music/pick.mp3'],
        currentPath: '/music/current.mp3',
        minSimilarity: 0.5,
      );
      expect(p?['similarTo'], ['music/pick.mp3']);
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

  // A cross-server session records which server each history path came
  // from; the single-server body may only carry the DJ server's own (any
  // other path draws that server's uniform 404 — "Track not found").
  group('AudioPlayerHandler.historyOwnedBy', () {
    test('keeps the DJ server\'s paths; a path with no owner recorded is its own',
        () {
      final owners = {
        'music/a.mp3': 'home',
        'nas/b.mp3': 'nas',
        'nas/c.mp3': 'nas',
      };
      expect(
        AudioPlayerHandler.historyOwnedBy(
            const ['music/a.mp3', 'nas/b.mp3', 'music/old.mp3', 'nas/c.mp3'],
            owners,
            'home'),
        ['music/a.mp3', 'music/old.mp3'],
      );
    });

    test('a history that lives entirely elsewhere yields nothing, and '
        'sonicParams then falls back to the seed, else the playing track', () {
      final owners = {'nas/b.mp3': 'nas', 'nas/c.mp3': 'nas'};
      final local = AudioPlayerHandler.historyOwnedBy(
          const ['nas/b.mp3', 'nas/c.mp3'], owners, 'home');
      expect(local, isEmpty);
      final withSeed = AudioPlayerHandler.sonicParams(
        enabled: true,
        history: local,
        seedPath: 'music/seed.mp3',
        currentPath: 'music/cur.mp3',
        minSimilarity: 0.5,
      );
      expect(withSeed?['similarTo'], ['music/seed.mp3']);
      final noSeed = AudioPlayerHandler.sonicParams(
        enabled: true,
        history: local,
        currentPath: '/music/cur.mp3',
        minSimilarity: 0.5,
      );
      expect(noSeed?['similarTo'], ['music/cur.mp3']);
      expect(
        AudioPlayerHandler.sonicParams(
          enabled: true,
          history: local,
          minSimilarity: 0.5,
        ),
        isNull,
        reason: 'nothing this server holds: no sonic params, not a foreign path',
      );
    });
  });

  // A session across several servers anchors on the playing track from any
  // of its servers — its sound is read from the server that holds it — so
  // the first pick follows what was playing, not a random track from the
  // DJ's own server.
  group('AudioPlayerHandler.fanOutCurrentSeed', () {
    bool session(String s) => {'home', 'office'}.contains(s);

    test('a track on any of the session\'s servers, normalized', () {
      expect(
          AudioPlayerHandler.fanOutCurrentSeed(
              path: '/music/a.mp3', server: 'office', inSession: session),
          (path: 'music/a.mp3', server: 'office'));
      expect(
          AudioPlayerHandler.fanOutCurrentSeed(
              path: 'music/a.mp3', server: 'home', inSession: session),
          (path: 'music/a.mp3', server: 'home'));
    });

    test('a track from a server outside the session anchors nothing', () {
      expect(
          AudioPlayerHandler.fanOutCurrentSeed(
              path: '/music/a.mp3', server: 'lab', inSession: session),
          isNull);
    });

    test('no server behind it (a local file), or no path: nothing', () {
      expect(
          AudioPlayerHandler.fanOutCurrentSeed(
              path: '/music/a.mp3', server: null, inSession: session),
          isNull);
      expect(
          AudioPlayerHandler.fanOutCurrentSeed(
              path: '/music/a.mp3', server: 42, inSession: session),
          isNull);
      expect(
          AudioPlayerHandler.fanOutCurrentSeed(
              path: '/', server: 'home', inSession: session),
          isNull);
      expect(
          AudioPlayerHandler.fanOutCurrentSeed(
              path: null, server: 'home', inSession: session),
          isNull);
    });
  });

  group('AudioPlayerHandler.inFanOut', () {
    test('the chosen servers, and always the DJ\'s own', () {
      bool inIt(String s) =>
          AudioPlayerHandler.inFanOut(s, all: false, chosen: ['a', 'b'], dj: 'c');
      expect(inIt('a'), isTrue);
      expect(inIt('b'), isTrue);
      expect(inIt('c'), isTrue, reason: "the DJ's own");
      expect(inIt('d'), isFalse);
    });

    test('All servers takes in every one', () {
      expect(
          AudioPlayerHandler.inFanOut('d',
              all: true, chosen: const [], dj: null),
          isTrue);
    });
  });

  group('AudioPlayerHandler.sonicPin', () {
    const elsewhere = (path: 'music/b.mp3', server: 'office');

    test('the DJ server\'s own anchor first, normalized — either route '
        'carries it', () {
      expect(
          AudioPlayerHandler.sonicPin(
              own: '/music/a.mp3', dj: 'home', elsewhere: elsewhere),
          (path: 'music/a.mp3', server: 'home'));
    });

    test('else the playing track on another of the session\'s servers', () {
      expect(
          AudioPlayerHandler.sonicPin(
              own: null, dj: 'home', elsewhere: elsewhere),
          elsewhere);
      expect(
          AudioPlayerHandler.sonicPin(own: '/', dj: 'home', elsewhere: elsewhere),
          elsewhere,
          reason: 'an empty path is no anchor');
    });

    test('nothing to pin: null, and the pick stays plain random', () {
      expect(AudioPlayerHandler.sonicPin(own: null, dj: 'home'), isNull);
    });
  });
}
