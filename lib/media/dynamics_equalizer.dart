// The ten-band equalizer for Android 9+: a DynamicsProcessing effect this
// class creates on the player's audio session while the EQ is on, with the
// band layout defined here (ISO octave centres) rather than read from the
// device — so the screen never has to wait for playback to know the bands,
// and the saved gains always mean the same frequencies.
//
// Lifecycle: the backend feeds it the player's audio session id (a new one
// after every player rebuild, null while there is no native player); it
// attaches when it has both a session and the on flag, releases when either
// goes away, and carries the gains across (set before an attach, they ride
// along with it). Attach-only-while-on is deliberate: an effect left on the
// session re-activates on every audio-route change, which on Samsung can
// cut playback (see LocalPlaybackBackend).
//
// Unlike the five-band fallback (just_audio's AndroidEqualizer, fixed into
// the player's pipeline at construction), toggling this engine never
// rebuilds the player.

import 'dart:async';

import 'package:dynamics_eq/dynamics_eq.dart';
import 'package:rxdart/rxdart.dart';

import '../singletons/log_manager.dart';

/// The native calls the engine makes: the plugin in the app, a fake in tests.
abstract class DynamicsEqPort {
  Future<void> attach({
    required int sessionId,
    required List<double> cutoffsHz,
    required List<double> gainsDb,
    required bool enabled,
  });
  Future<void> setGain(int band, double gainDb);
  Future<void> setEnabled(bool enabled);
  Future<void> release();
}

class _PluginPort implements DynamicsEqPort {
  @override
  Future<void> attach({
    required int sessionId,
    required List<double> cutoffsHz,
    required List<double> gainsDb,
    required bool enabled,
  }) =>
      DynamicsEq.attach(
          sessionId: sessionId,
          cutoffsHz: cutoffsHz,
          gainsDb: gainsDb,
          enabled: enabled);
  @override
  Future<void> setGain(int band, double gainDb) => DynamicsEq.setGain(band, gainDb);
  @override
  Future<void> setEnabled(bool enabled) => DynamicsEq.setEnabled(enabled);
  @override
  Future<void> release() => DynamicsEq.release();
}

class DynamicsEqualizer {
  DynamicsEqualizer({DynamicsEqPort? port}) : _port = port ?? _PluginPort();

  /// Whether this device gets this engine: decided once at startup
  /// (main.dart, before the handler builds the player) from the plugin's
  /// probe. False off Android and in tests.
  static bool supported = false;

  /// ISO octave centres: the usual ten-band graphic equalizer.
  static const List<double> centerFrequencies = [
    31.25, 62.5, 125, 250, 500, 1000, 2000, 4000, 8000, 16000,
  ];

  /// Each band's upper edge, which is how DynamicsProcessing defines a band:
  /// the geometric midpoint to the next centre, the last band running to the
  /// top of the audible range.
  static const List<double> cutoffFrequencies = [
    44.19, 88.39, 176.78, 353.55, 707.11, 1414.21, 2828.43, 5656.85, 11313.71, 20000,
  ];

  static const double minDb = -15;
  static const double maxDb = 15;
  static int get bandCount => centerFrequencies.length;

  final DynamicsEqPort _port;
  final List<BehaviorSubject<double>> _gains = [
    for (var i = 0; i < 10; i++) BehaviorSubject<double>.seeded(0),
  ];
  int? _sessionId;
  bool _enabled = false;
  bool _attached = false;
  // Serializes attach / release / gain pushes: a player rebuild racing a
  // toggle must not interleave native calls on two sessions.
  Future<void> _chain = Future<void>.value();

  bool _bypassed = false;

  bool get enabled => _enabled;
  bool get attached => _attached;
  int? get sessionId => _sessionId;

  /// Held off for the moment (the Compare button) with the on flag untouched:
  /// the effect stays attached, only disabled, so letting go is instant.
  bool get bypassed => _bypassed;

  double gain(int band) => _gains[band].value;
  Stream<double> gainStream(int band) => _gains[band].stream;
  List<double> get gains => [for (final g in _gains) g.value];

  /// The on flag. Attaches when a session is known, releases otherwise.
  Future<void> setEnabled(bool on) => _run(() async {
        if (_enabled == on) return;
        _enabled = on;
        await _sync();
      });

  /// Hold the effect off ([on] true) or let it back. Nothing is released and
  /// nothing persisted; an attach that happens while held comes up disabled.
  Future<void> setBypassed(bool on) => _run(() async {
        if (_bypassed == on) return;
        _bypassed = on;
        if (_attached) await _port.setEnabled(!on);
      });

  /// The player's audio session: a new id re-attaches, null releases.
  Future<void> setSessionId(int? id) => _run(() async {
        if (_sessionId == id) return;
        await _release();
        _sessionId = id;
        await _sync();
      });

  /// One band's gain in dB, clamped to the range. Recorded at once (the
  /// readout follows), pushed to the effect when one is attached.
  Future<void> setGain(int band, double db) {
    final v = db.clamp(minDb, maxDb);
    _gains[band].add(v);
    return _run(() async {
      if (_attached) await _port.setGain(band, v);
    });
  }

  /// Every band's gain in band order (extra entries ignored, missing ones
  /// left alone). The saved gains on launch and on enable.
  Future<void> setGains(List<double> dbs) {
    final n = dbs.length < bandCount ? dbs.length : bandCount;
    for (var i = 0; i < n; i++) {
      _gains[i].add(dbs[i].clamp(minDb, maxDb));
    }
    return _run(() async {
      if (!_attached) return;
      for (var i = 0; i < n; i++) {
        await _port.setGain(i, _gains[i].value);
      }
    });
  }

  Future<void> _sync() async {
    final want = _enabled && _sessionId != null;
    if (want && !_attached) {
      try {
        await _port.attach(
            sessionId: _sessionId!,
            cutoffsHz: cutoffFrequencies,
            gainsDb: gains,
            enabled: !_bypassed);
        _attached = true;
      } catch (e) {
        appLog('[eq] ten-band attach failed on session $_sessionId: $e');
      }
    } else if (!want && _attached) {
      await _release();
    }
  }

  Future<void> _release() async {
    if (!_attached) return;
    _attached = false;
    try {
      await _port.release();
    } catch (e) {
      appLog('[eq] ten-band release failed: $e');
    }
  }

  Future<void> _run(Future<void> Function() op) {
    _chain = _chain
        .then((_) => op())
        .catchError((Object e) => appLog('[eq] ten-band: $e'));
    return _chain;
  }

  Future<void> dispose() async {
    await _run(_release);
    for (final g in _gains) {
      await g.close();
    }
  }
}
