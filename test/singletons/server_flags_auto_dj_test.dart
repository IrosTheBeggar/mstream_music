// The Auto DJ picker's generation (mStream #1108: `features.autoDj` on
// GET /api, flat `autoDj` on ping), which says a server takes the DJ's
// "less like" negatives, and the gate built on it: Server.lessLikeUsable,
// a generation of 1 or more with discovery on and its scan done, the
// server's own rule. Where the generation is read from, what a missing or
// junk value reads as, its persistence, a federated peer keeping its own
// answer (random-songs and the embeddings route are allowlisted), and the
// change detection after a refresh: a server that gains or loses it is
// written to servers.json and announced on capabilityChanges, which the
// Auto DJ screen and the Seeds page redraw on.
//
// The folds go through ServerManager's applyServerInfoForTest /
// applyPingForTest seams; the change detection through a real
// getServerPaths against a MockClient.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/server_list.dart';

Server _plain() => Server('https://home.example.com', null, null, 'JWT', 'home');

Server _peerOf(Server parent) =>
    Server('federated://home/3', null, null, null, 'peer-basement')
      ..federationParent = 'home'
      ..federationPeerId = 3
      ..parentServer = parent;

/// A layered `GET /api/` body (mStream #932): discovery on with its scan
/// done, [features] and [user] merged in.
Map<String, dynamic> _info(Map<String, dynamic> features,
        {Map<String, dynamic> user = const {}}) =>
    {
      'server': '6.33.1',
      'features': {'discovery': true, 'discoveryReady': true, ...features},
      'user': {
        'vpaths': ['music'],
        ...user
      },
    };

