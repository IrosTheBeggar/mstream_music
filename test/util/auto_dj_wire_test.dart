import 'dart:convert';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/play_event.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/util/auto_dj_seeds.dart';
import 'package:mstream_music/util/auto_dj_wire.dart';
import 'package:mstream_music/util/seed_vector.dart';

// How the Auto DJ's seeds go out on the wire: the positive seeds a request
// can carry and which rows a pick across several servers counts as such,
// the Less like keys of a random-songs body (mStream #1108), the servers
// they go to and how a skip's change to them is told, the repeats a pick
// across several servers passes over, and what the embeddings route says
// about each seed.
void main() {
  final t0 = DateTime.utc(2026, 11, 17, 12);

  TrackFacts song(String path, {String server = 'home'}) =>
      TrackFacts(server: server, path: path, title: path);

  AutoDjSeed row(String path,
          {String server = 'home', SeedOrigin origin = SeedOrigin.pick}) =>
      AutoDjSeed(
          song: song(path, server: server), origin: origin, addedAt: t0);

  // A queue row as the handler builds it: a DJ pick's path has no leading
  // slash, a browsed row's does.
  MediaItem item(String path, {String? server = 'home', bool dj = false}) =>
      MediaItem(id: 'id:$path', title: path, extras: {
        'server': ?server,
        'path': path,
        if (dj) 'djPick': true,
      });

  group('usableSeeds', () {
    test('the rows the test accepts, each with the server holding it', () {
      final rows = [
        row('/Music/a.flac'),
        row('nas/b.mp3', server: 'nas'),
        row('Music/c.flac'),
      ];
      expect(usableSeeds(rows, (s) => s.server == 'home'), [
        (server: 'home', path: 'Music/a.flac'),
        (server: 'home', path: 'Music/c.flac'),
      ]);
      expect(usableSeeds(rows, (_) => true).map((s) => s.server),
          ['home', 'nas', 'home']);
    });

    test('rows that are all elsewhere filter to nothing', () {
      final rows = [row('nas/b.mp3', server: 'nas')];
      expect(usableSeeds(rows, (s) => s.server == 'home'), isEmpty);
    });

    test('at most eight, the newest kept, oldest first', () {
      final rows = [for (var i = 0; i < 10; i++) row('p$i')];
      expect(usableSeeds(rows, (_) => true).map((s) => s.path),
          [for (var i = 2; i < 10; i++) 'p$i']);
    });

    test('past eight a pin never makes way for Stay close\'s one song', () {
      // Eight pins a server refused, the one song taken in beside them, then
      // the pins usable again (a new lane, the scan done): the user's eight
      // go out and the stand-in waits.
      var lane = AutoDjSeeds.fresh(frozen: true, now: t0);
      for (var i = 0; i < AutoDjSeeds.maxPerList; i++) {
        lane = lane.addManual(SeedList.moreLike, song('Music/m$i.flac'),
            now: t0);
      }
      lane = lane.admitAnchor(song('Music/a.flac'), usable: (_) => false,
          now: t0);
      expect(lane.moreLike, hasLength(AutoDjSeeds.maxPerList + 1));
      expect(usableSeeds(lane.moreLike, (_) => true).map((s) => s.path),
          [for (var i = 0; i < AutoDjSeeds.maxPerList; i++) 'Music/m$i.flac']);
      // While the pins can't go, the one song is all the request carries.
      expect(
          usableSeeds(lane.moreLike, (s) => s.origin == SeedOrigin.anchor)
              .map((s) => s.path),
          ['Music/a.flac']);
    });

    test('a row with no server or no path never goes out', () {
      final rows = [
        AutoDjSeed(
            song: const TrackFacts(server: '', path: '/sdcard/a.mp3'),
            origin: SeedOrigin.pick,
            addedAt: t0),
        row('/'),
      ];
      expect(usableSeeds(rows, (_) => true), isEmpty);
    });
  });

  group('lessLikeParams', () {
    test('own paths as lessLike, normalised; nothing else', () {
      expect(lessLikeParams(paths: ['/Music/a.flac', 'Music/b.flac']), {
        'lessLike': ['Music/a.flac', 'Music/b.flac'],
      });
    });

    test('never a minSimilarity key, whatever it carries', () {
      final all = lessLikeParams(
          paths: ['a'], vectors: ['AAAA'], modelId: 'clap-v1');
      expect(all.containsKey('minSimilarity'), isFalse);
      expect(all.keys.toSet(),
          {'lessLike', 'lessLikeVectors', 'lessLikeModelId'});
      expect(all['lessLikeVectors'], ['AAAA']);
      expect(all['lessLikeModelId'], 'clap-v1');
    });

    test('empty lists are absent keys, since each array needs one item', () {
      expect(lessLikeParams(), isEmpty);
      expect(lessLikeParams(paths: const [], vectors: const []), isEmpty);
      expect(lessLikeParams(paths: ['/'], vectors: ['']), isEmpty,
          reason: 'an empty path or vector is no negative');
      expect(lessLikeParams(vectors: ['AAAA'], modelId: 'm').keys.toSet(),
          {'lessLikeVectors', 'lessLikeModelId'});
    });

    test('vectors without a model id are left out', () {
      expect(lessLikeParams(vectors: ['AAAA']), isEmpty);
      expect(lessLikeParams(vectors: ['AAAA'], modelId: ''), isEmpty);
      expect(lessLikeParams(paths: ['a'], vectors: ['AAAA']), {
        'lessLike': ['a'],
      });
    });

    test('at most eight in total, paths first, the newest of each kept', () {
      final got = lessLikeParams(
          paths: [for (var i = 0; i < 5; i++) 'p$i'],
          vectors: [for (var i = 0; i < 5; i++) 'v$i'],
          modelId: 'm');
      expect(got['lessLike'], ['p0', 'p1', 'p2', 'p3', 'p4']);
      expect(got['lessLikeVectors'], ['v2', 'v3', 'v4']);

      final paths = lessLikeParams(
          paths: [for (var i = 0; i < 10; i++) 'p$i'],
          vectors: ['v0'],
          modelId: 'm');
      expect(paths['lessLike'], [for (var i = 2; i < 10; i++) 'p$i']);
      expect(paths.containsKey('lessLikeVectors'), isFalse,
          reason: 'no room left for a vector, and no model id alone');
      expect(paths.containsKey('lessLikeModelId'), isFalse);
    });
  });

  group('fanOutRecentKeys', () {
    test('the playing row, every row after it, the More like rows and the '
        'seeds', () {
      final queue = [
        item('/Music/user-old.flac'),
        item('/Music/playing.flac'),
        item('/Music/next-user.flac'),
        item('nas/next-pick.mp3', server: 'nas', dj: true),
      ];
      final got = fanOutRecentKeys(queue, 1,
          moreLike: [row('Music/seed.flac')],
          seeds: [(server: 'lab', path: 'x/anchor.mp3')]);
      expect(got, {
        'home|Music/playing.flac',
        'home|Music/next-user.flac',
        'nas|nas/next-pick.mp3',
        'home|Music/seed.flac',
        'lab|x/anchor.mp3',
      });
      expect(got.contains('home|Music/user-old.flac'), isFalse,
          reason: 'a user row already played is fair game again');
    });

    test('the blended song the user quick-skipped stays out', () {
      final queue = [
        item('/Music/user.flac'),
        item('p0', dj: true),
      ];
      final got = fanOutRecentKeys(queue, 1,
          moreLike: const [],
          avoid: [(server: 'home', path: '/Music/user.flac')]);
      expect(got, {'home|p0', 'home|Music/user.flac'},
          reason: 'a user row behind the playing one is fair game, but not '
              'the one the lane passes over');
    });

    test('the last five DJ picks at or before the playing row', () {
      final queue = [
        for (var i = 0; i < 7; i++) item('p$i', dj: true),
        item('/Music/user.flac'),
        item('p7', dj: true),
      ];
      final got = fanOutRecentKeys(queue, 8, moreLike: const []);
      expect(got, {
        'home|p7',
        'home|p6',
        'home|p5',
        'home|p4',
        'home|p3',
      });
    });

    test('a Stay close lane: More like is only the anchor, yet the batch it '
        'just played is still guarded', () {
      // The frozen list holds one anchor; the old ring would have held the
      // picks this lane queued.
      final queue = [
        item('/Music/opener.flac'),
        item('a', dj: true),
        item('b', dj: true),
        item('c', dj: true),
        item('d', dj: true),
      ];
      final got = fanOutRecentKeys(queue, 4,
          moreLike: [row('/Music/opener.flac', origin: SeedOrigin.anchor)],
          seeds: [(server: 'home', path: 'Music/opener.flac')]);
      expect(got, {
        'home|Music/opener.flac',
        'home|a',
        'home|b',
        'home|c',
        'home|d',
      });
    });

    test('a song skipped quickly has left More like but is still guarded',
        () {
      final queue = [
        item('a', dj: true),
        item('skipped', dj: true),
        item('c', dj: true),
      ];
      final got = fanOutRecentKeys(queue, 2, moreLike: [row('a'), row('c')]);
      expect(got.contains('home|skipped'), isTrue);
    });

    test('no current row: every row counts as ahead', () {
      final queue = [item('/Music/a.flac'), item('b', dj: true)];
      expect(fanOutRecentKeys(queue, null, moreLike: const []),
          {'home|Music/a.flac', 'home|b'});
      expect(fanOutRecentKeys(queue, -1, moreLike: const []),
          {'home|Music/a.flac', 'home|b'});
      expect(fanOutRecentKeys(const [], null, moreLike: const []), isEmpty);
    });

    test('an index past the end reads as the last row', () {
      final queue = [item('a', dj: true), item('b', dj: true)];
      expect(fanOutRecentKeys(queue, 9, moreLike: const []),
          {'home|a', 'home|b'});
    });

    test('a local file (no server) or a row with no path is left out', () {
      final queue = [
        item('/sdcard/a.mp3', server: null),
        MediaItem(id: 'x', title: 'x', extras: const {'server': 'home'}),
        item('b', dj: true),
      ];
      expect(fanOutRecentKeys(queue, 2, moreLike: const []), {'home|b'});
    });
  });

  // A server as the session sees it: discovery on with its scan done unless
  // told otherwise, and the picker generation that takes negatives.
  Server server(String name,
          {bool? discoveryOn = true,
          bool? discoveryReady = true,
          int? autoDj = 1}) =>
      Server('https://$name.example.com', null, null, 'JWT', name)
        ..discoveryEnabled = discoveryOn
        ..discoveryReady = discoveryReady
        ..autoDjGeneration = autoDj;

  group('seedCarriedAcross', () {
    final home = server('home');
    final nas = server('nas', discoveryOn: false);
    final lab = server('lab');
    final servers = {for (final s in [home, nas, lab]) s.localname: s};
    // The fan-out's own test of a server, as canJoinMultiServer reads it.
    bool canSeed(Server s) =>
        s.discoveryOn == true && s.discoveryReady != false;

    bool carried(AutoDjSeed s,
            {Set<String> inSession = const {'home', 'nas', 'lab'},
            Set<String> unusable = const {}}) =>
        seedCarriedAcross(s,
            dj: 'home',
            owner: (n) => servers[n],
            inSession: inSession.contains,
            canSeed: canSeed,
            unusable: unusable);

    test('a row on a server that can hand out its vector is carried', () {
      expect(carried(row('x/a.mp3', server: 'lab')), isTrue);
    });

    test('not one on a server that never could (discovery off there)', () {
      // Before, any server of the session counted, so this row held off
      // Stay close's anchor for the whole lane.
      expect(carried(row('x/b.mp3', server: 'nas')), isFalse);
    });

    test('the DJ\'s own rows go by path, whatever the fan-out can do', () {
      expect(
          seedCarriedAcross(row('Music/a.flac'),
              dj: 'home',
              owner: (n) => servers[n],
              inSession: (_) => true,
              canSeed: (_) => false),
          isTrue);
    });

    test('never a row refused this lane, gone with its server, or outside '
        'the session', () {
      final r = row('x/a.mp3', server: 'lab');
      expect(carried(r, unusable: {r.key}), isFalse);
      expect(carried(row('x/a.mp3', server: 'gone')), isFalse);
      expect(carried(r, inSession: const {'home'}), isFalse);
    });

    test('Stay close admits the playing track when its only row is on such a '
        'server', () {
      final frozen = AutoDjSeeds.fresh(frozen: true, now: t0)
          .addManual(SeedList.moreLike, song('x/b.mp3', server: 'nas'),
              now: t0);
      final admitted = frozen.admitAnchor(song('Music/playing.flac'),
          usable: carried, now: t0);
      expect([for (final s in admitted.moreLike) '${s.server}:${s.wirePath}'],
          ['nas:x/b.mp3', 'home:Music/playing.flac']);
      expect(admitted.moreLike.last.origin, SeedOrigin.anchor);
      // The old test (any server of the session) admitted nothing.
      expect(
          frozen.admitAnchor(song('Music/playing.flac'),
              usable: (s) => servers[s.server] != null, now: t0),
          same(frozen));
      // With the row on a server that can seed, it stays the lane's anchor.
      final onLab = AutoDjSeeds.fresh(frozen: true, now: t0).addManual(
          SeedList.moreLike, song('x/a.mp3', server: 'lab'),
          now: t0);
      expect(
          onLab.admitAnchor(song('Music/playing.flac'),
              usable: carried, now: t0),
          same(onLab));
    });

    test('Drift\'s rows on such a server are no seeds of the pick', () {
      final drift = AutoDjSeeds.empty
          .pushPick(song('x/b.mp3', server: 'nas'), now: t0)
          .pushPick(song('x/a.mp3', server: 'lab'), now: t0);
      expect(usableSeeds(drift.moreLike, carried),
          [(server: 'lab', path: 'x/a.mp3')]);
    });
  });

  group('stayCloseFallsBack', () {
    test('frozen rows only a pick across the servers can carry: this pick '
        'falls back', () {
      expect(
          stayCloseFallsBack(
              multiServer: true, locked: true, anyHere: false, anyAcross: true),
          isTrue);
    });

    test('a row the single-server body carries anchors it as it is', () {
      expect(
          stayCloseFallsBack(
              multiServer: true, locked: true, anyHere: true, anyAcross: true),
          isFalse);
    });

    test('Drift falls back by itself; one server, or no row anywhere, is '
        'the admission\'s', () {
      expect(
          stayCloseFallsBack(
              multiServer: true,
              locked: false,
              anyHere: false,
              anyAcross: true),
          isFalse);
      expect(
          stayCloseFallsBack(
              multiServer: false,
              locked: true,
              anyHere: false,
              anyAcross: true),
          isFalse);
      expect(
          stayCloseFallsBack(
              multiServer: true,
              locked: true,
              anyHere: false,
              anyAcross: false),
          isFalse);
    });
  });

  group('stayCloseAdmission', () {
    test('a lane with nothing to stay close to admits its one song', () {
      final r = stayCloseAdmission(
          anchored: false, anyUsable: false, pinFound: true);
      expect(r.tryAdmit, isTrue);
      expect(r.anchored, isFalse,
          reason: 'the caller marks it once the admission took');
    });

    test('a cold start with no song to admit waits for one', () {
      final r = stayCloseAdmission(
          anchored: false, anyUsable: false, pinFound: false);
      expect(r.tryAdmit, isFalse);
      expect(r.anchored, isFalse);
    });

    test('usable carried pins anchor the lane, with or without a song', () {
      for (final pin in [true, false]) {
        final r = stayCloseAdmission(
            anchored: false, anyUsable: true, pinFound: pin);
        expect(r.tryAdmit, isFalse, reason: 'pin $pin');
        expect(r.anchored, isTrue, reason: 'pin $pin');
      }
    });

    test('once anchored, nothing is admitted, rows or none', () {
      for (final usable in [true, false]) {
        for (final pin in [true, false]) {
          final r = stayCloseAdmission(
              anchored: true, anyUsable: usable, pinFound: pin);
          expect(r.tryAdmit, isFalse, reason: 'usable $usable, pin $pin');
          expect(r.anchored, isTrue, reason: 'usable $usable, pin $pin');
        }
      }
    });

    // One Stay close pick as the handler runs it ([stayCloseAdmit]): the
    // flag follows every pick, the song goes in only when told to, and only
    // an admission that took anchors the lane.
    ({AutoDjSeeds seeds, bool anchored}) pick(
        AutoDjSeeds s, bool anchored, TrackFacts? playing,
        {bool Function(AutoDjSeed)? usable}) {
      final r = stayCloseAdmit(s,
          anchored: anchored,
          song: playing,
          usable: usable ?? (_) => true,
          now: t0);
      expect(r.admitted, !identical(r.seeds, s));
      return (seeds: r.seeds, anchored: r.anchored);
    }

    final close = AutoDjSeeds.fresh(frozen: true, now: t0);

    test('a lane admits the first song, then nothing: a removal sticks', () {
      var lane = pick(close, false, song('Music/first.flac'));
      expect([for (final s in lane.seeds.moreLike) s.wirePath],
          ['Music/first.flac']);
      expect(lane.anchored, isTrue);
      // The next picks play other songs; nothing joins.
      lane = pick(lane.seeds, lane.anchored, song('Music/second.flac'));
      expect(lane.seeds.moreLike.length, 1);
      // The user removes the row: no song comes in in its place.
      final emptied = lane.seeds
          .remove(SeedList.moreLike, seedKey('home', 'Music/first.flac'));
      lane = pick(emptied, lane.anchored, song('Music/third.flac'));
      expect(lane.seeds.moreLike, isEmpty);
      expect(lane.anchored, isTrue);
    });

    // A chosen opener comes in through Add song's path at the start
    // (addsChosenSong), pinned, never through this admission; a Random
    // opener does not come in at all.
    test('a seeded start whose carried pins are usable: the admission adds '
        'nothing', () {
      final pins = close.addManual(
          SeedList.moreLike, song('Music/pinned.flac'),
          now: t0);
      final lane = pick(pins, false, song('Music/opener.flac'));
      expect([for (final s in lane.seeds.moreLike) s.wirePath],
          ['Music/pinned.flac']);
      expect(lane.anchored, isTrue);
    });

    test('carried pins no request can carry: the lane admits one song', () {
      final pins = close.addManual(
          SeedList.moreLike, song('x/elsewhere.mp3', server: 'nas'),
          now: t0);
      final lane = pick(pins, false, song('Music/playing.flac'),
          usable: (s) => s.server == 'home');
      expect([for (final s in lane.seeds.moreLike) s.wirePath],
          ['x/elsewhere.mp3', 'Music/playing.flac']);
      expect(lane.anchored, isTrue);
    });

    test('a refused admission leaves the lane looking for its song', () {
      // The playing song is in Less like: admitAnchor takes nothing.
      final steered = close.addManual(
          SeedList.lessLike, song('Music/skip.flac'),
          now: t0);
      var lane = pick(steered, false, song('Music/skip.flac'));
      expect(lane.seeds, same(steered));
      expect(lane.anchored, isFalse);
      // The next song is fine: it comes in.
      lane = pick(lane.seeds, lane.anchored, song('Music/next.flac'));
      expect([for (final s in lane.seeds.moreLike) s.wirePath],
          ['Music/next.flac']);
      expect(lane.anchored, isTrue);
    });

    // A session across several servers, as the handler judges its rows:
    // home is the DJ; nas has discovery off (or is still scanning, or was
    // dropped this session), so it can't hand out a song's vector; lab can.
    final home = server('home');
    final nas = server('nas', discoveryOn: false);
    final lab = server('lab');
    final servers = {for (final s in [home, nas, lab]) s.localname: s};
    bool across(AutoDjSeed s, {Set<String> unusable = const {}}) =>
        seedCarriedAcross(s,
            dj: 'home',
            owner: (n) => servers[n],
            inSession: (_) => true,
            canSeed: (o) => o.discoveryOn == true && o.discoveryReady != false,
            unusable: unusable);

    test('a playing song no request can carry is no song to stay close to: '
        'the lane waits for one it can carry', () {
      final playingOnNas = song('x/nas.mp3', server: 'nas');
      var lane = pick(close, false, playingOnNas, usable: across);
      expect(lane.seeds, same(close), reason: 'the nas song stays out');
      expect(lane.anchored, isFalse, reason: 'still looking for its song');
      // The old rule (any song at all) took it in and anchored the lane on
      // a row no pick sends: every pick after it went plain random.
      final old = stayCloseAdmission(
          anchored: false, anyUsable: false, pinFound: true);
      expect(old.tryAdmit, isTrue);
      final stuck = close.admitAnchor(playingOnNas, usable: across, now: t0);
      expect(stuck.moreLike.single.server, 'nas');
      expect(usableSeeds(stuck.moreLike, across), isEmpty);
      // The DJ's own next pick plays: it is the lane's one song.
      lane = pick(lane.seeds, lane.anchored, song('Music/home.flac'),
          usable: across);
      expect([for (final s in lane.seeds.moreLike) '${s.server}:${s.wirePath}'],
          ['home:Music/home.flac']);
      expect(lane.seeds.moreLike.single.origin, SeedOrigin.anchor);
      expect(lane.anchored, isTrue);
      expect(usableSeeds(lane.seeds.moreLike, across),
          [(server: 'home', path: 'Music/home.flac')]);
      // And nothing after it.
      lane = pick(lane.seeds, lane.anchored, song('Music/next.flac'),
          usable: across);
      expect(lane.seeds.moreLike.length, 1);
    });

    test('a playing song on a server that can hand out its vector comes in',
        () {
      final lane =
          pick(close, false, song('x/lab.mp3', server: 'lab'), usable: across);
      expect([for (final s in lane.seeds.moreLike) '${s.server}:${s.wirePath}'],
          ['lab:x/lab.mp3']);
      expect(lane.anchored, isTrue);
    });

    test('a song a server refused this lane is not taken in again', () {
      final dead = song('Music/dead.flac');
      final lane = pick(close, false, dead,
          usable: (s) => across(s, unusable: {seedKey('home', dead.path)}));
      expect(lane.seeds, same(close));
      expect(lane.anchored, isFalse);
    });

    test('with no song at all, nothing is admitted and the lane waits', () {
      final r = stayCloseAdmit(close,
          anchored: false, song: null, usable: (_) => true, now: t0);
      expect(r.seeds, same(close));
      expect(r.admitted, isFalse);
      expect(r.anchored, isFalse);
    });
  });

  group('blendsOnLaneStart (Drift: the song playing joins at a new start)',
      () {
    bool blends({
      bool drift = true,
      bool laneStart = true,
      bool usable = true,
      bool inLessLike = false,
      bool alreadyMoreLike = false,
      bool isDjPick = false,
    }) =>
        blendsOnLaneStart(
            drift: drift,
            laneStart: laneStart,
            usable: usable,
            inLessLike: inLessLike,
            alreadyMoreLike: alreadyMoreLike,
            isDjPick: isDjPick);

    test('the lane\'s first pick in Drift, with a usable song playing', () {
      expect(blends(), isTrue);
    });

    test('each condition flipped on its own keeps the song out', () {
      expect(blends(drift: false), isFalse, reason: 'Stay close adds nothing');
      expect(blends(laneStart: false), isFalse,
          reason: 'only the lane\'s first pick');
      expect(blends(usable: false), isFalse,
          reason: 'a local file, or a song the route can\'t carry');
      expect(blends(inLessLike: true), isFalse,
          reason: 'never a song the user steers away from');
      expect(blends(alreadyMoreLike: true), isFalse,
          reason: 'a pin, an opener or a carried row keeps its place');
      expect(blends(isDjPick: true), isFalse,
          reason: 'this lane\'s picks join as they start playing');
    });

    test('the push itself: beside the pins, unpinned, the newest row', () {
      final pins = AutoDjSeeds.empty
          .addManual(SeedList.moreLike, song('Music/pin.flac'), now: t0);
      final lane = pins.pushPick(song('/Music/user.flac'),
          origin: SeedOrigin.opener, now: t0);
      expect([for (final s in lane.moreLike) '${s.wirePath}${s.pinned ? '*' : ''}'],
          ['Music/pin.flac*', 'Music/user.flac']);
      expect(lane.moreLike.last.origin, SeedOrigin.opener);
      expect(usableSeeds(lane.moreLike, (_) => true).map((r) => r.path),
          ['Music/pin.flac', 'Music/user.flac'],
          reason: 'the lane\'s first request carries both');
    });
  });

  group('quickSkipsBlend (a quick skip of the blended song)', () {
    final user = song('/Music/user.flac');
    final key = seedKey(user.server, user.path);

    bool skipsBlend({
      String? blended,
      bool isDjPick = false,
      bool unpinnedInMoreLike = true,
    }) =>
        quickSkipsBlend(
            key: key,
            blended: blended,
            isDjPick: isDjPick,
            unpinnedInMoreLike: unpinnedInMoreLike);

    test('the user\'s own song the lane blended in, unpinned in More like',
        () {
      expect(skipsBlend(blended: key), isTrue);
      expect(skipsBlend(blended: seedKey('home', 'Music/user.flac')), isTrue,
          reason: 'one key with or without the leading slash');
    });

    test('anything else is no skip of the blend', () {
      expect(skipsBlend(blended: null), isFalse,
          reason: 'a lane that blended nothing');
      expect(skipsBlend(blended: seedKey('home', '/Music/other.flac')),
          isFalse,
          reason: 'another song than the one blended in');
      expect(skipsBlend(blended: key, unpinnedInMoreLike: false), isFalse,
          reason: 'More like no longer holds it unpinned: removed, moved to '
              'Less like, or pinned since');
      expect(skipsBlend(blended: key, isDjPick: true), isFalse,
          reason: 'a DJ pick the start blended in (left by an earlier lane or '
              'run, or served again) keeps the DJ pick\'s rule, learning '
              'included');
    });

    test('the skip itself: out of More like, nothing learned, a pin kept',
        () {
      final pins = AutoDjSeeds.empty
          .addManual(SeedList.moreLike, song('Music/pin.flac'), now: t0);
      final lane =
          pins.pushPick(user, origin: SeedOrigin.opener, now: t0);
      final skipped = lane.quickSkip(user, learn: false, now: t0);
      expect([for (final s in skipped.moreLike) s.wirePath],
          ['Music/pin.flac'],
          reason: 'the blended song leaves; the pin stays');
      expect(skipped.lessLike, isEmpty,
          reason: 'nothing is learned from the user\'s own song');
      final pinnedSince =
          lane.setPinned(SeedList.moreLike, key, true, now: t0);
      expect(
          identical(
              pinnedSince.quickSkip(user, learn: false, now: t0), pinnedSince),
          isTrue,
          reason: 'a blended song the user pinned since stays put');
    });
  });

  group('isSkippedBlend (the picks pass over the skipped blend)', () {
    final skipped = seedKey('home', '/Music/user.flac');

    test('an answer row for that song on that server', () {
      expect(isSkippedBlend({'filepath': 'Music/user.flac'}, 'home', skipped),
          isTrue,
          reason: 'the server answers with the wire path, no leading slash');
      expect(isSkippedBlend({'filepath': '/Music/user.flac'}, 'home', skipped),
          isTrue);
    });

    test('anything else is kept', () {
      expect(isSkippedBlend({'filepath': 'Music/user.flac'}, 'home', null),
          isFalse,
          reason: 'no blend was skipped in this lane');
      expect(isSkippedBlend({'filepath': 'Music/other.flac'}, 'home', skipped),
          isFalse);
      expect(isSkippedBlend({'filepath': 'Music/user.flac'}, 'nas', skipped),
          isFalse,
          reason: 'the same path on another server is another song');
      expect(isSkippedBlend({'title': 'no path'}, 'home', skipped), isFalse);
    });
  });

  group('blendCulprit (a refused body that no probe explains)', () {
    const pinRow = (server: 'home', path: 'Music/pin.flac');
    const blendRow = (server: 'home', path: 'Music/new.flac');
    // The key the engine keeps when the blend lands: the playing row's own
    // path, which a browsed row holds with its leading slash.
    final blend = seedKey('home', '/Music/new.flac');

    // A Drift lane's first body: a pin the lane carried over, and the song
    // playing blended in beside it.
    AutoDjSeeds laneStart() => AutoDjSeeds.empty
        .addManual(SeedList.moreLike, song('Music/pin.flac'), now: t0)
        .pushPick(song('/Music/new.flac'), origin: SeedOrigin.opener, now: t0);

    test('the song the lane\'s start blended in, when the body carried it and '
        'no probe blamed a row', () {
      expect(carriesBlend(blend, [pinRow, blendRow]), isTrue);
      expect(blendCulprit(healed: false, blend: blend, sent: [pinRow, blendRow]),
          blend);
    });

    test('none when a probe found the row, a server has judged the blend, or '
        'the body did not carry it', () {
      expect(
          blendCulprit(healed: true, blend: blend, sent: [pinRow, blendRow]),
          isNull,
          reason: 'the probes found the row at fault: only it goes');
      expect(
          blendCulprit(healed: false, blend: null, sent: [pinRow, blendRow]),
          isNull,
          reason: 'no blend this lane, or a server took or refused it');
      expect(blendCulprit(healed: false, blend: blend, sent: [pinRow]), isNull,
          reason: 'a body without it goes to the usual handling');
      expect(carriesBlend(blend, const []), isFalse);
      expect(
          blendCulprit(
              healed: false,
              blend: seedKey('lab', 'Music/new.flac'),
              sent: [pinRow, blendRow]),
          isNull,
          reason: 'the same path on another server is another song');
    });

    test('Drift: the pin and the blend refused, no probe can tell: the blend '
        'leaves, and the next body is the pin alone, as before the blend', () {
      final lane = laneStart();
      final sent = usableSeeds(lane.moreLike, (_) => true);
      expect(sent.map((r) => r.path), ['Music/pin.flac', 'Music/new.flac'],
          reason: 'the refused body carried both');
      final culprit = blendCulprit(healed: false, blend: blend, sent: sent);
      expect(culprit, blend);
      final verdict = lane.culprits({culprit!});
      expect(verdict.drop, {blend}, reason: 'an engine row in Drift goes');
      expect(verdict.setAside, isEmpty);
      final next = lane.withoutKeys(verdict.drop);
      expect(usableSeeds(next.moreLike, (_) => true).map((r) => r.path),
          ['Music/pin.flac'],
          reason: 'the pin goes again on its own');
      expect(next.moreLike.single.pinned, isTrue);
    });

    test('pinned by the user since, or frozen by a switch to Stay close: set '
        'aside, still listed and out of the lane\'s requests', () {
      final pinned = laneStart().setPinned(SeedList.moreLike, blend, true,
          now: t0);
      expect(pinned.culprits({blend}).setAside, {blend});
      expect(pinned.culprits({blend}).drop, isEmpty);
      final frozen = laneStart().freeze(t0);
      expect(frozen.culprits({blend}).setAside, {blend});
      expect(frozen.culprits({blend}).drop, isEmpty);
    });
  });

  group('sonicFieldsDiffer (no request for the seeds just refused)', () {
    test('the same fields are no different body; other seeds, another match '
        'or none at all are', () {
      Map<String, dynamic> body(List<String> seeds, [double match = 0.6]) =>
          {'similarTo': seeds, 'minSimilarity': match};
      expect(sonicFieldsDiffer(body(['a']), body(['a'])), isFalse);
      expect(sonicFieldsDiffer(body(['a', 'b']), body(['a'])), isTrue);
      expect(sonicFieldsDiffer(body(['a']), body(['b'])), isTrue);
      expect(sonicFieldsDiffer(body(['a']), body(['a'], 0.5)), isTrue,
          reason: 'the match was changed while the probes were out');
      expect(sonicFieldsDiffer(body(['a']), null), isTrue,
          reason: 'Stay close with no row left sends no positive');
      expect(sonicFieldsDiffer(null, null), isFalse);
    });
  });

  group('addsChosenSong (Stay close: a chosen first song comes in pinned)',
      () {
    test('only in Stay close, for a chosen song, with room in More like', () {
      for (final stayClose in [true, false]) {
        for (final chosen in [true, false]) {
          for (final canAdd in [true, false]) {
            expect(
                addsChosenSong(
                    stayClose: stayClose, chosen: chosen, canAdd: canAdd),
                stayClose && chosen && canAdd,
                reason: 'stay close $stayClose, chosen $chosen, '
                    'canAdd $canAdd');
          }
        }
      }
    });

    test('Add song\'s path: pinned, the newest row, beside the pins', () {
      final pins = AutoDjSeeds.fresh(frozen: true, now: t0)
          .addManual(SeedList.moreLike, song('Music/pin.flac'), now: t0);
      expect(
          addsChosenSong(
              stayClose: pins.frozen,
              chosen: true,
              canAdd: pins.canAdd(SeedList.moreLike)),
          isTrue);
      final lane =
          pins.addManual(SeedList.moreLike, song('/Music/chosen.flac'), now: t0);
      expect([for (final s in lane.moreLike) '${s.wirePath}${s.pinned ? '*' : ''}'],
          ['Music/pin.flac*', 'Music/chosen.flac*']);
      expect(lane.moreLike.last.origin, SeedOrigin.manual);
      // Eight rows that all show pinned: no room, and nothing is added.
      var full = AutoDjSeeds.fresh(frozen: true, now: t0);
      for (var i = 0; i < AutoDjSeeds.maxPerList; i++) {
        full = full.addManual(SeedList.moreLike, song('Music/m$i.flac'), now: t0);
      }
      expect(
          addsChosenSong(
              stayClose: true,
              chosen: true,
              canAdd: full.canAdd(SeedList.moreLike)),
          isFalse);
    });
  });

  group('stayCloseReleases', () {
    test('only a frozen lane that took in no song and can carry no row', () {
      for (final frozen in [true, false]) {
        for (final admitted in [true, false]) {
          for (final anyUsable in [true, false]) {
            expect(
                stayCloseReleases(
                    frozen: frozen, admitted: admitted, anyUsable: anyUsable),
                frozen && !admitted && !anyUsable,
                reason: 'frozen $frozen, admitted $admitted, '
                    'anyUsable $anyUsable');
          }
        }
      }
    });

    // The handler's lane state through its picks and refusals: the flag,
    // whether the lane took in its song, and the rows set aside
    // (_seedUnusable).
    bool carried(AutoDjSeed s, Set<String> unusable) =>
        !unusable.contains(s.key) && s.server == 'home';
    final x = song('Music/x.flac');
    final y = song('Music/y.flac');

    test('a carried pin the server refuses: the lane takes in its one song '
        'at the next pick', () {
      // A new Stay close lane: the user's pin X carried over, nothing set
      // aside, the flag down.
      final lane0 = AutoDjSeeds.empty
          .addManual(SeedList.moreLike, x, now: t0)
          .carryOver(t0, frozen: true);
      final unusable = <String>{};
      // First pick: X is something to stay close to; Y is not taken in.
      final p1 = stayCloseAdmit(lane0,
          anchored: false,
          song: y,
          usable: (s) => carried(s, unusable),
          now: t0);
      expect(p1.anchored, isTrue);
      expect(p1.admitted, isFalse);
      expect(usableSeeds(p1.seeds.moreLike, (s) => carried(s, unusable)),
          [(server: 'home', path: 'Music/x.flac')]);
      // The server says X is not analysed yet: Stay close sets it aside
      // and keeps it listed.
      final verdict = p1.seeds.culprits({seedKey('home', x.path)});
      expect(verdict.drop, isEmpty);
      unusable.addAll(verdict.setAside);
      final released = stayCloseReleases(
          frozen: p1.seeds.frozen,
          admitted: p1.admitted,
          anyUsable: p1.seeds.moreLike.any((s) => carried(s, unusable)));
      expect(released, isTrue);
      // Before, the flag stayed up: no song came in, and every later pick
      // went without sonic similarity.
      final stuck = stayCloseAdmit(p1.seeds,
          anchored: true,
          song: y,
          usable: (s) => carried(s, unusable),
          now: t0);
      expect(stuck.admitted, isFalse);
      expect(usableSeeds(stuck.seeds.moreLike, (s) => carried(s, unusable)),
          isEmpty);
      // Released, the next pick takes in the song playing, beside X.
      final p2 = stayCloseAdmit(p1.seeds,
          anchored: !released,
          song: y,
          usable: (s) => carried(s, unusable),
          now: t0);
      expect(p2.admitted, isTrue);
      expect(p2.anchored, isTrue);
      expect([for (final s in p2.seeds.moreLike) s.wirePath],
          ['Music/x.flac', 'Music/y.flac']);
      expect(usableSeeds(p2.seeds.moreLike, (s) => carried(s, unusable)),
          [(server: 'home', path: 'Music/y.flac')]);
      // One song only: nothing after it.
      final p3 = stayCloseAdmit(p2.seeds,
          anchored: p2.anchored,
          song: song('Music/z.flac'),
          usable: (s) => carried(s, unusable),
          now: t0);
      expect(p3.seeds, same(p2.seeds));
    });

    test('a lane whose own song is refused takes in no other', () {
      final unusable = <String>{};
      final p1 = stayCloseAdmit(AutoDjSeeds.fresh(frozen: true, now: t0),
          anchored: false,
          song: y,
          usable: (s) => carried(s, unusable),
          now: t0);
      expect(p1.admitted, isTrue);
      unusable.addAll(p1.seeds.culprits({seedKey('home', y.path)}).setAside);
      expect(unusable, {seedKey('home', y.path)});
      expect(
          stayCloseReleases(
              frozen: p1.seeds.frozen,
              admitted: true,
              anyUsable: p1.seeds.moreLike.any((s) => carried(s, unusable))),
          isFalse);
    });

    test('a row the user removed is no refusal: nothing is set aside, and '
        'the emptied list stays empty', () {
      final lane = AutoDjSeeds.empty
          .addManual(SeedList.moreLike, x, now: t0)
          .carryOver(t0, frozen: true);
      final p1 = stayCloseAdmit(lane,
          anchored: false, song: y, usable: (s) => carried(s, {}), now: t0);
      expect(p1.anchored, isTrue);
      final emptied =
          p1.seeds.remove(SeedList.moreLike, seedKey('home', x.path));
      // A late refusal of X names no row now: the handler releases only
      // when it set a row aside.
      expect(emptied.culprits({seedKey('home', x.path)}).setAside, isEmpty);
      final p2 = stayCloseAdmit(emptied,
          anchored: p1.anchored,
          song: y,
          usable: (s) => carried(s, {}),
          now: t0);
      expect(p2.seeds.moreLike, isEmpty);
      expect(p2.anchored, isTrue);
    });

    test('a full list of refused rows takes in the one song as a ninth row',
        () {
      var lane = AutoDjSeeds.empty;
      for (var i = 0; i < AutoDjSeeds.maxPerList; i++) {
        lane = lane.addManual(SeedList.moreLike, song('Music/m$i.flac'),
            now: t0);
      }
      lane = lane.carryOver(t0, frozen: true);
      final unusable = lane.culprits({
        for (final s in lane.moreLike) s.key,
      }).setAside;
      expect(unusable.length, AutoDjSeeds.maxPerList);
      expect(
          stayCloseReleases(
              frozen: lane.frozen,
              admitted: false,
              anyUsable: lane.moreLike.any((s) => carried(s, unusable))),
          isTrue);
      final p = stayCloseAdmit(lane,
          anchored: false,
          song: y,
          usable: (s) => carried(s, unusable),
          now: t0);
      expect(p.admitted, isTrue,
          reason: 'nothing in the full list can be sent, so the one song '
              'comes in past eight and the lane keeps sonic similarity');
      expect(p.anchored, isTrue);
      expect(p.seeds.moreLike, hasLength(AutoDjSeeds.maxPerList + 1));
      expect(p.seeds.moreLike.take(AutoDjSeeds.maxPerList).map((s) => s.key),
          lane.moreLike.map((s) => s.key),
          reason: 'no refused row is taken out');
      expect(p.seeds.moreLike.last.origin, SeedOrigin.anchor);
    });
  });

  group('negativeTargets', () {
    String names(List<Server> s) => [for (final x in s) x.localname].join(',');

    test('the DJ\'s own server when it takes negatives', () {
      expect(names(negativeTargets(dj: server('home'), multiServer: false)),
          'home');
      expect(
          names(negativeTargets(
              dj: server('home', autoDj: null), multiServer: false)),
          '');
    });

    test('across several, the servers the pick may ask that take them, once '
        'each', () {
      final home = server('home');
      final lab = server('lab');
      final old = server('old', autoDj: null);
      expect(
          names(negativeTargets(
              dj: home, multiServer: true, candidates: [home, lab, old])),
          'home,lab');
      expect(
          names(negativeTargets(
              dj: home, multiServer: false, candidates: [home, lab])),
          'home');
    });

    test('a server of the session that sits every pick out is no target', () {
      // home (the DJ) predates negatives; nas takes them but sits out (no
      // mood scores while a mood is set), so the pick asks only home.
      final home = server('home', autoDj: null);
      expect(
          names(negativeTargets(
              dj: home, multiServer: true, candidates: [home])),
          '');
    });
  });

  group('seedAddServersFor', () {
    String names(List<Server> s) => [for (final x in s) x.localname].join(',');
    final home = server('home');
    final lab = server('lab');
    final nas = server('nas');
    final old = server('old', autoDj: null);
    // The servers able to hand out a vector, as the handler's canSeed would
    // read them (nas was dropped from the fan-out this session).
    bool canSeed(Server s) => s.localname != 'nas';

    String add(SeedList list, List<Server> servers,
            {String? dj = 'home',
            bool multiServer = true,
            bool Function(Server)? seeds,
            required List<Server> targets}) =>
        names(seedAddServersFor(list, servers,
            dj: dj,
            multiServer: multiServer,
            canSeed: seeds ?? canSeed,
            negativeTargets: targets));

    test('with the DJ off every server is offered, in the order given', () {
      final servers = [home, lab, nas, old];
      for (final list in SeedList.values) {
        expect(add(list, servers, dj: null, targets: const []),
            'home,lab,nas,old',
            reason: '$list');
        expect(add(list, servers, dj: null, multiServer: false, targets: []),
            'home,lab,nas,old',
            reason: '$list');
      }
    });

    test('one server: More like is the DJ\'s own; Less like only when it '
        'takes negatives', () {
      expect(
          add(SeedList.moreLike, [home],
              multiServer: false, targets: const []),
          'home');
      expect(
          add(SeedList.lessLike, [home], multiServer: false, targets: [home]),
          'home');
      expect(
          add(SeedList.lessLike, [home],
              multiServer: false, targets: const []),
          '',
          reason: 'a DJ server that takes no negatives can use no Less like '
              'song');
    });

    test('several servers, More like: the DJ\'s own and those that can hand '
        'out a vector, home first', () {
      expect(add(SeedList.moreLike, [home, lab, nas, old], targets: [home]),
          'home,lab,old');
      // The DJ's own songs go by path, whatever the fan-out can do with it.
      expect(
          add(SeedList.moreLike, [home, lab],
              seeds: (s) => s.localname != 'home', targets: const []),
          'home,lab');
    });

    test('several servers, Less like: the servers the next pick sends '
        'negatives to', () {
      // nas takes negatives but sits this session out: the pick asks it
      // nothing, so its own songs would go nowhere.
      expect(
          add(SeedList.lessLike, [home, lab, nas],
              seeds: (_) => false, targets: [home, lab]),
          'home,lab');
    });

    test('several servers, Less like: one whose vectors go to another server '
        'that takes negatives', () {
      // old predates negatives, but can hand out its songs' vectors, and
      // lab takes them.
      expect(add(SeedList.lessLike, [home, lab, old], targets: [lab]),
          'home,lab,old');
      // Without a server there that takes negatives, a vector goes nowhere.
      expect(add(SeedList.lessLike, [home, lab, old], targets: const []), '');
      // One that can't hand out a vector (dropped this session) and takes
      // no negatives: nothing to send.
      expect(add(SeedList.lessLike, [home, nas], targets: [home]), 'home');
    });
  });

  group('negativesSnapshot', () {
    String snapshot(AutoDjSeeds s, List<String> servers) => negativesSnapshot(
        {for (final name in servers) name: s.negativesFor(name)});

    test('a re-skip of a Less like song changes nothing a server is sent', () {
      final before = AutoDjSeeds.empty
          .quickSkip(song('a'), learn: true, now: t0)
          .quickSkip(song('b'), learn: true, now: t0);
      final after = before.quickSkip(song('a'), learn: true, now: t0);
      // The row moved to the newest place...
      expect(after.negativesFor('home').paths, ['b', 'a']);
      expect(before.negativesFor('home').paths, ['a', 'b']);
      // ...which the snapshot, like the server, does not count.
      expect(snapshot(after, ['home']), snapshot(before, ['home']));
    });

    test('a new negative, or one gone, is a change', () {
      final before =
          AutoDjSeeds.empty.quickSkip(song('a'), learn: true, now: t0);
      final more = before.quickSkip(song('b'), learn: true, now: t0);
      expect(snapshot(more, ['home']), isNot(snapshot(before, ['home'])));
      final less = before.remove(SeedList.lessLike, seedKey('home', 'a'));
      expect(snapshot(less, ['home']), isNot(snapshot(before, ['home'])));
    });

    test('each server is its own: the same song is a path to one, a vector '
        'to another', () {
      final s = AutoDjSeeds.empty
          .quickSkip(song('a'), learn: true, now: t0)
          .withVector(seedKey('home', 'a'), 'VEC', 'm');
      final sent = {
        'home': s.negativesFor('home', modelId: 'm'),
        'lab': s.negativesFor('lab', modelId: 'm'),
      };
      expect(negativesSnapshot(sent), jsonEncode([
        ['home', ['a'], []],
        ['lab', [], ['VEC']],
      ]));
      expect(negativesSnapshot({'lab': sent['lab']!, 'home': sent['home']!}),
          negativesSnapshot(sent));
    });
  });

  group('readEmbeddingsAnswer', () {
    final vec = Float32List.fromList([1, 0, 0, 0]);
    final wire = encodeWireVector(vec);
    String answer(List<Map<String, Object?>> tracks,
            {String model = 'effnet', int dim = 4}) =>
        jsonEncode({
          'model': {'id': model, 'version': '1'},
          'dim': dim,
          'tracks': tracks,
        });
    Map<String, Object?> analysed(String p) =>
        {'filePath': p, 'notAnalyzed': false, 'embedding': wire};
    Map<String, Object?> pending(String p) =>
        {'filePath': p, 'notAnalyzed': true, 'embedding': null};

    test('a 200: each path\'s vector, or not analysed yet', () {
      final r = readEmbeddingsAnswer(['a', 'b'],
          status: 200, body: answer([analysed('a'), pending('b')]));
      expect(r.verdicts, [SeedVerdict.vector, SeedVerdict.notAnalyzed]);
      expect(r.refuses(0), isFalse);
      expect(r.refuses(1), isTrue);
      expect(r.found!.modelId, 'effnet');
      expect(r.found!.dim, 4);
      expect(r.found!.vectors.single, vec);
    });

    test('every path not analysed: no vector, each one refused', () {
      final r = readEmbeddingsAnswer(['a', 'b'],
          status: 200, body: answer([pending('a'), pending('b')]));
      expect(r.found, isNull);
      expect([r.refuses(0), r.refuses(1)], [true, true]);
    });

    test('the route\'s 404 names the path asked alone as gone', () {
      final r = readEmbeddingsAnswer(['a'],
          status: 404, body: '{"error":"Track not found"}');
      expect(r.verdicts, [SeedVerdict.gone]);
      expect(r.refuses(0), isTrue);
      expect(r.someGone, isFalse);
      expect(r.found, isNull);
    });

    test('for a batch it names none, but says one of them is gone', () {
      final r = readEmbeddingsAnswer(['a', 'b'],
          status: 404, body: '{"error":"Track not found"}');
      expect(r.verdicts, [SeedVerdict.unknown, SeedVerdict.unknown]);
      expect(r.someGone, isTrue);
      expect([r.refuses(0), r.refuses(1)], [false, false]);
    });

    test('no answer, or one about the server rather than the songs, says '
        'nothing', () {
      final cases = <({int? status, String? body})>[
        (status: null, body: null), // a timeout, a dropped connection
        (status: 403, body: '{"error":"Discovery is disabled"}'),
        (status: 404, body: '<pre>Cannot POST /api/v1/discovery</pre>'),
        (status: 400, body: '{"error":"bad"}'),
        (status: 500, body: ''),
        (status: 200, body: 'not json'),
        (status: 200, body: '{"dim":4,"tracks":[]}'), // no model
      ];
      for (final c in cases) {
        final r = readEmbeddingsAnswer(['a', 'b'],
            status: c.status, body: c.body);
        expect(r.verdicts, [SeedVerdict.unknown, SeedVerdict.unknown],
            reason: '${c.status} ${c.body}');
        expect(r.someGone, isFalse, reason: '${c.status} ${c.body}');
        expect(r.found, isNull, reason: '${c.status} ${c.body}');
      }
    });

    test('an entry of another length, for another path, or missing says '
        'nothing about it', () {
      final r = readEmbeddingsAnswer(['a', 'b', 'c'],
          status: 200,
          body: answer([
            {'filePath': 'a', 'embedding': encodeWireVector(Float32List(3))},
            analysed('x'),
          ]));
      expect(r.verdicts,
          [SeedVerdict.unknown, SeedVerdict.unknown, SeedVerdict.unknown]);
      expect(r.found, isNull);
    });

    test('probes one path at a time read as one answer, in one model', () {
      final probes = [
        readEmbeddingsAnswer(['a'], status: 200, body: answer([analysed('a')])),
        readEmbeddingsAnswer(['b'],
            status: 404, body: '{"error":"Track not found"}'),
        readEmbeddingsAnswer(['c'], status: 200, body: answer([pending('c')])),
        readEmbeddingsAnswer(['d']), // timed out
        readEmbeddingsAnswer(['e'],
            status: 200, body: answer([analysed('e')], model: 'other')),
      ];
      final r = EmbeddingsReading.ofProbes(probes);
      expect(r.verdicts, [
        SeedVerdict.vector,
        SeedVerdict.gone,
        SeedVerdict.notAnalyzed,
        SeedVerdict.unknown,
        SeedVerdict.vector,
      ]);
      expect([for (var i = 0; i < 5; i++) r.refuses(i)],
          [false, true, true, false, false]);
      // The vector in another model is not averaged in.
      expect(r.found!.modelId, 'effnet');
      expect(r.found!.vectors.length, 1);
    });
  });
}
