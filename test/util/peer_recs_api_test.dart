// PeerRecsApi against a MockClient (mStream docs/peer-recommendations-plan.md
// §3.2, §3.3; the server's literal answers, src/api/discovery-p2p.js and
// src/state/discovery-peer-add.js): the peers poll parsed on a 200, any other
// answer read by its status alone, 0 when nothing answered; an Add posting
// {endpointId} with the token and carrying the stored state of a 200 / 202;
// always the user's OWN server; never a throw.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mstream_music/objects/peer_recs.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/util/peer_recs_api.dart';
import 'package:mstream_music/util/peer_recs_rules.dart' show PeerAddOutcome, peerAddOutcome;

import '../screens/discovery/peer_recs_fixtures.dart';

final home = Server('http://home.local:3000', null, null, 'JWT', 'home');

/// A connected server's virtual Server under [home] (proxy path).
Server peerOf(Server parent) =>
    Server('federated://home/1', null, null, null, 'peer-1')
      ..federationParent = 'home'
      ..federationPeerId = 1
      ..parentServer = parent;

http.Response json(Object? body, [int status = 200]) => http.Response(
    jsonEncode(body), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

http.Response error(String message, int status) => json({'error': message}, status);

/// The Add's answer body as the server writes it (discovery-peer-add.js).
Map<String, dynamic> addBody(String state, [String? code]) => {
      'endpointId': kLighthouse,
      'state': state,
      'code': code,
      'at': '2026-11-19T10:00:00.000Z',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<http.Request> seen;
  late Future<http.Response> Function(http.Request) handler;
  PeerRecsApi api([Server? s, Duration? timeout]) => PeerRecsApi(s ?? home,
      client: MockClient((req) async {
        seen.add(req);
        return handler(req);
      }),
      timeout: timeout ?? const Duration(seconds: 15));

  setUp(() {
    seen = [];
    handler = (_) async => json({});
  });

  test('peers 200 parses; 403/404/500 carry the status; a transport error is 0; a non-object 200 has no view', () async {
    handler = (_) async => json(peersAdminJson);
    final ok = await api().peers();
    expect([seen.single.method, seen.single.url.toString()],
        ['GET', 'http://home.local:3000/api/v1/discovery/p2p/peers']);
    expect(seen.single.headers['x-access-token'], 'JWT');
    expect(ok.status, 200);
    final view = ok.view!;
    expect([view.canAdd, view.held, view.searchable, view.running], [true, 4, 4, false]);
    expect(view.peers.map((p) => p.endpointId).toList(),
        [kBasement, kKitchen, kAttic, kMstream, kLighthouse, kStatic, kRooftop]);
    expect(view.row(kMstream)!.label, 'mStream · 3f9a', reason: 'the server-stamped label, verbatim');
    expect(view.row(kStatic)!.add!.state, PeerAddKind.adding);
    expect(view.row(kRooftop)!.add!.code, 'offline');

    handler = (_) async => json(peersMemberJson);
    final member = (await api().peers()).view!;
    expect(member.canAdd, isFalse);
    expect(member.peers, hasLength(4));

    for (final (status, message) in [
      (403, 'discovery P2P is disabled (config: discoveryP2p.enabled)'),
      (403, 'Forbidden'),
      (404, 'Not Found'),
      (500, 'boom'),
      (401, 'Authentication Error'),
    ]) {
      handler = (_) async => error(message, status);
      final a = await api().peers();
      expect([a.status, a.view], [status, null], reason: '$status $message');
    }
    // an error status with no JSON body at all
    handler = (_) async => http.Response('<html>bad gateway</html>', 502);
    final gateway = await api().peers();
    expect([gateway.status, gateway.view], [502, null]);

    handler = (_) async => throw http.ClientException('connection refused');
    final down = await api().peers();
    expect([down.status, down.view], [0, null]);
    handler = (_) async => throw const SocketLikeError();
    expect((await api().peers()).status, 0, reason: 'any thrown error reads as no answer');

    for (final body in ['[]', '"ok"', 'null', '', 'not json', '42']) {
      handler = (_) async => http.Response(body, 200);
      final a = await api().peers();
      expect([a.status, a.view], [200, null], reason: 'body $body');
    }
  });

  test('peers that run past the bound answer 0, never throw', () async {
    final never = Completer<http.Response>();
    handler = (_) => never.future;
    final a = await api(null, const Duration(milliseconds: 20)).peers();
    expect([a.status, a.view], [0, null]);
    expect(seen, hasLength(1));
  });

  test('add posts {endpointId} with the token', () async {
    handler = (_) async => json(addBody('adding'), 202);
    await api().add(kLighthouse);
    final req = seen.single;
    expect([req.method, req.url.toString()],
        ['POST', 'http://home.local:3000/api/v1/admin/discovery/p2p/peer-dbs/add']);
    expect(req.headers['x-access-token'], 'JWT');
    expect(req.headers['content-type'], startsWith('application/json'));
    expect(jsonDecode(req.body), {'endpointId': kLighthouse});

    // an account with no token sends an empty one, as every direct call does
    final guest = Server('http://guest.local:3000', null, null, null, 'guest');
    await api(guest).add(kStatic);
    expect(seen.last.headers['x-access-token'], '');
    expect(jsonDecode(seen.last.body), {'endpointId': kStatic});
  });

  test('add maps 202 adding, 200 done, 200 failed no-room, 404, 409, 403, 405, 400, 0', () async {
    Future<PeerAddAnswer> answer(http.Response res) {
      handler = (_) async => res;
      return api().add(kLighthouse);
    }

    final adding = await answer(json(addBody('adding'), 202));
    expect(adding.status, 202);
    expect([adding.state!.state, adding.state!.code, adding.state!.noRoom],
        [PeerAddKind.adding, null, false]);
    expect(adding.state!.at, DateTime.utc(2026, 11, 19, 10));

    final done = await answer(json(addBody('done')));
    expect([done.status, done.state!.state], [200, PeerAddKind.done]);

    final already = await answer(json(addBody('adding')));
    expect([already.status, already.state!.state], [200, PeerAddKind.adding]);

    final noRoom = await answer(json(addBody('failed', 'no-room')));
    expect([noRoom.status, noRoom.state!.state, noRoom.state!.code, noRoom.state!.noRoom],
        [200, PeerAddKind.failed, 'no-room', true]);

    for (final code in ['offline', 'bad-snapshot']) {
      final failed = await answer(json(addBody('failed', code)));
      expect([failed.status, failed.state!.state, failed.state!.code, failed.state!.noRoom],
          [200, PeerAddKind.failed, code, false]);
    }

    // the refusals carry their status alone: the server's words are never read
    for (final (status, message) in [
      (404, 'not-in-catalog'),
      (409, 'blocked'),
      (409, 'incompatible'),
      (403, 'Admin access required'),
      (403, 'Admin access restricted to local network'),
      (403, 'discovery P2P is disabled (config: discoveryP2p.enabled)'),
      (405, 'Admin API Disabled'),
      (400, '"endpointId" must only contain hexadecimal characters'),
      (500, 'boom'),
    ]) {
      final a = await answer(error(message, status));
      expect([a.status, a.state], [status, null], reason: '$status $message');
    }

    // a 200 the client cannot read: its status, no state
    for (final body in ['[]', 'null', '', 'not json', '{"state":"queued"}', '{"code":"no-room"}']) {
      final a = await answer(http.Response(body, 200));
      expect([a.status, a.state], [200, null], reason: 'body $body');
    }

    // what the page's rules make of each answer (the webapp's addOutcome
    // over statusReq's {status, body}; server.md §2.6)
    for (final (res, outcome) in [
      (json(addBody('adding'), 202), PeerAddOutcome.adding),
      (json(addBody('done')), PeerAddOutcome.landed),
      (json(addBody('adding')), PeerAddOutcome.adding),
      (json(addBody('failed', 'no-room')), PeerAddOutcome.noRoom),
      (json(addBody('failed', 'offline')), PeerAddOutcome.failed),
      (error('not-in-catalog', 404), PeerAddOutcome.gone),
      (error('blocked', 409), PeerAddOutcome.gone),
      (error('Admin access required', 403), PeerAddOutcome.notAllowed),
      (error('Admin API Disabled', 405), PeerAddOutcome.notAllowed),
      (error('"endpointId" is required', 400), PeerAddOutcome.failed),
      (http.Response('not json', 200), PeerAddOutcome.failed),
    ]) {
      expect(peerAddOutcome(await answer(res)).outcome, outcome,
          reason: '${res.statusCode} ${res.body}');
    }

    handler = (_) async => throw http.ClientException('connection reset');
    final lost = await api().add(kLighthouse);
    expect([lost.status, lost.state], [0, null]);
    expect(peerAddOutcome(lost).outcome, PeerAddOutcome.failed);

    final never = Completer<http.Response>();
    handler = (_) => never.future;
    final slow = await api(null, const Duration(milliseconds: 20)).add(kLighthouse);
    expect([slow.status, slow.state], [0, null], reason: 'the bound ran out');
  });

  test("the own server for a connected server's virtual Server", () async {
    handler = (req) async => req.method == 'GET'
        ? json(peersMemberJson)
        : json(addBody('adding'), 202);
    final a = api(peerOf(home));
    expect(identical(a.server, home), isTrue);
    expect((await a.peers()).status, 200);
    await a.add(kLighthouse);
    expect(seen.map((r) => r.url.toString()).toList(), [
      'http://home.local:3000/api/v1/discovery/p2p/peers',
      'http://home.local:3000/api/v1/admin/discovery/p2p/peer-dbs/add',
    ], reason: "the parent's own routes, never the proxy path to the peer");
    expect(seen.map((r) => r.headers['x-access-token']).toSet(), {'JWT'},
        reason: "the parent's token");

    // a connected server whose parent is not linked: nothing is sent
    final orphan = Server('federated://gone/1', null, null, null, 'peer-x')
      ..federationParent = 'gone'
      ..federationPeerId = 1;
    final o = api(orphan);
    expect(o.server, isNull);
    final p = await o.peers();
    final add = await o.add(kLighthouse);
    expect([p.status, p.view, add.status, add.state], [0, null, 0, null]);
    expect(seen, hasLength(2));
  });
}

/// A thrown value that is not an http exception (a socket or TLS error
/// surfaces as one of these on some platforms).
class SocketLikeError implements Exception {
  const SocketLikeError();
}
