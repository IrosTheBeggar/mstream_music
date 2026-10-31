// The Auto DJ screen's sheets (screens/auto_dj_sheets.dart), one per row, in
// one chrome: the title with its value beside it and any switch, close, then
// Clear | Done. Only Done applies; closing any other way changes nothing.
// First song is the exception: a tap applies it.
//
// Only the paths that never reach MediaManager().audioHandler are driven
// here (a VM test has no audio service): Sonic's and Play from's Done, and
// Rating's and Genres' Done after an edit, poke the handler.
//
// The setters save auto_dj.json through path_provider — real file IO, which
// never finishes on the fake clock — so a tap that saves runs under
// runAsync and waits for the sheet to close.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoTimerPicker;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/l10n/app_localizations.dart';
import 'package:mstream_music/media/audio_stuff.dart' show FanOutSitOut;
import 'package:mstream_music/objects/genre_source.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/auto_dj_sheets.dart';
import 'package:mstream_music/singletons/api.dart';
import 'package:mstream_music/singletons/auto_dj_manager.dart';
import 'package:mstream_music/util/server_tree.dart' show kPeerBranch;
import 'package:mstream_music/widgets/federation_widgets.dart' show FedCheckRow;
import 'package:mstream_music/widgets/star_rating.dart';

/// Counts the routes popped, which a saving tap only does once its save
/// has landed.
class _Pops extends NavigatorObserver {
  int count = 0;
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => count++;
}

