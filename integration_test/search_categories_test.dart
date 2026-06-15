// Search-category dropdown.
//
// Beside the home search field sits a dropdown that picks which categories the
// DB search queries. It uses CHECKBOXES (multi-select) rather than single-pick,
// so the user can search, say, just Artists + Albums. The two things that make
// that work — a checkbox per category, and the menu staying OPEN while you
// toggle (so several can be picked in one go) — are verified here.
//
// Lives in its own file because each integration test mounts a fresh
// MStreamApp, and mounting it twice in one process re-subscribes a
// single-subscription singleton stream (DownloadManager) — so one mount,
// one scenario, per file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mstream_music/l10n/app_localizations.dart';
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
    'category dropdown shows a checkbox per category and stays open on toggle',
    (WidgetTester tester) async {
      // Only the home screen is needed — the default ping route from
      // MockServer.start is enough to seed a server and land on the browser.
      mockServer = await MockServer.start({});
      await seedServer(mockServer!.url);

      // Localization delegates mirror the real MaterialApp in main.dart — see
      // search_test.dart for why a bare MaterialApp crashes MStreamApp.build.
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MStreamApp(),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Open the category dropdown beside the search field.
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      // One checkbox per category. 'Songs' and 'Files' are unique to the menu
      // (the home grid has Albums/Artists cards too, so assert on the
      // menu-only labels to avoid matching those).
      expect(find.byType(CheckboxListTile), findsNWidgets(4));
      expect(find.text('Songs'), findsOneWidget);
      expect(find.text('Files'), findsOneWidget);

      // Toggling a box must NOT close the menu — the whole point of checkboxes
      // is picking several without reopening. Tap 'Files'; the menu stays up.
      await tester.tap(find.text('Files'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsNWidgets(4),
          reason: 'menu stayed open after toggling a checkbox');
      expect(find.text('Songs'), findsOneWidget);
    },
  );
}
