// The app drawer's edge swipe and Android's gesture navigation. Where the
// system keeps the drawer's edge for its Back swipe, a swipe in from that
// edge leaves the drawer shut and the hamburger opens it. Where the system
// keeps no side edge (iOS, 3-button Android), the swipe still opens it. The
// harness has main.dart's shape: the drawer on an outer Scaffold, the
// hamburger on the inner one's app bar. A source pin checks that the real
// outer Scaffold asks [drawerEdgeSwipeAllowed], since MStreamApp itself
// needs platform plugins to pump (widget_test.dart).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/util/drawer_swipe.dart';

/// Gesture navigation at 3 px per dp: both side edges and the home bar are
/// the system's.
const _gestureNav = FakeViewPadding(left: 72, right: 72, bottom: 96);

/// 3-button navigation: only the bar at the bottom.
const _buttonNav = FakeViewPadding(bottom: 144);

void main() {
  final outer = GlobalKey<ScaffoldState>();

  Future<void> pumpShell(WidgetTester tester, FakeViewPadding insets,
      {TextDirection direction = TextDirection.ltr}) async {
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    tester.view.systemGestureInsets = insets;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Builder(
          builder: (context) => Scaffold(
            key: outer,
            drawer: const Drawer(child: Text('Menu')),
            drawerEnableOpenDragGesture: drawerEdgeSwipeAllowed(context),
            body: Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => outer.currentState?.openDrawer(),
                ),
              ),
              body: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    ));
  }

  /// A swipe in from the drawer's edge: the left one, or the right one in a
  /// right-to-left language.
  Future<void> swipeIn(WidgetTester tester,
      {TextDirection direction = TextDirection.ltr}) async {
    final ltr = direction == TextDirection.ltr;
    await tester.dragFrom(
        Offset(ltr ? 4 : 402 - 4, 437), Offset(ltr ? 300 : -300, 0));
    await tester.pumpAndSettle();
  }

  bool drawerOpen() => outer.currentState!.isDrawerOpen;

  testWidgets(
      'gesture navigation: a swipe in from the edge leaves the drawer shut, '
      'and the hamburger opens it', (tester) async {
    await pumpShell(tester, _gestureNav);
    await swipeIn(tester);
    expect(drawerOpen(), isFalse);
    expect(find.text('Menu'), findsNothing);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(drawerOpen(), isTrue);
    expect(find.text('Menu'), findsOneWidget);
  });

  testWidgets('3-button navigation keeps the edge swipe', (tester) async {
    await pumpShell(tester, _buttonNav);
    await swipeIn(tester);
    expect(drawerOpen(), isTrue);
    expect(find.text('Menu'), findsOneWidget);
  });

  testWidgets('iOS, which reports no gesture insets, keeps the edge swipe',
      (tester) async {
    await pumpShell(tester, const FakeViewPadding());
    await swipeIn(tester);
    expect(drawerOpen(), isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
      "right-to-left: the drawer's edge is the right one, so only that "
      "edge's inset counts", (tester) async {
    const rtl = TextDirection.rtl;
    await pumpShell(tester, _gestureNav, direction: rtl);
    await swipeIn(tester, direction: rtl);
    expect(drawerOpen(), isFalse);

    await pumpShell(tester, const FakeViewPadding(left: 72), direction: rtl);
    await swipeIn(tester, direction: rtl);
    expect(drawerOpen(), isTrue);
  });

  test("main.dart's outer Scaffold, the drawer's, asks it (source pin)", () {
    final source = File('lib/main.dart').readAsStringSync();
    final scaffold = RegExp(r'key: _outerScaffoldKey,([\s\S]*?)body: Stack\(')
        .firstMatch(source);
    expect(scaffold, isNotNull);
    final args = scaffold!.group(1)!;
    expect(args, contains('drawer: _appDrawer(context, l),'));
    expect(args,
        contains('drawerEnableOpenDragGesture: drawerEdgeSwipeAllowed(context),'));
  });
}
