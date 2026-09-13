import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:library_mirror/library_mirror.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  final server = MirrorServer('http://h:3000/', token: 'tok');

  test('MirrorServer: trailing slash trimmed, paths encoded, token carried', () {
    expect(server.base, 'http://h:3000');
    expect(server.api('/api/v1/ping').toString(), 'http://h:3000/api/v1/ping');
    expect(server.media('/music/A B/1 #2.mp3').toString(),
        'http://h:3000/media/music/A%20B/1%20%232.mp3?token=tok');
    expect(MirrorServer('http://h').media('/m/x.mp3').toString(),
        'http://h/media/m/x.mp3');
    expect(server.art('aa.jpeg').toString(),
        'http://h:3000/album-art/aa.jpeg?compress=m&token=tok');
    expect(server.headers, {'x-access-token': 'tok'});
  });

  test('login returns a server bound to the token; a refusal throws', () async {
    late http.Request seen;
    final ok = MockClient((r) async {
      seen = r;
      return http.Response(jsonEncode({'token': 'jwt'}), 200);
    });
    final s = await MirrorServer.login('http://h/', 'paul', 'pw', client: ok);
    expect(s.token, 'jwt');
    expect(seen.url.toString(), 'http://h/api/v1/auth/login');
    expect(seen.bodyFields, {'username': 'paul', 'password': 'pw'});
    final bad = MockClient((_) async => http.Response('no', 401));
    expect(MirrorServer.login('http://h', 'x', 'y', client: bad),
        throwsA(isA<HttpException>()));
  });

  test('manifest: cursor and limit in the body, quoted ETag, 304 → null', () async {
    final seen = <http.Request>[];
    final c = MockClient((r) async {
      seen.add(r);
      if (r.headers['If-None-Match'] == '"r1"') return http.Response('', 304);
      return http.Response(
          jsonEncode({
            'revision': 'r1',
            'scanning': false,
            'next': null,
            'entries': [
              {'filepath': 'music/a.mp3', 'id': 1, 'file-size': 3, 'modified': 1,
                'hash': 'h', 'metadata': {'title': 'A'}},
            ],
          }),
          200);
    });
    final m = HttpManifestClient(server, c);
    final page = await m.fetchPage(cursor: 5, limit: 10);
    expect(page!.entries.single.path, '/music/a.mp3');
    expect(jsonDecode(seen.first.body), {'cursor': 5, 'limit': 10});
    expect(seen.first.headers['x-access-token'], 'tok');
    expect(await m.fetchPage(ifNoneMatch: 'r1'), isNull);
    expect(jsonDecode(seen.last.body), {'limit': 2000});
    final down = HttpManifestClient(server, MockClient((_) async => http.Response('x', 500)));
    expect(down.fetchPage(), throwsA(isA<HttpException>()));
  });

  test('downloader streams the media to the file; a refusal leaves none', () async {
    final tmp = Directory.systemTemp.createTempSync('http_dl_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final c = MockClient((r) async => r.url.path.endsWith('/1.mp3')
        ? http.Response.bytes([1, 2, 3], 200)
        : http.Response('nope', 404));
    final d = HttpDownloader(server, c);
    final dest = p.join(tmp.path, 'out.part');
    await d.download('/music/1.mp3', dest);
    expect(File(dest).readAsBytesSync(), [1, 2, 3]);
    expect(d.download('/music/2.mp3', p.join(tmp.path, 'none.part')),
        throwsA(isA<HttpException>()));
  });

  test('lists: albums, artists, genres, playlists (getall + load), rated', () async {
    final c = MockClient((r) async {
      final path = r.url.path;
      Object body;
      if (path.endsWith('/db/albums')) {
        body = {'albums': [{'name': 'Alpha', 'album_artist': 'Ann', 'year': 2001, 'album_art_file': 'aa.jpeg'}]};
      } else if (path.endsWith('/db/artists')) {
        body = {'artists': ['Ann', {'name': 'Bob'}]};
      } else if (path.endsWith('/db/genres')) {
        body = {'genres': [{'name': 'Rock', 'track_count': 2}]};
      } else if (path.endsWith('/playlist/getall')) {
        body = [{'name': 'Mix'}];
      } else if (path.endsWith('/playlist/load')) {
        expect(jsonDecode(r.body), {'playlistname': 'Mix'});
        body = [{'filepath': 'music/a.mp3', 'metadata': {}}];
      } else if (path.endsWith('/db/rated')) {
        body = [{'filepath': 'music/b.mp3', 'metadata': {'rating': 8}}, {'filepath': 'music/c.mp3', 'metadata': {}}];
      } else {
        return http.Response('?', 404);
      }
      return http.Response(jsonEncode(body), 200);
    });
    final l = HttpListsClient(server, c);
    final albums = await l.albums();
    expect(albums.single.name, 'Alpha');
    expect(albums.single.albumArtist, 'Ann');
    expect(albums.single.art, 'aa.jpeg');
    expect(await l.artists(), ['Ann', 'Bob']);
    expect(await l.genres(), {'Rock': 2});
    final pls = await l.playlists();
    expect(pls.single.name, 'Mix');
    expect(pls.single.paths, ['/music/a.mp3']);
    expect(await l.rated(), {'/music/b.mp3': 8});
  });

  test('art is written to the destination', () async {
    final tmp = Directory.systemTemp.createTempSync('http_art_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final c = MockClient((r) async {
      expect(r.url.toString(), 'http://h:3000/album-art/aa.jpeg?compress=m&token=tok');
      return http.Response.bytes([9, 9], 200);
    });
    final dest = p.join(tmp.path, 'aa.jpeg');
    await HttpArtClient(server, c).fetchArt('aa.jpeg', dest);
    expect(File(dest).readAsBytesSync(), [9, 9]);
  });
}
