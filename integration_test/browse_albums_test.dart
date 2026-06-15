// Browse-albums flow.
//
// Pre-seeds a server in servers.json so MStreamApp loads it at startup
// and lands directly on the browser. Taps Albums and asserts the items
// returned by the mock /api/v1/db/albums endpoint render. Catches the
// most common modernization regression: server-side API shape drifts
// that silently break parsing in lib/singletons/api.dart.

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
    'tapping Albums renders the list returned by the server',
    (WidgetTester tester) async {
      mockServer = await MockServer.start({
        '/api/v1/db/albums': (_) => {
              'albums': [
                {
                  'name': 'Wish You Were Here',
                  'year': 1975,
                  'album_art_file': null,
                },
                {
                  'name': 'Dark Side of the Moon',
                  'year': 1973,
                  'album_art_file': null,
                },
              ],
            },
      });

      await seedServer(mockServer!.url);

      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('Albums'), findsOneWidget);

      await tester.tap(find.text('Albums'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Wish You Were Here'), findsOneWidget);
      expect(find.text('Dark Side of the Moon'), findsOneWidget);
    },
  );
}
