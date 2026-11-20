// PeerRecsController (mStream docs/peer-recommendations-plan.md §3.5 R1–R8;
// the phone build plan's piece I): the page's asks — R1's body, a tab's ask
// pinned on the batch, each tab's answer kept for the batch, the last ask
// winning — New seeds, the window and the seeds sheet; the strip's poll
// (its cadence, one timer, covered and backgrounded, late answers, redraws
// only on a change, a missing route); an admin's Add and what each answer
// means; R4's re-asks and their wait while the list is held; the states;
// and R7's re-ping. Each test names the webapp test it ports
// (test/unit/webapp-discovery-panel.test.mjs unless it says otherwise).
//
// Every dependency is a fake (peer_recs_fakes.dart): nothing touches the
// network, a timer of the clock's or a singleton's state.

import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/discovery.dart';
import 'package:mstream_music/objects/peer_recs.dart';
import 'package:mstream_music/screens/discovery/peer_recs_controller.dart';
import 'package:mstream_music/singletons/settings.dart';
import 'package:mstream_music/util/peer_recs_rules.dart';

import '../discovery_plugin_fakes.dart';
import 'peer_recs_fakes.dart';
import 'peer_recs_fixtures.dart';

// ── helpers ────────────────────────────────────────────────────────────

/// The tab a request asks for (its `networkPeers`), or null for All.
String? peerOf(TasteRequest r) =>
    (r.toJson()['networkPeers'] as List?)?.cast<String>().first;

/// The stage's answers: All's twelve leads, or a tab's own.
DiscoveryFetchResult<TasteResponse> stage(TasteRequest r) {
  final p = peerOf(r);
  return tasteOk(tasteJson(leads: p == null ? stageLeads : stageLeadsOf(p)));
}

/// An empty network section with [reason].
DiscoveryFetchResult<TasteResponse> reasonOnly(String reason,
        {bool notAnalyzed = false}) =>
    tasteOk(tasteJson(leads: const [], reason: reason, notAnalyzed: notAnalyzed));

/// Three history seeds, as a batch of more than one.
final List<Map<String, dynamic>> threeSeeds = [
  seedJson('h1', 'music/S/0.flac', 'Zero'),
  seedJson('h2', 'music/S/1.flac', 'One'),
  seedJson('h3', 'music/S/2.flac', 'Two'),
];

/// A server-stamped Add state.
Map<String, dynamic> addState(String state, [String? code]) =>
    {'state': state, 'code': code, 'at': '2026-11-19T10:00:00.000Z'};

/// The stage's peers answer, patched: the admin's or the member's rows,
/// [add] states set per endpoint id (null clears one), [shelve]d rows on
/// the shelf, [drop]ped rows gone, [labels] replaced; `searchable` is the
/// shelf rows left unless given.
Map<String, dynamic> peersJson({
  bool admin = false,
  Map<String, Object?> add = const {},
  Set<String> shelve = const {},
  Set<String> drop = const {},
  Map<String, String> labels = const {},
  int? searchable,
}) {
  final m = admin ? peersAdminJson : peersMemberJson;
  final rows = <Map<String, dynamic>>[];
  for (final r in (m['peers'] as List).cast<Map<String, dynamic>>()) {
    final id = r['endpointId'] as String;
    if (drop.contains(id)) continue;
    if (add.containsKey(id)) r['add'] = add[id];
    if (shelve.contains(id)) r['onShelf'] = true;
    if (labels.containsKey(id)) r['label'] = labels[id];
    rows.add(r);
  }
  m['peers'] = rows;
  final shelf = m['shelf'] as Map<String, dynamic>;
  final count = rows.where((r) => r['onShelf'] == true).length;
  shelf['held'] = count;
  shelf['searchable'] = searchable ?? count;
  return m;
}

/// An admin's strip where every addable peer is a plain "+".
Map<String, dynamic> adminPlus({Set<String> shelve = const {}}) =>
    peersJson(admin: true, add: {kStatic: null, kRooftop: null}, shelve: shelve);

/// No peer at all: nothing on the shelf, nothing searchable.
Map<String, dynamic> get emptyPeers => peersJson(
    drop: {kBasement, kKitchen, kAttic, kMstream}, searchable: 0);

PeerStripItem itemOf(PeerRecsController c, String id) =>
    c.stripItems.firstWhere((i) => i.id == id);

int liveTimers(FakePeerRecs f) => f.timers.made.where((t) => t.isActive).length;

