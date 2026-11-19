// ApiManager's embeddings calls against a MockClient: what goes on the wire,
// and what the Auto DJ learns about each seed path from the answer. A seed
// the server can't use (gone, not analysed yet) must read differently from
// a server that did not answer, which a timeout or a dropped connection
// says nothing about: only the first may cost a row its place in the
// lane's requests. fetchEmbeddings keeps its old contract on top.
//
// ApiManager keeps one pooled http.Client; resetDirectClient() inside
// http.runWithClient makes that pool the mock for the duration.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/api.dart';
import 'package:mstream_music/util/auto_dj_wire.dart';
import 'package:mstream_music/util/seed_vector.dart';

final _server = Server('http://music.local:3000', null, null, 'JWT', 'home');

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

  final wire = encodeWireVector(Float32List.fromList([0, 1, 0, 0]));
  Map<String, Object?> answer(List<String> asked, {Set<String> pending = const {}}) => {
        'model': {'id': 'effnet', 'version': '1'},
        'dim': 4,
        'tracks': [
          for (final p in asked)
            pending.contains(p)
                ? {'filePath': p, 'notAnalyzed': true, 'embedding': null}
                : {'filePath': p, 'notAnalyzed': false, 'embedding': wire},
        ],
      };

  group('readEmbeddings', () {
    test('asks for at most eight paths and reads each one', () async {
      final seen = <http.Request>[];
      final paths = [for (var i = 0; i < 10; i++) 'demo/p$i.mp3'];
      final r = await _withMock(seen, (req) async {
        final asked =
            (jsonDecode(req.body)['filePaths'] as List).cast<String>();
        return _json(answer(asked, pending: {'demo/p1.mp3'}));
      }, () => ApiManager().readEmbeddings(_server, paths));
      expect(seen.single.url.path, '/api/v1/discovery/local/embeddings');
      expect(jsonDecode(seen.single.body)['filePaths'], paths.take(8));
      expect(r.verdicts.length, 8);
      expect(r.verdicts[0], SeedVerdict.vector);
      expect(r.verdicts[1], SeedVerdict.notAnalyzed);
      expect(r.refuses(1), isTrue);
      expect(r.found!.vectors.length, 7);
    });

    test('the route\'s 404 for a lone path says it is gone', () async {
      final r = await _withMock(
          [],
          (_) async => _json({'error': 'Track not found'}, 404),
          () => ApiManager().readEmbeddings(_server, ['demo/gone.mp3']));
      expect(r.verdicts, [SeedVerdict.gone]);
    });

    test('for a batch it says only that one of them is', () async {
      final r = await _withMock(
          [],
          (_) async => _json({'error': 'Track not found'}, 404),
          () => ApiManager().readEmbeddings(_server, ['demo/a.mp3', 'demo/b.mp3']));
      expect(r.someGone, isTrue);
      expect([r.refuses(0), r.refuses(1)], [false, false]);
    });

    test('a dropped connection, or discovery off, says nothing of the songs',
        () async {
      final dropped = await _withMock(
          [],
          (_) async => throw http.ClientException('connection reset'),
          () => ApiManager().readEmbeddings(_server, ['demo/a.mp3', 'demo/b.mp3']));
      expect(dropped.verdicts, [SeedVerdict.unknown, SeedVerdict.unknown]);
      expect(dropped.someGone, isFalse);
      final off = await _withMock(
          [],
          (_) async => _json({'error': 'Discovery is disabled'}, 403),
          () => ApiManager().readEmbeddings(_server, ['demo/a.mp3']));
      expect(off.verdicts, [SeedVerdict.unknown]);
      expect(off.refuses(0), isFalse);
    });

    test('no paths: nothing asked', () async {
      final seen = <http.Request>[];
      final r = await _withMock(seen, (_) async => _json({}),
          () => ApiManager().readEmbeddings(_server, const []));
      expect(seen, isEmpty);
      expect(r.verdicts, isEmpty);
      expect(r.found, isNull);
    });
  });

  group('fetchEmbeddings', () {
    test('the vectors that came back, in their model', () async {
      final got = await _withMock(
          [],
          (req) async => _json(answer(
              (jsonDecode(req.body)['filePaths'] as List).cast<String>(),
              pending: {'demo/b.mp3'})),
          () => ApiManager().fetchEmbeddings(_server, ['demo/a.mp3', 'demo/b.mp3']));
      expect(got!.modelId, 'effnet');
      expect(got.dim, 4);
      expect(got.vectors.length, 1);
    });

    test('null when none did, or nothing answered', () async {
      expect(
          await _withMock(
              [],
              (req) async => _json(answer(['demo/a.mp3'], pending: {'demo/a.mp3'})),
              () => ApiManager().fetchEmbeddings(_server, ['demo/a.mp3'])),
          isNull);
      expect(
          await _withMock([], (_) async => http.Response('', 500),
              () => ApiManager().fetchEmbeddings(_server, ['demo/a.mp3'])),
          isNull);
      expect(await ApiManager().fetchEmbeddings(_server, const []), isNull);
    });
  });
}
