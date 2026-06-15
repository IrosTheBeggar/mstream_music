// Search-category dropdown + focus preview.
//
// Beside the home search field sits a dropdown that picks which categories the
// DB search queries. It uses CHECKBOXES (multi-select) rather than single-pick,
// so the user can search, say, just Artists + Albums. This verifies:
//   • touching the field shows a subheader previewing which categories a search
//     will cover (so stale defaults from a past session are visible up front);
//   • the dropdown shows a checkbox per category and stays OPEN while toggling
//     (so several can be picked in one go).
//
// Lives in its own file because each integration test mounts a fresh
// MStreamApp, and mounting it twice in one process re-subscribes a
// single-subscription singleton stream (DownloadManager) — so one mount,
// one scenario, per file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

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
    'category dropdown: focus preview + a checkbox per category, stays open',
    (WidgetTester tester) async {
      // Only the home screen is needed — the default ping route from
      // MockServer.start is enough to seed a server and land on the browser.
      mockServer = await MockServer.start({});
      await seedServer(mockServer!.url);

      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Touching the search field previews which categories a search will
      // cover, so a stale selection from a past session is visible before
      // typing. (Default selection → "Searching ...".)
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.textContaining('Searching'), findsOneWidget);

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
