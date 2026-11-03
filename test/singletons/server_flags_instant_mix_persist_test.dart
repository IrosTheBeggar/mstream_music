// Instant Mix's flag through the real ServerManager.getServerPaths, beside
// noMkdir and the audio formats: the persist compare writes servers.json and
// announces the server once when the flag arrives, writes nothing when
// nothing moved, and a server that only answers ping (pre-mStream #932)
// nulls the flag while its flat noMkdir and formats are still read.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/server_list.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final manager = ServerManager();
  late Directory scratch;
  late Server s;
  late Map<String, dynamic> answer;
  Map<String, dynamic>? ping;

  File serversFile() => File('${scratch.path}/servers.json');

  setUpAll(() {
    scratch = Directory.systemTemp.createTempSync('instant-mix-persist-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => scratch.path);
  });
  tearDownAll(() {
    try {
      scratch.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<void> refresh() => http.runWithClient(
      () => manager.getServerPaths(s, throwErr: true),
      () => MockClient((req) async => http.Response(
          jsonEncode(req.url.path == '/api/'
              ? answer
              : req.url.path == '/api/v1/ping'
                  ? ping
                  : []),
          200,
          headers: {'content-type': 'application/json'})));

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
    s = Server('https://home.example.com', null, null, 'JWT', 'home');
    manager.serverList
      ..clear()
      ..add(s);
    manager.currentServer = s;
    answer = {
      'server': '6.33.0',
      'features': {
        'transcode': false,
        'discovery': true,
        'discoveryReady': true,
        'supportedAudioFiles': {'mp3': true, 'opus': true},
      },
      'user': {
        'vpaths': ['Music'],
        'noUpload': false,
        'noMkdir': false,
      },
    };
    ping = null;
    await refresh();
    await manager.writeServerFile();
    serversFile().deleteSync();
  });
  tearDown(() {
    manager.serverList.clear();
    manager.currentServer = null;
  });

  test('instantMix arriving alone is written and announced', () async {
    expect(s.instantMixGeneration, isNull);
    final changes = <Server>[];
    final sub = manager.capabilityChanges.listen(changes.add);
    answer['features']['instantMix'] = 1;
    await refresh();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(s.instantMixGeneration, 1);
    expect(s.instantMixUsable, isTrue);
    expect((await written())?['instantMixGeneration'], 1);
    expect(changes, [s]);
  });

  test('nothing moved: nothing written, nothing announced', () async {
    answer['features']['instantMix'] = 1;
    await refresh();
    await manager.writeServerFile();
    serversFile().deleteSync();
    final changes = <Server>[];
    final sub = manager.capabilityChanges.listen(changes.add);
    await refresh();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await sub.cancel();
    expect(serversFile().existsSync(), isFalse);
    expect(changes, isEmpty);
  });

  test('noMkdir and the formats still persist beside it', () async {
    answer['features']['instantMix'] = 1;
    answer['user']['noMkdir'] = true;
    answer['features']['supportedAudioFiles'] = {'mp3': true};
    await refresh();
    final saved = await written();
    expect(saved?['noMkdir'], isTrue);
    expect(saved?['supportedAudioFormats'], ['mp3']);
    expect(saved?['instantMixGeneration'], 1);
  });

  test('a pre-#932 server (ping): YouTube flags read flat, Instant mix '
      'nulled', () async {
    answer['features']['instantMix'] = 1;
    await refresh();
    expect(s.instantMixGeneration, 1);
    answer = {
      'server': '5.12.0',
      'apiVersions': ['1'],
      'features': {'subsonic': false},
    };
    ping = {
      'vpaths': ['Music'],
      'playlists': [],
      'noMkdir': true,
      'supportedAudioFiles': {'mp3': true, 'flac': true, 'm3u': false},
      'instantMix': 1,
    };
    await refresh();
    expect(s.instantMixGeneration, isNull);
    expect(s.noMkdir, isTrue);
    expect(s.supportedAudioFormats, ['flac', 'mp3']);
    final saved = await written();
    expect(saved?['instantMixGeneration'], isNull);
    expect(saved?['noMkdir'], isTrue);
  });
}