void main() {
  late FakePeerRecs f;

  setUp(() => f = FakePeerRecs());

  PeerRecsController make({FakePeerRecs? fake, String? pin}) {
    final c = (fake ?? f).makeController(pinAtOpen: pin);
    addTearDown(c.dispose);
    return c;
  }

  /// Fire the one poll scheduled now, and let it land.
  Future<void> tick([FakePeerRecs? fake]) async {
    final t = (fake ?? f).timers.active;
    expect(t, isNotNull, reason: 'a poll is scheduled');
    t!.fire();
    await settle();
  }

  group('opening and bodies', () {
    test('open: one R1 call (golden body, the now-playing pin, never moods '
        'even when moodFilters is on) and one poll (:2863)', () async {
      f.server.moodFiltersAvailable = true;
      f.auto = stage;
      f.peersAuto = () => peersOk(peersMemberJson);
      final c = make(pin: '/testlib/Vosto/Highway.mp3');
      await c.open();
      expect(f.bodies, [
        {
          'window': 30,
          'pin': ['testlib/Vosto/Highway.mp3'],
          'sources': ['network'],
          'limit': {'seeds': 12, 'network': 32},
          'newArtistsOnly': false,
          'networkOnRandomSeed': true,
        }
      ], reason: 'now playing pinned; All: no networkPeers; no moods');
      expect(f.polls, 1);
      expect(c.state, PeerRecsState.ready);
      expect(c.leads, hasLength(12));
      expect(c.seeded, same(c.shown), reason: 'the first answer is the batch');
      expect(c.loading, isFalse);
      expect(c.stripVisible, isTrue);
      expect(c.stripItems.map((i) => i.id),
          [null, kBasement, kKitchen, kAttic, kMstream]);
      expect(c.selected, isNull);
      expect(c.nextPollIn, kPeerPoll);
      expect(c.canRefresh, isTrue);
    });

    test('flags off at open: off, no calls (:2851)', () async {
      for (final flag in [false, null]) {
        final fake = FakePeerRecs(server: peerRecsServer()..peerRecsAvailable = flag);
        fake.auto = stage;
        fake.peersAuto = () => peersOk(peersMemberJson);
        final c = make(fake: fake);
        var notes = 0;
        c.addListener(() => notes++);
        await c.open();
        expect(c.off, isTrue, reason: '$flag');
        expect(notes, 1);
        expect(fake.requests, isEmpty);
        expect(fake.polls, 0);
        expect(fake.timers.made, isEmpty);
        expect(c.canRefresh, isFalse);
        await c.refresh();
        await c.select(kKitchen);
        expect(fake.requests, isEmpty, reason: 'off: nothing is asked');
      }
    });

    test('the batch starts out loading: the answer on screen stays while a '
        'new one is asked', () async {
      f.peersAuto = () => peersOk(peersMemberJson);
      final c = make();
      unawaited(c.open());
      await settle();
      expect(c.loading, isTrue);
      expect(c.state, PeerRecsState.loading);
      expect(c.canRefresh, isFalse);
      expect(c.answerShown, isFalse, reason: 'the first ask: no line');
      f.answerTaste(stage(f.requests.last));
      await settle();
      final first = c.shown;
      expect(c.state, PeerRecsState.ready);
      unawaited(c.refresh());
      await settle();
      expect(c.loading, isTrue);
      expect(c.shown, same(first), reason: 'the rows stay until the new ones');
      expect(c.state, PeerRecsState.ready);
      expect(c.seeded, isNull, reason: 'a new batch is asked: no seeds yet');
      expect(c.answerShown, isTrue,
          reason: "the bar's line shows over the rows still up");
    });

    test('New seeds while an ask is out asks nothing (Discover does the same)',
        () async {
      f.peersAuto = () => peersOk(peersMemberJson);
      final c = make();
      unawaited(c.open());
      await settle();
      unawaited(c.refresh());
      await settle();
      expect(f.requests, hasLength(1), reason: 'R1 is out');
      f.answerTaste(stage(f.requests.single));
      await settle();
      unawaited(c.refresh());
      await settle();
      expect(f.requests, hasLength(2));
      // "Nothing new"'s New seeds and pull to refresh stay live meanwhile.
      unawaited(c.refresh());
      await settle();
      expect(f.requests, hasLength(2), reason: 'the same ask, not sent twice');
      f.answerTaste(stage(f.requests.last));
      await settle();
      expect(c.loading, isFalse);
      unawaited(c.refresh());
      await settle();
      expect(f.requests, hasLength(3), reason: 'answered: it asks again');
    });
  });

  group('tabs and the batch', () {
    test('a tab: one pinned call with networkPeers; All: no call; the tab '
        'again: no call (:3035)', () async {
      f.auto = (r) {
        final p = peerOf(r);
        return tasteOk(tasteJson(
            seeds: threeSeeds,
            leads: p == null ? stageLeads : stageLeadsOf(p)));
      };
      f.peersAuto = () => peersOk(peersMemberJson);
      final c = make();
      await c.open();
      final first = f.bodies.single;
      await c.select(kKitchen);
      expect(f.bodies, hasLength(2));
      expect(f.bodies[1], {
        ...first,
        'pin': ['music/S/0.flac', 'music/S/1.flac', 'music/S/2.flac'],
        'limit': {'seeds': 3, 'network': 32},
        'networkPeers': [kKitchen],
      }, reason: 'R2: the batch, its seed count, the tab');
      expect(c.selected, kKitchen);
      expect(itemOf(c, kKitchen).selected, isTrue);
      expect(c.stripItems.first.selected, isFalse);
      expect(c.leads.map((l) => l.title),
          ['Signal Fires', 'Harbor Lights', 'Long Exposure', 'Sunday Wire', 'Field Notes']);
      await c.select(null);
      expect(f.requests, hasLength(2), reason: "All: the batch's own answer");
      expect(c.shown, same(c.seeded));
      expect(c.leads, hasLength(12));
      await c.select(kKitchen);
      expect(f.requests, hasLength(2), reason: 'the tab again: its answer');
      expect(c.leads, hasLength(5));
      expect(c.loading, isFalse);
    });

    test("seeds and seeded stay the batch's after a tab answer (:3056)",
        () async {
      f.auto = (r) => peerOf(r) == null
          ? tasteOk(tasteJson(seeds: threeSeeds))
          : tasteOk(tasteJson(seeds: [
              for (final s in threeSeeds) {...s, 'pinned': true, 'outcome': null}
            ], leads: stageLeadsOf(kKitchen)));
      f.peersAuto = () => peersOk(peersMemberJson);
      final c = make();
      await c.open();
      final batch = c.seeded;
      await c.select(kKitchen);
      expect(c.seeded, same(batch));
      expect(c.shown, isNot(same(batch)));
      expect(c.seeds.map((s) => s.hash), ['h1', 'h2', 'h3']);
      expect(c.seeds.every((s) => !s.pinned), isTrue,
          reason: "the batch's history seeds, not the tab's pins");
      expect(c.isRandom, isFalse);
    });

    test("a random batch's tab pins its pick, limit.seeds 1 (:3068)",
        () async {
      f.auto = (r) {
        final p = peerOf(r);
        return tasteOk(tasteJson(
            seedSource: 'random',
            seeds: [seedJson('r1', 'music/R/Rand.flac', 'Rand', outcome: null)],
            leads: p == null ? stageLeads : stageLeadsOf(p)));
      };
      f.peersAuto = () => peersOk(peersMemberJson);
      final c = make();
      await c.open();
      expect(c.isRandom, isTrue);
      expect(c.state, PeerRecsState.ready,
          reason: 'a random answer with a network section is ready here');
      await c.select(kBasement);
      final body = f.bodies.last;
      expect(body['pin'], ['music/R/Rand.flac']);
      expect(body['limit'], {'seeds': 1, 'network': 32});
      expect(body['networkPeers'], [kBasement]);
      expect(body['networkOnRandomSeed'], isTrue);
    });

    test('not-on-shelf on a tab → All (cached: no call; else pinned), the '
        'answer is not stored (:3079)', () async {
      f.auto = (r) =>
          peerOf(r) == null ? stage(r) : reasonOnly('not-on-shelf');
      f.peersAuto = () => peersOk(peersMemberJson);
      final c = make();
      await c.open();
      await c.select(kKitchen);
      expect(c.selected, isNull);
      expect(f.requests, hasLength(2), reason: 'no third call');
      expect(c.shown, same(c.seeded), reason: "All's answer for the batch");
      expect(c.leads, hasLength(12));
      expect(c.stripItems.first.selected, isTrue);
      await c.select(kKitchen);
      expect(f.requests, hasLength(3), reason: 'not kept for its tab');

      // No All kept for the batch (its walk failed): All is asked pinned.
      final g = FakePeerRecs();
      var allFails = true;
      g.auto = (r) => peerOf(r) != null
          ? reasonOnly('not-on-shelf')
          : (allFails ? reasonOnly('error') : stage(r));
      g.peersAuto = () => peersOk(peersMemberJson);
      final d = make(fake: g);
      await d.open();
      expect(d.state, PeerRecsState.failed);
      allFails = false;
      await d.select(kKitchen);
      expect(g.bodies, hasLength(3));
      expect(g.bodies[2]['networkPeers'], isNull);
      expect(g.bodies[2]['pin'], [kSeedPath], reason: 'pinned on the batch');
      expect(g.bodies[2]['limit'], {'seeds': 1, 'network': 32});
      expect(d.selected, isNull);
      expect(d.state, PeerRecsState.ready);
    });

    test('an error answer is never cached (:3090)', () async {
      var failing = true;
      f.auto = (r) =>
          peerOf(r) != null && failing ? reasonOnly('error') : stage(r);
      f.peersAuto = () => peersOk(peersMemberJson);
      final c = make();
      await c.open();
      await c.select(kKitchen);
      expect(c.state, PeerRecsState.failed, reason: '"Try again"');
      failing = false;
      await c.select(null);
      final n = f.requests.length;
      await c.select(kKitchen);
      expect(f.requests, hasLength(n + 1), reason: 'asked again');
      expect(f.bodies.last['networkPeers'], [kKitchen]);
      expect(c.state, PeerRecsState.ready);
      expect(c.leads.map((l) => l.title), contains('Long Exposure'));
      await c.select(null);
      await c.select(kKitchen);
      expect(f.requests, hasLength(n + 1), reason: 'its answer now kept');
    });

    test('the selected peer gone in a poll → All (:3111)', () async {
      f.auto = stage;
      f.peersAuto = () => peersOk(peersMemberJson);
      final c = make();
      await c.open();
      await c.select(kKitchen);
      final n = f.requests.length;
      f.peersAuto = () => peersOk(peersJson(drop: {kKitchen}));
      await tick();
      expect(c.selected, isNull);
      expect(f.requests, hasLength(n), reason: "All's answer for the batch");
      expect(c.leads, hasLength(12));
      expect(c.stripItems.map((i) => i.id), isNot(contains(kKitchen)));
      expect(c.stripItems.first.selected, isTrue);
    });

    test('last tap wins (:3127)', () async {
      f.peersAuto = () => peersOk(peersMemberJson);
      final c = make();
      unawaited(c.open());
      await settle();
      f.answerTaste(stage(f.requests.single));
      await settle();
      unawaited(c.select(kKitchen));
      await settle();
      expect(c.loading, isTrue, reason: 'asking: the rows on screen stay');
      expect(c.leads, hasLength(12));
      unawaited(c.select(kBasement));
      await settle();
      expect(f.requests, hasLength(3));
      // Basement answers first; Kitchen's answer lands late and is dropped.
      f.pending[2].complete(stage(f.requests[2]));
      await settle();
      f.pending[1].complete(stage(f.requests[1]));
      await settle();
      expect(c.selected, kBasement);
      expect(c.loading, isFalse);
      expect(c.leads.map((l) => l.title), contains('Breakwater'));
      expect(c.leads.map((l) => l.title), isNot(contains('Signal Fires')));
      // The late answer was kept for no tab: Kitchen asks again.
      unawaited(c.select(kKitchen));
      await settle();
      expect(f.requests, hasLength(4));
    });
  });

  group('New seeds, window, seeds', () {
    test("New seeds on history: a new batch, the selected tab's networkPeers "
        "kept, the open's pin only (:3146)", () async {
      f.auto = stage;
      f.peersAuto = () => peersOk(peersMemberJson);
      final c = make(pin: '/music/Now/Playing.flac');
      await c.open();
      await c.select(kKitchen);
      expect(c.canRefresh, isTrue);
      await c.refresh();
      final body = f.bodies.last;
      expect(body['networkPeers'], [kKitchen]);
      expect(body['pin'], ['music/Now/Playing.flac']);
      expect(body['limit'], {'seeds': 12, 'network': 32});
      expect(body.containsKey('exclude'), isFalse,
          reason: 'a history batch passes nothing over');
      expect(c.selected, kKitchen);
      final n = f.requests.length;
      await c.select(null);
      expect(f.requests, hasLength(n + 1),
          reason: "All asks again: the last batch's answers are gone");
      expect(f.bodies.last['pin'], [kSeedPath],
          reason: "on the new batch (the Kitchen tab's answer)");
    });

    test('New seeds on random: the pick goes into exclude; no pick left '
        'clears passed and asks once more (:3163, DP :383, :639)', () async {
      Map<String, dynamic> pick(String h) => tasteJson(
          seedSource: 'random',
          seeds: [seedJson(h, 'music/R/$h.flac', h, outcome: null)]);
      final answers = [
        pick('r1'),
        pick('r2'),
        tasteJson(seedSource: 'random', seeds: const [], notAnalyzed: true),
        pick('r1'),
      ];
      f.auto = (r) => tasteOk(answers[f.requests.length - 1]);
      f.peersAuto = () => peersOk(peersMemberJson);
      final c = make();
      await c.open();
      await c.refresh();
      expect(f.bodies[1]['exclude'], ['r1']);
      expect(c.seeds.single.hash, 'r2');
      await c.refresh();
      expect(f.requests, hasLength(4),
          reason: 'no pick left: the passed picks go, asked once more');
      expect(f.bodies[2]['exclude'], ['r1', 'r2']);
      expect(f.bodies[3].containsKey('exclude'), isFalse);
      expect(c.seeds.single.hash, 'r1');
      expect(c.state, PeerRecsState.ready);
    });

    test('the window: a new batch, saved; a failure puts the old one back',
        () async {
      f.auto = stage;
      f.peersAuto = () => peersOk(peersMemberJson);
      final c = make();
      await c.open();
      await c.select(kKitchen);
      await c.setWindow(90);
      expect(c.window, 90);
      expect(f.saves, [90]);
      expect(f.bodies.last['window'], 90);
      expect(f.bodies.last['networkPeers'], [kKitchen]);
      expect(f.bodies.last['limit'], {'seeds': 12, 'network': 32},
          reason: 'a new batch');
      final n = f.requests.length;
      await c.setWindow(90);
      await c.setWindow(45);
      expect(f.requests, hasLength(n), reason: 'the same, or no window');
      f.auto = (_) => tasteFailed;
      await c.setWindow(7);
      expect(f.bodies.last['window'], 7);
      expect(c.window, 90, reason: 'the old one back');
      expect(f.saves, [90, 7, 90]);
      expect(c.state, PeerRecsState.failed);

      // A refusal puts it back too, whatever the re-ping finds.
      for (final on in [true, false]) {
        final g = FakePeerRecs()
          ..auto = stage
          ..peersAuto = (() => peersOk(peersMemberJson))
          ..repingPeerRecs = on;
        final d = make(fake: g);
        await d.open();
        g.auto = (_) => tasteRefused;
        await d.setWindow(7);
        expect(d.window, 30, reason: 'refused, flags $on');
        expect(g.saves, [7, 30], reason: 'flags $on');
        expect(d.off, !on);
      }
    });

    test('a window ask dropped for a newer ask keeps the window, though the '
        'ask before it failed', () async {
      f.peersAuto = () => peersOk(peersMemberJson);
      final c = make();
      unawaited(c.open());
      await settle();
      f.answerTaste(tasteFailed);
      await settle();
      expect(c.state, PeerRecsState.failed);
      unawaited(c.setWindow(7));
      await settle();
      expect(c.window, 7);
      // A tab tap while the window ask is out: a new batch (none is up),
      // sent with the new window.
      unawaited(c.select(kKitchen));
      await settle();
      expect(f.requests, hasLength(3));
      expect(f.bodies[2]['window'], 7);
      expect(f.bodies[2]['networkPeers'], [kKitchen]);

      // The window ask answers late: dropped, and the window stays.
      f.pending[1].complete(stage(f.requests[1]));
      await settle();
      expect(c.window, 7, reason: 'the tab asked with it');
      expect(f.saves, [7]);
      f.pending[2].complete(stage(f.requests[2]));
      await settle();
      expect(c.state, PeerRecsState.ready);
      expect(c.selected, kKitchen);
      expect(c.window, 7, reason: 'the leads came from 7 days');
      expect(f.saves, [7]);
      f.auto = stage;
      await c.refresh();
      expect(f.bodies.last['window'], 7);
    });

    test('a refused window ask leaves the window when Check again asked '
        'during its re-ping', () async {
      f.auto = stage;
      f.peersAuto = () => peersOk(peersMemberJson);
      f.repingPeerRecs = true;
      final c = make();
      await c.open();
      f.auto = (_) => tasteRefused;
      f.holdRepings = true;
      unawaited(c.setWindow(7));
      await settle();
      expect(c.disabled, isTrue);
      expect(f.repings, 1, reason: "the refusal's re-ping is out");
      f.auto = stage;
      unawaited(c.recheck());
      await settle();
      f.repingWaits[1].complete(); // Check again's: on, asked at once
      await settle();
      expect(f.requests, hasLength(3));
      expect(f.bodies.last['window'], 7);
      f.repingWaits[0].complete();
      await settle();
      expect(c.window, 7, reason: 'the answer up came from 7 days');
      expect(f.saves, [7]);
      expect(c.state, PeerRecsState.ready);
    });

    test('applySeeds: drops in exclude, pins replaced, a new batch', () async {
      f.auto = stage;
      f.peersAuto = () => peersOk(peersMemberJson);
      final c = make(pin: '/testlib/Vosto/Highway.mp3');
      await c.open();
      await c.select(kKitchen);
      await c.applySeeds(
          drop: {'h-x'}, pins: ['music/A.flac', '/music/B.flac']);
      var body = f.bodies.last;
      expect(body['exclude'], ['h-x']);
      expect(body['pin'], ['music/A.flac', 'music/B.flac']);
      expect(body['networkPeers'], [kKitchen]);
      expect(body['limit'], {'seeds': 12, 'network': 32});
      expect(c.pins, ['/music/A.flac', '/music/B.flac']);
      await c.applySeeds(restore: {'h-x'}, pins: const []);
      body = f.bodies.last;
      expect(body.containsKey('exclude'), isFalse);
      expect(body.containsKey('pin'), isFalse);
      expect(c.pins, isEmpty);
    });
  });

  group('polls', () {
    test('15 s; 3 s while an Add is out or an item is adding; failed/noRoom '
        'do not hurry; exactly one timer (:3644, PR :326)', () async {
      f.auto = stage;
      f.peersAuto = () => peersOk(peersMemberJson);
      final calm = make();
      await calm.open();
      expect(calm.nextPollIn, kPeerPoll);
      expect(liveTimers(f), 1);

      final adding = FakePeerRecs()
        ..auto = stage
        ..peersAuto = () => peersOk(peersAdminJson); // Static Garden adding
      final a = make(fake: adding);
      await a.open();
      expect(a.nextPollIn, kPeerPollFast);

      final idle = FakePeerRecs()
        ..auto = stage
        ..peersAuto = () => peersOk(peersJson(admin: true, add: {
              kStatic: addState('failed', 'no-room'),
              kRooftop: addState('failed', 'offline'),
            }));
      final d = make(fake: idle);
      await d.open();
      expect(itemOf(d, kStatic).state, PeerAddView.noRoom);
      expect(itemOf(d, kRooftop).state, PeerAddView.failed);
      expect(d.nextPollIn, kPeerPoll, reason: 'failed and No room do not hurry');

      // An Add out: 3 s, and still one timer after a poll answers.
      idle.peersAuto = () => peersOk(peersJson(admin: true));
      unawaited(d.add(kLighthouse));
      await settle();
      expect(d.nextPollIn, kPeerPollFast);
      expect(liveTimers(idle), 1);
      await tick(idle);
      expect(d.nextPollIn, kPeerPollFast, reason: 'the POST is still out');
      expect(liveTimers(idle), 1);
    });

    test('covered: no poll; uncovered: one poll at once (:3825)', () async {
      f.auto = stage;
      f.peersAuto = () => peersOk(peersMemberJson);
      final c = make();
      await c.open();
      expect(f.polls, 1);
      c.setCovered(true);
      expect(liveTimers(f), 0);
      expect(c.nextPollIn, isNull);
      c.setCovered(false);
      await settle();
      expect(f.polls, 2, reason: 'one at once');
      expect(c.nextPollIn, kPeerPoll);
      c.setCovered(false);
      await settle();
      expect(f.polls, 2, reason: 'one, not one per call');

      // A poll still out when the page is covered schedules nothing.
      f.peersAuto = null;
      await tick();
      expect(f.polls, 3);
      c.setCovered(true);
      f.peersPending.last.complete(peersOk(peersMemberJson));
      await settle();
      expect(liveTimers(f), 0);
      c.setCovered(false);
      await settle();
      expect(f.polls, 4);
    });

    test('backgrounded: none; resumed: one at once (:3778)', () async {
      f.auto = stage;
      f.peersAuto = () => peersOk(peersMemberJson);
      final c = make();
      await c.open();
      c.didChangeAppLifecycleState(AppLifecycleState.inactive);
      expect(liveTimers(f), 1, reason: 'inactive is a passing state');
      for (final away in [
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.detached,
      ]) {
        final n = f.polls;
        c.didChangeAppLifecycleState(away);
        expect(liveTimers(f), 0, reason: '$away');
        c.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await settle();
        expect(f.polls, n + 1, reason: '$away: one at once');
        c.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await settle();
        expect(f.polls, n + 1, reason: 'one, not one per event');
      }
      // Covered and backgrounded: back in front but still covered, none.
      c.setCovered(true);
      c.didChangeAppLifecycleState(AppLifecycleState.paused);
      c.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await settle();
      final n = f.polls;
      expect(liveTimers(f), 0);
      c.setCovered(false);
      await settle();
      expect(f.polls, n + 1);
    });

    test('an older poll answering late is dropped', () async {
      f.auto = stage;
      final c = make();
      unawaited(c.open());
      await settle();
      expect(f.peersPending, hasLength(1));
      // A second poll goes out while the first is still out (back from a
      // cover), and answers first.
      c.setCovered(true);
      c.setCovered(false);
      await settle();
      expect(f.peersPending, hasLength(2));
      f.peersPending[1]
          .complete(peersOk(peersJson(labels: {kKitchen: 'Kitchen New'})));
      await settle();
      f.peersPending[0]
          .complete(peersOk(peersJson(labels: {kKitchen: 'Kitchen Old'})));
      await settle();
      expect(itemOf(c, kKitchen).label, 'Kitchen New');
      expect(liveTimers(f), 1);
    });

    test('a poll that changes nothing does not notify; a label change does; '
        'a searchable-only change does (Nothing new → No peers yet)',
        () async {
      f.auto = stage;
      f.peersAuto = () => peersOk(peersMemberJson);
      final c = make();
      await c.open();
      var notes = 0;
      c.addListener(() => notes++);
      await tick();
      expect(notes, 0, reason: 'the same strip');
      f.peersAuto =
          () => peersOk(peersJson(labels: {kKitchen: 'Kitchen Radio 2'}));
      await tick();
      expect(notes, 1);
      expect(itemOf(c, kKitchen).label, 'Kitchen Radio 2');
      f.peersAuto = () => peersOk(
          peersJson(labels: {kKitchen: 'Kitchen Radio 2'}, searchable: 2));
      await tick();
      expect(notes, 2, reason: 'searchable moved, the rows did not');
      expect(f.requests, hasLength(1));

      // The first answer, with the strip still All alone, moves only
      // searchable: "Nothing new" becomes "No peers yet".
      final g = FakePeerRecs()..auto = (_) => reasonOnly('nothing-new');
      final d = make(fake: g);
      unawaited(d.open());
      await settle();
      expect(d.state, PeerRecsState.nothingNew);
      var dNotes = 0;
      d.addListener(() => dNotes++);
      g.peersPending.single.complete(peersOk(emptyPeers));
      await settle();
      expect(dNotes, 1);
      expect(d.state, PeerRecsState.noPeers);
      expect(d.stripVisible, isFalse, reason: 'All alone: no strip');
      expect(g.requests, hasLength(1), reason: 'not under "No peers yet"');
    });

    test('404 → noRoute: All alone, no more polls (:2985)', () async {
      f.auto = stage;
      f.peersAuto = () => const PeersAnswer(404);
      final c = make();
      await c.open();
      expect(c.noRoute, isTrue);
      expect(c.peers, isNull);
      expect(c.stripItems.map((i) => i.kind), [PeerItemKind.all]);
      expect(c.stripVisible, isTrue, reason: 'All alone, drawn');
      expect(c.polling, isFalse);
      expect(liveTimers(f), 0, reason: 'the poll stops');
      expect(c.state, PeerRecsState.ready, reason: 'the page still works');
      c.setCovered(true);
      c.setCovered(false);
      await settle();
      expect(f.polls, 1);
    });

    test('other failures keep the last strip and poll on', () async {
      f.auto = stage;
      f.peersAuto = () => peersOk(peersMemberJson);
      final c = make();
      await c.open();
      final items = c.stripItems.map((i) => i.signature).toList();
      for (final a in const [PeersAnswer(0), PeersAnswer(500), PeersAnswer(200)]) {
        f.peersAuto = () => a;
        await tick();
        expect(c.stripItems.map((i) => i.signature), items, reason: '${a.status}');
        expect(c.nextPollIn, kPeerPoll);
      }
    });

    test('dispose stops polling', () async {
      f.auto = stage;
      f.peersAuto = () => peersOk(peersMemberJson);
      final c = make();
      await c.open();
      f.peersAuto = null;
      await tick();
      c.dispose();
      expect(c.polling, isFalse);
      expect(liveTimers(f), 0);
      f.peersPending.single.complete(peersOk(peersMemberJson));
      await settle();
      expect(liveTimers(f), 0, reason: 'a late answer schedules nothing');
      c.dispose();
      c.didChangeAppLifecycleState(AppLifecycleState.resumed);
      c.setCovered(true);
      c.setCovered(false);
      await c.add(kLighthouse);
      await c.select(kKitchen);
      await settle();
      expect(f.polls, 2);
      expect(f.requests, hasLength(1));
      expect(f.adds, isEmpty);
    });
  });

  group('Add', () {
    test('every outcome: local state, posted, next poll (:3467, :3485)',
        () async {
      // [answer, the item's state after it, whether its landing re-asks
      // (posted), the next poll]
      final cases = <(PeerAddAnswer, PeerAddView?, bool, Duration)>[
        (addAnswer(202, 'adding'), PeerAddView.adding, true, kPeerPollFast),
        (addAnswer(200, 'done'), PeerAddView.adding, true, Duration.zero),
        (addAnswer(200, 'adding'), PeerAddView.adding, true, kPeerPollFast),
        (addAnswer(200, 'failed', 'no-room'), PeerAddView.noRoom, false, kPeerPoll),
        (addAnswer(200, 'failed', 'offline'), PeerAddView.failed, false, kPeerPoll),
        (addAnswer(200, 'failed', 'bad-snapshot'), PeerAddView.failed, false, kPeerPoll),
        (addAnswer(200, 'failed'), PeerAddView.failed, false, kPeerPoll),
        (addAnswer(404), null, false, Duration.zero),
        (addAnswer(409), null, false, Duration.zero),
        (addAnswer(403), null, false, Duration.zero),
        (addAnswer(405), null, false, Duration.zero),
        (addAnswer(400), PeerAddView.failed, false, kPeerPoll),
        (addAnswer(401), PeerAddView.failed, false, kPeerPoll),
        (addAnswer(500), PeerAddView.failed, false, kPeerPoll),
        (addAnswer(0), PeerAddView.failed, false, kPeerPoll),
        (const PeerAddAnswer(200), PeerAddView.failed, false, kPeerPoll),
      ];
      for (final (answer, state, posted, next) in cases) {
        final label = '${answer.status} ${answer.state?.state} ${answer.state?.code}';
        final g = FakePeerRecs()
          ..auto = stage
          ..peersAuto = () => peersOk(adminPlus());
        final c = make(fake: g);
        await c.open();
        g.addQueue.add(answer);
        await c.add(kLighthouse);
        expect(g.adds, [kLighthouse], reason: label);
        expect(itemOf(c, kLighthouse).state, state, reason: label);
        expect(itemOf(c, kLighthouse).act,
            state == null || state == PeerAddView.failed
                ? PeerItemAct.add
                : PeerItemAct.none,
            reason: label);
        expect(c.nextPollIn, next, reason: '$label: the next poll');
        expect(liveTimers(g), 1, reason: label);
        // It lands on the next poll: only an Add still on its way re-asks.
        final n = g.requests.length;
        g.peersAuto = () => peersOk(adminPlus(shelve: {kLighthouse}));
        await tick(g);
        expect(g.requests.length, n + (posted ? 1 : 0), reason: '$label: posted');
      }
    });

    test('a "+" press: Adding… at once (inert), the poll at 3 s', () async {
      f.auto = stage;
      f.peersAuto = () => peersOk(adminPlus());
      final c = make();
      await c.open();
      var notes = 0;
      c.addListener(() => notes++);
      unawaited(c.add(kLighthouse));
      expect(f.adds, [kLighthouse]);
      expect(notes, 1);
      expect(itemOf(c, kLighthouse).state, PeerAddView.adding);
      expect(itemOf(c, kLighthouse).act, PeerItemAct.none);
      expect(c.nextPollIn, kPeerPollFast);
      expect(liveTimers(f), 1);
    });

    test('Adding… stands across polls until one sent after the press answers',
        () async {
      f.auto = stage;
      f.peersAuto = () => peersOk(adminPlus());
      final c = make();
      await c.open();
      unawaited(c.add(kLighthouse));
      await settle();
      // Poll 2 goes out while the POST is still out; the server's row has
      // no Add state yet.
      f.peersAuto = null;
      await tick();
      expect(f.peersPending, hasLength(1));
      f.addPending.single.complete(addAnswer(202, 'adding'));
      await settle();
      f.peersPending.single.complete(peersOk(adminPlus()));
      await settle();
      expect(itemOf(c, kLighthouse).state, PeerAddView.adding,
          reason: 'poll 2 was sent before the POST answered');
      f.peersAuto = () => peersOk(adminPlus());
      await tick();
      expect(itemOf(c, kLighthouse).state, isNull,
          reason: "a poll sent after it: the server's word");
      f.peersAuto = () => peersOk(
          peersJson(admin: true, add: {kLighthouse: addState('adding')}));
      await tick();
      expect(itemOf(c, kLighthouse).state, PeerAddView.adding);
    });

    test('No room is inert and never re-POSTs; a member never POSTs (:3512)',
        () async {
      f.auto = stage;
      f.peersAuto = () => peersOk(peersJson(admin: true, add: {
            kLighthouse: addState('failed', 'no-room'),
          })); // Static Garden adding, Rooftop FM failed
      final c = make();
      await c.open();
      await c.add(kLighthouse);
      await c.add(kStatic);
      await c.add(kKitchen);
      expect(f.adds, isEmpty, reason: 'No room, Adding… and a shelf peer');
      f.addAuto = (_) => addAnswer(200, 'failed', 'no-room');
      await c.add(kRooftop);
      expect(f.adds, [kRooftop], reason: 'Try again is a press');
      expect(itemOf(c, kRooftop).state, PeerAddView.noRoom);
      await c.add(kRooftop);
      expect(f.adds, [kRooftop], reason: 'No room never re-POSTs');

      final m = FakePeerRecs()
        ..auto = stage
        ..peersAuto = (() => peersOk(peersMemberJson))
        ..addAuto = (_) => addAnswer(202, 'adding');
      final d = make(fake: m);
      await d.open();
      for (final id in [kLighthouse, kStatic, kRooftop, kKitchen]) {
        await d.add(id);
      }
      expect(m.adds, isEmpty, reason: 'a member has no add item');
    });

    test('a press while posting is ignored', () async {
      f.auto = stage;
      f.peersAuto = () => peersOk(adminPlus());
      final c = make();
      await c.open();
      unawaited(c.add(kLighthouse));
      unawaited(c.add(kLighthouse));
      await settle();
      expect(f.adds, [kLighthouse]);
      f.addPending.single.complete(addAnswer(200, 'failed', 'offline'));
      await settle();
      expect(itemOf(c, kLighthouse).state, PeerAddView.failed);
      f.addAuto = (_) => addAnswer(202, 'adding');
      await c.add(kLighthouse);
      expect(f.adds, [kLighthouse, kLighthouse], reason: 'Try again posts');
    });
  });

  group('landing (R4)', () {
    test('own Add lands → answers dropped, one pinned re-ask', () async {
      f.auto = stage;
      f.peersAuto = () => peersOk(adminPlus());
      f.addAuto = (_) => addAnswer(202, 'adding');
      final c = make();
      await c.open();
      await c.select(kKitchen);
      await c.add(kLighthouse);
      final n = f.requests.length;
      f.peersAuto = () => peersOk(adminPlus(shelve: {kLighthouse}));
      await tick();
      expect(f.requests, hasLength(n + 1), reason: 'one re-ask');
      expect(f.bodies.last['networkPeers'], [kKitchen]);
      expect(f.bodies.last['pin'], [kSeedPath], reason: 'on the batch');
      expect(f.bodies.last['limit'], {'seeds': 1, 'network': 32});
      expect(itemOf(c, kLighthouse).kind, PeerItemKind.peer);
      await c.select(null);
      expect(f.requests, hasLength(n + 2),
          reason: "All's answer went with the shelf's move");
      await tick();
      expect(f.requests, hasLength(n + 2), reason: 'it landed once');
    });

    test("another admin's add or a rotation only moves the strip (:3599)",
        () async {
      f.auto = stage;
      f.peersAuto = () => peersOk(adminPlus());
      final c = make();
      await c.open();
      final n = f.requests.length;
      f.peersAuto = () => peersOk(adminPlus(shelve: {kLighthouse}));
      await tick();
      expect(itemOf(c, kLighthouse).kind, PeerItemKind.peer);
      f.peersAuto = () => peersOk(peersJson(
          admin: true,
          add: {kStatic: null, kRooftop: null},
          shelve: {kLighthouse},
          drop: {kAttic}));
      await tick();
      expect(c.stripItems.map((i) => i.id), isNot(contains(kAttic)));
      expect(f.requests, hasLength(n), reason: 'the list stays');
    });

    test('0→>0 under No peers yet re-asks', () async {
      f.auto = (_) => reasonOnly('empty-shelf');
      f.peersAuto = () => peersOk(emptyPeers);
      final c = make();
      await c.open();
      expect(c.state, PeerRecsState.noPeers);
      final n = f.requests.length;
      f.peersAuto = () => peersOk(peersJson(drop: {kBasement, kAttic, kMstream}));
      await tick();
      expect(f.requests, hasLength(n + 1));
      expect(f.bodies.last['pin'], [kSeedPath], reason: 'on the batch');

      // Under "Nothing new" the shelf's first answer asks nothing.
      final g = FakePeerRecs()..auto = (_) => reasonOnly('nothing-new');
      final d = make(fake: g);
      unawaited(d.open());
      await settle();
      g.peersPending.single.complete(peersOk(peersMemberJson));
      await settle();
      expect(g.requests, hasLength(1));
      expect(d.state, PeerRecsState.nothingNew);
    });

    test('emptied → re-ask, No peers yet (:3621)', () async {
      for (final tab in [null, kKitchen]) {
        var shelf = true;
        final g = FakePeerRecs()
          ..auto = ((r) => shelf ? stage(r) : reasonOnly('empty-shelf'))
          ..peersAuto = () => peersOk(shelf ? peersMemberJson : emptyPeers);
        final c = make(fake: g);
        await c.open();
        if (tab != null) await c.select(tab);
        final n = g.requests.length;
        shelf = false;
        await tick(g);
        final name = tab == null ? 'All' : "a peer's tab";
        expect(g.requests, hasLength(n + 1),
            reason: '$name: asked again, never the answer kept');
        expect(g.bodies.last['networkPeers'], isNull, reason: name);
        expect(c.selected, isNull, reason: name);
        expect(c.state, PeerRecsState.noPeers, reason: name);
        expect(c.leads, isEmpty, reason: name);
      }
    });

    test('a re-ask waits while holding and runs when holding ends (:3577)',
        () async {
      f.auto = (_) => reasonOnly('empty-shelf');
      f.peersAuto = () => peersOk(emptyPeers);
      final c = make();
      await c.open();
      final n = f.requests.length;
      c.setHolding(true);
      expect(c.holding, isTrue);
      f.peersAuto = () => peersOk(peersJson(drop: {kBasement, kAttic, kMstream}));
      await tick();
      expect(f.requests, hasLength(n), reason: 'not under a clip or a sheet');
      expect(c.pending, isTrue);
      await tick();
      expect(f.requests, hasLength(n), reason: 'still held');
      expect(c.pending, isTrue);
      c.setHolding(false);
      await settle();
      expect(f.requests, hasLength(n + 1), reason: 'at once (D10.3)');
      expect(c.pending, isFalse);
      c.setHolding(true);
      c.setHolding(false);
      await settle();
      expect(f.requests, hasLength(n + 1), reason: 'nothing owed');
    });
  });

  test('the state matrix (:3685, :3700, :3711)', () async {
    final cases = <(String, DiscoveryFetchResult<TasteResponse>?, PeersAnswer, PeerRecsState)>[
      ('loading', null, peersOk(peersMemberJson), PeerRecsState.loading),
      ('no answer', tasteFailed, peersOk(peersMemberJson), PeerRecsState.failed),
      ('reason error', reasonOnly('error'), peersOk(peersMemberJson), PeerRecsState.failed),
      ('not analyzed', tasteOk(tasteJson(notAnalyzed: true, leads: const [])),
          peersOk(peersMemberJson), PeerRecsState.scanPending),
      ('reason scan-pending', reasonOnly('scan-pending', notAnalyzed: true),
          peersOk(peersMemberJson), PeerRecsState.scanPending),
      ('403, flags on', tasteRefused, peersOk(peersMemberJson), PeerRecsState.scanPending),
      ('empty-shelf', reasonOnly('empty-shelf'), peersOk(emptyPeers), PeerRecsState.noPeers),
      ('no-compatible', reasonOnly('no-compatible'), peersOk(peersMemberJson), PeerRecsState.noPeers),
      ('none searchable', reasonOnly('nothing-new'),
          peersOk(peersJson(searchable: 0)), PeerRecsState.noPeers),
      ('nothing-new', reasonOnly('nothing-new'), peersOk(peersMemberJson), PeerRecsState.nothingNew),
      ('leads', tasteOk(tasteJson()), peersOk(peersMemberJson), PeerRecsState.ready),
      ('random + network', tasteOk(tasteJson(seedSource: 'random',
          seeds: [seedJson('r1', 'music/R/r1.flac', 'r1', outcome: null)])),
          peersOk(peersMemberJson), PeerRecsState.ready),
    ];
    for (final (label, taste, peers, want) in cases) {
      final g = FakePeerRecs()
        ..repingPeerRecs = true
        ..peersAuto = () => peers;
      if (taste != null) g.auto = (_) => taste;
      final c = make(fake: g);
      unawaited(c.open());
      await settle();
      expect(c.state, want, reason: label);
      expect(c.off, isFalse, reason: label);
    }
  });

  test('Try again: pinned on a tab with a batch, else a new batch (:3726)',
      () async {
    var fail = false;
    f.auto = (r) => fail ? tasteFailed : stage(r);
    f.peersAuto = () => peersOk(peersMemberJson);
    final c = make();
    await c.open();
    fail = true;
    await c.select(kKitchen);
    expect(c.state, PeerRecsState.failed);
    expect(c.shown, isNull);
    fail = false;
    await c.retry();
    expect(f.bodies.last['networkPeers'], [kKitchen]);
    expect(f.bodies.last['pin'], [kSeedPath]);
    expect(c.leads.map((l) => l.title), contains('Long Exposure'));

    final g = FakePeerRecs()
      ..auto = ((_) => tasteFailed)
      ..peersAuto = () => peersOk(peersMemberJson);
    final d = make(fake: g, pin: '/music/Now/Playing.flac');
    await d.open();
    expect(d.state, PeerRecsState.failed);
    g.auto = stage;
    await d.retry();
    expect(g.bodies.last, g.bodies.first, reason: 'no batch: R1 again');
    expect(d.state, PeerRecsState.ready);
  });

  group('R7', () {
    test('taste 403 → re-ping: off → off; on → scanPending; Check again '
        're-pings, clears and asks', () async {
      f.auto = (_) => tasteRefused;
      f.peersAuto = () => peersOk(peersMemberJson);
      f.repingPeerRecs = false;
      final c = make();
      await c.open();
      expect(f.repings, 1);
      expect(c.off, isTrue);
      expect(c.polling, isFalse);
      expect(liveTimers(f), 0);

      // Still on: the scan-pending card; Check again re-pings, lets go of
      // the latch and the passed picks, and asks a new batch.
      final g = FakePeerRecs()
        ..peersAuto = (() => peersOk(peersMemberJson))
        ..repingPeerRecs = true;
      final answers = <DiscoveryFetchResult<TasteResponse>>[
        tasteOk(tasteJson(
            seedSource: 'random',
            seeds: [seedJson('r1', 'music/R/r1.flac', 'r1', outcome: null)])),
        tasteRefused,
        tasteOk(tasteJson()),
      ];
      g.auto = (_) => answers[g.requests.length - 1];
      final d = make(fake: g);
      await d.open();
      await d.refresh();
      expect(g.bodies[1]['exclude'], ['r1']);
      expect(g.repings, 1);
      expect(d.off, isFalse);
      expect(d.disabled, isTrue);
      expect(d.state, PeerRecsState.scanPending);
      expect(d.canRefresh, isFalse);
      await d.refresh();
      await d.setWindow(90);
      expect(g.requests, hasLength(2), reason: 'under the latch, nothing asked');
      expect(d.window, 30);
      g.holdRepings = true;
      unawaited(d.recheck());
      await settle();
      expect(d.rechecking, isTrue);
      expect(g.repings, 2);
      g.repingWaits.single.complete();
      await settle();
      expect(d.rechecking, isFalse);
      expect(d.disabled, isFalse);
      expect(g.requests, hasLength(3));
      expect(g.bodies[2].containsKey('exclude'), isFalse,
          reason: 'the passed picks went');
      expect(g.bodies[2]['limit'], {'seeds': 12, 'network': 32});
      expect(d.state, PeerRecsState.ready);
    });

    test('history network:null → re-ping: off → off; on → failed (:3743)',
        () async {
      f.auto = (_) => tasteOk(tasteJson(networkNull: true));
      f.peersAuto = () => peersOk(peersMemberJson);
      f.repingPeerRecs = false;
      final c = make();
      await c.open();
      expect(f.repings, 1);
      expect(c.off, isTrue);

      final g = FakePeerRecs()
        ..auto = ((_) => tasteOk(tasteJson(networkNull: true)))
        ..peersAuto = (() => peersOk(peersMemberJson))
        ..repingPeerRecs = true;
      final d = make(fake: g);
      await d.open();
      expect(g.repings, 1);
      expect(d.off, isFalse);
      expect(d.shown, isNull);
      expect(d.state, PeerRecsState.failed, reason: '"Try again"');
      expect(d.seeded, isNull, reason: 'the answer is kept for nothing');
      g.auto = stage;
      await d.retry();
      expect(g.bodies.last, g.bodies.first, reason: 'no batch: R1 again');
      expect(d.state, PeerRecsState.ready);

      // A random answer without a network section is no off signal (the
      // peers poll's 403 says so): "Try again".
      final r = FakePeerRecs()
        ..auto = ((_) => tasteOk(tasteJson(seedSource: 'random', networkNull: true,
            seeds: [seedJson('r1', 'music/R/r1.flac', 'r1', outcome: null)])))
        ..peersAuto = () => peersOk(peersMemberJson);
      final e = make(fake: r);
      await e.open();
      expect(r.repings, 0);
      expect(e.state, PeerRecsState.failed);
    });

    test("network:null's re-ping still on leaves a newer tab's answer alone "
        '(the last ask wins)', () async {
      f.auto = (r) => peerOf(r) == null
          ? tasteOk(tasteJson(networkNull: true))
          : stage(r);
      f.peersAuto = () => peersOk(peersMemberJson);
      f.repingPeerRecs = true;
      f.holdRepings = true;
      final c = make();
      unawaited(c.open());
      await settle();
      expect(f.repings, 1, reason: 'the re-ping is out');
      await c.select(kKitchen);
      expect(c.state, PeerRecsState.ready);
      final tab = c.shown;
      expect(tab, isNotNull);
      f.repingWaits.single.complete();
      await settle();
      expect(c.off, isFalse);
      expect(c.selected, kKitchen);
      expect(c.shown, same(tab), reason: 'not wiped with "Try again"');
      expect(c.state, PeerRecsState.ready);
      expect(c.leads.map((l) => l.title), contains('Long Exposure'));

      // With no newer ask, the same re-ping is "Try again" (as before).
      final g = FakePeerRecs()
        ..auto = ((_) => tasteOk(tasteJson(networkNull: true)))
        ..peersAuto = (() => peersOk(peersMemberJson))
        ..repingPeerRecs = true
        ..holdRepings = true;
      final d = make(fake: g);
      unawaited(d.open());
      await settle();
      g.repingWaits.single.complete();
      await settle();
      expect(d.state, PeerRecsState.failed);
      expect(d.shown, isNull);
    });

    test('network:null while another off check is out is "Try again" at once, '
        "not the last tab's leads", () async {
      f.auto = stage;
      f.peersAuto = () => peersOk(peersMemberJson);
      f.repingPeerRecs = true;
      final c = make();
      await c.open();
      expect(c.state, PeerRecsState.ready);
      f.holdRepings = true;
      f.peersAuto = () => const PeersAnswer(403);
      await tick();
      expect(f.repings, 1, reason: "the refused poll's re-ping is out");
      f.auto = (_) => tasteOk(tasteJson(networkNull: true));
      await c.select(kKitchen);
      expect(f.repings, 1, reason: 'one re-ping at a time');
      expect(c.loading, isFalse);
      expect(c.selected, kKitchen);
      expect(c.shown, isNull,
          reason: "not All's leads left under the Kitchen tab");
      expect(c.state, PeerRecsState.failed);
      f.repingWaits.single.complete();
      await settle();
      expect(c.off, isFalse, reason: 'the other check decides: still on');
      expect(c.state, PeerRecsState.failed);
    });

    test('peers 403 → re-ping: off → off; on → the page stays, polls stopped '
        '(:3762)', () async {
      f.auto = stage;
      f.peersAuto = () => const PeersAnswer(403);
      f.repingPeerRecs = false;
      final c = make();
      await c.open();
      await settle();
      expect(f.repings, 1);
      expect(c.off, isTrue);

      final g = FakePeerRecs()
        ..auto = stage
        ..peersAuto = (() => const PeersAnswer(403))
        ..repingPeerRecs = true;
      final d = make(fake: g);
      await d.open();
      await settle();
      expect(g.repings, 1);
      expect(d.off, isFalse);
      expect(d.polling, isFalse);
      expect(liveTimers(g), 0, reason: 'the refused poll stops');
      expect(d.state, PeerRecsState.ready);
      expect(d.leads, hasLength(12));
      d.setCovered(true);
      d.setCovered(false);
      d.didChangeAppLifecycleState(AppLifecycleState.paused);
      d.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await settle();
      expect(g.polls, 1, reason: 'stopped stays stopped');
    });

    test('a re-ping with no answer is off (m.js:6196)', () async {
      for (final setUp in <void Function(FakePeerRecs)>[
        (g) => g.auto = (_) => tasteRefused,
        (g) => g.auto = (_) => tasteOk(tasteJson(networkNull: true)),
        (g) => g.peersAuto = () => const PeersAnswer(403),
      ]) {
        final g = FakePeerRecs()
          ..auto = stage
          ..peersAuto = (() => peersOk(peersMemberJson))
          ..repingAnswers = false;
        setUp(g);
        final c = make(fake: g);
        await c.open();
        await settle();
        expect(g.repings, 1);
        expect(c.off, isTrue);
        expect(g.server.peerRecsAvailable, isTrue,
            reason: 'the flags were not read again, yet it is off');
      }
      // Check again with no answer: off too.
      final g = FakePeerRecs()
        ..auto = ((_) => tasteRefused)
        ..peersAuto = (() => peersOk(peersMemberJson))
        ..repingPeerRecs = true;
      final c = make(fake: g);
      await c.open();
      expect(c.state, PeerRecsState.scanPending);
      g.repingAnswers = false;
      await c.recheck();
      expect(c.off, isTrue);
      expect(c.rechecking, isFalse);
      expect(g.requests, hasLength(1));
    });

    test('one re-ping at a time; a second off check after the first finished '
        're-pings again', () async {
      f.auto = (_) => tasteRefused;
      f.peersAuto = () => const PeersAnswer(403);
      f.repingPeerRecs = true;
      f.holdRepings = true;
      final c = make();
      unawaited(c.open());
      await settle();
      expect(f.repings, 1, reason: 'the taste and the poll refused: one');
      await c.offCheck(PeerRecsOffSource.clip);
      expect(f.repings, 1, reason: 'one at a time');
      f.repingWaits.single.complete();
      await settle();
      expect(c.off, isFalse);
      f.holdRepings = false;
      await c.offCheck(PeerRecsOffSource.clip);
      expect(f.repings, 2);
      expect(c.off, isFalse);
      f.repingPeerRecs = false;
      await c.offCheck(PeerRecsOffSource.clip);
      expect(f.repings, 3);
      expect(c.off, isTrue, reason: "a preview's 403 can find it off");
      await c.offCheck(PeerRecsOffSource.clip);
      expect(f.repings, 3, reason: 'off: nothing more');
    });

    test('off drops an answer still out and the poll', () async {
      f.peersAuto = () => peersOk(peersMemberJson);
      final c = make();
      unawaited(c.open());
      await settle();
      f.repingPeerRecs = false;
      await c.offCheck(PeerRecsOffSource.clip);
      expect(c.off, isTrue);
      expect(c.loading, isFalse);
      expect(liveTimers(f), 0);
      f.answerTaste(stage(f.requests.single));
      await settle();
      expect(c.shown, isNull, reason: 'dropped');
    });
  });

  group('misc', () {
    test('a dependency that throws is no answer: nothing stays stuck',
        () async {
      Never boom() => throw StateError('boom');
      final c = PeerRecsController(
        server: f.server,
        fetchPeers: () async => boom(),
        postAdd: (_) async => boom(),
        fetch: (_, _) async => boom(),
        reping: (_) async => boom(),
        readWindow: () => 30,
        saveWindow: (_) {},
        timer: f.timers.call,
        watchLifecycle: false,
      );
      addTearDown(c.dispose);
      await c.open();
      expect(c.loading, isFalse);
      expect(c.state, PeerRecsState.failed);
      expect(c.nextPollIn, kPeerPoll, reason: 'the poll goes on');
      await c.offCheck(PeerRecsOffSource.clip);
      expect(c.off, isTrue, reason: 'a re-ping that throws is no answer');

      f.auto = stage;
      f.peersAuto = () => peersOk(adminPlus());
      final d = PeerRecsController(
        server: f.server,
        fetchPeers: f.peers,
        postAdd: (_) async => boom(),
        fetch: f.taste,
        reping: f.reping,
        readWindow: () => 30,
        saveWindow: (_) {},
        timer: f.timers.call,
        watchLifecycle: false,
      );
      addTearDown(d.dispose);
      await d.open();
      await d.add(kLighthouse);
      expect(itemOf(d, kLighthouse).state, PeerAddView.failed,
          reason: '"Try again", not stuck posting');
      expect(itemOf(d, kLighthouse).act, PeerItemAct.add);
    });

    test('copyListText and seedTitleOf (:3656)', () async {
      f.auto = stage;
      f.peersAuto = () => peersOk(peersMemberJson);
      final c = make();
      await c.open();
      expect(
          c.copyListText(),
          [for (final l in parseLeads(tasteJson())) '${l.artist} - ${l.title}']
              .join('\n'));
      await c.select(kKitchen);
      expect(
          c.copyListText(),
          'Paper Lantern - Signal Fires\nPaper Lantern - Harbor Lights\n'
          'Marlowe Fields - Long Exposure\nOkra Bloom - Sunday Wire\n'
          'Ada Merrow - Field Notes');
      expect(c.seedTitleOf(c.leads.first), kSeedTitle);
      final other = parseLeads(tasteJson(leads: [
        leadJson(seedHash: 'h-unknown'),
        leadJson(seedHash: null),
      ]));
      expect(c.seedTitleOf(other[0]), isNull);
      expect(c.seedTitleOf(other[1]), isNull);
    });

    test('the window is shared with Discover (readWindow / saveWindow)',
        () async {
      f.stored = 90;
      f.auto = stage;
      f.peersAuto = () => peersOk(peersMemberJson);
      final c = make();
      expect(c.window, 90);
      await c.open();
      expect(f.bodies.single['window'], 90);
      await c.setWindow(7);
      expect(f.stored, 7, reason: "the phone's one remembered window");

      final g = FakePeerRecs()..stored = 45;
      expect(make(fake: g).window, kTasteDefaultWindow,
          reason: 'no window: the default');

      // By default it is the window Discover reads and saves.
      final before = SettingsManager().discoverWindow;
      addTearDown(() => SettingsManager().discoverWindow = before);
      SettingsManager().discoverWindow = 0;
      final d = PeerRecsController(
        server: f.server,
        fetchPeers: f.peers,
        postAdd: f.add,
        fetch: f.taste,
        reping: f.reping,
        timer: f.timers.call,
        watchLifecycle: false,
      );
      addTearDown(d.dispose);
      expect(d.window, 0);
    });
  });
}
