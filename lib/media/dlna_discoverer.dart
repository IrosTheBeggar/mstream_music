import 'dart:async';

import 'package:media_cast_dlna/media_cast_dlna.dart';
import 'package:rxdart/rxdart.dart';

import 'cast_log.dart';
import 'cast_target.dart';
import 'device_discoverer.dart';

/// Discovers DLNA MediaRenderers via the native `media_cast_dlna` plugin and
/// surfaces them as [CastTarget]s for the [CastManager].
///
/// The native plugin owns SSDP/multicast and the per-device AVTransport
/// control URLs (we address renderers by [DeviceUdn] when controlling them in
/// [DlnaPlaybackBackend]). Android-only — the plugin has no iOS/desktop impl,
/// so this is only registered on Android (see MediaManager.start).
class DlnaDeviceDiscoverer implements DeviceDiscoverer {
  final MediaCastDlnaApi _api = MediaCastDlnaApi();
  MediaCastDlnaDiscoveryEvents? _events;

  final Map<String, CastTarget> _devices = {};
  final BehaviorSubject<List<CastTarget>> _subject =
      BehaviorSubject<List<CastTarget>>.seeded(const []);
  final List<StreamSubscription<dynamic>> _subs = [];
  bool _initialized = false;
  bool _running = false;

  /// Limit the SSDP search to MediaRenderers (TVs, AV receivers, speakers) —
  /// we don't want to list MediaServers (which is what mStream itself is).
  static const _rendererTarget = 'urn:schemas-upnp-org:device:MediaRenderer:1';

  /// Shared handle to the plugin API so [DlnaPlaybackBackend] controls the
  /// same native UPnP service this discoverer initialized.
  MediaCastDlnaApi get api => _api;

  @override
  Stream<List<CastTarget>> get devicesStream => _subject.stream;

  @override
  List<CastTarget> get devices => _subject.value;

  @override
  Future<void> start() async {
    if (_running) return;
    _running = true;
    try {
      if (!_initialized) {
        await _api.initializeUpnpService();
        _events = MediaCastDlnaDiscoveryEvents();
        _subs.add(_events!.onDeviceFound.listen(_onFound));
        _subs.add(_events!.onDeviceLost.listen(_onLost));
        _subs.add(_events!.onRendererOffline.listen(_onLost));
        _initialized = true;
      }
      // initializeUpnpService() only *starts* the asynchronous Android service
      // bind (bindService) and returns before it completes — so the service can
      // still be unbound here and startDiscovery() would throw "UPnP service is
      // not bound". Wait for the plugin to report the bind landed first.
      if (!await _awaitServiceBound()) {
        throw StateError('UPnP service did not bind in time');
      }
      await _api.startDiscovery(
        DiscoveryOptions(
          searchTarget: SearchTarget(target: _rendererTarget),
          timeout: DiscoveryTimeout(seconds: 5),
        ),
      );
      castLog('DLNA discovery started');
    } catch (e) {
      // Plugin/native failure (e.g. service init) shouldn't crash the picker;
      // the list just stays empty.
      _running = false;
      castLog('DLNA discovery start failed', error: e);
    }
  }

  /// Polls the plugin's readiness flag until the native UPnP service has bound
  /// (or [timeout] elapses); returns whether it bound.
  ///
  /// The bind (bindService → onServiceConnected) is asynchronous and is *not*
  /// awaited by initializeUpnpService(), so without this the first discovery
  /// attempt races the bind and fails with "UPnP service is not bound". A later
  /// retry usually wins the race — which is why DLNA discovery was flaky rather
  /// than permanently broken.
  Future<bool> _awaitServiceBound({
    Duration timeout = const Duration(seconds: 5),
    Duration interval = const Duration(milliseconds: 100),
  }) async {
    final sw = Stopwatch()..start();
    while (sw.elapsed < timeout) {
      if (await _api.isUpnpServiceInitialized()) return true;
      await Future<void>.delayed(interval);
    }
    return await _api.isUpnpServiceInitialized();
  }

  @override
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    try {
      await _api.stopDiscovery();
    } catch (_) {/* best-effort */}
  }

  void _onFound(DlnaDevice device) {
    // Defensive: only list MediaRenderers even though we scoped the search.
    if (!device.deviceType.contains('MediaRenderer')) return;
    _devices[device.udn.value] = CastTarget(
      id: device.udn.value,
      name: device.friendlyName,
      kind: CastTargetKind.dlna,
    );
    _emit();
  }

  void _onLost(DeviceUdn udn) {
    if (_devices.remove(udn.value) != null) _emit();
  }

  void _emit() => _subject.add(List<CastTarget>.unmodifiable(_devices.values));

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _events?.dispose();
    await _subject.close();
  }
}
