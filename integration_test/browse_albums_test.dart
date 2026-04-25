// Browse-albums flow.
//
// Pre-seeds a server entry in servers.json on disk so MStreamApp loads it
// at startup and lands directly on the browser. Then taps "Albums" and
// verifies the items returned by the mock /api/v1/db/albums endpoint
// render in the list.
//
// This catches the most common modernization regression: server-side API
// shape drifts (renamed fields, restructured response) that silently
// break parsing in lib/singletons/api.dart.
//
// Lives in its own file because audio_service and flutter_downloader
// assert single-init per process — see add_server_test.dart for the
// same constraint.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:mstream_music/main.dart';
import 'package:mstream_music/singletons/media.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/singletons/browser_list.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  HttpServer? mockServer;

  setUpAll(() async {
    await MediaManager().start();
  });

  setUp(() async {
    final dir = await getApplicationDocumentsDirectory();
    final serversFile = File('${dir.path}/servers.json');
    if (await serversFile.exists()) {
      await serversFile.delete();
    }
    ServerManager().serverList.clear();
    ServerManager().currentServer = null;
    BrowserManager().browserCache.clear();
    BrowserManager().browserList.clear();
  });

  tearDown(() async {
    if (mockServer != null) {
      await mockServer!.close(force: true);
      mockServer = null;
    }
  });

  testWidgets(
    'tapping Albums renders the list returned by the server',
    (WidgetTester tester) async {
      mockServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final mockUrl = 'http://127.0.0.1:${mockServer!.port}';

      mockServer!.listen((HttpRequest req) async {
        req.response.headers.contentType = ContentType.json;
        if (req.method == 'GET' && req.uri.path == '/api/v1/ping') {
          req.response.statusCode = 200;
          req.response.write(jsonEncode({
            'vpaths': ['default'],
            'playlists': <String>[],
          }));
        } else if (req.method == 'GET' &&
            req.uri.path == '/api/v1/db/albums') {
          req.response.statusCode = 200;
          req.response.write(jsonEncode({
            'albums': [
              {
                'name': 'Wish You Were Here',
                'year': 1975,
                'album_art_file': null,
              },
              {
                'name': 'Dark Side of the Moon',
                'year': 1973,
                'album_art_file': null,
              },
            ],
          }));
        } else {
          req.response.statusCode = 404;
        }
        await req.response.close();
      });

      // Pre-seed a server entry on disk so MStreamApp.initState's
      // loadServerList picks it up and skips the welcome screen.
      final dir = await getApplicationDocumentsDirectory();
      final serversFile = File('${dir.path}/servers.json');
      await serversFile.writeAsString(jsonEncode([
        {
          'url': mockUrl,
          'jwt': null,
          'username': null,
          'password': null,
          'localname': 'integration-test-server',
          'autoDJPaths': <String, bool>{},
          'autoDJminRating': null,
          'playlists': <String>[],
          'saveToSdCard': false,
        },
      ]));

      await tester.pumpWidget(MaterialApp(home: MStreamApp()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // We should be on the browser now (server was pre-loaded).
      expect(find.text('Albums'), findsOneWidget);

      await tester.tap(find.text('Albums'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Wish You Were Here'), findsOneWidget);
      expect(find.text('Dark Side of the Moon'), findsOneWidget);
    },
  );
}
