import 'dart:async';

import 'package:rxdart/rxdart.dart';

import '../media/cast_target.dart';
import '../media/device_discoverer.dart';

/// Coordinates *where* audio plays: aggregates the remote devices reported by
/// registered [DeviceDiscoverer]s with the always-present local target, and
/// tracks which target is currently active.
///
/// Phase 2 ships the discovery/selection plumbing + picker UI only — no
/// discoverers are registered yet, so the picker shows just "This device".
/// Phase 3 (DLNA) and Phase 4 (Chromecast) register discoverers and set
/// [onTargetSelected] to perform the actual backend swap on the
/// AudioPlayerHandler (build the remote backend, hand it the current track +
/// position, switch `_backend`).
class CastManager {
  CastManager._privateConstructor();
  static final CastManager _instance = CastManager._privateConstructor();
  factory CastManager() => _instance;

  final List<DeviceDiscoverer> _discoverers = [];
  final List<StreamSubscription<List<CastTarget>>> _subs = [];
  bool _discovering = false;

  // Available targets: always the local device first, then whatever the
  // registered discoverers currently see.
  final BehaviorSubject<List<CastTarget>> _targets =
      BehaviorSubject<List<CastTarget>>.seeded(const [CastTarget.local]);

  // Currently-selected target. Seeded local; never null.
  final BehaviorSubject<CastTarget> _activeTarget =
      BehaviorSubject<CastTarget>.seeded(CastTarget.local);

  // Surfaces "casting failed, fell back to this device" messages for the UI to
  // show as a toast. PublishSubject so a late listener doesn't replay a stale
  // error.
  final PublishSubject<String> _castErrors = PublishSubject<String>();

  Stream<List<CastTarget>> get targetsStream => _targets.stream;
  List<CastTarget> get targets => _targets.value;
  Stream<CastTarget> get activeTargetStream => _activeTarget.stream;
  CastTarget get activeTarget => _activeTarget.value;
  bool get isCasting => !_activeTarget.value.isLocal;

  /// Emits a message when a cast attempt failed and playback fell back to this
  /// device. The UI listens and shows a toast.
  Stream<String> get castErrorStream => _castErrors.stream;

  /// True once at least one discoverer is registered — lets the picker decide
  /// whether to show the "searching…" hint.
  bool get hasDiscoverers => _discoverers.isNotEmpty;

  /// Invoked when the user picks a target. Phase 3/4 set this to perform the
  /// backend swap on AudioPlayerHandler. Left null in Phase 2, so selecting a
  /// target only updates [activeTarget] (and only "This device" is ever
  /// listed until a discoverer is registered).
  Future<void> Function(CastTarget target)? onTargetSelected;

  /// Register a discovery source. Call before [startDiscovery].
  void registerDiscoverer(DeviceDiscoverer d) {
    _discoverers.add(d);
  }

  /// Begin scanning on all registered discoverers, recomputing the target list
  /// as they report changes. Idempotent; safe to call when no discoverers are
  /// registered (no-op beyond keeping the local target listed).
  Future<void> startDiscovery() async {
    if (_discovering) return;
    _discovering = true;
    for (final d in _discoverers) {
      _subs.add(d.devicesStream.listen((_) => _recompute()));
      await d.start();
    }
    _recompute();
  }

  Future<void> stopDiscovery() async {
    if (!_discovering) return;
    _discovering = false;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    for (final d in _discoverers) {
      await d.stop();
    }
    _recompute();
  }

  /// Select a playback target. Updates [activeTarget] and invokes
  /// [onTargetSelected] (when wired) to perform the actual backend swap.
  Future<void> selectTarget(CastTarget target) async {
    if (target == _activeTarget.value) return;
    _activeTarget.add(target);
    final cb = onTargetSelected;
    if (cb != null) {
      await cb(target);
    }
  }

  /// Called by the handler when a remote backend failed to start. Reflects the
  /// revert in the UI (active target → local) WITHOUT re-invoking
  /// [onTargetSelected] (the handler has already reverted the backend), and
  /// surfaces [message] on [castErrorStream] for a toast.
  void reportCastFailed(String message) {
    _activeTarget.add(CastTarget.local);
    if (!_castErrors.isClosed) _castErrors.add(message);
  }

  void _recompute() {
    // Local always first; then de-duped remote devices (two discoverers could
    // in principle surface the same physical device).
    final seen = <String>{CastTarget.localId};
    final merged = <CastTarget>[CastTarget.local];
    for (final d in _discoverers) {
      for (final t in d.devices) {
        if (seen.add(t.id)) merged.add(t);
      }
    }
    // Always keep the active remote target listed, even when the current scan
    // snapshot doesn't include it — SSDP devices flicker in and out, and a
    // transient gap (notably right after the picker reopens and rescans) must
    // not drop the device the user is actively casting to. Without this, the
    // active target fell out of the list and the picker showed "This device"
    // while audio was still playing on the renderer.
    final active = _activeTarget.value;
    if (!active.isLocal && seen.add(active.id)) {
      merged.add(active);
    }
    _targets.add(merged);
    // NOTE: we intentionally do NOT auto-fall-back to local when a device is
    // merely absent from a scan (that was the bug above). Graceful handling of
    // a renderer that genuinely goes offline mid-cast is a future refinement
    // (drive it off an explicit onRendererOffline for the *active* device).
  }

  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _targets.close();
    _activeTarget.close();
    _castErrors.close();
  }
}
