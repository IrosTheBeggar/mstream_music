import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../objects/server.dart';

/// What the admin federation routes told us about the caller, read off the
/// first status call: the panel renders the admin sections only for
/// [admin], and says why not for the rest.
enum FederationAccess {
  admin,

  /// Signed in fine, not an admin (403 "Admin access required").
  member,

  /// An admin, but the server only takes admin calls from its own network
  /// (403 "Admin access restricted to local network").
  restricted,

  /// The whole admin API is switched off on this server (405).
  disabled,

  /// A server without the federation admin routes (404).
  unsupported,
}

/// A non-2xx answer from an admin route, with the server's own message when
/// it sent one (`{ error: … }`).
class FederationAdminException implements Exception {
  final int status;
  final String message;
  const FederationAdminException(this.status, this.message);

  /// The access verdict this failure implies, or null when it is an
  /// ordinary error (400 validation, 409 conflict, 500).
  FederationAccess? get access {
    switch (status) {
      case 403:
        return message.toLowerCase().contains('network')
            ? FederationAccess.restricted
            : FederationAccess.member;
      case 405:
        return FederationAccess.disabled;
      case 404:
        return FederationAccess.unsupported;
      default:
        return null;
    }
  }

  @override
  String toString() => 'HTTP $status: $message';
}

/// Bandwidth caps on a key. 0 = unlimited, in every field.
class FederationLimits {
  final int streamKbps;
  final int dailyMb;
  final int maxStreams;
  const FederationLimits({
    required this.streamKbps,
    required this.dailyMb,
    required this.maxStreams,
  });

  /// The webapp's fallback when a server reports no defaults.
  static const FederationLimits fallback =
      FederationLimits(streamKbps: 8000, dailyMb: 2048, maxStreams: 3);

  /// From the camelCase shape (status `limitDefaults`, request bodies).
  factory FederationLimits.fromJson(dynamic j) {
    if (j is! Map) return fallback;
    return FederationLimits(
      streamKbps: _int(j['streamKbps']) ?? fallback.streamKbps,
      dailyMb: _int(j['dailyMb']) ?? fallback.dailyMb,
      maxStreams: _int(j['maxStreams']) ?? fallback.maxStreams,
    );
  }

  /// From a key row (snake_case columns).
  factory FederationLimits.fromRow(Map j) => FederationLimits(
        streamKbps: _int(j['stream_kbps']) ?? 0,
        dailyMb: _int(j['daily_mb']) ?? 0,
        maxStreams: _int(j['max_streams']) ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'streamKbps': streamKbps,
        'dailyMb': dailyMb,
        'maxStreams': maxStreams,
      };

  FederationLimits copyWith({int? streamKbps, int? dailyMb, int? maxStreams}) =>
      FederationLimits(
        streamKbps: streamKbps ?? this.streamKbps,
        dailyMb: dailyMb ?? this.dailyMb,
        maxStreams: maxStreams ?? this.maxStreams,
      );

  @override
  bool operator ==(Object other) =>
      other is FederationLimits &&
      other.streamKbps == streamKbps &&
      other.dailyMb == dailyMb &&
      other.maxStreams == maxStreams;

  @override
  int get hashCode => Object.hash(streamKbps, dailyMb, maxStreams);
}

/// `GET /api/v1/admin/federation`.
class FederationStatus {
  final bool enabled;

  /// False when the iroh component has no build for the server's platform.
  final bool available;
  final bool running;
  final bool online;
  final String? endpointId;
  final String? relayUrl;
  final FederationLimits limitDefaults;
  final bool acceptRequests;
  const FederationStatus({
    required this.enabled,
    required this.available,
    required this.running,
    required this.online,
    this.endpointId,
    this.relayUrl,
    required this.limitDefaults,
    required this.acceptRequests,
  });

  factory FederationStatus.fromJson(Map j) => FederationStatus(
        enabled: j['enabled'] == true,
        available: j['available'] != false,
        running: j['running'] == true,
        online: j['online'] == true,
        endpointId: j['endpointId'] is String ? j['endpointId'] : null,
        relayUrl: j['relayUrl'] is String ? j['relayUrl'] : null,
        limitDefaults: FederationLimits.fromJson(j['limitDefaults']),
        acceptRequests: j['acceptRequests'] == true,
      );
}

