import 'dart:async';

import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:rxdart/rxdart.dart';

import 'cast_target.dart';
import 'device_discoverer.dart';

/// Discovers Chromecast / Google Cast devices via the native Google Cast SDK
/// (flutter_chrome_cast) and surfaces them as [CastTarget]s for [CastManager].
///
/// Android-only here (registered only on Android in MediaManager.start). The
/// shared Cast context is initialized lazily on first [start]; the backend
/// ([ChromecastPlaybackBackend]) reuses the same native context to control the
/// device addressed by its id.
class ChromecastDeviceDiscoverer implements DeviceDiscoverer {
  final BehaviorSubject<List<CastTarget>> _subject =
      BehaviorSubject<List<CastTarget>>.seeded(const []);
  StreamSubscription<List<GoogleCastDevice>>? _sub;
  bool _initialized = false;
  bool _running = false;

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
        await GoogleCastContext.instance
            .setSharedInstanceWithOptions(GoogleCastOptions());
        _sub = GoogleCastDiscoveryManager.instance.devicesStream
            .listen(_onDevices);
        _initialized = true;
      }
      await GoogleCastDiscoveryManager.instance.startDiscovery();
    } catch (e) {
      _running = false;
      // ignore: avoid_print
      print('Chromecast discovery start failed: $e');
    }
  }

  @override
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    try {
      await GoogleCastDiscoveryManager.instance.stopDiscovery();
    } catch (_) {/* best-effort */}
  }

  void _onDevices(List<GoogleCastDevice> devices) {
    _subject.add(devices
        .map((d) => CastTarget(
              id: d.deviceID,
              name: d.friendlyName,
              kind: CastTargetKind.chromecast,
            ))
        .toList());
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _subject.close();
  }
}
