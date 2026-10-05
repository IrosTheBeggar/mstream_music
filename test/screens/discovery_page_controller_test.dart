// DiscoveryPageController (Discover page plan §3.1, §4.2): the two parallel
// taste calls, stale answers dropped, the 403 latch with ONE re-ping, the
// five-minute client TTL, remembered exclusions, pins at open only.
//
// Every dependency is injected — taste fetch, prefs, re-ping, random pick,
// clock — so nothing here touches the network or a singleton's state.

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

/// The usual answers: the main payload for library + network, the peers one
/// for peers.
DiscoveryFetchResult<TasteResponse> answer(TasteRequest r) =>
    ok(isPeersCall(r) ? peersPayload() : mainPayload());

void main() {
  late FakeTaste taste;
  late int repings;
  late DateTime clock;
  late Server server;

  DiscoveryPageController make({
    String? pin,
    Future<void> Function(Server)? reping,
    Future<DiscoveryFetchResult<TastePrefs>> Function(Server)? fetchPrefs,
    Future<DiscoveryFetchResult<TastePrefs>> Function(Server, TastePrefs)?
        savePrefs,
    Future<String?> Function(Server)? randomPick,
  }) =>
      DiscoveryPageController(
        server: server,
        fetch: taste.call,
        fetchPrefs: fetchPrefs ??
            (_) async => const DiscoveryFetchResult.ok(TastePrefs()),
        savePrefs: savePrefs ??
            (_, p) async => DiscoveryFetchResult.ok(p),
        reping: reping ?? (_) async => repings++,
        randomPick: randomPick ?? (_) async => null,
        newArtistsOnly: () => false,
        now: () => clock,
        pinAtOpen: pin,
      );

  setUp(() {
    DiscoveryPageController.clearCache();
    taste = FakeTaste();
    repings = 0;
    clock = DateTime.utc(2026, 10, 5, 12);
    server = discoveryServer();
  });

  group('two parallel requests', () {
    test('library + network and peers go out together, before either '
        'answers', () async {
      final c = make();
      final done = c.load();
      await Future<void>.delayed(Duration.zero);
      expect(taste.requests, hasLength(2), reason: 'both in flight at once');
      final main = taste.mainCalls.single.toJson();
      expect(main['sources'], ['library', 'network']);
      expect(main['limit'], {'tracks': 24, 'albums': 8, 'network': 12});
      expect(taste.peersCalls.single.toJson()['sources'], ['peers']);
      expect(c.loading, isTrue);
      expect(c.loadingPeers, isTrue);

      // The peers answer first: the library is not held up by it, nor it
      // by the library.
      taste.pending[1].complete(ok(peersPayload()));
      await Future<void>.delayed(Duration.zero);
      expect(c.peers?.peers, hasLength(2));
      expect(c.seeded, isNull);

      taste.pending[0].complete(ok(mainPayload()));
      await done;
      expect(c.loading, isFalse);
      expect(c.seeds, hasLength(5));
      expect(c.library?.tracks, hasLength(5));
      expect(c.network?.results.single.title, 'Says');
      // Rows are playable DisplayItems with the app's leading slash and the
      // lite-metadata flag.
      expect(c.libraryRows.first.data, '/music/Moderat/Dawn Chorus.mp3');
      expect(c.libraryRows.first.partialMetadata, isTrue);
      expect(c.albumItems.first.type, 'album');
      expect(c.albumItems.first.albumArtist, 'Tycho');
      expect(c.albumItems.first.year, 2011);
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
    final first = c.load(force: true);
    await Future<void>.delayed(Duration.zero);
    final second = c.load(force: true);
    await Future<void>.delayed(Duration.zero);
    expect(taste.mainCalls, hasLength(2));

    // Main calls are pending[0] and pending[2]; peers [1] and [3].
    taste.pending[2].complete(ok(mainPayload(window: 7)));
    taste.pending[3].complete(ok(peersPayload()));
    await second;
    expect(c.seeded?.window, 7);

    // The first call's late answer must not overwrite the newer one.
    taste.pending[0].complete(ok(mainPayload(window: 90)));
    taste.pending[1].complete(
        const DiscoveryFetchResult<TasteResponse>.disabled());
    await first;
    expect(c.seeded?.window, 7);
    expect(c.peersDisabled, isFalse, reason: 'a stale 403 latches nothing');
    expect(repings, 0);
  });

  group('403', () {
    test('latches each call and re-pings exactly once', () async {
      taste.auto = (_) => const DiscoveryFetchResult.disabled();
      final c = make();
      await c.load();
      expect(c.disabled, isTrue);
      expect(c.peersDisabled, isTrue);
      expect(repings, 1, reason: 'one re-ping for the page, not per call');
      // Flags survived the re-ping: discovery is on, nothing indexed yet.
      expect(c.scanPending, isTrue);

      // Latched: a reload asks neither call again.
      await c.load(force: true);
      expect(taste.requests, hasLength(2));
      expect(repings, 1);
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
      expect(taste.requests, hasLength(4));
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

  group('client TTL', () {
    test('re-entering within five minutes does not refetch', () async {
      taste.auto = answer;
      final a = make();
      await a.load();
      a.dispose();
      expect(taste.requests, hasLength(2));

      clock = clock.add(const Duration(minutes: 4));
      final b = make();
      await b.load();
      expect(taste.requests, hasLength(2), reason: 'served from the cache');
      expect(b.seeds, hasLength(5));
      expect(b.peers?.peers, hasLength(2));
      b.dispose();

      clock = clock.add(const Duration(minutes: 2));
      final c = make();
      await c.load();
      expect(taste.requests, hasLength(4), reason: 'stale after 5 minutes');
    });

    test('refresh always fetches; a different pin is a different visit',
        () async {
      taste.auto = answer;
      final a = make();
      await a.load();
      await a.refresh();
      expect(taste.requests, hasLength(4));
      a.dispose();

      final b = make(pin: '/music/Other/Song.mp3');
      await b.load();
      expect(taste.requests, hasLength(6));
    });

    test('a visit left before its peers landed still fetches them',
        () async {
      final a = make();
      final done = a.load();
      await Future<void>.delayed(Duration.zero);
      taste.pending[0].complete(ok(mainPayload()));
      await Future<void>.delayed(Duration.zero);
      a.dispose();
      taste.pending[1].complete(ok(peersPayload()));
      await done;

      taste.auto = answer;
      final b = make();
      await b.load();
      expect(taste.mainCalls, hasLength(1), reason: 'library from the cache');
      expect(taste.peersCalls, hasLength(2));
      expect(b.peers?.peers, hasLength(2));
    });

    // The peers call stores the snapshot too, so a snapshot can hold no
    // library answer. Restoring it as a hit left the page on a spinner
    // nothing was loading.
    test('peers landed, main left in flight: the reopen asks main again',
        () async {
      final a = make();
      final done = a.load();
      await Future<void>.delayed(Duration.zero);
      taste.pending[1].complete(ok(peersPayload()));
      await Future<void>.delayed(Duration.zero);
      a.dispose();
      taste.pending[0].complete(ok(mainPayload()));
      await done;

      taste.auto = answer;
      final b = make();
      final reopened = b.load();
      expect(b.loading, isTrue, reason: 'in flight, so the spinner is true');
      await reopened;
      expect(taste.mainCalls, hasLength(2));
      expect(taste.peersCalls, hasLength(1), reason: 'peers from the cache');
      expect(b.seeded, isNotNull);
      expect(b.peers?.peers, hasLength(2));
    });

    test('main failed, peers landed: the reopen asks main again', () async {
      taste.auto = (r) => isPeersCall(r)
          ? ok(peersPayload())
          : const DiscoveryFetchResult.error();
      final a = make();
      await a.load();
      expect(a.error, isTrue);
      a.dispose();

      taste.auto = answer;
      final b = make();
      await b.load();
      expect(taste.mainCalls, hasLength(2));
      expect(b.seeds, hasLength(5));
      expect(b.error, isFalse);
    });

    test('main refused, peers landed: the reopen asks main again and the '
        'refusal reads as scan pending', () async {
      taste.auto = (r) => isPeersCall(r)
          ? ok(peersPayload())
          : const DiscoveryFetchResult.disabled();
      final a = make();
      await a.load();
      a.dispose();

      final b = make();
      await b.load();
      expect(taste.mainCalls, hasLength(2),
          reason: 'a new controller inherits no latch');
      expect(b.disabled, isTrue);
      expect(b.scanPending, isTrue);
      expect(repings, 2, reason: 'one re-ping per page');
    });

    test('the cache is per account, not only per server entry', () async {
      taste.auto = answer;
      server.username = 'alice';
      final a = make();
      await a.load();
      a.dispose();

      // The same entry edited to another account keeps its localname.
      server = discoveryServer()..username = 'bob';
      final b = make();
      await b.load();
      expect(taste.mainCalls, hasLength(2), reason: "not alice's rows");
    });
  });

  group('steering', () {
    test('a dropped seed is sent as exclude with remember', () async {
      taste.auto = answer;
      final c = make();
      await c.load();
      expect(taste.mainCalls.single.toJson().containsKey('remember'), isFalse,
          reason: 'nothing chosen yet: the saved prefs apply');

      await c.applySeeds(window: c.effectiveWindow, drop: {'h2'}, pins: []);
      final main = taste.mainCalls.last.toJson();
      expect(main['exclude'], ['h2']);
      expect(main['remember'], isTrue);
      expect(main.containsKey('window'), isFalse,
          reason: 'the window did not change');
      final peers = taste.peersCalls.last.toJson();
      expect(peers['exclude'], ['h2'],
          reason: 'the same seeds, so the same centroid');
      expect(peers.containsKey('remember'), isFalse,
          reason: 'saved once, by the main call');
    });

    test('a changed window is sent and remembered', () async {
      taste.auto = answer;
      final c = make();
      await c.load();
      await c.applySeeds(window: 90, pins: []);
      final main = taste.mainCalls.last.toJson();
      expect(main['window'], 90);
      expect(main['remember'], isTrue);
    });

    test('after widening, the window is the one asked for, and All time is '
        'a change', () async {
      // The server reports the window that produced seeds (0) and the one
      // asked for in widenedFrom.
      taste.auto = (r) => ok(isPeersCall(r)
          ? peersPayload()
          : {...mainPayload(window: 0), 'widenedFrom': 30});
      final c = make();
      await c.load();
      expect(c.seeded?.window, 0);
      expect(c.effectiveWindow, 30, reason: 'what the sheet starts on');

      await c.applySeeds(window: 0, pins: []);
      final main = taste.mainCalls.last.toJson();
      expect(main['window'], 0, reason: 'All time chosen, so sent');
      expect(main['remember'], isTrue);
    });

    test('a restored seed leaves the saved exclusions', () async {
      taste.auto = answer;
      TastePrefs? saved;
      final c = make(
        fetchPrefs: (_) async => const DiscoveryFetchResult.ok(
            TastePrefs(exclude: ['h-old', 'h-dropped'])),
        savePrefs: (_, p) async {
          saved = p;
          return DiscoveryFetchResult.ok(p);
        },
      );
      await c.load();
      expect(
          await c.applySeeds(
              window: c.effectiveWindow, restore: {'h-dropped'}, pins: []),
          isTrue);
      expect(saved?.toJson(), {
        'exclude': ['h-old']
      });
    });

    test('a restore whose write fails reports it', () async {
      taste.auto = answer;
      final c = make(
        fetchPrefs: (_) async => const DiscoveryFetchResult.ok(
            TastePrefs(exclude: ['h-dropped'])),
        savePrefs: (_, p) async => const DiscoveryFetchResult.error(),
      );
      await c.load();
      expect(
          await c.applySeeds(
              window: c.effectiveWindow, restore: {'h-dropped'}, pins: []),
          isFalse);
      expect(taste.mainCalls, hasLength(2), reason: 'the refetch still runs');
    });

    test('a failed prefs read saves nothing (it would wipe the list)',
        () async {
      taste.auto = answer;
      var saves = 0;
      final c = make(
        fetchPrefs: (_) async => const DiscoveryFetchResult.error(),
        savePrefs: (_, p) async {
          saves++;
          return DiscoveryFetchResult.ok(p);
        },
      );
      await c.load();
      expect(
          await c.applySeeds(
              window: c.effectiveWindow, restore: {'h-dropped'}, pins: []),
          isFalse,
          reason: 'the server still excludes it: the page must say so');
      expect(saves, 0);
    });

    test('the filter refetches library + network only, remembered',
        () async {
      taste.auto = answer;
      final c = make();
      await c.load();
      await c.setFilter(TasteFilter.unplayed);
      expect(taste.mainCalls, hasLength(2));
      expect(taste.peersCalls, hasLength(1), reason: 'peers ignore the filter');
      final main = taste.mainCalls.last.toJson();
      expect(main['filter'], 'unplayed');
      expect(main['remember'], isTrue);
    });

    test('a failed filter change puts the old choice back', () async {
      taste.auto = answer;
      final c = make();
      await c.load();
      taste.auto = (_) => const DiscoveryFetchResult.error();
      await c.setFilter(TasteFilter.unplayed);
      expect(c.error, isTrue);
      expect(c.effectiveFilter, TasteFilter.fresh,
          reason: 'the rows shown are still the fresh ones');
      expect(c.library?.tracks, hasLength(5));

      taste.auto = answer;
      await c.refresh();
      expect(taste.mainCalls.last.toJson().containsKey('filter'), isFalse,
          reason: 'a filter that never landed is not remembered');
    });
  });

  group('pins', () {
    test('the song playing at open is pinned, without its slash', () async {
      taste.auto = answer;
      final c = make(pin: '/music/ALM/Manor.flac');
      await c.load();
      expect(taste.mainCalls.single.toJson()['pin'], ['music/ALM/Manor.flac']);
      expect(taste.peersCalls.single.toJson()['pin'], ['music/ALM/Manor.flac']);
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

    test('Another pick pins a random library song', () async {
      taste.auto = answer;
      final c = make(randomPick: (_) async => '/music/Random/Pick.mp3');
      await c.load();
      expect(await c.anotherPick(), isTrue);
      expect(taste.mainCalls.last.toJson()['pin'], ['music/Random/Pick.mp3']);
    });

    test('Another pick with nothing to pick changes nothing', () async {
      taste.auto = answer;
      final c = make();
      await c.load();
      expect(await c.anotherPick(), isFalse);
      expect(taste.mainCalls, hasLength(1));
    });
  });

  test('the random fallback is recognised', () async {
    taste.auto = (r) => ok(isPeersCall(r)
        ? {'peers': null}
        : mainPayload(
            seedSource: 'random',
            fallback: true,
            network: false,
            seeds: [seedRow('hr', 'Pick', 'Someone')]));
    final c = make();
    await c.load();
    expect(c.isRandom, isTrue);
    expect(c.network, isNull);
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

    test('an unmirrored peer, or one under another parent, gives no row',
        () async {
      ServerManager().serverList.addAll([server, peer(7, parent: 'elsewhere')]);
      final c = make();
      expect(c.peerServerFor(lead), isNull);
      expect(c.peerTrackItem(lead), isNull);
    });
  });
}
