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

  static String _origin(String scheme, String host, int port) {
    // An IPv6 literal must be bracketed in a URL, and Android reports
    // link-local addresses with a %zone suffix no URL parser accepts —
    // strip it (an unroutable address just fails its probe and the next
    // candidate is tried).
    final h = host.contains(':') ? '[${host.split('%').first}]' : host;
    return '$scheme://$h:$port';
  }

  /// LAN origin to bootstrap against, e.g. `http://192.168.1.50:3000`. Null
  /// when no usable address resolved yet. The FIRST of [baseUrls]; connect via
  /// that whole list so a multi-homed host (a WSL/Docker/VPN virtual adapter
  /// advertises its own unroutable IP too) is reached on whichever address
  /// actually answers.
  String? get baseUrl => baseUrls.isEmpty ? null : baseUrls.first;

  /// Every advertised address as a candidate origin, IPv4 first (the loopback
  /// tunnel bootstrap and most LANs are v4). Probe them in order.
  List<String> get baseUrls =>
      hostAddresses.map((h) => _origin(scheme, h, port)).toList();
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

  // Services found but not yet resolved, keyed by name+type. Android's NSD
  // resolver is a single system-wide slot shared with every other app, so a
  // resolve request routinely fails with BUSY. bonsoir reports the failure
  // (sans service — upstream drops it) but keeps the service in its found
  // list, so simply asking again works. Without a retry the tile silently
  // never appears until the user hits refresh.
  final Map<String, BonsoirService> _pendingResolves = {};
  final Map<String, int> _resolveAttempts = {};
  static const int _maxResolveAttempts = 5;

  // Android's NSD resolve can also HANG outright (observed on-device: the
  // system's resolve request sat active for 2+ minutes, no callback), and
  // bonsoir's resolve queue only drains on a callback — so one hung resolve
  // wedges discovery until it's torn down. The watchdog does automatically
  // what the user's refresh button does: if anything found stays unresolved
  // past _resolveTimeout, restart discovery (bounded by _maxAutoRestarts,
  // reset on the next manual start/refresh).
  final Map<String, DateTime> _pendingSince = {};
  Timer? _watchdog;
  int _autoRestarts = 0;
  static const int _maxAutoRestarts = 3;
  static const Duration _resolveTimeout = Duration(seconds: 7);

  // Keyed by DiscoveredServer.id so a server re-announcing (or changing IP)
  // updates in place instead of duplicating.
  final Map<String, DiscoveredServer> _servers = {};
  final StreamController<List<DiscoveredServer>> _controller =
      StreamController<List<DiscoveredServer>>.broadcast();

  /// Live list of discovered iroh servers; emits on every change.
  ///
  /// Replays the current snapshot to every new subscriber before the live
  /// events. Discovery starts when the screen opens but the Quick Connect
  /// tab's StreamBuilder subscribes later (tab switch) — a resolve landing in
  /// that window was emitted with no listener and a broadcast stream never
  /// replays, so the tile stayed on "Searching…" until a manual refresh
  /// (verified on-device). The snapshot-on-listen closes that window.
  ///
  /// Stream.multi, NOT async*: a generator is single-subscription, and the
  /// tab's StreamBuilder widget (created once per screen build) re-listens to
  /// the SAME stream object when TabBarView remounts the tab — leaving and
  /// re-entering Quick Connect then threw "Stream has already been listened
  /// to". Stream.multi runs this callback per listener instead.
  Stream<List<DiscoveredServer>> get stream => Stream.multi((listener) {
        listener.add(current);
        final sub = _controller.stream.listen(
          listener.add,
          onError: listener.addError,
          onDone: listener.close,
        );
        listener.onCancel = sub.cancel;
      });

  /// Snapshot for seeding a StreamBuilder before the first event.
  List<DiscoveredServer> get current => _servers.values.toList();

  /// True only on builds that can actually pair an iroh tunnel.
  bool get isSupported => IrohTunnel.isSupported;

  /// Begin browsing. Idempotent; a no-op on unsupported builds.
  Future<void> start() async {
    if (!isSupported || _discovery != null) return;
    _autoRestarts = 0; // a fresh user-driven start earns a new restart budget
    await _startInternal();
  }

  Future<void> _startInternal() async {
    if (!isSupported || _discovery != null) return;
    try {
      final discovery = BonsoirDiscovery(type: _serviceType);
      _discovery = discovery;
      await discovery.initialize();
      _sub = discovery.eventStream?.listen(_onEvent, onError: _onError);
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
    _watchdog?.cancel();
    _watchdog = null;
    _pendingResolves.clear();
    _resolveAttempts.clear();
    _pendingSince.clear();
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

  // The watchdog's restart: same teardown, but keeps the bounded
  // auto-restart count (start() resets it; this must not).
  Future<void> _autoRestart() async {
    appLog('[lan-discovery] resolve stuck ${_resolveTimeout.inSeconds}s — '
        'restarting discovery (${_autoRestarts + 1}/$_maxAutoRestarts)');
    _autoRestarts++;
    await stop();
    await _startInternal();
  }

  void _onEvent(BonsoirDiscoveryEvent event) {
    // A found service carries no host/port/TXT yet — ask the platform to resolve
    // it; the resolved event below has the details.
    if (event is BonsoirDiscoveryServiceFoundEvent) {
      appLog('[lan-discovery] found: ${event.service.name}');
      final key = _resolveKey(event.service);
      _pendingResolves[key] = event.service;
      _resolveAttempts[key] = 1;
      _pendingSince[key] = DateTime.now();
      _armWatchdog();
      _requestResolve(event.service);
      return;
    }
    // Updated fires when a resolved service's address/port/TXT change (DHCP
    // move, late TXT records on Android 14+) — treat it exactly like a fresh
    // resolve so tiles never go stale. A service whose update dropped iroh=1
    // (or lost its address) is removed rather than kept with dead data.
    if (event is BonsoirDiscoveryServiceResolvedEvent ||
        event is BonsoirDiscoveryServiceUpdatedEvent) {
      final s = event.service; // base-class getter is nullable
      if (s == null) return;
      appLog('[lan-discovery] ${event is BonsoirDiscoveryServiceResolvedEvent ? "resolved" : "updated"}: '
          '${s.name} port=${s.port} hosts=${s.hostAddresses} attrs=${s.attributes}');
      final key = _resolveKey(s);
      _pendingResolves.remove(key);
      _resolveAttempts.remove(key);
      _pendingSince.remove(key);
      _autoRestarts = 0; // discovery is demonstrably healthy again
      final server = _fromService(s);
      if (server != null) {
        _servers[server.id] = server;
        _emit();
      } else if (_servers.remove(_idFor(s)) != null) {
        _emit();
      }
      return;
    }
    // The failed event doesn't say WHICH service failed (upstream constructs
    // it without the service), so retry every still-pending one — on this
    // screen that's essentially always the one server just found.
    if (event is BonsoirDiscoveryServiceResolveFailedEvent) {
      appLog('[lan-discovery] resolve failed (${_pendingResolves.length} pending)');
      _retryPendingResolves();
      return;
    }
    if (event is BonsoirDiscoveryServiceLostEvent) {
      final key = _resolveKey(event.service);
      _pendingResolves.remove(key);
      _resolveAttempts.remove(key);
      _pendingSince.remove(key);
      final id = _idFor(event.service);
      if (_servers.remove(id) != null) _emit();
    }
  }

  // Fires while anything is pending; a pending entry older than
  // _resolveTimeout means the platform resolve hung — restart discovery.
  void _armWatchdog() {
    _watchdog ??= Timer.periodic(Duration(seconds: 3), (_) {
      if (_pendingSince.isEmpty) {
        _watchdog?.cancel();
        _watchdog = null;
        return;
      }
      if (_autoRestarts >= _maxAutoRestarts) return;
      final now = DateTime.now();
      final stuck = _pendingSince.values
          .any((t) => now.difference(t) > _resolveTimeout);
      if (stuck) unawaited(_autoRestart());
    });
  }

  // Ask the platform to resolve, tolerating a torn-down discovery (a late
  // event can arrive while stop() is mid-flight).
  void _requestResolve(BonsoirService s) {
    final discovery = _discovery;
    if (discovery == null) return;
    try {
      s.resolve(discovery.serviceResolver);
    } catch (e) {
      appLog('[lan-discovery] resolve request failed: $e');
    }
  }

  // Re-request resolution for everything still pending, with backoff
  // (500ms, 1s, 2s, 4s) and an attempt cap so a permanently hogged system
  // resolver can't loop forever. Guarded on the discovery generation: a
  // stop()/refresh() in the meantime invalidates the scheduled retry.
  void _retryPendingResolves() {
    final discovery = _discovery;
    if (discovery == null) return;
    for (final entry in _pendingResolves.entries.toList()) {
      final attempts = _resolveAttempts[entry.key] ?? 0;
      if (attempts >= _maxResolveAttempts) continue;
      _resolveAttempts[entry.key] = attempts + 1;
      final delay = Duration(milliseconds: 500 * (1 << (attempts - 1)));
      Timer(delay, () {
        if (_discovery != discovery) return; // stopped/refreshed meanwhile
        if (!_pendingResolves.containsKey(entry.key)) return; // resolved already
        _requestResolve(entry.value);
      });
    }
  }

  String _resolveKey(BonsoirService s) => '${s.name}.${s.type}';

  // bonsoir surfaces native NSD failures as STREAM errors (a failed discovery
  // start even self-disposes on the native side). Without a handler they're
  // unhandled async errors AND the Dart side still believes it's browsing
  // (_discovery non-null) — start() would no-op forever while the UI spins on
  // "Searching…". Reset, so the next start()/refresh() genuinely restarts.
  void _onError(Object e) {
    appLog('[lan-discovery] error: $e');
    unawaited(stop());
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
