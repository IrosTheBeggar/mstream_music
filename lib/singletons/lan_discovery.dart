import 'dart:async';

import 'package:bonsoir/bonsoir.dart';

import '../native/iroh_tunnel.dart';
import 'log_manager.dart';

/// An mStream server found on the LAN over mDNS/DNS-SD (`_mstream._tcp`).
///
/// Built from a resolved Bonsoir service: [port] comes from the SRV record and
/// [hostAddresses] from the A/AAAA records; the rest are read from the TXT
/// records the server advertises (see mStream `src/discovery/mdns.js`).
class DiscoveredServer {
  /// Stable instance id (TXT `id`) — the dedupe key across IP/interface changes.
  /// Falls back to the service name when the server didn't advertise one.
  final String id;

  /// Friendly name to show the user (TXT `name`, else the mDNS service name).
  final String name;

  /// Server version (TXT `v`), or null if not advertised.
  final String? version;

  /// `http` or `https` (TXT `scheme`).
  final String scheme;

  /// SRV port (falls back to the TXT `port`).
  final int port;

  /// Resolved host addresses, IPv4 preferred.
  final List<String> hostAddresses;

  const DiscoveredServer({
    required this.id,
    required this.name,
    required this.version,
    required this.scheme,
    required this.port,
    required this.hostAddresses,
  });

  /// LAN origin to bootstrap against, e.g. `http://192.168.1.50:3000`. Null when
  /// no usable address resolved yet.
  String? get baseUrl {
    final host = hostAddresses.isNotEmpty ? hostAddresses.first : null;
    return host == null ? null : '$scheme://$host:$port';
  }
}

/// Browses the LAN for iroh-capable mStream servers so the Quick Connect screen
/// can offer them without the user typing anything. Only servers advertising
/// `iroh=1` are surfaced — those are the ones a tunnel can be paired with.
///
/// Android-only, gated by [IrohTunnel.isSupported] (same gate as Quick Connect):
/// the payoff is a roaming iroh connection, which only the Android build has.
class LanDiscovery {
  static final LanDiscovery _instance = LanDiscovery._();
  factory LanDiscovery() => _instance;
  LanDiscovery._();

  static const String _serviceType = '_mstream._tcp';

  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _sub;

  // Keyed by DiscoveredServer.id so a server re-announcing (or changing IP)
  // updates in place instead of duplicating.
  final Map<String, DiscoveredServer> _servers = {};
  final StreamController<List<DiscoveredServer>> _controller =
      StreamController<List<DiscoveredServer>>.broadcast();

  /// Live list of discovered iroh servers; emits on every change.
  Stream<List<DiscoveredServer>> get stream => _controller.stream;

  /// Snapshot for seeding a StreamBuilder before the first event.
  List<DiscoveredServer> get current => _servers.values.toList();

  /// True only on builds that can actually pair an iroh tunnel.
  bool get isSupported => IrohTunnel.isSupported;

  /// Begin browsing. Idempotent; a no-op on unsupported builds.
  Future<void> start() async {
    if (!isSupported || _discovery != null) return;
    try {
      final discovery = BonsoirDiscovery(type: _serviceType);
      _discovery = discovery;
      await discovery.initialize();
      _sub = discovery.eventStream?.listen(_onEvent);
      await discovery.start();
    } catch (e) {
      appLog('[lan-discovery] start failed: $e');
      await stop();
    }
  }

  /// Stop browsing and drop the current results.
  Future<void> stop() async {
    final discovery = _discovery;
    _discovery = null;
    await _sub?.cancel();
    _sub = null;
    try {
      await discovery?.stop();
    } catch (_) {
      // Already stopped / platform teardown — nothing to recover.
    }
    if (_servers.isNotEmpty) {
      _servers.clear();
      _emit();
    }
  }

  /// Restart browsing (the screen's "refresh" affordance).
  Future<void> refresh() async {
    await stop();
    await start();
  }

  void _onEvent(BonsoirDiscoveryEvent event) {
    // A found service carries no host/port/TXT yet — ask the platform to resolve
    // it; the resolved event below has the details.
    if (event is BonsoirDiscoveryServiceFoundEvent) {
      event.service.resolve(_discovery!.serviceResolver);
      return;
    }
    if (event is BonsoirDiscoveryServiceResolvedEvent) {
      final server = _fromService(event.service);
      if (server != null) {
        _servers[server.id] = server;
        _emit();
      }
      return;
    }
    if (event is BonsoirDiscoveryServiceLostEvent) {
      final id = _idFor(event.service);
      if (_servers.remove(id) != null) _emit();
    }
  }

  // Build a DiscoveredServer from a resolved service, or null if it isn't an
  // iroh-capable server we can use (no `iroh=1`, or no address/port resolved).
  DiscoveredServer? _fromService(BonsoirService s) {
    final attrs = s.attributes;
    if (attrs['iroh'] != '1') return null; // not pairable — Quick Connect skips it

    final port = s.port != 0 ? s.port : int.tryParse(attrs['port'] ?? '');
    if (port == null || port == 0) return null;

    // Prefer IPv4 (the loopback-tunnel bootstrap and most LANs are v4).
    final ipv4 =
        s.hostAddresses.where((a) => !a.contains(':')).toList(growable: false);
    final hosts = ipv4.isNotEmpty ? ipv4 : s.hostAddresses;
    if (hosts.isEmpty) return null;

    final advertisedName = attrs['name'];
    return DiscoveredServer(
      id: _idFor(s),
      name: (advertisedName != null && advertisedName.isNotEmpty)
          ? advertisedName
          : s.name,
      version: attrs['v'],
      scheme: attrs['scheme'] == 'https' ? 'https' : 'http',
      port: port,
      hostAddresses: hosts,
    );
  }

  String _idFor(BonsoirService s) {
    final id = s.attributes['id'];
    return (id != null && id.isNotEmpty) ? id : s.name;
  }

  void _emit() => _controller.add(current);
}
