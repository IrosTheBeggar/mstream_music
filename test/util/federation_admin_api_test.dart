// The admin federation client against canned server answers: the row
// shapes the routes really send (snake_case SQLite columns, 0/1 booleans,
// `datetime('now')` timestamps), the access verdicts read off the guard's
// status codes, and the request bodies the server's Joi schemas expect.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/util/federation_admin_api.dart';

void main() {
  final server = Server('http://music.test:3000', 'rig', 'pw', 'jwt-123', 'music');

  FederationAdminApi api(Future<http.Response> Function(http.Request) handler) =>
      FederationAdminApi(server, client: MockClient(handler));

  test('status: the auth header rides along and the shape maps', () async {
    late http.Request seen;
    final a = api((req) async {
      seen = req;
      return http.Response(
          jsonEncode({
            'enabled': true,
            'available': true,
            'running': true,
            'endpointId': 'abc',
            'online': true,
            'relayUrl': 'https://use1-1.relay.iroh.network',
            'limitDefaults': {'streamKbps': 8000, 'dailyMb': 2048, 'maxStreams': 3},
            'acceptRequests': false,
          }),
          200);
    });
    final s = await a.status();
    expect(seen.url.toString(), 'http://music.test:3000/api/v1/admin/federation');
    expect(seen.headers['x-access-token'], 'jwt-123');
    expect(s.enabled, isTrue);
    expect(s.online, isTrue);
    expect(s.relayUrl, contains('iroh'));
    expect(s.limitDefaults, const FederationLimits(streamKbps: 8000, dailyMb: 2048, maxStreams: 3));
    expect(s.acceptRequests, isFalse);
  });

  test('the guard\'s status codes become access verdicts', () async {
    Future<FederationAccess?> verdict(int code, String error) async {
      final a = api((_) async => http.Response(jsonEncode({'error': error}), code));
      try {
        await a.status();
        return null;
      } on FederationAdminException catch (e) {
        expect(e.message, error);
        return e.access;
      }
    }

    expect(await verdict(403, 'Admin access required'), FederationAccess.member);
    expect(await verdict(403, 'Admin access restricted to local network'),
        FederationAccess.restricted);
    expect(await verdict(405, 'Admin API Disabled'), FederationAccess.disabled);
    expect(await verdict(404, 'Not found'), FederationAccess.unsupported);
    expect(await verdict(409, 'already federated'), isNull);
  });

  test('a non-JSON error body still throws with the status', () async {
    final a = api((_) async => http.Response('<html>nope</html>', 502));
    expect(a.keys(), throwsA(isA<FederationAdminException>()
        .having((e) => e.status, 'status', 502)
        .having((e) => e.message, 'message', 'HTTP 502')));
  });

  test('keys: SQLite rows map, claimed and expired read off the columns', () async {
    final a = api((_) async => http.Response(
        jsonEncode([
          {
            'id': 4,
            'key': 'fedk_secret',
            'name': "Bob's NAS",
            'stream_kbps': 8000,
            'daily_mb': 2048,
            'max_streams': 3,
            'expires_at': null,
            'expired': 0,
            'created_at': '2026-09-01 10:00:00',
            'last_used': '2026-09-06 14:02:11',
            'bound_endpoint_id': 'ep-bob',
            'bound_at': '2026-09-03 09:00:00',
            'library_names': ['Vinyl', 'Podcasts'],
            'usage_today_bytes': 1288490188,
            'ticket': 'mstrfed1:abc',
          },
          {
            'id': 5,
            'name': 'Carla',
            'stream_kbps': 0,
            'daily_mb': 0,
            'max_streams': 0,
            'expires_at': '2026-09-12 00:00:00',
            'expired': 1,
            'library_names': ['Lossless'],
            'ticket': null,
          },
        ]),
        200));
    final keys = await a.keys();
    expect(keys.length, 2);
    final bob = keys[0];
    expect(bob.name, "Bob's NAS");
    expect(bob.libraryNames, ['Vinyl', 'Podcasts']);
    expect(bob.limits.streamKbps, 8000);
    expect(bob.claimed, isTrue);
    expect(bob.expired, isFalse);
    expect(bob.usageTodayBytes, 1288490188);
    expect(bob.lastUsed, DateTime.utc(2026, 9, 6, 14, 2, 11).toLocal());
    expect(bob.ticket, 'mstrfed1:abc');
    final carla = keys[1];
    expect(carla.claimed, isFalse);
    expect(carla.expired, isTrue);
    expect(carla.expiresAt, DateTime.utc(2026, 9, 12).toLocal());
    expect(carla.ticket, isNull);
    expect(carla.limits, const FederationLimits(streamKbps: 0, dailyMb: 0, maxStreams: 0));
  });

  test('mint posts the Joi shape and reads the canonical row back', () async {
    late Map body;
    final a = api((req) async {
      if (req.method == 'GET') {
        // The list row: snake_case columns and the granted names, which
        // the mint response lacks (it carries camelCase limits and no
        // libraries at all).
        return http.Response(
            jsonEncode([
              {'id': 9, 'name': 'Bob', 'stream_kbps': 320, 'daily_mb': 500, 'max_streams': 1, 'library_names': ['Vinyl'], 'ticket': 'mstrfed1:zzz'},
            ]),
            200);
      }
      body = jsonDecode(req.body);
      return http.Response(jsonEncode({'id': 9, 'name': 'Bob', 'key': 'fedk_x', 'ticket': 'mstrfed1:zzz', 'streamKbps': 320, 'dailyMb': 500, 'maxStreams': 1, 'expiresAt': null}), 200);
    });
    final k = await a.mint(
        name: 'Bob',
        vpaths: ['Vinyl'],
        limits: const FederationLimits(streamKbps: 320, dailyMb: 500, maxStreams: 1),
        expiresAt: DateTime.utc(2030, 1, 1));
    expect(body, {
      'name': 'Bob',
      'vpaths': ['Vinyl'],
      'streamKbps': 320,
      'dailyMb': 500,
      'maxStreams': 1,
      'expiresAt': '2030-01-01T00:00:00.000Z',
    });
    expect(k.id, 9);
    expect(k.ticket, 'mstrfed1:zzz');
    expect(k.libraryNames, ['Vinyl']);
    expect(k.limits.streamKbps, 320);
  });

  test('a mint response stands in when the list cannot be re-read', () async {
    final a = api((req) async {
      if (req.method == 'GET') return http.Response('boom', 500);
      return http.Response(jsonEncode({'id': 3, 'name': 'Al', 'ticket': 't', 'streamKbps': 8000, 'dailyMb': 2048, 'maxStreams': 3}), 200);
    });
    final k = await a.mint(name: 'Al', vpaths: ['A'], limits: FederationLimits.fallback);
    expect(k.id, 3);
    expect(k.limits.streamKbps, 8000, reason: 'camelCase limits are read too');
    expect(k.libraryNames, isEmpty);
  });

  test('limits: expiry is tri-state (absent, null, ISO)', () async {
    final bodies = <Map>[];
    final a = api((req) async {
      bodies.add(jsonDecode(req.body));
      return http.Response('{}', 200);
    });
    const l = FederationLimits(streamKbps: 1, dailyMb: 2, maxStreams: 3);
    await a.setKeyLimits(4, l);
    await a.setKeyLimits(4, l, clearExpiry: true);
    await a.setKeyLimits(4, l, expiresAt: DateTime.utc(2031));
    expect(bodies[0].containsKey('expiresAt'), isFalse);
    expect(bodies[1]['expiresAt'], isNull);
    expect(bodies[1].containsKey('expiresAt'), isTrue);
    expect(bodies[2]['expiresAt'], '2031-01-01T00:00:00.000Z');
  });

  test('peers and requests: 0/1 flags, arrays, directions', () async {
    final a = api((req) async {
      if (req.url.path.endsWith('/peers')) {
        return http.Response(
            jsonEncode([
              {'id': 2, 'name': 'peer-a', 'last_status': 'ok', 'last_seen': '2026-09-06 14:05:00', 'use_discovery': 1, 'added_at': '2026-09-01 00:00:00'},
              {'id': 3, 'name': 'peer-b', 'last_status': null, 'last_seen': null, 'use_discovery': 0},
            ]),
            200);
      }
      return http.Response(
          jsonEncode({
            'acceptRequests': true,
            'requests': [
              {'id': 1, 'direction': 'in', 'state': 'received', 'peer_name': 'studio', 'peer_endpoint_id': 'ep1', 'message': 'hi', 'offered_libraries': ['Field'], 'created_at': '2026-09-06 12:00:00'},
              {'id': 2, 'direction': 'out', 'state': 'delivered', 'peer_endpoint_id': 'ep2', 'offered_libraries': []},
              {'id': 3, 'direction': 'out', 'state': 'rejected', 'peer_endpoint_id': 'ep3', 'reject_reason': 'no thanks'},
            ],
          }),
          200);
    });
    final peers = await a.peers();
    expect(peers[0].reachable, isTrue);
    expect(peers[0].useDiscovery, isTrue);
    expect(peers[1].reachable, isFalse);
    expect(peers[1].lastStatus, isNull);
    final r = await a.requests();
    expect(r.acceptRequests, isTrue);
    expect(r.requests[0].awaitingAnswer, isTrue);
    expect(r.requests[0].offeredLibraries, ['Field']);
    expect(r.requests[1].canCancel, isTrue);
    expect(r.requests[1].isActive, isTrue);
    expect(r.requests[2].isActive, isFalse);
    expect(r.requests[2].canCancel, isFalse);
    expect(r.requests[2].rejectReason, 'no thanks');
  });

  test('add peer sends the ticket and an optional name only when given', () async {
    final bodies = <Map>[];
    final a = api((req) async {
      bodies.add(jsonDecode(req.body));
      return http.Response(jsonEncode({'id': 7, 'name': 'Carla', 'ticketLibraries': ['Lossless']}), 200);
    });
    final p = await a.addPeer(ticket: 'mstrfed1:abc');
    await a.addPeer(ticket: 'mstrfed1:abc', name: '  Carla  ');
    expect(bodies[0], {'ticket': 'mstrfed1:abc'});
    expect(bodies[1], {'ticket': 'mstrfed1:abc', 'name': 'Carla'});
    expect(p.id, 7);
  });

  test('sqliteUtc reads both the SQLite and ISO forms', () {
    expect(sqliteUtc('2026-09-06 14:05:00'), DateTime.utc(2026, 9, 6, 14, 5).toLocal());
    expect(sqliteUtc('2026-09-06T14:05:00.000Z'), DateTime.utc(2026, 9, 6, 14, 5).toLocal());
    expect(sqliteUtc(null), isNull);
    expect(sqliteUtc(''), isNull);
  });
}
