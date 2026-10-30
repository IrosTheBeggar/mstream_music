// Per-output equalizer curves: the car gets its curve, the earbuds theirs,
// the phone's speaker its own, and the engine swaps between them as the audio
// route changes — with the EQ screen closed too, which is why this lives in
// the media layer and not in the screen's controller.
//
// Ten-band engine only: its layout is fixed (DynamicsEqualizer), so a stored
// curve is one gain per band and applying one never waits for playback. The
// route comes from the dynamics_eq plugin (the device media routes to on
// Android 12+, the best available output below). A profile is keyed by kind —
// speaker, wired, usb, hdmi — or, for Bluetooth, by a short hash of the
// device address, so each car or headset is its own output and the address
// itself never lands in settings. A new output starts from Flat; the output
// in use when the feature is switched on adopts the curve in use.

import 'dart:async';

import 'package:dynamics_eq/dynamics_eq.dart';
import 'package:flutter/foundation.dart';

import '../singletons/log_manager.dart';
import '../singletons/settings.dart';
import 'dynamics_equalizer.dart';

enum EqOutputKind { speaker, wired, bluetooth, usb, hdmi, other }

EqOutputKind _kindOf(Object? raw) => switch (raw) {
      'speaker' => EqOutputKind.speaker,
      'wired' => EqOutputKind.wired,
      'bluetooth' => EqOutputKind.bluetooth,
      'usb' => EqOutputKind.usb,
      'hdmi' => EqOutputKind.hdmi,
      _ => EqOutputKind.other,
    };

