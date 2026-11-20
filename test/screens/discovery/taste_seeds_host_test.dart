// The configuration bar and the seeds sheet over a TasteSeedsHost (mStream
// plan §4.2: Discover and Peer Recommendations draw the same bar, each over
// its own controller). A fake host stands in for both pages: the bar draws
// the host's window and calls its setWindow, More options opens the seeds
// sheet on the host's seeds and hands Use these to its applySeeds, the
// page's onOpenSeeds runs once as the sheet opens (Peer Recommendations
// ends a live preview there, the phone build plan's D2), and the controls
// are off while the host is loading or latched off.
//
// Nothing here touches the network: the fake records what it is asked.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/discovery.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/discovery/discovery_seeds_sheet.dart';
import 'package:mstream_music/screens/discovery/discovery_widgets.dart';
import 'package:mstream_music/screens/discovery/taste_seeds_host.dart';

import '../discovery_fixtures.dart';

/// One call of [FakeTasteHost.applySeeds], as sent.
typedef AppliedSeeds = ({
  Set<String> drop,
  Set<String> restore,
  List<String> pins,
});

/// A page that is neither Discover nor Peer Recommendations: plain state the
/// test sets, and a record of every call the bar and the sheet make.
class FakeTasteHost extends ChangeNotifier implements TasteSeedsHost {
  FakeTasteHost({
    required this.server,
    this.seeded,
    this.window = kTasteDefaultWindow,
    this.pins = const [],
  });

  @override
  final Server server;
  @override
  int window;
  @override
  bool loading = false;
  @override
  bool disabled = false;
  @override
  TasteResponse? seeded;
  @override
  List<String> pins;
  @override
  DateTime Function() now = () => DateTime.utc(2026, 10, 5, 12);

  @override
  List<TasteSeed> get seeds => seeded?.seeds ?? const [];
  @override
  List<TasteExcluded> get excluded => seeded?.excluded ?? const [];
  @override
  bool get isRandom => seeded?.seedSource == TasteSeedSource.random;

  /// Discover's rule by default: an answer is up once one has landed. A
  /// test sets [shownOverride] to stand for a page whose seeds and screen
  /// part (Peer Recommendations while a new batch is out).
  bool? shownOverride;
  @override
  bool get answerShown => shownOverride ?? seeded != null;

  final List<int> windows = [];
  final List<AppliedSeeds> applied = [];

  @override
  Future<void> setWindow(int w) async {
    windows.add(w);
    window = w;
    notifyListeners();
  }

  @override
  Future<void> applySeeds({
    Set<String> drop = const {},
    Set<String> restore = const {},
    required List<String> pins,
  }) async {
    applied.add((drop: drop, restore: restore, pins: pins));
  }

