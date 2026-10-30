// The equalizer screen's state, kept apart from its widgets.
//
// What the screen shows is a function of five facts: the platform (the native
// EQ is Android-only), the cast state (the EQ only colours on-device audio),
// the persisted on/off toggle, the equalizer the handler currently has
// attached, and whether the player has loaded anything yet. This controller
// derives one [EqStatus] from them and re-derives it whenever any of them
// moves, instead of juggling loading/error flags across several callbacks.
//
// Why a seam ([EqAudio]) rather than reading the singletons directly:
// just_audio's AndroidEqualizerParameters / AndroidEqualizerBand have private
// constructors and MediaManager's handler needs a live AudioService, so
// neither can be stood up in a test. [LiveEqAudio] is the only place that
// touches them; everything else here runs against fakes.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:audio_service/audio_service.dart' show AudioProcessingState;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart'
    show AndroidEqualizer, AndroidEqualizerBand;

import '../../media/audio_stuff.dart';
import '../../singletons/cast_manager.dart';
import '../../singletons/log_manager.dart';
import '../../singletons/media.dart';
import '../../singletons/settings.dart';

/// One equalizer band: a centre frequency and a live gain in dB.
abstract class EqBand {
  double get centerFrequency;
  double get gain;
  Stream<double> get gainStream;
  Future<void> setGain(double gain);
}

/// The device's band layout and gain range, as the native effect reports it.
class EqParams {
  const EqParams(
      {required this.minDb, required this.maxDb, required this.bands});

  final double minDb;
  final double maxDb;
  final List<EqBand> bands;

  /// Where 0 dB sits along a band's travel: 0 at the min end, 1 at the max
  /// end. Half-way on the usual symmetric range; a degenerate range reads as
  /// half-way too so nothing divides by zero.
  double get zeroFraction {
    final span = maxDb - minDb;
    if (span <= 0) return 0.5;
    return ((0 - minDb) / span).clamp(0.0, 1.0);
  }
}

/// The attached native equalizer. The handler builds a new one every time it
/// rebuilds the player (the EQ pipeline is fixed at player construction), so
/// identity is what tells the controller a band set has gone stale.
abstract class EqUnit {
  /// Resolves once the player first loads a source — the native effect only
  /// exists once there is an audio session — and then stays resolved for the
  /// life of this unit. It never resolves on an idle player.
  Future<EqParams> get params;
}

/// What the screen needs from the audio side.
abstract class EqAudio {
  /// A native EQ exists on this platform at all.
  bool get supported;
  bool get casting;
  Stream<void> get castingChanges;

  /// The persisted on/off setting — the source of truth for the switch.
  bool get enabled;

  /// The attached equalizer, or null while the pipeline is off.
  EqUnit? get unit;

  /// Nothing is loaded (idle or errored), so [EqUnit.params] cannot resolve
  /// until the user starts a song.
  bool get playerInactive;
  Stream<void> get playerChanges;

  /// Rebuilds the player with or without the EQ pipeline and persists the
  /// setting only on success; never throws.
  Future<void> setEnabled(bool on);
  Future<void> saveGains(List<double> gains);
}

enum EqStatus {
  /// Not Android: no native EQ, no toggle.
  unsupported,

  /// Audio is on a cast device; the toggle is locked.
  casting,

  /// A toggle is in flight (the player is being rebuilt).
  busy,

  /// The EQ is off: the pipeline is not attached.
  off,

  /// On, but the band layout cannot be read until something loads.
  needsPlayback,

  /// On and something is loaded; the band layout is on its way.
  loading,

  /// The band layout never came (or the read threw).
  failed,

  /// The device reports an equalizer with zero bands.
  noBands,

  /// Sliders.
  ready,
}

class EqController extends ChangeNotifier {
  EqController(this.audio, {this.loadTimeout = const Duration(seconds: 8)}) {
    _castSub = audio.castingChanges.listen((_) => _refresh());
    _playerSub = audio.playerChanges.listen((_) => _refresh());
    _refresh();
  }

  final EqAudio audio;

  /// How long a player that HAS loaded something may leave the band layout
  /// unanswered before the screen calls it a failure. A safety net only: the
  /// answer normally lands within milliseconds of a load starting, and the
  /// clock only runs while the player is active.
  final Duration loadTimeout;

  EqStatus _status = EqStatus.off;
  EqStatus get status => _status;

  EqParams? _params;

  /// The band layout, present exactly when [status] is ready or noBands.
  EqParams? get params => _params;

  String? _failure;

  /// Raw detail for [EqStatus.failed]: the thrown error's text, or null when
  /// the layout simply never arrived.
  String? get failure => _failure;

  bool _toggling = false;
  bool _pendingEnabled = false;

  /// The switch's value: the persisted setting, or the value in flight.
  bool get enabled => _toggling ? _pendingEnabled : audio.enabled;

  bool get canToggle => switch (_status) {
        EqStatus.unsupported || EqStatus.casting || EqStatus.busy => false,
        _ => true,
      };

  EqUnit? _loadingUnit;
  EqUnit? _loadedUnit;
  Timer? _timer;
  bool _timedOut = false;
  bool _disposed = false;
  StreamSubscription<void>? _castSub;
  StreamSubscription<void>? _playerSub;

  void _refresh() {
    if (_disposed) return;
    _status = _derive();
    notifyListeners();
  }

  EqStatus _derive() {
    if (!audio.supported) return EqStatus.unsupported;
    if (audio.casting) return EqStatus.casting;
    if (_toggling) return EqStatus.busy;
    if (!audio.enabled) {
      _drop();
      return EqStatus.off;
    }
    final unit = audio.unit;
    if (unit == null) {
      // Enabled with no pipeline attached: a moment inside a rebuild, or a
      // toggle done elsewhere. The next player event re-derives.
      _drop();
      return _waiting();
    }
    if (!identical(unit, _loadedUnit)) {
      _load(unit);
      return _waiting();
    }
    return _params!.bands.isEmpty ? EqStatus.noBands : EqStatus.ready;
  }

