// The two flags Add from YouTube adds to the boot payloads: `noMkdir` (the
// account's folder right — caller-scoped, under `user` on /api, flat on
// ping) and the formats the server converts to (the `true` keys of
// `supportedAudioFiles` — under `features` on /api, flat on ping). Where
// each is read from, what a missing or junk value reads as, the pin a
// federated peer gets whatever it says — and the change detection after a
// refresh: the feature's gates (transcodeAvailable, the library set,
// noMkdir, the formats) redraw a home that is showing and are written to
// servers.json, while a refresh that changes nothing does neither.
//
// The folds go through ServerManager's applyServerInfoForTest /
// applyPingForTest seams; the change detection through a real
// getServerPaths against a MockClient.

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

Server _peerOf(Server parent) =>
    Server('federated://home/3', null, null, null, 'peer-basement')
      ..federationParent = 'home'
      ..federationPeerId = 3
      ..parentServer = parent;

/// mStream's default `supportedAudioFiles` (m3u listed, and off).
const _defaultFormats = {
  'mp3': true,
  'flac': true,
  'wav': true,
  'ogg': true,
  'aac': true,
  'm4a': true,
  'm4b': true,
  'opus': true,
  'm3u': false,
};

/// A layered `GET /api/` body with [features] and [user] merged in.
Map<String, dynamic> _info(
        {Map<String, dynamic> features = const {},
        Map<String, dynamic> user = const {}}) =>
    {
      'server': '6.32.0',
      'features': {'transcode': false, ...features},
      'user': {
        'vpaths': ['Music'],
        ...user
      },
    };

