import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../objects/server.dart';
import 'federation_admin_api.dart' show FederationAdminException, FederationRequest;

/// `GET /api/v1/admin/discovery/p2p/status`.
class P2pStatus {
  final bool enabled;
  final bool binaryFound;
  final bool binaryFetchable;
  final bool running;
  final String? endpointId;

  /// The sidecar's endpoint address — what a friend pastes to befriend
  /// this server. An address, not a credential.
  final String? ticket;
  final bool joined;
  final int neighbors;
  final double? sidecarRssMb;
  final int sidecarMaxRssMb;
  final int watchdogRestarts;
  final int recoveryAttempts;
  final bool recoveryPending;
  final int knownPeers;
  final bool communitySeeds;
  final String serverName;
  final String serverDescription;
  final int maxPeerDbStorageMb;
  final int autoFetchCount;
  final int rotationDays;
  final int peerRetentionDays;
  final List<String> blockedPeers;

  const P2pStatus({
    required this.enabled,
    required this.binaryFound,
    required this.binaryFetchable,
    required this.running,
    this.endpointId,
    this.ticket,
    required this.joined,
    required this.neighbors,
    this.sidecarRssMb,
    required this.sidecarMaxRssMb,
    required this.watchdogRestarts,
    required this.recoveryAttempts,
    required this.recoveryPending,
    required this.knownPeers,
    required this.communitySeeds,
    required this.serverName,
    required this.serverDescription,
    required this.maxPeerDbStorageMb,
    required this.autoFetchCount,
    required this.rotationDays,
    required this.peerRetentionDays,
    required this.blockedPeers,
  });

  /// The webapp's "meshSearching": on, but no neighbor yet (sidecar
  /// starting, topic joining, or genuinely alone).
  bool get searching => enabled && (!running || !joined || neighbors == 0);

  /// The webapp's "meshRecovering": crash recovery owns the sidecar.
  bool get recovering =>
      enabled && (recoveryAttempts > 0 || recoveryPending) && neighbors == 0;

  /// Neither the prebuilt binary nor a downloadable one.
  bool get unavailable => !binaryFound && !binaryFetchable;

  factory P2pStatus.fromJson(Map j) {
    final w = j['watchdog'] is Map ? j['watchdog'] as Map : const {};
    final r = j['recovery'] is Map ? j['recovery'] as Map : const {};
    return P2pStatus(
      enabled: j['enabled'] == true,
      binaryFound: j['binaryFound'] != false,
      binaryFetchable: j['binaryFetchable'] == true,
      running: j['running'] == true,
      endpointId: j['endpointId'] is String ? j['endpointId'] : null,
      ticket: j['ticket'] is String ? j['ticket'] : null,
      joined: j['joined'] == true,
      neighbors: _int(j['neighbors']) ?? 0,
      sidecarRssMb: _double(w['lastRssMb']),
      sidecarMaxRssMb: _int(w['maxRssMb']) ?? 0,
      watchdogRestarts: _int(w['restarts']) ?? 0,
      recoveryAttempts: _int(r['attempts']) ?? 0,
      recoveryPending: r['retryPending'] == true,
      knownPeers: _int(j['knownPeers']) ?? 0,
      communitySeeds: j['communitySeeds'] == true,
      serverName: j['serverName'] is String ? j['serverName'] : '',
      serverDescription:
          j['serverDescription'] is String ? j['serverDescription'] : '',
      maxPeerDbStorageMb: _int(j['maxPeerDbStorageMb']) ?? 0,
      autoFetchCount: _int(j['autoFetchCount']) ?? 0,
      rotationDays: _int(j['rotationDays']) ?? 0,
      peerRetentionDays: _int(j['peerRetentionDays']) ?? 0,
      blockedPeers: _strings(j['blockedPeers']),
    );
  }
}

/// A downloaded snapshot of a peer's library, as the catalog reports it.
class P2pFetched {
  final int snapshotSeq;
  final bool stale;
  final int sizeBytes;
  final DateTime? fetchedAt;
  final DateTime? firstFetchedAt;
  final bool pinned;
  const P2pFetched({
    required this.snapshotSeq,
    required this.stale,
    required this.sizeBytes,
    this.fetchedAt,
    this.firstFetchedAt,
    required this.pinned,
  });

