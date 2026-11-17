// Auto DJ seeds (More like / Less like) on the real audio handler.
//
// The seeds model and its rules are unit-tested on plain values
// (test/util/auto_dj_seeds_test.dart, auto_dj_wire_test.dart,
// auto_dj_skips_test.dart). This file checks the handler's wiring, which no
// VM test can reach, against real playback:
//   1. Drift: a DJ pick joins More like when it STARTS playing (never while
//      it waits in the queue), and later random-songs bodies carry the
//      started picks' wire paths as `similarTo`.
//   2. Learn from skips on: a quick skip (Next about 1.5 s into a DJ pick)
//      moves the song from More like to Less like, and the next body carries
//      it as `lessLike`.
//   3. Learn from skips off: the same skip adds nothing to Less like and
//      still takes the song out of More like.
//   4. In Drift a queue clear keeps the pins of both lists and drops the
//      DJ's own picks, and the new lane's first pick blends in the song
//      playing: it joins More like, unpinned, beside the pins, and that
//      body carries both. With "Clear pins when the queue is cleared"
//      ticked, a clear of a queue that held a row leaves both lists empty,
//      and the next lane's first body carries the song playing alone.
//   5. Stay close admits one song only to start: after the user removes it,
//      nothing comes back and the picks send no positive seed.
//   6. A server without the picker generation that takes negatives is never
//      sent `lessLike`, `lessLikeVectors` or `lessLikeModelId`.
//   7. Stay close keeps every row it shows through a queue clear: the song
//      it admitted stays, and the next lane stays close to it without
//      taking in a song of its own.
//   8. Stay close started from a song the user chose adds that song to More
//      like, pinned, after the pin held aside, and the first follower's body
//      carries both.
//   9. A Stay close start from Random's song adds nothing: the first body
//      carries the pin alone.
//  10. Drift: the song the lane's start blends in can be one the server has
//      not analysed yet. When the server refuses the body over it and no
//      probe can say which row it meant (a server from before the
//      embeddings route), the blend leaves, the pin goes again alone, and
//      sonic similarity stays on.
//  11. With no pin beside it the blend is the lane's one row, and once it is
//      out Drift would fall back to that same song: the refused seeds are
//      not sent again, and the pick goes without sonic similarity at once.
//  12. Drift: a quick skip of the blended song (the user's own, no DJ pick)
//      takes it out of More like as a quick-skipped pick leaves, and with
//      Learn from skips on nothing joins Less like. Offered again by the
//      server, it is passed over for the rest of the lane.
//  13. A DJ pick an earlier lane left at the end of the queue, blended in
//      by a new start (Stop, then Start), keeps the DJ pick's rule: with
//      Learn from skips on its quick skip puts it in Less like.
//  14. A queue clear while the DJ's last row plays with no pick behind it
//      (every answer empty) opens no lane on the rows it throws away: the
//      stop's own index events start no pick, so nothing is blended in and
//      no body goes out until the next queue.
//  15. Stay close with More like full of another server's songs (as after a
//      move of the DJ) still takes in the song playing as its one song, a
//      ninth row, removing nothing, and the first pick stays close to it.
//  16. Discover's start (startSessionFromSong) with the DJ off opens the
//      session on the song it was started from, and in Stay close adds that
//      song to More like, pinned: the clear that spends a one-shot seed comes
//      before the song is stored.
//  17. The same with the DJ already on the same server, where setAutoDJ is
//      no new session and never reads a seed: the armed DJ starts from it.
//  18. The same with the DJ on another server: the start moves the DJ to the
//      song's server, a fresh session that reads the seed.
//
// Every expectation reads the handler's seeds or the bodies the mock
// recorded; waits only bound how long a test looks.
//
// The mock: an in-process MockServer whose random-songs route records every
// body and answers ONE song per call, whatever `limit` asks, each on a new
// path whose stream URL serves a silent WAV. With one song per answer the DJ
// asks again only when its last row starts playing. So "every body has
// queued its song and a row waits behind the playing one" means no pick is
// out and none is due ([quiet]), which lets a test act between picks. A body
// seeded by a song a test marks unanalysed is refused as random-songs
// refuses it, a 400 "not analyzed yet"; the embeddings route answers as a
// server from before it does, a 404 that names no song. Two switches change
// the answers: a path a test puts in `serveAgain` is answered again (a pick
// that passes it over asks again at once, so [quiet] no longer holds after
// it), and `answerNone` answers every call with no song at all.
//
// The DJ's Server is never added to ServerManager. resetAppState empties
// the server list, so loadPinnedSeeds (which waits for one) stays inert: no
// row stored in the device's auto_dj.json joins the lists, and the save hook
// that follows them stays off. Only the ticked box's clear (test 4) writes
// the stored rows, as it must. The Server's capability fields are set
// by hand: discoveryEnabled and discoveryReady for Server.sonicUsable (the
// DJ's sonic gate), and autoDjGeneration for Server.lessLikeUsable (the
// negatives gate).
//
// The Auto DJ settings this file changes, the stored rows and when they
// froze among them, are put back after the last test.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mstream_music/media/audio_stuff.dart' show SonicDrop;
import 'package:mstream_music/objects/play_event.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/auto_dj_manager.dart';
import 'package:mstream_music/singletons/media.dart';
import 'package:mstream_music/util/auto_dj_seeds.dart';

import 'helpers/test_helpers.dart';

// Each pick's length. A Next 1.5 s in is a second or more heard and short of
// half the track (the play rule's other half, 30 s, is out of reach), with
// seconds to spare either side; and picks still start one after another
// within a test's patience.
const int _trackSeconds = 8;

