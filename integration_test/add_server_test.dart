// Add-server flow.
//
// Walks the realistic user journey of adding a new mStream server:
//   1. From the welcome screen, open AddServerScreen.
//   2. Tap Save with an empty URL — form validation fails.
//   3. Enter a valid URL pointing at an in-process mock HTTP server.
//   4. Tap Save — flow completes, returns to browser, server URL shown.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mstream_music/main.dart';
import 'package:mstream_music/singletons/media.dart';

import 'helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  MockServer? mockServer;

  setUpAll(() async {
    await MediaManager().start();
  });

  setUp(resetAppState);

  tearDown(() async {
    await mockServer?.close();
    mockServer = null;
  });

  testWidgets(
    'add server: empty URL validates, valid URL connects to browser',
    (WidgetTester tester) async {
      mockServer = await MockServer.start({});

      await tester.pumpWidget(MaterialApp(home: MStreamApp()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.text('Welcome To mStream'));
      await tester.pumpAndSettle();
      expect(find.text('Add Server'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Server URL is needed'), findsOneWidget);

      await tester.enterText(
          find.byType(TextFormField).first, mockServer!.url);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text(mockServer!.url), findsOneWidget);
      expect(find.text('Albums'), findsOneWidget);
      expect(find.text('Artists'), findsOneWidget);
      expect(find.text('Playlists'), findsOneWidget);
    },
  );
}