  factory P2pFetched.fromJson(Map j) => P2pFetched(
        snapshotSeq: _int(j['snapshotSeq']) ?? 0,
        stale: j['stale'] == true,
        sizeBytes: _int(j['sizeBytes']) ?? 0,
        fetchedAt: _iso(j['fetchedAt']),
        firstFetchedAt: _iso(j['firstFetchedAt']),
        pinned: j['pinned'] == true,
      );
}

/// A server heard on the discovery network (a catalog entry with the
/// admin route's live decorations: online, seeders, fetched, compatible).
class P2pPeer {
  /// The origin endpoint id — the key everything else addresses it by.
  final String endpointId;
  final String? name;
  final String? description;
  final int trackCount;
  final String? modelId;
  final int snapshotSeq;
  final DateTime? firstSeenAt;
  final DateTime? updatedAt;
  final bool online;
  final int seeders;
  final P2pFetched? fetched;

  /// null = unknown (this server has no discovery model yet).
  final bool? compatible;

  const P2pPeer({
    required this.endpointId,
    this.name,
    this.description,
    required this.trackCount,
    this.modelId,
    required this.snapshotSeq,
    this.firstSeenAt,
    this.updatedAt,
    required this.online,
    required this.seeders,
    this.fetched,
    this.compatible,
  });

  bool get downloaded => fetched != null;
  bool get updateAvailable => fetched?.stale == true;

  /// The webapp's short form of an unnamed server.
  String get shortId =>
      endpointId.length > 12 ? '${endpointId.substring(0, 12)}…' : endpointId;

  factory P2pPeer.fromJson(Map j) {
    final p = j['payload'] is Map ? j['payload'] as Map : const {};
    return P2pPeer(
      endpointId: j['from'] is String ? j['from'] : '',
      name: p['name'] is String && (p['name'] as String).trim().isNotEmpty
          ? (p['name'] as String).trim()
          : null,
      description: p['description'] is String &&
              (p['description'] as String).trim().isNotEmpty
          ? (p['description'] as String).trim()
          : null,
      trackCount: _int(p['rowCount']) ?? 0,
      modelId: p['modelId'] is String ? p['modelId'] : null,
      snapshotSeq: _int(p['snapshotSeq']) ?? 0,
      firstSeenAt: _iso(j['firstSeenAt']),
      updatedAt: _iso(j['updatedAt']),
      online: j['online'] == true,
      seeders: _int(j['seeders']) ?? 0,
      fetched: j['fetched'] is Map ? P2pFetched.fromJson(j['fetched']) : null,
      compatible: j['compatible'] is bool ? j['compatible'] : null,
    );
  }
}

/// `GET /api/v1/admin/discovery/p2p/catalog`.
class P2pCatalog {
  final List<P2pPeer> peers;
  final int hiddenIncompatible;
  final String? localModelId;
  final bool autoFetch;
  final int storageUsedBytes;
  final int storageCapBytes;
  const P2pCatalog({
    required this.peers,
    required this.hiddenIncompatible,
    this.localModelId,
    required this.autoFetch,
    required this.storageUsedBytes,
    required this.storageCapBytes,
  });

  static const P2pCatalog empty = P2pCatalog(
      peers: [], hiddenIncompatible: 0, autoFetch: false, storageUsedBytes: 0, storageCapBytes: 0);

  List<P2pPeer> get held => peers.where((p) => p.downloaded).toList();
  int get heldTrackTotal => held.fold(0, (n, p) => n + p.trackCount);

  factory P2pCatalog.fromJson(Map j) {
    final s = j['storage'] is Map ? j['storage'] as Map : const {};
    return P2pCatalog(
      peers: [
        for (final p in (j['peers'] is List ? j['peers'] as List : const []))
          if (p is Map) P2pPeer.fromJson(p)
      ],
      hiddenIncompatible: _int(j['hiddenIncompatible']) ?? 0,
      localModelId: j['localModelId'] is String ? j['localModelId'] : null,
      autoFetch: j['autoFetch'] != false,
      storageUsedBytes: _int(s['usedBytes']) ?? 0,
      storageCapBytes: _int(s['capBytes']) ?? 0,
    );
  }
}