/// A flat ping body: discovery on, [extra] merged in.
Map<String, dynamic> _ping(Map<String, dynamic> extra) => {
      'vpaths': ['music'],
      'playlists': [],
      'discovery': true,
      ...extra,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final manager = ServerManager();

  group('GET /api', () {
    test('reads features.autoDj, keeping the number', () {
      final s = _plain();
      manager.applyServerInfoForTest(s, _info({'autoDj': 1}));
      expect(s.autoDjGeneration, 1);
      expect(s.lessLikeUsable, isTrue);
      manager.applyServerInfoForTest(s, _info({'autoDj': 2}));
      expect(s.autoDjGeneration, 2,
          reason: 'a later generation is gated with >=, so the number stays');
      expect(s.lessLikeUsable, isTrue);
    });

    test('a refresh without the key turns it back off', () {
      // A server rolled back to a build before #1108, which refuses the keys.
      final s = _plain();
      manager.applyServerInfoForTest(s, _info({'autoDj': 1}));
      manager.applyServerInfoForTest(s, _info({}));
      expect(s.autoDjGeneration, isNull);
      expect(s.lessLikeUsable, isFalse);
    });

    test('junk values are unknown', () {
      final s = _plain();
      for (final junk in [true, '1', 1.5, null, <String, dynamic>{}]) {
        s.autoDjGeneration = 1;
        manager.applyServerInfoForTest(s, _info({'autoDj': junk}));
        expect(s.autoDjGeneration, isNull, reason: 'autoDj: $junk');
      }
    });

    test('server-wide: read from features, never from user', () {
      final s = _plain();
      manager.applyServerInfoForTest(s, _info({}, user: {'autoDj': 1}));
      expect(s.autoDjGeneration, isNull);
    });

    test('a features block that is not a map leaves it unknown', () {
      final s = _plain()..autoDjGeneration = 1;
      manager.applyServerInfoForTest(s, {
        'server': '6.33.1',
        'features': 'nope',
        'user': {'vpaths': []},
      });
      expect(s.autoDjGeneration, isNull);
    });
  });

  group('GET /api/v1/ping', () {
    test('reads it flat', () {
      final s = _plain();
      manager.applyPingForTest(s, _ping({'autoDj': 1}));
      expect(s.autoDjGeneration, 1);
      manager.applyPingForTest(s, _ping({}));
      expect(s.autoDjGeneration, isNull);
      manager.applyPingForTest(s, _ping({'autoDj': '1'}));
      expect(s.autoDjGeneration, isNull);
    });

    test('a nested features block on ping is not read', () {
      // Ping is flat: its capability keys are listed by hand at the top
      // level (mStream src/api/playlist.js).
      final s = _plain();
      manager.applyPingForTest(s, _ping({
        'features': {'autoDj': 1}
      }));
      expect(s.autoDjGeneration, isNull);
    });

    test('ping carries no readiness, so its server takes no negatives', () {
      final s = _plain();
      manager.applyPingForTest(s, _ping({'autoDj': 1}));
      expect(s.autoDjGeneration, 1);
      expect(s.discoveryReady, isNull);
      expect(s.lessLikeUsable, isFalse);
      expect(s.sonicUsable, isTrue,
          reason: 'the sonic seed is lenient on unreported readiness');
    });
  });

  group('Server.lessLikeUsable', () {
    Server withFlags(int? generation, {bool? enabled = true, bool? ready = true}) =>
        _plain()
          ..autoDjGeneration = generation
          ..discoveryEnabled = enabled
          ..discoveryReady = ready;

    test('a generation of 1 or more, discovery on and its scan done', () {
      expect(withFlags(1).lessLikeUsable, isTrue);
      expect(withFlags(3).lessLikeUsable, isTrue);
    });

    test('no generation, or 0: the server would refuse the keys', () {
      expect(withFlags(null).lessLikeUsable, isFalse);
      expect(withFlags(0).lessLikeUsable, isFalse);
    });

    test('discovery off, or never reported, holds them back', () {
      expect(withFlags(1, enabled: false).lessLikeUsable, isFalse);
      expect(withFlags(1, enabled: null).lessLikeUsable, isFalse);
    });

    test('readiness must be reported: stricter than sonicUsable', () {
      final unreported = withFlags(1, ready: null);
      expect(unreported.lessLikeUsable, isFalse,
          reason: "the server's rule is autoDj >= 1 && discoveryReady: "
              'negatives do nothing before the scan is done');
      expect(unreported.sonicUsable, isTrue);
      expect(withFlags(1, ready: false).lessLikeUsable, isFalse);
    });
  });

  group('a federated peer', () {
    test('keeps its own answer: random-songs is allowlisted', () {
      final peer = _peerOf(_plain());
      manager.applyServerInfoForTest(peer, _info({'autoDj': 1, 'stats': 2}));
      expect(peer.autoDjGeneration, 1);
      expect(peer.lessLikeUsable, isTrue,
          reason: 'a peer hosts or joins the DJ on its own engine flags');
      // The flags around it are still pinned.
      expect(peer.statsVersion, isNull);
      expect(peer.discoveryAvailable, isFalse);
    });

    test('an older peer answers null; its parent keeps its own answer', () {
      final parent = _plain();
      final peer = _peerOf(parent);
      manager.applyServerInfoForTest(parent, _info({'autoDj': 1}));
      manager.applyServerInfoForTest(peer, _info({}));
      expect(parent.autoDjGeneration, 1);
      expect(peer.autoDjGeneration, isNull);
    });
  });

  group('persistence', () {
    test('round-trips through servers.json, as the number', () {
      final back = Server.fromJson((_plain()..autoDjGeneration = 2).toJson());
      expect(back.autoDjGeneration, 2);
    });

    test('absent or junk values load as unknown', () {
      final absent = _plain().toJson()..remove('autoDjGeneration');
      expect(Server.fromJson(absent).autoDjGeneration, isNull);
      for (final junk in ['1', true, 1.5]) {
        final j = _plain().toJson()..['autoDjGeneration'] = junk;
        expect(Server.fromJson(j).autoDjGeneration, isNull, reason: '$junk');
      }
    });

    test('a record from before the field waits for its next /api answer', () {
      final j = (_plain()
            ..discoveryEnabled = true
            ..discoveryReady = true)
          .toJson()
        ..remove('autoDjGeneration');
      final back = Server.fromJson(j);
      expect(back.lessLikeUsable, isFalse);
      manager.applyServerInfoForTest(back, _info({'autoDj': 1}));
      expect(back.lessLikeUsable, isTrue);
    });
  });

  // getServerPaths snapshots every flag, folds the answer, then writes
  // servers.json and announces the server when a flag it compares moved.
  group('a refresh that changes it', () {
    late Directory scratch;
    late Server s;
    late Map<String, dynamic> answer;
    late List<Server> announced;
    StreamSubscription<Server>? sub;

    File serversFile() => File('${scratch.path}/servers.json');

    setUpAll(() {
      scratch = Directory.systemTemp.createTempSync('mstream-auto-dj-flags-');
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

    /// Lets the writes a refresh queued land, then forgets them, so what
    /// the next refresh writes and announces is all that is left to see.
    Future<void> settle() async {
      await manager.writeServerFile();
      serversFile().deleteSync();
      await Future<void>.delayed(Duration.zero);
      announced.clear();
    }

    setUp(() async {
      s = _plain();
      manager.serverList
        ..clear()
        ..add(s);
      announced = [];
      sub = manager.capabilityChanges.listen(announced.add);
      answer = _info({});
      await refresh(); // the baseline: every flag known, no generation
      await settle();
    });
    tearDown(() async {
      await sub?.cancel();
      manager.serverList.clear();
    });

    test('the generation arriving is written and announced', () async {
      answer = _info({'autoDj': 1});
      await refresh();
      expect(s.autoDjGeneration, 1);
      expect((await written())?['autoDjGeneration'], 1);
      expect(announced, hasLength(1));
      expect(announced.single, same(s));
    });

    test('the same generation again: nothing written, nothing announced',
        () async {
      answer = _info({'autoDj': 1});
      await refresh();
      await settle();
      await refresh();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(serversFile().existsSync(), isFalse);
      expect(announced, isEmpty);
    });

    test('a server rolled back loses it: written and announced', () async {
      answer = _info({'autoDj': 1});
      await refresh();
      await settle();
      answer = _info({});
      await refresh();
      expect(s.autoDjGeneration, isNull);
      final saved = await written();
      expect(saved, isNotNull);
      expect(saved!.containsKey('autoDjGeneration'), isTrue);
      expect(saved['autoDjGeneration'], isNull);
      expect(announced, hasLength(1));
    });
  });
}
