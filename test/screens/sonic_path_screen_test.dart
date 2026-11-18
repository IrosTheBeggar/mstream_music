// SonicPathScreen drops a pick the user walked away from (a drawer re-entry
// over a live banner), so the next browse tap after the screen closes again
// plays instead of being captured. It drops it once its first frame is
// built: the home's banner listens to the pick, and cancelling while the
// screen's route is being built would mark the banner for a rebuild in the
// middle of that build ("setState() or markNeedsBuild() called during
// build"), leaving it drawn in a debug build.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/app_localizations.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/sonic_path_screen.dart';
import 'package:mstream_music/singletons/track_capture.dart';

void main() {
  final home = Server('https://home.example.com', 'u', 'p', 'JWT', 'home');

  TrackCaptureRequest request() => TrackCaptureRequest(
      server: home,
      bannerLabel: (_) => '',
      returnStack: const [],
      onPicked: (_) {});

  late GlobalKey<NavigatorState> nav;

  // The home draws the capture banner as main.dart does: it listens to the
  // armed pick.
  Future<void> showHome(WidgetTester tester) async {
    nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: nav,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ValueListenableBuilder<TrackCaptureRequest?>(
          valueListenable: TrackCapture.active,
          builder: (_, req, _) => Text(req == null ? 'library' : 'banner'),
        ),
      ),
    ));
  }

  tearDown(TrackCapture.cancel);

  testWidgets(
      'opened while a pick is still armed, the screen drops it once its '
      'first frame is built, so the banner goes with no rebuild mid-build '
      'and the next library tap plays', (tester) async {
    await showHome(tester);
    TrackCapture.arm(request());
    await tester.pump();
    expect(find.text('banner'), findsOneWidget);

    nav.currentState!.push(
        MaterialPageRoute(builder: (_) => const SonicPathScreen()));
    await tester.pump();
    expect(tester.takeException(), isNull,
        reason: 'the cancel must not notify the banner during the build');
    expect(TrackCapture.pending, isNull,
        reason: 'dropped at the end of the frame that built the screen');

    await tester.pumpAndSettle();
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('library'), findsOneWidget);
    expect(find.text('banner'), findsNothing);
  });

  testWidgets('opened with nothing armed, it arms and drops nothing',
      (tester) async {
    await showHome(tester);
    nav.currentState!.push(
        MaterialPageRoute(builder: (_) => const SonicPathScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(TrackCapture.pending, isNull);

    // A pick armed after the screen opened (its own Browse library) stays.
    final mine = request();
    TrackCapture.arm(mine);
    await tester.pumpAndSettle();
    expect(TrackCapture.pending, same(mine));
  });
}