/// A minted key (a ticket you handed out), `GET /api/v1/admin/federation/keys`.
class FederationKey {
  final int id;
  final String name;
  final List<String> libraryNames;
  final FederationLimits limits;
  final DateTime? expiresAt;
  final bool expired;
  final int usageTodayBytes;
  final DateTime? lastUsed;
  final DateTime? createdAt;

  /// The endpoint that redeemed the ticket (TOFU); null until claimed.
  final String? boundEndpointId;
  final DateTime? boundAt;

  /// The full ticket to send — null while the federation endpoint is not
  /// running (there is no endpoint ticket to wrap the key in).
  final String? ticket;

  const FederationKey({
    required this.id,
    required this.name,
    required this.libraryNames,
    required this.limits,
    this.expiresAt,
    this.expired = false,
    this.usageTodayBytes = 0,
    this.lastUsed,
    this.createdAt,
    this.boundEndpointId,
    this.boundAt,
    this.ticket,
  });

  bool get claimed => boundEndpointId != null;

  /// Reads the list row (snake_case columns, `library_names`) and the
  /// mint response (camelCase limits, `libraries`) alike.
  factory FederationKey.fromJson(Map j) => FederationKey(
        id: _int(j['id']) ?? 0,
        name: j['name'] is String ? j['name'] : '',
        libraryNames: _strings(j['library_names'] ?? j['libraries'] ?? j['vpaths']),
        limits: j.containsKey('stream_kbps')
            ? FederationLimits.fromRow(j)
            : FederationLimits.fromJson(j),
        expiresAt: sqliteUtc(j['expires_at'] ?? j['expiresAt']),
        expired: j['expired'] == 1 || j['expired'] == true,
        usageTodayBytes: _int(j['usage_today_bytes']) ?? 0,
        lastUsed: sqliteUtc(j['last_used']),
        createdAt: sqliteUtc(j['created_at']),
        boundEndpointId:
            j['bound_endpoint_id'] is String ? j['bound_endpoint_id'] : null,
        boundAt: sqliteUtc(j['bound_at']),
        ticket: j['ticket'] is String ? j['ticket'] : null,
      );
}

/// A server this one can read, as the admin sees it
/// (`GET /api/v1/admin/federation/peers`). The row id is the same id the
/// app's peer mirror keys on ([Server.federationPeerId]).
class FederationPeerRow {
  final int id;
  final String name;

  /// 'ok', an error summary, or null when never tested.
  final String? lastStatus;
  final DateTime? lastSeen;
  final bool useDiscovery;
  final DateTime? addedAt;
  const FederationPeerRow({
    required this.id,
    required this.name,
    this.lastStatus,
    this.lastSeen,
    this.useDiscovery = false,
    this.addedAt,
  });

  bool get reachable => lastStatus == 'ok';

  factory FederationPeerRow.fromJson(Map j) => FederationPeerRow(
        id: _int(j['id']) ?? 0,
        name: j['name'] is String ? j['name'] : '',
        lastStatus: j['last_status'] is String ? j['last_status'] : null,
        lastSeen: sqliteUtc(j['last_seen']),
        useDiscovery: j['use_discovery'] == 1 || j['use_discovery'] == true,
        addedAt: sqliteUtc(j['added_at']),
      );
}

/// `POST /api/v1/admin/federation/peers/:id/test`.
class FederationPeerTest {
  final bool ok;
  final String? error;
  final FederationPeerRow? peer;
  const FederationPeerTest({required this.ok, this.error, this.peer});

  factory FederationPeerTest.fromJson(Map j) => FederationPeerTest(
        ok: j['ok'] == true,
        error: j['error'] is String ? j['error'] : null,
        peer: j['peer'] is Map ? FederationPeerRow.fromJson(j['peer']) : null,
      );
}

/// A pairing request over the discovery network (V67), either direction.
class FederationRequest {
  final int id;

  /// 'in' (they asked us) or 'out' (we asked them).
  final String direction;
  final String state;
  final String? peerName;
  final String peerEndpointId;
  final String? message;
  final List<String> offeredLibraries;
  final String? rejectReason;
  final DateTime? nextAttemptAt;
  final DateTime? createdAt;
  final int? createdPeerId;
  const FederationRequest({
    required this.id,
    required this.direction,
    required this.state,
    this.peerName,
    required this.peerEndpointId,
    this.message,
    this.offeredLibraries = const [],
    this.rejectReason,
    this.nextAttemptAt,
    this.createdAt,
    this.createdPeerId,
  });

