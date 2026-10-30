// The ten-band engine over a scripted native port: it attaches exactly when
// it has both a session and the on flag, follows the session id across
// rebuilds, carries gains set before an attach into it, pushes later ones
// to the live effect, clamps, and survives a platform refusal.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/dynamics_equalizer.dart';

class FakePort implements DynamicsEqPort {
  final List<String> calls = [];
  List<double>? attachedGains;
  List<double>? attachedCutoffs;
  int? attachedSession;
  bool? attachedEnabled;
  bool attachFails = false;

  @override
  Future<void> attach(
      {required int sessionId,
      required List<double> cutoffsHz,
      required List<double> gainsDb,
      required bool enabled}) async {
    if (attachFails) throw StateError('refused');
    calls.add('attach:$sessionId');
    attachedSession = sessionId;
    attachedCutoffs = List.of(cutoffsHz);
    attachedGains = List.of(gainsDb);
    attachedEnabled = enabled;
  }

  @override
  Future<void> setGain(int band, double gainDb) async =>
      calls.add('gain:$band=$gainDb');
  @override
  Future<void> setEnabled(bool enabled) async => calls.add('enabled:$enabled');
  @override
  Future<void> release() async => calls.add('release');
}

void main() {
  late FakePort port;
  late DynamicsEqualizer eq;
  setUp(() {
    port = FakePort();
    eq = DynamicsEqualizer(port: port);
  });
  tearDown(() => eq.dispose());

  test('the layout: ten ISO centres, cutoffs between them, ±15 dB', () {
    expect(DynamicsEqualizer.bandCount, 10);
    expect(DynamicsEqualizer.centerFrequencies.first, 31.25);
    expect(DynamicsEqualizer.centerFrequencies.last, 16000);
    final c = DynamicsEqualizer.centerFrequencies;
    final k = DynamicsEqualizer.cutoffFrequencies;
    for (var i = 0; i < 9; i++) {
      expect(k[i], greaterThan(c[i]));
      expect(k[i], lessThan(c[i + 1]));
    }
    expect(k.last, 20000);
    expect(DynamicsEqualizer.minDb, -15);
    expect(DynamicsEqualizer.maxDb, 15);
  });

  test('nothing attaches without a session, or while off', () async {
    await eq.setEnabled(true);
    expect(port.calls, isEmpty);
    await eq.setEnabled(false);
    await eq.setSessionId(7);
    expect(port.calls, isEmpty);
    expect(eq.attached, isFalse);
  });

  test('on + session attaches with the cutoffs and gains; off releases',
      () async {
    await eq.setGain(0, 4);
    await eq.setGain(9, -2.5);
    await eq.setSessionId(7);
    await eq.setEnabled(true);
    expect(port.calls, ['attach:7']);
    expect(port.attachedCutoffs, DynamicsEqualizer.cutoffFrequencies);
    expect(port.attachedGains, [4, 0, 0, 0, 0, 0, 0, 0, 0, -2.5]);
    expect(eq.attached, isTrue);
    await eq.setEnabled(false);
    expect(port.calls.last, 'release');
    expect(eq.attached, isFalse);
    expect(eq.gain(0), 4, reason: 'gains outlive the effect');
  });

  test('a new session re-attaches, null releases', () async {
    await eq.setEnabled(true);
    await eq.setSessionId(7);
    await eq.setSessionId(8);
    expect(port.calls, ['attach:7', 'release', 'attach:8']);
    await eq.setSessionId(null);
    expect(port.calls.last, 'release');
    expect(eq.attached, isFalse);
    await eq.setSessionId(9);
    expect(port.calls.last, 'attach:9');
  });

  test('gains reach the live effect, clamped; readouts follow at once',
      () async {
    await eq.setSessionId(7);
    await eq.setEnabled(true);
    final seen = <double>[];
    final sub = eq.gainStream(3).listen(seen.add);
    await eq.setGain(3, 6);
    await eq.setGain(3, 40);
    await eq.setGain(3, -40);
    expect(port.calls.sublist(1), ['gain:3=6.0', 'gain:3=15.0', 'gain:3=-15.0']);
    expect(eq.gain(3), -15);
    await Future<void>.delayed(Duration.zero);
    expect(seen, [0, 6, 15, -15]);
    await sub.cancel();
  });

  test('setGains takes the saved list in band order and tolerates its length',
      () async {
    await eq.setGains(const [1, 2, 3]);
    expect(eq.gains.sublist(0, 4), [1, 2, 3, 0]);
    await eq.setGains(List<double>.filled(12, 2));
    expect(eq.gains, everyElement(2));
    await eq.setSessionId(7);
    await eq.setEnabled(true);
    port.calls.clear();
    await eq.setGains(const [5, -5]);
    expect(port.calls, ['gain:0=5.0', 'gain:1=-5.0']);
  });

  test('a platform refusal is logged, not thrown, and a new session retries',
      () async {
    port.attachFails = true;
    await eq.setEnabled(true);
    await eq.setSessionId(7);
    expect(eq.attached, isFalse);
    port.attachFails = false;
    await eq.setSessionId(8);
    expect(eq.attached, isTrue);
    expect(port.calls, ['attach:8']);
  });

  test('operations serialize in call order', () async {
    final f1 = eq.setSessionId(7);
    final f2 = eq.setEnabled(true);
    final f3 = eq.setGain(2, 3);
    final f4 = eq.setSessionId(null);
    await Future.wait([f1, f2, f3, f4]);
    expect(port.calls, ['attach:7', 'gain:2=3.0', 'release']);
  });

  test('a bypass disables the live effect without releasing it, and lifts',
      () async {
    await eq.setSessionId(7);
    await eq.setEnabled(true);
    expect(port.attachedEnabled, isTrue);
    port.calls.clear();
    await eq.setBypassed(true);
    expect(eq.bypassed, isTrue);
    expect(eq.attached, isTrue);
    expect(port.calls, ['enabled:false']);
    await eq.setBypassed(true);
    expect(port.calls, ['enabled:false'], reason: 'idempotent');
    await eq.setBypassed(false);
    expect(eq.bypassed, isFalse);
    expect(port.calls, ['enabled:false', 'enabled:true']);
    // The on flag is its own thing: off still releases while held.
    await eq.setBypassed(true);
    await eq.setEnabled(false);
    expect(port.calls.last, 'release');
    expect(eq.enabled, isFalse);
  });

  test('a bypass with nothing attached only records; the next attach honours it',
      () async {
    await eq.setBypassed(true);
    expect(port.calls, isEmpty);
    await eq.setSessionId(7);
    await eq.setEnabled(true);
    expect(port.calls, ['attach:7']);
    expect(port.attachedEnabled, isFalse);
    await eq.setBypassed(false);
    expect(port.calls, ['attach:7', 'enabled:true']);
  });
}
