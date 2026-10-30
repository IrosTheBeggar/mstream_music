// Widget tests for the EQ screen over a scripted audio side: each status
// renders its message or the sliders, the switch locks when it should, a
// drag moves the band live and saves on release, Reset flattens, and the
// 0 dB guide and axis label land exactly where the sliders put 0 dB.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/screens/eq/eq_controller.dart';
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

  testWidgets('ready: a slider per band, readouts, frequencies, axis, Reset',
      (tester) async {
    await pumpReady(tester);
    expect(find.byType(Slider), findsNWidgets(5));
    for (final f in ['60', '230', '910', '3.6k', '14k']) {
      expect(find.text(f), findsOneWidget, reason: f);
    }
    expect(find.text('Hz'), findsNWidgets(5));
    expect(find.text('0.0'), findsNWidgets(5));
    expect(find.text('+15 dB'), findsOneWidget);
    expect(find.text('0 dB'), findsOneWidget);
    expect(find.text('-15 dB'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    expect(theSwitch(tester).value, isTrue);
  });

  testWidgets('the 0 dB guide and axis label sit where the sliders put 0 dB',
      (tester) async {
    // An asymmetric range, so 0 dB is not simply the middle.
    final p = await pumpReady(tester, params: fakeParams(minDb: -10, maxDb: 20));
    final box = tester.renderObject(find.byType(Slider).first) as RenderBox;
    // The slider's own x axis runs along the screen's vertical, min at the
    // bottom; this is the point its track shape places 0 dB at.
    final local = Offset(
        kEqRailInset + p.zeroFraction * (box.size.width - 2 * kEqRailInset),
        box.size.height / 2);
    final zeroY = box.localToGlobal(local).dy;
    expect(tester.getRect(find.byKey(const Key('eq-zero-line'))).center.dy,
        closeTo(zeroY, 1));
    expect(tester.getCenter(find.text('0 dB')).dy, closeTo(zeroY, 1));
  });

  testWidgets('dragging a band up raises its gain live and saves on release',
      (tester) async {
    final p = await pumpReady(tester);
    final band = p.bands[2] as FakeBand;
    await tester.drag(find.byType(Slider).at(2), const Offset(0, -80));
    await tester.pump();
    expect(band.setCalls, isNotEmpty);
    expect(band.gain, greaterThan(0));
    expect(find.text(formatGain(band.gain)), findsOneWidget);
    expect(audio.saveCount, 1);
    expect(audio.savedGains![2], band.gain);
    expect(audio.savedGains![0], 0);
  });

  testWidgets('Reset flattens every band and saves', (tester) async {
    final p =
        await pumpReady(tester, params: fakeParams(gains: const [3, -2, 0, 5.5, -15]));
    expect(find.text('+3.0'), findsOneWidget);
    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(p.bands.map((b) => b.gain), everyElement(0));
    expect(find.text('0.0'), findsNWidgets(5));
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
    expect(find.text('+5.0'), findsOneWidget);
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
    expect(find.text('0.0'), findsNWidgets(10));
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
