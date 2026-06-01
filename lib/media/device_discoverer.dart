import 'cast_target.dart';

/// A source of remote [CastTarget]s on the local network.
///
/// Implementations wrap a specific protocol/SDK — DLNA/UPnP via SSDP in
/// Phase 3, Chromecast via the Cast SDK in Phase 4 — and are aggregated by
/// [CastManager]. Keeping discovery behind this interface means the manager
/// and the picker UI never depend on a particular casting package, so the
/// package choice (e.g. dart_cast vs flutter_chrome_cast) can be made — and
/// changed — without touching anything above this seam.
///
/// Construction must be cheap; real network activity starts on [start] and
/// must be fully released on [stop]. [devicesStream] must be a broadcast
/// stream and should emit a fresh list whenever a device appears or vanishes.
abstract class DeviceDiscoverer {
  /// Begin scanning. Discovered/lost devices are surfaced via [devicesStream].
  Future<void> start();

  /// Stop scanning and release sockets / SDK resources.
  Future<void> stop();

  /// Emits the current set of visible devices, refreshed on every change.
  Stream<List<CastTarget>> get devicesStream;

  /// Snapshot of the currently-visible devices (for seeding late readers).
  List<CastTarget> get devices;
}
