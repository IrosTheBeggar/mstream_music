// Fakes for the EQ controller and screen tests: an audio side the test sets
// directly (platform, cast state, the persisted toggle, the attached unit,
// player activity) and bands whose gains live in a BehaviorSubject, every
// set recorded.

import 'dart:async';

import 'package:mstream_music/screens/eq/eq_controller.dart';
import 'package:mstream_music/screens/eq/eq_presets.dart';
import 'package:rxdart/rxdart.dart';

class FakeBand implements EqBand {
  FakeBand(this.centerFrequency, [double gain = 0])
      : _gain = BehaviorSubject<double>.seeded(gain);

  @override
  final double centerFrequency;
  final BehaviorSubject<double> _gain;
  final List<double> setCalls = [];

  @override
  double get gain => _gain.value;
  @override
  Stream<double> get gainStream => _gain.stream;
  @override
  Future<void> setGain(double gain) async {
    setCalls.add(gain);
    _gain.add(gain);
  }
}

/// A five-band ±15 dB layout (what a Samsung reports) unless told otherwise.
EqParams fakeParams({
  double minDb = -15,
  double maxDb = 15,
  List<double> freqs = const [60, 230, 910, 3600, 14000],
  List<double>? gains,
}) =>
    EqParams(minDb: minDb, maxDb: maxDb, bands: [
      for (var i = 0; i < freqs.length; i++)
        FakeBand(freqs[i], gains == null ? 0 : gains[i]),
    ]);

/// A unit whose params the test resolves (or fails) when it chooses.
class FakeUnit implements EqUnit {
  final Completer<EqParams> _c = Completer<EqParams>();
  @override
  Future<EqParams> get params => _c.future;
  void resolve(EqParams p) => _c.complete(p);
  void fail(Object e) => _c.completeError(e);
}

class FakeEqAudio implements EqAudio {
  @override
  bool supported = true;
  @override
  bool casting = false;
  @override
  bool enabled = false;
  @override
  EqUnit? unit;
  @override
  bool playerInactive = true;

  final _cast = StreamController<void>.broadcast();
  final _player = StreamController<void>.broadcast();
  @override
  Stream<void> get castingChanges => _cast.stream;
  @override
  Stream<void> get playerChanges => _player.stream;
  void emitCast() => _cast.add(null);
  void emitPlayer() => _player.add(null);

  /// Every setEnabled call's requested value.
  final List<bool> toggles = [];

  /// When set, setEnabled waits on it (the player rebuild in flight).
  Completer<void>? toggleGate;

  /// When false the rebuild fails: the setting and the unit stay as they were,
  /// as the handler leaves them.
  bool toggleSucceeds = true;

  List<double>? savedGains;
  int saveCount = 0;

  @override
  Future<void> setEnabled(bool on) async {
    toggles.add(on);
    if (toggleGate != null) await toggleGate!.future;
    if (!toggleSucceeds) return;
    enabled = on;
    unit = on ? FakeUnit() : null;
  }

  @override
  Future<void> saveGains(List<double> gains) async {
    savedGains = List<double>.of(gains);
    saveCount++;
  }

  @override
  List<EqPreset> userPresets = [];

  /// Every list handed to saveUserPresets, last one current.
  int userPresetSaves = 0;

  @override
  Future<void> saveUserPresets(List<EqPreset> presets) async {
    userPresets = List<EqPreset>.of(presets);
    userPresetSaves++;
  }

  /// The ten-band engine unless a test says otherwise.
  @override
  bool canBypassInPlace = true;

  /// Every setBypassed call's value, in order.
  final List<bool> bypasses = [];

  @override
  Future<void> setBypassed(bool on) async => bypasses.add(on);
}
