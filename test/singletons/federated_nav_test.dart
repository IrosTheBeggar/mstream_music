// The section list a federated server gets. Playlists and Rated are the two
// nav entries whose routes are off the federation allowlist (every
// /api/v1/playlist/* route, and db/rated), so they can only ever 403 on a
// peer — everything else on this screen is allowlisted, and Local Files is
// this device's own downloads either way.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/server_list.dart';

/// The `data` slug of every execAction row currently on the nav screen.
List<String?> _sections() => BrowserManager()
    .browserList
    .where((i) => i.type == 'execAction')
    .map((i) => i.data)
    .toList();

/// The group headers, in order.
List<String> _headers() => BrowserManager()
    .browserList
    .where((i) => i.type == 'section')
    .map((i) => i.name)
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
      'autoDj',
      'torrents',
    ]);
    expect(BrowserManager().browserList.any((i) => i.type == 'note'), isFalse);
    // Grouped under headers: LIBRARY, LISTEN, SERVER — no NETWORK without a
    // peer, no Sonic path without the route advertised.
    expect(_headers(), ['Library', 'Listen', 'Server']);
  });

  test('a server that advertises the path route gets Sonic path under Listen',
      () {
    final s = Server('https://home.example.com', null, null, 'JWT', 'home')
      ..discoveryPathAvailable = true;
    manager.serverList.add(s);
    manager.currentServer = s;
    BrowserManager().goToNavScreen();
    expect(_sections(), contains('sonicPath'));
    final i =
        BrowserManager().browserList.indexWhere((r) => r.data == 'sonicPath');
    final j =
        BrowserManager().browserList.indexWhere((r) => r.data == 'autoDj');
    expect(i, j + 1, reason: 'right after Auto DJ, in the same group');
  });

  test('a server with peers gets a NETWORK group above SERVER, counting them',
      () {
    final parent = Server('https://home.example.com', null, null, 'JWT', 'home');
    final peer = Server('federated://home/3', null, null, null, 'peer-basement')
      ..federationParent = 'home'
      ..federationPeerId = 3
      ..parentServer = parent;
    final hidden = Server('federated://home/4', null, null, null, 'peer-attic')
      ..federationParent = 'home'
      ..federationPeerId = 4
      ..parentServer = parent
      ..federationHidden = true;
    manager.serverList.addAll([parent, peer, hidden]);
    manager.currentServer = parent;
    BrowserManager().goToNavScreen();
    expect(_headers(), ['Library', 'Listen', 'Network', 'Server']);
    final fed = BrowserManager()
        .browserList
        .singleWhere((r) => r.data == 'federation');
    expect(fed.subtext, 'sharedLibraries:1',
        reason: 'a hidden peer is not counted');
  });

  test('a server whose build has federation gets NETWORK even with no peers',
      () {
    // The card leads to the Federation screen, which has something to say
    // on with no peers yet (share a library, add a peer) and off (turn it
    // on) — so the build having federation at all is the gate, and the
    // shared-library count only appears once there is one.
    final s = Server('https://home.example.com', null, null, 'JWT', 'home')
      ..federationAvailable = true;
    manager.serverList.add(s);
    manager.currentServer = s;
    BrowserManager().goToNavScreen();
    expect(_headers(), ['Library', 'Listen', 'Network', 'Server']);
    final fed = BrowserManager()
        .browserList
        .singleWhere((r) => r.data == 'federation');
    expect(fed.subtext, isNull, reason: 'no count without a peer');
  });

  test('a server that never reported federation gets no NETWORK group', () {
    final s = Server('https://home.example.com', null, null, 'JWT', 'home')
      ..federationAvailable = false;
    manager.serverList.add(s);
    manager.currentServer = s;
    BrowserManager().goToNavScreen();
    expect(_headers(), ['Library', 'Listen', 'Server']);
  });

  test('a server whose build has the discovery network gets the P2P card',
      () {
    // Off: the card still shows (an admin joins from it) and its second
    // line says so; on: the ping flag flips the line.
    final s = Server('https://home.example.com', null, null, 'JWT', 'home')
      ..p2pAvailable = true;
    manager.serverList.add(s);
    manager.currentServer = s;
    BrowserManager().goToNavScreen();
    expect(_headers(), ['Library', 'Listen', 'Network', 'Server']);
    expect(_sections(), isNot(contains('federation')),
        reason: 'no federation without the flag or a peer');
    final p2p = BrowserManager()
        .browserList
        .singleWhere((r) => r.data == 'p2pNetwork');
    expect(p2p.subtext, 'p2p:off');
    s.discoveryP2pAvailable = true;
    BrowserManager().goToNavScreen();
    expect(
        BrowserManager()
            .browserList
            .singleWhere((r) => r.data == 'p2pNetwork')
            .subtext,
        'p2p:on');
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
      'autoDj',
    ]);
    // A peer hosts the DJ (mStream #946) but takes no torrents and has no
    // peers of its own: LISTEN stays, NETWORK and SERVER go.
    expect(_headers(), ['Library', 'Listen']);
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

  test('requests waiting on the operator put a banner above the sections', () {
    final s = Server('https://home.example.com', null, null, 'JWT', 'home')
      ..federationInbox = 2;
    manager.serverList.add(s);
    manager.currentServer = s;

    BrowserManager().goToNavScreen();

    final first = BrowserManager().browserList.first;
    expect(first.type, 'banner');
    expect(first.data, 'federation', reason: 'taps through like the card');
    expect(first.subtext, 'federationInbox:2');
    expect(BrowserManager.isHomeList(BrowserManager().browserList), isTrue);
    // The count alone is not a NETWORK group: that still needs the flag.
    expect(_headers(), ['Library', 'Listen', 'Server']);

    // Nothing waiting: no banner.
    s.federationInbox = 0;
    BrowserManager().goToNavScreen();
    expect(BrowserManager().browserList.any((i) => i.type == 'banner'),
        isFalse);
  });

  group('BrowserManager.isHomeList', () {
    DisplayItem row(String type) =>
        DisplayItem(null, type, type, null, null, null);
    test('a section list is home', () {
      expect(BrowserManager.isHomeList([row('execAction'), row('execAction')]),
          isTrue);
    });
    test("a peer's leading note does not demote its home", () {
      // The toolbar's whole-server search and the card grid key on this; the
      // note used to make a peer's home a plain list without the search.
      expect(BrowserManager.isHomeList([row('section'), row('execAction')]),
          isTrue);
      expect(BrowserManager.isHomeList([row('note'), row('execAction')]),
          isTrue);
    });
    test('anything else is not home', () {
      expect(BrowserManager.isHomeList([row('file'), row('execAction')]),
          isFalse);
      expect(BrowserManager.isHomeList([row('note')]), isFalse);
      expect(BrowserManager.isHomeList(const []), isFalse);
    });
  });
}