  EqStatus _waiting() {
    if (audio.playerInactive) {
      // Idle: params cannot resolve, so say what to do. A later load gets a
      // fresh timeout window.
      _stopTimer();
      _timedOut = false;
      return EqStatus.needsPlayback;
    }
    if (_failure != null || _timedOut) {
      _stopTimer();
      return EqStatus.failed;
    }
    _timer ??= Timer(loadTimeout, () {
      _timedOut = true;
      _refresh();
    });
    return EqStatus.loading;
  }

  // Start reading a unit's layout. Idempotent per unit; the result is kept
  // only if that unit is still the one attached when it arrives, so a toggle
  // mid-read cannot leave the sliders bound to a disposed equalizer.
  void _load(EqUnit unit) {
    if (identical(unit, _loadingUnit)) return;
    _drop();
    _loadingUnit = unit;
    unit.params.then((p) {
      if (_disposed || !identical(unit, _loadingUnit)) return;
      _params = p;
      _loadedUnit = unit;
      _stopTimer();
      _refresh();
    }, onError: (Object e) {
      if (_disposed || !identical(unit, _loadingUnit)) return;
      _failure = '$e';
      _stopTimer();
      _refresh();
    });
  }

  void _drop() {
    _loadingUnit = null;
    _loadedUnit = null;
    _params = null;
    _failure = null;
    _timedOut = false;
    _stopTimer();
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// Flip the EQ on or off. The switch shows the requested value while the
  /// player is rebuilt, then snaps to the persisted setting — which the
  /// handler writes only after a successful rebuild, so a failure reverts it.
  Future<void> setEnabled(bool on) async {
    if (!canToggle) return;
    _toggling = true;
    _pendingEnabled = on;
    _drop();
    _refresh();
    try {
      await audio.setEnabled(on);
    } catch (e) {
      appLog('[eq] toggle failed: $e');
    } finally {
      _toggling = false;
    }
    _refresh();
  }

  Future<void> resetToFlat() async {
    final p = _params;
    if (p == null) return;
    await Future.wait(p.bands.map((b) => b.setGain(0)));
    await saveGains();
  }

  /// Snapshot every band's gain into settings. Called on slider release, not
  /// per drag tick, so the settings file is not rewritten dozens of times per
  /// gesture.
  Future<void> saveGains() async {
    final p = _params;
    if (p == null) return;
    await audio.saveGains([for (final b in p.bands) b.gain]);
  }

  @override
  void dispose() {
    _disposed = true;
    _castSub?.cancel();
    _playerSub?.cancel();
    _stopTimer();
    super.dispose();
  }
}

/// 60 → "60", 1000 → "1k", 1500 → "1.5k", 14000 → "14k".
String formatFrequency(double hz) {
  if (hz < 1000) return '${hz.round()}';
  final k = (hz / 1000).toStringAsFixed(1);
  return k.endsWith('.0') ? '${k.substring(0, k.length - 2)}k' : '${k}k';
}

/// "+3.5", "0.0", "-3.5": one decimal, an explicit plus, never "-0.0".
String formatGain(double db) {
  final s = db.toStringAsFixed(1);
  if (s == '0.0' || s == '-0.0') return '0.0';
  return db > 0 ? '+$s' : s;
}

/// The real audio side: the handler's equalizer, the cast manager and the
/// persisted settings.
class LiveEqAudio implements EqAudio {
  AudioPlayerHandler get _handler => MediaManager().audioHandler;

  @override
  bool get supported => Platform.isAndroid;

  @override
  bool get casting => CastManager().isCasting;

  @override
  Stream<void> get castingChanges => CastManager().activeTargetStream;

  @override
  bool get enabled => SettingsManager().eqEnabled;

  // One wrapper per AndroidEqualizer instance, so the controller's identity
  // check sees a new unit exactly when the handler built a new equalizer.
  AndroidEqualizer? _eq;
  _LiveUnit? _unit;

  @override
  EqUnit? get unit {
    final eq = _handler.equalizer;
    if (eq == null) {
      _eq = null;
      _unit = null;
      return null;
    }
    if (!identical(eq, _eq)) {
      _eq = eq;
      _unit = _LiveUnit(eq);
    }
    return _unit;
  }

  @override
  bool get playerInactive {
    final s = _handler.playbackState.value.processingState;
    return s == AudioProcessingState.idle || s == AudioProcessingState.error;
  }

  @override
  Stream<void> get playerChanges =>
      _handler.playbackState.map((s) => s.processingState).distinct();

  @override
  Future<void> setEnabled(bool on) => _handler.setEqEnabled(on);

  @override
  Future<void> saveGains(List<double> gains) =>
      SettingsManager().setEqBandGains(gains);
}

class _LiveUnit implements EqUnit {
  _LiveUnit(AndroidEqualizer eq)
      : params = eq.parameters.then((p) => EqParams(
              minDb: p.minDecibels,
              maxDb: p.maxDecibels,
              bands: [for (final b in p.bands) _LiveBand(b)],
            ));

  @override
  final Future<EqParams> params;
}

class _LiveBand implements EqBand {
  _LiveBand(this._band);
  final AndroidEqualizerBand _band;

  @override
  double get centerFrequency => _band.centerFrequency;
  @override
  double get gain => _band.gain;
  @override
  Stream<double> get gainStream => _band.gainStream;
  @override
  Future<void> setGain(double gain) => _band.setGain(gain);
}
