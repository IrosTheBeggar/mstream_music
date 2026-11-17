import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/audio_stuff.dart';
import 'package:mstream_music/objects/play_event.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/auto_dj_manager.dart';
import 'package:mstream_music/util/auto_dj_seeds.dart';
import 'package:mstream_music/util/auto_dj_wire.dart';

// The pure helpers behind Auto DJ's sonic-similarity mode: the
// `similarTo`/`minSimilarity` fields a single-server random-songs body gets
// from the session's More like rows (mirrors webapp/alpha/auto-dj.js
// buildSonicParams, with Drift's fallback to the explicit seed or the
// playing track); the seeds a session across several servers averages, each
// with its server; which playing track anchors such a session; and the
// anchor a Stay close lane with no row admits.

void main() {
  final t0 = DateTime.utc(2026, 11, 17, 12);

  AutoDjSeed row(String path, {String server = 'home'}) => AutoDjSeed(
      song: TrackFacts(server: server, path: path, title: path),
      origin: SeedOrigin.pick,
      addedAt: t0);

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

    test('the rows win over the current track (the session centroid)', () {
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

    test('Drift with no row falls back to the playing track, normalized', () {
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

    test('explicit seed beats the playing track, loses to the rows', () {
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

      // Once the session has rows, they take over.
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

    test('Stay close sends its rows, not the seed or the playing track', () {
      final p = AudioPlayerHandler.sonicParams(
        enabled: true,
        mode: SonicAnchorMode.locked,
        history: const ['/music/anchor.mp3', 'music/pick.mp3'],
        seedPath: 'music/seed.mp3',
        currentPath: '/music/current.mp3',
        minSimilarity: 0.5,
      );
      expect(p, {
        'similarTo': ['music/anchor.mp3', 'music/pick.mp3'],
        'minSimilarity': 0.5,
      });
    });

    test('Stay close with no row sends no sonic constraint: its anchor is a '
        'row, admitted before this is built', () {
      expect(
        AudioPlayerHandler.sonicParams(
          enabled: true,
          mode: SonicAnchorMode.locked,
          history: const [],
          seedPath: 'music/seed.mp3',
          currentPath: '/music/current.mp3',
          minSimilarity: 0.5,
        ),
        isNull,
      );
    });

    test('at most eight rows, the newest kept, each normalized', () {
      final p = AudioPlayerHandler.sonicParams(
        enabled: true,
        history: [for (var i = 0; i < 10; i++) '/music/p$i.mp3'],
        minSimilarity: 0.5,
      );
      expect(p?['similarTo'],
          [for (var i = 2; i < 10; i++) 'music/p$i.mp3']);
    });

    test('returned similarTo is a copy — later edits to the rows cannot '
        'mutate an in-flight request body', () {
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

  // The single-server body may carry only the DJ server's own rows (any
  // other path draws that server's uniform 404 — "Track not found"), so it
  // passes the rows through usableSeeds with that test first.
  group('the single-server rows', () {
    test('only the DJ server\'s rows go in the body', () {
      final rows = [
        row('music/a.mp3'),
        row('nas/b.mp3', server: 'nas'),
        row('/music/c.mp3'),
      ];
      final here = usableSeeds(rows, (s) => s.server == 'home');
      final p = AudioPlayerHandler.sonicParams(
        enabled: true,
        history: [for (final s in here) s.path],
        currentPath: '/music/cur.mp3',
        minSimilarity: 0.5,
      );
      expect(p?['similarTo'], ['music/a.mp3', 'music/c.mp3']);
    });

    test('Drift whose rows are all elsewhere filters to nothing, and falls '
        'back to the seed, else the playing track', () {
      final rows = [
        row('nas/b.mp3', server: 'nas'),
        row('nas/c.mp3', server: 'nas'),
      ];
      final here = [
        for (final s in usableSeeds(rows, (s) => s.server == 'home')) s.path,
      ];
      expect(here, isEmpty);
      final withSeed = AudioPlayerHandler.sonicParams(
        enabled: true,
        history: here,
        seedPath: 'music/seed.mp3',
        currentPath: 'music/cur.mp3',
        minSimilarity: 0.5,
      );
      expect(withSeed?['similarTo'], ['music/seed.mp3']);
      final noSeed = AudioPlayerHandler.sonicParams(
        enabled: true,
        history: here,
        currentPath: '/music/cur.mp3',
        minSimilarity: 0.5,
      );
      expect(noSeed?['similarTo'], ['music/cur.mp3']);
      expect(
        AudioPlayerHandler.sonicParams(
          enabled: true,
          history: here,
          minSimilarity: 0.5,
        ),
        isNull,
        reason: 'nothing this server holds: no sonic params, not a foreign path',
      );
    });

    test('Stay close whose rows are all elsewhere stays plain random', () {
      final rows = [row('nas/b.mp3', server: 'nas')];
      final here = usableSeeds(rows, (s) => s.server == 'home');
      expect(
        AudioPlayerHandler.sonicParams(
          enabled: true,
          mode: SonicAnchorMode.locked,
          history: [for (final s in here) s.path],
          currentPath: '/music/cur.mp3',
          minSimilarity: 0.5,
        ),
        isNull,
      );
    });

    // Across several servers, frozen rows that only the pick across them
    // can carry, on a server that did not answer this time: that pick fell
    // through to this body, which anchors on the playing track for once, in
    // Drift's mode, rather than going plain random until the server is back.
    test('Stay close across servers whose servers did not answer falls back '
        'for the pick', () {
      final rows = [row('nas/b.mp3', server: 'nas')];
      final here = usableSeeds(rows, (s) => s.server == 'home');
      final across = rows.any((s) => s.server == 'nas');
      final stranded = stayCloseFallsBack(
          multiServer: true,
          locked: true,
          anyHere: here.isNotEmpty,
          anyAcross: across);
      expect(stranded, isTrue);
      final p = AudioPlayerHandler.sonicParams(
        enabled: true,
        mode: stranded ? SonicAnchorMode.rolling : SonicAnchorMode.locked,
        history: [for (final s in here) s.path],
        currentPath: '/music/cur.mp3',
        minSimilarity: 0.5,
      );
      expect(p?['similarTo'], ['music/cur.mp3']);
      // A frozen row of the DJ's own anchors the pick as it always did.
      final own = usableSeeds([row('music/a.mp3'), ...rows],
          (s) => s.server == 'home');
      expect(
          stayCloseFallsBack(
              multiServer: true,
              locked: true,
              anyHere: own.isNotEmpty,
              anyAcross: true),
          isFalse);
    });
  });

  // A body refused over a seed the server can't use (not analysed yet, gone)
  // heals: the row at fault leaves, and the pick goes again with what is
  // left, unless that is the very seeds just refused.
  group('the heal of a refused single-server body', () {
    TrackFacts track(String path) =>
        TrackFacts(server: 'home', path: path, title: path);
    // The song playing joined More like at the lane's first pick (Drift's
    // blend); the body carries the lane's rows of the DJ's own server, and
    // Drift falls back to that same song when none is left.
    Map<String, dynamic>? body(AutoDjSeeds s) => AudioPlayerHandler.sonicParams(
          enabled: true,
          history: [
            for (final r in usableSeeds(s.moreLike, (r) => r.server == 'home'))
              r.path,
          ],
          currentPath: '/music/new.mp3',
          minSimilarity: 0.6,
        );
    final blend = seedKey('home', '/music/new.mp3');

    test('Drift, the blend the lane\'s one row: the fallback is that same '
        'song, so the refusal stands and no request goes for it', () {
      final lane = AutoDjSeeds.empty.pushPick(track('/music/new.mp3'),
          origin: SeedOrigin.opener, now: t0);
      final refused = body(lane);
      expect(refused?['similarTo'], ['music/new.mp3']);
      // One row sent is the one at fault: it goes.
      final healed = lane.withoutKeys(lane.culprits({blend}).drop);
      expect(healed.moreLike, isEmpty);
      final next = body(healed);
      expect(next?['similarTo'], ['music/new.mp3'],
          reason: 'Drift falls back to the song playing, the row just gone');
      expect(sonicFieldsDiffer(refused, next), isFalse);
    });

    test('Drift, a pin beside the blend, no probe can tell: the blend goes '
        'and the pin alone is a new body', () {
      final lane = AutoDjSeeds.empty
          .addManual(SeedList.moreLike, track('music/pin.mp3'), now: t0)
          .pushPick(track('/music/new.mp3'),
              origin: SeedOrigin.opener, now: t0);
      final sent = usableSeeds(lane.moreLike, (r) => r.server == 'home');
      final refused = body(lane);
      expect(refused?['similarTo'], ['music/pin.mp3', 'music/new.mp3']);
      final culprit = blendCulprit(healed: false, blend: blend, sent: sent);
      expect(culprit, blend);
      final next = body(lane.withoutKeys(lane.culprits({culprit!}).drop));
      expect(next?['similarTo'], ['music/pin.mp3'],
          reason: 'the body the lane sent before the blend');
      expect(sonicFieldsDiffer(refused, next), isTrue);
    });
  });

  // A session across several servers averages its seeds' vectors, each read
  // from the server holding it, so every seed travels with its server.
  group('AudioPlayerHandler.fanOutSeeds', () {
    const rows = [
      (server: 'home', path: 'music/a.mp3'),
      (server: 'nas', path: 'nas/b.mp3'),
    ];

    test('the rows first, each with its server', () {
      expect(
          AudioPlayerHandler.fanOutSeeds(
              enabled: true,
              rows: rows,
              dj: 'home',
              seedPath: 'music/seed.mp3',
              current: (server: 'office', path: '/x/cur.mp3')),
          rows);
    });

    test('Drift with no row: the explicit seed on the DJ\'s server, else the '
        'playing track on its own server, normalized', () {
      expect(
          AudioPlayerHandler.fanOutSeeds(
              enabled: true,
              rows: const [],
              dj: 'home',
              seedPath: '/music/seed.mp3',
              current: (server: 'office', path: '/x/cur.mp3')),
          [(server: 'home', path: 'music/seed.mp3')]);
      expect(
          AudioPlayerHandler.fanOutSeeds(
              enabled: true,
              rows: const [],
              dj: 'home',
              current: (server: 'office', path: '/x/cur.mp3')),
          [(server: 'office', path: 'x/cur.mp3')]);
    });

    test('Stay close has no fallback', () {
      expect(
          AudioPlayerHandler.fanOutSeeds(
              enabled: true,
              mode: SonicAnchorMode.locked,
              rows: const [],
              dj: 'home',
              seedPath: 'music/seed.mp3',
              current: (server: 'office', path: 'x/cur.mp3')),
          isEmpty);
      expect(
          AudioPlayerHandler.fanOutSeeds(
              enabled: true,
              mode: SonicAnchorMode.locked,
              rows: rows,
              dj: 'home'),
          rows);
    });

    test('nothing when sonic is off or nothing anchors the pick', () {
      expect(
          AudioPlayerHandler.fanOutSeeds(
              enabled: false, rows: rows, dj: 'home'),
          isEmpty);
      expect(
          AudioPlayerHandler.fanOutSeeds(
              enabled: true, rows: const [], dj: 'home'),
          isEmpty);
      expect(
          AudioPlayerHandler.fanOutSeeds(
              enabled: true,
              rows: const [],
              dj: 'home',
              current: (server: '', path: '/sdcard/a.mp3')),
          isEmpty,
          reason: 'a local file has no server to read it');
    });

    test('at most eight rows, the newest kept; a row with no path is no seed',
        () {
      final many = [
        for (var i = 0; i < 10; i++) (server: 'home', path: 'p$i'),
        (server: 'home', path: '/'),
      ];
      expect(
          AudioPlayerHandler.fanOutSeeds(
                  enabled: true, rows: many, dj: 'home')
              .map((s) => s.path),
          [for (var i = 2; i < 10; i++) 'p$i']);
    });

    test('Drift whose only row is on a server that can\'t hand out vectors '
        'follows the playing track', () {
      final nas = Server('https://nas.example.com', null, null, 'JWT', 'nas')
        ..discoveryEnabled = false;
      final servers = {'nas': nas};
      final across = usableSeeds(
          [row('nas/b.mp3', server: 'nas')],
          (s) => seedCarriedAcross(s,
              dj: 'home',
              owner: (n) => servers[n],
              inSession: (_) => true,
              canSeed: (o) => AudioPlayerHandler.canJoinMultiServer(o, {})));
      expect(across, isEmpty);
      expect(
          AudioPlayerHandler.fanOutSeeds(
              enabled: true,
              rows: across,
              dj: 'home',
              current: (server: 'office', path: '/x/cur.mp3')),
          [(server: 'office', path: 'x/cur.mp3')]);
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

  // The anchor a Stay close lane with no row its request can carry admits
  // (AutoDjSeeds.admitAnchor): the same inputs the old lazy pin took.
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

    test('nothing to anchor on: null, and the pick stays plain random', () {
      expect(AudioPlayerHandler.sonicPin(own: null, dj: 'home'), isNull);
    });
  });
}