  bool get inbound => direction == 'in';

  /// Needs the admin's answer right now.
  bool get awaitingAnswer => inbound && state == 'received';

  /// A live exchange (the engine's non-terminal states).
  bool get isActive => const {
        'received', 'pending-delivery', 'delivered', 'accepted', 'granting'
      }.contains(state);

  /// An outbound ask that can still be withdrawn.
  bool get canCancel =>
      !inbound && (state == 'pending-delivery' || state == 'delivered');

  factory FederationRequest.fromJson(Map j) => FederationRequest(
        id: _int(j['id']) ?? 0,
        direction: j['direction'] is String ? j['direction'] : 'in',
        state: j['state'] is String ? j['state'] : '',
        peerName: j['peer_name'] is String ? j['peer_name'] : null,
        peerEndpointId:
            j['peer_endpoint_id'] is String ? j['peer_endpoint_id'] : '',
        message: j['message'] is String ? j['message'] : null,
        offeredLibraries: _strings(j['offered_libraries']),
        rejectReason: j['reject_reason'] is String ? j['reject_reason'] : null,
        nextAttemptAt: sqliteUtc(j['next_attempt_at']),
        createdAt: sqliteUtc(j['created_at']),
        createdPeerId: _int(j['created_peer_id']),
      );
}

/// `GET /api/v1/admin/federation/requests`.
class FederationRequests {
  final List<FederationRequest> requests;
  final bool acceptRequests;
  const FederationRequests({required this.requests, required this.acceptRequests});
}

/// The admin half of federation, spoken to the parent server (never a
/// peer): status and switches, keys (tickets you minted), peers (servers
/// you read), pairing requests. Every call is one route; the screens hold
/// the state. Injectable [client] for tests.
class FederationAdminApi {
  final Server server;
  final http.Client _client;
  final Duration timeout;

  FederationAdminApi(this.server,
      {http.Client? client, this.timeout = const Duration(seconds: 12)})
      : _client = client ?? http.Client();

  // ── status ──────────────────────────────────────────────────────────
  Future<FederationStatus> status() async =>
      FederationStatus.fromJson(await _get('/api/v1/admin/federation') as Map);

  Future<void> setEnabled(bool enabled) =>
      _post('/api/v1/admin/federation', {'enabled': enabled});

  Future<void> setAcceptRequests(bool enabled) =>
      _post('/api/v1/admin/federation/accept-requests', {'enabled': enabled});

  /// The server's libraries by name (`GET /api/v1/admin/directories` keys):
  /// what a ticket can grant.
  Future<List<String>> libraries() async {
    final res = await _get('/api/v1/admin/directories');
    if (res is! Map) return const [];
    return [for (final k in res.keys) if (k is String) k];
  }

  // ── keys ────────────────────────────────────────────────────────────
  Future<List<FederationKey>> keys() async {
    final res = await _get('/api/v1/admin/federation/keys');
    return [
      for (final k in (res is List ? res : const []))
        if (k is Map) FederationKey.fromJson(k)
    ];
  }

  Future<FederationKey> mint({
    required String name,
    required List<String> vpaths,
    required FederationLimits limits,
    DateTime? expiresAt,
  }) async {
    final res = await _post('/api/v1/admin/federation/keys', {
      'name': name,
      'vpaths': vpaths,
      ...limits.toJson(),
      if (expiresAt != null) 'expiresAt': expiresAt.toUtc().toIso8601String(),
    });
    final minted = FederationKey.fromJson(res is Map ? res : const {});
    // The list row is the canonical shape (usage, claim state, the same
    // ticket); read it back so the ticket screen shows the row the list
    // will show. The mint response stands in if the re-read fails.
    try {
      for (final k in await keys()) {
        if (k.id == minted.id) return k;
      }
    } catch (_) {}
    return minted;
  }

