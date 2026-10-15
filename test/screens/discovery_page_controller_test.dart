// DiscoveryPageController (Discover page plan §3.1, §4.2, §2.13): the two
// taste calls (the library, then — once it lands — peers pinned to its
// seeds, so both sections share one batch), stale answers dropped, the
// 403 latch with ONE re-ping, no reuse of an earlier answer (every open and
// every tap asks — the server draws a new random batch of seeds each time),
// the window remembered on the phone, the visit-local pins and drops, and
// the connected servers' playable rows and album cards.
//
// Every dependency is injected — taste fetch, re-ping, the remembered
// window, clock — so nothing here touches the network or a singleton's
// state.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/discovery.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/discovery/discovery_page_controller.dart';
import 'package:mstream_music/singletons/server_list.dart';

import 'discovery_fixtures.dart';

/// A scripted taste route: records every request and answers each through
/// a completer the test resolves (or [auto] answers at once).
class FakeTaste {
  final List<TasteRequest> requests = [];
  final List<Completer<DiscoveryFetchResult<TasteResponse>>> pending = [];
  DiscoveryFetchResult<TasteResponse> Function(TasteRequest)? auto;

  Future<DiscoveryFetchResult<TasteResponse>> call(
      Server s, TasteRequest r) {
    requests.add(r);
    if (auto != null) return Future.value(auto!(r));
    final c = Completer<DiscoveryFetchResult<TasteResponse>>();
    pending.add(c);
    return c.future;
  }

  List<TasteRequest> get mainCalls =>
      requests.where((r) => !isPeersCall(r)).toList();
  List<TasteRequest> get peersCalls => requests.where(isPeersCall).toList();
}

DiscoveryFetchResult<TasteResponse> ok(Map<String, dynamic> m) =>
    DiscoveryFetchResult.ok(parse(m));

/// The usual answers: the main payload for the library, the peers one for
/// peers.
DiscoveryFetchResult<TasteResponse> answer(TasteRequest r) =>
    ok(isPeersCall(r) ? peersPayload() : mainPayload(exclude: excludeOf(r)));

