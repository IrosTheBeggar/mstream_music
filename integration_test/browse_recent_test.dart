// Browse-recently-added flow.
//
// Verifies the POST /api/v1/db/recent/added parsing path. Each item is
// shaped {filepath, metadata: {artist, album, title, ...}}; when
// metadata.title is set, DisplayItem renders it as the row title.

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
    'tapping Recent renders titles from /api/v1/db/recent/added',
    (WidgetTester tester) async {
      mockServer = await MockServer.start({
        '/api/v1/db/recent/added': (_) => [
              {
                'filepath': 'pink-floyd/wywh/01.mp3',
                'metadata': {
                  'artist': 'Pink Floyd',
                  'album': 'Wish You Were Here',
                  'title': 'Shine On You Crazy Diamond',
                  'track': 1,
                  'disc': 1,
                  'year': 1975,
                  'hash': 'h-shine',
                  'rating': null,
                  'album-art': null,
                },
              },
              {
                'filepath': 'led-zeppelin/iv/04.mp3',
                'metadata': {
                  'artist': 'Led Zeppelin',
                  'album': 'IV',
                  'title': 'Stairway to Heaven',
                  'track': 4,
                  'disc': 1,
                  'year': 1971,
                  'hash': 'h-stairway',
                  'rating': null,
                  'album-art': null,
                },
              },
            ],
      });

      await seedServer(mockServer!.url);

      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.text('Recent'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Shine On You Crazy Diamond'), findsOneWidget);
      expect(find.text('Stairway to Heaven'), findsOneWidget);
      // Artist is rendered as the row's subtitle.
      expect(find.text('Pink Floyd'), findsOneWidget);
      expect(find.text('Led Zeppelin'), findsOneWidget);
    },
  );
}
