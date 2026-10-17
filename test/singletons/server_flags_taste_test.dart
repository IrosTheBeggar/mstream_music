// The two Discover-page flags (Discover page plan §2.10, §4.2): where they
// are read from, the integer-generation rule for `discoveryTaste`, their
// persistence, and the pin a federated peer gets whatever it says.
//
// Both boot shapes go through the real folds (ServerManager's
// applyServerInfoForTest / applyPingForTest seams), so a flag dropped from
// either path, or from the peer pin, fails here.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/server.dart';
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
}
