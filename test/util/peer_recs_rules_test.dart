import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/discovery.dart';
import 'package:mstream_music/objects/discovery_plugins.dart';
import 'package:mstream_music/objects/peer_recs.dart';
import 'package:mstream_music/util/peer_recs_rules.dart';

import '../screens/discovery/peer_recs_fixtures.dart';

// The Peer Recommendations page's pure rules (mStream
// docs/peer-recommendations-plan.md §3.5, §5). Each test ports one of the
// webapp's: "PR :n" is test/unit/webapp-peer-recs.test.mjs, "DP :n" is
// test/unit/webapp-discovery-page.test.mjs (mStream master 07d442a1).

// ── peers answers ────────────────────────────────────────────────────────

/// The admin sample's row of [id] (any of the 7 stage peers), as sent.
Map<String, dynamic> _row(String id) => {
      ...((peersAdminJson['peers'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((r) => r['endpointId'] == id)),
    };

/// A peers answer over the stage's peers: [shelf] rows (in that order),
/// then — only when [canAdd] — the [addable] ones, each with the Add state
/// [states] names for it (none otherwise). `searchable` = the shelf's size.
PeerView _view({
  bool canAdd = true,
  List<String> shelf = const [kBasement, kKitchen, kAttic, kMstream],
  List<String> addable = const [kLighthouse, kStatic, kRooftop],
  Map<String, Object?> states = const {},
}) =>
    parsePeers({
      'canAdd': canAdd,
      'shelf': {
        'held': shelf.length,
        'searchable': shelf.length,
        'running': false,
      },
      'peers': [
        for (final id in shelf)
          {..._row(id), 'onShelf': true, 'add': states[id]},
        if (canAdd)
          for (final id in addable)
            {..._row(id), 'onShelf': false, 'add': states[id]},
      ],
    });

Map<String, dynamic> _failed(String? code) =>
    {'state': 'failed', 'code': code, 'at': '2026-11-19T10:00:00.000Z'};
const Map<String, dynamic> _adding = {'state': 'adding', 'code': null};
const Map<String, dynamic> _done = {'state': 'done', 'code': null};

PeerStripItem _byId(PeerStrip s, String id) =>
    s.items.firstWhere((i) => i.id == id);

/// Each item as [kind, label (or 'All'), state, act, selected].
List<List<Object?>> _shape(PeerStrip s) => [
      for (final i in s.items)
        [
          i.kind,
          i.kind == PeerItemKind.all ? 'All' : i.label,
          i.state,
          i.act,
          i.selected,
        ],
    ];

// ── leads (the webapp test's six, as the taste route stamps them) ─────────

DiscoveryLead _lead(String exportId, String artist, String title,
        String? album, String peer) =>
    DiscoveryLead.fromServerMap(leadJson(
        exportId: exportId,
        artist: artist,
        title: title,
        album: album,
        peer: peer))!;

final _signal =
    _lead('x1', 'Paper Lantern', 'Signal Fires', 'Night Ferry', kKitchen);
final _harbor = _lead(
    'x2', '  PAPER   lantern ', 'Harbor Lights', 'Night  Ferry', kBasement);
final _long = _lead(
    'x3', 'Marlowe Fields', 'Long Exposure', 'Daylight Savings', kKitchen);
final _arcade =
    _lead('x4', 'Juniper Static', 'Arcade Rain', 'Neon Psalms', kMstream);
final _untitled = _lead('x5', '', 'Untitled Lead', null, kBasement);
final _copper = _lead('x6', 'Kestrel & Vine', 'Copper Dawn', null, kKitchen);
final _leads = [_signal, _harbor, _long, _arcade, _untitled, _copper];

DiscoveryLead _with(DiscoveryLead l, Map<String, dynamic> over) =>
    DiscoveryLead.fromServerMap({...l.raw, ...over})!;

void main() {
  group('peerStripItems: the peer strip from the peers answer', () {
    test(
        'a member: All (selected) and the shelf peers in the server\'s order '
        '— labels and monograms verbatim, no "+" (PR :172)', () {
      final v = parsePeers(peersMemberJson);
      final s = peerStripItems(v);
      expect(_shape(s), [
        [PeerItemKind.all, 'All', null, PeerItemAct.tab, true],
        [PeerItemKind.peer, 'Basement Hi-Fi', null, PeerItemAct.tab, false],
        [PeerItemKind.peer, 'Kitchen Radio', null, PeerItemAct.tab, false],
        [PeerItemKind.peer, 'Attic Tapes', null, PeerItemAct.tab, false],
        [PeerItemKind.peer, 'mStream · 3f9a', null, PeerItemAct.tab, false],
      ]);
      expect(
          [
            for (final i in s.items.skip(1)) [i.id, i.monogram, i.hue, i.online]
          ],
          [
            for (final r in v.peers) [r.endpointId, r.monogram, r.hue, r.online]
          ]);
      final all = s.items.first;
      expect([all.id, all.label, all.monogram, all.hue, all.online],
          [null, '', '', 0, false]);
      expect([_byId(s, kMstream).monogram, _byId(s, kMstream).online],
          ['mS', false]);
      expect([s.selected, s.fallback, s.local], [null, false, isEmpty]);
      // A member never gets an add item, even from a row the answer leaks.
      final leaky = {
        ...peersMemberJson,
        'peers': [
          ...peersMemberJson['peers'] as List,
          {..._row(kLighthouse), 'onShelf': false},
        ],
      };
      expect(
          peerStripItems(parsePeers(leaky))
              .items
              .any((i) => i.kind == PeerItemKind.add),
          isFalse);
    });

    test(
        'an admin: the addable peers after the shelf, one item per Add '
        'state (PR :191)', () {
      final s = peerStripItems(parsePeers(peersAdminJson));
      expect(_shape(s), [
        [PeerItemKind.all, 'All', null, PeerItemAct.tab, true],
        [PeerItemKind.peer, 'Basement Hi-Fi', null, PeerItemAct.tab, false],
        [PeerItemKind.peer, 'Kitchen Radio', null, PeerItemAct.tab, false],
        [PeerItemKind.peer, 'Attic Tapes', null, PeerItemAct.tab, false],
        [PeerItemKind.peer, 'mStream · 3f9a', null, PeerItemAct.tab, false],
        [PeerItemKind.add, 'Lighthouse Tapes', null, PeerItemAct.add, false],
        [
          PeerItemKind.add,
          'Static Garden',
          PeerAddView.adding,
          PeerItemAct.none,
          false
        ],
        [
          PeerItemKind.add,
          'Rooftop FM',
          PeerAddView.failed,
          PeerItemAct.add,
          false
        ],
      ]);
      final lt = _byId(s, kLighthouse);
      expect([lt.id, lt.label, lt.monogram, lt.hue, lt.online],
          [kLighthouse, 'Lighthouse Tapes', 'LT', 280, true]);
    });

    test('every Add state an addable row can carry (PR :214)', () {
      final cases = <(Object?, PeerAddView?, PeerItemAct)>[
        (null, null, PeerItemAct.add),
        (_adding, PeerAddView.adding, PeerItemAct.none),
        // done, not yet a shelf row in this answer: it lands next poll
        (_done, PeerAddView.adding, PeerItemAct.none),
        (_failed('no-room'), PeerAddView.noRoom, PeerItemAct.none),
        (_failed('offline'), PeerAddView.failed, PeerItemAct.add),
        (_failed('no-disk'), PeerAddView.failed, PeerItemAct.add),
        (_failed('bad-snapshot'), PeerAddView.failed, PeerItemAct.add),
        (_failed('gone'), PeerAddView.failed, PeerItemAct.add),
        (_failed('failed'), PeerAddView.failed, PeerItemAct.add),
        (_failed(null), PeerAddView.failed, PeerItemAct.add),
        ({'state': 'mystery'}, null, PeerItemAct.add),
      ];
      for (final (add, state, act) in cases) {
        final item = _byId(
            peerStripItems(_view(states: {kLighthouse: add})), kLighthouse);
        expect([item.state, item.act], [state, act], reason: '$add');
      }
    });

    test(
        'a local "Adding…" stands until a poll sent after the press answers, '
        'then yields to the server (PR :236)', () {
      final local = {kLighthouse: (state: PeerAddView.adding, poll: 4)};
      final idle = _view();
      // Poll 4 was sent before the press: the press stands over the idle row.
      final before = peerStripItems(idle, local: local, poll: 4);
      expect([_byId(before, kLighthouse).state, _byId(before, kLighthouse).act],
          [PeerAddView.adding, PeerItemAct.none]);
      expect(before.local, local);
      // Without a poll number every local entry stands.
      expect(_byId(peerStripItems(idle, local: local), kLighthouse).state,
          PeerAddView.adding);
      // It stands over a stale failed state too.
      final stale = peerStripItems(
          _view(states: {kLighthouse: _failed('offline')}),
          local: local,
          poll: 3);
      expect(_byId(stale, kLighthouse).state, PeerAddView.adding);
      // Poll 5, sent after it: the server's word, and the entry is dropped.
      for (final (add, want) in <(Object?, PeerAddView?)>[
        (_adding, PeerAddView.adding),
        (_failed('no-room'), PeerAddView.noRoom),
        (_failed('offline'), PeerAddView.failed),
        (null, null),
      ]) {
        final after = peerStripItems(_view(states: {kLighthouse: add}),
            local: local, poll: 5);
        expect([_byId(after, kLighthouse).state, after.local], [want, isEmpty],
            reason: '$add');
      }
      // A local "Try again" and a local "No room" stand the same way.
      final tryAgain = peerStripItems(idle,
          local: {kLighthouse: (state: PeerAddView.failed, poll: 6)}, poll: 6);
      expect(
          [_byId(tryAgain, kLighthouse).state, _byId(tryAgain, kLighthouse).act],
          [PeerAddView.failed, PeerItemAct.add]);
      final noRoom = peerStripItems(idle,
          local: {kLighthouse: (state: PeerAddView.noRoom, poll: 6)}, poll: 6);
      expect([_byId(noRoom, kLighthouse).state, _byId(noRoom, kLighthouse).act],
          [PeerAddView.noRoom, PeerItemAct.none]);
      // The local map handed back is the caller's to keep and change.
      before.local[kRooftop] = (state: PeerAddView.adding, poll: 7);
      expect(local.containsKey(kRooftop), isFalse);
    });

    test(
        'a local state is dropped once its peer is on the shelf, gone from '
        'the answer, or no longer addable here (PR :265)', () {
      final local = {
        kLighthouse: (state: PeerAddView.adding, poll: 9),
        kStatic: (state: PeerAddView.adding, poll: 9),
        kAttic: (state: PeerAddView.adding, poll: 9),
      };
      // Lighthouse landed; Attic is in neither list (gone).
      final landed = _view(
          shelf: [kBasement, kKitchen, kMstream, kLighthouse],
          addable: [kStatic, kRooftop]);
      final s = peerStripItems(landed, local: local, poll: 2);
      expect(_byId(s, kLighthouse).kind, PeerItemKind.peer);
      expect(s.local, {kStatic: local[kStatic]});
      expect(peerStripItems(_view(canAdd: false), local: local, poll: 2).local,
          isEmpty);
    });

    test(
        'the selected peer: kept while on the shelf (offline too); gone from '
        'the shelf → All (R5, PR :275)', () {
      final kitchen = peerStripItems(_view(canAdd: false), selected: kKitchen);
      expect(
          [
            kitchen.selected,
            kitchen.fallback,
            kitchen.items.first.selected,
            _byId(kitchen, kKitchen).selected,
          ],
          [kKitchen, false, false, true]);
      final offline = peerStripItems(_view(canAdd: false), selected: kMstream);
      expect([offline.selected, offline.fallback, _byId(offline, kMstream).selected],
          [kMstream, false, true]);
      // Rotated out: still announced (an admin sees it as "+"), not shelved.
      final rotated = _view(
          shelf: [kBasement, kAttic, kMstream],
          addable: [kKitchen, kLighthouse]);
      for (final v in [
        rotated,
        _view(canAdd: false, shelf: [kBasement, kAttic, kMstream]),
      ]) {
        final s = peerStripItems(v, selected: kKitchen);
        expect([s.selected, s.fallback, s.items.first.selected],
            [null, true, true]);
        expect(
            s.items.any((i) => i.selected && i.kind != PeerItemKind.all), isFalse);
      }
      expect(_byId(peerStripItems(rotated, selected: kKitchen), kKitchen).kind,
          PeerItemKind.add);
      // An addable peer is never a selection.
      expect(peerStripItems(rotated, selected: kLighthouse).fallback, isTrue);
    });

    test(
        'before the first answer: All alone, the selection and the local '
        'states untouched (PR :292)', () {
      final local = {kLighthouse: (state: PeerAddView.adding, poll: 1)};
      final s = peerStripItems(null, local: local);
      expect(s.items, hasLength(1));
      final all = s.items.single;
      expect([all.kind, all.id, all.label, all.selected, all.state, all.act],
          [PeerItemKind.all, null, '', true, null, PeerItemAct.tab]);
      expect([s.selected, s.fallback, s.local], [null, false, local]);
      final k = peerStripItems(null, selected: kKitchen);
      expect([k.selected, k.fallback, k.items.single.selected],
          [kKitchen, false, false]);
      expect(peerStripItems(_view(canAdd: false)).items, hasLength(5),
          reason: 'no options at all');
    });

    test('only well-formed endpoint ids are drawn, each once; hues are '
        'integers (PR :302)', () {
      final good = _row(kBasement);
      final v = parsePeers({
        ...peersMemberJson,
        'peers': [
          ...peersMemberJson['peers'] as List,
          {...good}, // a duplicate
          {...good, 'endpointId': kBasement.toUpperCase()}, // not lower case
          {...good, 'endpointId': '3f9a'}, // short
          {...good, 'endpointId': '${'a' * 63}"'}, // markup
          {...good, 'endpointId': null},
          null,
          'row',
          {...good, 'endpointId': 'ab07'.padRight(64, '0'), 'hue': '1;x', 'label': 'Odd Hue'},
        ],
      });
      final s = peerStripItems(v);
      expect(s.items.map((i) => i.id), [
        null,
        kBasement,
        kKitchen,
        kAttic,
        kMstream,
        'ab07'.padRight(64, '0'),
      ]);
      expect(_byId(s, 'ab07'.padRight(64, '0')).hue, 0);
      // The page's own check on a tapped item's id.
      expect(
          [
            kKitchen,
            kKitchen.toUpperCase(),
            '3f9a',
            '',
            null,
            '$kKitchen ',
          ].map(isEndpointId),
          [true, false, false, false, false, false]);
    });

    test('shelf rows ignore add (the server stamps it there too)', () {
      final s = peerStripItems(_view(states: {
        kBasement: _failed('no-room'),
        kKitchen: _done,
        kAttic: _adding,
      }));
      for (final id in [kBasement, kKitchen, kAttic]) {
        final i = _byId(s, id);
        expect([i.kind, i.state, i.act],
            [PeerItemKind.peer, null, PeerItemAct.tab],
            reason: id);
      }
      expect(peerPollDelay(s.items, 0), kPeerPoll,
          reason: 'a shelf row adding does not hurry the poll');
    });

    test('the signature: equal items sign alike, any drawn change differs', () {
      final a = peerStripItems(parsePeers(peersAdminJson));
      final b = peerStripItems(parsePeers(peersAdminJson));
      expect(a.items.map((i) => i.signature), b.items.map((i) => i.signature));
      String sig(PeerStrip s) => s.items.map((i) => i.signature).join('\n');
      expect(sig(peerStripItems(parsePeers(peersAdminJson), selected: kKitchen)),
          isNot(sig(a)), reason: 'the selection');
      expect(sig(peerStripItems(_view(states: {kStatic: _adding, kRooftop: _failed('no-room')}))),
          isNot(sig(a)), reason: 'an Add state');
      final renamed = {...peersAdminJson};
      (renamed['peers'] as List)[1] = {..._row(kKitchen), 'label': 'Kitchen Radio · cafe'};
      expect(sig(peerStripItems(parsePeers(renamed))), isNot(sig(a)),
          reason: 'a label');
      final moved = {...peersAdminJson};
      (moved['peers'] as List)[4] = {..._row(kLighthouse), 'rowCount': 1, 'add': null};
      expect(sig(peerStripItems(parsePeers(moved))), sig(a),
          reason: 'what is never drawn (rowCount) changes nothing');
    });
  });

  group('peerPollDelay (R6)', () {
    test('15 s, or 3 s while a shown row is adding or an own POST is out '
        '(PR :326)', () {
      expect([kPeerPoll, kPeerPollFast],
          [const Duration(seconds: 15), const Duration(seconds: 3)]);
      List<PeerStripItem> items(Map<String, Object?> states,
              [Map<String, PeerLocalAdd> local = const {}]) =>
          peerStripItems(_view(states: states), local: local).items;
      expect(peerPollDelay(items({}), 0), kPeerPoll);
      expect(peerPollDelay(items({kStatic: _adding}), 0), kPeerPollFast,
          reason: 'a server adding');
      expect(peerPollDelay(items({kStatic: _done}), 0), kPeerPollFast,
          reason: 'done, not yet on the shelf');
      expect(
          peerPollDelay(
              items({}, {kLighthouse: (state: PeerAddView.adding, poll: 0)}), 0),
          kPeerPollFast,
          reason: 'a local adding');
      expect(
          peerPollDelay(
              items({kRooftop: _failed('offline'), kStatic: _failed('no-room')}),
              0),
          kPeerPoll,
          reason: 'failed and No room do not hurry');
      expect(peerPollDelay(items({}), 1), kPeerPollFast,
          reason: 'an own POST out');
      expect(peerPollDelay(peerStripItems(_view(canAdd: false)).items, 0),
          kPeerPoll,
          reason: 'a member');
      expect(peerPollDelay(peerStripItems(null).items, 0), kPeerPoll);
    });
  });

  group('peerAddOutcome: what an Add\'s answer means for the strip (§5.6)', () {
    PeerAddAnswer answer(int status, [Map<String, dynamic>? body]) =>
        PeerAddAnswer(status, PeerAddState.fromServerMap(body));
    List<Object?> out(PeerAddAnswer a) {
      final o = peerAddOutcome(a);
      return [o.outcome, o.local, o.pollNow];
    }

    test(
        "the server's own answers: 202, 200 done, 200 failed (offline, "
        'bad-snapshot, no-room), 404, 409 ×2 (PR :372)', () {
      Map<String, dynamic> body(String state, [String? code]) => {
            'endpointId': kLighthouse,
            'state': state,
            'code': code,
            'at': '2026-11-19T10:00:00.000Z',
          };
      expect(out(answer(202, body('adding'))),
          [PeerAddOutcome.adding, PeerAddView.adding, false]);
      expect(out(answer(202)), [PeerAddOutcome.adding, PeerAddView.adding, false],
          reason: 'a 202 is adding, whatever its body');
      expect(out(answer(200, body('done'))),
          [PeerAddOutcome.landed, PeerAddView.adding, true]);
      expect(out(answer(200, body('adding'))),
          [PeerAddOutcome.adding, PeerAddView.adding, false]);
      for (final code in ['offline', 'bad-snapshot']) {
        expect(out(answer(200, body('failed', code))),
            [PeerAddOutcome.failed, PeerAddView.failed, false],
            reason: code);
      }
      expect(out(answer(200, body('failed', 'no-room'))),
          [PeerAddOutcome.noRoom, PeerAddView.noRoom, false]);
      for (final (status, error) in [
        (404, 'not-in-catalog'),
        (409, 'blocked'),
        (409, 'incompatible'),
      ]) {
        expect(out(answer(status, {'error': error})),
            [PeerAddOutcome.gone, null, true],
            reason: error);
      }
    });

    test(
        'failed codes decided later reach the client the same way: no-room is '
        'No room, any other is Try again (PR :416)', () {
      Map<String, dynamic> body(String? code) =>
          {'endpointId': kLighthouse, 'state': 'failed', 'code': code};
      expect(out(answer(200, body('no-room'))),
          [PeerAddOutcome.noRoom, PeerAddView.noRoom, false]);
      for (final code in [
        'offline',
        'no-disk',
        'bad-snapshot',
        'gone',
        'failed',
        null,
        'something-new',
      ]) {
        expect(out(answer(200, body(code))),
            [PeerAddOutcome.failed, PeerAddView.failed, false],
            reason: '$code');
      }
    });

    test(
        '403 / 405: not allowed (canAdd comes back false); 400 / 5xx / no '
        'answer: a local Try again until the next poll (PR :424)', () {
      for (final status in [403, 405]) {
        expect(out(answer(status, {'error': 'nope'})),
            [PeerAddOutcome.notAllowed, null, true],
            reason: '$status');
      }
      for (final (status, body) in <(int, Map<String, dynamic>?)>[
        (400, {'error': 'bad'}),
        (500, null),
        (502, null),
        (503, {}),
        (0, null),
        (401, {'error': 'x'}),
        (200, null),
        (200, {'state': 'odd'}),
      ]) {
        expect(out(answer(status, body)),
            [PeerAddOutcome.failed, PeerAddView.failed, false],
            reason: '$status $body');
      }
    });
  });

  group('peerLanded / peerEmptied (R4)', () {
    test("an own POST lands — through the server's Add, then on the poll "
        '(PR :435)', () {
      final before = _view();
      final adding = _view(states: {kLighthouse: _adding});
      final r1 = peerLanded(before, adding, {kLighthouse}, showingNoPeers: false);
      expect([r1.reask, r1.ids, r1.failed], [false, isEmpty, isEmpty],
          reason: 'still adding');
      // The download lands: the shelf holds it, its Add state is done.
      final after = _view(
          shelf: [kBasement, kKitchen, kAttic, kMstream, kLighthouse],
          addable: [kStatic, kRooftop],
          states: {kLighthouse: _done});
      expect(after.row(kLighthouse)!.onShelf, isTrue);
      final r2 = peerLanded(adding, after, {kLighthouse}, showingNoPeers: false);
      expect([r2.reask, r2.ids, r2.failed], [true, [kLighthouse], isEmpty]);
      // The next poll: it already landed.
      final r3 = peerLanded(after, after, {kLighthouse}, showingNoPeers: false);
      expect([r3.reask, r3.ids, r3.failed], [false, isEmpty, isEmpty]);
    });

    test('a done state counts before the shelf row shows (PR :452)', () {
      final r = peerLanded(_view(), _view(states: {kLighthouse: _done}),
          {kLighthouse},
          showingNoPeers: false);
      expect([r.reask, r.ids], [true, [kLighthouse]]);
    });

    test('an own Add that fails is reported once, so it stops being tracked '
        '(PR :460)', () {
      final adding = _view(states: {kLighthouse: _adding});
      final down = _view(states: {kLighthouse: _failed('offline')});
      final r = peerLanded(adding, down, {kLighthouse}, showingNoPeers: false);
      expect([r.reask, r.ids, r.failed], [false, isEmpty, [kLighthouse]]);
      expect(
          peerLanded(down, down, {kLighthouse}, showingNoPeers: false).failed,
          isEmpty,
          reason: 'a failed state already drawn is not news');
    });

    test('shelf.searchable 0 → more re-asks only while "No peers yet" shows '
        '(PR :467)', () {
      final empty = _view(shelf: []);
      final one = _view(shelf: [kBasement]);
      expect([empty.searchable, one.searchable], [0, 1]);
      expect(peerLanded(empty, one, {}, showingNoPeers: true).reask, isTrue);
      expect(peerLanded(null, one, {}, showingNoPeers: true).reask, isTrue,
          reason: 'no earlier answer counts as an empty shelf');
      expect(peerLanded(empty, one, {}, showingNoPeers: false).reask, isFalse,
          reason: 'a page with leads on it is left alone');
      expect(peerLanded(one, one, {}, showingNoPeers: true).reask, isFalse,
          reason: 'no change, no re-ask');
    });

    test('emptied: shelf.searchable more → 0 only (§2 item 18, PR :477)', () {
      final empty = _view(shelf: []);
      final one = _view(shelf: [kBasement]);
      final full = _view();
      expect(peerEmptied(one, empty), isTrue);
      expect(peerEmptied(full, empty), isTrue);
      expect(peerEmptied(empty, empty), isFalse, reason: 'already empty');
      expect(peerEmptied(full, one), isFalse,
          reason: 'a peer left, one stays: R5 and the strip, no re-ask');
      expect(peerEmptied(empty, one), isFalse, reason: "filling is R4's");
      expect(peerEmptied(null, empty), isFalse,
          reason: 'nothing before the first answer');
    });

    test("a rotation swap or another admin's Add only changes the strip "
        '(PR :490)', () {
      final before = _view();
      // Kitchen Radio rotated out; another admin's Lighthouse landed.
      final swapped = _view(
          shelf: [kBasement, kAttic, kMstream, kLighthouse],
          addable: [kKitchen, kStatic, kRooftop]);
      final r1 = peerLanded(before, swapped, {}, showingNoPeers: false);
      expect([r1.reask, r1.ids, r1.failed], [false, isEmpty, isEmpty]);
      final r2 = peerLanded(before, swapped, {kStatic}, showingNoPeers: true);
      expect([r2.reask, r2.ids, r2.failed], [false, isEmpty, isEmpty]);
    });
  });

  group('peerPreviewProvider and peerRetryDelay (§2 item 12, §5.5)', () {
    PluginListing listing(List<Object?> plugins) =>
        PluginListing.fromServerMap({'plugins': plugins});
    Map<String, dynamic> plugin(String name, List<String> caps,
            {bool? available}) =>
        {
          'name': name,
          'capabilities': caps,
          'available': ?available,
        };
    final links = plugin('links', ['links']);
    final deezer = plugin('deezer', ['preview']);
    final itunes = plugin('itunes', ['preview']);
    final copy = plugin('federation-copy', ['acquire']);

    test("the first previewing plug-in in the listing's order, and only it "
        '(PR :507)', () {
      final both = listing([links, deezer, itunes, copy]);
      expect(identical(peerPreviewProvider(both), both.plugins[1]), isTrue,
          reason: 'the listing entry itself');
      expect(peerPreviewProvider(listing([links, itunes]))!.name, 'itunes');
      expect(peerPreviewProvider(listing([links, copy])), isNull);
      expect(peerPreviewProvider(listing([])), isNull);
      expect(peerPreviewProvider(null), isNull);
      // Listing order, not a preference: itunes listed first previews alone.
      expect(peerPreviewProvider(listing([itunes, deezer]))!.name, 'itunes');
    });

    test('odd listings (PR :520), and a plug-in that cannot run here is '
        'skipped (phone, plan D6)', () {
      expect(
          peerPreviewProvider(listing([
            null,
            'deezer',
            {'capabilities': ['preview']},
            {'name': '  ', 'capabilities': ['preview']},
            {'name': 'x', 'capabilities': 'preview'},
          ])),
          isNull);
      final off = listing([plugin('deezer', ['preview'], available: false), itunes]);
      expect(peerPreviewProvider(off)!.name, 'itunes',
          reason: "the sheet's rows skip it too (PluginListing.previews)");
      expect(peerPreviewProvider(listing([plugin('deezer', ['preview'], available: false)])),
          isNull);
      expect(
          peerPreviewProvider(PluginListing(const [
            DiscoveryPlugin(name: ' ', capabilities: [kCapPreview]),
          ])),
          isNull);
    });

    test('a 429 waits 5 s (deezer, any other) or 60 s (itunes) before its one '
        'retry (PR :526)', () {
      expect(
          [
            'deezer',
            'itunes',
            'links',
            'some-new-one',
            '',
            '__proto__',
            'constructor',
          ].map((p) => peerRetryDelay(p).inSeconds),
          [5, 60, 5, 5, 5, 5, 5]);
    });
  });

  group("peerArtMatches: when a preview's artwork stands in for the tile "
      '(§2 item 10)', () {
    test(
        "the lead's own album and artist, nameKey-folded — so it spreads to "
        'every lead with the same tile key (PR :538)', () {
      expect(peerArtMatches(_signal, deezerPreview()), isTrue);
      expect(peerArtMatches(_harbor, deezerPreview()), isTrue,
          reason: 'the same preview matches the other spelling');
      expect(
          peerArtMatches(_signal,
              deezerPreview(artist: '  PAPER  LANTERN', album: 'night ferry')),
          isTrue);
      expect(peerArtMatches(_signal, deezerPreview(album: 'Night Ferry – Live')),
          isFalse,
          reason: 'another album');
      expect(
          peerArtMatches(_signal, deezerPreview(album: 'Night Ferry (Deluxe)')),
          isFalse);
      expect(peerArtMatches(_signal, deezerPreview(artist: 'Paper Lanterns')),
          isFalse,
          reason: 'another artist');
      expect(peerArtMatches(_signal, deezerPreview(artist: null)), isFalse);
      expect(peerArtMatches(_long, deezerPreview()), isFalse,
          reason: 'another lead');
      // Dashes and quotes fold the way the server built the tile keys.
      final dashed = _with(_signal, {'album': 'Night‐Ferry', 'artist': 'Paper’s Lantern'});
      expect(
          peerArtMatches(
              dashed, deezerPreview(album: 'night-ferry', artist: "paper's lantern")),
          isTrue);
    });

    test('a lead without an album never earns art, even from an album-less '
        'preview (PR :552)', () {
      expect(_copper.album, isNull);
      expect(
          peerArtMatches(
              _copper, deezerPreview(artist: 'Kestrel & Vine', album: null)),
          isFalse);
      expect(
          peerArtMatches(
              _copper, deezerPreview(artist: 'Kestrel & Vine', album: '')),
          isFalse);
      expect(
          peerArtMatches(
              _with(_signal, {'album': '   '}), deezerPreview(album: '   ')),
          isFalse);
    });

    test('https artwork only (PR :559)', () {
      for (final artwork in [
        null,
        'http://e-cdns-images.example/cover.jpg',
        '//e-cdns-images.example/cover.jpg',
        'javascript:alert(1)',
        'data:image/png;base64,AAAA',
        'cover.jpg',
        'https//nope',
        'https:///no-host.jpg',
      ]) {
        expect(peerArtMatches(_signal, deezerPreview(artwork: artwork)), isFalse,
            reason: '$artwork');
      }
      expect(
          peerArtMatches(_signal,
              deezerPreview(artwork: 'HTTPS://E-CDNS-IMAGES.EXAMPLE/cover.jpg')),
          isTrue);
    });
  });

  group('peerLeadKey (§5.3)', () {
    test("the peer's endpointId and the snapshot's exportId (PR :571)", () {
      expect(peerLeadKey(_signal), '$kKitchen\u0000x1');
      expect(peerLeadKey(_harbor), '$kBasement\u0000x2');
      expect(peerLeadKey(_with(_signal, {'peer': {'endpointId': kBasement, 'name': 'B'}})),
          isNot(peerLeadKey(_signal)),
          reason: 'the same export on another peer');
      expect(peerLeadKey(_signal.withRaw(_signal.recommendation!)),
          peerLeadKey(_signal),
          reason: "the sheet's repaired lead keys the same");
    });

    test('without an exportId: the folded artist, title and album (PR :578)',
        () {
      final noId = _with(_signal, {'exportId': null});
      expect(peerLeadKey(noId),
          '$kKitchen\u0000paper lantern|signal fires|night ferry');
      expect(
          peerLeadKey(
              _with(noId, {'artist': '  PAPER   Lantern', 'exportId': ''})),
          peerLeadKey(noId));
      expect(peerLeadKey(_with(_copper, {'exportId': null})),
          '$kKitchen\u0000kestrel & vine|copper dawn|');
      expect(peerLeadKey(DiscoveryLead.fromServerMap({'title': 'Loose'})!),
          '\u0000|loose|',
          reason: 'no peer');
      expect(peerLeadKey(_with(_signal, {'exportId': 42})),
          peerLeadKey(noId),
          reason: 'an export id is a string (the parser drops any other)');
    });
  });

  group("peerNextIndex: Preview all's next lead", () {
    test(
        "the next lead not in the visit's \"No preview\" set; -1 after the "
        'last (PR :589)', () {
      bool Function(DiscoveryLead) skipping(Iterable<DiscoveryLead> none) {
        final keys = {for (final l in none) peerLeadKey(l)};
        return (l) => keys.contains(peerLeadKey(l));
      }

      expect(peerNextIndex(_leads, -1, skipping([])), 0, reason: 'from the top');
      expect(peerNextIndex(_leads, 0, skipping([])), 1);
      final none = skipping([_harbor, _long]);
      expect(peerNextIndex(_leads, 0, none), 3,
          reason: 'skips the leads with no preview');
      expect(peerNextIndex(_leads, -1, skipping([_signal])), 1);
      expect(peerNextIndex(_leads, 5, none), -1, reason: 'the end');
      expect(peerNextIndex(_leads, 3, skipping([_untitled, _copper])), -1,
          reason: 'every rest skipped');
      expect(peerNextIndex(_leads, 3, skipping([_untitled])), 5);
      expect(peerNextIndex(const [], -1, skipping([])), -1);
      expect(peerNextIndex(_leads, -7, skipping([])), 0,
          reason: 'any negative index is the top');
    });
  });

  group('peerCopyText / peerCopyListText (§5.7)', () {
    DiscoveryLead bare(String artist, String title) =>
        DiscoveryLead(artist, title, 0, null, null, const [], null);

    test('"Artist - Title", or the title alone when there is no artist '
        '(PR :606)', () {
      expect(peerCopyText(_signal), 'Paper Lantern - Signal Fires');
      expect(peerCopyText(_harbor), 'PAPER   lantern - Harbor Lights',
          reason: 'the artist as sent, trimmed');
      expect(peerCopyText(_untitled), 'Untitled Lead', reason: 'no leading "- "');
      expect(peerCopyText(bare('  ', 'Only Title')), 'Only Title');
      expect(peerCopyText(bare('Only Artist', '')), 'Only Artist');
      expect(peerCopyText(bare(' A ', '  T  ')), 'A - T');
      expect(_harbor.copyText, '  PAPER   lantern  - Harbor Lights',
          reason: 'DiscoveryLead.copyText trims nothing: the page uses its own');
    });

    test("the tab's leads in list order, joined by \\n, no trailing newline "
        '(PR :616)', () {
      final text = peerCopyListText(_leads);
      expect(
          text,
          [
            'Paper Lantern - Signal Fires',
            'PAPER   lantern - Harbor Lights',
            'Marlowe Fields - Long Exposure',
            'Juniper Static - Arcade Rain',
            'Untitled Lead',
            'Kestrel & Vine - Copper Dawn',
          ].join('\n'));
      expect(text.endsWith('\n'), isFalse);
      expect(peerCopyListText([_arcade]), 'Juniper Static - Arcade Rain');
      expect(peerCopyListText(const []), '');
      expect(peerCopyListText([_signal, bare(' ', ' '), _arcade]),
          'Paper Lantern - Signal Fires\nJuniper Static - Arcade Rain',
          reason: 'an empty line is dropped');
    });
  });

  group('the page requests (R1, R2)', () {
    test(
        'peerRecsRequest: the R1 body — the network alone, its own limits, '
        'a walk on a random seed too, never moods (DP :256)', () {
      expect(
          peerRecsRequest(window: 30, pins: ['/testlib/Vosto/Highway.mp3'])
              .toJson(),
          {
            'window': 30,
            'pin': ['testlib/Vosto/Highway.mp3'],
            'sources': ['network'],
            'limit': {'seeds': 12, 'network': 32},
            'newArtistsOnly': false,
            'networkOnRandomSeed': true,
          },
          reason: 'no networkPeers for All');
      expect(
          peerRecsRequest(window: 90, pins: ['/Music/now.flac'], exclude: ['h1', 'r1'])
              .toJson(),
          {
            'window': 90,
            'pin': ['Music/now.flac'],
            'exclude': ['h1', 'r1'],
            'sources': ['network'],
            'limit': {'seeds': 12, 'network': 32},
            'newArtistsOnly': false,
            'networkOnRandomSeed': true,
          });
      expect(peerRecsRequest(window: 30).toJson(), {
        'window': 30,
        'sources': ['network'],
        'limit': {'seeds': 12, 'network': 32},
        'newArtistsOnly': false,
        'networkOnRandomSeed': true,
      }, reason: 'a bare open');
      final r = peerRecsRequest(window: 30, peer: kKitchen);
      expect(r.toJson()['networkPeers'], [kKitchen]);
      expect([r.moods, r.ignoreVPaths], [null, null]);
      expect(r.limit, same(kPeerRecsLimits));
      // Pins as the route takes them: one per path, none empty or past 2048.
      expect(
          peerRecsRequest(window: 30, pins: [
            '/a.mp3',
            'a.mp3',
            '//a.mp3',
            '/',
            '',
            '/${'x' * 2049}',
            for (var i = 0; i < 14; i++) '/p$i',
          ]).toJson()['pin'],
          ['a.mp3', for (var i = 0; i < 11; i++) 'p$i']);
    });

    test(
        'networkPeers: lower-cased, 64 hex only, de-duplicated — none left, '
        'no key (DP :271)', () {
      expect(peerRecsRequest(window: 30, peer: kKitchen.toUpperCase())
          .toJson()['networkPeers'], [kKitchen]);
      for (final none in ['', 'nope', kKitchen.substring(2), ' $kKitchen']) {
        expect(peerRecsRequest(window: 30, peer: none).toJson()
            .containsKey('networkPeers'), isFalse, reason: none);
      }
    });

    group('peerRecsBatchRequest: a re-ask on the batch on screen', () {
      Map<String, dynamic> seed(int i, {String? path, bool pinned = false, String? outcome = 'completed'}) =>
          seedJson('h$i', path ?? 'Music/S/$i.flac', 'S$i', pinned: pinned, outcome: outcome);
      final batch = parseTaste(tasteJson(
          seeds: [seed(0, pinned: true), seed(1), seed(2)], leads: const []));

      test(
          "a peer's tab: every seed of the batch pinned, limit.seeds = their "
          'count, networkPeers = that peer (DP :547)', () {
        final out = peerRecsBatchRequest(batch,
            window: 7, exclude: ['hx'], peer: kKitchen)!;
        expect(out.toJson(), {
          'window': 7,
          'pin': ['Music/S/0.flac', 'Music/S/1.flac', 'Music/S/2.flac'],
          'exclude': ['hx'],
          'sources': ['network'],
          'limit': {'seeds': 3, 'network': 32},
          'newArtistsOnly': false,
          'networkOnRandomSeed': true,
          'networkPeers': [kKitchen],
        });
        expect(
            peerRecsBatchRequest(batch, window: 7, peer: kKitchen.toUpperCase())!
                .toJson()['networkPeers'],
            [kKitchen],
            reason: 'cleaned as R1 cleans it');
        expect(peerBatchPins(batch),
            ['/Music/S/0.flac', '/Music/S/1.flac', '/Music/S/2.flac'],
            reason: 'app paths; toJson strips the slash');
      });

      test(
          'All: the key left out; an id that is no endpoint id is All '
          '(DP :560)', () {
        for (final all in [null, '', 'all', 'b2' * 31]) {
          final j = peerRecsBatchRequest(batch, window: 7, peer: all)!.toJson();
          expect(j.containsKey('networkPeers'), isFalse, reason: '$all');
          expect((j['limit'] as Map)['seeds'], 3);
        }
        expect(
            peerRecsBatchRequest(batch, window: 7, peer: 'a1' * 32)!
                .toJson()['networkPeers'],
            ['a1' * 32],
            reason: 'another tab');
      });

      test("a random answer's pick is pinned too (the page walks the network "
          'on it) (DP :572)', () {
        final random = parseTaste(tasteJson(
            seedSource: 'random', seeds: [seed(9, outcome: null)], leads: const []));
        final j = peerRecsBatchRequest(random, window: 30, peer: kKitchen)!.toJson();
        expect(j['pin'], ['Music/S/9.flac']);
        expect((j['limit'] as Map)['seeds'], 1);
      });

      test(
          'a full batch; past the pin cap (a malformed answer) the first '
          'ones; bad paths skipped (DP :580)', () {
        final full = parseTaste(tasteJson(
            seeds: [for (var i = 0; i < 12; i++) seed(i, pinned: i == 0)],
            leads: const []));
        final all = peerRecsBatchRequest(full, window: 30)!.toJson();
        expect(all['pin'], [for (var i = 0; i < 12; i++) 'Music/S/$i.flac']);
        expect((all['limit'] as Map)['seeds'], 12);
        final odd = parseTaste(tasteJson(seeds: [
          seed(0, path: '/Music/S/0.flac'),
          seed(9, path: ''),
          seed(1, path: 'Music/S/0.flac'),
          seed(8, path: 'x' * 2049),
          for (var i = 0; i < 12; i++) seed(i + 2),
        ], leads: const []));
        final out = peerRecsBatchRequest(odd, window: 30)!.toJson();
        expect(out['pin'], hasLength(kTastePinMax));
        expect((out['pin'] as List).sublist(0, 2),
            ['Music/S/0.flac', 'Music/S/2.flac'],
            reason: 'the leading / stripped, a duplicate, an empty and an '
                'over-long path skipped');
        // The route takes a 2048-char pin (Joi max 2048), as the webapp
        // sends it.
        final long = 'y' * 2048;
        expect(
            peerRecsBatchRequest(parseTaste(tasteJson(seeds: [seed(1, path: long)], leads: const [])),
                    window: 30)!
                .toJson()['pin'],
            [long]);
      });

      test(
          'null: a batch with no seed with a path (the caller asks a new '
          'batch) (DP :592)', () {
        for (final bad in [
          tasteJson(seeds: [], leads: const []),
          tasteJson(seeds: [seed(1, path: '')], leads: const []),
          {'seedSource': 'history'},
        ]) {
          expect(peerRecsBatchRequest(parseTaste(bad), window: 30), isNull,
              reason: '$bad');
        }
      });
    });

    test(
        'peerNoPickLeft: no seed at all on a random or scan-pending answer — '
        'never a listed seed (DP :639)', () {
      TasteResponse r(String source, List<Map<String, dynamic>> seeds,
              {bool notAnalyzed = false}) =>
          parseTaste(tasteJson(
              seedSource: source,
              seeds: seeds,
              notAnalyzed: notAnalyzed,
              leads: const []));
      expect(peerNoPickLeft(r('random', [], notAnalyzed: true)), isTrue);
      expect(peerNoPickLeft(r('random', [])), isTrue);
      expect(peerNoPickLeft(r('history', [], notAnalyzed: true)), isTrue);
      expect(peerNoPickLeft(r('history', [])), isFalse);
      expect(
          peerNoPickLeft(r('random', [seedJson('r1', 'Music/r1.flac', 'R1', outcome: null)])),
          isFalse);
      expect(
          peerNoPickLeft(r('history', [seedJson('h1', 'Music/h1.flac', 'H1', analyzed: false)],
              notAnalyzed: true)),
          isFalse);
    });
  });

  group('peerRecsStateOf (DP.networkState / DP.stateOf, page branch)', () {
    PeerRecsState state(Map<String, dynamic>? json,
            {bool loading = false, bool disabled = false, PeerView? peers}) =>
        peerRecsStateOf(
            shown: json == null ? null : parseTaste(json),
            loading: loading,
            disabled: disabled,
            peers: peers);
    Map<String, dynamic> empty(String? reason, {String seedSource = 'history'}) =>
        tasteJson(seedSource: seedSource, leads: const [], reason: reason);

    test(
        'a 403 with the flags on is scan pending; a history answer with '
        "network: null is the controller's R7, read here as failed (DP :2733)",
        () {
      expect(state(tasteJson(), disabled: true), PeerRecsState.scanPending);
      expect(state(null, disabled: true, loading: true),
          PeerRecsState.scanPending);
      expect(state(tasteJson(networkNull: true)), PeerRecsState.failed);
      expect(state(tasteJson()), PeerRecsState.ready);
    });

    test('loading and failed', () {
      expect(state(null, loading: true), PeerRecsState.loading);
      expect(state(null), PeerRecsState.failed, reason: '"Try again" alone');
      expect(state(tasteJson(), loading: true), PeerRecsState.ready,
          reason: 'an answer on screen stays drawn while the next is out');
    });

    test(
        'a random seed with a network section is ready — never "finish a few '
        'songs" (DP :2780)', () {
      final pick = [seedJson('r', 'Music/r.flac', 'R', outcome: null)];
      expect(state(tasteJson(seedSource: 'random', seeds: pick)),
          PeerRecsState.ready);
      expect(
          state(tasteJson(
              seedSource: 'random', seeds: pick, leads: const [], reason: 'empty-shelf')),
          PeerRecsState.noPeers,
          reason: "the network's own empty state");
      expect(state(tasteJson(seedSource: 'random', seeds: pick, networkNull: true)),
          PeerRecsState.failed,
          reason: 'no section on a random answer: "Try again" (the peers '
              "poll's 403 catches p2p off)");
    });

    test('scan pending: no seed analyzed, or the network says so', () {
      expect(state(tasteJson(notAnalyzed: true, leads: const [])),
          PeerRecsState.scanPending);
      expect(state(tasteJson(notAnalyzed: true)), PeerRecsState.scanPending);
      expect(state(empty('scan-pending')), PeerRecsState.scanPending,
          reason: "by the network's reason alone");
      expect(state(empty('scan-pending', seedSource: 'random')),
          PeerRecsState.scanPending,
          reason: 'a random pick with no vector too');
    });

    test(
        "the network names its emptiness by the server's reason — rows win "
        'over a reason (DP :2835)', () {
      for (final reason in ['empty-shelf', 'no-compatible']) {
        expect(state(empty(reason)), PeerRecsState.noPeers, reason: reason);
      }
      for (final reason in ['nothing-new', null, 'something-later']) {
        expect(state(empty(reason)), PeerRecsState.nothingNew,
            reason: '$reason');
      }
      expect(state(empty('error')), PeerRecsState.failed,
          reason: 'the walk failed: "Try again" alone');
      expect(state(tasteJson(reason: 'empty-shelf')), PeerRecsState.ready,
          reason: 'rows win over a reason');
      expect(state(tasteJson(reason: 'error')), PeerRecsState.ready);
    });

    test('a shelf with nothing searchable is "No peers yet"', () {
      final emptyShelf = _view(shelf: [], canAdd: false);
      expect(state(empty('nothing-new'), peers: emptyShelf),
          PeerRecsState.noPeers);
      expect(state(empty(null), peers: emptyShelf), PeerRecsState.noPeers);
      expect(state(empty('nothing-new'), peers: _view()),
          PeerRecsState.nothingNew);
      expect(state(empty('nothing-new')), PeerRecsState.nothingNew,
          reason: 'before the first poll');
      expect(state(tasteJson(), peers: emptyShelf), PeerRecsState.ready,
          reason: 'leads on screen are drawn');
    });
  });
}
