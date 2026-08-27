// Add-server flow.
//
// Walks the realistic user journey of adding a new mStream server:
//   1. From the welcome screen, open AddServerScreen.
//   2. Tap Save with an empty URL — form validation fails.
//   3. Enter a valid URL pointing at an in-process mock HTTP server.
//   4. Tap Save — the first-run setup flow appears over the browser.
//   5. Skip it — browser is shown with the server URL.

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mstream_music/singletons/media.dart';
import 'package:mstream_music/screens/welcome_screen.dart';
import 'package:mstream_music/singletons/settings.dart';

import 'helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  MockServer? mockServer;

  setUpAll(() async {
    await MediaManager().start();
  });

  setUp(() async {
    await resetAppState();
    // A previous test in this process may have dismissed these (both persist
    // once spent). This test asserts on both, so put them back.
    SettingsManager().onboardingComplete = false;
    SettingsManager().welcomeShown = false;
  });

  tearDown(() async {
    await mockServer?.close();
    mockServer = null;
  });

  testWidgets(
    'add server: empty URL validates, valid URL connects to browser',
    (WidgetTester tester) async {
      mockServer = await MockServer.start({});

      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // A brand new install opens onto the one-shot WelcomeScreen, pushed over
      // the browser (whose own add-server row is offstage behind it). Matched
      // by type, not text: its header is the logo image, and the browser row
      // underneath carries the only "Welcome to mStream" string left.
      expect(find.byType(WelcomeScreen), findsOneWidget);
      await tester.tap(find.text('Add Server'));
      await tester.pumpAndSettle();
      expect(find.text('Add Server'), findsOneWidget);

      // The Save button is at the bottom edge of the form; scroll it fully
      // into view so the tap lands on it rather than the screen edge.
      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Server URL is needed'), findsOneWidget);

      await tester.enterText(
          find.byType(TextFormField).first, mockServer!.url);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // First server on a fresh install pushes the setup flow over the
      // browser. Skip out of it to get at the browser underneath.
      expect(find.text('Quick setup'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(SettingsManager().onboardingComplete, isTrue,
          reason: 'dismissing the flow must stop it coming back');

      expect(find.text(mockServer!.url), findsOneWidget);
      expect(find.text('Albums'), findsOneWidget);
      expect(find.text('Artists'), findsOneWidget);
      expect(find.text('Playlists'), findsOneWidget);
    },
  );
}