/// FNV-1a over the address: a stable key that is not the address.
String _fnv1a(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

/// The output media plays through right now.
class EqOutput {
  const EqOutput({required this.key, required this.kind, required this.name});

  final String key;
  final EqOutputKind kind;

  /// The device's own name, for Bluetooth; empty otherwise (the screen
  /// labels the kind).
  final String name;

  /// From the plugin's `{kind, name, address}` map.
  factory EqOutput.fromRoute(Map<String, Object?> route) {
    final kind = _kindOf(route['kind']);
    final address = (route['address'] as String?) ?? '';
    final name = kind == EqOutputKind.bluetooth
        ? ((route['name'] as String?) ?? '').trim()
        : '';
    final key = kind == EqOutputKind.bluetooth && address.isNotEmpty
        ? 'bluetooth:${_fnv1a(address)}'
        : kind.name;
    return EqOutput(key: key, kind: kind, name: name);
  }
}

/// A remembered output and its curve.
class EqOutputProfile {
  const EqOutputProfile({
    required this.key,
    required this.kind,
    required this.name,
    required this.gains,
    required this.lastUsed,
  });

  final String key;
  final EqOutputKind kind;
  final String name;

  /// One gain per band of the engine's layout, in band order.
  final List<double> gains;
  final DateTime lastUsed;

  EqOutputProfile copyWith(
          {String? name, List<double>? gains, DateTime? lastUsed}) =>
      EqOutputProfile(
        key: key,
        kind: kind,
        name: name ?? this.name,
        gains: gains ?? this.gains,
        lastUsed: lastUsed ?? this.lastUsed,
      );

  Map<String, Object?> toJson() => {
        'key': key,
        'kind': kind.name,
        'name': name,
        'gains': gains,
        'lastUsed': lastUsed.toIso8601String(),
      };

  /// Back from [toJson]; null for anything malformed, so one bad entry drops
  /// that entry, not the list.
  static EqOutputProfile? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final key = raw['key'];
    final gains = raw['gains'];
    if (key is! String || key.isEmpty || gains is! List) return null;
    final g = [for (final x in gains) if (x is num) x.toDouble()];
    if (g.isEmpty || g.length != gains.length) return null;
    final name = raw['name'];
    final ts = raw['lastUsed'];
    return EqOutputProfile(
      key: key,
      kind: _kindOf(raw['kind']),
      name: name is String ? name : '',
      gains: g,
      lastUsed: (ts is String ? DateTime.tryParse(ts) : null) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// What the router keeps in settings.
abstract class EqOutputStore {
  bool get perOutput;
  Future<void> setPerOutput(bool on);
  List<EqOutputProfile> get profiles;
  Future<void> saveProfiles(List<EqOutputProfile> profiles);
}

/// Where the route comes from: the plugin in the app, a fake in tests.
abstract class EqRoutePort {
  Future<Map<String, Object?>?> current();
  Stream<Map<String, Object?>> get changes;
}

class EqOutputRouter extends ChangeNotifier {
  EqOutputRouter({
    required this.port,
    required this.store,
    required this.applyGains,
    required this.readGains,
    this.frequencies = DynamicsEqualizer.centerFrequencies,
    this.minDb = DynamicsEqualizer.minDb,
    this.maxDb = DynamicsEqualizer.maxDb,
    this.settle = const Duration(milliseconds: 300),
  });

  final EqRoutePort port;
  final EqOutputStore store;

  /// Put a curve on the engine and persist it as the current gains.
  final Future<void> Function(List<double> gains) applyGains;

  /// The engine's gains right now, adopted for the output in use when the
  /// feature is switched on.
  final List<double> Function() readGains;

  /// The engine's layout, which every stored curve is in.
  final List<double> frequencies;
  final double minDb;
  final double maxDb;

  /// Routes flap for a moment when a device connects; the last one within
  /// this window is the one acted on.
  final Duration settle;

  EqOutput? _current;
  EqOutput? get current => _current;

  bool get enabled => store.perOutput;

  /// Most recently used first.
  List<EqOutputProfile> get profiles {
    final list = [...store.profiles];
    list.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
    return list;
  }

  EqOutputProfile? profileOf(String key) {
    for (final p in store.profiles) {
      if (p.key == key) return p;
    }
    return null;
  }

  StreamSubscription<Map<String, Object?>>? _sub;
  Timer? _timer;
  EqOutput? _pending;
  bool _disposed = false;

  /// Read the route once and follow it from then on.
  Future<void> start() async {
    _sub ??= port.changes.listen((m) => _schedule(EqOutput.fromRoute(m)));
    final m = await port.current();
    if (m != null && !_disposed) await _onRoute(EqOutput.fromRoute(m));
  }

  void _schedule(EqOutput o) {
    _pending = o;
    _timer?.cancel();
    _timer = Timer(settle, () {
      final p = _pending;
      _pending = null;
      if (p != null && !_disposed) {
        _onRoute(p).catchError(
            (Object e) => appLog('[eq] output route failed: $e'));
      }
    });
  }

  Future<void> _onRoute(EqOutput o) async {
    final changed = o.key != _current?.key;
    _current = o;
    if (changed) {
      appLog('[eq] output → ${o.key}${o.name.isEmpty ? '' : ' (${o.name})'}');
      if (enabled) await _applyFor(o);
    }
    notifyListeners();
  }

  Future<void> _applyFor(EqOutput o) async {
    final now = DateTime.now();
    final known = profileOf(o.key);
    final profile = known == null
        ? EqOutputProfile(
            key: o.key,
            kind: o.kind,
            name: o.name,
            gains: List<double>.filled(frequencies.length, 0),
            lastUsed: now)
        : known.copyWith(
            name: o.name.isNotEmpty ? o.name : known.name, lastUsed: now);
    await _upsert(profile);
    try {
      await applyGains(profile.gains);
    } catch (e) {
      appLog('[eq] output curve failed: $e');
    }
  }

  Future<void> _upsert(EqOutputProfile p) async {
    final list = [...store.profiles];
    final i = list.indexWhere((q) => q.key == p.key);
    if (i >= 0) {
      list[i] = p;
    } else {
      list.add(p);
    }
    await store.saveProfiles(list);
  }

  /// Switch the feature. Turning it on gives the output in use the curve in
  /// use, so nothing changes under the listener's ears — asking the platform
  /// for the route first when none has arrived yet, or the first device
  /// event would start that output from Flat over the curve just tuned.
  Future<void> setEnabled(bool on) async {
    await store.setPerOutput(on);
    var c = _current;
    if (on && c == null) {
      final m = await port.current();
      if (m != null) c = _current = EqOutput.fromRoute(m);
    }
    if (on && c != null) {
      await _upsert(EqOutputProfile(
        key: c.key,
        kind: c.kind,
        name: c.name,
        gains: List<double>.of(readGains()),
        lastUsed: DateTime.now(),
      ));
    }
    notifyListeners();
  }

  /// The gains just saved from the EQ screen belong to the output in use.
  Future<void> recordGains(List<double> gains) async {
    final c = _current;
    if (!enabled || c == null) return;
    final known = profileOf(c.key);
    final now = DateTime.now();
    await _upsert(known == null
        ? EqOutputProfile(
            key: c.key,
            kind: c.kind,
            name: c.name,
            gains: List<double>.of(gains),
            lastUsed: now)
        : known.copyWith(gains: List<double>.of(gains), lastUsed: now));
    notifyListeners();
  }

  /// A curve picked for an output on the Outputs screen; live at once when
  /// that output is the one in use.
  Future<void> setProfileGains(String key, List<double> gains) async {
    final p = profileOf(key);
    if (p == null) return;
    await _upsert(p.copyWith(gains: List<double>.of(gains)));
    if (enabled && key == _current?.key) {
      try {
        await applyGains(gains);
      } catch (e) {
        appLog('[eq] output curve failed: $e');
      }
    }
    notifyListeners();
  }

  Future<void> forget(String key) async {
    await store.saveProfiles([
      for (final p in store.profiles)
        if (p.key != key) p,
    ]);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}

/// The plugin's route, for the app.
class PluginRoutePort implements EqRoutePort {
  @override
  Future<Map<String, Object?>?> current() => DynamicsEq.currentRoute();

  @override
  Stream<Map<String, Object?>> get changes => DynamicsEq.routeChanges();
}

/// Settings-backed store, for the app.
class SettingsEqOutputStore implements EqOutputStore {
  @override
  bool get perOutput => SettingsManager().eqPerOutput;

  @override
  Future<void> setPerOutput(bool on) => SettingsManager().setEqPerOutput(on);

  @override
  List<EqOutputProfile> get profiles => [
        for (final raw in SettingsManager().eqOutputProfiles)
          ?EqOutputProfile.fromJson(raw),
      ];

  @override
  Future<void> saveProfiles(List<EqOutputProfile> profiles) =>
      SettingsManager()
          .setEqOutputProfiles([for (final p in profiles) p.toJson()]);
}
