// The EQ controller's state machine against a scripted audio side: which
// status each combination of platform / cast / toggle / unit / player
// activity yields, that a band read outlives neither a rebuild nor the
// controller, the toggle's in-flight and reverted values, reset and save.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/screens/eq/eq_controller.dart';
import 'package:mstream_music/screens/eq/eq_presets.dart';

import 'eq_fakes.dart';

/// Lets the controller's future callbacks (microtasks) run.
Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('formatters', () {
    test('frequency labels', () {
      expect(formatFrequency(60), '60');
      expect(formatFrequency(230), '230');
      expect(formatFrequency(910), '910');
      expect(formatFrequency(1000), '1k');
      expect(formatFrequency(1500), '1.5k');
      expect(formatFrequency(3600), '3.6k');
      expect(formatFrequency(14000), '14k');
      expect(formatFrequency(12500), '12.5k');
    });

    test('gain readouts', () {
      expect(formatGain(3.5), '+3.5');
      expect(formatGain(-3.26), '-3.3');
      expect(formatGain(15), '+15.0');
      expect(formatGain(0), '0.0');
      expect(formatGain(-0.04), '0.0');
      expect(formatGain(0.04), '0.0');
    });

    test('zeroFraction', () {
      expect(fakeParams().zeroFraction, 0.5);
      expect(fakeParams(minDb: -10, maxDb: 20).zeroFraction,
          closeTo(1 / 3, 1e-9));
      expect(fakeParams(minDb: 0, maxDb: 0).zeroFraction, 0.5);
      expect(fakeParams(minDb: 5, maxDb: 10).zeroFraction, 0);
    });
  });

  group('EqController', () {
    late FakeEqAudio audio;
    setUp(() => audio = FakeEqAudio());

    test('not Android: unsupported, no toggle', () {
      audio.supported = false;
      final c = EqController(audio);
      expect(c.status, EqStatus.unsupported);
      expect(c.canToggle, isFalse);
      c.dispose();
    });

    test('casting locks the switch and ignores a flip; ends back on the setting',
        () async {
      audio.casting = true;
      final c = EqController(audio);
      expect(c.status, EqStatus.casting);
      expect(c.canToggle, isFalse);
      await c.setEnabled(true);
      expect(audio.toggles, isEmpty);
      audio.casting = false;
      audio.emitCast();
      await settle();
      expect(c.status, EqStatus.off);
      c.dispose();
    });

    test('off: the hint, switch unlocked', () {
      final c = EqController(audio);
      expect(c.status, EqStatus.off);
      expect(c.enabled, isFalse);
      expect(c.canToggle, isTrue);
      c.dispose();
    });

    test('on with an idle player waits for playback; a load brings the bands',
        () async {
      final unit = FakeUnit();
      audio
        ..enabled = true
        ..unit = unit
        ..playerInactive = true;
      final c = EqController(audio);
      expect(c.status, EqStatus.needsPlayback);
      // Play: the player loads, the native effect comes alive, params land.
      audio.playerInactive = false;
      audio.emitPlayer();
      await settle();
      expect(c.status, EqStatus.loading);
      unit.resolve(fakeParams());
      await settle();
      expect(c.status, EqStatus.ready);
      expect(c.params!.bands, hasLength(5));
      // Read once, the bands stay through an idle spell (gains are recorded
      // and re-applied on the next load).
      audio.playerInactive = true;
      audio.emitPlayer();
      await settle();
      expect(c.status, EqStatus.ready);
      c.dispose();
    });

    test('params that land while the hint shows still count', () async {
      final unit = FakeUnit();
      audio
        ..enabled = true
        ..unit = unit;
      final c = EqController(audio);
      expect(c.status, EqStatus.needsPlayback);
      unit.resolve(fakeParams());
      await settle();
      expect(c.status, EqStatus.ready);
      c.dispose();
    });

    test('an empty band list is its own state', () async {
      final unit = FakeUnit();
      audio
        ..enabled = true
        ..unit = unit;
      final c = EqController(audio);
      unit.resolve(fakeParams(freqs: const []));
      await settle();
      expect(c.status, EqStatus.noBands);
      c.dispose();
    });

    test(
        'an active player that never answers fails after the timeout, '
        'and an idle spell grants a fresh window', () async {
      audio
        ..enabled = true
        ..unit = FakeUnit()
        ..playerInactive = false;
      final c =
          EqController(audio, loadTimeout: const Duration(milliseconds: 20));
      expect(c.status, EqStatus.loading);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(c.status, EqStatus.failed);
      expect(c.failure, isNull);
      audio.playerInactive = true;
      audio.emitPlayer();
      await settle();
      expect(c.status, EqStatus.needsPlayback);
      audio.playerInactive = false;
      audio.emitPlayer();
      await settle();
      expect(c.status, EqStatus.loading);
      c.dispose();
    });

    test('the clock does not run while idle', () async {
      audio
        ..enabled = true
        ..unit = FakeUnit()
        ..playerInactive = true;
      final c =
          EqController(audio, loadTimeout: const Duration(milliseconds: 20));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(c.status, EqStatus.needsPlayback);
      c.dispose();
    });

    test('a thrown read is reported with its text', () async {
      final unit = FakeUnit();
      audio
        ..enabled = true
        ..unit = unit
        ..playerInactive = false;
      final c = EqController(audio);
      unit.fail(StateError('no effect'));
      await settle();
      expect(c.status, EqStatus.failed);
      expect(c.failure, contains('no effect'));
      c.dispose();
    });

    test("a stale unit's answer is dropped once the handler has rebuilt",
        () async {
      final a = FakeUnit();
      audio
        ..enabled = true
        ..unit = a
        ..playerInactive = false;
      final c = EqController(audio);
      final b = FakeUnit();
      audio.unit = b;
      audio.emitPlayer();
      await settle();
      a.resolve(fakeParams(freqs: const [100]));
      await settle();
      expect(c.status, EqStatus.loading, reason: 'a is no longer attached');
      b.resolve(fakeParams(freqs: const [60, 230]));
      await settle();
      expect(c.status, EqStatus.ready);
      expect(c.params!.bands.map((x) => x.centerFrequency), [60, 230]);
      c.dispose();
    });

    test('turning on: busy during the rebuild, then the new unit is read',
        () async {
      final c = EqController(audio);
      audio.toggleGate = Completer<void>();
      final done = c.setEnabled(true);
      expect(c.status, EqStatus.busy);
      expect(c.enabled, isTrue,
          reason: 'the switch shows the requested value in flight');
      expect(c.canToggle, isFalse);
      audio.toggleGate!.complete();
      await done;
      expect(audio.toggles, [true]);
      expect(c.enabled, isTrue);
      expect(c.status, EqStatus.needsPlayback);
      (audio.unit as FakeUnit).resolve(fakeParams());
      await settle();
      expect(c.status, EqStatus.ready);
      // And off again: the bands go with the pipeline.
      await c.setEnabled(false);
      expect(c.status, EqStatus.off);
      expect(c.params, isNull);
      c.dispose();
    });

    test('a failed rebuild snaps the switch back', () async {
      final c = EqController(audio);
      audio.toggleSucceeds = false;
      await c.setEnabled(true);
      expect(audio.toggles, [true]);
      expect(c.enabled, isFalse);
      expect(c.status, EqStatus.off);
      c.dispose();
    });

    test('reset zeroes every band and saves once', () async {
      final unit = FakeUnit();
      audio
        ..enabled = true
        ..unit = unit;
      final c = EqController(audio);
      unit.resolve(fakeParams(gains: const [3, -2, 0, 5.5, -15]));
      await settle();
      await c.resetToFlat();
      expect(c.params!.bands.map((b) => b.gain), everyElement(0));
      expect(audio.savedGains, [0, 0, 0, 0, 0]);
      expect(audio.saveCount, 1);
      c.dispose();
    });

    test('saveGains snapshots the live gains in band order', () async {
      final unit = FakeUnit();
      audio
        ..enabled = true
        ..unit = unit;
      final c = EqController(audio);
      unit.resolve(fakeParams(gains: const [1, 2, 3, 4, 5]));
      await settle();
      await c.params!.bands[1].setGain(-4);
      await c.saveGains();
      expect(audio.savedGains, [1, -4, 3, 4, 5]);
      c.dispose();
    });

    test('presets: the gains name the active one; applying sets and saves',
        () async {
      final unit = FakeUnit();
      audio
        ..enabled = true
        ..unit = unit;
      final c = EqController(audio);
      unit.resolve(fakeParams(gains: const [3, 0, 0, 0, 3]));
      await settle();
      expect(c.activePreset!.id, 'normal', reason: 'the device default');
      await c.applyPreset(kEqPresets.firstWhere((p) => p.id == 'rock'));
      expect(c.gains, [5, 3, -1, 3, 5]);
      expect(c.activePreset!.id, 'rock');
      expect(audio.savedGains, [5, 3, -1, 3, 5]);
      expect(audio.saveCount, 1);
      await c.resetToFlat();
      expect(c.activePreset!.id, 'flat');
      c.dispose();
    });

    test('a band moving by hand deselects the preset and notifies', () async {
      final unit = FakeUnit();
      audio
        ..enabled = true
        ..unit = unit;
      final c = EqController(audio);
      unit.resolve(fakeParams(gains: const [3, 0, 0, 0, 3]));
      await settle();
      var notified = 0;
      c.addListener(() => notified++);
      await c.params!.bands[2].setGain(4);
      await settle();
      expect(c.activePreset, isNull);
      expect(notified, greaterThan(0), reason: 'the chips re-render');
      // Off: the band subscriptions go with the layout.
      await c.setEnabled(false);
      final before = notified;
      await (unit.params.then((p) => p.bands[2].setGain(5)));
      await settle();
      expect(notified, before + 0,
          reason: 'no listener left on the dropped bands, bar the refresh');
      c.dispose();
    });

    test('a late answer after dispose is ignored', () async {
      final unit = FakeUnit();
      audio
        ..enabled = true
        ..unit = unit
        ..playerInactive = false;
      final c = EqController(audio);
      var notified = 0;
      c.addListener(() => notified++);
      c.dispose();
      unit.resolve(fakeParams());
      await settle();
      expect(notified, 0);
    });
  });
}