final _sheetValue = find.byKey(const ValueKey('auto-dj-sheet-value'));
final _clear = find.byKey(const ValueKey('auto-dj-sheet-clear'));
final _done = find.byKey(const ValueKey('auto-dj-sheet-done'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mgr = AutoDJManager();
  late Directory scratch;
  late _Pops pops;

  setUpAll(() {
    scratch = Directory.systemTemp.createTempSync('mstream-auto-dj-sheets-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => scratch.path);
  });
  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
    try {
      scratch.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() {
    pops = _Pops();
    mgr
      ..emptyQueueStart = EmptyQueueStart.ask
      ..songsPerFetch = AutoDJManager.defaultSongsPerFetch
      ..bpmContinuityEnabled = false
      ..bpmTolerance = 8
      ..durationFilterEnabled = false
      ..minDurationSec = 120
      ..maxDurationSec = AutoDJManager.durationCeilSec
      ..allowUnknownDuration = false
      ..keywordFilterEnabled = false
      ..keywordFilterWords = []
      ..sonicSimilarityEnabled = true
      ..sonicMinSimilarity = 0.55
      ..sonicAnchorMode = SonicAnchorMode.rolling;
  });

  /// A page whose button opens [sheet] in the Auto DJ chrome. A sheet
  /// showing a spinner never settles: [settle] false pumps it open instead.
  Future<void> open(WidgetTester tester, WidgetBuilder sheet,
      {Locale? locale, double textScale = 1, bool settle = true}) async {
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      navigatorObservers: [pops],
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAutoDjSheet<void>(context, sheet),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }
  }

  /// Taps [target], whose handler saves and then closes the sheet: the save
  /// is real IO, so it runs off the fake clock until the sheet pops.
  Future<void> tapAndSave(WidgetTester tester, Finder target) async {
    final before = pops.count;
    await tester.runAsync(() async {
      await tester.tap(target);
      for (var i = 0; i < 400 && pops.count == before; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    expect(pops.count, before + 1, reason: 'the sheet closed after its save');
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
  }

  String? value(WidgetTester tester) => tester.widget<Text>(_sheetValue).data;
  Color? valueColor(WidgetTester tester) =>
      tester.widget<Text>(_sheetValue).style?.color;

  bool clearOn(WidgetTester tester) => tester
      .widget<InkWell>(
          find.descendant(of: _clear, matching: find.byType(InkWell)))
      .onTap != null;

  Switch switchIn(WidgetTester tester, Finder f) => tester.widget<Switch>(
      find.descendant(of: f, matching: find.byType(Switch)).first);

  /// True when [a] sits on the same line as [b] — the title row.
  bool sameRow(WidgetTester tester, Finder a, Finder b) =>
      (tester.getCenter(a).dy - tester.getCenter(b).dy).abs() < 2;

  // ── pure labels ─────────────────────────────────────────────────────

  group('labels', () {
    final l = lookupAppLocalizations(const Locale('en'));

    test('autoDjLengthValue: the ends mean no limit', () {
      const ceil = AutoDJManager.durationCeilSec;
      expect(autoDjLengthValue(l, 0, ceil), 'Any');
      expect(autoDjLengthValue(l, 120, ceil), '2:00+');
      expect(autoDjLengthValue(l, 0, 360), 'Under 6:00');
      expect(autoDjLengthValue(l, 120, 360), '2:00–6:00');
      expect(autoDjLengthValue(l, 15, ceil - 1), '0:15–23:59:59');
    });

    test('autoDjServerName: no scheme, no trailing slash; a peer by name',
        () {
      expect(
          autoDjServerName(
              Server('https://music.home.arpa', 'u', 'p', 'JWT', 'a')),
          'music.home.arpa');
      expect(
          autoDjServerName(
              Server('http://laptop.local:3000/', 'u', 'p', 'JWT', 'b')),
          'laptop.local:3000');
      final peer = Server('federated://home/3', null, null, null, 'peer-3')
        ..federationParent = 'home'
        ..federationPeerId = 3
        ..federationPeerName = 'Basement';
      expect(autoDjServerName(peer), 'Basement');
    });

    test('sitOutLabel: a short reason for every way to sit out', () {
      expect(sitOutLabel(l, FanOutSitOut.discoveryOff), 'Discovery off');
      expect(sitOutLabel(l, FanOutSitOut.scanning), 'Still scanning');
      expect(sitOutLabel(l, FanOutSitOut.olderServer), 'Needs server 6.26+');
      expect(sitOutLabel(l, FanOutSitOut.noMood), 'No mood data');
      expect(sitOutLabel(l, FanOutSitOut.otherModel), 'Different audio model');
      expect(sitOutLabel(l, FanOutSitOut.unreachable), 'Unreachable');
      for (final why in FanOutSitOut.values) {
        expect(sitOutLabel(l, why).split(' ').length, lessThanOrEqualTo(4),
            reason: why.name);
      }
    });
  });

  // ── First song ──────────────────────────────────────────────────────

  group('FirstSongSheet', () {
    Finder row(EmptyQueueStart v) =>
        find.byKey(ValueKey('auto-dj-first-song-${v.name}'));
    bool checked(EmptyQueueStart v) => find
        .descendant(of: row(v), matching: find.byIcon(Icons.check))
        .evaluate()
        .isNotEmpty;

    testWidgets('three choices, the stored one checked, no buttons',
        (tester) async {
      await open(tester, (_) => const FirstSongSheet());
      expect(find.text('First song'), findsOneWidget);
      expect(find.text('Ask'), findsOneWidget);
      expect(find.text('Random'), findsOneWidget);
      expect(find.text('Choose'), findsOneWidget);
      expect(checked(EmptyQueueStart.ask), isTrue);
      expect(checked(EmptyQueueStart.random), isFalse);
      expect(checked(EmptyQueueStart.pick), isFalse);
      expect(_done, findsNothing, reason: 'a tap applies');
      expect(_clear, findsNothing);
      expect(_sheetValue, findsNothing);
    });

    testWidgets('a tap applies it and closes; reopened, it is checked',
        (tester) async {
      await open(tester, (_) => const FirstSongSheet());
      await tapAndSave(tester, row(EmptyQueueStart.random));
      expect(find.text('First song'), findsNothing);
      expect(mgr.emptyQueueStart, EmptyQueueStart.random);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(checked(EmptyQueueStart.random), isTrue);
      expect(checked(EmptyQueueStart.ask), isFalse);

      await tapAndSave(tester, row(EmptyQueueStart.pick));
      expect(mgr.emptyQueueStart, EmptyQueueStart.pick);
    });

    testWidgets('closing changes nothing', (tester) async {
      mgr.emptyQueueStart = EmptyQueueStart.pick;
      await open(tester, (_) => const FirstSongSheet());
      expect(checked(EmptyQueueStart.pick), isTrue);
      await close(tester);
      expect(find.text('First song'), findsNothing);
      expect(mgr.emptyQueueStart, EmptyQueueStart.pick);
    });
  });

  // ── Batch ───────────────────────────────────────────────────────────

  group('BatchSheet', () {
    final slider = find.byKey(const ValueKey('auto-dj-batch-slider'));

    testWidgets('the value follows the slider; Done applies it',
        (tester) async {
      await open(tester, (_) => const BatchSheet());
      expect(find.text('Batch'), findsOneWidget);
      expect(value(tester), '4 songs');
      expect(_clear, findsNothing, reason: 'nothing to clear');

      await tester.drag(slider, const Offset(-2000, 0));
      await tester.pumpAndSettle();
      expect(value(tester), '1 song');
      await tester.drag(slider, const Offset(2000, 0));
      await tester.pumpAndSettle();
      expect(value(tester), '25 songs');
      expect(mgr.songsPerFetch, 4, reason: 'nothing applies before Done');

      await tapAndSave(tester, _done);
      expect(mgr.songsPerFetch, AutoDJManager.maxSongsPerFetch);
    });

    testWidgets('closing discards the draft', (tester) async {
      await open(tester, (_) => const BatchSheet());
      await tester.drag(slider, const Offset(-2000, 0));
      await tester.pumpAndSettle();
      await close(tester);
      expect(mgr.songsPerFetch, 4);
    });
  });

  // ── Tempo ───────────────────────────────────────────────────────────

  group('TempoSheet', () {
    final toggle = find.byKey(const ValueKey('auto-dj-tempo-switch'));
    final slider = find.byKey(const ValueKey('auto-dj-tempo-slider'));
    bool sliderOn(WidgetTester tester) =>
        tester.widget<Slider>(slider).onChanged != null;

    testWidgets('off: the switch in the title row, "Off", the slider '
        'resting', (tester) async {
      await open(tester, (_) => const TempoSheet());
      expect(find.text('Beat matching'), findsOneWidget);
      expect(tester.widget<Switch>(toggle).value, isFalse);
      expect(sameRow(tester, toggle, find.text('Beat matching')), isTrue);
      expect(sameRow(tester, _sheetValue, find.text('Beat matching')), isTrue);
      expect(value(tester), 'Off');
      expect(sliderOn(tester), isFalse);
      expect(find.text('Off'), findsOneWidget,
          reason: 'one neutral word, no Off stop on the slider');
    });

    testWidgets('switched on, the value reads the tolerance; Done applies',
        (tester) async {
      await open(tester, (_) => const TempoSheet());
      final offColor = valueColor(tester);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(value(tester), '± 8 BPM');
      expect(valueColor(tester), isNot(offColor), reason: 'amber while on');
      expect(sliderOn(tester), isTrue);

      await tester.drag(slider, const Offset(2000, 0));
      await tester.pumpAndSettle();
      expect(value(tester), '± 20 BPM',
          reason: 'right is wider: the scale is not reversed');
      await tester.drag(slider, const Offset(-2000, 0));
      await tester.pumpAndSettle();
      expect(value(tester), '± 1 BPM');
      expect(mgr.bpmContinuityEnabled, isFalse);

      await tapAndSave(tester, _done);
      expect(mgr.bpmContinuityEnabled, isTrue);
      expect(mgr.bpmTolerance, 1);
    });

    testWidgets('switching it off keeps the tolerance; Done applies off',
        (tester) async {
      mgr
        ..bpmContinuityEnabled = true
        ..bpmTolerance = 12;
      await open(tester, (_) => const TempoSheet());
      expect(value(tester), '± 12 BPM');
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(value(tester), 'Off');
      await tapAndSave(tester, _done);
      expect(mgr.bpmContinuityEnabled, isFalse);
      expect(mgr.bpmTolerance, 12);
    });

    testWidgets('Done closes the sheet even when the save fails',
        (tester) async {
      // auto_dj.json cannot be written (no documents folder, a full disk):
      // the setting has already applied in memory, so Done should still
      // close the sheet rather than leave it open with nothing said.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              (_) async => throw PlatformException(code: 'unavailable'));
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              (_) async => scratch.path));
      await open(tester, (_) => const TempoSheet());
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tapAndSave(tester, _done);
      expect(mgr.bpmContinuityEnabled, isTrue, reason: 'applied in memory');
      expect(find.text('Beat matching'), findsNothing, reason: 'closed all the same');
    });

    testWidgets('closing discards the draft', (tester) async {
      await open(tester, (_) => const TempoSheet());
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.drag(slider, const Offset(2000, 0));
      await tester.pumpAndSettle();
      await close(tester);
      expect(find.text('Beat matching'), findsNothing);
      expect(mgr.bpmContinuityEnabled, isFalse);
      expect(mgr.bpmTolerance, 8);
    });
  });

  // ── Sonic similarity (its Done reaches the audio handler) ───────────

  group('SonicSheet', () {
    final toggle = find.byKey(const ValueKey('auto-dj-sonic-switch'));
    final slider = find.byKey(const ValueKey('auto-dj-sonic-slider'));

    testWidgets('the switch in the title row; the value is the match or Off',
        (tester) async {
      await open(tester, (_) => const SonicSheet());
      expect(find.text('Sonic similarity'), findsOneWidget);
      expect(sameRow(tester, toggle, find.text('Sonic similarity')), isTrue);
      expect(tester.widget<Switch>(toggle).value, isTrue);
      expect(value(tester), '55%');
      expect(tester.widget<Slider>(slider).onChanged, isNotNull);

      await tester.drag(slider, const Offset(2000, 0));
      await tester.pumpAndSettle();
      expect(value(tester), '80%');
      await tester.drag(slider, const Offset(-2000, 0));
      await tester.pumpAndSettle();
      expect(value(tester), '30%');

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(value(tester), 'Off');
      expect(tester.widget<Slider>(slider).onChanged, isNull);
      expect(
          tester
              .widget<SegmentedButton<SonicAnchorMode>>(
                  find.byKey(const ValueKey('auto-dj-sonic-anchor')))
              .onSelectionChanged,
          isNull);
    });

    testWidgets('closing discards the draft', (tester) async {
      await open(tester, (_) => const SonicSheet());
      await tester.tap(find.text('Stay close'));
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await close(tester);
      expect(mgr.sonicSimilarityEnabled, isTrue);
      expect(mgr.sonicMinSimilarity, 0.55);
      expect(mgr.sonicAnchorMode, SonicAnchorMode.rolling);
    });
  });

  // ── Length ──────────────────────────────────────────────────────────

  group('LengthSheet', () {
    final unknown = find.byKey(const ValueKey('auto-dj-length-unknown'));
    final shortest = find.byKey(const ValueKey('auto-dj-length-shortest'));
    final longest = find.byKey(const ValueKey('auto-dj-length-longest'));
    final wheel = find.byType(CupertinoTimerPicker);
    const ceil = AutoDJManager.durationCeilSec;

    String? rowValue(WidgetTester tester, Finder row) => tester
        .widgetList<Text>(find.descendant(of: row, matching: find.byType(Text)))
        .last
        .data;
    Duration wheelAt(WidgetTester tester) =>
        tester.widget<CupertinoTimerPicker>(wheel).initialTimerDuration;
    // The wheel's own scrolling is Flutter's; what the sheet does with the
    // length it reports is this sheet's.
    Future<void> turn(WidgetTester tester, Duration d) async {
      tester.widget<CupertinoTimerPicker>(wheel).onTimerDurationChanged(d);
      await tester.pumpAndSettle();
    }

    testWidgets('at rest: Any on both rows, no wheel, Include unknown off and '
        'resting, Clear off', (tester) async {
      await open(tester, (_) => const LengthSheet());
      expect(find.text('Length'), findsOneWidget);
      expect(value(tester), 'Any');
      expect(rowValue(tester, shortest), 'Any');
      expect(rowValue(tester, longest), 'Any');
      expect(wheel, findsNothing);
      expect(switchIn(tester, unknown).value, isFalse);
      expect(switchIn(tester, unknown).onChanged, isNull);
      expect(clearOn(tester), isFalse);
      expect(find.text('Include unknown'), findsOneWidget,
          reason: 'always drawn, so nothing jumps');
    });

    testWidgets('a stored window that is switched off opens at Any',
        (tester) async {
      mgr
        ..durationFilterEnabled = false
        ..minDurationSec = 120
        ..maxDurationSec = 360
        ..allowUnknownDuration = true;
      await open(tester, (_) => const LengthSheet());
      expect(value(tester), 'Any');
      expect(rowValue(tester, shortest), 'Any');
      expect(switchIn(tester, unknown).value, isFalse);
    });

    testWidgets('a window: its value and rows, Include unknown live; Clear '
        'goes back to Any and Done applies the filter off', (tester) async {
      mgr
        ..durationFilterEnabled = true
        ..minDurationSec = 120
        ..maxDurationSec = 360
        ..allowUnknownDuration = true;
      await open(tester, (_) => const LengthSheet());
      expect(value(tester), '2:00–6:00');
      expect(rowValue(tester, shortest), '2:00');
      expect(rowValue(tester, longest), '6:00');
      expect(switchIn(tester, unknown).value, isTrue);
      expect(switchIn(tester, unknown).onChanged, isNotNull);
      expect(clearOn(tester), isTrue);

      await tester.tap(_clear);
      await tester.pumpAndSettle();
      expect(value(tester), 'Any');
      expect(rowValue(tester, shortest), 'Any');
      expect(rowValue(tester, longest), 'Any');
      expect(switchIn(tester, unknown).value, isFalse);
      expect(switchIn(tester, unknown).onChanged, isNull);
      expect(clearOn(tester), isFalse);
      expect(mgr.durationFilterEnabled, isTrue, reason: 'not before Done');

      await tapAndSave(tester, _done);
      expect(mgr.durationFilterEnabled, isFalse);
      expect(mgr.minDurationSec, AutoDJManager.durationFloorSec);
      expect(mgr.maxDurationSec, ceil);
      expect(mgr.allowUnknownDuration, isFalse);
    });

    testWidgets('a row opens its wheel on its own value, one at a time; '
        'tapping it again closes it', (tester) async {
      mgr
        ..durationFilterEnabled = true
        ..minDurationSec = 120
        ..maxDurationSec = 360;
      await open(tester, (_) => const LengthSheet());
      await tester.tap(shortest);
      await tester.pumpAndSettle();
      expect(wheel, findsOneWidget);
      expect(wheelAt(tester), const Duration(minutes: 2));
      await tester.tap(longest);
      await tester.pumpAndSettle();
      expect(wheel, findsOneWidget);
      expect(wheelAt(tester), const Duration(minutes: 6));
      await tester.tap(longest);
      await tester.pumpAndSettle();
      expect(wheel, findsNothing);
    });

    testWidgets('to the second: the shortest wheel sets a minimum; Include '
        'unknown wakes up and Done applies both', (tester) async {
      await open(tester, (_) => const LengthSheet());
      await tester.tap(shortest);
      await tester.pumpAndSettle();
      await turn(tester, const Duration(minutes: 1, seconds: 37));
      expect(value(tester), '1:37+');
      expect(rowValue(tester, shortest), '1:37');
      expect(switchIn(tester, unknown).onChanged, isNotNull);
      expect(clearOn(tester), isTrue);

      await tester
          .tap(find.descendant(of: unknown, matching: find.byType(Switch)));
      await tester.pumpAndSettle();
      await tapAndSave(tester, _done);
      expect(mgr.durationFilterEnabled, isTrue);
      expect((mgr.minDurationSec, mgr.maxDurationSec), (97, ceil));
      expect(mgr.allowUnknownDuration, isTrue);
    });

    testWidgets('past an hour: the longest wheel sets a maximum, shown as '
        'h:mm:ss', (tester) async {
      await open(tester, (_) => const LengthSheet());
      await tester.tap(longest);
      await tester.pumpAndSettle();
      await turn(tester, const Duration(hours: 1, minutes: 5, seconds: 30));
      expect(value(tester), 'Under 1:05:30');
      expect(rowValue(tester, longest), '1:05:30');
      await tapAndSave(tester, _done);
      expect(mgr.activeDurationBounds, (min: null, max: 3930));
    });

    testWidgets('back to 0:00:00 is no limit on that side', (tester) async {
      mgr
        ..durationFilterEnabled = true
        ..minDurationSec = 120
        ..maxDurationSec = 360;
      await open(tester, (_) => const LengthSheet());
      await tester.tap(longest);
      await tester.pumpAndSettle();
      await turn(tester, Duration.zero);
      expect(rowValue(tester, longest), 'Any');
      expect(value(tester), '2:00+');
    });

    testWidgets('a shortest past the longest: the pair is kept in order',
        (tester) async {
      mgr
        ..durationFilterEnabled = true
        ..minDurationSec = 120
        ..maxDurationSec = 300;
      await open(tester, (_) => const LengthSheet());
      await tester.tap(shortest);
      await tester.pumpAndSettle();
      await turn(tester, const Duration(minutes: 6));
      expect(value(tester), '5:00–6:00');
      await tapAndSave(tester, _done);
      expect((mgr.minDurationSec, mgr.maxDurationSec), (300, 360));
    });

    testWidgets('Clear sets an open wheel back to zero', (tester) async {
      mgr
        ..durationFilterEnabled = true
        ..minDurationSec = 120
        ..maxDurationSec = ceil;
      await open(tester, (_) => const LengthSheet());
      await tester.tap(shortest);
      await tester.pumpAndSettle();
      expect(wheelAt(tester), const Duration(minutes: 2));
      final before = tester.state(wheel);
      await tester.tap(_clear);
      await tester.pumpAndSettle();
      // A wheel takes its value only when it is built: a new one, not the
      // old one handed zero.
      expect(tester.state(wheel), isNot(same(before)));
      expect(wheelAt(tester), Duration.zero);
    });

    testWidgets("a short hour unit: the wheel's room for it fits no "
        '"Stunden"', (tester) async {
      await open(tester, (_) => const LengthSheet(),
          locale: const Locale('de'));
      await tester.tap(shortest);
      await tester.pumpAndSettle();
      expect(find.text('Std.'), findsWidgets);
      expect(find.text('Stunden'), findsNothing);
      expect(find.text('Min.'), findsWidgets,
          reason: "minutes and seconds keep the language's own");
    });

    testWidgets('an hour-long window at a large text size is cut short, not '
        'overflowing', (tester) async {
      mgr
        ..durationFilterEnabled = true
        ..minDurationSec = 3600
        ..maxDurationSec = 7200;
      await open(tester, (_) => const LengthSheet(),
          locale: const Locale('es'), textScale: 3);
      expect(tester.takeException(), isNull);
      expect(value(tester), '1:00:00–2:00:00');
    });

    testWidgets('closing discards the draft', (tester) async {
      mgr
        ..durationFilterEnabled = true
        ..minDurationSec = 120
        ..maxDurationSec = 360;
      await open(tester, (_) => const LengthSheet());
      await tester.tap(_clear);
      await tester.pumpAndSettle();
      await close(tester);
      expect(mgr.durationFilterEnabled, isTrue);
      expect((mgr.minDurationSec, mgr.maxDurationSec), (120, 360));
    });
  });

  // ── Skip words ──────────────────────────────────────────────────────

  group('SkipWordsSheet', () {
    final field = find.byKey(const ValueKey('auto-dj-skip-words-field'));
    final add = find.byKey(const ValueKey('auto-dj-skip-words-add'));
    Finder chip(String w) => find.byKey(ValueKey('auto-dj-skip-word-$w'));
    bool addOn(WidgetTester tester) =>
        tester.widget<IconButton>(add).onPressed != null;
    int chips() => find.byType(InputChip).evaluate().length;

    testWidgets('a word typed but not yet added counts on Done',
        (tester) async {
      await open(tester, (_) => const SkipWordsSheet());
      await tester.enterText(field, 'remix');
      await tester.pump();
      await tapAndSave(tester, _done);
      expect(mgr.keywordFilterWords, ['remix']);
      expect(mgr.keywordFilterEnabled, isTrue);
    });

    testWidgets('add with + and with the keyboard; a case-insensitive '
        'duplicate is refused', (tester) async {
      await open(tester, (_) => const SkipWordsSheet());
      expect(find.text('Skip words'), findsOneWidget);
      expect(_sheetValue, findsNothing, reason: 'caps show only once reached');
      expect(addOn(tester), isFalse, reason: 'nothing typed');
      expect(clearOn(tester), isFalse);

      await tester.enterText(field, '  Live ');
      await tester.pump();
      expect(addOn(tester), isTrue);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(chip('Live'), findsOneWidget, reason: 'trimmed');
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);

      await tester.enterText(field, 'remix');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(chip('remix'), findsOneWidget);
      expect(chips(), 2);

      await tester.enterText(field, 'LIVE');
      await tester.pump();
      expect(addOn(tester), isFalse);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(chips(), 2);
      expect(chip('LIVE'), findsNothing);

      await tester.enterText(field, '   ');
      await tester.pump();
      expect(addOn(tester), isFalse, reason: 'blank');
      expect(clearOn(tester), isTrue);
      expect(mgr.keywordFilterWords, isEmpty, reason: 'not before Done');
    });

    testWidgets('a chip comes off; Clear empties the list', (tester) async {
      mgr
        ..keywordFilterEnabled = true
        ..keywordFilterWords = ['live', 'remix', 'demo'];
      await open(tester, (_) => const SkipWordsSheet());
      expect(chips(), 3);
      await tester.tap(
          find.descendant(of: chip('remix'), matching: find.byTooltip('Delete')));
      await tester.pumpAndSettle();
      expect(chip('remix'), findsNothing);
      expect(chips(), 2);

      await tester.tap(_clear);
      await tester.pumpAndSettle();
      expect(chips(), 0);
      expect(clearOn(tester), isFalse);
      expect(mgr.keywordFilterWords, ['live', 'remix', 'demo'],
          reason: 'not before Done');
    });

    testWidgets('Done applies the list', (tester) async {
      mgr
        ..keywordFilterEnabled = true
        ..keywordFilterWords = ['live'];
      await open(tester, (_) => const SkipWordsSheet());
      await tester.enterText(field, 'Remix');
      await tester.pump();
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tapAndSave(tester, _done);
      expect(mgr.keywordFilterWords, ['live', 'Remix']);
      expect(mgr.keywordFilterEnabled, isTrue);
    });

    testWidgets('Done on an emptied list is the filter off', (tester) async {
      mgr
        ..keywordFilterEnabled = true
        ..keywordFilterWords = ['live'];
      await open(tester, (_) => const SkipWordsSheet());
      await tester.tap(_clear);
      await tester.pumpAndSettle();
      await tapAndSave(tester, _done);
      expect(mgr.keywordFilterWords, isEmpty);
      expect(mgr.keywordFilterEnabled, isFalse);
    });

    testWidgets('a list that is switched off opens empty', (tester) async {
      mgr
        ..keywordFilterEnabled = false
        ..keywordFilterWords = ['live'];
      await open(tester, (_) => const SkipWordsSheet());
      expect(chips(), 0);
    });

    testWidgets('at the cap: the value says so and the field rests',
        (tester) async {
      mgr
        ..keywordFilterEnabled = true
        ..keywordFilterWords = [
          for (var i = 0; i < AutoDJManager.maxKeywords; i++) 'w$i'
        ];
      await open(tester, (_) => const SkipWordsSheet());
      expect(value(tester), '50 max');
      expect(tester.widget<TextField>(field).enabled, isFalse);
      expect(addOn(tester), isFalse);
    });

    testWidgets('closing discards the draft', (tester) async {
      mgr
        ..keywordFilterEnabled = true
        ..keywordFilterWords = ['live'];
      await open(tester, (_) => const SkipWordsSheet());
      await tester.enterText(field, 'remix');
      await tester.pump();
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(chip('remix'), findsOneWidget);
      await close(tester);
      expect(mgr.keywordFilterWords, ['live']);
    });
  });

  // ── Play from (its Done reaches the handler; the statuses are passed in) ──

  group('PlayFromSheet', () {
    final all = find.byKey(const ValueKey('auto-dj-play-from-all'));
    Finder pick(String name) =>
        find.byKey(ValueKey('auto-dj-play-from-$name'));
    Finder folder(String server, String vpath) =>
        find.byKey(ValueKey('auto-dj-folder-$server-$vpath'));
    bool checked(Finder f) => find
        .descendant(of: f, matching: find.byIcon(Icons.check))
        .evaluate()
        .isNotEmpty;
    bool tappable(WidgetTester tester, Finder f) => tester
        .widget<InkWell>(find.descendant(of: f, matching: find.byType(InkWell)))
        .onTap != null;
    Finder within(Finder row, String text) =>
        find.descendant(of: row, matching: find.text(text));
    bool warned(Finder row) => find
        .descendant(of: row, matching: find.byIcon(Icons.warning_amber_rounded))
        .evaluate()
        .isNotEmpty;

    Server server(String name,
            {bool? discovery = true, Map<String, bool>? paths}) =>
        Server('https://$name.example.com', 'u', 'p', 'JWT', name)
          ..serverVersion = '6.26.0'
          ..discoveryEnabled = discovery
          ..autoDJPaths = paths ?? {'music': true};

    /// The sheet over [servers], [chosen] ticked (the first server if not
    /// given), with the statuses a session would report.
    PlayFromSheet sheet(List<Server> servers,
            {List<Server>? chosen,
            Server? home,
            Map<String, FanOutSitOut> sitOut = const {},
            Set<String> connecting = const {},
            Stream<Object?>? changes}) =>
        PlayFromSheet(
          servers: servers,
          chosen: chosen ?? [servers.first],
          home: home ?? (chosen ?? servers).first,
          sitOut: (s) => sitOut[s.localname],
          connecting: (s) => connecting.contains(s.localname),
          changes: changes,
        );

    setUp(() {
      mgr
        ..playFromAll = false
        ..playFromServers = const []
        ..playFromServer = null
        ..moodFilterEnabled = false;
    });

    testWidgets('the chosen servers ticked; ticking another adds it and shows '
        'its folders', (tester) async {
      final home = server('home');
      final office =
          server('office', paths: {'music': true, 'podcasts': false});
      await open(tester, (_) => sheet([home, office]));
      expect(find.text('Play from'), findsOneWidget);
      expect(find.text('All servers'), findsOneWidget);
      expect(checked(pick('home')), isTrue);
      expect(checked(pick('office')), isFalse);
      expect(checked(all), isFalse);
      expect(folder('office', 'music'), findsNothing,
          reason: "only a ticked server's folders");

      await tester.tap(pick('office'));
      await tester.pumpAndSettle();
      expect(checked(pick('office')), isTrue);
      expect(checked(pick('home')), isTrue, reason: 'one more, not another');
      expect(checked(all), isTrue, reason: 'every server is ticked');
      expect(folder('office', 'music'), findsOneWidget);
      expect(folder('office', 'podcasts'), findsOneWidget);
      expect(folder('home', 'music'), findsNothing,
          reason: 'one folder is nothing to choose');

      await tester.tap(pick('home'));
      await tester.pumpAndSettle();
      expect(checked(pick('home')), isFalse);
      expect(checked(pick('office')), isTrue);
      expect(checked(all), isFalse);
    });

    testWidgets('a set of any size: two of three', (tester) async {
      final home = server('home');
      final office = server('office');
      final lab = server('lab');
      await open(tester,
          (_) => sheet([home, office, lab], chosen: [home, lab]));
      expect(checked(pick('home')), isTrue);
      expect(checked(pick('office')), isFalse);
      expect(checked(pick('lab')), isTrue);
      expect(checked(all), isFalse);
    });

    testWidgets('the last server ticked stays ticked', (tester) async {
      final home = server('home');
      final office = server('office');
      await open(tester, (_) => sheet([home, office]));
      expect(tappable(tester, pick('home')), isFalse);
      expect(tappable(tester, pick('office')), isTrue);

      await tester.tap(pick('office'));
      await tester.pumpAndSettle();
      expect(tappable(tester, pick('home')), isTrue);
      await tester.tap(pick('home'));
      await tester.pumpAndSettle();
      expect(checked(pick('home')), isFalse);
      expect(tappable(tester, pick('office')), isFalse,
          reason: 'now the one left');
    });

    testWidgets('All servers ticks every one; again, it goes back to the '
        'home alone', (tester) async {
      final home = server('home');
      final office = server('office');
      final lab = server('lab');
      await open(tester,
          (_) => sheet([home, office, lab], chosen: [office], home: office));
      await tester.tap(all);
      await tester.pumpAndSettle();
      for (final n in ['home', 'office', 'lab']) {
        expect(checked(pick(n)), isTrue, reason: n);
      }
      expect(checked(all), isTrue);

      await tester.tap(all);
      await tester.pumpAndSettle();
      expect(checked(pick('office')), isTrue, reason: 'the home stays');
      expect(checked(pick('home')), isFalse);
      expect(checked(pick('lab')), isFalse);
      expect(checked(all), isFalse);
    });

    testWidgets('alone, a server says nothing; the others say why they would '
        'sit out, plainly', (tester) async {
      final home = server('home');
      final office = server('office');
      await open(
          tester,
          (_) => sheet([home, office], sitOut: {
                'home': FanOutSitOut.scanning,
                'office': FanOutSitOut.discoveryOff,
              }));
      expect(within(pick('home'), 'Still scanning'), findsNothing,
          reason: 'on its own it needs no discovery');
      expect(within(pick('office'), 'Discovery off'), findsOneWidget);
      expect(warned(pick('office')), isFalse, reason: 'not ticked: no alarm');
    });

    testWidgets('ticked with others, a server that sits out says why in '
        'amber', (tester) async {
      final home = server('home');
      final office = server('office');
      final lab = server('lab');
      await open(
          tester,
          (_) => sheet([home, office, lab],
                  chosen: [home, office, lab],
                  sitOut: {
                    'office': FanOutSitOut.olderServer,
                    'lab': FanOutSitOut.otherModel,
                  }));
      expect(within(pick('home'), 'Needs server 6.26+'), findsNothing);
      expect(warned(pick('home')), isFalse);
      expect(within(pick('office'), 'Needs server 6.26+'), findsOneWidget);
      expect(warned(pick('office')), isTrue);
      expect(warned(pick('lab')), isTrue);

      // Down to one: it needs none of this.
      await tester.tap(pick('home'));
      await tester.tap(pick('lab'));
      await tester.pumpAndSettle();
      expect(within(pick('office'), 'Needs server 6.26+'), findsNothing);
    });

    testWidgets('a server on its way spins while it is ticked with others',
        (tester) async {
      final home = server('home');
      final office = server('office');
      await open(
          tester,
          (_) => sheet([home, office],
              chosen: [home, office], connecting: {'office'}),
          settle: false);
      expect(
          find.descendant(
              of: pick('office'),
              matching: find.byType(CircularProgressIndicator)),
          findsOneWidget);
      expect(
          find.descendant(
              of: pick('home'),
              matching: find.byType(CircularProgressIndicator)),
          findsNothing);

      await tester.tap(pick('home'));
      await tester.pump();
      expect(
          find.descendant(
              of: pick('office'),
              matching: find.byType(CircularProgressIndicator)),
          findsNothing,
          reason: 'alone it is not fanning anything out');
    });

    testWidgets('the rows follow the session while the sheet is open',
        (tester) async {
      final home = server('home');
      final office = server('office');
      final sitOut = <String, FanOutSitOut>{};
      final connecting = {'office'};
      final changes = StreamController<Object?>.broadcast();
      addTearDown(changes.close);
      Finder spinner(String name) => find.descendant(
          of: pick(name), matching: find.byType(CircularProgressIndicator));
      await open(
          tester,
          (_) => sheet([home, office],
              chosen: [home, office],
              sitOut: sitOut,
              connecting: connecting,
              changes: changes.stream),
          settle: false);
      expect(spinner('office'), findsOneWidget);

      // Its tunnel comes up.
      connecting.clear();
      changes.add(null);
      await tester.pump();
      expect(spinner('office'), findsNothing);

      // Its first answer says discovery is off.
      sitOut['office'] = FanOutSitOut.discoveryOff;
      changes.add(null);
      await tester.pump();
      expect(within(pick('office'), 'Discovery off'), findsOneWidget);
      expect(warned(pick('office')), isTrue);
    });

    testWidgets('the last folder on cannot be switched off; closing discards '
        'every draft', (tester) async {
      final home = server('home', paths: {'music': true, 'podcasts': false});
      final office = server('office');
      await open(tester, (_) => sheet([home, office]));
      expect(switchIn(tester, folder('home', 'music')).onChanged, isNull);

      await tester.tap(find.descendant(
          of: folder('home', 'podcasts'), matching: find.byType(Switch)));
      await tester.pumpAndSettle();
      expect(switchIn(tester, folder('home', 'podcasts')).value, isTrue);
      expect(switchIn(tester, folder('home', 'music')).onChanged, isNotNull);
      await tester.tap(find.descendant(
          of: folder('home', 'music'), matching: find.byType(Switch)));
      await tester.pumpAndSettle();
      expect(switchIn(tester, folder('home', 'music')).value, isFalse);
      expect(switchIn(tester, folder('home', 'podcasts')).onChanged, isNull);

      await tester.tap(pick('office'));
      await tester.pumpAndSettle();
      await close(tester);
      expect(home.autoDJPaths, {'music': true, 'podcasts': false});
      expect(mgr.playFromServer, isNull);
      expect(mgr.playFromServers, isEmpty);
      expect(mgr.multiServerEnabled, isFalse);
    });

    testWidgets('one server: no list, just its folders', (tester) async {
      final home = server('home', paths: {'music': true, 'podcasts': true});
      await open(tester, (_) => sheet([home]));
      expect(all, findsNothing);
      expect(pick('home'), findsNothing);
      expect(folder('home', 'music'), findsOneWidget);
      expect(folder('home', 'podcasts'), findsOneWidget);
    });

    testWidgets('a peer hangs off its parent', (tester) async {
      final home = server('home');
      final peer = Server('federated://home/3', null, null, null, 'peer-3')
        ..federationParent = 'home'
        ..federationPeerId = 3
        ..federationPeerName = 'Basement'
        ..autoDJPaths = {'music': true};
      await open(tester, (_) => sheet([home, peer]));
      expect(
          find.descendant(
              of: pick('peer-3'),
              matching: find.text('$kPeerBranch Basement', findRichText: true)),
          findsOneWidget);
    });

    testWidgets('a screen reader hears a checkbox and whether it is ticked',
        (tester) async {
      final handle = tester.ensureSemantics();
      final home = server('home');
      final office = server('office');
      await open(tester, (_) => sheet([home, office]));
      expect(
          tester.getSemantics(pick('home')),
          isSemantics(
              label: 'home.example.com',
              hasCheckedState: true,
              isChecked: true,
              hasEnabledState: true,
              isEnabled: false,
              hasTapAction: false),
          reason: 'the last one ticked holds');
      expect(
          tester.getSemantics(pick('office')),
          isSemantics(
              label: 'office.example.com',
              hasCheckedState: true,
              isChecked: false,
              isEnabled: true,
              hasTapAction: true));
      handle.dispose();
    });
  });

  // ── Rating ──────────────────────────────────────────────────────────

  group('RatingSheet', () {
    final stars = find.byKey(const ValueKey('auto-dj-rating-stars'));
    Finder star(int i) => find
        .descendant(of: stars, matching: find.byType(GestureDetector))
        .at(i);

    Server server(String name, {int? rating}) =>
        Server('https://$name.example.com', 'u', 'p', 'JWT', name)
          ..autoDJminRating = rating;

    testWidgets('one server: stars, the value, Clear; no chips',
        (tester) async {
      final s = server('home');
      await open(tester, (_) => RatingSheet(servers: [s], initial: s));
      expect(find.text('Rating'), findsOneWidget);
      expect(value(tester), 'Any');
      expect(clearOn(tester), isFalse);
      expect(find.byKey(const ValueKey('auto-dj-server-chip-home')),
          findsNothing);

      await tester.tap(star(2));
      await tester.pumpAndSettle();
      expect(value(tester), '3★+');
      expect(tester.widget<StarRating>(stars).rating, 6);
      expect(clearOn(tester), isTrue);

      await tester.tap(star(2));
      await tester.pumpAndSettle();
      expect(value(tester), 'Any', reason: 'the top star again clears it');

      await tester.tap(star(3));
      await tester.pumpAndSettle();
      expect(value(tester), '4★+');
      await tester.tap(_clear);
      await tester.pumpAndSettle();
      expect(value(tester), 'Any');
      expect(tester.widget<StarRating>(stars).rating, isNull);
      expect(s.autoDJminRating, isNull, reason: 'not before Done');
    });

    testWidgets('a half-star minimum reads in halves', (tester) async {
      final s = server('home', rating: 7);
      await open(tester, (_) => RatingSheet(servers: [s], initial: s));
      expect(value(tester), '3.5★+');
    });

    testWidgets('closing discards the draft', (tester) async {
      final s = server('home', rating: 6);
      await open(tester, (_) => RatingSheet(servers: [s], initial: s));
      expect(value(tester), '3★+');
      await tester.tap(star(4));
      await tester.pumpAndSettle();
      expect(value(tester), '5★+');
      await close(tester);
      expect(s.autoDJminRating, 6);
    });

    testWidgets('Done with nothing changed just closes', (tester) async {
      final s = server('home', rating: 6);
      await open(tester, (_) => RatingSheet(servers: [s], initial: s));
      await tester.tap(star(3));
      await tester.pumpAndSettle();
      await tester.tap(star(2));
      await tester.pumpAndSettle();
      expect(value(tester), '3★+');
      await tester.tap(_done);
      await tester.pumpAndSettle();
      expect(find.text('Rating'), findsNothing);
      expect(s.autoDJminRating, 6);
    });

    testWidgets('two servers: chips choose whose rating; a dot marks one set',
        (tester) async {
      final a = server('home', rating: 6);
      final b = server('office');
      await open(tester, (_) => RatingSheet(servers: [a, b], initial: a));
      final chipA = find.byKey(const ValueKey('auto-dj-server-chip-home'));
      final chipB = find.byKey(const ValueKey('auto-dj-server-chip-office'));
      expect(chipA, findsOneWidget);
      expect(chipB, findsOneWidget);
      expect(value(tester), '3★+');

      await tester.tap(chipB);
      await tester.pumpAndSettle();
      expect(value(tester), 'Any');
      await tester.tap(star(4));
      await tester.pumpAndSettle();
      expect(value(tester), '5★+');

      await tester.tap(chipA);
      await tester.pumpAndSettle();
      expect(value(tester), '3★+', reason: 'each server keeps its own draft');

      await close(tester);
      expect(a.autoDJminRating, 6);
      expect(b.autoDJminRating, isNull);
    });
  });

  // ── Genres ──────────────────────────────────────────────────────────

  group('GenresSheet', () {
    // getGenres runs on ApiManager's pooled client; resetDirectClient()
    // inside http.runWithClient makes that pool the mock.
    late Map<String, http.Response Function(String? source)> answers;
    late List<String> asked;
    // The `source` each genre list was asked for, null for both kinds.
    late List<String?> kinds;

    setUp(() {
      asked = [];
      kinds = [];
      answers = {};
      http.runWithClient(
          () => ApiManager().resetDirectClient(),
          () => MockClient((req) async {
                asked.add(req.url.host);
                final answer = answers[req.url.host];
                if (answer == null || req.url.path != '/api/v1/db/genres') {
                  return http.Response('not found', 404);
                }
                final source =
                    (jsonDecode(req.body) as Map)['source'] as String?;
                kinds.add(source);
                return answer(source);
              }));
    });
    tearDown(() => ApiManager().resetDirectClient());

    http.Response genres(List<String> names, {Map<String, int>? sources}) =>
        http.Response(
            jsonEncode({
              'genres': [for (final n in names) {'name': n, 'track_count': 1}],
              'sources': ?sources,
            }),
            200,
            headers: {'content-type': 'application/json'});

    // A server that tells its genres apart (mStream #716): each kind's own
    // list, and how many genres each kind has whatever was asked for.
    http.Response Function(String?) byKind(
            {required List<String> tag, required List<String> model}) =>
        (source) => genres(
            switch (source) {
              'tag' => tag,
              'model' => model,
              _ => {...tag, ...model}.toList(),
            },
            sources: {'tag': tag.length, 'model': model.length});

    Server server(String name,
            {bool enabled = false,
            String mode = 'whitelist',
            List<String> list = const []}) =>
        Server('https://$name.example.com', 'u', 'p', 'JWT', name)
          ..autoDJGenreEnabled = enabled
          ..autoDJGenreMode = mode
          ..autoDJGenres = List.of(list);

    Finder row(String g) => find.byKey(ValueKey('auto-dj-genre-$g'));
    bool on(WidgetTester tester, String g) =>
        tester.widget<FedCheckRow>(row(g)).value;
    // Every row built, the ones scrolled under the header too.
    List<String> order(WidgetTester tester) => [
          for (final e
              in find.byType(FedCheckRow, skipOffstage: false).evaluate())
            ((e.widget as FedCheckRow).key as ValueKey<String>)
                .value
                .replaceFirst('auto-dj-genre-', ''),
        ];
    Set<String> mode(WidgetTester tester) => tester
        .widget<SegmentedButton<String>>(
            find.byKey(const ValueKey('auto-dj-genre-mode')))
        .selected;

    testWidgets('ticking does not reorder the list under the finger',
        (tester) async {
      answers['home.example.com'] = (_) => genres(['Ambient', 'Blues', 'jazz']);
      final s = server('home', enabled: true, list: []);
      await open(tester, (_) => GenresSheet(servers: [s], initial: s));
      expect(order(tester), ['Ambient', 'Blues', 'jazz']);
      await tester.tap(row('jazz'));
      await tester.pumpAndSettle();
      expect(on(tester, 'jazz'), isTrue);
      expect(order(tester), ['Ambient', 'Blues', 'jazz'],
          reason: 'the chosen lead only as of when the list opened');
    });

    testWidgets("the server's list, sorted, the chosen first; search narrows "
        'it', (tester) async {
      answers['home.example.com'] =
          (_) => genres(['rock', 'Ambient', '', 'jazz', 'Blues']);
      final s = server('home', enabled: true, list: ['rock']);
      await open(tester, (_) => GenresSheet(servers: [s], initial: s));
      expect(find.text('Genres'), findsOneWidget);
      expect(_sheetValue, findsNothing, reason: 'caps show only once reached');
      expect(order(tester), ['rock', 'Ambient', 'Blues', 'jazz'],
          reason: 'chosen first, the rest case-insensitively, blanks dropped');
      expect(on(tester, 'rock'), isTrue);
      expect(on(tester, 'jazz'), isFalse);
      expect(mode(tester), {'whitelist'});
      expect(clearOn(tester), isTrue);

      await tester.enterText(
          find.byKey(const ValueKey('auto-dj-genre-search')), 'BL');
      await tester.pumpAndSettle();
      expect(order(tester), ['Blues']);
      await tester.enterText(
          find.byKey(const ValueKey('auto-dj-genre-search')), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No matches'), findsOneWidget);
      expect(asked, ['home.example.com'], reason: 'one fetch');
    });

    testWidgets('ticks, Only | Skip and Clear edit the draft; closing '
        'discards it', (tester) async {
      answers['home.example.com'] = (_) => genres(['Ambient', 'jazz', 'rock']);
      final s = server('home', enabled: true, list: ['rock']);
      await open(tester, (_) => GenresSheet(servers: [s], initial: s));
      await tester.tap(row('jazz'));
      await tester.pumpAndSettle();
      expect(on(tester, 'jazz'), isTrue);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(mode(tester), {'blacklist'});

      await tester.tap(_clear);
      await tester.pumpAndSettle();
      expect(on(tester, 'rock'), isFalse);
      expect(on(tester, 'jazz'), isFalse);
      expect(clearOn(tester), isFalse);

      await close(tester);
      expect(s.autoDJGenres, ['rock']);
      expect(s.autoDJGenreMode, 'whitelist');
      expect(s.autoDJGenreEnabled, isTrue);
    });

    testWidgets('a list switched off opens with nothing chosen',
        (tester) async {
      answers['home.example.com'] = (_) => genres(['jazz', 'rock']);
      final s = server('home', enabled: false, list: ['rock']);
      await open(tester, (_) => GenresSheet(servers: [s], initial: s));
      expect(on(tester, 'rock'), isFalse);
      expect(order(tester), ['jazz', 'rock']);
      expect(clearOn(tester), isFalse);
    });

    testWidgets('a chosen genre the server no longer reports can still be '
        'let go', (tester) async {
      answers['home.example.com'] = (_) => genres(['jazz']);
      final s = server('home', enabled: true, list: ['polka']);
      await open(tester, (_) => GenresSheet(servers: [s], initial: s));
      expect(order(tester), ['polka', 'jazz']);
      expect(on(tester, 'polka'), isTrue);
    });

    testWidgets('no genres, and a failed load', (tester) async {
      answers['home.example.com'] = (_) => genres(const []);
      final s = server('home');
      await open(tester, (_) => GenresSheet(servers: [s], initial: s));
      expect(find.text('No genres'), findsOneWidget);
      await close(tester);

      answers['home.example.com'] = (_) => http.Response('boom', 500);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Could not load genres'), findsOneWidget);
    });

    testWidgets('Done with nothing touched just closes', (tester) async {
      answers['home.example.com'] = (_) => genres(['jazz', 'rock']);
      final s = server('home', enabled: true, list: ['rock']);
      await open(tester, (_) => GenresSheet(servers: [s], initial: s));
      await tester.tap(_done);
      await tester.pumpAndSettle();
      expect(find.text('Genres'), findsNothing);
      expect(s.autoDJGenres, ['rock']);
      expect(s.autoDJGenreEnabled, isTrue);
    });

    testWidgets('at the cap: the value says so and an unchosen genre rests',
        (tester) async {
      answers['home.example.com'] = (_) => genres(['jazz']);
      final s = server('home', enabled: true, list: [
        for (var i = 0; i < AutoDJManager.maxGenres; i++) 'g$i'
      ]);
      await open(tester, (_) => GenresSheet(servers: [s], initial: s));
      expect(value(tester), '200 max');
      await tester.enterText(
          find.byKey(const ValueKey('auto-dj-genre-search')), 'jazz');
      await tester.pumpAndSettle();
      expect(order(tester), ['jazz']);
      expect(tester.widget<FedCheckRow>(row('jazz')).onChanged, isNull);
      await tester.enterText(
          find.byKey(const ValueKey('auto-dj-genre-search')), 'g199');
      await tester.pumpAndSettle();
      expect(tester.widget<FedCheckRow>(row('g199')).onChanged, isNotNull,
          reason: 'a chosen one can still be let go');
    });

    testWidgets("two servers: chips switch whose list, each fetched from its "
        'own server once', (tester) async {
      answers['home.example.com'] = (_) => genres(['jazz', 'rock']);
      answers['office.example.com'] = (_) => genres(['Ambient', 'house']);
      final a = server('home', enabled: true, list: ['rock']);
      final b = server('office', mode: 'blacklist');
      await open(tester, (_) => GenresSheet(servers: [a, b], initial: a));
      expect(order(tester), ['rock', 'jazz']);

      await tester.tap(find.byKey(const ValueKey('auto-dj-server-chip-office')));
      await tester.pumpAndSettle();
      expect(order(tester), ['Ambient', 'house']);
      expect(mode(tester), {'blacklist'});

      await tester.tap(find.byKey(const ValueKey('auto-dj-server-chip-home')));
      await tester.pumpAndSettle();
      expect(order(tester), ['rock', 'jazz']);
      expect(asked, ['home.example.com', 'office.example.com']);
    });

    // ── Generated | Tags | Mixed ──

    final sourceSwitch = find.byKey(const ValueKey('auto-dj-genre-source'));
    Set<GenreSource> kind(WidgetTester tester) =>
        tester.widget<SegmentedButton<GenreSource>>(sourceSwitch).selected;

    testWidgets('Generated | Tags | Mixed: Mixed lists both kinds',
        (tester) async {
      answers['home.example.com'] =
          byKind(tag: ['jazz', 'rock'], model: ['Ambient', 'jazz']);
      final s = server('home');
      await open(tester, (_) => GenresSheet(servers: [s], initial: s));
      expect(sourceSwitch, findsOneWidget);
      expect(kind(tester), {GenreSource.both});
      expect(
          [for (final t in ['Generated', 'Tags', 'Mixed']) find.text(t)],
          everyElement(findsOneWidget));
      expect(order(tester), ['Ambient', 'jazz', 'rock']);
      expect(kinds, [null]);
    });

    testWidgets('a kind re-lists from the server; the ticked genres stay, '
        'and closing keeps the stored kind', (tester) async {
      answers['home.example.com'] =
          byKind(tag: ['jazz', 'rock'], model: ['Ambient', 'house']);
      final s = server('home', enabled: true, list: ['rock']);
      await open(tester, (_) => GenresSheet(servers: [s], initial: s));
      await tester.tap(find.text('Generated'));
      await tester.pumpAndSettle();
      expect(kind(tester), {GenreSource.model});
      expect(order(tester), ['rock', 'Ambient', 'house'],
          reason: 'a chosen tag genre can still be let go');
      expect(on(tester, 'rock'), isTrue);

      await tester.tap(find.text('Tags'));
      await tester.pumpAndSettle();
      expect(order(tester), ['rock', 'jazz']);
      await tester.tap(find.text('Mixed'));
      await tester.pumpAndSettle();
      expect(order(tester), ['rock', 'Ambient', 'house', 'jazz']);
      expect(kinds, [null, 'model', 'tag'], reason: 'each kind fetched once');

      await close(tester);
      expect(s.autoDJGenreSource, GenreSource.both);
    });

    testWidgets('a stored kind opens on its own list', (tester) async {
      answers['home.example.com'] =
          byKind(tag: ['jazz'], model: ['Ambient', 'house']);
      final s = server('home', enabled: true, list: ['house'])
        ..autoDJGenreSource = GenreSource.model;
      await open(tester, (_) => GenresSheet(servers: [s], initial: s));
      expect(kind(tester), {GenreSource.model});
      expect(order(tester), ['house', 'Ambient']);
      expect(kinds, [null, 'model'],
          reason: 'what the server has comes back with the first list');
    });

    testWidgets('no switch where there is no choice, or the server is too '
        'old to filter by kind', (tester) async {
      // A server that can't tell its genres apart lists them all, whatever
      // is stored.
      answers['home.example.com'] = (_) => genres(['jazz', 'Ambient']);
      final old = server('home')..autoDJGenreSource = GenreSource.model;
      await open(tester, (_) => GenresSheet(servers: [old], initial: old));
      expect(sourceSwitch, findsNothing);
      expect(order(tester), ['Ambient', 'jazz']);
      expect(kinds, [null]);
      await close(tester);

      // Only tag genres here: nothing to choose between.
      answers['home.example.com'] = byKind(tag: ['jazz'], model: []);
      final tagsOnly = server('home');
      await open(
          tester, (_) => GenresSheet(servers: [tagsOnly], initial: tagsOnly));
      expect(sourceSwitch, findsNothing);
      await close(tester);

      // Both kinds, but random-songs there predates `genreSource`.
      answers['home.example.com'] = byKind(tag: ['jazz'], model: ['Ambient']);
      final before = server('home')..serverVersion = '6.32.1';
      await open(
          tester, (_) => GenresSheet(servers: [before], initial: before));
      expect(sourceSwitch, findsNothing);
    });

    testWidgets('a genre ticked under one kind stays in view, ticked, under '
        'the next', (tester) async {
      answers['home.example.com'] =
          byKind(tag: ['acid', 'rock'], model: ['Ambient', 'house']);
      final s = server('home');
      await open(tester, (_) => GenresSheet(servers: [s], initial: s));
      await tester.tap(row('acid'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generated'));
      await tester.pumpAndSettle();
      expect(order(tester), ['acid', 'Ambient', 'house']);
      expect(on(tester, 'acid'), isTrue);
      await tester.tap(row('acid'));
      await tester.pumpAndSettle();
      expect(order(tester), ['acid', 'Ambient', 'house'],
          reason: 'let go, it keeps its place');
      expect(on(tester, 'acid'), isFalse);
    });

    testWidgets("a kind whose list fails says so above the genres still "
        "pinned", (tester) async {
      final kinds = byKind(tag: ['rock'], model: ['Ambient']);
      answers['home.example.com'] = (source) =>
          source == 'tag' ? http.Response('boom', 500) : kinds(source);
      final s = server('home');
      await open(tester, (_) => GenresSheet(servers: [s], initial: s));
      await tester.tap(row('Ambient'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generated'));
      await tester.pumpAndSettle();
      await tester.tap(_clear);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tags'));
      await tester.pumpAndSettle();
      expect(find.text('Could not load genres'), findsOneWidget);
      expect(order(tester), ['Ambient'], reason: 'still there to tick again');
      expect(on(tester, 'Ambient'), isFalse);
    });

    testWidgets('a long translation shrinks to one line on a narrow phone',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      answers['home.example.com'] = byKind(tag: ['jazz'], model: ['Ambient']);
      final s = server('home');
      await open(tester, (_) => GenresSheet(servers: [s], initial: s),
          locale: const Locale('ru'));
      expect(find.text('Сгенерированные'), findsOneWidget);
      expect(
          tester.getSize(sourceSwitch).height,
          tester
              .getSize(find.byKey(const ValueKey('auto-dj-genre-mode')))
              .height,
          reason: 'as tall as Only | Skip: no label broke onto a second line');
    });
  });

  group('genre kind rules', () {
    Server at(String? version, [GenreSource kind = GenreSource.model]) =>
        Server('https://h.example.com', 'u', 'p', 'JWT', 'h')
          ..serverVersion = version
          ..autoDJGenreSource = kind;

    test('offered where the server has both kinds and can be asked for one',
        () {
      expect(genreKindOffered(at('6.33.0'), const GenreSources(3, 5)), isTrue);
      expect(genreKindOffered(at(null), const GenreSources(3, 5)), isTrue,
          reason: 'an unknown version is sent the key and learns');
      expect(genreKindOffered(at('6.33.0'), const GenreSources(3, 0)), isFalse);
      expect(genreKindOffered(at('6.33.0'), null), isFalse,
          reason: 'not before the server says what it has');
      expect(genreKindOffered(at('6.32.1'), const GenreSources(3, 5)), isFalse);
    });

    test('sent: the stored kind, or every kind where the key is stripped', () {
      expect(genreKindSent(at('6.33.0')), GenreSource.model);
      expect(genreKindSent(at(null, GenreSource.tag)), GenreSource.tag);
      expect(genreKindSent(at('6.32.1')), GenreSource.both);
    });
  });
}