  /// Flip the state the bar gates on, as a page's notify would.
  void set({bool? loading, bool? disabled, TasteResponse? seeded}) {
    if (loading != null) this.loading = loading;
    if (disabled != null) this.disabled = disabled;
    if (seeded != null) this.seeded = seeded;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pinPath = '/music/Someone/Pinned.flac';

  /// A history answer with one pinned seed, three finished ones (Manor
  /// last finished in February: "8 months ago" from the host's clock in
  /// any time zone) and one left-out row the answer resolved.
  TasteResponse answer() => parse(mainPayload(
        exclude: ['hx'],
        seeds: [
          seedRow('hp', 'Pinned', 'Someone', pinned: true),
          seedRow('h1', 'Manor', 'ALM',
              plays: 3, lastPlayed: '2026-02-01T12:00:00.000Z'),
          seedRow('h2', 'Roygbiv', 'Boards of Canada'),
          seedRow('h3', 'Xtal', 'Aphex Twin'),
        ],
      ));

  FakeTasteHost host({int window = kTasteDefaultWindow, bool answered = true}) =>
      FakeTasteHost(
        server: discoveryServer(),
        seeded: answered ? answer() : null,
        window: window,
        pins: answered ? const [pinPath] : const [],
      );

  /// The bar alone on a phone-sized screen, redrawn on the host's notify
  /// (Peer Recommendations' view draws it under a ListenableBuilder).
  Future<void> pumpBar(WidgetTester tester, FakeTasteHost h,
      {VoidCallback? onOpenSeeds}) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      home: Scaffold(
        body: ListenableBuilder(
          listenable: h,
          builder: (_, _) =>
              DiscoveryConfigBar(controller: h, onOpenSeeds: onOpenSeeds),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  final windowChooser = find.byKey(const ValueKey('discovery-window'));
  final moreOptions = find.byKey(const ValueKey('discovery-more-options'));
  Finder menuItem(String label) =>
      find.widgetWithText(CheckedPopupMenuItem<int>, label);

  testWidgets("the bar draws the host's window and calls setWindow",
      (tester) async {
    final h = host(window: 90);
    await pumpBar(tester, h);
    expect(tester.takeException(), isNull, reason: 'no overflow at 390 px');
    expect(find.text('Based on the last'), findsOneWidget);
    expect(find.text('90 days'), findsOneWidget,
        reason: "the host's window, not the phone's default");

    await tester.tap(windowChooser);
    await tester.pumpAndSettle();
    await tester.tap(menuItem('7 days'));
    await tester.pumpAndSettle();
    expect(h.windows, [7]);
    expect(find.text('7 days'), findsOneWidget);

    await tester.tap(windowChooser);
    await tester.pumpAndSettle();
    await tester.tap(menuItem('All time'));
    await tester.pumpAndSettle();
    expect(h.windows, [7, 0]);
    expect(find.text('Based on'), findsOneWidget,
        reason: '"Based on the last All time" reads wrong');
    expect(find.text('All time'), findsOneWidget);
    expect(h.applied, isEmpty);
  });

  testWidgets("More options opens the seeds sheet with the host's seeds; "
      'Use these calls applySeeds(drop, restore, pins)', (tester) async {
    final h = host();
    await pumpBar(tester, h);
    await tester.tap(moreOptions);
    await tester.pumpAndSettle();
    expect(find.byType(DiscoverySeedsSheet), findsOneWidget);
    expect(tester.takeException(), isNull);

    // The host's pins, finished seeds and left-out rows, each where the
    // sheet draws it; the clock is the host's.
    expect(find.textContaining('PICKED FOR THIS VISIT', findRichText: true),
        findsOneWidget);
    expect(find.text('Pinned'), findsOneWidget);
    expect(find.text('Manor'), findsOneWidget);
    expect(find.text('ALM · 8 months ago · played 3×'), findsOneWidget);
    expect(find.text('Roygbiv'), findsOneWidget);
    expect(find.text('Xtal'), findsOneWidget);
    expect(find.textContaining('RANDOM PICK', findRichText: true),
        findsNothing);
    expect(find.textContaining('LEFT OUT', findRichText: true),
        findsOneWidget);
    expect(find.text('Left hx'), findsOneWidget);
    expect(find.text('Use these 4'), findsOneWidget);

    // Drop one seed, use a left-out one again: nothing is asked until
    // "Use these N".
    await tester.tap(find.text('Roygbiv'));
    await tester.pump();
    await tester.tap(find.text('Left hx'));
    await tester.pump();
    expect(h.applied, isEmpty);
    await tester.tap(find.text('Use these 4'));
    await tester.pumpAndSettle();

    expect(find.byType(DiscoverySeedsSheet), findsNothing,
        reason: 'the sheet closed');
    expect(h.applied, hasLength(1));
    expect(h.applied.single.drop, {'h2'});
    expect(h.applied.single.restore, {'hx'});
    expect(h.applied.single.pins, [pinPath]);
    expect(h.windows, isEmpty);
  });

  testWidgets('More options calls onOpenSeeds once, before the sheet opens',
      (tester) async {
    final h = host();
    var opened = 0;
    final sheetUpAtCall = <bool>[];
    await pumpBar(tester, h, onOpenSeeds: () {
      opened++;
      sheetUpAtCall.add(find.byType(DiscoverySeedsSheet).evaluate().isNotEmpty);
    });
    expect(opened, 0, reason: 'nothing runs until More options');

    await tester.tap(moreOptions);
    await tester.pumpAndSettle();
    expect(find.byType(DiscoverySeedsSheet), findsOneWidget);
    expect(opened, 1);
    expect(sheetUpAtCall, [false]);

    // Closing the sheet runs nothing; the next opening runs it once more.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(DiscoverySeedsSheet), findsNothing);
    expect(opened, 1);
    await tester.tap(moreOptions);
    await tester.pumpAndSettle();
    expect(opened, 2);
    expect(sheetUpAtCall, [false, false]);
  });

  testWidgets('controls are off while loading or disabled', (tester) async {
    final h = host();
    var opened = 0;
    await pumpBar(tester, h, onOpenSeeds: () => opened++);

    bool chooserOn() =>
        tester.widget<PopupMenuButton<int>>(windowChooser).enabled;
    bool moreOn() => tester.widget<TextButton>(moreOptions).onPressed != null;
    final line = find.byType(LinearProgressIndicator);

    expect(chooserOn(), isTrue);
    expect(moreOn(), isTrue);
    expect(line, findsNothing);

    // Fixed pumps, not pumpAndSettle: the loading line never settles.
    Future<void> triesNothing() async {
      await tester.tap(windowChooser);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('7 days'), findsNothing, reason: 'no window menu');
      await tester.tap(moreOptions, warnIfMissed: false);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(DiscoverySeedsSheet), findsNothing);
      expect(opened, 0);
      expect(h.windows, isEmpty);
    }

    // A call is out, with rows up: both off, and the thin line shows.
    h.set(loading: true);
    await tester.pump();
    expect(chooserOn(), isFalse);
    expect(moreOn(), isFalse);
    expect(line, findsOneWidget);
    await triesNothing();

    // The 403 latch: both off, no line.
    h.set(loading: false, disabled: true);
    await tester.pumpAndSettle();
    expect(chooserOn(), isFalse);
    expect(moreOn(), isFalse);
    expect(line, findsNothing);
    await triesNothing();

    // Back to idle: the bar follows the host's notify.
    h.set(disabled: false);
    await tester.pumpAndSettle();
    expect(chooserOn(), isTrue);
    expect(moreOn(), isTrue);
  });

  testWidgets('More options is off before the host has an answer; the '
      'window is not', (tester) async {
    final h = host(answered: false);
    await pumpBar(tester, h);
    expect(tester.widget<PopupMenuButton<int>>(windowChooser).enabled, isTrue);
    expect(tester.widget<TextButton>(moreOptions).onPressed, isNull);
    expect(find.byType(LinearProgressIndicator), findsNothing,
        reason: 'the first call shows no line: there are no rows yet');
    h.set(loading: true);
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);

    h.set(loading: false, seeded: answer());
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(moreOptions).onPressed, isNotNull);
  });

  testWidgets("the thin line follows answerShown, not the host's seeds",
      (tester) async {
    // Peer Recommendations lets go of its batch as a new one is asked,
    // while the old leads stay on screen: the line must still show.
    final h = host(answered: false)..shownOverride = true;
    await pumpBar(tester, h);
    final line = find.byType(LinearProgressIndicator);
    h.set(loading: true);
    await tester.pump();
    expect(h.seeded, isNull);
    expect(line, findsOneWidget, reason: 'an answer is up: the line shows');
    expect(tester.widget<TextButton>(moreOptions).onPressed, isNull,
        reason: 'no seeds: More options stays off');

    // Seeds but nothing on screen: no line.
    h
      ..shownOverride = false
      ..set(seeded: answer());
    await tester.pump();
    expect(line, findsNothing);

    h.set(loading: false);
    await tester.pumpAndSettle();
    expect(line, findsNothing);
  });
}
