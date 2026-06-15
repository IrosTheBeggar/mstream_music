// Browse-rated flow.
//
// Verifies the GET /api/v1/db/rated parsing path. Same shape as
// recent/added, but DisplayItem.showRating is set to true, so the row
// title is prefixed with `[rating/2] `. Rating 8 → "[4.0] Title".

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
    'tapping Rated renders titles prefixed with rating/2',
    (WidgetTester tester) async {
      mockServer = await MockServer.start({
        '/api/v1/db/rated': (_) => [
              {
                'filepath': 'pink-floyd/wywh/03.mp3',
                'metadata': {
                  'artist': 'Pink Floyd',
                  'album': 'Wish You Were Here',
                  'title': 'Have a Cigar',
                  'track': 3,
                  'disc': 1,
                  'year': 1975,
                  'hash': 'h-cigar',
                  'rating': 8,
                  'album-art': null,
                },
              },
              {
                'filepath': 'pink-floyd/wywh/04.mp3',
                'metadata': {
                  'artist': 'Pink Floyd',
                  'album': 'Wish You Were Here',
                  'title': 'Wish You Were Here',
                  'track': 4,
                  'disc': 1,
                  'year': 1975,
                  'hash': 'h-wywh',
                  'rating': 10,
                  'album-art': null,
                },
              },
            ],
      });

      await seedServer(mockServer!.url);

      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.text('Rated'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // DisplayItem prefixes the title with `[rating/2] ` when
      // showRating is true. Both ratings are even ints so the format
      // is `[N.0] Title`.
      expect(find.text('[4.0] Have a Cigar'), findsOneWidget);
      expect(find.text('[5.0] Wish You Were Here'), findsOneWidget);
    },
  );
}
