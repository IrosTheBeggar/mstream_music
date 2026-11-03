// BrowserManager's two per-frame markers for Instant mix: the artist an
// artist's-albums frame lists (the toolbar's ✦ there), and the album detail
// a frame was pushed over (Instant mix closes it on the way in, Back opens
// it again). Both stay 1:1 with the stack through every push, pop and
// reset, like the other caches — a missed path would hand a frame the
// marker of the one under it.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/server_list.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final server = Server('http://music.example', null, null, 'JWT', 'home');
  final browser = BrowserManager();

  // The browser resolves on-device download badges for file rows through
  // path_provider; a VM test has no platform side, so answer it.
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => '/nonexistent-return-album-test-dir');
  });

  setUp(() {
    ServerManager().serverList
      ..clear()
      ..add(server);
    ServerManager().currentServer = server;
    browser.closeAlbumDetail();
    browser.goToNavScreen();
  });
  tearDown(() {
    browser.closeAlbumDetail();
    ServerManager().currentServer = null;
    ServerManager().serverList.clear();
  });

  DisplayItem album(String name) =>
      DisplayItem(server, name, 'album', name, null, null);
  List<DisplayItem> albums() => [album('Dive'), album('Immunity')];
  List<DisplayItem> songs() => [
        DisplayItem(server, '/a.mp3', 'file', '/a.mp3', null, null),
      ];

  void expectOneToOne() {
    final n = browser.browserCache.length;
    expect(browser.artistCache, hasLength(n));
    expect(browser.returnAlbumCache, hasLength(n));
    expect(browser.moodFrameCache, hasLength(n));
  }

  test('both markers stay 1:1 with the stack through push, pop and every '
      'reset', () {
    expectOneToOne();
    expect(browser.currentArtist, isNull, reason: 'the home lists no artist');
    browser.addListToStack(albums());
    browser.addListToStack(albums(),
        artist: (server: server, name: 'Tycho'));
    browser.addListToStack(songs(), returnAlbum: album('Dive'));
    expectOneToOne();
    browser.popBrowser();
    expectOneToOne();
    browser.clear();
    expectOneToOne();
    expect(browser.browserCache, hasLength(1));
    expect(browser.currentArtist, isNull);
    browser.addListToStack(albums(), artist: (server: server, name: 'X'));
    browser.goToNavScreen();
    expectOneToOne();
    expect(browser.currentArtist, isNull);
    browser.addListToStack(songs(), returnAlbum: album('Dive'));
    browser.noServerScreen();
    expect(browser.artistCache, isEmpty);
    expect(browser.returnAlbumCache, isEmpty);
    browser.goToNavScreen();
    expectOneToOne();
  });

  test("the artist marker names an artist's albums, and comes back with "
      'its frame after an album', () {
    browser.addListToStack(albums(),
        artist: (server: server, name: 'Tycho'));
    expect(browser.currentArtist?.name, 'Tycho');
    expect(browser.currentArtist?.server, same(server));
    // One of its albums, as a frame of songs (Back returns to the artist).
    browser.addListToStack(songs());
    expect(browser.currentArtist, isNull);
    browser.popBrowser();
    expect(browser.currentArtist?.name, 'Tycho');
    browser.popBrowser();
    expect(browser.currentArtist, isNull);
  });

  test('Back from a frame pushed over an album detail opens that album '
      'again, over the list it came from', () async {
    final list = albums();
    browser.addListToStack(list);
    final dive = list.first;
    browser.openAlbumDetail(dive);
    // What Instant mix does: close the detail, push its frame over the
    // list, remember the album.
    browser.closeAlbumDetail();
    browser.addListToStack(songs(), returnAlbum: dive);
    expect(browser.albumDetail, isNull);

    browser.popBrowser();
    expect(browser.albumDetail, same(dive));
    expect(browser.browserCache.last, same(list));
    expect(browser.albumDetailSongs, isNull,
        reason: 'the detail loads its songs again');

    // The detail's own Back, then the list's: nothing more reopens.
    browser.closeAlbumDetail();
    browser.popBrowser();
    expect(browser.albumDetail, isNull);
    expect(browser.browserCache, hasLength(1));
  });

  test('a frame pushed without one reopens nothing', () {
    browser.addListToStack(albums());
    browser.addListToStack(songs());
    browser.popBrowser();
    expect(browser.albumDetail, isNull);
  });

  test('a reveal request reaches every listener', () async {
    var heard = 0;
    final sub = browser.revealRequests.listen((_) => heard++);
    addTearDown(sub.cancel);
    browser.requestReveal();
    await pumpEventQueue();
    expect(heard, 1);
  });
}
