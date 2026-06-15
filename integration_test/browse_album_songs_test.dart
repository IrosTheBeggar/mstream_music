// Browse-album-songs drill-down.
//
// The two-step drill-down:
//   1. Tap Albums → mock /api/v1/db/albums response shows.
//   2. Tap an album → mock POST /api/v1/db/album-songs response shows
//      track titles via the metadata-title path on DisplayItem.
//
// Catches regressions in the album-songs parsing path. Stops short of
// tapping a song to play it — just_audio would attempt to fetch the
// (mocked) URL, which is out of scope for this test.

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
    'Albums → tap album shows album songs with metadata titles',
    (WidgetTester tester) async {
      mockServer = await MockServer.start({
        '/api/v1/db/albums': (_) => {
              'albums': [
                {
                  'name': 'Wish You Were Here',
                  'year': 1975,
                  'album_art_file': null,
                },
              ],
            },
        '/api/v1/db/album-songs': (_) => [
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
                'filepath': 'pink-floyd/wywh/02.mp3',
                'metadata': {
                  'artist': 'Pink Floyd',
                  'album': 'Wish You Were Here',
                  'title': 'Welcome to the Machine',
                  'track': 2,
                  'disc': 1,
                  'year': 1975,
                  'hash': 'h-welcome',
                  'rating': null,
                  'album-art': null,
                },
              },
            ],
      });

      await seedServer(mockServer!.url);

      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.text('Albums'));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('Wish You Were Here'), findsOneWidget);

      await tester.tap(find.text('Wish You Were Here'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Shine On You Crazy Diamond'), findsOneWidget);
      expect(find.text('Welcome to the Machine'), findsOneWidget);
    },
  );
}
