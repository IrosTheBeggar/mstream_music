// DiscoveryPluginsApi against a MockClient: method, path and body on the
// wire; always the user's OWN server (a connected server's virtual Server
// resolves to its parent); recommendations sent exactly as received; the
// server's error words surfaced verbatim; a cancel that lost the race
// (409) read as "already finished"; the batch lookup in chunks of 100.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mstream_music/objects/discovery_plugins.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/api.dart';
import 'package:mstream_music/util/discovery_plugins_api.dart';

final home = Server('http://home.local:3000', null, null, 'JWT', 'home');

/// A connected server's virtual Server under [home] (proxy path).
Server peerOf(Server parent) => Server('federated://home/1', null, null, null, 'peer-1')
  ..federationParent = 'home'
  ..federationPeerId = 1
  ..parentServer = parent;

http.Response json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

/// A taste peers row exactly as the route sends it (extra keys included:
/// the server's schema strips them, the client never does).
final row = Map<String, dynamic>.unmodifiable({
  'artist': 'Boukmanflow',
  'title': 'Late Train Verse',
  'album': 'Borrowed Tapes',
  'albumArtist': null,
  'year': 2019,
  'duration': 221,
  'similarity': 0.91,
  'genreTags': ['Hip Hop---Boom Bap'],
  'recordingMbid': null,
  'albumArt': 'abc123.jpg',
  'seedHash': 'h1',
  'filepath': 'peerlib/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3',
  'peer': {'id': 1, 'name': 'Stage Peer B'},
  'source': 'federation',
});

