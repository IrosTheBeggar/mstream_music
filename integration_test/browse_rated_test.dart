// Browse-rated flow.
//
// Verifies the GET /api/v1/db/rated parsing path. Same shape as
// recent/added: each row renders its plain title plus a compact trailing
// rating readout ("N★", rating/2) from RatingControl. Rating 8 → "4".

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
    'tapping Rated renders rated songs with their rating',
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

      // Titles render plainly (no rating prefix); each rating shows as the
      // compact trailing "N★" readout — 8 → "4", 10 → "5".
      expect(find.text('Have a Cigar'), findsOneWidget);
      expect(find.text('Wish You Were Here'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    },
  );
}
