// Search flow.
//
// The browser exposes a search TextField in the top row when on the root
// browse menu. Submitting a query hits POST /api/v1/db/search, which
// returns three parallel arrays (artists, albums, title) that all flow
// into one combined results list. This test verifies one item from each
// section renders.
//
// Catches regressions in the most complex parsing path in
// lib/singletons/api.dart.searchServer — three different DisplayItem
// shapes share one response.
//
// The search-category dropdown beside the field is covered separately in
// search_categories_test.dart (mounting MStreamApp twice in one process
// re-subscribes a singleton stream, so each scenario gets its own file).

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
    'submitting a search query renders artists, albums, and titles',
    (WidgetTester tester) async {
      mockServer = await MockServer.start({
        '/api/v1/db/search': (_) => {
              'artists': [
                {
                  'name': 'Pink Floyd',
                  'album_art_file': null,
                },
              ],
              'albums': [
                {
                  'name': 'Wish You Were Here',
                  'album_art_file': null,
                },
              ],
              'title': [
                {
                  'name': 'Have a Cigar',
                  // For type='file', DisplayItem.getText renders
                  // filepath.split('/').last — not the 'name' field.
                  'filepath': 'pink-floyd/wywh/Have-a-Cigar.mp3',
                  'album_art_file': null,
                },
              ],
            },
      });

      await seedServer(mockServer!.url);

      // MStreamApp.build calls AppLocalizations.of(context), so the host
      // MaterialApp must carry the app's localization delegates (mirrors the
      // real MaterialApp in main.dart). Without them AppLocalizations.of
      // returns null and the app crashes before the search field renders.
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MStreamApp(),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Search TextField is in the top row when on the root browse menu.
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'pink');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // One item from each of the three sections.
      expect(find.text('Pink Floyd'), findsOneWidget);
      expect(find.text('Wish You Were Here'), findsOneWidget);
      expect(find.text('Have-a-Cigar.mp3'), findsOneWidget);
    },
  );
}
