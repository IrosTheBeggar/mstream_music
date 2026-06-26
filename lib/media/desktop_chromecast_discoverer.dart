import 'dart:async';
import 'dart:io';

import 'package:multicast_dns/multicast_dns.dart';
import 'package:rxdart/rxdart.dart';

import 'cast_log.dart';
import 'cast_target.dart';
import 'device_discoverer.dart';

/// Where a discovered Chromecast lives on the LAN — looked up by the desktop
/// backend when the user picks it.
class ChromecastEndpoint {
  final InternetAddress host;
  final int port;
  const ChromecastEndpoint(this.host, this.port);
}

/// Discovers Chromecast / Google Cast devices on the LAN via pure-Dart mDNS
/// (`_googlecast._tcp`), for desktop where the native Google Cast SDK
/// (flutter_chrome_cast) isn't available. Surfaces [CastTarget]s for
/// [CastManager] and records each device's host:port in [endpoints] so the
/// [DesktopChromecastPlaybackBackend] can open a CASTV2 connection to it.
class DesktopChromecastDiscoverer implements DeviceDiscoverer {
  static const _service = '_googlecast._tcp.local';

  final BehaviorSubject<List<CastTarget>> _subject =
      BehaviorSubject<List<CastTarget>>.seeded(const []);

  /// device id → endpoint, filled during discovery; read by the backend.
  static final Map<String, ChromecastEndpoint> endpoints = {};

  MDnsClient? _client;
  Timer? _rescan;
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
      _client = _newClient();
      await _client!.start(interfacesFactory: _interfaces);
      await _scan();
      // mDNS devices answer once; re-scan periodically to catch new ones and
      // refresh TTLs.
      _rescan = Timer.periodic(const Duration(seconds: 15), (_) => _scan());
    } catch (e) {
      _running = false;
      castLog('Desktop Chromecast discovery failed to start', error: e);
    }
  }

  @override
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _rescan?.cancel();
    _rescan = null;
    _client?.stop();
    _client = null;
  }

  Future<void> _scan() async {
    final client = _client;
    if (client == null) return;
    final found = <String, CastTarget>{};
    try {
      await for (final ptr in client
          .lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer(_service))
          .timeout(const Duration(seconds: 4), onTimeout: (s) => s.close())) {
        SrvResourceRecord? srv;
        await for (final r in client.lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(ptr.domainName))) {
          srv = r;
          break;
        }
        if (srv == null) continue;

        // TXT carries fn= (friendly name) and id= (stable device id).
        var name = srv.target;
        var id = srv.target;
        await for (final txt in client.lookup<TxtResourceRecord>(
            ResourceRecordQuery.text(ptr.domainName))) {
          for (final line in txt.text.split('\n')) {
            final eq = line.indexOf('=');
            if (eq <= 0) continue;
            final key = line.substring(0, eq);
            final value = line.substring(eq + 1);
            if (key == 'fn' && value.isNotEmpty) name = value;
            if (key == 'id' && value.isNotEmpty) id = value;
          }
          break;
        }

        // Resolve the host to an address for the CASTV2 socket.
        InternetAddress? addr;
        await for (final ip in client.lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(srv.target))) {
          addr = ip.address;
          break;
        }
        if (addr == null) continue;

        endpoints[id] = ChromecastEndpoint(addr, srv.port);
        found[id] = CastTarget(
            id: id, name: name, kind: CastTargetKind.chromecast);
      }
    } catch (e) {
      castLog('Desktop Chromecast scan error', error: e);
    }
    if (!_subject.isClosed) _subject.add(found.values.toList());
  }

  Future<void> dispose() async {
    await stop();
    await _subject.close();
  }

  /// Windows' winsock has no `SO_REUSEPORT`, so multicast_dns's default
  /// `MDnsClient()` (which binds with `reusePort: true`) throws on `start()`.
  /// Supply a socket factory that forces `reusePort: false` there.
  static MDnsClient _newClient() => MDnsClient(
        rawDatagramSocketFactory: (dynamic host, int port,
            {bool reuseAddress = true, bool reusePort = true, int ttl = 1}) {
          return RawDatagramSocket.bind(host, port,
              reuseAddress: reuseAddress,
              reusePort: Platform.isWindows ? false : reusePort,
              ttl: ttl);
        },
      );

  /// Exclude the loopback adapter: `joinMulticast` on it throws
  /// `WSAENOPROTOOPT` on Windows, and multicast_dns aborts `start()` if any one
  /// interface fails. Verified against real hardware — the remaining LAN
  /// interfaces discover devices fine. (Harmless on Linux/macOS too.)
  static Future<Iterable<NetworkInterface>> _interfaces(
          InternetAddressType type) =>
      NetworkInterface.list(type: type, includeLoopback: false);
}
