// Browse-artists drill-down.
//
// Verifies the artists → artist-albums path:
//   1. Tap Artists, expect mocked artist names to render.
//   2. Tap an artist, expect that artist's albums to render.
//
// Catches regressions in the GET /api/v1/db/artists and POST
// /api/v1/db/artists-albums parsing in lib/singletons/api.dart.

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
    'Artists list renders, tapping one drills to that artist\'s albums',
    (WidgetTester tester) async {
      mockServer = await MockServer.start({
        '/api/v1/db/artists': (_) => {
              'artists': ['Pink Floyd', 'Led Zeppelin'],
            },
        '/api/v1/db/artists-albums': (_) => {
              'albums': [
                {
                  'name': 'Wish You Were Here',
                  'year': 1975,
                  'album_art_file': null,
                },
                {
                  'name': 'The Dark Side of the Moon',
                  'year': 1973,
                  'album_art_file': null,
                },
              ],
            },
      });

      await seedServer(mockServer!.url);

      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.text('Artists'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Pink Floyd'), findsOneWidget);
      expect(find.text('Led Zeppelin'), findsOneWidget);

      await tester.tap(find.text('Pink Floyd'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Wish You Were Here'), findsOneWidget);
      expect(find.text('The Dark Side of the Moon'), findsOneWidget);
    },
  );
}