/// One line of the sidecar's activity ring.
class P2pActivityEntry {
  final int seq;
  final DateTime? at;
  final String level;
  final String message;
  const P2pActivityEntry(
      {required this.seq, this.at, required this.level, required this.message});

  factory P2pActivityEntry.fromJson(Map j) => P2pActivityEntry(
        seq: _int(j['seq']) ?? 0,
        at: _iso(j['t'] ?? j['time'] ?? j['at']),
        level: j['level'] is String ? j['level'] : 'info',
        message: j['message'] is String ? j['message'] : '',
      );
}

class P2pActivity {
  final List<P2pActivityEntry> entries;
  final int lastSeq;
  const P2pActivity({required this.entries, required this.lastSeq});
}

/// What enabling returned: the inbox half can fail on its own.
class P2pEnableResult {
  final bool enabled;
  final bool acceptRequests;
  final String? federationError;
  const P2pEnableResult(
      {required this.enabled, required this.acceptRequests, this.federationError});
}

/// The relationship a catalog entry has with this server through the
/// federation-request engine — the webapp's `fedReqStateFor`.
enum P2pFederationState { federated, theirs, sent, none }

P2pFederationState federationStateFor(
    Iterable<FederationRequest> requests, String endpointId) {
  final rows = requests.where((r) => r.peerEndpointId == endpointId).toList();
  if (rows.any((r) => r.state == 'completed')) return P2pFederationState.federated;
  if (rows.any((r) =>
      r.inbound && const {'received', 'accepted', 'granting'}.contains(r.state))) {
    return P2pFederationState.theirs;
  }
  if (rows.any((r) =>
      !r.inbound &&
      const {'pending-delivery', 'delivered', 'granting'}.contains(r.state))) {
    return P2pFederationState.sent;
  }
  return P2pFederationState.none;
}

/// The admin half of the discovery network, spoken to the server being
/// browsed: status, the catalog of servers heard, snapshots, befriending,
/// blocking, the knobs. Same transport rules as [FederationAdminApi]; the
/// admin guard's verdicts arrive as [FederationAdminException].
class P2pAdminApi {
  final Server server;
  final http.Client _client;
  final Duration timeout;

  P2pAdminApi(this.server,
      {http.Client? client, this.timeout = const Duration(seconds: 12)})
      : _client = client ?? http.Client();

  static const _base = '/api/v1/admin/discovery/p2p';

  Future<P2pStatus> status() async =>
      P2pStatus.fromJson(await _get('$_base/status') as Map);

  Future<P2pCatalog> catalog({bool includeIncompatible = false}) async =>
      P2pCatalog.fromJson(await _get(
          '$_base/catalog${includeIncompatible ? '?includeIncompatible=1' : ''}') as Map);

  Future<P2pActivity> activity({int since = 0}) async {
    final res = await _get('$_base/activity?since=$since');
    final raw = res is Map ? res['entries'] : null;
    return P2pActivity(
      entries: [
        for (final e in (raw is List ? raw : const []))
          if (e is Map) P2pActivityEntry.fromJson(e)
      ],
      lastSeq: res is Map ? (_int(res['lastSeq']) ?? since) : since,
    );
  }

  /// Join (or leave) the network. [acceptFederationRequests] is the
  /// consent screen's opt-in: it turns the federation request inbox on in
  /// the same call, and the answer says whether that half worked.
  Future<P2pEnableResult> setEnabled(bool enabled,
      {bool acceptFederationRequests = false}) async {
    final res = await _post('$_base/enabled', {
      'enabled': enabled,
      if (enabled && acceptFederationRequests) 'acceptFederationRequests': true,
    });
    final m = res is Map ? res : const {};
    return P2pEnableResult(
      enabled: m['enabled'] != false,
      acceptRequests: m['acceptRequests'] == true,
      federationError:
          m['federationError'] is String ? m['federationError'] : null,
    );
  }

  /// Befriend a server by its endpoint ticket; [persist] keeps it in the
  /// config so the friendship survives restarts.
  Future<void> join(String ticket, {bool persist = true}) =>
      _post('$_base/join', {'peer': ticket.trim(), 'persist': persist});