Map<String, dynamic> jobWire({int id = 7, String state = 'queued', Map<String, dynamic>? params}) => {
      'id': id,
      'plugin': 'federation-copy',
      'key': 'text:x',
      'recommendation': row,
      'params': params,
      'state': state,
      'progress': null,
      'statusText': null,
      'result': null,
      'error': null,
      'attempts': 0,
      'cancelRequested': false,
      'createdAt': 1,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<http.Request> seen;
  late Future<http.Response> Function(http.Request) handler;
  DiscoveryPluginsApi api([Server? s]) => DiscoveryPluginsApi(s ?? home, client: MockClient((req) async {
        seen.add(req);
        return handler(req);
      }));

  setUp(() {
    seen = [];
    handler = (_) async => json({});
  });

  test("a connected server's Server resolves to its parent: every call is the user's own server's", () async {
    handler = (_) async => json({'plugins': [], 'jobs': {'allowed': true}});
    final a = api(peerOf(home));
    expect(identical(a.server, home), isTrue);
    await a.plugins();
    expect(seen.single.url.toString(), 'http://home.local:3000/api/v1/discovery/plugins');
    expect(seen.single.headers['x-access-token'], 'JWT');
    // a peer whose parent is not linked: nothing is sent
    final orphan = Server('federated://gone/1', null, null, null, 'peer-x')
      ..federationParent = 'gone'
      ..federationPeerId = 1;
    await expectLater(api(orphan).plugins(), throwsA(isA<DiscoveryPluginsException>().having((e) => e.status, 'status', 0)));
    expect(seen, hasLength(1));
  });

  test('GET the listing and the destination; PUT a destination, and null for the default', () async {
    handler = (req) async => req.url.path.endsWith('/plugins')
        ? json({
            'plugins': [
              {'name': 'federation-copy', 'scopes': ['song', 'album']}
            ],
            'jobs': {'allowed': true}
          })
        : json({
            'destination': {'vpath': 'demo', 'base': 'From peers', 'layout': '{{ARTIST}}/{{ALBUM}}', 'source': 'user'},
            'saved': {'vpath': 'demo', 'base': 'From peers', 'layout': '{{ARTIST}}/{{ALBUM}}'},
            'libraries': [{'vpath': 'demo', 'template': null}],
          });
    final a = api();
    expect((await a.plugins()).copy!.scopes, ['song', 'album']);
    final d = await a.destination();
    expect([seen.last.method, seen.last.url.path], ['GET', '/api/v1/discovery/collection/destination']);
    expect(d.destination!.source, 'user');
    await a.saveDestination(const CollectionDestination(vpath: 'demo', base: 'From peers', layout: '{{ARTIST}}/{{ALBUM}}'));
    expect([seen.last.method, seen.last.url.path], ['PUT', '/api/v1/discovery/collection/destination']);
    expect(jsonDecode(seen.last.body), {
      'destination': {'vpath': 'demo', 'base': 'From peers', 'layout': '{{ARTIST}}/{{ALBUM}}'}
    });
    await a.saveDestination(null);
    expect(jsonDecode(seen.last.body), {'destination': null}, reason: '"Use the library default"');
  });

  test("a refused save carries the server's reason, verbatim", () async {
    handler = (_) async => json({'error': 'destination layout: unknown variable {{TRACK}}'}, 400);
    await expectLater(
        api().saveDestination(const CollectionDestination(vpath: 'demo', layout: '{{TRACK}}')),
        throwsA(isA<DiscoveryPluginsException>()
            .having((e) => e.status, 'status', 400)
            .having((e) => e.message, 'message', 'destination layout: unknown variable {{TRACK}}')
            .having((e) => e.fromServer, 'fromServer', true)));
  });

  group('start a job', () {
    test('a song: the row exactly as received, no scope; 202 = created', () async {
      handler = (_) async => json({'job': jobWire(), 'created': true}, 202);
      final r = await api().startJob(row);
      expect([seen.single.method, seen.single.url.path], ['POST', '/api/v1/discovery/plugins/federation-copy/jobs']);
      final body = jsonDecode(seen.single.body) as Map;
      expect(body.keys, ['recommendation'], reason: 'a song job sends no scope');
      expect(body['recommendation'], jsonDecode(jsonEncode(row)), reason: 'unchanged — seedHash, similarity, albumArt and all');
      expect([r.created, r.job.id, r.job.state], [true, 7, JobState.queued]);
    });

    test('an album: scope album; 200 = your own live job for the same key', () async {
      handler = (_) async => json({'job': jobWire(state: 'running', params: {'scope': 'album'}), 'created': false});
      final r = await api().startJob(row, scope: 'album');
      expect((jsonDecode(seen.single.body) as Map)['scope'], 'album');
      expect([r.created, r.job.scope], [false, 'album']);
      // 'song' is the same as no scope
      await api().startJob(row, scope: 'song');
      expect((jsonDecode(seen.last.body) as Map).containsKey('scope'), isFalse);
    });

    test("every refusal is the server's own words: 400, 403, 404, 409, 429", () async {
      for (final (status, words) in [
        (400, 'a album job needs the recommendation\'s album'),
        (403, 'Uploading Disabled'),
        (404, 'unknown discovery plug-in'),
        (409, 'someone else on this server is already getting this — try again in a moment'),
        (429, 'you have 20 jobs queued or running — wait for some to finish (the limit is 20)'),
      ]) {
        handler = (_) async => json({'error': words}, status);
        await expectLater(
            api().startJob(row, scope: 'album'),
            throwsA(isA<DiscoveryPluginsException>()
                .having((e) => e.status, 'status', status)
                .having((e) => e.message, 'message', words)
                .having((e) => e.fromServer, 'fromServer', true)),
            reason: '$status');
      }
      handler = (_) async => http.Response('<html>bad gateway</html>', 502);
      await expectLater(api().startJob(row),
          throwsA(isA<DiscoveryPluginsException>().having((e) => e.message, 'message', 'HTTP 502').having((e) => e.fromServer, 'fromServer', false)));
      handler = (_) async => throw http.ClientException('Connection refused');
      await expectLater(api().startJob(row), throwsA(isA<DiscoveryPluginsException>().having((e) => e.status, 'status', 0)));
    });
  });

  group('a start sends the place it showed', () {
    const shown = ShownPlace(CollectionDestination(vpath: 'copies', base: 'From peers', layout: '{{ALBUMARTIST}}/{{ALBUM}}', source: 'user'));
    const words = 'your collection destination has changed — check where this will land and ask again';
    Map<String, dynamic> moved(Object? destination) =>
        {'error': 'destination_changed', 'message': words, 'destination': destination};

    test('{vpath, base, layout} beside the row, its source dropped; no place shown sends none', () async {
      handler = (_) async => json({'job': jobWire(), 'created': true}, 202);
      await api().startJob(row, scope: 'album', destination: shown);
      expect(jsonDecode(seen.single.body), {
        'recommendation': jsonDecode(jsonEncode(row)),
        'scope': 'album',
        'destination': {'vpath': 'copies', 'base': 'From peers', 'layout': '{{ALBUMARTIST}}/{{ALBUM}}'},
      });
      await api().startJob(row);
      expect((jsonDecode(seen.last.body) as Map).keys, ['recommendation'], reason: 'nothing shown, nothing checked');
    });

    test('a place that showed nowhere is an explicit null — the key is there, so the server checks it', () async {
      handler = (_) async => json({'error': 'destination_changed', 'message': words, 'destination': shown.toJson()}, 409);
      await expectLater(api().startJob(row, scope: 'album', destination: const ShownPlace(null)),
          throwsA(isA<DestinationChangedException>().having((e) => e.destination?.base, 'destination', 'From peers')));
      final body = jsonDecode(seen.single.body) as Map;
      expect(body, {'recommendation': jsonDecode(jsonEncode(row)), 'scope': 'album', 'destination': null});
      expect(body.containsKey('destination'), isTrue);
    });

    test("409 destination_changed: nothing started, and where files land now — null is nowhere, an answer that names none (or none this client reads) names none", () async {
      handler = (_) async => json(moved({'vpath': 'music', 'base': 'Peers', 'layout': '{{ARTIST}}/{{ALBUM}}', 'source': 'user'}), 409);
      await expectLater(
          api().startJob(row, destination: shown),
          throwsA(isA<DestinationChangedException>()
              .having((e) => e.status, 'status', 409)
              .having((e) => e.message, 'message', words)
              .having((e) => e.fromServer, 'fromServer', true)
              .having((e) => e.named, 'named', true)
              .having((e) => [e.destination?.vpath, e.destination?.base, e.destination?.layout], 'destination', ['music', 'Peers', '{{ARTIST}}/{{ALBUM}}'])));
      expect(seen, hasLength(1), reason: 'a moved place is not asked again');

      handler = (_) async => json(moved(null), 409);
      await expectLater(api().startJob(row, destination: shown),
          throwsA(isA<DestinationChangedException>().having((e) => e.named, 'named', true).having((e) => e.destination, 'destination', isNull)));

      handler = (_) async => json({'error': 'destination_changed'}, 409);
      await expectLater(api().startJob(row, destination: shown),
          throwsA(isA<DestinationChangedException>().having((e) => e.named, 'named', false).having((e) => e.message, 'message', 'destination_changed')));
      handler = (_) async => json(moved({'vpath': 7}), 409);
      await expectLater(api().startJob(row, destination: shown),
          throwsA(isA<DestinationChangedException>().having((e) => e.named, 'named', false)));
    });

    test("another account's live job is the other 409: its own words, no moved place", () async {
      handler = (_) async => json({'error': 'someone else on this server is already getting this — try again in a moment'}, 409);
      await expectLater(
          api().startJob(row, destination: shown),
          throwsA(isA<DiscoveryPluginsException>()
              .having((e) => e is DestinationChangedException, 'a moved place', isFalse)
              .having((e) => e.message, 'message', 'someone else on this server is already getting this — try again in a moment')));
    });

    test('a server from before the key (400 "destination" is not allowed) is asked once more without it', () async {
      handler = (req) async => (jsonDecode(req.body) as Map).containsKey('destination')
          ? json({'error': '"destination" is not allowed'}, 400)
          : json({'job': jobWire(), 'created': true}, 202);
      final r = await api().startJob(row, scope: 'album', destination: shown);
      expect([r.created, r.job.id], [true, 7]);
      expect(seen, hasLength(2));
      expect(jsonDecode(seen.last.body), {'recommendation': jsonDecode(jsonEncode(row)), 'scope': 'album'});
      // Nowhere is dropped the same way.
      seen.clear();
      await api().startJob(row, destination: const ShownPlace(null));
      expect([for (final s in seen) (jsonDecode(s.body) as Map).containsKey('destination')], [true, false]);

      // Once only: the same refusal again is the answer.
      seen.clear();
      handler = (_) async => json({'error': '"destination" is not allowed'}, 400);
      await expectLater(api().startJob(row, destination: shown),
          throwsA(isA<DiscoveryPluginsException>().having((e) => e.status, 'status', 400)));
      expect(seen, hasLength(2));
      // Any other 400 is the server's no, as it stands.
      seen.clear();
      handler = (_) async => json({'error': "a album job needs the recommendation's album"}, 400);
      await expectLater(api().startJob(row, scope: 'album', destination: shown),
          throwsA(isA<DiscoveryPluginsException>().having((e) => e.message, 'message', "a album job needs the recommendation's album")));
      expect(seen, hasLength(1));
    });
  });

  group('the job list, one job, cancel, clear', () {
    test('GET plugin-jobs, with a state and a limit when asked', () async {
      handler = (_) async => json({
            'jobs': [jobWire(id: 9, state: 'running'), jobWire(id: 8, state: 'done'), 'junk'],
            'runner': {'running': 1, 'active': true}
          });
      final l = await api().jobs();
      expect([seen.single.method, seen.single.url.path, seen.single.url.query], ['GET', '/api/v1/discovery/plugin-jobs', '']);
      expect([for (final j in l.jobs) j.id], [9, 8]);
      expect([l.running, l.active], [1, true]);
      await api().jobs(state: JobState.failed, limit: 900);
      expect(seen.last.url.queryParameters, {'state': 'failed', 'limit': '500'});
      handler = (_) async => json({'job': jobWire(id: 9)});
      expect((await api().job(9)).id, 9);
      expect(seen.last.url.path, '/api/v1/discovery/plugin-jobs/9');
    });

    test('cancel: queued is cancelled, running is requested, 409 is already finished', () async {
      handler = (_) async => json({'job': jobWire(state: 'cancelled'), 'outcome': 'cancelled'});
      final a = await api().cancel(7);
      expect([seen.single.method, seen.single.url.path], ['POST', '/api/v1/discovery/plugin-jobs/7/cancel']);
      expect([a.outcome, a.job!.state], [CancelOutcome.cancelled, JobState.cancelled]);
      handler = (_) async => json({'job': {...jobWire(state: 'running'), 'cancelRequested': true}, 'outcome': 'requested'});
      final b = await api().cancel(7);
      expect([b.outcome, b.job!.cancelRequested], [CancelOutcome.requested, true]);
      handler = (_) async => json({'error': 'job 7 is already done'}, 409);
      final c = await api().cancel(7);
      expect([c.outcome, c.job, c.message], [CancelOutcome.alreadyFinished, null, 'job 7 is already done']);
      handler = (_) async => json({'error': 'job not found'}, 404);
      await expectLater(api().cancel(7), throwsA(isA<DiscoveryPluginsException>().having((e) => e.message, 'message', 'job not found')));
    });

    test('clear finished', () async {
      handler = (_) async => json({'removed': 3});
      expect(await api().clearFinished(), 3);
      expect([seen.single.method, seen.single.url.path], ['POST', '/api/v1/discovery/plugin-jobs/clear']);
    });
  });

  group('the batch lookup', () {
    Map<String, dynamic> answerFor(List recs) => {
          'results': [
            for (final r in recs)
              {
                'key': 'text:${r['title']}',
                'keys': {'song': 'text:${r['title']}'},
                'jobs': []
              }
          ]
        };

    test('rows unchanged, in chunks of 100, answers aligned', () async {
      handler = (req) async => json(answerFor((jsonDecode(req.body) as Map)['recommendations'] as List));
      final recs = List.generate(230, (i) => {...row, 'title': 't$i'});
      final out = await api().lookupBatch(recs);
      expect([for (final r in seen) (jsonDecode(r.body)['recommendations'] as List).length], [100, 100, 30]);
      expect(seen.every((r) => r.url.path == '/api/v1/discovery/plugin-jobs/lookup/batch'), isTrue);
      expect((jsonDecode(seen.first.body)['recommendations'] as List).first, jsonDecode(jsonEncode(recs.first)));
      expect(out, hasLength(230));
      expect([out[0]!.key, out[150]!.key, out[229]!.key], ['text:t0', 'text:t150', 'text:t229']);
      expect(await api().lookupBatch([]), isEmpty);
    });

    test("a chunk that fails leaves its rows null; when every chunk fails, the server's words are thrown", () async {
      var call = 0;
      handler = (req) async {
        call += 1;
        if (call == 2) return json({'error': 'recommendations[3].year must be ≥ 1000'}, 400);
        return json(answerFor((jsonDecode(req.body) as Map)['recommendations'] as List));
      };
      final out = await api().lookupBatch(List.generate(150, (i) => {...row, 'title': 't$i'}));
      expect([out[99]?.key, out[100], out[149]], ['text:t99', null, null]);
      handler = (_) async => json({'error': 'recommendations[0].isrc fails the pattern'}, 400);
      await expectLater(api().lookupBatch([row]),
          throwsA(isA<DiscoveryPluginsException>().having((e) => e.message, 'message', 'recommendations[0].isrc fails the pattern')));
    });
  });

  test('Open elsewhere: the links resolve, the row as received', () async {
    handler = (_) async => json({
          'plugin': 'links',
          'capabilities': ['links'],
          'key': 'text:x',
          'recommendation': row,
          'result': {
            'links': [
              {'id': 'deezer-search', 'label': 'Search Deezer', 'url': 'https://www.deezer.com/search/Boukmanflow%20Late%20Train%20Verse', 'kind': 'search'}
            ]
          }
        });
    final links = await api().links(row);
    expect([seen.single.method, seen.single.url.path], ['POST', '/api/v1/discovery/plugins/links/resolve']);
    expect(jsonDecode(seen.single.body), {'recommendation': jsonDecode(jsonEncode(row))});
    expect(links.single.label, 'Search Deezer');
    handler = (_) async => json({'error': 'plug-in links is rate-limited right now — try again shortly'}, 429);
    await expectLater(api().links(row),
        throwsA(isA<DiscoveryPluginsException>().having((e) => e.message, 'message', 'plug-in links is rate-limited right now — try again shortly')));
  });

  test("by default the calls ride ApiManager's pooled client, as the taste call does", () async {
    final sent = <http.Request>[];
    await http.runWithClient(() async {
      ApiManager().resetDirectClient();
      try {
        await DiscoveryPluginsApi(home).plugins();
      } finally {
        ApiManager().resetDirectClient();
      }
    }, () => MockClient((req) async {
          sent.add(req);
          return json({'plugins': [], 'jobs': {'allowed': false}});
        }));
    expect(sent.single.url.path, '/api/v1/discovery/plugins');
  });
}