/// A flat ping body with [extra] merged in.
Map<String, dynamic> _ping(Map<String, dynamic> extra) => {
      'vpaths': ['Music'],
      'playlists': [],
      ...extra,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final manager = ServerManager();

  group('noMkdir (the folder right)', () {
    test('/api reads it from user, never from features', () {
      final s = _plain();
      manager.applyServerInfoForTest(s, _info(user: {'noMkdir': true}));
      expect(s.noMkdir, isTrue);
      manager.applyServerInfoForTest(s, _info(user: {'noMkdir': false}));
      expect(s.noMkdir, isFalse);
      manager.applyServerInfoForTest(s, _info(features: {'noMkdir': true}));
      expect(s.noMkdir, isNull,
          reason: 'a server too old to say: unknown, not allowed');
      manager.applyServerInfoForTest(s, _info(user: {'noMkdir': 'yes'}));
      expect(s.noMkdir, isNull);
      manager.applyServerInfoForTest(s, _info(user: {'noMkdir': 1}));
      expect(s.noMkdir, isNull, reason: 'bool only');
    });

    test('ping reads it flat', () {
      final s = _plain();
      manager.applyPingForTest(s, _ping({'noMkdir': true}));
      expect(s.noMkdir, isTrue);
      manager.applyPingForTest(s, _ping({'noMkdir': false}));
      expect(s.noMkdir, isFalse);
      manager.applyPingForTest(s, _ping({}));
      expect(s.noMkdir, isNull);
      manager.applyPingForTest(s, _ping({'noMkdir': 'false'}));
      expect(s.noMkdir, isNull);
    });

    test('is independent of noUpload', () {
      final s = _plain();
      manager.applyServerInfoForTest(
          s, _info(user: {'noUpload': true, 'noMkdir': false}));
      expect([s.noUpload, s.noMkdir], [true, false]);
    });
  });

  group('supportedAudioFormats (what POST /ytdl may convert to)', () {
    test("/api reads features.supportedAudioFiles: the true keys, sorted", () {
      final s = _plain();
      manager.applyServerInfoForTest(
          s, _info(features: {'supportedAudioFiles': _defaultFormats}));
      expect(s.supportedAudioFormats,
          ['aac', 'flac', 'm4a', 'm4b', 'mp3', 'ogg', 'opus', 'wav'],
          reason: 'm3u is listed, and off');
    });

    test('ping reads it flat', () {
      final s = _plain();
      manager.applyPingForTest(s, _ping({
        'supportedAudioFiles': {'opus': true, 'mp3': false, 'flac': true}
      }));
      expect(s.supportedAudioFormats, ['flac', 'opus']);
    });

    test('only `true` counts; every format off is an empty list', () {
      final s = _plain();
      manager.applyPingForTest(s, _ping({
        'supportedAudioFiles': {'mp3': 'true', 'flac': 1, 'wav': null, 'ogg': true}
      }));
      expect(s.supportedAudioFormats, ['ogg']);
      manager.applyPingForTest(s, _ping({
        'supportedAudioFiles': {'mp3': false}
      }));
      expect(s.supportedAudioFormats, isEmpty);
    });

    test('anything but a map is unknown (null), from either payload', () {
      final s = _plain()..supportedAudioFormats = ['mp3'];
      manager.applyServerInfoForTest(s, _info());
      expect(s.supportedAudioFormats, isNull, reason: 'a server too old to say');
      for (final junk in [
        ['mp3', 'flac'],
        'mp3',
        true,
      ]) {
        manager.applyPingForTest(s, _ping({'supportedAudioFiles': junk}));
        expect(s.supportedAudioFormats, isNull, reason: '$junk');
      }
    });

    test('read where each payload keeps it, nowhere else', () {
      final s = _plain();
      manager.applyServerInfoForTest(
          s, _info(user: {'supportedAudioFiles': _defaultFormats}));
      expect(s.supportedAudioFormats, isNull, reason: "it is server-wide, not the user's");
      manager.applyPingForTest(s, _ping({
        'features': {'supportedAudioFiles': _defaultFormats}
      }));
      expect(s.supportedAudioFormats, isNull, reason: 'ping is flat');
    });

    test('the helpers: true keys sorted; same formats in any order', () {
      expect(ServerManager.enabledAudioFormats({'opus': true, 'aac': true}),
          ['aac', 'opus']);
      expect(ServerManager.enabledAudioFormats(null), isNull);
      expect(ServerManager.sameAudioFormats(['mp3', 'flac'], ['flac', 'mp3']),
          isTrue);
      expect(ServerManager.sameAudioFormats(['mp3'], ['mp3', 'flac']), isFalse);
      expect(ServerManager.sameAudioFormats(null, null), isTrue);
      expect(ServerManager.sameAudioFormats(null, []), isFalse,
          reason: 'unknown is not "every format off"');
    });
  });

  group('a federated peer', () {
    test('both are pinned null whatever its own /api says', () {
      final peer = _peerOf(_plain());
      manager.applyServerInfoForTest(
          peer,
          _info(
              features: {'supportedAudioFiles': _defaultFormats},
              user: {'noMkdir': false}));
      expect(peer.noMkdir, isNull);
      expect(peer.supportedAudioFormats, isNull);
    });

    test('the parent keeps its own answer', () {
      final parent = _plain();
      final peer = _peerOf(parent);
      final body = _info(
          features: {'supportedAudioFiles': _defaultFormats},
          user: {'noMkdir': true});
      manager.applyServerInfoForTest(parent, body);
      manager.applyServerInfoForTest(peer, body);
      expect(parent.noMkdir, isTrue);
      expect(parent.supportedAudioFormats, hasLength(8));
      expect(peer.noMkdir, isNull);
      expect(peer.supportedAudioFormats, isNull);
    });
  });

  // getServerPaths snapshots every flag, folds the answer, then writes
  // servers.json and redraws a showing home when a flag it compares moved.
  group('a refresh that changes a gate', () {
    late Directory scratch;
    late Server s;
    late Map<String, dynamic> answer;

    File serversFile() => File('${scratch.path}/servers.json');

    setUpAll(() {
      scratch = Directory.systemTemp.createTempSync('mstream-ytdl-flags-');
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
    /// write, so give the chain a moment — and read past a half-written
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

    setUp(() async {
      s = _plain();
      manager.serverList
        ..clear()
        ..add(s);
      manager.currentServer = s;
      answer = _info(
          features: {'supportedAudioFiles': _defaultFormats},
          user: {'noUpload': false, 'noMkdir': false});
      await refresh(); // the baseline: every flag known
      // Queued behind the baseline's write (and any a previous test left),
      // so once it lands nothing else is pending.
      await manager.writeServerFile();
      serversFile().deleteSync();
      showHome();
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

    test('transcode coming up (ffmpeg fetched) redraws the home', () async {
      expect(s.transcodeAvailable, isFalse);
      answer['features']['transcode'] = {
        'defaultCodec': 'opus',
        'defaultBitrate': '96k'
      };
      await refresh();
      expect(s.transcodeAvailable, isTrue);
      expect(homeRedrawn(), isTrue,
          reason: 'the YouTube card hides only on transcode == false');
      expect((await written())?['transcodeAvailable'], isTrue);
    });

    test('noMkdir moving redraws the home and is written', () async {
      answer['user']['noMkdir'] = true;
      await refresh();
      expect(homeRedrawn(), isTrue);
      expect((await written())?['noMkdir'], isTrue);
    });

    test('a format switched off redraws the home and is written', () async {
      answer['features']['supportedAudioFiles'] = {
        ..._defaultFormats,
        'opus': false
      };
      await refresh();
      expect(homeRedrawn(), isTrue);
      expect((await written())?['supportedAudioFormats'],
          ['aac', 'flac', 'm4a', 'm4b', 'mp3', 'ogg', 'wav']);
    });

    test('the same formats in another order are no change', () async {
      answer['features']['supportedAudioFiles'] = Map.fromEntries(
          _defaultFormats.entries.toList().reversed);
      await refresh();
      expect(homeRedrawn(), isFalse);
    });

    test('a library added or removed redraws the home and is written',
        () async {
      answer['user']['vpaths'] = ['Music', 'Audiobooks'];
      await refresh();
      expect(homeRedrawn(), isTrue);
      expect(((await written())?['autoDJPaths'] as Map).keys,
          unorderedEquals(['Music', 'Audiobooks']));

      showHome();
      await manager.writeServerFile();
      serversFile().deleteSync();
      answer['user']['vpaths'] = <String>[];
      await refresh();
      expect(homeRedrawn(), isTrue, reason: 'no libraries: the card hides');
      expect(((await written())?['autoDJPaths'] as Map), isEmpty);
    });

    test('a home that is not showing is left alone', () async {
      BrowserManager().browserList
        ..clear()
        ..add(DisplayItem(s, 'marker', 'directory', '/Music/', null, null));
      answer['features']['transcode'] = {'defaultCodec': 'opus'};
      await refresh();
      expect(homeRedrawn(), isFalse, reason: 'a rebuild resets the browse stack');
    });
  });
}
