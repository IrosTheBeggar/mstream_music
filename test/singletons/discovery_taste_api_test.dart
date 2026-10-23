// ApiManager's Discover-page calls against a MockClient: method, path and
// body on the wire, and the DiscoveryFetchResult classification the page's
// controller latches on (403 → disabled, other failures → error).
//
// ApiManager keeps one pooled http.Client; resetDirectClient() inside
// http.runWithClient makes that pool the mock for the duration.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mstream_music/objects/discovery.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/api.dart';

final _server = Server('http://music.local:3000', null, null, 'JWT', 'home');

/// Runs [body] with ApiManager's pooled client answering through [handler],
/// recording every request it saw.
Future<T> _withMock<T>(List<http.Request> seen,
    Future<http.Response> Function(http.Request) handler,
    Future<T> Function() body) async {
  try {
    return await http.runWithClient(() async {
      ApiManager().resetDirectClient();
      return body();
    }, () => MockClient((req) async {
          seen.add(req);
          return handler(req);
        }));
  } finally {
    ApiManager().resetDirectClient();
  }
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('fetchDiscoveryTaste', () {
    test('POSTs the request body and parses the answer', () async {
      final seen = <http.Request>[];
      final res = await _withMock(
          seen,
          (_) async => _json({
                'window': 30,
                'seedSource': 'history',
                'seeds': [
                  {'hash': 'h', 'filepath': 'music/a.mp3'}
                ],
                'library': {'tracks': [], 'albums': []},
              }),
          () => ApiManager().fetchDiscoveryTaste(
              _server,
              const TasteRequest(
                window: 90,
                pin: ['/music/now.mp3'],
                exclude: ['h-dropped'],
                sources: {TasteSource.library, TasteSource.network},
              )));
      final req = seen.single;
      expect(req.method, 'POST');
      expect(req.url.path, '/api/v1/discovery/taste');
      expect(req.headers['x-access-token'], 'JWT');
      // The whole body: no `remember`, `filter` or `staleDays` (the route
      // answers 400 to those now).
      expect(jsonDecode(req.body), {
        'window': 90,
        'pin': ['music/now.mp3'],
        'exclude': ['h-dropped'],
        'sources': ['library', 'network'],
      });
      expect(res.disabled, isFalse);
      expect(res.data!.seeds.single.hash, 'h');
      expect(res.data!.library, isNotNull);
    });

    test('403 is "disabled", so the page latches', () async {
      final res = await _withMock(
          [],
          (_) async => _json({'error': 'Discovery is disabled'}, 403),
          () => ApiManager()
              .fetchDiscoveryTaste(_server, const TasteRequest()));
      expect(res.disabled, isTrue);
      expect(res.data, isNull);
    });

    test('any other failure is a plain error', () async {
      for (final r in [
        _json({'error': 'boom'}, 500),
        _json({'error': 'bad'}, 400),
        _json(['not', 'a', 'map']),
        http.Response('<html>', 200),
      ]) {
        final res = await _withMock([], (_) async => r,
            () => ApiManager().fetchDiscoveryTaste(_server, const TasteRequest()));
        expect(res.disabled, isFalse);
        expect(res.data, isNull);
      }
      final thrown = await _withMock([],
          (_) async => throw http.ClientException('down'),
          () => ApiManager().fetchDiscoveryTaste(_server, const TasteRequest()));
      expect(thrown.disabled, isFalse);
      expect(thrown.data, isNull);
    });
  });
}
