// The "Surprise me" opener (ApiManager.fetchAutoDjSeed) sends the Auto DJ
// library filters. A key the server's schema refuses — one the version table
// couldn't rule out, like genreSource on a server whose version isn't known
// yet — is learned and the pick sent again without it, as the DJ's own picks
// do, rather than reading as "No songs match your filters".

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mstream_music/objects/genre_source.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/api.dart';
import 'package:mstream_music/singletons/auto_dj_manager.dart';
import 'package:mstream_music/singletons/server_capabilities.dart';

void main() {
  final server = Server('https://home.example.com', 'u', 'p', 'JWT', 'home')
    ..autoDJGenreEnabled = true
    ..autoDJGenres = ['Ambient']
    ..autoDJGenreSource = GenreSource.model;
  late List<Map<String, dynamic>> bodies;

  setUp(() {
    bodies = [];
    ServerCapabilities().forget(server);
    AutoDJManager()
      ..durationFilterEnabled = false
      ..moodFilterEnabled = false;
  });

  Future<({dynamic item, bool noMatch})> fetch(
          http.Response Function(Map<String, dynamic> body) answer) =>
      http.runWithClient(
          () => ApiManager().fetchAutoDjSeed(server),
          () => MockClient((req) async {
                final body = jsonDecode(req.body) as Map<String, dynamic>;
                bodies.add(body);
                return answer(body);
              }));

  http.Response refuse(String key) =>
      http.Response(jsonEncode({'error': '"$key" is not allowed'}), 400);
  final song = http.Response(
      jsonEncode({
        'songs': [
          {'filepath': 'demo/a.mp3', 'metadata': {'title': 'A'}}
        ]
      }),
      200);

  test('a refused key is learned and the pick sent again without it',
      () async {
    final r = await fetch(
        (body) => body.containsKey('genreSource') ? refuse('genreSource') : song);
    expect(r.item, isNotNull);
    expect(r.noMatch, isFalse);
    expect(bodies, hasLength(2));
    expect(bodies.first['genreSource'], 'model');
    expect(bodies.last, isNot(contains('genreSource')));
    expect(bodies.last['genres'], ['Ambient']);
    expect(ServerCapabilities().rejectedFor(server), contains('genreSource'));
  });

  test('an empty pool is still "nothing matched", asked once', () async {
    final r = await fetch((_) => http.Response(
        jsonEncode({'error': 'No songs that match criteria'}), 400));
    expect(r.item, isNull);
    expect(r.noMatch, isTrue);
    expect(bodies, hasLength(1));
  });

  test('a server that refuses whatever it is sent stops after one try per '
      'key', () async {
    final r = await fetch((_) => refuse('genreSource'));
    expect(r.item, isNull);
    expect(bodies, hasLength(1 + bodies.first.length));
  });
}