  /// Live limit edit. [expiresAt] null with [clearExpiry] false leaves the
  /// expiry alone; [clearExpiry] true makes the key never expire.
  Future<void> setKeyLimits(int id, FederationLimits limits,
      {DateTime? expiresAt, bool clearExpiry = false}) {
    return _post('/api/v1/admin/federation/keys/$id/limits', {
      ...limits.toJson(),
      if (expiresAt != null)
        'expiresAt': expiresAt.toUtc().toIso8601String()
      else if (clearExpiry)
        'expiresAt': null,
    });
  }

  Future<void> revokeKey(int id) => _delete('/api/v1/admin/federation/keys/$id');

  Future<void> resetBinding(int id) =>
      _post('/api/v1/admin/federation/keys/$id/reset-binding');

  // ── requests ────────────────────────────────────────────────────────
  Future<FederationRequests> requests() async {
    final res = await _get('/api/v1/admin/federation/requests');
    final raw = res is Map ? res['requests'] : null;
    return FederationRequests(
      requests: [
        for (final r in (raw is List ? raw : const []))
          if (r is Map) FederationRequest.fromJson(r)
      ],
      acceptRequests: res is Map && res['acceptRequests'] == true,
    );
  }

  Future<void> acceptRequest(int id,
      {required List<String> vpaths,
      required FederationLimits limits,
      DateTime? expiresAt,
      bool acceptTheirOffer = true}) {
    return _post('/api/v1/admin/federation/requests/$id/accept', {
      'vpaths': vpaths,
      ...limits.toJson(),
      if (expiresAt != null) 'expiresAt': expiresAt.toUtc().toIso8601String(),
      'acceptTheirOffer': acceptTheirOffer,
    });
  }

  Future<void> rejectRequest(int id, {String? reason}) =>
      _post('/api/v1/admin/federation/requests/$id/reject',
          {if (reason != null && reason.isNotEmpty) 'reason': reason});

  Future<void> cancelRequest(int id) =>
      _post('/api/v1/admin/federation/requests/$id/cancel');

  Future<void> dismissRequest(int id) =>
      _delete('/api/v1/admin/federation/requests/$id');

  // ── peers ───────────────────────────────────────────────────────────
  Future<List<FederationPeerRow>> peers() async {
    final res = await _get('/api/v1/admin/federation/peers');
    return [
      for (final p in (res is List ? res : const []))
        if (p is Map) FederationPeerRow.fromJson(p)
    ];
  }

  Future<FederationPeerRow> addPeer({required String ticket, String? name}) async {
    final res = await _post('/api/v1/admin/federation/peers', {
      'ticket': ticket,
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
    });
    return FederationPeerRow.fromJson(res is Map ? res : const {});
  }

  Future<FederationPeerTest> testPeer(int id) async {
    final res = await _post('/api/v1/admin/federation/peers/$id/test');
    return FederationPeerTest.fromJson(res is Map ? res : const {});
  }

  Future<void> setPeerDiscovery(int id, bool enabled) =>
      _post('/api/v1/admin/federation/peers/$id/discovery', {'enabled': enabled});

  Future<void> removePeer(int id) => _delete('/api/v1/admin/federation/peers/$id');

  // ── transport ───────────────────────────────────────────────────────
  Map<String, String> get _headers => {
        'x-access-token': server.authToken ?? '',
        'Content-Type': 'application/json',
      };

  Future<dynamic> _get(String path) async =>
      _decode(await _client.get(server.apiUri(path), headers: _headers).timeout(timeout));

  Future<dynamic> _post(String path, [Map<String, dynamic>? body]) async =>
      _decode(await _client
          .post(server.apiUri(path), headers: _headers, body: jsonEncode(body ?? const {}))
          .timeout(timeout));

  Future<dynamic> _delete(String path) async =>
      _decode(await _client.delete(server.apiUri(path), headers: _headers).timeout(timeout));

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

/// SQLite's `datetime('now')` text (`YYYY-MM-DD HH:MM:SS`, UTC) or an ISO
/// string, as a local DateTime; null for anything else.
DateTime? sqliteUtc(dynamic v) {
  if (v is! String || v.isEmpty) return null;
  var s = v.trim();
  if (s.length >= 19 && s[10] == ' ') s = '${s.replaceFirst(' ', 'T')}Z';
  return DateTime.tryParse(s)?.toLocal();
}

int? _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

List<String> _strings(dynamic v) =>
    v is List ? [for (final x in v) if (x is String) x] : const [];
