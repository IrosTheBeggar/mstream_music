// The section list a federated server gets. Playlists and Rated are the two
// nav entries whose routes are off the federation allowlist (every
// /api/v1/playlist/* route, and db/rated), so they can only ever 403 on a
// peer — everything else on this screen is allowlisted, and Local Files is
// this device's own downloads either way.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/server_list.dart';

/// The `data` slug of every execAction row currently on the nav screen.
List<String?> _sections() => BrowserManager()
    .browserList
    .where((i) => i.type == 'execAction')
    .map((i) => i.data)
    .toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final manager = ServerManager();

  setUp(() {
    manager.serverList.clear();
    manager.currentServer = null;
  });

  tearDown(() {
    manager.serverList.clear();
    manager.currentServer = null;
  });

  test('a plain server gets every section', () {
    final s = Server('https://home.example.com', null, null, 'JWT', 'home');
    manager.serverList.add(s);
    manager.currentServer = s;

    BrowserManager().goToNavScreen();

    expect(_sections(), [
      'fileExplorer',
      'playlists',
      'albums',
      'artists',
      'rated',
      'recent',
      'localFiles',
    ]);
    expect(BrowserManager().browserList.any((i) => i.type == 'note'), isFalse);
  });

  test('a federated server loses Playlists and Rated', () {
    final parent = Server('https://home.example.com', null, null, 'JWT', 'home');
    final peer = Server('federated://home/3', null, null, null, 'peer-basement')
      ..federationParent = 'home'
      ..federationPeerId = 3
      ..federationPeerName = 'Basement'
      ..parentServer = parent;
    manager.serverList.addAll([parent, peer]);
    manager.currentServer = peer;

    BrowserManager().goToNavScreen();

    expect(_sections(), [
      'fileExplorer',
      'albums',
      'artists',
      'recent',
      'localFiles',
    ]);
  });

  test('a federated server explains itself with an inert note row', () {
    final parent = Server('https://home.example.com', null, null, 'JWT', 'home');
    final peer = Server('federated://home/3', null, null, null, 'peer-basement')
      ..federationParent = 'home'
      ..federationPeerId = 3
      ..parentServer = parent;
    manager.serverList.addAll([parent, peer]);
    manager.currentServer = peer;

    BrowserManager().goToNavScreen();

    final notes =
        BrowserManager().browserList.where((i) => i.type == 'note').toList();
    expect(notes, hasLength(1));
    // First row, so the explanation precedes what it explains.
    expect(BrowserManager().browserList.first.type, 'note');
    // No `data` and no handler for the type: browser.dart's handleTap falls
    // through every branch, so tapping it does nothing.
    expect(notes.single.data, isNull);
    expect(notes.single.subtext, isNotNull);
  });

  test('switching back to a plain server restores the full list', () {
    final parent = Server('https://home.example.com', null, null, 'JWT', 'home');
    final peer = Server('federated://home/3', null, null, null, 'peer-basement')
      ..federationParent = 'home'
      ..federationPeerId = 3
      ..parentServer = parent;
    manager.serverList.addAll([parent, peer]);

    manager.currentServer = peer;
    BrowserManager().goToNavScreen();
    expect(_sections(), isNot(contains('playlists')));

    manager.currentServer = parent;
    BrowserManager().goToNavScreen();
    expect(_sections(), contains('playlists'));
    expect(_sections(), contains('rated'));
    expect(BrowserManager().browserList.any((i) => i.type == 'note'), isFalse);
  });
}
