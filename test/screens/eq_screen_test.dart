// Widget tests for the EQ screen over a scripted audio side: each status
// renders its message or the sliders, the switch locks when it should, a
// drag moves the band live with a value bubble over the thumb and saves on
// release, the curve under the sliders follows the gains, Reset flattens, and
// the 0 dB guide and axis label land exactly where the sliders put 0 dB.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/screens/eq/eq_controller.dart';
import 'package:mstream_music/screens/eq/eq_curve.dart';
import 'package:mstream_music/screens/eq/eq_screen.dart';

import 'eq_fakes.dart';

void main() {
  late FakeEqAudio audio;
  late EqController controller;
  setUp(() => audio = FakeEqAudio());
  tearDown(() => controller.dispose());

  Future<void> pumpScreen(WidgetTester tester) async {
    controller = EqController(audio);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      home: EqScreen(controller: controller),
    ));
    await tester.pump();
  }

  /// On, player active, bands already read.
  Future<EqParams> pumpReady(WidgetTester tester, {EqParams? params}) async {
    final unit = FakeUnit();
    audio
      ..enabled = true
      ..unit = unit
      ..playerInactive = false;
    final p = params ?? fakeParams();
    unit.resolve(p);
    await pumpScreen(tester);
    await tester.pump();
    return p;
  }

  SwitchListTile theSwitch(WidgetTester tester) =>
      tester.widget<SwitchListTile>(find.byType(SwitchListTile));

  final bubble = find.byKey(const Key('eq-bubble'));

  EqCurvePainter curve(WidgetTester tester) =>
      tester.widget<CustomPaint>(find.byKey(const Key('eq-curve'))).painter!
          as EqCurvePainter;

  /// Screen y of a band's thumb centre, from the slider's own geometry: its
  /// x axis runs along the screen's vertical, min at the bottom, and its
  /// track shape insets the rail by [kEqRailInset] at each end.
  double thumbY(WidgetTester tester, int band, EqParams p, double gain) {
    final box = tester.renderObject(find.byType(Slider).at(band)) as RenderBox;
    final local = Offset(
        kEqRailInset + p.fractionOf(gain) * (box.size.width - 2 * kEqRailInset),
        box.size.height / 2);
    return box.localToGlobal(local).dy;
  }

  testWidgets('off: the switch is off and the body says to turn it on',
      (tester) async {
    await pumpScreen(tester);
    expect(find.text('Turn on the equalizer to adjust the bands.'),
        findsOneWidget);
    expect(theSwitch(tester).value, isFalse);
    expect(theSwitch(tester).onChanged, isNotNull);
    expect(find.text('Reset'), findsNothing);
  });

  testWidgets('casting: the explanation, switch locked', (tester) async {
    audio.casting = true;
    await pumpScreen(tester);
    expect(find.textContaining('unavailable while casting'), findsOneWidget);
    expect(theSwitch(tester).onChanged, isNull);
  });

  testWidgets('on with an idle player: the start-a-song hint, no spinner',
      (tester) async {
    audio
      ..enabled = true
      ..unit = FakeUnit()
      ..playerInactive = true;
    await pumpScreen(tester);
    expect(find.textContaining('Start a song'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(theSwitch(tester).value, isTrue);
  });

  testWidgets('ready: a slider per band, frequencies, the axis, Reset',
      (tester) async {
    await pumpReady(tester);
    expect(find.byType(Slider), findsNWidgets(5));
    for (final f in ['60', '230', '910', '3.6k', '14k']) {
      expect(find.text(f), findsOneWidget, reason: f);
    }
    expect(find.text('Hz'), findsOneWidget);
    expect(find.text('dB'), findsOneWidget);
    expect(find.text('+15'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('-15'), findsOneWidget);
    expect(bubble, findsNothing, reason: 'values show only while dragging');
    expect(curve(tester).gains, [0, 0, 0, 0, 0]);
    expect(curve(tester).active, isNull);
    expect(find.text('Reset'), findsOneWidget);
    expect(theSwitch(tester).value, isTrue);
  });

  testWidgets('the 0 dB guide, the axis and the curve sit where the sliders put 0 dB',
      (tester) async {
    // An asymmetric range, so 0 dB is not simply the middle.
    final p = await pumpReady(tester, params: fakeParams(minDb: -10, maxDb: 20));
    final zeroY = thumbY(tester, 0, p, 0);
    expect(tester.getRect(find.byKey(const Key('eq-zero-line'))).center.dy,
        closeTo(zeroY, 1));
    expect(tester.getCenter(find.text('0')).dy, closeTo(zeroY, 1));
    // The painter's rail is the plot's own frame, which starts at the same
    // y as the sliders' columns.
    final plotTop = tester.getTopLeft(find.byKey(const Key('eq-curve'))).dy;
    expect(plotTop + curve(tester).yFor(0), closeTo(zeroY, 1));
    expect(plotTop + curve(tester).yFor(20), closeTo(thumbY(tester, 0, p, 20), 1));
  });

  testWidgets('dragging a band: live gain, a bubble over the thumb, save on release',
      (tester) async {
    final p = await pumpReady(tester);
    final band = p.bands[2] as FakeBand;
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(Slider).at(2)));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    expect(band.setCalls, isNotEmpty);
    expect(band.gain, greaterThan(0));
    expect(curve(tester).gains[2], band.gain);
    expect(curve(tester).active, 2);
    expect(bubble, findsOneWidget);
    expect(find.descendant(of: bubble, matching: find.text(formatGain(band.gain))),
        findsOneWidget);
    final rect = tester.getRect(bubble);
    expect(rect.center.dx,
        closeTo(tester.getCenter(find.byType(Slider).at(2)).dx, 1));
    expect(rect.bottom, closeTo(thumbY(tester, 2, p, band.gain) - 14, 1));
    expect(audio.saveCount, 0, reason: 'settings are written on release only');
    await gesture.up();
    await tester.pump();
    expect(bubble, findsNothing);
    expect(curve(tester).active, isNull);
    expect(audio.saveCount, 1);
    expect(audio.savedGains![2], band.gain);
    expect(audio.savedGains![0], 0);
  });

  testWidgets('the bubble stays inside the panel at the edge bands',
      (tester) async {
    await pumpReady(tester);
    final plot = tester.getRect(find.byKey(const Key('eq-curve')));
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(Slider).first));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    expect(tester.getRect(bubble).left, greaterThanOrEqualTo(plot.left));
    await gesture.up();
    await tester.pump();
  });

  testWidgets('Reset flattens every band and saves', (tester) async {
    final p =
        await pumpReady(tester, params: fakeParams(gains: const [3, -2, 0, 5.5, -15]));
    expect(curve(tester).gains, [3, -2, 0, 5.5, -15]);
    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(p.bands.map((b) => b.gain), everyElement(0));
    expect(curve(tester).gains, [0, 0, 0, 0, 0]);
    expect(audio.savedGains, [0, 0, 0, 0, 0]);
  });

  testWidgets('flipping the switch on: spinner while rebuilding, then bands',
      (tester) async {
    await pumpScreen(tester);
    audio.toggleGate = Completer<void>();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    expect(audio.toggles, [true]);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(theSwitch(tester).value, isTrue);
    expect(theSwitch(tester).onChanged, isNull, reason: 'locked mid-toggle');
    audio.playerInactive = false;
    audio.toggleGate!.complete();
    await tester.pump();
    (audio.unit as FakeUnit).resolve(fakeParams());
    await tester.pump();
    expect(find.byType(Slider), findsNWidgets(5));
    expect(theSwitch(tester).onChanged, isNotNull);
  });

  testWidgets('preset chips: the device default is Normal, a tap applies',
      (tester) async {
    final p = await pumpReady(tester, params: fakeParams(gains: const [3, 0, 0, 0, 3]));
    expect(find.byType(ChoiceChip), findsWidgets);
    ChoiceChip chip(String id) =>
        tester.widget<ChoiceChip>(find.byKey(ValueKey('eq-preset-$id')));
    expect(chip('normal').selected, isTrue);
    expect(chip('flat').selected, isFalse);
    expect(find.text('Heavy Metal'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('eq-preset-classical')));
    await tester.pump();
    expect(p.bands.map((b) => b.gain), [5, 3, -2, 4, 4]);
    expect(chip('classical').selected, isTrue);
    expect(chip('normal').selected, isFalse);
    expect(curve(tester).gains, [5, 3, -2, 4, 4]);
    expect(audio.savedGains, [5, 3, -2, 4, 4]);
  });

  testWidgets('a drag deselects the preset; Reset selects Flat',
      (tester) async {
    await pumpReady(tester, params: fakeParams(gains: const [3, 0, 0, 0, 3]));
    ChoiceChip chip(String id) =>
        tester.widget<ChoiceChip>(find.byKey(ValueKey('eq-preset-$id')));
    expect(chip('normal').selected, isTrue);
    await tester.drag(find.byType(Slider).at(2), const Offset(0, -80));
    await tester.pump();
    expect(chip('normal').selected, isFalse);
    expect(chip('flat').selected, isFalse);
    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(chip('flat').selected, isTrue);
  });

  testWidgets('no preset row while the EQ is off', (tester) async {
    await pumpScreen(tester);
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('ten bands fit: every slider and label, no overflow',
      (tester) async {
    await pumpReady(tester,
        params: fakeParams(freqs: const [
          31.25, 62.5, 125, 250, 500, 1000, 2000, 4000, 8000, 16000,
        ]));
    expect(find.byType(Slider), findsNWidgets(10));
    for (final f in ['31', '63', '125', '250', '500', '1k', '2k', '4k', '8k', '16k']) {
      expect(find.text(f), findsOneWidget, reason: f);
    }
    expect(curve(tester).gains, hasLength(10));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed read shows the error text', (tester) async {
    final unit = FakeUnit();
    audio
      ..enabled = true
      ..unit = unit
      ..playerInactive = false;
    unit.fail(StateError('no effect'));
    await pumpScreen(tester);
    await tester.pump();
    expect(find.textContaining('Could not initialize equalizer'), findsOneWidget);
    expect(find.textContaining('no effect'), findsOneWidget);
    expect(find.text('Reset'), findsNothing);
  });
}