void main() {
  late FakeTaste taste;
  late int repings;
  late DateTime clock;
  late Server server;
  // The phone's remembered window (SettingsManager in the app).
  late int stored;
  late List<int> saves;

  DiscoveryPageController make({
    String? pin,
    Future<void> Function(Server)? reping,
  }) =>
      DiscoveryPageController(
        server: server,
        fetch: taste.call,
        reping: reping ?? (_) async => repings++,
        readWindow: () => stored,
        saveWindow: (w) {
          stored = w;
          saves.add(w);
        },
        now: () => clock,
        pinAtOpen: pin,
      );

  setUp(() {
    taste = FakeTaste();
    repings = 0;
    clock = DateTime.utc(2026, 10, 5, 12);
    server = discoveryServer();
    stored = kTasteDefaultWindow;
    saves = [];
  });

  group('one batch per visit: peers after the library', () {
    test('the peers call waits for the library answer and is pinned to its '
        'seeds', () async {
      final c = make();
      final done = c.load();
      await Future<void>.delayed(Duration.zero);
      expect(taste.requests, hasLength(1),
          reason: 'each call draws its own batch: peers waits for the seeds');
      final main = taste.mainCalls.single.toJson();
      // The play-now page: no P2P network (a later Explore surface's).
      expect(main['sources'], ['library']);
      expect(main['limit'], {'tracks': 24, 'albums': 8});
      expect(main['window'], 30, reason: 'the window is sent on every call');
      // Discover draws no "new artists only" control, so it never thins
      // the rows unseen.
      expect(main['newArtistsOnly'], isFalse);
      expect(c.loading, isTrue);
      expect(c.loadingPeers, isTrue,
          reason: 'the section shows it is coming from the start');

      // The library lands: it is drawn at once, and only now is peers asked.
      taste.pending[0].complete(ok(mainPayload()));
      await Future<void>.delayed(Duration.zero);
      expect(c.loading, isFalse);
      expect(c.seeds, hasLength(5));
      expect(c.loadingPeers, isTrue);
      final peersBody = taste.peersCalls.single.toJson();
      expect(peersBody['sources'], ['peers']);
      expect(peersBody['window'], 30);
      expect(peersBody['newArtistsOnly'], isFalse);
      expect(peersBody['pin'], [for (final s in c.seeds) s.filepath],
          reason: "the library answer's seeds, so both sections share them");
      expect(peersBody['limit'], {'seeds': 5, 'peers': 10},
          reason: 'limit.seeds = the pins: the server adds no seed of its own');

      taste.pending[1].complete(ok(peersPayload()));
      await done;
      expect(c.loadingPeers, isFalse);
      expect(c.peers?.peers, hasLength(2));
      expect(c.library?.tracks, hasLength(5));
      // Rows are playable DisplayItems with the app's leading slash and the
      // lite-metadata flag.
      expect(c.libraryRows.first.data, '/music/Moderat/Dawn Chorus.mp3');
      expect(c.libraryRows.first.partialMetadata, isTrue);
      expect(c.albumItems.first.type, 'album');
      expect(c.albumItems.first.albumArtist, 'Tycho');
      expect(c.albumItems.first.year, 2011);
      // The faces carry no year, count or play fact: the song row's line
      // is "Artist · Album", the card's the credit alone.
      expect(c.albumItems.first.subtext, 'Tycho');
      expect(c.libraryRows.first.subtext, 'Moderat');
    });

    test('nothing the server no longer takes is ever sent', () async {
      taste.auto = answer;
      final c = make(pin: '/music/now.mp3');
      await c.load();
      await c.applySeeds(drop: {'h2'}, pins: ['/music/now.mp3']);
      await c.setWindow(90);
      for (final r in taste.requests) {
        final body = r.toJson();
        expect(body.containsKey('remember'), isFalse);
        expect(body.containsKey('filter'), isFalse);
        expect(body.containsKey('staleDays'), isFalse);
      }
    });

    test("the seeds sheet shows the batch both sections were built from",
        () async {
      // Every call draws a new batch: the fake answers each main call with
      // another one.
      var batch = 0;
      taste.auto = (r) {
        if (isPeersCall(r)) return ok(peersPayload());
        batch++;
        return ok(mainPayload(seeds: [
          for (var i = 0; i < 3; i++) seedRow('b$batch-$i', 'Song $i', 'Batch $batch'),
        ]));
      };
      final c = make();
      await c.load();
      await c.refresh();
      expect(taste.peersCalls, hasLength(2));
      final pinned = taste.peersCalls.last.toJson()['pin'];
      expect(pinned, [for (var i = 0; i < 3; i++) 'music/Batch 2/Song $i.flac']);
      expect([for (final s in c.seeds) s.filepath], pinned,
          reason: 'the picker shows the batch the peers rows came from');
    });

    test("the user's pins ride along; every seed of a full batch is pinned "
        '(12)', () async {
      taste.auto = (r) => ok(isPeersCall(r)
          ? peersPayload()
          : mainPayload(seeds: [
              seedRow('p', 'Now', 'Pinned', pinned: true),
              for (var i = 0; i < 11; i++) seedRow('h$i', 'S$i', 'A'),
            ]));
      final c = make(pin: '/music/Pinned/Now.flac');
      await c.load();
      final body = taste.peersCalls.single.toJson();
      expect(body['pin'], [
        'music/Pinned/Now.flac',
        for (var i = 0; i < 11; i++) 'music/A/S$i.flac',
      ]);
      expect((body['pin'] as List), hasLength(kTastePinMax));
      expect(body['limit'], {'seeds': 12, 'peers': 10});

      // A pin the server dropped (not visible) is not among the seeds, so
      // the peers call does not send it: the server would stop at
      // limit.seeds before reading it (the webapp pins the seeds alone).
      taste.auto = (r) => ok(isPeersCall(r)
          ? peersPayload()
          : {...mainPayload(), 'dropped': 1});
      final d = make(pin: '/music/gone.mp3');
      await d.load();
      final next = taste.peersCalls.last.toJson();
      expect(next['pin'], [for (final s in d.seeds) s.filepath]);
      expect(next['limit'], {'seeds': 5, 'peers': 10});
    });

    test('a failed library call asks no peers and keeps the rows shown',
        () async {
      taste.auto = answer;
      final c = make();
      await c.load();
      final shown = c.peers;
      taste.auto = (_) => const DiscoveryFetchResult.error();
      await c.refresh();
      expect(taste.peersCalls, hasLength(1));
      expect(c.loadingPeers, isFalse);
      expect(identical(c.peers, shown), isTrue);
    });

    test('a new batch never stands over the old batch\'s peers rows: a '
        'failed peers call shows none', () async {
      taste.auto = answer;
      final c = make();
      await c.load();
      expect(c.peers?.peers, isNotEmpty);

      taste.auto = null;
      final next = c.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(c.peers, isNotNull, reason: 'up while the library call is out');
      // The new batch lands: the old rows go, the section is loading.
      taste.pending[0]
          .complete(ok(mainPayload(seeds: [seedRow('n1', 'New', 'One')])));
      await Future<void>.delayed(Duration.zero);
      expect(c.seeds.single.hash, 'n1');
      expect(c.peers, isNull);
      expect(c.peerRows, isEmpty);
      expect(c.loadingPeers, isTrue);
      expect(c.hasConnectedServers, isTrue, reason: 'its loading line');

      // Its peers call fails: nothing is drawn, not the old batch's rows.
      taste.pending[1].complete(const DiscoveryFetchResult.error());
      await next;
      expect(c.peers, isNull);
      expect(c.peerRows, isEmpty);
      expect(c.loadingPeers, isFalse);
      expect(c.hasConnectedServers, isFalse);
    });

    test('a refresh that fails leaves the peers call of the batch on screen '
        'to land', () async {
      final c = make();
      final first = c.load();
      await Future<void>.delayed(Duration.zero);
      taste.pending[0].complete(ok(mainPayload()));
      await Future<void>.delayed(Duration.zero);
      expect(taste.peersCalls, hasLength(1));
      final shown = c.seeded;

      // The user refreshes while that peers call is out (canRefresh only
      // waits on the library call), and the new library call fails.
      expect(c.canRefresh, isTrue);
      final second = c.refresh();
      await Future<void>.delayed(Duration.zero);
      taste.pending[2].complete(const DiscoveryFetchResult.error());
      await second;
      expect(c.error, isTrue);
      expect(c.seeded, same(shown));
      expect(taste.peersCalls, hasLength(1), reason: 'no batch to pin');
      expect(c.loadingPeers, isTrue, reason: 'its peers call is still out');
      expect(c.hasConnectedServers, isTrue);

      // That call belongs to the batch still on screen: it is drawn.
      taste.pending[1].complete(ok(peersPayload()));
      await first;
      expect(c.loadingPeers, isFalse);
      expect(c.peers?.peers, hasLength(2));
    });

    test('a library answer with no seed asks no peers', () async {
      taste.auto = (r) => ok(isPeersCall(r)
          ? peersPayload()
          : {...mainPayload(seeds: const []), 'notAnalyzed': true});
      final c = make();
      await c.load();
      expect(taste.peersCalls, isEmpty);
      expect(c.loadingPeers, isFalse);
      expect(c.hasConnectedServers, isFalse);
    });

    test('no peers call when this account may not query peers', () async {
      server = discoveryServer(peers: false);
      taste.auto = answer;
      final c = make();
      await c.load();
      expect(taste.peersCalls, isEmpty);
      expect(taste.mainCalls, hasLength(1));
    });

    test('nothing is asked when the flags are off', () async {
      server.discoveryTasteAvailable = false;
      taste.auto = answer;
      final c = make();
      await c.load();
      expect(taste.requests, isEmpty, reason: 'flags, never probes');
      expect(c.available, isFalse);
    });
  });

  test('a stale answer is dropped', () async {
    final c = make();
    final first = c.load();
    await Future<void>.delayed(Duration.zero);
    final second = c.load();
    await Future<void>.delayed(Duration.zero);
    expect(taste.mainCalls, hasLength(2));

    // Main calls are pending[0] and pending[1].
    taste.pending[1].complete(ok(mainPayload(window: 7)));
    await Future<void>.delayed(Duration.zero);
    expect(taste.peersCalls, hasLength(1));
    taste.pending[2].complete(ok(peersPayload()));
    await second;
    expect(c.seeded?.window, 7);

    // The first call's late answer must not overwrite the newer one, nor
    // send a peers call of its own.
    taste.pending[0].complete(ok(mainPayload(window: 90)));
    await first;
    expect(c.seeded?.window, 7);
    expect(taste.peersCalls, hasLength(1));
    expect(repings, 0);
  });

  test('a stale peers answer is dropped, and its 403 latches nothing',
      () async {
    final c = make();
    final first = c.load();
    await Future<void>.delayed(Duration.zero);
    taste.pending[0].complete(ok(mainPayload(window: 90)));
    await Future<void>.delayed(Duration.zero);
    expect(taste.peersCalls, hasLength(1));

    // A refresh overtakes the first visit's peers call.
    final second = c.refresh();
    await Future<void>.delayed(Duration.zero);
    taste.pending[2].complete(ok(mainPayload(window: 7)));
    await Future<void>.delayed(Duration.zero);
    taste.pending[3].complete(ok(peersPayload()));
    await second;
    expect(c.peers?.peers, hasLength(2));

    taste.pending[1]
        .complete(const DiscoveryFetchResult<TasteResponse>.disabled());
    await first;
    expect(c.peersDisabled, isFalse, reason: 'a stale 403 latches nothing');
    expect(c.peers?.peers, hasLength(2));
    expect(repings, 0);
  });

  group('403', () {
    test('latches each call and re-pings exactly once', () async {
      taste.auto = (_) => const DiscoveryFetchResult.disabled();
      final c = make();
      await c.load();
      expect(c.disabled, isTrue);
      expect(taste.peersCalls, isEmpty,
          reason: 'no library seeds to pin the peers call to');
      expect(c.loadingPeers, isFalse);
      expect(repings, 1);
      // Flags survived the re-ping: discovery is on, nothing indexed yet.
      expect(c.scanPending, isTrue);

      // Latched: a reload asks nothing again.
      await c.refresh();
      expect(taste.requests, hasLength(1));
      expect(repings, 1);
    });

    test('a peers 403 latches the peers call alone, with the same one '
        're-ping', () async {
      taste.auto = (r) => isPeersCall(r)
          ? const DiscoveryFetchResult.disabled()
          : ok(mainPayload());
      final c = make();
      await c.load();
      expect(c.peersDisabled, isTrue);
      expect(c.disabled, isFalse);
      expect(repings, 1);
      await c.refresh();
      expect(taste.mainCalls, hasLength(2));
      expect(taste.peersCalls, hasLength(1), reason: 'latched');
      expect(repings, 1, reason: 'one re-ping for the page, not per call');
    });

    test('a re-ping that turns the flag off reads as switched off',
        () async {
      taste.auto = (_) => const DiscoveryFetchResult.disabled();
      final c = make(reping: (s) async {
        repings++;
        s.discoveryAvailable = false;
      });
      await c.load();
      expect(repings, 1);
      expect(c.available, isFalse);
      expect(c.scanPending, isFalse);
    });

    test('Check again re-pings, clears the latches and fetches', () async {
      taste.auto = (_) => const DiscoveryFetchResult.disabled();
      final c = make();
      await c.load();
      taste.auto = answer;
      await c.recheck();
      expect(repings, 2);
      expect(c.disabled, isFalse);
      expect(c.peersDisabled, isFalse);
      expect(taste.mainCalls, hasLength(2));
      expect(taste.peersCalls, hasLength(1));
      expect(c.seeds, isNotEmpty);
    });

    test('a transient failure keeps the rows already shown', () async {
      taste.auto = answer;
      final c = make();
      await c.load();
      taste.auto = (_) => const DiscoveryFetchResult.error();
      await c.refresh();
      expect(c.error, isTrue);
      expect(c.seeds, hasLength(5));
      expect(c.peers, isNotNull);
      expect(repings, 0);
    });
  });

  // Seeds that differ on every open are the feature: no answer is reused.
  group('every open asks', () {
    test('re-entering Discover at once asks again, for a new batch',
        () async {
      taste.auto = answer;
      final a = make();
      await a.load();
      a.dispose();
      expect(taste.requests, hasLength(2));

      final b = make();
      await b.load();
      expect(taste.requests, hasLength(4), reason: 'nothing is reused');
      expect(b.seeds, hasLength(5));
    });

    test('refresh is a plain re-ask with the same window, pins and drops',
        () async {
      taste.auto = answer;
      final c = make(pin: '/music/now.mp3');
      await c.load();
      await c.applySeeds(drop: {'h2'}, pins: ['/music/now.mp3']);
      final before = taste.mainCalls.last.toJson();
      expect(c.canRefresh, isTrue);
      await c.refresh();
      expect(taste.mainCalls.last.toJson(), before);
      expect(taste.peersCalls.last.toJson()['exclude'], ['h2']);
    });

    test('the previous answer stays up while the new one is out', () async {
      final c = make();
      final first = c.load();
      await Future<void>.delayed(Duration.zero);
      taste.pending[0].complete(answer(taste.requests[0]));
      await Future<void>.delayed(Duration.zero);
      taste.pending[1].complete(answer(taste.requests[1]));
      await first;
      final shown = c.seeded;
      final shownPeers = c.peers;

      final next = c.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(c.loading, isTrue);
      expect(c.seeded, same(shown), reason: 'no flash to placeholders');
      expect(c.peers, same(shownPeers));
      expect(c.canRefresh, isFalse, reason: 'one call at a time');

      taste.pending[2]
          .complete(ok(mainPayload(seeds: [seedRow('n1', 'New', 'One')])));
      await Future<void>.delayed(Duration.zero);
      taste.pending[3].complete(answer(taste.requests[3]));
      await next;
      expect(c.seeds.single.hash, 'n1');
    });

    test('nothing to refresh before an answer, or under the 403 latch',
        () async {
      final c = make();
      expect(c.canRefresh, isFalse);
      taste.auto = (_) => const DiscoveryFetchResult.disabled();
      await c.load();
      expect(c.canRefresh, isFalse);
    });

    test('a fresh open forgets the visit\'s pins and drops', () async {
      taste.auto = answer;
      final c = make();
      await c.load();
      await c.applySeeds(drop: {'h2'}, pins: ['/music/x.mp3']);
      expect(c.exclude, ['h2']);
      c.dispose();

      final again = make();
      await again.load();
      expect(again.pins, isEmpty);
      expect(again.exclude, isEmpty);
      final main = taste.mainCalls.last.toJson();
      expect(main.containsKey('exclude'), isFalse);
      expect(main.containsKey('pin'), isFalse);
    });
  });

  group('the window', () {
    test('the remembered window is asked for from the first call', () async {
      stored = 90;
      taste.auto = answer;
      final c = make();
      expect(c.window, 90);
      await c.load();
      expect(taste.mainCalls.single.toJson()['window'], 90);
      expect(taste.peersCalls.single.toJson()['window'], 90);
    });

    test('a remembered window the route would refuse reads as the default',
        () {
      stored = 45;
      expect(make().window, kTasteDefaultWindow);
    });

    test('the bar re-asks every source with the visit\'s pins and drops, and '
        'the phone remembers it', () async {
      taste.auto = answer;
      final c = make(pin: '/music/pinned.mp3');
      await c.load();
      await c.applySeeds(drop: {'h2'}, pins: ['/music/pinned.mp3']);
      taste.requests.clear();

      await c.setWindow(90);
      expect(c.window, 90);
      expect(saves, [90]);
      final main = taste.mainCalls.single.toJson();
      expect(main['window'], 90);
      expect(main['exclude'], ['h2']);
      expect(main['pin'], ['music/pinned.mp3']);
      final peers = taste.peersCalls.single.toJson();
      expect(peers['window'], 90);
      expect(peers['exclude'], ['h2']);
      expect(peers['pin'], [for (final s in c.seeds) s.filepath],
          reason: "the new answer's seeds (accepted pins are among them)");

      // The next open starts from it.
      expect(make().window, 90);
    });

    test('choosing the window already in force asks nothing', () async {
      taste.auto = answer;
      final c = make();
      await c.load();
      taste.requests.clear();
      await c.setWindow(c.window);
      expect(taste.requests, isEmpty);
      expect(saves, isEmpty);
    });

    test('after widening, the bar keeps the window asked for, and All time '
        'is a change', () async {
      // The server reports the window that produced seeds (0) and the one
      // asked for in widenedFrom.
      taste.auto = (r) => ok(isPeersCall(r)
          ? peersPayload()
          : {...mainPayload(window: 0), 'widenedFrom': 30});
      final c = make();
      await c.load();
      expect(c.seeded?.window, 0);
      expect(c.window, 30, reason: 'what the bar shows');
      await c.setWindow(0);
      expect(taste.mainCalls.last.toJson()['window'], 0);
    });

    test('a failed window change puts the old one back, remembered too',
        () async {
      taste.auto = answer;
      final c = make();
      await c.load();
      taste.auto = (_) => const DiscoveryFetchResult.error();
      await c.setWindow(7);
      expect(c.error, isTrue);
      expect(c.window, 30, reason: 'the rows shown are still the 30-day ones');
      expect(stored, 30);
      expect(c.library?.tracks, hasLength(5));

      taste.auto = answer;
      await c.refresh();
      expect(taste.mainCalls.last.toJson()['window'], 30);
    });

    test('a failed window change puts the peers rows back too', () async {
      taste.auto = answer;
      final c = make();
      await c.load();
      final before = c.peers;
      expect(before?.peers, isNotEmpty);
      // Main fails, so no peers call goes out (had one, it would answer
      // over the new window).
      taste.auto = (r) => isPeersCall(r)
          ? ok({
              'peers': {'peers': [], 'searched': {'peers': 0}}
            })
          : const DiscoveryFetchResult.error();
      await c.setWindow(90);
      expect(c.window, 30);
      expect(identical(c.peers, before), isTrue,
          reason: 'both sections from the window the bar shows');
    });

    test('under the 403 latch the window does not move and nothing is '
        'asked', () async {
      taste.auto = (_) => const DiscoveryFetchResult.disabled();
      final c = make();
      await c.load();
      expect(c.disabled, isTrue);
      taste.requests.clear();
      await c.setWindow(90);
      expect(c.window, 30);
      expect(saves, isEmpty);
      expect(taste.requests, isEmpty);
    });
  });

  group('the seed picker', () {
    test('a dropped seed is sent as exclude on both calls, for this visit',
        () async {
      taste.auto = answer;
      final c = make();
      await c.load();
      expect(taste.mainCalls.single.toJson().containsKey('exclude'), isFalse);

      await c.applySeeds(drop: {'h2'}, pins: []);
      expect(taste.mainCalls.last.toJson()['exclude'], ['h2']);
      expect(taste.peersCalls.last.toJson()['exclude'], ['h2']);

      // It stays out for the rest of the visit.
      await c.refresh();
      expect(taste.mainCalls.last.toJson()['exclude'], ['h2']);
      await c.applySeeds(drop: {'h3'}, pins: []);
      expect(taste.mainCalls.last.toJson()['exclude'], ['h2', 'h3']);
    });

    test('"Use again" takes it out of the list and asks again', () async {
      taste.auto = answer;
      final c = make();
      await c.load();
      await c.applySeeds(drop: {'h2', 'h3'}, pins: []);
      final calls = taste.mainCalls.length;
      await c.applySeeds(restore: {'h2'}, pins: []);
      expect(taste.mainCalls, hasLength(calls + 1));
      expect(taste.mainCalls.last.toJson()['exclude'], ['h3']);
      expect(c.exclude, ['h3']);
    });

    test('the dropped list is the answer\'s excluded rows', () async {
      taste.auto = answer;
      final c = make();
      await c.load();
      expect(c.excluded, isEmpty, reason: 'nothing dropped on a fresh visit');
      await c.applySeeds(drop: {'h2'}, pins: []);
      expect(c.excluded.map((e) => e.hash), ['h2']);
      await c.applySeeds(restore: {'h2'}, pins: []);
      expect(c.excluded, isEmpty);
    });

    test('pins replace the visit\'s pins; unpinning asks without it',
        () async {
      taste.auto = answer;
      final c = make(pin: '/music/now.mp3');
      await c.load();
      await c.applySeeds(pins: ['/music/now.mp3', 'music/picked.mp3']);
      expect(taste.mainCalls.last.toJson()['pin'],
          ['music/now.mp3', 'music/picked.mp3']);
      expect(c.pins, ['/music/now.mp3', '/music/picked.mp3']);

      await c.applySeeds(pins: ['/music/picked.mp3']);
      expect(taste.mainCalls.last.toJson()['pin'], ['music/picked.mp3']);
      expect(c.pins, ['/music/picked.mp3']);
    });

    test('at most twelve pins (= the seed limit)', () async {
      taste.auto = answer;
      final c = make();
      await c.load();
      await c.applySeeds(pins: [for (var i = 0; i < 14; i++) '/music/$i.mp3']);
      expect(kTastePinMax, 12);
      expect(c.pins, hasLength(kTastePinMax));
    });
  });

  group('pins', () {
    test('the song playing at open is pinned, without its slash', () async {
      taste.auto = answer;
      final c = make(pin: '/music/ALM/Manor.flac');
      await c.load();
      expect(taste.mainCalls.single.toJson()['pin'], ['music/ALM/Manor.flac']);
      // The peers call pins the library answer's seeds — the server lists
      // an accepted pin among them.
      expect(taste.peersCalls.single.toJson()['pin'],
          [for (final s in c.seeds) s.filepath]);
    });

    test('it stays the open-time song: a refresh does not re-read playback',
        () async {
      taste.auto = answer;
      final c = make(pin: '/music/ALM/Manor.flac');
      await c.load();
      await c.refresh();
      expect(taste.mainCalls.last.toJson()['pin'], ['music/ALM/Manor.flac']);
      expect(c.pins, ['/music/ALM/Manor.flac']);
    });

    test('no pin when nothing was playing', () async {
      taste.auto = answer;
      final c = make();
      await c.load();
      expect(taste.mainCalls.single.toJson().containsKey('pin'), isFalse);
    });

    test('"Choose a song…" pins one more and asks again', () async {
      taste.auto = answer;
      final c = make();
      await c.load();
      await c.pinSong('music/Chosen.mp3');
      expect(taste.mainCalls.last.toJson()['pin'], ['music/Chosen.mp3']);
      expect(c.pins, ['/music/Chosen.mp3']);
    });
  });

  group('the random pick', () {
    Map<String, dynamic> randomPayload(String hash) => mainPayload(
        seedSource: 'random',
        fallback: true,
        network: false,
        seeds: [seedRow(hash, 'Pick $hash', 'Someone')]);

    test('the random fallback is recognised', () async {
      taste.auto = (r) =>
          ok(isPeersCall(r) ? {'peers': null} : randomPayload('hr'));
      final c = make();
      await c.load();
      expect(c.isRandom, isTrue);
      // The server asks no connected server for a random seed, so no
      // peers call is made (a pin would make it ask).
      expect(taste.peersCalls, isEmpty);
      expect(c.loadingPeers, isFalse);
      expect(c.peers, isNull);
      expect(c.hasConnectedServers, isFalse);
    });

    test('a random answer after a seeded one clears the connected-server '
        'rows', () async {
      taste.auto = answer;
      final c = make();
      await c.load();
      expect(c.peers, isNotNull);
      taste.auto = (r) => ok(randomPayload('hr'));
      await c.refresh();
      expect(taste.peersCalls, hasLength(1));
      expect(c.peers, isNull);
      expect(c.peerRows, isEmpty);
      expect(c.hasConnectedServers, isFalse);
    });

    test('Another pick asks again with the pick on screen passed over, and '
        'never lists it as dropped', () async {
      taste.auto = (r) {
        if (isPeersCall(r)) return ok({'peers': null});
        final ex = (r.toJson()['exclude'] as List?)?.cast<String>() ?? [];
        final pick = ['r1', 'r2', 'r3'].firstWhere((h) => !ex.contains(h));
        return ok({
          ...randomPayload(pick),
          'excluded': [
            for (final h in ex)
              {'hash': h, 'filepath': 'music/$h.mp3', 'metadata': {}},
          ],
        });
      };
      final c = make();
      await c.load();
      expect(c.seeds.single.hash, 'r1');

      await c.anotherPick();
      expect(taste.mainCalls.last.toJson()['exclude'], ['r1']);
      expect(c.seeds.single.hash, 'r2');
      expect(c.excluded, isEmpty, reason: 'a passed pick was never dropped');

      await c.anotherPick();
      expect(taste.mainCalls.last.toJson()['exclude'], ['r1', 'r2']);
      expect(c.seeds.single.hash, 'r3');
    });

    test('past the last song to draw, Another pick starts over instead of '
        'showing a false scan-pending card', () async {
      taste.auto = (r) {
        if (isPeersCall(r)) return ok({'peers': null});
        final ex = excludeOf(r);
        final left = ['r1', 'r2'].where((h) => !ex.contains(h)).toList();
        if (left.isEmpty) {
          // The server's answer when its random draw finds nothing.
          return ok({
            ...mainPayload(
                seedSource: 'random',
                fallback: true,
                network: false,
                seeds: const [],
                exclude: ex),
            'notAnalyzed': true,
          });
        }
        return ok(randomPayload(left.first));
      };
      final c = make();
      await c.load();
      await c.anotherPick();
      expect(c.seeds.single.hash, 'r2');

      expect(taste.mainCalls, hasLength(2));

      await c.anotherPick();
      expect(taste.mainCalls, hasLength(4),
          reason: 'the empty answer, then exactly one re-ask');
      expect(taste.mainCalls[2].toJson()['exclude'], ['r1', 'r2']);
      expect(taste.mainCalls[3].toJson().containsKey('exclude'), isFalse,
          reason: 'the passed picks are let go');
      expect(c.passed, isEmpty);
      expect(c.seeds.single.hash, 'r1');
      expect(c.scanPending, isFalse);
      expect(c.loading, isFalse);
    });

    test('a history answer still scanning is no "no pick left": no re-ask',
        () async {
      var calls = 0;
      taste.auto = (r) {
        if (isPeersCall(r)) return ok({'peers': null});
        calls++;
        return ok(calls == 1
            ? randomPayload('r1')
            : {...mainPayload(), 'notAnalyzed': true});
      };
      final c = make();
      await c.load();
      await c.anotherPick();
      expect(taste.mainCalls, hasLength(2));
      expect(c.passed, ['r1']);
      expect(c.scanPending, isTrue);
    });

    test('Another pick passes over the pick on screen; the passed picks '
        'ride on every call of the visit', () async {
      // Fresh per call: the fake draws the next pick on every plain call.
      final order = ['r1', 'r2', 'r3', 'r4'];
      var plain = 0;
      taste.auto = (r) {
        final ex = excludeOf(r);
        final pick = ex.isEmpty
            ? order[plain++ % order.length]
            : order.firstWhere((h) => !ex.contains(h));
        return ok(randomPayload(pick));
      };
      final c = make();
      await c.load();
      await c.refresh();
      expect(taste.mainCalls.last.toJson().containsKey('exclude'), isFalse);
      expect(c.seeds.single.hash, 'r2');
      expect(c.passed, isEmpty, reason: 'a refresh passes nothing over');

      await c.anotherPick();
      expect(taste.mainCalls.last.toJson()['exclude'], ['r2']);
      expect(c.passed, ['r2']);
      expect(c.seeds.single.hash, 'r1');

      await c.refresh();
      expect(taste.mainCalls.last.toJson()['exclude'], ['r2'],
          reason: 'passed over for the rest of the visit');
    });

    test('Check again lets the passed picks go', () async {
      taste.auto = (r) {
        final ex = excludeOf(r);
        return ok(randomPayload(
            ['r1', 'r2', 'r3'].firstWhere((h) => !ex.contains(h))));
      };
      final c = make();
      await c.load();
      await c.anotherPick();
      expect(taste.mainCalls.last.toJson()['exclude'], ['r1']);
      expect(c.passed, ['r1']);
      await c.recheck();
      expect(taste.mainCalls.last.toJson().containsKey('exclude'), isFalse);
      expect(c.passed, isEmpty);
      await c.anotherPick();
      expect(taste.mainCalls.last.toJson()['exclude'], ['r1']);
    });

    test('the drops come first in exclude, and keep their room under the '
        'cap', () async {
      taste.auto = (r) => ok(randomPayload('r1'));
      final c = make();
      await c.load();
      await c.applySeeds(drop: {'h9'}, pins: []);
      expect(taste.mainCalls.last.toJson()['exclude'], ['h9']);
      await c.anotherPick();
      expect(taste.mainCalls.last.toJson()['exclude'], ['h9', 'r1']);

      // A full list of drops leaves no room: the passed pick gives way.
      await c.applySeeds(
          drop: {for (var i = 0; i < kTasteExcludeMax; i++) 'd$i'}, pins: []);
      final ex = excludeOf(taste.mainCalls.last);
      expect(ex, hasLength(kTasteExcludeMax));
      expect(ex, isNot(contains('r1')));
      expect(ex.last, 'd${kTasteExcludeMax - 1}');
    });
  });

  // Peers rows play through the parent's federation stream proxy: as a row
  // on the peer's virtual Server, which ServerManager mirrors from this
  // server's peer list (plan §1, §4.2).
  group('peer rows', () {
    late DiscoveryLead lead;

    setUp(() async {
      ServerManager().serverList.clear();
      taste.auto = answer;
      final c = make();
      await c.load();
      lead = c.peers!.allResults.single;
    });
    tearDown(() => ServerManager().serverList.clear());

    Server peer(int id, {String parent = 'home'}) =>
        Server('federated://$parent/$id', null, null, null, 'peer-$id')
          ..federationParent = parent
          ..federationPeerId = id;

    test('a mirrored peer gives a playable row on its virtual Server',
        () async {
      final sam = peer(7)..parentServer = server;
      ServerManager().serverList.addAll([server, peer(9), sam]);
      final c = make();
      final row = c.peerTrackItem(lead);
      expect(c.peerServerFor(lead), same(sam));
      expect(row, isNotNull);
      expect(row!.server, same(sam));
      expect(row.type, 'file');
      expect(row.data, '/sam/Kiasmos/Blurred.flac',
          reason: 'the app path carries the slash the wire path lacks');
      expect(row.partialMetadata, isTrue,
          reason: 'a lead is a handful of fields: fetch the full block');
      expect(row.metadata?.title, 'Blurred EP');
      expect(row.metadata?.artist, 'Kiasmos');
    });

    test('the connected servers\' rows: answered peers only, mirrored only, '
        'with a path, best match first', () async {
      ServerManager().serverList.addAll([
        server,
        peer(7)..parentServer = server,
        peer(8)..parentServer = server,
        peer(10)..parentServer = server,
        peer(11)..parentServer = server,
      ]);
      taste.auto = (r) =>
          ok(isPeersCall(r) ? manyPeersPayload() : mainPayload());
      final c = make();
      await c.load();
      // Kim is not mirrored, Ola offline, Ivo on another model, Echo has
      // no path: none of them is drawn.
      expect([for (final r in c.peerRows) r.metadata?.title],
          ['Bravo', 'Delta', 'Alpha', 'Charlie']);
      expect(c.peerRows.first.server?.federationPeerId, 7);
      expect(c.peerRows.first.subtext, 'Kiasmos · Blurred');
      expect(c.peerRows[3].subtext, 'Ólafur Arnalds');
      // Three paired servers answered: "… from connected servers".
      expect(c.connectedServerName, isNull);
      expect(c.hasConnectedServers, isTrue);
    });

    test('the album cards: grouped by server + album + artist, ranked by '
        'their best row, art from the first row that has it', () async {
      ServerManager().serverList.addAll([
        server,
        peer(7)..parentServer = server,
        peer(8)..parentServer = server,
      ]);
      taste.auto = (r) =>
          ok(isPeersCall(r) ? manyPeersPayload() : mainPayload());
      final c = make();
      await c.load();
      final albums = c.peerAlbumItems;
      expect([for (final a in albums) a.name], ['Blurred', 'Persona'],
          reason: 'Charlie has no album tag; Echo cannot play');
      expect(albums.first.type, 'album');
      expect(albums.first.data, 'Blurred');
      expect(albums.first.server?.federationPeerId, 7,
          reason: 'opens in the album detail through that peer');
      expect(albums.first.subtext, 'Kiasmos');
      expect(albums.first.altAlbumArt, 'blurred.jpg');
      expect(albums.first.year, isNull);
      expect(albums.first.albumArtist, isNull,
          reason: 'a track artist is not the album credit');
      expect(albums.first.trackArtist, 'Kiasmos',
          reason: 'opened by name + the artist filter, as the webapp does, '
              'so same-named albums on the peer do not merge');
      expect(albums.last.altAlbumArt, isNull);
    });

    test('one connected server answered: it is named', () async {
      ServerManager().serverList.addAll([server, peer(7)..parentServer = server]);
      final c = make();
      await c.load();
      expect(c.connectedServerName, "Sam's server",
          reason: "Lee's server did not answer");
      expect(c.peerRows.single.metadata?.title, 'Blurred EP');
      expect(c.peerAlbumItems, isEmpty, reason: 'the row has no album tag');
    });

    test('no paired server: no connected-server section at all', () async {
      taste.auto = (r) => ok(isPeersCall(r)
          ? {
              'peers': {'peers': [], 'searched': {'peers': 0}}
            }
          : mainPayload());
      final c = make();
      await c.load();
      expect(c.peers?.peers, isEmpty);
      expect(c.hasConnectedServers, isFalse);
    });

    test('an unmirrored peer, or one under another parent, gives no row',
        () async {
      ServerManager().serverList.addAll([server, peer(7, parent: 'elsewhere')]);
      final c = make();
      expect(c.peerServerFor(lead), isNull);
      expect(c.peerTrackItem(lead), isNull);
    });
  });
}