// The window a quick skip is pressed in, in ms of the pick's position: past
// the one-second floor, short of half the track.
const int _skipFromMs = 1500;
const int _skipBeforeMs = 3500;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final wav = buildSilentWav(seconds: _trackSeconds);

  MockServer? mockServer;

  // Every random-songs body the app sent this test, oldest first.
  final djBodies = <Map<String, dynamic>>[];
  // This test's name for its server and paths ('t1', 't2', …), so nothing a
  // test leaves behind can be mistaken for the next test's rows.
  var tag = '';
  var nextPickId = 0;
  // The wire paths the mock server has not analysed yet, and how many times
  // the app asked its embeddings route about a song.
  final unanalysed = <String>{};
  var embeddingProbes = 0;
  // Wire paths the mock answers its next calls with, oldest first, before it
  // makes up new picks: a test that wants a song offered again puts it here.
  final serveAgain = <String>[];
  // While set, every call is answered with no song (the server found none).
  var answerNone = false;

  String serverName() => 'it-seeds-$tag';

  Future<Object?> randomSongs(HttpRequest req) async {
    final body =
        jsonDecode(await utf8.decoder.bind(req).join()) as Map<String, dynamic>;
    djBodies.add(body);
    // One seed without a vector fails the whole body, as random-songs' sonic
    // pool does, with no word of which seed it was.
    if (((body['similarTo'] as List?) ?? const []).any(unanalysed.contains)) {
      req.response.statusCode = 400;
      return {'error': 'Sonic seed track has not been analyzed yet'};
    }
    final id = nextPickId++;
    // Echo the server contract: the sent list plus this pick's id. A lane's
    // first body is the only one with an empty list ([opensLane]).
    final ignore = List<int>.from(
        (body['ignoreList'] as List?)?.cast<int>() ?? const <int>[])
      ..add(id);
    if (answerNone) return {'songs': const <Object>[], 'ignoreList': ignore};
    final again = serveAgain.isEmpty ? null : serveAgain.removeAt(0);
    return {
      'songs': [
        {
          'filepath': again ?? 'demo/$tag/pick_$id.wav',
          'metadata': {
            'title': again == null ? 'Pick $id' : 'Offered again',
            'artist': 'DJ Pick',
            'duration': _trackSeconds,
          },
        }
      ],
      'ignoreList': ignore,
    };
  }

  Future<void> waitFor(bool Function() cond, String what,
      {Duration timeout = const Duration(seconds: 60)}) async {
    final deadline = DateTime.now().add(timeout);
    while (!cond()) {
      if (DateTime.now().isAfter(deadline)) fail('timed out waiting for $what');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  // One of the handler's actions, bounded so a wedged one fails the test
  // rather than hanging it.
  Future<T> within<T>(Future<T> action, String what) => action.timeout(
      const Duration(seconds: 30),
      onTimeout: () => fail('timed out: $what'));

  /// The DJ's server, with the capability fields the gates read. [localname]
  /// names another server on the same mock (this test's server by default).
  Server djServer({String? localname, bool takesNegatives = true}) {
    final s =
        Server(mockServer!.url, null, null, null, localname ?? serverName());
    // Server.sonicUsable, the DJ's sonic gate: discovery switched on (the raw
    // engine flag, Server.discoveryOn) and its scan not unfinished.
    s.discoveryEnabled = true;
    s.discoveryReady = true;
    // Server.lessLikeUsable: a random-songs picker generation of 1 or more
    // (mStream #1108), with discovery on and its scan done. A server from
    // before the generation reports none.
    s.autoDjGeneration = takesNegatives ? 1 : null;
    return s;
  }

  String keyOf(MediaItem m) =>
      seedKey(m.extras!['server'] as String, m.extras!['path'] as String);
  String wireOf(MediaItem m) => seedWirePath(m.extras!['path'] as String);
  List<String> keysIn(List<AutoDjSeed> rows) => [for (final s in rows) s.key];
  List<String> similarTo(Map<String, dynamic> b) =>
      [for (final p in (b['similarTo'] as List?) ?? const []) p as String];
  List<String> lessLike(Map<String, dynamic> b) =>
      [for (final p in (b['lessLike'] as List?) ?? const []) p as String];
  // A lane's first body: a reset leaves the ignoreList empty, and the mock
  // adds to it on every answer after that.
  bool opensLane(Map<String, dynamic> b) =>
      ((b['ignoreList'] as List?) ?? const []).isEmpty;

  /// No pick is out and none is due: every body sent so far has queued its
  /// one song, and a row waits behind the playing one, so the next request
  /// goes out only when that row starts. Holds as a test of that only within
  /// the lane the test opened and before any skip, where each body queued
  /// exactly one row.
  bool quiet() {
    final h = MediaManager().audioHandler;
    final q = h.queue.value;
    final i = h.index;
    final djRows = q.where((m) => m.extras?['djPick'] == true).length;
    return i != null && q.length >= i + 2 && djBodies.length == djRows;
  }

  /// Arms the DJ on [srv], as Start does on an empty queue. Not awaited: the
  /// tests follow it through the bodies and the seeds. Its synchronous part
  /// (the new lane and the server) has run when this returns.
  void arm(Server srv) => unawaited(MediaManager()
      .audioHandler
      .customAction('setAutoDJ', {'autoDJServer': srv}));

  /// A quick skip: Next on a DJ pick that sits in More like (this lane's,
  /// or one an earlier lane left that this lane's start blended in),
  /// pressed between [_skipFromMs] and [_skipBeforeMs] into it, with the
  /// next pick already queued behind it and no pick out. Returns the skipped
  /// row and how many bodies had come in before the Next, so
  /// `djBodies[sentBefore]` is the first body built after it.
  Future<({MediaItem row, int sentBefore})> quickSkip() async {
    final h = MediaManager().audioHandler;
    ({MediaItem row, int sentBefore, int heardMs, Future<void> next})? press;
    await waitFor(() {
      final q = h.queue.value;
      final i = h.index;
      if (i == null || i < 0 || i >= q.length) return false;
      final at = h.position.inMilliseconds;
      if (q[i].extras?['djPick'] != true ||
          !quiet() ||
          !h.seeds.has(SeedList.moreLike, keyOf(q[i])) ||
          at < _skipFromMs ||
          at >= _skipBeforeMs) {
        return false;
      }
      // Pressed in the same turn as the look, so no pick goes out and the
      // song doesn't move on in between. The handler judges the skip inside
      // this call, before its seek; the future is the rest of the Next.
      press = (
        row: q[i],
        sentBefore: djBodies.length,
        heardMs: at,
        next: h.skipToNext(),
      );
      return true;
    }, 'a DJ pick in More like ${_skipFromMs}ms in, with the next one queued',
        timeout: const Duration(seconds: 90));
    final p = press!;
    await within(p.next, 'the Next');
    // What the handler read as heard time: the play tracker is not running
    // here, so it falls back to the player's position, which starts at 0
    // (see zeroIdlePlayer).
    expect(p.heardMs, inInclusiveRange(1000, _trackSeconds * 500 - 1),
        reason: 'a quick skip is heard for a second or more and short of a '
            'play (half the track)');
    return (row: p.row, sentBefore: p.sentBefore);
  }

  /// After a clear the idle player still holds the spot its last track
  /// stopped at, and the next play loads its first row there. Zeroed, so
  /// that row starts at its beginning and its position is the time it was
  /// heard. Only on an idle, empty player (right after a clear).
  Future<void> zeroIdlePlayer() => within(
      MediaManager().audioHandler.seek(Duration.zero),
      'zeroing the idle player');

  /// A row the user queues on the empty queue, then plays: the DJ tops up
  /// behind it.
  Future<MediaItem> queueAndPlay(String name) async {
    final h = MediaManager().audioHandler;
    await zeroIdlePlayer();
    final path = '/demo/$tag/$name.wav';
    final item = MediaItem(
      id: '${mockServer!.url}/media$path',
      title: 'User $name',
      extras: {'server': serverName(), 'path': path},
    );
    await within(h.addQueueItem(item), 'queueing $name');
    unawaited(h.play());
    return item;
  }

  /// Both lists emptied through the page's own Remove. A row can sit in the
  /// live set and in the one held aside; the view shows one of them, so go
  /// round until the view is empty.
  void dropAllSeeds() {
    final h = MediaManager().audioHandler;
    for (var pass = 0; pass < 4 && !h.seeds.isEmpty; pass++) {
      final view = h.seeds;
      for (final s in view.moreLike) {
        h.seedRemove(SeedList.moreLike, s.key);
      }
      for (final s in view.lessLike) {
        h.seedRemove(SeedList.lessLike, s.key);
      }
    }
  }

  /// The shared handler back to a clean start: the DJ off, the queue empty
  /// (both new-lane resets), Drift, and no row in either list. A reset keeps
  /// the pins and the unpinned skips on purpose, so the lists are emptied by
  /// hand.
  Future<void> resetHandler() async {
    final h = MediaManager().audioHandler;
    await within(h.customAction('setAutoDJ', {'autoDJServer': null}),
        'switching the DJ off');
    await within(h.customAction('clearPlaylist'), 'clearing the queue');
    await within(h.setSeedMode(SonicAnchorMode.rolling), 'Drift');
    dropAllSeeds();
  }

  late Future<void> Function() restoreSettings;

  setUpAll(() async {
    await MediaManager().start();
    // Settled before any test sets a field: load() is memoized, and the arm
    // awaits it (loadPinnedSeeds), so a first read of auto_dj.json mid-test
    // would put the stored settings back over the ones the tests set.
    await AutoDJManager().load();
    final mgr = AutoDJManager();
    final sonic = mgr.sonicSimilarityEnabled;
    final learn = mgr.learnFromSkips;
    final clearPins = mgr.clearPinsOnQueueClear;
    final mode = mgr.sonicAnchorMode;
    final pins = mgr.pinnedSeeds;
    final frozenAt = mgr.seedsFrozenAt;
    final keywords = mgr.keywordFilterEnabled;
    final playFromAll = mgr.playFromAll;
    final playFromServers = mgr.playFromServers;
    final playFromServer = mgr.playFromServer;
    final enabledServer = mgr.enabledServer;
    restoreSettings = () async {
      await MediaManager().audioHandler.setSeedMode(mode);
      mgr
        ..learnFromSkips = learn
        ..clearPinsOnQueueClear = clearPins
        ..pinnedSeeds = pins
        ..seedsFrozenAt = frozenAt
        ..keywordFilterEnabled = keywords
        ..playFromAll = playFromAll
        ..playFromServers = playFromServers
        ..playFromServer = playFromServer
        ..enabledServer = enabledServer;
      // One save writes every key from memory.
      await mgr.setSonic(enabled: sonic, minSimilarity: mgr.sonicMinSimilarity);
    };
  });

  tearDownAll(() => restoreSettings());

  setUp(() async {
    await resetAppState();
    final h = MediaManager().audioHandler;
    // A failed earlier test can leave the DJ armed, a queue, Stay close or
    // rows in the lists; the handler is shared, so each test starts clean.
    await resetHandler();
    // The lane's first pick then starts at its beginning.
    await zeroIdlePlayer();
    await within(h.setRepeatMode(AudioServiceRepeatMode.none), 'repeat off');
    await within(
        h.setShuffleMode(AudioServiceShuffleMode.none), 'shuffle off');
    // In memory only, saved with the setters below. A one-shot seed left by
    // an earlier run would reroute the arm through the seeded start, a skip
    // word could block the mock's picks, and Play from across several
    // servers would take the cross-server route, whose bodies carry vectors
    // instead of similarTo paths.
    final mgr = AutoDJManager()
      ..sonicSeedPath = null
      ..sonicSeedTitle = null
      ..sonicSeedServer = null
      ..sonicSeedChosen = false
      ..keywordFilterEnabled = false
      ..playFromAll = false
      ..playFromServers = const [];
    await mgr.setSonicSimilarityEnabled(true);
    await mgr.setLearnFromSkips(false);
    await mgr.setClearPinsOnQueueClear(false);
    expect(h.seeds.isEmpty, isTrue, reason: 'each test starts with no seeds');
    expect(mgr.multiServerEnabled, isFalse);
    djBodies.clear();
    nextPickId = 0;
    unanalysed.clear();
    embeddingProbes = 0;
    serveAgain.clear();
    answerNone = false;
    mockServer = await MockServer.start(
      {
        '/api/v1/db/random-songs': randomSongs,
        // A server from before the embeddings route (mStream 6.26) answers
        // a probe with a 404 that names no song.
        '/api/v1/discovery/local/embeddings': (_) {
          embeddingProbes++;
          return null;
        },
      },
      // Everything else is a stream URL: playable audio, so the picks play
      // through instead of taking the error walk.
      defaultHandler: (_) => wav,
    );
  });

  tearDown(() async {
    await resetHandler();
    await AutoDJManager().setLearnFromSkips(false);
    await AutoDJManager().setClearPinsOnQueueClear(false);
    await mockServer?.close();
    mockServer = null;
  });

  testWidgets(
      'Drift: DJ picks join More like as they start playing, and later '
      'bodies send them as similarTo', (WidgetTester tester) async {
    tag = 't1';
    final h = MediaManager().audioHandler;
    arm(djServer());

    // The opening pick: nothing has played, so More like is empty and Drift
    // has no playing track to fall back to.
    await waitFor(() => djBodies.isNotEmpty, 'the opening pick');
    expect(djBodies.first.containsKey('similarTo'), isFalse,
        reason: 'a cold start on an empty queue has no positive seed');

    await waitFor(() => (h.index ?? -1) >= 1, 'the second pick to start',
        timeout: const Duration(seconds: 90));
    final first = h.queue.value[0];
    final second = h.queue.value[1];
    expect(first.extras?['djPick'], isTrue);
    expect(second.extras?['djPick'], isTrue);
    await waitFor(
        () =>
            h.seeds.has(SeedList.moreLike, keyOf(first)) &&
            h.seeds.has(SeedList.moreLike, keyOf(second)),
        'both started picks to join More like');

    // One synchronous look at the queue, the playing row and the seeds:
    // what More like holds is picks that have started, and none of the
    // picks still waiting behind the playing row.
    final q = h.queue.value;
    final playing = h.index!;
    final seeds = h.seeds;
    for (final row in seeds.moreLike) {
      expect(row.origin, SeedOrigin.pick,
          reason: 'a DJ pick joins as a pick');
      expect(row.pinned, isFalse, reason: 'a pick joins unpinned');
      expect(q.indexWhere((m) => keyOf(m) == row.key),
          inInclusiveRange(0, playing),
          reason: 'only a pick that has started playing is in More like');
    }
    for (var i = playing + 1; i < q.length; i++) {
      expect(seeds.has(SeedList.moreLike, keyOf(q[i])), isFalse,
          reason: 'row $i is queued but has not started playing');
    }

    // The pick fetched as the second one started carries both, oldest
    // first: no fallback ever sends two paths, so these are the rows.
    final w0 = wireOf(first);
    final w1 = wireOf(second);
    await waitFor(() => djBodies.any((b) => similarTo(b).contains(w1)),
        'a body seeded by the second pick');
    final seeded = djBodies.firstWhere((b) => similarTo(b).contains(w1));
    expect(similarTo(seeded), [w0, w1],
        reason: 'similarTo is the started picks\' wire paths, oldest first');
    expect(seeded['minSimilarity'],
        closeTo(AutoDJManager().sonicMinSimilarity, 1e-9),
        reason: 'the match goes with the positive seeds');
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets(
      'Learn from skips on: a quick skip puts the song in Less like, and the '
      'next body sends it as lessLike', (WidgetTester tester) async {
    tag = 't2';
    final h = MediaManager().audioHandler;
    await AutoDJManager().setLearnFromSkips(true);
    arm(djServer());
    expect(h.seedsTakeNegatives, isTrue,
        reason: 'the DJ\'s server reports a picker generation that takes '
            'negatives');

    final skip = await quickSkip();
    final key = keyOf(skip.row);
    final wire = wireOf(skip.row);
    // Judged before the seek, so the lists already show it.
    expect(h.seeds.has(SeedList.moreLike, key), isFalse,
        reason: 'the skipped song leaves More like');
    final rows = h.seeds.lessLike.where((s) => s.key == key).toList();
    expect(rows, hasLength(1), reason: 'the skipped song joins Less like');
    expect(rows.single.origin, SeedOrigin.skip);
    expect(rows.single.pinned, isFalse,
        reason: 'a learned skip is unpinned, on its 30-minute clock');

    // No pick was out at the Next (quickSkip waits for that), so the first
    // body to come in after it was built after it.
    await waitFor(() => djBodies.length > skip.sentBefore,
        'the pick after the skip');
    final next = djBodies[skip.sentBefore];
    expect(lessLike(next), [wire],
        reason: 'the next body steers away from the skipped song');
    expect(similarTo(next), isNot(contains(wire)),
        reason: 'a song in Less like is never a positive seed');
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets(
      'Learn from skips off: a quick skip adds nothing to Less like and '
      'takes the song out of More like', (WidgetTester tester) async {
    tag = 't3';
    final h = MediaManager().audioHandler;
    expect(AutoDJManager().learnFromSkips, isFalse);
    arm(djServer());
    // The server takes negatives, so a Less like row would show on the wire.
    expect(h.seedsTakeNegatives, isTrue);

    // quickSkip presses Next only on a pick that is in More like.
    final skip = await quickSkip();
    final key = keyOf(skip.row);
    final wire = wireOf(skip.row);
    expect(h.seeds.has(SeedList.moreLike, key), isFalse,
        reason: 'a quick skip takes the song out of More like, learned or not');
    expect(h.seeds.lessLike, isEmpty,
        reason: 'with Learn from skips off nothing joins Less like');

    await waitFor(() => djBodies.length > skip.sentBefore,
        'the pick after the skip');
    final next = djBodies[skip.sentBefore];
    expect(next.containsKey('lessLike'), isFalse,
        reason: 'Less like is empty, so no negative goes out');
    expect(similarTo(next), isNot(contains(wire)),
        reason: 'the skipped song no longer seeds the picks');
    expect(h.seeds.lessLike, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets(
      'pins outlive a queue clear and the song playing joins them at the new '
      'lane\'s first pick; with the box ticked a clear removes them',
      (WidgetTester tester) async {
    tag = 't4';
    final h = MediaManager().audioHandler;
    final mgr = AutoDJManager();
    arm(djServer());

    await waitFor(() => (h.index ?? -1) >= 1, 'the second pick to start',
        timeout: const Duration(seconds: 90));
    final first = h.queue.value[0];
    final second = h.queue.value[1];
    final k0 = keyOf(first);
    final w0 = wireOf(first);
    await waitFor(
        () =>
            h.seeds.has(SeedList.moreLike, k0) &&
            h.seeds.has(SeedList.moreLike, keyOf(second)),
        'both started picks to join More like');

    // The user pins the first pick, and adds a song to Less like (Add song
    // pins it).
    h.seedPin(SeedList.moreLike, k0, true);
    expect(h.seeds.moreLike.firstWhere((s) => s.key == k0).pinned, isTrue,
        reason: 'the pin took');
    final avoid = TrackFacts(
        server: serverName(),
        path: '/demo/$tag/avoid.wav',
        title: 'Avoid me',
        artist: 'Someone');
    final avoidKey = seedKey(avoid.server, avoid.path);
    h.seedAdd(SeedList.lessLike, avoid);
    expect(h.seeds.lessLike.where((s) => s.key == avoidKey).single.pinned,
        isTrue,
        reason: 'Add song pins its row');

    // ── Box unticked: the clear keeps the pins, the picks start over. ──
    expect(mgr.clearPinsOnQueueClear, isFalse);
    await within(h.customAction('clearPlaylist'), 'the first clear');
    expect(h.queue.value, isEmpty);
    expect(keysIn(h.seeds.moreLike), [k0],
        reason: 'the pinned pick stays; the unpinned picks go');
    expect(h.seeds.moreLike.single.pinned, isTrue);
    expect(keysIn(h.seeds.lessLike), [avoidKey],
        reason: 'the Less like pin stays too');

    // The new lane blends the new music in: at its first pick the song
    // playing (the user's own) joins More like beside the pin, unpinned, so
    // that body carries both, the pin first.
    final lane2 = djBodies.length;
    final userA = await queueAndPlay('user_a');
    await waitFor(() => djBodies.skip(lane2).any(opensLane),
        'the first pick after the first clear');
    final opener2 = djBodies.skip(lane2).firstWhere(opensLane);
    expect(similarTo(opener2), [w0, wireOf(userA)],
        reason: 'the song playing joins More like at the lane\'s first pick, '
            'next to the pin');
    expect(lessLike(opener2), [seedWirePath(avoid.path)],
        reason: 'the pinned Less like row still steers it');
    // Not asserted newest: the lane's next pick joins as soon as it starts.
    final joined =
        h.seeds.moreLike.where((s) => s.key == keyOf(userA)).toList();
    expect(joined, hasLength(1), reason: 'the song playing is in More like');
    expect(joined.single.pinned, isFalse,
        reason: 'it joins unpinned and rotates out like a DJ pick');
    expect(joined.single.origin, SeedOrigin.opener,
        reason: 'the song the lane opened on');
    expect(h.seeds.moreLike.firstWhere((s) => s.key == k0).pinned, isTrue,
        reason: 'the pin stays pinned');

    // ── Box ticked: a clear of a queue that held a row removes the pins. ──
    await mgr.setClearPinsOnQueueClear(true);
    expect(h.queue.value, isNotEmpty,
        reason: 'only a clear of a queue that held a row counts');
    await within(h.customAction('clearPlaylist'), 'the second clear');
    expect(h.seeds.moreLike, isEmpty, reason: 'the More like pin went');
    expect(h.seeds.lessLike, isEmpty, reason: 'the Less like pin went');
    expect(mgr.pinnedSeeds, isEmpty,
        reason: 'the stored pins go with them');

    // Nothing of them reaches the next lane.
    final lane3 = djBodies.length;
    final userB = await queueAndPlay('user_b');
    await waitFor(() => djBodies.skip(lane3).any(opensLane),
        'the first pick after the second clear');
    final opener3 = djBodies.skip(lane3).firstWhere(opensLane);
    expect(opener3.containsKey('lessLike'), isFalse,
        reason: 'no Less like row is left to send');
    expect(similarTo(opener3), [wireOf(userB)],
        reason: 'the song playing joined More like at the lane\'s first pick; '
            'the old pin is gone');
    final joinedB =
        h.seeds.moreLike.where((s) => s.key == keyOf(userB)).toList();
    expect(joinedB, hasLength(1));
    expect(joinedB.single.pinned, isFalse);
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('Stay close admits one song only to start',
      (WidgetTester tester) async {
    tag = 't5';
    final h = MediaManager().audioHandler;
    await within(h.setSeedMode(SonicAnchorMode.locked), 'Stay close');
    expect(h.seeds.frozen, isTrue, reason: 'Stay close freezes the lists');
    arm(djServer());

    // A lane with nothing to stay close to: the first pick that has a song
    // playing admits that song.
    await waitFor(() => h.seeds.moreLike.isNotEmpty,
        'Stay close to admit its one song');
    expect(h.seeds.moreLike, hasLength(1), reason: 'one song, to start');
    final anchor = h.seeds.moreLike.single;
    expect(anchor.origin, SeedOrigin.anchor);
    expect(anchor.pinned, isFalse,
        reason: 'the admitted song is not one the user pinned');
    expect(h.seeds.shownPinned(anchor), isTrue,
        reason: 'Stay close shows every row pinned');
    expect(h.queue.value.map(keyOf), contains(anchor.key),
        reason: 'the admitted song is one the lane queued and played');

    // The next pick starts and its follower lands: still that one song.
    await waitFor(() => (h.index ?? -1) >= 1 && quiet(),
        'the second pick to start and its follower to land',
        timeout: const Duration(seconds: 90));
    expect(keysIn(h.seeds.moreLike), [anchor.key],
        reason: 'Stay close adds nothing after its one song');
    final seeded = djBodies.where((b) => b.containsKey('similarTo')).toList();
    expect(seeded, isNotEmpty, reason: 'the admitted song seeds the picks');
    for (final b in seeded) {
      expect(similarTo(b), [anchor.wirePath],
          reason: 'every seeded body stays close to the one song');
    }

    // The user removes it between picks: nothing comes back, and the picks
    // go without a positive seed. Removed in the same turn as the look that
    // finds no pick out, so every body counted from here was built after it.
    var removedAt = -1;
    await waitFor(() {
      if (!quiet()) return false;
      removedAt = djBodies.length;
      h.seedRemove(SeedList.moreLike, anchor.key);
      return true;
    }, 'a moment with no pick out');
    expect(h.seeds.moreLike, isEmpty);
    // Listened to after the removal, so the replayed value is the empty one.
    final readmitted = <AutoDjSeeds>[];
    final sub = h.seedsStream.listen((s) {
      if (s.moreLike.isNotEmpty) readmitted.add(s);
    });
    addTearDown(sub.cancel);

    await waitFor(() => djBodies.length >= removedAt + 2,
        'two picks after the removal',
        timeout: const Duration(seconds: 90));
    for (final b in djBodies.skip(removedAt)) {
      expect(b.containsKey('similarTo'), isFalse,
          reason: 'with More like empty a Stay close pick sends no positive');
      expect(b.containsKey('minSimilarity'), isFalse,
          reason: 'a match without a seed is never sent');
    }
    expect(readmitted, isEmpty, reason: 'no row is added back');
    expect(h.seeds.moreLike, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('a server that takes no negatives is sent none',
      (WidgetTester tester) async {
    tag = 't6';
    final h = MediaManager().audioHandler;
    // An older server: discovery on and scanned, so sonic picks still run,
    // but no picker generation, so it takes no negatives.
    final srv = djServer(takesNegatives: false);
    expect(srv.sonicUsable, isTrue);
    expect(srv.lessLikeUsable, isFalse);
    await AutoDJManager().setLearnFromSkips(true);

    // A song already in Less like (Add song while the DJ is off, held aside
    // until the lane's first pick), so a negative would go out if the gate
    // let one through.
    final avoid = TrackFacts(
        server: serverName(),
        path: '/demo/$tag/avoid.wav',
        title: 'Avoid me',
        artist: 'Someone');
    final avoidKey = seedKey(avoid.server, avoid.path);
    h.seedAdd(SeedList.lessLike, avoid);
    expect(h.seeds.has(SeedList.lessLike, avoidKey), isTrue);

    arm(srv);
    expect(h.seedsTakeNegatives, isFalse,
        reason: 'no server in scope takes negatives');
    expect(h.seedAddServers(SeedList.lessLike), isEmpty,
        reason: 'Add song offers Less like nothing from such a server');

    // Learn from skips is on, but with no server taking negatives a quick
    // skip learns nothing; it still drops the song from More like.
    final skip = await quickSkip();
    final key = keyOf(skip.row);
    expect(h.seeds.has(SeedList.lessLike, key), isFalse,
        reason: 'no skip is learned without a server that takes negatives');
    expect(h.seeds.has(SeedList.moreLike, key), isFalse);
    expect(keysIn(h.seeds.lessLike), [avoidKey]);

    await waitFor(() => djBodies.length > skip.sentBefore,
        'the pick after the skip');
    expect(djBodies.where((b) => b.containsKey('similarTo')), isNotEmpty,
        reason: 'sonic similarity is still in play on this server');
    for (final b in djBodies) {
      for (final k in const ['lessLike', 'lessLikeVectors', 'lessLikeModelId']) {
        expect(b.containsKey(k), isFalse,
            reason: 'a server that takes no negatives is never sent $k');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('Stay close keeps the song it admitted through a queue clear',
      (WidgetTester tester) async {
    tag = 't7';
    final h = MediaManager().audioHandler;
    await within(h.setSeedMode(SonicAnchorMode.locked), 'Stay close');
    arm(djServer());

    // As in test 5: the first pick that has a song playing admits it.
    await waitFor(() => h.seeds.moreLike.isNotEmpty,
        'Stay close to admit its one song');
    expect(h.seeds.moreLike, hasLength(1));
    final anchor = h.seeds.moreLike.single;
    expect(anchor.origin, SeedOrigin.anchor);

    // Box unticked, a queue that held a row: the clear keeps every row
    // Stay close shows, the song it admitted among them.
    expect(AutoDJManager().clearPinsOnQueueClear, isFalse);
    expect(h.queue.value, isNotEmpty);
    await within(h.customAction('clearPlaylist'), 'the clear');
    expect(h.queue.value, isEmpty);
    expect(keysIn(h.seeds.moreLike), [anchor.key],
        reason: 'the admitted song outlives the queue');
    expect(h.seeds.moreLike.single.pinned, isFalse,
        reason: 'it is still no pin of the user\'s');
    expect(h.seeds.shownPinned(h.seeds.moreLike.single), isTrue,
        reason: 'Stay close shows it pinned');

    // The next lane stays close to it, and takes in no song of its own.
    final lane2 = djBodies.length;
    await queueAndPlay('user_c');
    await waitFor(() => djBodies.skip(lane2).any(opensLane),
        'the first pick after the clear');
    final first = djBodies.skip(lane2).firstWhere(opensLane);
    expect(similarTo(first), [anchor.wirePath],
        reason: 'the new lane stays close to the kept song');
    expect(keysIn(h.seeds.moreLike), [anchor.key],
        reason: 'nothing new was admitted');
  }, timeout: const Timeout(Duration(minutes: 5)));

  /// A Stay close start staged as the start sheet runs it: with the DJ off,
  /// Stay close and a pin held aside (Add song), then the opening song
  /// stored ([chosen]: Recently played or Choose; else Random's draw) and
  /// Start on the empty queue, a fresh arm that opens on it. Returns the
  /// pin and the opening song.
  Future<({TrackFacts pin, String openerPath})> stayCloseStart(
      {required bool chosen}) async {
    final h = MediaManager().audioHandler;
    await within(h.setSeedMode(SonicAnchorMode.locked), 'Stay close');
    final pin = TrackFacts(
        server: serverName(),
        path: '/demo/$tag/pin.wav',
        title: 'Pinned',
        artist: 'Someone');
    h.seedAdd(SeedList.moreLike, pin);
    expect(keysIn(h.seeds.moreLike), [seedKey(pin.server, pin.path)]);
    expect(h.seeds.moreLike.single.pinned, isTrue,
        reason: 'Add song pins its row, held aside while the DJ is off');
    final opener = 'demo/$tag/opener.wav';
    await within(
        AutoDJManager().setSonicSeed(
            path: opener,
            title: 'Opener',
            server: serverName(),
            chosen: chosen),
        'storing the opening song');
    expect(h.queue.value, isEmpty);
    arm(djServer());
    return (pin: pin, openerPath: '/$opener');
  }

  testWidgets('Stay close from a chosen song adds it, pinned',
      (WidgetTester tester) async {
    tag = 't8';
    final h = MediaManager().audioHandler;
    final start = await stayCloseStart(chosen: true);
    final pinKey = seedKey(start.pin.server, start.pin.path);
    final openerKey = seedKey(serverName(), start.openerPath);

    // The opener's metadata POST gets the mock's WAV and falls back to no
    // metadata, which is fine: the row still plays.
    await waitFor(() => djBodies.any(opensLane), 'the first follower');
    final first = djBodies.firstWhere(opensLane);
    expect(similarTo(first),
        [seedWirePath(start.pin.path), seedWirePath(start.openerPath)],
        reason: 'the chosen song joins More like after the pin, and the '
            'first follower\'s body carries both');
    expect(keysIn(h.seeds.moreLike), [pinKey, openerKey]);
    final chosen = h.seeds.moreLike.last;
    expect(chosen.pinned, isTrue, reason: 'added as Add song adds a song');
    expect(chosen.origin, SeedOrigin.manual);
    expect(keyOf(h.queue.value.first), openerKey,
        reason: 'the queue opens on the chosen song');
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('a Random seed in Stay close adds nothing',
      (WidgetTester tester) async {
    tag = 't9';
    final h = MediaManager().audioHandler;
    final start = await stayCloseStart(chosen: false);
    final pinKey = seedKey(start.pin.server, start.pin.path);

    await waitFor(() => djBodies.any(opensLane), 'the first follower');
    final first = djBodies.firstWhere(opensLane);
    expect(similarTo(first), [seedWirePath(start.pin.path)],
        reason: 'the pin anchors the lane; Random\'s song is not added');
    expect(keysIn(h.seeds.moreLike), [pinKey]);
    expect(keyOf(h.queue.value.first), seedKey(serverName(), start.openerPath),
        reason: 'the queue still opens on Random\'s song');
  }, timeout: const Timeout(Duration(minutes: 5)));

  /// The user plays [name], a song the mock server has not analysed yet, on
  /// the empty queue, and arms the DJ on that one-row queue: the lane's first
  /// pick runs at once, with that song playing. Returns its queue row.
  Future<MediaItem> armOnUnanalysedSong(String name) async {
    final h = MediaManager().audioHandler;
    final row = await queueAndPlay(name);
    unanalysed.add(wireOf(row));
    // Playing, not only queued: armed on an idle player, setAutoDJ plays its
    // pick at once instead of queueing it behind the user's song.
    await waitFor(() {
      final s = h.playbackState.value;
      return h.index == 0 &&
          s.playing &&
          s.processingState == AudioProcessingState.ready;
    }, 'the user\'s song to play');
    arm(djServer());
    return row;
  }

  testWidgets(
      'Drift: a song the server has not analysed blends in beside a pin; with '
      'no probe to tell, the blend leaves and the pin goes again alone',
      (WidgetTester tester) async {
    tag = 't10';
    final h = MediaManager().audioHandler;
    // A pin held aside while the DJ is off (Add song): it joins at the lane's
    // first pick, beside the song playing.
    final pin = TrackFacts(
        server: serverName(),
        path: '/demo/$tag/pin.wav',
        title: 'Pinned',
        artist: 'Someone');
    final pinKey = seedKey(pin.server, pin.path);
    h.seedAdd(SeedList.moreLike, pin);
    final fresh = await armOnUnanalysedSong('fresh');

    await waitFor(() => djBodies.length >= 2, 'the refused body and the next');
    expect(similarTo(djBodies[0]), [seedWirePath(pin.path), wireOf(fresh)],
        reason: 'the song playing blends in beside the pin');
    expect(embeddingProbes, 2,
        reason: 'each row was asked about first, and no answer could tell');
    expect(similarTo(djBodies[1]), [seedWirePath(pin.path)],
        reason: 'the refusal is laid on the blend, and the pin goes again on '
            'its own, as the lane sent it before the blend');
    await waitFor(() => h.queue.value.length >= 2, 'the pick to land');
    expect(h.sonicDrop, isNull, reason: 'the lane keeps sonic similarity');
    expect(h.seeds.has(SeedList.moreLike, keyOf(fresh)), isFalse,
        reason: 'the blend left More like');
    expect(h.seeds.moreLike.where((s) => s.key == pinKey).single.pinned,
        isTrue,
        reason: 'the pin stays as it was');
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets(
      'Drift: a blend the server has not analysed as the lane\'s one row: the '
      'refused seeds are not sent again', (WidgetTester tester) async {
    tag = 't11';
    final h = MediaManager().audioHandler;
    final fresh = await armOnUnanalysedSong('fresh');

    await waitFor(() => djBodies.length >= 2, 'the refused body and the next');
    expect(similarTo(djBodies[0]), [wireOf(fresh)],
        reason: 'the song playing blends in as the lane\'s one row');
    expect(embeddingProbes, 0, reason: 'one row sent is the one at fault');
    expect(djBodies[1].containsKey('similarTo'), isFalse,
        reason: 'with the blend out Drift falls back to that same song, '
            'which the server just refused: the pick goes without sonic '
            'similarity rather than ask again');
    await waitFor(() => h.queue.value.length >= 2, 'the pick to land');
    expect(h.sonicDrop, SonicDrop.scanning,
        reason: 'the server is still scanning, as with no blend at all');
    expect(h.seeds.has(SeedList.moreLike, keyOf(fresh)), isFalse,
        reason: 'the blend left More like');
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets(
      'Drift: a quick skip of the blended song takes it out of More like and '
      'learns nothing from it', (WidgetTester tester) async {
    tag = 't12';
    final h = MediaManager().audioHandler;
    // On, so a learned skip would show: the user's own song must not join
    // Less like all the same.
    await AutoDJManager().setLearnFromSkips(true);
    final user = await queueAndPlay('user');
    // Playing, not only queued: armed on an idle player, setAutoDJ plays its
    // pick at once instead of queueing it behind the user's song.
    await waitFor(() {
      final s = h.playbackState.value;
      return h.index == 0 &&
          s.playing &&
          s.processingState == AudioProcessingState.ready;
    }, 'the user\'s song to play');
    arm(djServer());
    expect(h.seedsTakeNegatives, isTrue,
        reason: 'a learned skip would reach the wire');

    await waitFor(() => djBodies.isNotEmpty, 'the lane\'s first pick');
    expect(similarTo(djBodies.first), [wireOf(user)],
        reason: 'the song playing blends in at the lane\'s first pick');

    // Next on the user's song a quick skip's time into it, with the pick
    // queued behind it and none out, pressed in the same turn as the look.
    ({int sentBefore, Future<void> next})? press;
    await waitFor(() {
      final at = h.position.inMilliseconds;
      if (h.index != 0 ||
          !quiet() ||
          !h.seeds.has(SeedList.moreLike, keyOf(user)) ||
          at < _skipFromMs ||
          at >= _skipBeforeMs) {
        return false;
      }
      // The first answer after the skip offers the skipped song again, as
      // a server may: no seed and never served, nothing on its side keeps
      // it out.
      serveAgain.add(wireOf(user));
      press = (sentBefore: djBodies.length, next: h.skipToNext());
      return true;
    }, 'the blended song ${_skipFromMs}ms in, with the pick queued',
        timeout: const Duration(seconds: 90));
    final p = press!;
    await within(p.next, 'the Next');
    // Judged before the seek, so the lists already show it.
    expect(h.seeds.has(SeedList.moreLike, keyOf(user)), isFalse,
        reason: 'a quick skip takes the blended song out of More like, as it '
            'does a DJ pick');
    expect(h.seeds.lessLike, isEmpty,
        reason: 'nothing is learned from the user\'s own song');

    // The answer that offers it again is passed over and the pick asks
    // once more; that second answer is the one queued.
    await waitFor(
        () => djBodies.length > p.sentBefore + 1 && h.queue.value.length >= 3,
        'the passed-over answer and the pick after it');
    expect(serveAgain, isEmpty, reason: 'the mock did offer the song again');
    final next = djBodies[p.sentBefore];
    expect(similarTo(next), isNot(contains(wireOf(user))),
        reason: 'the skipped song no longer steers the picks');
    expect(next.containsKey('lessLike'), isFalse,
        reason: 'no negative goes out');
    expect(h.queue.value.where((m) => keyOf(m) == keyOf(user)), hasLength(1),
        reason: 'the lane passes over the song the user just skipped');
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets(
      'Drift: a DJ pick an earlier lane left, blended in at a new start, keeps '
      'the DJ pick\'s rule: its quick skip is learned', (WidgetTester tester) async {
    tag = 't13';
    final h = MediaManager().audioHandler;
    await AutoDJManager().setLearnFromSkips(true);
    arm(djServer());
    // The opening pick plays and the next one waits behind it.
    await waitFor(() => h.queue.value.length >= 2 && h.index == 0,
        'the opening pick playing, the next one queued');
    final p1 = h.queue.value[1];
    expect(p1.extras?['djPick'], isTrue);

    // Stop, then Start: a new lane. The rows the old lane queued stay, and
    // its first pick runs when its last row, p1, starts: p1 is the old
    // lane's pick, so the start blends it in.
    final lane2 = djBodies.length;
    await within(h.customAction('setAutoDJ', {'autoDJServer': null}),
        'Stop');
    arm(djServer());
    await waitFor(() => djBodies.skip(lane2).any(opensLane),
        'the new lane\'s first pick');
    expect(similarTo(djBodies.skip(lane2).firstWhere(opensLane)),
        contains(wireOf(p1)),
        reason: 'the start blends in the old lane\'s pick that is playing');

    final skip = await quickSkip();
    expect(keyOf(skip.row), keyOf(p1), reason: 'the blended DJ pick');
    expect(h.seeds.has(SeedList.moreLike, keyOf(p1)), isFalse,
        reason: 'it leaves More like');
    final rows = h.seeds.lessLike.where((s) => s.key == keyOf(p1)).toList();
    expect(rows, hasLength(1),
        reason: 'a DJ pick\'s quick skip is learned, blended in or not');
    expect(rows.single.origin, SeedOrigin.skip);

    await waitFor(() => djBodies.length > skip.sentBefore,
        'the pick after the skip');
    expect(lessLike(djBodies[skip.sentBefore]), [wireOf(p1)],
        reason: 'the next body steers away from it');
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets(
      'a queue clear opens no lane on the rows it throws away: the playing '
      'last row is not blended in, and no pick goes out mid-clear',
      (WidgetTester tester) async {
    tag = 't14';
    final h = MediaManager().audioHandler;
    final user = await queueAndPlay('user');
    await waitFor(() {
      final s = h.playbackState.value;
      return h.index == 0 &&
          s.playing &&
          s.processingState == AudioProcessingState.ready;
    }, 'the user\'s song to play');
    // Every answer is empty, so the user's row stays the last one with no
    // pick behind it: the state a top-up fires on.
    answerNone = true;
    arm(djServer());
    await waitFor(() => djBodies.isNotEmpty, 'the lane\'s first pick');
    expect(similarTo(djBodies.first), [wireOf(user)],
        reason: 'the arm blended in the user\'s song');
    expect(h.queue.value, hasLength(1),
        reason: 'nothing is queued behind it, so it is the last row');
    // The arm's pick done, so none is out when the clear comes: a top-up the
    // clear's own stop sets off would otherwise return at the in-flight pick.
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final before = djBodies.length;
    await within(h.customAction('clearPlaylist'), 'the clear');
    expect(h.queue.value, isEmpty);
    expect(h.seeds.moreLike, isEmpty,
        reason: 'Drift keeps only pins through a clear: a row here is a new '
            'lane opened mid-clear on the song being thrown away');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(djBodies.skip(before), isEmpty,
        reason: 'no pick starts mid-clear, so none can land in the emptied '
            'queue; the armed DJ waits for the next queue');
    expect(h.queue.value, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets(
      'Stay close: a More like full of another server\'s songs still takes in '
      'the one song, as a ninth row, and the pick stays close to it',
      (WidgetTester tester) async {
    tag = 't15';
    final h = MediaManager().audioHandler;
    await within(h.setSeedMode(SonicAnchorMode.locked), 'Stay close');
    // Eight rows on a server the DJ won't ask, as the old server's songs
    // stay listed after a move of the DJ. Add song pins them, held aside
    // while the DJ is off; they join the lane at its first pick.
    final other = [
      for (var i = 0; i < AutoDjSeeds.maxPerList; i++)
        TrackFacts(
            server: 'other-$tag',
            path: '/demo/$tag/old_$i.wav',
            title: 'Old $i',
            artist: 'Elsewhere'),
    ];
    for (final s in other) {
      h.seedAdd(SeedList.moreLike, s);
    }
    expect(h.seeds.moreLike, hasLength(AutoDjSeeds.maxPerList));

    final user = await queueAndPlay('user');
    await waitFor(() {
      final s = h.playbackState.value;
      return h.index == 0 &&
          s.playing &&
          s.processingState == AudioProcessingState.ready;
    }, 'the user\'s song to play');
    arm(djServer());
    await waitFor(() => djBodies.isNotEmpty, 'the lane\'s first pick');
    expect(similarTo(djBodies.first), [wireOf(user)],
        reason: 'nothing in the full list can go to this server, so the song '
            'playing comes in as the one song and the pick stays close to it');
    final more = h.seeds.moreLike;
    expect(more, hasLength(AutoDjSeeds.maxPerList + 1),
        reason: 'it comes in as a ninth row');
    expect([for (final s in more.take(AutoDjSeeds.maxPerList)) s.key],
        [for (final s in other) seedKey(s.server, s.path)],
        reason: 'nothing is removed to make room');
    expect(more.last.key, keyOf(user));
    expect(more.last.origin, SeedOrigin.anchor);
  }, timeout: const Timeout(Duration(minutes: 5)));

  /// Discover's start from the song at [path] on [srv], chosen, then the
  /// checks both of its cases share: the queue opens on that song, Stay
  /// close holds it in More like as Add song would (pinned), and the first
  /// follower's body carries it.
  Future<void> discoverStartOpensOn(Server srv, String path) async {
    final h = MediaManager().audioHandler;
    final chosenKey = seedKey(serverName(), '/$path');
    final before = djBodies.length;
    await within(
        h.startSessionFromSong(
            server: srv, path: path, title: 'Chosen', chosen: true),
        'Discover\'s start');
    await waitFor(
        () =>
            h.queue.value.isNotEmpty &&
            keyOf(h.queue.value.first) == chosenKey,
        'the queue to open on the chosen song');
    final rows = h.seeds.moreLike.where((s) => s.key == chosenKey).toList();
    expect(rows, hasLength(1),
        reason: 'Stay close adds the chosen song to More like');
    expect(rows.single.pinned, isTrue, reason: 'as Add song adds a song');
    expect(rows.single.origin, SeedOrigin.manual);
    await waitFor(() => djBodies.skip(before).any(opensLane),
        'the first follower');
    expect(similarTo(djBodies.skip(before).firstWhere(opensLane)),
        contains(path),
        reason: 'the first follower stays close to the chosen song');
  }

  testWidgets(
      'Discover\'s start with the DJ off opens on its song, and Stay close '
      'pins it', (WidgetTester tester) async {
    tag = 't16';
    final h = MediaManager().audioHandler;
    await within(h.setSeedMode(SonicAnchorMode.locked), 'Stay close');
    expect(h.autoDJServer, isNull);
    await discoverStartOpensOn(djServer(), 'demo/$tag/chosen.wav');
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets(
      'Discover\'s start with the DJ already on the same server opens on its '
      'song too', (WidgetTester tester) async {
    tag = 't17';
    final h = MediaManager().audioHandler;
    await within(h.setSeedMode(SonicAnchorMode.locked), 'Stay close');
    final srv = djServer();
    arm(srv);
    await waitFor(() => djBodies.isNotEmpty && h.queue.value.isNotEmpty,
        'the cold start\'s opening pick');
    expect(h.autoDJServer, same(srv));
    await discoverStartOpensOn(srv, 'demo/$tag/chosen.wav');
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets(
      'Discover\'s start with the DJ on another server moves it to the song\'s '
      'server and opens on the song', (WidgetTester tester) async {
    tag = 't18';
    final h = MediaManager().audioHandler;
    await within(h.setSeedMode(SonicAnchorMode.locked), 'Stay close');
    final other = djServer(localname: 'it-seeds-$tag-other');
    arm(other);
    await waitFor(() => djBodies.isNotEmpty && h.queue.value.isNotEmpty,
        'the other server\'s opening pick');
    expect(h.autoDJServer, same(other));
    final srv = djServer();
    await discoverStartOpensOn(srv, 'demo/$tag/chosen.wav');
    expect(h.autoDJServer, same(srv),
        reason: 'the DJ moved to the server the song is on');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
