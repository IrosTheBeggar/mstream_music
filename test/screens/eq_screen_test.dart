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
import 'package:mstream_music/screens/eq/eq_presets.dart';
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

  testWidgets('a custom curve: Custom leads the chips, Save appears, saving makes a chip',
      (tester) async {
    await pumpReady(tester, params: fakeParams(gains: const [3, 0, 0, 0, 3]));
    final custom = find.byKey(const ValueKey('eq-preset-custom'));
    final save = find.byKey(const Key('eq-save-preset'));
    expect(custom, findsNothing);
    expect(save, findsNothing);
    await tester.drag(find.byType(Slider).at(2), const Offset(0, -80));
    await tester.pump();
    expect(custom, findsOneWidget);
    expect(tester.widget<ChoiceChip>(custom).selected, isTrue);
    expect(save, findsOneWidget);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Save preset'), findsOneWidget);
    final sheetSave = find.byKey(const Key('eq-preset-sheet-save'));
    expect(tester.widget<FilledButton>(sheetSave).onPressed, isNull,
        reason: 'nothing typed yet');
    await tester.enterText(find.byKey(const Key('eq-preset-name')), ' Car bass ');
    await tester.pump();
    expect(find.text('Save'), findsOneWidget);
    await tester.tap(sheetSave);
    await tester.pumpAndSettle();
    expect(audio.userPresets.single.name, 'Car bass');
    expect(custom, findsNothing);
    expect(save, findsNothing);
    final chip = find.byKey(ValueKey('eq-preset-${audio.userPresets.single.id}'));
    await tester.scrollUntilVisible(chip, 100,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
    expect(find.text('Car bass'), findsOneWidget);
  });

  testWidgets('long-press a saved chip: rename, then delete after confirming',
      (tester) async {
    final p = fakeParams(gains: const [1, 2, 3, 4, 5]);
    audio.userPresets = [
      EqPreset.user(id: 'user:9', name: 'Night', params: p, gains: const [1, 2, 3, 4, 5]),
    ];
    await pumpReady(tester, params: p);
    final chip = find.byKey(const ValueKey('eq-preset-user:9'));
    await tester.scrollUntilVisible(chip, 100,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(chip).selected, isTrue,
        reason: 'the gains are this curve');
    expect(find.byKey(const ValueKey('eq-preset-custom')), findsNothing);
    await tester.longPress(chip);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('eq-preset-menu-rename')));
    await tester.pumpAndSettle();
    expect(find.text('Rename preset'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('eq-preset-name')), 'Late');
    await tester.pump();
    await tester.tap(find.byKey(const Key('eq-preset-sheet-save')));
    await tester.pumpAndSettle();
    expect(audio.userPresets.single.name, 'Late');
    expect(audio.userPresets.single.id, 'user:9');
    expect(find.text('Late'), findsOneWidget);
    expect(find.text('Night'), findsNothing);
    await tester.longPress(chip);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('eq-preset-menu-delete')));
    await tester.pumpAndSettle();
    expect(find.text('Delete “Late”?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('eq-preset-delete-confirm')));
    await tester.pumpAndSettle();
    expect(audio.userPresets, isEmpty);
    expect(chip, findsNothing);
    // The row is still scrolled to where the chip was; the Custom chip leads.
    await tester.drag(find.byType(Scrollable).first, const Offset(2000, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('eq-preset-custom')), findsOneWidget,
        reason: 'the gains spell nothing once the curve is gone');
  });

  testWidgets('a name another saved preset has: blocked on rename, Replace on save',
      (tester) async {
    final p = fakeParams(gains: const [1, 2, 3, 4, 5]);
    audio.userPresets = [
      EqPreset.user(id: 'user:1', name: 'Car', params: p, gains: const [1, 0, 0, 0, 0]),
      EqPreset.user(id: 'user:2', name: 'Home', params: p, gains: const [1, 2, 3, 4, 5]),
    ];
    await pumpReady(tester, params: p);
    final home = find.byKey(const ValueKey('eq-preset-user:2'));
    await tester.scrollUntilVisible(home, 100,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(home);
    await tester.pumpAndSettle();
    await tester.longPress(home);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('eq-preset-menu-rename')));
    await tester.pumpAndSettle();
    final sheetSave = find.byKey(const Key('eq-preset-sheet-save'));
    expect(tester.widget<FilledButton>(sheetSave).onPressed, isNotNull,
        reason: 'its own name is fine');
    await tester.enterText(find.byKey(const Key('eq-preset-name')), 'car');
    await tester.pump();
    expect(tester.widget<FilledButton>(sheetSave).onPressed, isNull);
    expect(find.text('Another saved preset already has this name.'),
        findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    // Now a custom curve saved under "Car": the sheet offers Replace.
    await tester.drag(find.byType(Slider).at(2), const Offset(0, -80));
    await tester.pump();
    await tester.tap(find.byKey(const Key('eq-save-preset')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('eq-preset-name')), 'CAR');
    await tester.pump();
    expect(find.text('Replace'), findsOneWidget);
    await tester.tap(sheetSave);
    await tester.pumpAndSettle();
    expect(audio.userPresets.map((u) => u.name), ['CAR', 'Home']);
    expect(audio.userPresets.first.id, 'user:1', reason: 'replaced in place');
    expect(audio.userPresets.first.curve[2].$2, p.bands[2].gain,
        reason: 'the replaced curve is the one just dragged');
  });

  testWidgets('Hold to compare: a hold fades the panel and bypasses, a release restores',
      (tester) async {
    await pumpReady(tester);
    final compare = find.byKey(const Key('eq-compare'));
    expect(compare, findsOneWidget);
    expect(find.text('Hold to compare'), findsOneWidget);
    expect(find.byKey(const Key('eq-save-preset')), findsNothing);
    final fade = find.byKey(const Key('eq-bypass-fade'));
    expect(tester.widget<AnimatedOpacity>(fade).opacity, 1);
    final gesture = await tester.startGesture(tester.getCenter(compare));
    await tester.pump();
    expect(controller.bypassed, isTrue);
    expect(audio.bypasses, [true]);
    expect(tester.widget<AnimatedOpacity>(fade).opacity, lessThan(1));
    // A long hold is still a hold.
    await tester.pump(const Duration(seconds: 2));
    expect(controller.bypassed, isTrue);
    await gesture.up();
    await tester.pump();
    expect(controller.bypassed, isFalse);
    expect(audio.bypasses, [true, false]);
    expect(tester.widget<AnimatedOpacity>(fade).opacity, 1);
    expect(audio.toggles, isEmpty);
  });

  testWidgets('no Compare on the five-band engine, Save alone on a custom curve',
      (tester) async {
    audio.canBypassInPlace = false;
    await pumpReady(tester, params: fakeParams(gains: const [1, 2, 3, 4, 5]));
    expect(find.byKey(const Key('eq-compare')), findsNothing);
    expect(find.byKey(const Key('eq-save-preset')), findsOneWidget);
  });

  testWidgets('Compare and Save share the row on a custom curve',
      (tester) async {
    await pumpReady(tester, params: fakeParams(gains: const [1, 2, 3, 4, 5]));
    expect(find.byKey(const Key('eq-compare')), findsOneWidget);
    expect(find.byKey(const Key('eq-save-preset')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the options sheet: Prevent clipping and Always show band values',
      (tester) async {
    await pumpReady(tester, params: fakeParams(gains: const [3, 0, 0, 0, 3]));
    expect(find.text('+3.0'), findsNothing, reason: 'readouts off by default');
    await tester.tap(find.byKey(const Key('eq-options')));
    await tester.pumpAndSettle();
    expect(find.text('Equalizer options'), findsOneWidget);
    final limiter = find.byKey(const Key('eq-opt-limiter'));
    final values = find.byKey(const Key('eq-opt-values'));
    expect(tester.widget<SwitchListTile>(limiter).value, isTrue);
    expect(tester.widget<SwitchListTile>(values).value, isFalse);
    await tester.tap(limiter);
    await tester.pumpAndSettle();
    expect(audio.limiterSets, [false]);
    expect(tester.widget<SwitchListTile>(limiter).value, isFalse,
        reason: 'the sheet follows the controller');
    await tester.tap(values);
    await tester.pumpAndSettle();
    expect(audio.showValuesSets, [true]);
    // Close the sheet: the readouts are up over every band.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('+3.0'), findsNWidgets(2));
    expect(find.text('0.0'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('no clipping row on the five-band engine; options reachable while off',
      (tester) async {
    audio.hasLimiter = false;
    await pumpScreen(tester);
    expect(find.byKey(const Key('eq-options')), findsOneWidget,
        reason: 'the sheet is useful before the EQ is on');
    await tester.tap(find.byKey(const Key('eq-options')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('eq-opt-limiter')), findsNothing);
    expect(find.byKey(const Key('eq-opt-values')), findsOneWidget);
  });

  testWidgets('no options button where there is no equalizer', (tester) async {
    audio.supported = false;
    await pumpScreen(tester);
    expect(find.byKey(const Key('eq-options')), findsNothing);
  });
}
