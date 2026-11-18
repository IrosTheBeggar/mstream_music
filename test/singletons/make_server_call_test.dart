// ApiManager.makeServerCall asks the server the caller names (an item's own
// server), falling back to the current one. Discover lists a connected
// server's albums while the user's own server is current; opening one must
// reach that connected server through the parent's federation proxy, never
// the current server's same-named album (the bug until 2026-10-20).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/api.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/util/decode_json.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Server home;
  late Server peer;

  setUp(() {
    home = Server('http://music.local:3000', null, null, 'JWT', 'home');
    peer = Server('federated://home/7', null, null, null, 'peer-7')
      ..federationParent = 'home'
      ..federationPeerId = 7
      ..parentServer = home;
    ServerManager().serverList
      ..clear()
      ..addAll([home, peer]);
    ServerManager().currentServer = home;
  });
  tearDown(() {
    ServerManager().serverList.clear();
    ServerManager().currentServer = null;
  });

  Future<List<http.Request>> albumSongsVia(Server? useThisServer) async {
    final seen = <http.Request>[];
    await http.runWithClient(
        () => ApiManager().fetchAlbumSongs('Borrowed Tapes',
            useThisServer: useThisServer, albumArtist: 'Boukmanflow'),
        () => MockClient((req) async {
              seen.add(req);
              return http.Response(
                  jsonEncode([
                    {
                      'filepath': 'peerlib/Boukmanflow/Borrowed Tapes/02.mp3',
                      'metadata': {'title': 'Late Train Verse'}
                    }
                  ]),
                  200,
                  headers: {'content-type': 'application/json'});
            }));
    return seen;
  }

  test("a connected server's album asks that server, through the parent's proxy",
      () async {
    final seen = await albumSongsVia(peer);
    expect(seen, hasLength(1));
    expect(seen.single.url.host, 'music.local');
    expect(seen.single.url.path,
        '/api/v1/federation/peers/7/api/api/v1/db/album-songs');
    expect(jsonDecode(seen.single.body)['album'], 'Borrowed Tapes');
  });

  test('no server named: the current one, as before', () async {
    final seen = await albumSongsVia(null);
    expect(seen.single.url.path, '/api/v1/db/album-songs');
  });

  // A whole-library answer: big enough that decodeJsonBody hands it to a
  // background isolate, so the decode spans event-loop turns of its own.
  // Until Dart 3.13 flagged it (unawaited_return_in_try_block) the decode ran
  // after makeServerCall's finally, with the load already ended.
  final library = jsonEncode([
    for (var i = 0; i < 100000; i++) {'name': 'Artist $i', 'album_count': i % 7}
  ]);

  test('a library-sized answer keeps the tap-guard up until it is decoded',
      () async {
    expect(library.length, greaterThan(kIsolateDecodeThreshold));
    var done = false;
    var guardDropped = false;
    await http.runWithClient(() async {
      final call = ApiManager()
          .makeServerCall(home, '/api/v1/db/artists', {}, 'GET')
          .whenComplete(() => done = true);
      while (!done) {
        if (!BrowserManager().isLoading) guardDropped = true;
        await Future<void>.delayed(Duration.zero);
      }
      expect(await call, hasLength(100000));
    }, () => MockClient((req) async => http.Response(library, 200)));
    expect(guardDropped, isFalse,
        reason: 'a second tap must stay blocked while the answer decodes');
  });

  test('Back while a library-sized answer decodes drops it', () async {
    var answered = false;
    await http.runWithClient(() async {
      final call = ApiManager()
          .makeServerCall(home, '/api/v1/db/artists', {}, 'GET');
      // By the first timer turn after the answer, its body is read and the
      // decode is under way on the other isolate.
      while (!answered) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(BrowserManager().cancelLoading(), isTrue,
          reason: 'Back cancels the call: it is still decoding');
      await expectLater(call, throwsA(isA<BrowseCancelled>()));
    }, () => MockClient((req) async {
          answered = true;
          return http.Response(library, 200);
        }));
  });
}
