// The discovery-network admin client against the shapes the routes send:
// the status object with its nested watchdog/recovery, catalog entries
// (payload + live decorations), the activity ring, the request bodies the
// Joi schemas expect, and the relationship helper the catalog chips use.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/util/federation_admin_api.dart';
import 'package:mstream_music/util/p2p_admin_api.dart';

void main() {
  final server = Server('http://music.test:3000', 'rig', 'pw', 'jwt-123', 'music');
  P2pAdminApi api(Future<http.Response> Function(http.Request) handler) =>
      P2pAdminApi(server, client: MockClient(handler));

  test('status maps the nested watchdog and recovery, and the derived states', () async {
    final a = api((req) async {
      expect(req.url.path, '/api/v1/admin/discovery/p2p/status');
      expect(req.headers['x-access-token'], 'jwt-123');
      return http.Response(
          jsonEncode({
            'enabled': true, 'binaryFound': true, 'binaryFetchable': true, 'running': true,
            'endpointId': 'a' * 64, 'ticket': 'endpointabc', 'joined': true, 'neighbors': 0,
            'watchdog': {'lastRssMb': 187.6, 'restarts': 1, 'maxRssMb': 256},
            'recovery': {'attempts': 2, 'retryPending': true},
            'knownPeers': 37, 'communitySeeds': true, 'serverName': 'Rum.st', 'serverDescription': 'Jazz',
            'maxPeerDbStorageMb': 2048, 'autoFetchCount': 6, 'rotationDays': 7, 'peerRetentionDays': 30,
            'blockedPeers': ['b' * 64],
          }),
          200);
    });
    final s = await a.status();
    expect(s.sidecarRssMb, 187.6);
    expect(s.watchdogRestarts, 1);
    expect(s.recovering, isTrue, reason: 'attempts > 0 and no neighbor');
    expect(s.searching, isTrue, reason: 'no neighbor yet');
    expect(s.unavailable, isFalse);
    expect(s.blockedPeers.length, 1);
    expect(s.serverName, 'Rum.st');
  });

  test('a missing binary with nothing downloadable is unavailable', () {
    final s = P2pStatus.fromJson({'enabled': false, 'binaryFound': false, 'binaryFetchable': false});
    expect(s.unavailable, isTrue);
    expect(s.searching, isFalse);
  });

  test('catalog entries: payload fields, decorations, held totals', () async {
    final a = api((req) async {
      expect(req.url.query, 'includeIncompatible=1');
      return http.Response(
          jsonEncode({
            'peers': [
              {
                'from': 'c' * 64,
                'payload': {'name': 'Vinyl Vault', 'description': 'Jazz', 'rowCount': 12480, 'modelId': 'm1', 'snapshotSeq': 43},
                'firstSeenAt': '2026-09-01T10:00:00.000Z', 'updatedAt': '2026-09-07T00:40:00.000Z',
                'online': true, 'seeders': 2,
                'fetched': {'snapshotSeq': 42, 'stale': true, 'sizeBytes': 220000000, 'fetchedAt': '2026-09-03T09:00:00.000Z', 'firstFetchedAt': '2026-09-03T09:00:00.000Z', 'pinned': true},
                'compatible': true,
              },
              {'from': 'd' * 64, 'payload': {'name': '', 'rowCount': 2100}, 'online': false, 'seeders': 0, 'fetched': null, 'compatible': false},
            ],
            'hiddenIncompatible': 3, 'localModelId': 'm1', 'autoFetch': true,
            'storage': {'usedBytes': 1288490188, 'capBytes': 2147483648},
          }),
          200);
    });
    final c = await a.catalog(includeIncompatible: true);
    expect(c.peers.length, 2);
    final v = c.peers[0];
    expect(v.name, 'Vinyl Vault');
    expect(v.trackCount, 12480);
    expect(v.downloaded, isTrue);
    expect(v.updateAvailable, isTrue, reason: 'announced 43, held 42');
    expect(v.fetched!.pinned, isTrue);
    expect(v.compatible, isTrue);
    final d = c.peers[1];
    expect(d.name, isNull, reason: 'blank names read as unnamed');
    expect(d.shortId, '${'d' * 12}…');
    expect(d.downloaded, isFalse);
    expect(c.hiddenIncompatible, 3);
    expect(c.held.length, 1);
    expect(c.heldTrackTotal, 12480);
    expect(c.storageCapBytes, 2147483648);
  });

  test('activity reads entries and the cursor', () async {
    final a = api((req) async {
      expect(req.url.query, 'since=40');
      return http.Response(jsonEncode({'entries': [{'seq': 41, 't': '2026-09-07T00:41:00.000Z', 'level': 'info', 'message': 'announce ok'}], 'lastSeq': 41}), 200);
    });
    final r = await a.activity(since: 40);
    expect(r.lastSeq, 41);
    expect(r.entries.single.message, 'announce ok');
    expect(r.entries.single.at, DateTime.utc(2026, 9, 7, 0, 41).toLocal());
  });

  test('request bodies match the Joi schemas', () async {
    final seen = <String, Map>{};
    final a = api((req) async {
      seen[req.url.path.split('/').skip(6).join('/')] = jsonDecode(req.body);
      return http.Response(jsonEncode({'enabled': true, 'acceptRequests': true}), 200);
    });
    final r = await a.setEnabled(true, acceptFederationRequests: true);
    expect(r.acceptRequests, isTrue);
    await a.setEnabled(false, acceptFederationRequests: true);
    await a.join(' endpointxyz ', persist: true);
    await a.fetchSnapshot('e' * 64);
    await a.pinSnapshot('e' * 64, false);
    await a.removeSnapshot('e' * 64);
    await a.forget('e' * 64);
    await a.block('e' * 64);
    await a.unblock('e' * 64);
    await a.setName(' Rum.st ');
    await a.setDescription('Jazz');
    await a.setMaxStorageMb(2048);
    await a.setAutoFetchCount(6);
    await a.setRotationDays(7);
    await a.setPeerRetentionDays(30);
    expect(seen['enabled'], {'enabled': false}, reason: 'the opt-in only rides with enable=true (last call wins here)');
    expect(seen['join'], {'peer': 'endpointxyz', 'persist': true});
    expect(seen['peer-dbs/fetch'], {'endpointId': 'e' * 64});
    expect(seen['peer-dbs/pin'], {'endpointId': 'e' * 64, 'pinned': false});
    expect(seen['peer-dbs/remove'], {'endpointId': 'e' * 64});
    expect(seen['forget'], {'endpointId': 'e' * 64});
    expect(seen['block'], {'endpointId': 'e' * 64});
    expect(seen['unblock'], {'endpointId': 'e' * 64});
    expect(seen['name'], {'name': 'Rum.st'});
    expect(seen['description'], {'description': 'Jazz'});
    expect(seen['max-storage'], {'maxPeerDbStorageMb': 2048});
    expect(seen['auto-fetch-count'], {'autoFetchCount': 6});
    expect(seen['rotation'], {'rotationDays': 7});
    expect(seen['peer-retention'], {'peerRetentionDays': 30});
  });

  test('enable carries the opt-in and reports a failed inbox half', () async {
    late Map body;
    final a = api((req) async {
      body = jsonDecode(req.body);
      return http.Response(jsonEncode({'enabled': true, 'acceptRequests': false, 'federationError': 'no binary'}), 200);
    });
    final r = await a.setEnabled(true, acceptFederationRequests: true);
    expect(body, {'enabled': true, 'acceptFederationRequests': true});
    expect(r.enabled, isTrue);
    expect(r.acceptRequests, isFalse);
    expect(r.federationError, 'no binary');
  });

  test('the guard verdicts arrive as federation exceptions', () async {
    final a = api((_) async => http.Response(jsonEncode({'error': 'Admin access required'}), 403));
    expect(a.status(), throwsA(isA<FederationAdminException>().having((e) => e.access, 'access', FederationAccess.member)));
  });

  test('federationStateFor mirrors the webapp chips', () {
    FederationRequest req(String dir, String state, {String ep = 'x'}) =>
        FederationRequest(id: 1, direction: dir, state: state, peerEndpointId: ep);
    expect(federationStateFor([req('out', 'completed')], 'x'), P2pFederationState.federated);
    expect(federationStateFor([req('in', 'received')], 'x'), P2pFederationState.theirs);
    expect(federationStateFor([req('in', 'granting')], 'x'), P2pFederationState.theirs);
    expect(federationStateFor([req('out', 'delivered')], 'x'), P2pFederationState.sent);
    expect(federationStateFor([req('out', 'rejected')], 'x'), P2pFederationState.none);
    expect(federationStateFor([req('out', 'delivered', ep: 'y')], 'x'), P2pFederationState.none);
    expect(federationStateFor([req('in', 'received'), req('out', 'completed')], 'x'),
        P2pFederationState.federated, reason: 'completed wins');
  });

  test('composeRequest posts the endpoint, message and offer', () async {
    late Map body;
    final fed = FederationAdminApi(server, client: MockClient((req) async {
      body = jsonDecode(req.body);
      return http.Response(jsonEncode({'id': 5, 'direction': 'out', 'state': 'pending-delivery', 'peer_endpoint_id': 'x'}), 200);
    }));
    final r = await fed.composeRequest('x', message: ' hi ', offerVpaths: ['Vinyl']);
    expect(body, {'endpointId': 'x', 'message': 'hi', 'offerVpaths': ['Vinyl']});
    expect(r.state, 'pending-delivery');
    await fed.composeRequest('x');
    expect(body, {'endpointId': 'x', 'offerVpaths': []});
  });
}
