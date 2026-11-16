// What browsing a connected server keeps for Keep a copy: the album
// listings' credits (known / disagree / unknown on an older server), their
// counts and the singles bucket; the artist page's own answer and its name
// on the bar (a label per frame, restored on Back); a search Album hit's
// credit and year as hints only; the open folder's context; the headless
// reads (a folder's count, the own library's folders); and a connected
// server that does not answer a browse call, said once.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/api.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/server_list.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Server home;
  late Server peer;
  final told = <Server>[];

  setUp(() {
    home = Server('http://music.local:3000', null, null, 'JWT', 'home');
    peer = Server('federated://home/1', null, null, null, 'peer-1')
      ..federationParent = 'home'
      ..federationPeerId = 1
      ..federationPeerName = 'Stage Peer B'
      ..parentServer = home;
    ServerManager().serverList
      ..clear()
      ..addAll([home, peer]);
    ServerManager().currentServer = peer;
    BrowserManager().goToNavScreen();
    told.clear();
    ApiManager.onPeerNotAnswering = told.add;
  });
  tearDown(() {
    ApiManager.onPeerNotAnswering = null;
    ServerManager().serverList.clear();
    ServerManager().currentServer = null;
  });

  http.Response json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

  Future<void> via(Future<void> Function() call, Object body, {int status = 200}) =>
      http.runWithClient(call, () => MockClient((_) async => json(body, status)));

  final albumsAnswer = {
    'albums': [
      {'name': 'Borrowed Tapes', 'year': 2019, 'album_art_file': 'a.jpg', 'album_artist': 'Boukmanflow', 'artists': ['Boukmanflow'], 'compilation': false, 'year_min': 2019, 'year_max': 2019, 'track_count': 3, 'duration': 29.4},
      {'name': 'Split Series', 'year': 2022, 'album_artist': null, 'artists': ['ALM', 'Night Owl Radio'], 'compilation': false, 'track_count': 2, 'duration': 21},
      {'name': 'Night Market Sampler', 'year': 2024, 'album_artist': 'Various Artists', 'artists': ['Color Out', 'Boukmanflow', 'ALM'], 'compilation': true, 'track_count': 3},
    ],
  };

  group('the albums listing', () {
    test("keeps each album's credit, compilation, artists, counts and years; credits that disagree read as their artists on a connected server", () async {
      await via(() => ApiManager().getAlbums(useThisServer: peer), albumsAnswer);
      final list = BrowserManager().browserList;
      final tapes = list[0];
      expect([tapes.creditState, tapes.albumArtist, tapes.compilation, tapes.artists, tapes.trackCount, tapes.duration, tapes.yearMin, tapes.yearMax, tapes.subtext],
          [AlbumCredit.known, 'Boukmanflow', false, ['Boukmanflow'], 3, const Duration(milliseconds: 29400), 2019, 2019, 'Boukmanflow · 2019']);
      final split = list[1];
      expect([split.creditState, split.albumArtist, split.subtext], [AlbumCredit.disagree, null, 'ALM, Night Owl Radio']);
      final sampler = list[2];
      expect([sampler.creditState, sampler.albumArtist, sampler.compilation], [AlbumCredit.known, 'Various Artists', true]);
    });

    test("your own server's disagreeing album keeps today's line (the year)", () async {
      ServerManager().currentServer = home;
      await via(() => ApiManager().getAlbums(useThisServer: home), albumsAnswer);
      final split = BrowserManager().browserList[1];
      expect([split.creditState, split.subtext], [AlbumCredit.disagree, '2022']);
    });

    test('an older server names no credit: unknown, and nothing else kept', () async {
      await via(() => ApiManager().getAlbums(useThisServer: peer), {
        'albums': [
          {'name': 'Borrowed Tapes', 'year': 2019, 'album_art_file': 'a.jpg'},
        ],
      });
      final old = BrowserManager().browserList.single;
      expect([old.creditState, old.albumArtist, old.compilation, old.artists, old.trackCount, old.duration, old.subtext],
          [AlbumCredit.unknown, null, null, isEmpty, null, null, '2019']);
    });
  });

  group("an artist's page", () {
    final answer = {
      'albums': [
        {'name': 'Borrowed Tapes', 'year': 2019, 'album_artist': 'Boukmanflow', 'artists': ['Boukmanflow'], 'compilation': false, 'track_count': 3},
        {'name': 'Split Series', 'year': 2022, 'album_artist': null, 'artists': ['ALM', 'Boukmanflow']},
        {'name': null, 'year': null, 'album_artist': 'Boukmanflow', 'artists': ['Boukmanflow']},
      ],
    };

    test("the bar names the artist; the frame keeps the page's own answer, the singles bucket included", () async {
      await via(() => ApiManager().getArtists(useThisServer: peer), {'artists': ['ALM', 'Boukmanflow']});
      expect(BrowserManager().listName, 'Artists');
      await via(() => ApiManager().getArtistAlbums('Boukmanflow', useThisServer: peer), answer);
      final bm = BrowserManager();
      expect(bm.listName, 'Boukmanflow');
      final ctx = bm.currentArtist!;
      expect([ctx.name, identical(ctx.server, peer), ctx.albums.length, ctx.albumCount, ctx.namesCredits],
          ['Boukmanflow', true, 3, 2, true]);
      final singles = bm.browserList[2];
      expect([singles.name, singles.data, singles.creditState], ['SINGLES', null, AlbumCredit.unknown],
          reason: 'the singles bucket is no album: no credit');
      expect(bm.browserList[1].subtext, 'ALM, Boukmanflow');

      // Back restores the previous frame's label, and its artist (none)
      final labels = <String>[];
      final sub = bm.browserLabelStream.listen(labels.add);
      bm.popBrowser();
      await Future<void>.delayed(Duration.zero);
      expect([bm.listName, bm.currentArtist], ['Artists', null]);
      expect(labels.last, 'Artists');
      await sub.cancel();
    });
  });

  test("a search Album hit keeps its credit and year as hints only: the album page opens by name as before", () async {
    ServerManager().currentServer = peer;
    await via(() => ApiManager().searchServer('night'), {
      'artists': [],
      'albums': [
        {'name': 'Night Market Sampler', 'album_art_file': 'n.jpg', 'album_artist': 'Various Artists', 'year': 2024},
        {'name': 'Old Hit', 'album_art_file': null},
      ],
      'title': [],
    });
    final hit = BrowserManager().browserList.first;
    expect([hit.creditHint, hit.yearHint, hit.albumArtist, hit.year, hit.creditState], ['Various Artists', 2024, null, null, AlbumCredit.unknown]);
    final old = BrowserManager().browserList[1];
    expect([old.creditHint, old.yearHint], [null, null]);
  });

  group("the open folder's context", () {
    test("its folders, and the folder Keep a copy can take — none at the top or a library's root", () {
      final top = FolderContext.of('/', server: peer..autoDJPaths = {'live sets': true, 'music': true})!;
      expect([top.path, top.segments, top.ref], ['/', isEmpty, null]);
      final lib = FolderContext.of('/music/')!;
      expect([lib.path, lib.name, lib.library, lib.ref], ['/music', 'music', 'music', null]);
      final f = FolderContext.of('/music/Boukmanflow/', server: peer)!;
      expect([f.path, f.name, f.library, f.ref!.filepath], ['/music/Boukmanflow', 'Boukmanflow', 'music', 'music/Boukmanflow']);
      expect(FolderContext.of(null), isNull);
    });

    test("the top frame's: from the explorer's path, on its rows' server", () async {
      await via(() => ApiManager().getFileList('~', useThisServer: peer), {
        'path': '/music/Boukmanflow/',
        'directories': [
          {'name': 'Borrowed Tapes'},
        ],
        'files': [],
      });
      final f = BrowserManager().currentFolder!;
      expect([f.path, identical(f.server, peer), f.ref!.name], ['/music/Boukmanflow', true, 'Boukmanflow']);
      expect(BrowserManager().browserList.single.data, '/music/Boukmanflow/Borrowed Tapes');
    });

    // "Show in your library" says so when the explorer does not open
    // (the live walk: a folder copy's never-made landing answered 404).
    test('the listing says whether it opened: a folder the server does not have is false, the stack as it was', () async {
      ServerManager().currentServer = home;
      Future<bool> listing(Object body, int status) => http.runWithClient(
          () => ApiManager().getFileList('/copies/Borrowed Tapes', useThisServer: home),
          () => MockClient((_) async => json(body, status)));
      expect(await listing({'path': '/copies/Boukmanflow/', 'directories': [{'name': 'Borrowed Tapes'}], 'files': []}, 200), isTrue);
      final before = List.of(BrowserManager().browserList);
      expect(await listing({'error': 'not found'}, 404), isFalse);
      expect(BrowserManager().browserList, before);
    });
  });

  group("a connected server that does not answer", () {
    test('a 5xx or a failed call is said once per step; a refusal (4xx) and your own server never', () async {
      await via(() => ApiManager().getAlbums(useThisServer: peer), {'error': 'bad gateway'}, status: 502);
      expect(told, [peer]);
      await via(() => ApiManager().getAlbums(useThisServer: peer), {'error': 'bad gateway'}, status: 502);
      expect(told, [peer], reason: 'one step fires several calls, and says so once');
      told.clear();
      await via(() => ApiManager().getRated(useThisServer: peer), {'error': 'not allowed'}, status: 403);
      expect(told, isEmpty);
      await via(() => ApiManager().getAlbums(useThisServer: home), {'error': 'boom'}, status: 500);
      expect(told, isEmpty);
    });

    test('a transport failure', () async {
      final other = Server('federated://home/2', null, null, null, 'peer-2')
        ..federationParent = 'home'
        ..federationPeerId = 2
        ..parentServer = home;
      await http.runWithClient(() => ApiManager().getAlbums(useThisServer: other),
          () => MockClient((_) async => throw http.ClientException('connection refused')));
      expect(told, [other]);
    });
  });

  group('the headless reads', () {
    tearDown(() => ApiManager().resetDirectClient());

    test("a folder's recursive listing through the connected server, and the own library's folders, alphabetical", () async {
      final asked = <http.Request>[];
      http.runWithClient(() => ApiManager().resetDirectClient(), () => MockClient((req) async {
            asked.add(req);
            if (req.url.path.endsWith('/file-explorer/recursive')) {
              return json(['music/Boukmanflow/Borrowed Tapes/01.mp3', 7, '/music/Boukmanflow/Borrowed Tapes/02.mp3']);
            }
            if (jsonDecode(req.body)['directory'] == '/copies/Missing') return json({'error': 'not found'}, 400);
            return json({
              'path': '/copies/',
              'directories': [
                {'name': 'from Sam'},
                {'name': 'Boukmanflow'},
                {'name': ''},
              ],
              'files': [],
            });
          }));
      final paths = await ApiManager().recursiveListing(peer, '/music/Boukmanflow/Borrowed Tapes');
      expect(paths, ['music/Boukmanflow/Borrowed Tapes/01.mp3', '/music/Boukmanflow/Borrowed Tapes/02.mp3']);
      expect(asked.last.url.path, '/api/v1/federation/peers/1/api/api/v1/file-explorer/recursive');
      expect(BrowserManager().isLoading, isFalse, reason: 'no loading bar');
      expect(await ApiManager().ownFolderListing(home, '/copies'), ['Boukmanflow', 'from Sam']);
      expect(asked.last.url.path, '/api/v1/file-explorer');
      await expectLater(ApiManager().ownFolderListing(home, '/copies/Missing'), throwsA(anything));
      expect(told, isEmpty, reason: 'a quiet read says nothing');
    });
  });
}
