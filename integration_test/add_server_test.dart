// Add-server flow.
//
// Walks the realistic user journey of adding a new mStream server:
//   1. From the welcome screen, open AddServerScreen.
//   2. Tap Save with an empty URL — form validation fails with an error.
//   3. Enter a valid URL pointing at an in-process mock HTTP server.
//   4. Tap Save — flow completes, returns to browser, server URL shown.
//
// The mock server runs inside the test process on the emulator's loopback,
// so the app under test reaches it as http://127.0.0.1:<port>.
//
// Why this is one journey-style test instead of multiple cases:
//   audio_service and flutter_downloader both assert single-init per
//   process. testWidgets doesn't reset that state, so re-pumping
//   MStreamApp in a second testWidgets case crashes in initState. Test
//   files that need fresh init must be in separate files (each file is a
//   separate flutter-test driver entry).

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
    // NowPlaying tab is built alongside Browser via TabBarView and accesses
    // MediaManager().audioHandler.queue, so the audio handler must exist
    // before any pumpWidget(MStreamApp()) call.
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
    'add server: empty URL validates, valid URL connects to browser',
    (WidgetTester tester) async {
      mockServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final mockUrl = 'http://127.0.0.1:${mockServer!.port}';

      mockServer!.listen((HttpRequest req) async {
        if (req.method == 'GET' && req.uri.path == '/api/v1/ping') {
          req.response.statusCode = 200;
          req.response.headers.contentType = ContentType.json;
          req.response.write(jsonEncode({
            'vpaths': ['default'],
            'playlists': <String>[],
          }));
        } else {
          req.response.statusCode = 404;
        }
        await req.response.close();
      });

      await tester.pumpWidget(MaterialApp(home: MStreamApp()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Step 1: open AddServerScreen from the welcome item.
      await tester.tap(find.text('Welcome To mStream'));
      await tester.pumpAndSettle();
      expect(find.text('Add Server'), findsOneWidget);

      // Step 2: Save with empty URL — validation kicks in.
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Server URL is needed'), findsOneWidget);

      // Step 3: enter the mock URL and Save.
      await tester.enterText(find.byType(TextFormField).first, mockUrl);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Step 4: we're back on the browser. AppBar shows server URL,
      // default browse menu items are rendered.
      expect(find.text(mockUrl), findsOneWidget);
      expect(find.text('Albums'), findsOneWidget);
      expect(find.text('Artists'), findsOneWidget);
      expect(find.text('Playlists'), findsOneWidget);
    },
  );
}
