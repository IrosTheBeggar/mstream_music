// TrackCapture's way back (singletons/track_capture.dart). goBack puts a
// request's screens back over the home, bottom first, and tells the home
// once the top one has slid in, or was popped before it had: the home's cue
// to put back what isn't a route, the player it closed to show the library.
// With no screens to put back it pushes nothing and tells nothing. The
// banner's Cancel (cancelAndGoBack) disarms the pick at once and takes the
// same way back; with nothing armed it does nothing.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/track_capture.dart';

void main() {
  final home = Server('https://home.example.com', 'u', 'p', 'JWT', 'home');

  TrackCaptureRequest request({List<WidgetBuilder> back = const []}) =>
      TrackCaptureRequest(
          server: home,
          bannerLabel: (_) => '',
          returnStack: back,
          onPicked: (_) {});

  // A screen two deep, as the Seeds page over the Auto DJ screen.
  final twoDeep = <WidgetBuilder>[
    (_) => const Scaffold(body: Text('under')),
    (_) => const Scaffold(body: Text('asking')),
  ];

  late GlobalKey<NavigatorState> nav;
  // What the home is told, in order.
  late List<TrackCaptureRequest> told;

  Future<void> showHome(WidgetTester tester) async {
    nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
        navigatorKey: nav, home: const Scaffold(body: Text('home'))));
  }

  setUp(() {
    told = [];
    TrackCapture.onHomeCovered = told.add;
  });
  tearDown(() {
    TrackCapture.onHomeCovered = null;
    TrackCapture.cancel();
  });

  group('TrackCapture.goBack', () {
    testWidgets('tells the home once the top screen has slid in over it, '
        'not before, and only once', (tester) async {
      await showHome(tester);
      final req = request(back: twoDeep);
      TrackCapture.goBack(nav.currentState!, req);
      await tester.pump();
      expect(find.text('asking', skipOffstage: false), findsOneWidget);
      expect(told, isEmpty, reason: 'the first frame of the slide-in');
      await tester.pump(const Duration(milliseconds: 100));
      expect(told, isEmpty, reason: 'still sliding in');
      await tester.pumpAndSettle();
      expect(told, [same(req)]);
      expect(find.text('under', skipOffstage: false), findsOneWidget);

      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('under'), findsOneWidget);
      expect(told, hasLength(1), reason: 'leaving tells nothing more');
    });

    testWidgets('tells the home too when the top screen is popped before it '
        'has slid in', (tester) async {
      await showHome(tester);
      final req = request(back: [(_) => const Scaffold(body: Text('asking'))]);
      TrackCapture.goBack(nav.currentState!, req);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(told, isEmpty);
      nav.currentState!.pop();
      await tester.pump();
      expect(told, [same(req)], reason: 'Back before the page was in');
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(told, hasLength(1));
    });

    testWidgets('with no screens to put back, pushes nothing and tells '
        'nothing', (tester) async {
      await showHome(tester);
      TrackCapture.goBack(nav.currentState!, request());
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(nav.currentState!.canPop(), isFalse);
      expect(told, isEmpty);
    });
  });

  group('TrackCapture.cancelAndGoBack', () {
    testWidgets("the banner's Cancel disarms the pick at once and takes its "
        'way back', (tester) async {
      await showHome(tester);
      final req = request(back: twoDeep);
      TrackCapture.arm(req);
      TrackCapture.cancelAndGoBack(nav.currentState!);
      expect(TrackCapture.pending, isNull, reason: 'before any frame');
      await tester.pumpAndSettle();
      expect(find.text('asking'), findsOneWidget);
      expect(find.text('under', skipOffstage: false), findsOneWidget);
      expect(told, [same(req)]);
    });

    testWidgets('with no way back, Cancel disarms the pick and stays put, as '
        "for the Auto DJ start's pick", (tester) async {
      await showHome(tester);
      TrackCapture.arm(request());
      TrackCapture.cancelAndGoBack(nav.currentState!);
      expect(TrackCapture.pending, isNull);
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(nav.currentState!.canPop(), isFalse);
      expect(told, isEmpty);
    });

    testWidgets('with nothing armed, as under a banner drawn for a pick that '
        'is already gone, Cancel does nothing', (tester) async {
      await showHome(tester);
      TrackCapture.arm(request(back: twoDeep));
      TrackCapture.cancel();
      TrackCapture.cancelAndGoBack(nav.currentState!);
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(nav.currentState!.canPop(), isFalse);
      expect(told, isEmpty);
    });
  });
}
