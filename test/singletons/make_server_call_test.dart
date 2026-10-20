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
import 'package:mstream_music/singletons/server_list.dart';

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
}
