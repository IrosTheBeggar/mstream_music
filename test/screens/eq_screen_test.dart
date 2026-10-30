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
