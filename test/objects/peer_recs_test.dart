import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/discovery.dart';
import 'package:mstream_music/objects/peer_recs.dart';

import '../screens/discovery/peer_recs_fixtures.dart';

// The peers route and the Add answer (mStream
// docs/peer-recommendations-plan.md §3.2; src/state/discovery-peer-view.js
// buildPeerView, src/state/discovery-peer-add.js wire). The samples are the
// server's own buildPeerView over the stage's peers.

void main() {
  group('PeerView.fromServerMap', () {
    test('the §3.2 admin sample', () {
      final v = parsePeers(peersAdminJson);
      expect([v.canAdd, v.held, v.searchable, v.running], [true, 4, 4, false]);
      expect(v.peers.map((p) => p.endpointId), [
        kBasement,
        kKitchen,
        kAttic,
        kMstream,
        kLighthouse,
        kStatic,
        kRooftop,
      ]);
      expect(v.peers.map((p) => p.label), [
        'Basement Hi-Fi',
        'Kitchen Radio',
        'Attic Tapes',
        'mStream · 3f9a',
        'Lighthouse Tapes',
        'Static Garden',
        'Rooftop FM',
      ]);
      expect(v.peers.map((p) => p.monogram),
          ['BH', 'KR', 'AT', 'mS', 'LT', 'SG', 'RF'],
          reason: 'verbatim: mS keeps its case');
      expect(v.peers.map((p) => p.hue), [210, 25, 112, 140, 280, 330, 232]);
      expect(v.peers.map((p) => p.online),
          [true, true, false, false, true, true, true]);
      expect(v.peers.map((p) => p.onShelf),
          [true, true, true, true, false, false, false]);
      expect(v.peers.map((p) => p.pinned),
          [true, true, false, true, false, false, false]);
      expect(v.peers.map((p) => p.rowCount), [5, 5, 2, 2, 9400, 7000, 3100]);
      final mstream = v.row(kMstream)!;
      expect([mstream.name, mstream.label], ['mStream', 'mStream · 3f9a']);

      final adding = v.row(kStatic)!.add!;
      expect([adding.state, adding.code, adding.noRoom],
          [PeerAddKind.adding, null, false]);
      expect(adding.at, DateTime.utc(2026, 11, 19, 10));
      final failed = v.row(kRooftop)!.add!;
      expect([failed.state, failed.code, failed.noRoom],
          [PeerAddKind.failed, 'offline', false]);
      for (final id in [kBasement, kKitchen, kAttic, kMstream, kLighthouse]) {
        expect(v.row(id)!.add, isNull, reason: id);
      }
      expect(v.row('f' * 64), isNull);
      expect(() => (v.peers as List).add(v.peers.first), throwsUnsupportedError);
    });

    test('the member sample', () {
      final v = parsePeers(peersMemberJson);
      expect(v.canAdd, isFalse);
      expect([v.held, v.searchable], [4, 4], reason: 'the same shelf');
      expect(v.peers.map((p) => p.endpointId),
          [kBasement, kKitchen, kAttic, kMstream]);
      expect(v.peers.every((p) => p.onShelf && p.add == null), isTrue);
    });

    test('bad ids dropped', () {
      final good = (peersAdminJson['peers'] as List).first as Map<String, dynamic>;
      final v = PeerView.fromServerMap({
        'canAdd': false,
        'shelf': {'held': 1, 'searchable': 1, 'running': true},
        'peers': [
          good,
          {...good}, // a duplicate
          {...good, 'endpointId': kBasement.toUpperCase()}, // not folded
          {...good, 'endpointId': kKitchen.substring(1)}, // 63 chars
          {...good, 'endpointId': '${kKitchen}0'}, // 65 chars
          {...good, 'endpointId': 'g' * 64}, // not hex
          {...good, 'endpointId': ' $kKitchen'}, // padded
          {...good, 'endpointId': null},
          {...good, 'endpointId': 42},
          null,
          'row',
          42,
          [good],
          {...good, 'endpointId': kKitchen, 'name': 'Kitchen Radio', 'label': 'Kitchen Radio'},
        ],
      })!;
      expect(v.peers.map((p) => p.endpointId), [kBasement, kKitchen]);
      expect(v.running, isTrue);
      for (final bad in [null, 'peers', 42, [peersAdminJson]]) {
        expect(PeerView.fromServerMap(bad), isNull, reason: '$bad');
      }
      final empty = PeerView.fromServerMap(<String, dynamic>{})!;
      expect([empty.canAdd, empty.held, empty.searchable, empty.running, empty.peers],
          [false, 0, 0, false, isEmpty], reason: 'shelf missing → zeros');
      final odd = PeerView.fromServerMap({
        'canAdd': 'true',
        'shelf': {'held': -2, 'searchable': 1.5, 'running': 'yes'},
        'peers': 'none',
      })!;
      expect([odd.canAdd, odd.held, odd.searchable, odd.running, odd.peers],
          [false, 0, 0, false, isEmpty]);
      expect(PeerView.fromServerMap({'shelf': {'held': 3.0, 'searchable': 2}})!.held, 3,
          reason: 'a whole number sent as a double');
    });

    test('every add state and code', () {
      PeerAddState? add(Object? a) {
        final row = {...(peersAdminJson['peers'] as List)[4] as Map<String, dynamic>, 'add': a};
        return PeerView.fromServerMap({'canAdd': true, 'peers': [row]})!.peers.single.add;
      }

      final at = '2026-11-19T10:00:00.000Z';
      expect(add({'state': 'adding', 'code': null, 'at': at})!.state, PeerAddKind.adding);
      expect(add({'state': 'done', 'code': null, 'at': at})!.state, PeerAddKind.done);
      for (final code in ['no-room', 'no-disk', 'offline', 'bad-snapshot', 'gone', 'failed', 'something-new']) {
        final s = add({'state': 'failed', 'code': code, 'at': at})!;
        expect([s.state, s.code, s.noRoom], [PeerAddKind.failed, code, code == 'no-room'], reason: code);
      }
      final nullCode = add({'state': 'failed', 'code': null, 'at': at})!;
      expect([nullCode.code, nullCode.noRoom], [null, false]);
      expect(add({'state': 'adding', 'code': 7, 'at': 12})!.code, isNull);
      expect(add({'state': 'adding', 'at': 12})!.at, isNull);
      expect(add({'state': 'adding', 'at': 'soon'})!.at, isNull);
      expect(add({'state': 'done', 'at': '2026-11-19T12:00:00+02:00'})!.at,
          DateTime.utc(2026, 11, 19, 10));
      expect(add({'state': 'adding', 'code': 'no-room'})!.noRoom, isFalse,
          reason: 'only a failed Add finds no room');
      for (final bad in [
        null,
        'adding',
        42,
        <String, dynamic>{},
        {'state': 'mystery'},
        {'state': 'Adding'},
        {'state': null, 'code': 'no-room'},
        {'code': 'offline'},
      ]) {
        expect(add(bad), isNull, reason: '$bad');
      }
      // The Add route's own answer body (H reads it with the same parser).
      final body = PeerAddState.fromServerMap({
        'endpointId': kLighthouse,
        'state': 'failed',
        'code': 'no-room',
        'at': at,
      })!;
      expect(body.noRoom, isTrue);
    });

    test('hue folding', () {
      int hue(Object? h) {
        final row = {...(peersAdminJson['peers'] as List).first as Map<String, dynamic>, 'hue': h};
        return PeerView.fromServerMap({'peers': [row]})!.peers.single.hue;
      }

      expect(hue(400), 40);
      expect(hue(-10), 350);
      expect(hue('x'), 0);
      expect([360, 361, -30, 210.4, 359.6, 0, -2.5, 2.5].map(hue),
          [0, 1, 330, 210, 0, 0, 358, 3],
          reason: "the webapp's hueOf: JS Math.round, then into 0..359");
      for (final bad in [double.nan, double.infinity, '210', null, true, <String, dynamic>{}]) {
        expect(hue(bad), 0, reason: '$bad');
      }
    });

    test('label falls back to the trimmed name', () {
      PeerRow row(Map<String, dynamic> over) => PeerView.fromServerMap({
            'peers': [
              {'endpointId': kKitchen, 'onShelf': true, ...over},
            ],
          })!.peers.single;
      expect(row({'name': '  Kitchen Radio ', 'label': 'Kitchen Radio · cafe'}).label,
          'Kitchen Radio · cafe', reason: 'the label, verbatim');
      expect(row({'name': '  Kitchen Radio ', 'label': '  '}).label, 'Kitchen Radio');
      expect(row({'name': '  Kitchen Radio ', 'label': null}).label, 'Kitchen Radio');
      expect(row({'name': '  Kitchen Radio '}).label, 'Kitchen Radio');
      expect(row({'name': 'Kitchen', 'label': ' Kitchen '}).label, ' Kitchen ',
          reason: 'a label that is not blank is never trimmed');
      final bare = row({});
      expect([bare.name, bare.label, bare.monogram, bare.hue, bare.online, bare.pinned, bare.rowCount, bare.add],
          ['', '', '', 0, false, false, null, null]);
      expect(row({'name': 42, 'monogram': 7}).name, '');
      expect(row({'monogram': ''}).monogram, '');
      expect(row({'rowCount': -1}).rowCount, isNull);
      expect(row({'onShelf': 'true'}).onShelf, isFalse);
    });
  });

  // The shared fixtures every other piece builds on: hold them to the stage
  // (server.md §4.3 — rank order, tiles, peers, ISRCs).
  group('the stage fixtures', () {
    test('12 leads in rank order with their tiles; Basement 5, Kitchen 5, mStream 2', () {
      final leads = parseLeads(tasteJson());
      expect(leads.map((l) => l.title), [
        'Salt Road',
        'Breakwater',
        'Signal Fires',
        'Harbor Lights',
        'Glass Season',
        'Quiet Engine',
        'Long Exposure',
        'Arcade Rain',
        'Paper Moons',
        'Sunday Wire',
        'Copper Dawn',
        'Field Notes',
      ]);
      expect(leads.map((l) => l.tile!.hue), [203, 203, 39, 39, 4, 4, 352, 78, 154, 353, 53, 81]);
      expect(leads.every((l) => l.source == 'p2p' && l.seedHash == kSeedHash && l.isNetwork), isTrue);
      expect([for (final id in [kBasement, kKitchen, kMstream]) leads.where((l) => l.endpointId == id).length],
          [5, 5, 2]);
      expect(stageLeadsOf(kKitchen), hasLength(5));
      final signal = leads[2];
      expect([signal.isrc, signal.peerName, signal.peerLabel, signal.exportId, signal.similarity],
          ['QZPRS2600003', 'Kitchen Radio', 'Kitchen Radio', 'anon:03', 0.9213]);
      expect(signal.tile, const LeadTile('paper lantern|night ferry', 39, 'P'));
      final copper = leads[10];
      expect([copper.album, copper.tile!.key, copper.isrc], [null, 'kestrel & vine', null]);
      final quiet = leads[5];
      expect([quiet.peerName, quiet.peerLabel], ['mStream', 'mStream · 3f9a']);
      expect(leads.every((l) => l.recommendation != null), isTrue, reason: 'every lead is sendable');
      final r = parseTaste(tasteJson());
      expect([r.seedSource, r.fallback, r.seeds.single.filepath, r.library, r.peers, r.network!.reason],
          [TasteSeedSource.history, false, kSeedPath, null, null, null]);
      final random = parseTaste(tasteJson(seedSource: 'random', networkNull: true));
      expect([random.seedSource, random.fallback, random.network], [TasteSeedSource.random, true, null]);
      expect(parseTaste(tasteJson(leads: const [], reason: 'empty-shelf')).network!.reason, NetworkReason.emptyShelf);
      expect(leadJson().containsKey('tile'), isFalse);
      expect(deezerPreview().artwork!.scheme, 'https');
    });
  });

  group('the answers', () {
    test('PeersAnswer and PeerAddAnswer carry the status and what was read', () {
      final view = parsePeers(peersMemberJson);
      expect([PeersAnswer(200, view).status, PeersAnswer(200, view).view], [200, view]);
      expect([const PeersAnswer(0).status, const PeersAnswer(0).view], [0, null]);
      final state = PeerAddState.fromServerMap({'state': 'adding'});
      expect([PeerAddAnswer(202, state).status, PeerAddAnswer(202, state).state], [202, state]);
      expect(const PeerAddAnswer(404).state, isNull);
    });
  });
}
