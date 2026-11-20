// The two Discover-page flags (Discover page plan §2.10, §4.2): where they
// are read from, the integer-generation rule for `discoveryTaste`, their
// persistence, and the pin a federated peer gets whatever it says.
//
// Both boot shapes go through the real folds (ServerManager's
// applyServerInfoForTest / applyPingForTest seams), so a flag dropped from
// either path, or from the peer pin, fails here.
//
// The Peer Recommendations flag (mStream docs/peer-recommendations-plan.md
// §2 item 2) is here too: its four-key truth table, both folds, the peer
// pin, and the change detection after a real getServerPaths against a
// MockClient (the harness of server_flags_ytdl_test.dart).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/server_list.dart';

Server _plain() => Server('https://home.example.com', null, null, 'JWT', 'home');

/// A layered `GET /api/` body (mStream #932) with [features] merged in.
Map<String, dynamic> _info(Map<String, dynamic> features) => {
      'server': '6.32.0',
      'features': {'discovery': true, 'discoveryReady': true, ...features},
      'user': {
        'vpaths': ['music']
      },
    };

/// A flat ping body with [extra] merged in.
Map<String, dynamic> _ping(Map<String, dynamic> extra) => {
      'vpaths': ['music'],
      'playlists': [],
      'discovery': true,
      ...extra,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final manager = ServerManager();

  group('discoveryTaste is an integer generation', () {
    test('any int ≥ 1 has the page; nothing else does', () {
      expect(ServerManager.hasTasteGeneration(1), isTrue);
      expect(ServerManager.hasTasteGeneration(2), isTrue,
          reason: 'a later body key ships as 2 and keeps the page');
      expect(ServerManager.hasTasteGeneration(0), isFalse);
      expect(ServerManager.hasTasteGeneration(-1), isFalse);
      expect(ServerManager.hasTasteGeneration(null), isFalse);
      expect(ServerManager.hasTasteGeneration(true), isFalse);
      expect(ServerManager.hasTasteGeneration('1'), isFalse);
      expect(ServerManager.hasTasteGeneration(1.5), isFalse);
    });
  });

  group('GET /api', () {
    test('reads both flags from features', () {
      final s = _plain();
      manager.applyServerInfoForTest(
          s, _info({'discoveryTaste': 1, 'discoveryPlugins': true}));
      expect(s.discoveryAvailable, isTrue);
      expect(s.discoveryTasteAvailable, isTrue);
      expect(s.discoveryPluginsAvailable, isTrue);
    });

    test('an older build (no keys) answers false, not unknown', () {
      final s = _plain();
      manager.applyServerInfoForTest(s, _info({}));
      expect(s.discoveryTasteAvailable, isFalse);
      expect(s.discoveryPluginsAvailable, isFalse);
    });

    test('junk values are off', () {
      final s = _plain();
      manager.applyServerInfoForTest(
          s, _info({'discoveryTaste': true, 'discoveryPlugins': 'yes'}));
      expect(s.discoveryTasteAvailable, isFalse);
      expect(s.discoveryPluginsAvailable, isFalse);
      manager.applyServerInfoForTest(s, _info({'discoveryTaste': 0}));
      expect(s.discoveryTasteAvailable, isFalse);
    });

    test('a refresh without the key turns a flag back off', () {
      // A server rolled back to an older build: the page must go with it.
      final s = _plain();
      manager.applyServerInfoForTest(
          s, _info({'discoveryTaste': 1, 'discoveryPlugins': true}));
      manager.applyServerInfoForTest(s, _info({}));
      expect(s.discoveryTasteAvailable, isFalse);
      expect(s.discoveryPluginsAvailable, isFalse);
    });

    test('a features block that is not a map leaves both off', () {
      final s = _plain();
      manager.applyServerInfoForTest(s, {
        'server': '6.32.0',
        'features': 'nope',
        'user': {'vpaths': []},
      });
      expect(s.discoveryTasteAvailable, isFalse);
      expect(s.discoveryPluginsAvailable, isFalse);
    });
  });

  group('GET /api/v1/ping', () {
    test('reads both flags from the flat payload', () {
      final s = _plain();
      manager.applyPingForTest(
          s, _ping({'discoveryTaste': 1, 'discoveryPlugins': true}));
      expect(s.discoveryAvailable, isTrue);
      expect(s.discoveryTasteAvailable, isTrue);
      expect(s.discoveryPluginsAvailable, isTrue);
    });

    test('the same generation rule applies', () {
      final s = _plain();
      manager.applyPingForTest(s, _ping({'discoveryTaste': 3}));
      expect(s.discoveryTasteAvailable, isTrue);
      manager.applyPingForTest(s, _ping({'discoveryTaste': '1'}));
      expect(s.discoveryTasteAvailable, isFalse);
      manager.applyPingForTest(s, _ping({}));
      expect(s.discoveryTasteAvailable, isFalse);
      expect(s.discoveryPluginsAvailable, isFalse);
    });

    test('a nested features block on ping is not read', () {
      // Ping is flat: its capability keys are listed by hand at the top
      // level (mStream src/api/playlist.js). Reading `features` there would
      // be guessing at a shape the route never had.
      final s = _plain();
      manager.applyPingForTest(s, _ping({
        'features': {'discoveryTaste': 1, 'discoveryPlugins': true}
      }));
      expect(s.discoveryTasteAvailable, isFalse);
      expect(s.discoveryPluginsAvailable, isFalse);
    });
  });

  group('a federated peer', () {
    Server peerOf(Server parent) =>
        Server('federated://home/3', null, null, null, 'peer-basement')
          ..federationParent = 'home'
          ..federationPeerId = 3
          ..parentServer = parent;

    test('is pinned off whatever its own /api says', () {
      // The taste route wants a logged-in account (a federation key 403s),
      // and the plug-in routes are off the federation allowlist.
      final peer = peerOf(_plain());
      manager.applyServerInfoForTest(
          peer, _info({'discoveryTaste': 1, 'discoveryPlugins': true}));
      expect(peer.discoveryTasteAvailable, isFalse);
      expect(peer.discoveryPluginsAvailable, isFalse);
      // The raw engine flag is kept as reported (it drives the DJ's seed).
      expect(peer.discoveryEnabled, isTrue);
    });

    test('the parent keeps its own answer', () {
      final parent = _plain();
      final peer = peerOf(parent);
      manager.applyServerInfoForTest(parent, _info({'discoveryTaste': 1}));
      manager.applyServerInfoForTest(peer, _info({'discoveryTaste': 1}));
      expect(parent.discoveryTasteAvailable, isTrue);
      expect(peer.discoveryTasteAvailable, isFalse);
    });
  });

  group('persistence', () {
    test('both flags round-trip through servers.json', () {
      final s = _plain()
        ..discoveryTasteAvailable = true
        ..discoveryPluginsAvailable = false;
      final back = Server.fromJson(s.toJson());
      expect(back.discoveryTasteAvailable, isTrue);
      expect(back.discoveryPluginsAvailable, isFalse);
    });

    test('absent or junk values load as unknown', () {
      final j = _plain().toJson()
        ..remove('discoveryTasteAvailable')
        ..['discoveryPluginsAvailable'] = 1;
      final back = Server.fromJson(j);
      expect(back.discoveryTasteAvailable, isNull);
      expect(back.discoveryPluginsAvailable, isNull);
    });
  });
  // Keep a copy words a null collection destination by the ACCOUNT's upload
  // right: "your account can't add files" against "no library takes new
  // files". Caller-scoped: `user.noUpload` on /api, `noUpload` on ping.
  group('noUpload (the upload right)', () {
    Map<String, dynamic> withUser(Map<String, dynamic> user) => {
          'server': '6.32.0',
          'features': {'discovery': true, 'discoveryPlugins': true},
          'user': {'vpaths': ['music'], ...user},
        };

    test('/api reads it from user, never from features', () {
      final s = _plain();
      manager.applyServerInfoForTest(s, withUser({'noUpload': true}));
      expect(s.noUpload, isTrue);
      manager.applyServerInfoForTest(s, withUser({'noUpload': false}));
      expect(s.noUpload, isFalse);
      manager.applyServerInfoForTest(s, {
        'server': '6.32.0',
        'features': {'noUpload': true},
        'user': {'vpaths': []},
      });
      expect(s.noUpload, isNull, reason: 'a server too old to say: unknown, not allowed');
      manager.applyServerInfoForTest(s, withUser({'noUpload': 'yes'}));
      expect(s.noUpload, isNull);
    });

    test('ping reads it flat', () {
      final s = _plain();
      manager.applyPingForTest(s, _ping({'noUpload': true}));
      expect(s.noUpload, isTrue);
      manager.applyPingForTest(s, _ping({}));
      expect(s.noUpload, isNull);
    });

    test('a federated peer is pinned unknown: a copy lands on the parent', () {
      final peer = Server('federated://home/3', null, null, null, 'peer-basement')
        ..federationParent = 'home'
        ..federationPeerId = 3
        ..parentServer = _plain();
      manager.applyServerInfoForTest(peer, withUser({'noUpload': false}));
      expect(peer.noUpload, isNull);
    });

    test('round-trips through servers.json; junk loads as unknown', () {
      final back = Server.fromJson((_plain()..noUpload = true).toJson());
      expect(back.noUpload, isTrue);
      final j = _plain().toJson()..['noUpload'] = 'no';
      expect(Server.fromJson(j).noUpload, isNull);
    });
  });

  // Discover by mood (mStream #1092): the flag follows the server's scores,
  // and the route has to be generation 2 — a generation-1 taste body
  // refuses the `moods` key.
  group('moodFilters (Discover by mood)', () {
    test('needs generation 2 and the flag, from /api and from ping', () {
      final s = _plain();
      manager.applyServerInfoForTest(
          s, _info({'discoveryTaste': 2, 'moodFilters': true}));
      expect(s.moodFiltersAvailable, isTrue);
      manager.applyServerInfoForTest(
          s, _info({'discoveryTaste': 1, 'moodFilters': true}));
      expect(s.moodFiltersAvailable, isFalse,
          reason: 'a generation-1 route refuses the key');
      manager.applyServerInfoForTest(
          s, _info({'discoveryTaste': 2, 'moodFilters': false}));
      expect(s.moodFiltersAvailable, isFalse, reason: 'no scores yet');
      manager.applyServerInfoForTest(s, _info({'discoveryTaste': 2}));
      expect(s.moodFiltersAvailable, isFalse);
      manager.applyPingForTest(
          s, _ping({'discoveryTaste': 2, 'moodFilters': true}));
      expect(s.moodFiltersAvailable, isTrue);
      manager.applyPingForTest(
          s, _ping({'discoveryTaste': 2, 'moodFilters': 'yes'}));
      expect(s.moodFiltersAvailable, isFalse);
    });

    test('a federated peer is pinned off; the flag round-trips', () {
      final peer = Server('federated://home/3', null, null, null, 'peer-basement')
        ..federationParent = 'home'
        ..federationPeerId = 3
        ..parentServer = _plain();
      manager.applyServerInfoForTest(
          peer, _info({'discoveryTaste': 2, 'moodFilters': true}));
      expect(peer.moodFiltersAvailable, isFalse);
      final back =
          Server.fromJson((_plain()..moodFiltersAvailable = true).toJson());
      expect(back.moodFiltersAvailable, isTrue);
      final j = _plain().toJson()..['moodFiltersAvailable'] = 1;
      expect(Server.fromJson(j).moodFiltersAvailable, isNull);
    });
  });

  // Peer Recommendations (mStream docs/peer-recommendations-plan.md §2
  // item 2): the page's gate is `discovery && discoveryP2p &&
  // discoveryTaste >= 3 && discoveryP2pPeers >= 1` (mStream
  // src/api/server-info.js), with the phone's integers-only rule.
  group('hasPeerRecs truth table', () {
    bool on(dynamic discovery, dynamic p2p, dynamic taste, dynamic peers) =>
        ServerManager.hasPeerRecs(discovery, p2p, taste, peers);

    test('all four on: the page', () {
      expect(on(true, true, 3, 1), isTrue);
    });

    test('later generations keep it', () {
      expect(on(true, true, 4, 2), isTrue);
      expect(on(true, true, 3, 2), isTrue);
      expect(on(true, true, 4, 1), isTrue);
    });

    test('a taste route below generation 3 is off', () {
      // 2 is a mood-filters-only server, 1 a Discover-only one.
      for (final taste in [2, 1, 0, null]) {
        expect(on(true, true, taste, 1), isFalse, reason: 'taste $taste');
      }
    });

    test('a taste generation that is not an int is off', () {
      for (final taste in <Object>['3', 3.5, true, 3.0]) {
        expect(on(true, true, taste, 1), isFalse, reason: 'taste $taste');
      }
    });

    test('a peers generation absent, 0 or not an int is off', () {
      for (final peers in <Object?>[null, 0, -1, true, '1', 1.0]) {
        expect(on(true, true, 3, peers), isFalse, reason: 'peers $peers');
      }
    });

    test('discovery off, absent or not a bool is off', () {
      for (final discovery in <Object?>[false, null, 'true', 1]) {
        expect(on(discovery, true, 3, 1), isFalse,
            reason: 'discovery $discovery');
      }
    });

    test('the p2p network off, absent or not a bool is off', () {
      for (final p2p in <Object?>[false, null, 'true', 1]) {
        expect(on(true, p2p, 3, 1), isFalse, reason: 'discoveryP2p $p2p');
      }
    });
  });

  /// The three keys beside `discovery` that turn the page on.
  const peerRecsOn = {
    'discoveryP2p': true,
    'discoveryTaste': 3,
    'discoveryP2pPeers': 1,
  };

  group('/api features fold', () {
    test('reads all four flags from features', () {
      final s = _plain();
      manager.applyServerInfoForTest(s, _info(peerRecsOn));
      expect(s.peerRecsAvailable, isTrue);
    });

    test('an older build answers false, not unknown', () {
      // A generation-2 server: Discover and its moods, no peers route.
      final s = _plain();
      manager.applyServerInfoForTest(
          s, _info({'discoveryP2p': true, 'discoveryTaste': 2}));
      expect(s.peerRecsAvailable, isFalse);
      manager.applyServerInfoForTest(s, _info({}));
      expect(s.peerRecsAvailable, isFalse);
    });

    test('each flag alone turns it off', () {
      final s = _plain();
      for (final off in <Map<String, dynamic>>[
        {'discovery': false},
        {'discoveryP2p': false},
        {'discoveryTaste': 2},
        {'discoveryTaste': '3'},
        {'discoveryP2pPeers': 0},
        {'discoveryP2pPeers': true},
      ]) {
        manager.applyServerInfoForTest(s, _info(peerRecsOn));
        expect(s.peerRecsAvailable, isTrue);
        manager.applyServerInfoForTest(s, _info({...peerRecsOn, ...off}));
        expect(s.peerRecsAvailable, isFalse, reason: '$off');
      }
    });

    test('a refresh without the peers key turns it back off', () {
      // A server rolled back to an older build: the page goes with it.
      final s = _plain();
      manager.applyServerInfoForTest(s, _info(peerRecsOn));
      manager.applyServerInfoForTest(
          s, _info({...peerRecsOn}..remove('discoveryP2pPeers')));
      expect(s.peerRecsAvailable, isFalse);
    });

    test('the keys under user, or a features block that is not a map, are off',
        () {
      // Server-wide flags: /api serves them under `features` only.
      final s = _plain();
      manager.applyServerInfoForTest(s, {
        'server': '6.32.0',
        'features': {'discoveryReady': true},
        'user': {
          'vpaths': ['music'],
          'discovery': true,
          ...peerRecsOn,
        },
      });
      expect(s.peerRecsAvailable, isFalse);
      manager.applyServerInfoForTest(s, {
        'server': '6.32.0',
        'features': 'nope',
        'user': {'vpaths': []},
      });
      expect(s.peerRecsAvailable, isFalse);
    });
  });

  group('ping fold', () {
    test('reads all four flags from the flat payload', () {
      final s = _plain();
      manager.applyPingForTest(s, _ping(peerRecsOn));
      expect(s.peerRecsAvailable, isTrue);
    });

    test('the same integers-only rule applies', () {
      final s = _plain();
      manager.applyPingForTest(
          s, _ping({...peerRecsOn, 'discoveryP2pPeers': 2, 'discoveryTaste': 4}));
      expect(s.peerRecsAvailable, isTrue);
      manager.applyPingForTest(s, _ping({...peerRecsOn, 'discoveryTaste': '3'}));
      expect(s.peerRecsAvailable, isFalse);
      manager.applyPingForTest(s, _ping({...peerRecsOn, 'discoveryP2pPeers': 1.0}));
      expect(s.peerRecsAvailable, isFalse);
      manager.applyPingForTest(s, _ping({...peerRecsOn, 'discovery': false}));
      expect(s.peerRecsAvailable, isFalse);
      manager.applyPingForTest(s, _ping({}));
      expect(s.peerRecsAvailable, isFalse,
          reason: 'an older build answers false, not unknown');
    });

    test('a nested features block on ping is not read', () {
      // Ping is flat: its keys are listed by hand at the top level (mStream
      // src/api/playlist.js lists discoveryP2pPeers beside discoveryTaste).
      final s = _plain();
      manager.applyPingForTest(s, _ping({'features': peerRecsOn}));
      expect(s.peerRecsAvailable, isFalse);
    });
  });

  test('pinned false on a federated peer whose own /api says yes', () {
    // The taste route takes a logged-in account and the peers route is the
    // parent's own network: the page is the parent's.
    final parent = _plain();
    final peer = Server('federated://home/3', null, null, null, 'peer-basement')
      ..federationParent = 'home'
      ..federationPeerId = 3
      ..parentServer = parent;
    manager.applyServerInfoForTest(parent, _info(peerRecsOn));
    manager.applyServerInfoForTest(peer, _info(peerRecsOn));
    expect(parent.peerRecsAvailable, isTrue);
    expect(peer.peerRecsAvailable, isFalse);
  });

  // getServerPaths snapshots every flag, folds the answer, then writes
  // servers.json and redraws a showing home when a flag it compares moved.
  // Each change below moves the Peer Recommendations flag ALONE (no other
  // flag reads `discoveryP2pPeers`, and taste 2 → 3 keeps the Discover and
  // mood flags as they were), so only its own lines in the two change lists
  // can catch it.
  group('a change redraws the home', () {
    late Directory scratch;
    late Server s;
    late Map<String, dynamic> answer;

    File serversFile() => File('${scratch.path}/servers.json');

    setUpAll(() {
      scratch = Directory.systemTemp.createTempSync('mstream-peer-recs-flag-');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              (_) async => scratch.path);
    });
    tearDownAll(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'), null);
      try {
        scratch.deleteSync(recursive: true);
      } catch (_) {}
    });

    Future<void> refresh() => http.runWithClient(
        () => manager.getServerPaths(s, throwErr: true),
        () => MockClient((req) async => http.Response(
            jsonEncode(req.url.path == '/api/' ? answer : []), 200,
            headers: {'content-type': 'application/json'})));

    /// The home drawn fresh, with a marker row a rebuild would clear.
    void showHome() {
      BrowserManager().goToNavScreen();
      BrowserManager()
          .browserList
          .add(DisplayItem(null, 'marker', 'note', null, null, null));
    }

    bool homeRedrawn() =>
        !BrowserManager().browserList.any((i) => i.name == 'marker');

    /// The server as servers.json has it. The refresh does not await its
    /// write, so give the chain a moment, and read past a half-written
    /// file.
    Future<Map?> written() async {
      for (var i = 0; i < 100; i++) {
        if (serversFile().existsSync()) {
          try {
            final saved = jsonDecode(serversFile().readAsStringSync());
            if (saved is List && saved.length == 1) return saved.single as Map;
          } on FormatException {
            // mid-write
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      return null;
    }

    /// The next refresh starts from a clean slate: nothing written, the
    /// home freshly drawn.
    Future<void> settle() async {
      // Queued behind any earlier write, so once it lands nothing else is
      // pending.
      await manager.writeServerFile();
      if (serversFile().existsSync()) serversFile().deleteSync();
      showHome();
    }

    setUp(() async {
      s = _plain();
      manager.serverList
        ..clear()
        ..add(s);
      manager.currentServer = s;
      answer = _info({...peerRecsOn});
      await refresh(); // the baseline: every flag known, the page on
      expect(s.peerRecsAvailable, isTrue);
      await settle();
    });
    tearDown(() {
      manager.serverList.clear();
      manager.currentServer = null;
    });

    test('nothing moved: the home stays, nothing is written', () async {
      await refresh();
      expect(homeRedrawn(), isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(serversFile().existsSync(), isFalse);
    });

    test('a later generation is no change: the app keeps the answer',
        () async {
      answer['features']['discoveryTaste'] = 4;
      answer['features']['discoveryP2pPeers'] = 2;
      await refresh();
      expect(s.peerRecsAvailable, isTrue);
      expect(homeRedrawn(), isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(serversFile().existsSync(), isFalse);
    });

    test('the peers route going away redraws the home and is written',
        () async {
      (answer['features'] as Map).remove('discoveryP2pPeers');
      await refresh();
      expect(s.peerRecsAvailable, isFalse);
      expect(homeRedrawn(), isTrue, reason: 'the card goes with the flag');
      expect((await written())?['peerRecsAvailable'], isFalse);
    });

    test('the page coming on redraws the home and is written', () async {
      // Off first: a generation-2 taste route (Discover and its moods
      // keep their flags; only this one moves).
      answer['features']['discoveryTaste'] = 2;
      await refresh();
      expect(s.peerRecsAvailable, isFalse);
      expect(s.discoveryTasteAvailable, isTrue);
      expect(homeRedrawn(), isTrue);
      expect((await written())?['peerRecsAvailable'], isFalse);

      await settle();
      answer['features']['discoveryTaste'] = 3;
      await refresh();
      expect(s.peerRecsAvailable, isTrue);
      expect(homeRedrawn(), isTrue, reason: 'the card comes with the flag');
      expect((await written())?['peerRecsAvailable'], isTrue);
    });

    test('a home that is not showing is left alone; the flag is still written',
        () async {
      BrowserManager().browserList
        ..clear()
        ..add(DisplayItem(s, 'marker', 'directory', '/music/', null, null));
      (answer['features'] as Map).remove('discoveryP2pPeers');
      await refresh();
      expect(homeRedrawn(), isFalse, reason: 'a rebuild resets the browse stack');
      expect((await written())?['peerRecsAvailable'], isFalse);
    });
  });
}