  Future<void> fetchSnapshot(String endpointId) =>
      _post('$_base/peer-dbs/fetch', {'endpointId': endpointId});

  Future<void> pinSnapshot(String endpointId, bool pinned) =>
      _post('$_base/peer-dbs/pin', {'endpointId': endpointId, 'pinned': pinned});

  Future<void> removeSnapshot(String endpointId) =>
      _post('$_base/peer-dbs/remove', {'endpointId': endpointId});

  Future<void> forget(String endpointId) =>
      _post('$_base/forget', {'endpointId': endpointId});

  Future<void> block(String endpointId) =>
      _post('$_base/block', {'endpointId': endpointId});

  Future<void> unblock(String endpointId) =>
      _post('$_base/unblock', {'endpointId': endpointId});

  Future<void> setName(String name) => _post('$_base/name', {'name': name.trim()});

  Future<void> setDescription(String description) =>
      _post('$_base/description', {'description': description.trim()});

  Future<void> setMaxStorageMb(int mb) =>
      _post('$_base/max-storage', {'maxPeerDbStorageMb': mb});

  Future<void> setAutoFetchCount(int n) =>
      _post('$_base/auto-fetch-count', {'autoFetchCount': n});

  Future<void> setRotationDays(int days) =>
      _post('$_base/rotation', {'rotationDays': days});

  Future<void> setPeerRetentionDays(int days) =>
      _post('$_base/peer-retention', {'peerRetentionDays': days});

  // ── transport ───────────────────────────────────────────────────────
  Map<String, String> get _headers => {
        'x-access-token': server.authToken ?? '',
        'Content-Type': 'application/json',
      };

  Future<dynamic> _get(String path) async => _decode(
      await _client.get(server.apiUri(path), headers: _headers).timeout(timeout));

  Future<dynamic> _post(String path, [Map<String, dynamic>? body]) async =>
      _decode(await _client
          .post(server.apiUri(path), headers: _headers, body: jsonEncode(body ?? const {}))
          .timeout(timeout));

  dynamic _decode(http.Response res) {
    dynamic body;
    if (res.body.isNotEmpty) {
      try {
        body = jsonDecode(res.body);
      } catch (_) {
        body = null;
      }
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = body is Map && body['error'] is String
          ? body['error'] as String
          : 'HTTP ${res.statusCode}';
      throw FederationAdminException(res.statusCode, msg);
    }
    return body;
  }
}

int? _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? _double(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

DateTime? _iso(dynamic v) {
  if (v is! String || v.isEmpty) return null;
  var s = v.trim();
  if (s.length >= 19 && s[10] == ' ') s = '${s.replaceFirst(' ', 'T')}Z';
  return DateTime.tryParse(s)?.toLocal();
}

List<String> _strings(dynamic v) =>
    v is List ? [for (final x in v) if (x is String) x] : const [];

/// A downloaded peer library as any signed-in user may see it
/// (`GET /api/v1/discovery/p2p/peer-dbs`): what the Discover panel's
/// "From the network" section searches.
class P2pHeldLibrary {
  final String name;
  final int trackCount;
  final DateTime? fetchedAt;
  const P2pHeldLibrary({required this.name, required this.trackCount, this.fetchedAt});
}

Future<List<P2pHeldLibrary>> fetchHeldLibraries(Server server,
    {http.Client? client, Duration timeout = const Duration(seconds: 10)}) async {
  final c = client ?? http.Client();
  final res = await c
      .get(server.apiUri('/api/v1/discovery/p2p/peer-dbs'),
          headers: {'x-access-token': server.authToken ?? ''})
      .timeout(timeout);
  if (res.statusCode != 200) {
    throw FederationAdminException(res.statusCode, 'HTTP ${res.statusCode}');
  }
  final body = jsonDecode(res.body);
  final raw = body is Map ? body['peerDbs'] : null;
  return [
    for (final e in (raw is List ? raw : const []))
      if (e is Map)
        P2pHeldLibrary(
          name: e['name'] is String && (e['name'] as String).isNotEmpty
              ? e['name']
              : '',
          trackCount: _int(e['rowCount']) ?? 0,
          fetchedAt: _iso(e['fetchedAt']),
        ),
  ];
}
