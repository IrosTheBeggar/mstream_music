// Instant Mix's flag (mStream POST /api/v1/discovery/local/mix): where it is
// read from, the integer-generation rule for `features.instantMix`, its
// persistence, and the gate the entries take (Server.instantMixUsable) —
// the readiness the sonic index reports, and never a connected server's
// items.
//
// Both boot shapes go through the real folds (ServerManager's
// applyServerInfoForTest / applyPingForTest seams), so a flag dropped from
// either path fails here.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/server_list.dart';

Server _plain() => Server('https://home.example.com', null, null, 'JWT', 'home');

/// A layered `GET /api/` body (mStream #932) with [features] merged in.
Map<String, dynamic> _info(Map<String, dynamic> features) => {
      'server': '6.33.0',
      'features': {'discovery': true, 'discoveryReady': true, ...features},
      'user': {
        'vpaths': ['music']
      },
    };

Server _peerOf(Server parent) =>
    Server('federated://home/3', null, null, null, 'peer-basement')
      ..federationParent = 'home'
      ..federationPeerId = 3
      ..parentServer = parent;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final manager = ServerManager();

  group('instantMix is an integer generation', () {
    test('any int ≥ 1 is a generation; nothing else is', () {
      expect(ServerManager.instantMixGenerationOf(1), 1);
      expect(ServerManager.instantMixGenerationOf(2), 2,
          reason: 'a filter added later ships as 2 and keeps the page');
      expect(ServerManager.instantMixGenerationOf(0), isNull);
      expect(ServerManager.instantMixGenerationOf(-1), isNull);
      expect(ServerManager.instantMixGenerationOf(null), isNull);
      expect(ServerManager.instantMixGenerationOf(true), isNull);
      expect(ServerManager.instantMixGenerationOf('1'), isNull);
      expect(ServerManager.instantMixGenerationOf(1.5), isNull);
    });
  });

  group('GET /api', () {
    test('reads the generation from features', () {
      final s = _plain();
      manager.applyServerInfoForTest(s, _info({'instantMix': 1}));
      expect(s.instantMixGeneration, 1);
      expect(s.instantMixUsable, isTrue);
    });

    test('an older build (no key), junk, and a features block that is not '
        'a map: no generation', () {
      final s = _plain();
      manager.applyServerInfoForTest(s, _info({}));
      expect(s.instantMixGeneration, isNull);
      manager.applyServerInfoForTest(s, _info({'instantMix': true}));
      expect(s.instantMixGeneration, isNull);
      manager.applyServerInfoForTest(s, _info({'instantMix': 0}));
      expect(s.instantMixGeneration, isNull);
      manager.applyServerInfoForTest(s, {
        'server': '6.33.0',
        'features': 'nope',
        'user': {'vpaths': []},
      });
      expect(s.instantMixGeneration, isNull);
      expect(s.instantMixUsable, isFalse);
    });

    test('a refresh without the key takes the entries away', () {
      // A server rolled back to an older build: the entries go with it.
      final s = _plain();
      manager.applyServerInfoForTest(s, _info({'instantMix': 1}));
      manager.applyServerInfoForTest(s, _info({}));
      expect(s.instantMixGeneration, isNull);
      expect(s.instantMixUsable, isFalse);
    });
  });

  group('GET /api/v1/ping', () {
    test('sets no generation, whatever the payload says', () {
      // Ping is only read from servers that predate /api/, which predate
      // the route too.
      final s = _plain()..instantMixGeneration = 1;
      manager.applyPingForTest(s, {
        'vpaths': ['music'],
        'playlists': [],
        'discovery': true,
        'instantMix': 1,
      });
      expect(s.instantMixGeneration, isNull);
      expect(s.instantMixUsable, isFalse);
    });
  });

  group('instantMixUsable', () {
    test('needs discovery on, the sonic index ready, and the generation', () {
      final s = _plain();
      manager.applyServerInfoForTest(s, _info({'instantMix': 1}));
      expect(s.instantMixUsable, isTrue);

      manager.applyServerInfoForTest(
          s, _info({'instantMix': 1, 'discoveryReady': false}));
      expect(s.instantMixUsable, isFalse,
          reason: 'still scanning: hidden, never disabled');

      manager.applyServerInfoForTest(
          s, _info({'instantMix': 1, 'discovery': false}));
      expect(s.instantMixUsable, isFalse, reason: 'discovery off');
    });

    test('readiness the server did not report holds the entries back', () {
      // Every build with the route reports discoveryReady, and the gate both
      // clients take is discovery && discoveryReady === true && instantMix
      // ≥ 1: a missing readiness is no reason to guess.
      final s = _plain()
        ..instantMixGeneration = 1
        ..discoveryEnabled = true
        ..discoveryReady = null;
      expect(s.sonicUsable, isTrue,
          reason: "Auto DJ's sonic seed is not held back by it");
      expect(s.instantMixUsable, isFalse);

      // Through the real fold: an /api/ body without the key.
      final t = _plain();
      manager.applyServerInfoForTest(t, {
        'server': '6.33.0',
        'features': {'discovery': true, 'instantMix': 1},
        'user': {
          'vpaths': ['music']
        },
      });
      expect(t.instantMixGeneration, 1);
      expect(t.discoveryReady, isNull);
      expect(t.instantMixUsable, isFalse);
    });

    test('never on a federated server, whatever its own /api says', () {
      final parent = _plain();
      final peer = _peerOf(parent);
      manager.applyServerInfoForTest(parent, _info({'instantMix': 1}));
      manager.applyServerInfoForTest(peer, _info({'instantMix': 1}));
      expect(parent.instantMixUsable, isTrue);
      expect(peer.instantMixGeneration, 1,
          reason: 'kept as reported: the getter is the one place it is off');
      expect(peer.sonicUsable, isTrue);
      expect(peer.instantMixUsable, isFalse);
    });
  });

  group('persistence', () {
    test('round-trips through servers.json', () {
      final back =
          Server.fromJson((_plain()..instantMixGeneration = 2).toJson());
      expect(back.instantMixGeneration, 2);
    });

    test('absent or junk values load as unknown', () {
      final j = _plain().toJson()..remove('instantMixGeneration');
      expect(Server.fromJson(j).instantMixGeneration, isNull);
      final junk = _plain().toJson()..['instantMixGeneration'] = '1';
      expect(Server.fromJson(junk).instantMixGeneration, isNull);
    });
  });
}
