import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../objects/discovery_plugins.dart';
import '../objects/server.dart';
import '../singletons/api.dart';
import 'discover_badges.dart' show lookupChunks;

/// A non-2xx answer from a plug-in route, or a call that never got one.
///
/// [message] is the server's own `{ error }` text, verbatim ([fromServer]
/// true) — "Uploading Disabled", "someone else on this server is already
/// getting this — try again in a moment", "you have 20 jobs queued or
/// running — …" — so the UI can show it as the server said it. Without one
/// it is `HTTP <status>`, or the transport's failure ([status] 0).
class DiscoveryPluginsException implements Exception {
  final int status;
  final String message;
  final bool fromServer;
  const DiscoveryPluginsException(this.status, this.message,
      {this.fromServer = false});

  /// The plug-in route is not there for this caller (plug-ins off since the
  /// ping, a jukebox session, an older server): 403 / 404.
  bool get absent => status == 403 || status == 404;

  @override
  String toString() => 'DiscoveryPluginsException($status: $message)';
}

/// The user's OWN server for [server]: itself, or — for a connected
/// server's virtual Server — its parent. Every plug-in route is the
/// parent's (the plug-ins act on a recommendation the parent's taste route
/// handed out), never a peer's.
Server? ownServerOf(Server? server) {
  if (server == null) return null;
  return server.isFederated ? server.parentServer : server;
}

/// The discovery plug-in routes (mStream docs/openapi.yaml, tags
/// "Discovery"): the listing, the copy jobs, the batch lookup, the
/// collection destination and the links plug-in's resolve.
///
/// Spoken to the user's own server ([ownServerOf]) over ApiManager's pooled
/// direct client — the transport the Discover page's taste call uses —
/// unless a client is injected (tests). Headless (no browser loading bar),
/// bounded by [timeout]; every failure throws [DiscoveryPluginsException]
/// carrying the server's words.
///
/// Recommendations are sent exactly as received — a taste peers row is
/// already a valid recommendation (the route's schema strips what it does
/// not know: seedHash, similarity, genreTags, albumArt).
class DiscoveryPluginsApi {
  /// The user's own server; null when [ownServerOf] found none (a connected
  /// server whose parent is not linked) — every call then throws.
  final Server? server;

  /// An injected client (tests); null = ApiManager's pooled one.
  final http.Client? client;
  final Duration timeout;

  DiscoveryPluginsApi(Server? server,
      {this.client, this.timeout = const Duration(seconds: 15)})
      : server = ownServerOf(server);

  http.Client get _http => client ?? ApiManager().directClient;

  // ── the listing ─────────────────────────────────────────────────────

  /// `GET /api/v1/discovery/plugins`.
  Future<PluginListing> plugins() async =>
      PluginListing.fromServerMap(_map(await _get('/api/v1/discovery/plugins')));

  // ── the collection destination ──────────────────────────────────────

  /// `GET /api/v1/discovery/collection/destination`.
  Future<DestinationView> destination() async => DestinationView.fromServerMap(
      _map(await _get('/api/v1/discovery/collection/destination')));

  /// `PUT /api/v1/discovery/collection/destination` — [destination] null
  /// goes back to the library default. A 400 carries the server's reason
  /// ("destination layout: …").
  Future<DestinationView> saveDestination(
          CollectionDestination? destination) async =>
      DestinationView.fromServerMap(_map(await _send(
          'PUT', '/api/v1/discovery/collection/destination',
          {'destination': destination?.toJson()})));

  // ── jobs ────────────────────────────────────────────────────────────

  /// `POST /api/v1/discovery/plugins/:name/jobs` {recommendation, scope?}:
  /// 202 with a new job, or 200 with the caller's own live job for the same
  /// key (for an album or artist scope that may be another connected
  /// server's copy — the keys carry no server). A song job sends no scope.
  /// Refused with 400 (a scope's field missing), 403 (jobs gate, "Uploading
  /// Disabled"), 404 (plug-in missing or unavailable), 409 (another
  /// account's live job for the key) or 429 (the queue cap).
  Future<StartedJob> startJob(Map<String, dynamic> recommendation,
      {String plugin = kCopyPlugin, String? scope}) async {
    final res = _map(await _send('POST', '/api/v1/discovery/plugins/$plugin/jobs', {
      'recommendation': recommendation,
      if (scope != null && scope != kScopeSong) 'scope': scope,
    }));
    final job = DiscoveryJob.fromServerMap(res['job']);
    if (job == null) {
      throw const DiscoveryPluginsException(0, 'the server answered no job');
    }
    return StartedJob(job, created: res['created'] == true);
  }

  /// `GET /api/v1/discovery/plugin-jobs[?state=&limit=]` — the caller's
  /// jobs, newest first.
  Future<JobList> jobs({JobState? state, int? limit}) async {
    final q = <String, String>{
      if (state != null) 'state': state.name,
      if (limit != null) 'limit': '${limit.clamp(1, 500)}',
    };
    final path = q.isEmpty
        ? '/api/v1/discovery/plugin-jobs'
        : '/api/v1/discovery/plugin-jobs?${Uri(queryParameters: q).query}';
    return JobList.fromServerMap(_map(await _get(path)));
  }

  /// `GET /api/v1/discovery/plugin-jobs/:id`.
  Future<DiscoveryJob> job(int id) async {
    final job = DiscoveryJob.fromServerMap(
        _map(await _get('/api/v1/discovery/plugin-jobs/$id'))['job']);
    if (job == null) {
      throw const DiscoveryPluginsException(0, 'the server answered no job');
    }
    return job;
  }

  /// `POST /api/v1/discovery/plugin-jobs/:id/cancel`: `cancelled` (it was
  /// queued) or `requested` (it was running). A 409 — it finished before the
  /// cancel reached it — is [CancelOutcome.alreadyFinished], not an error.
  Future<CancelResult> cancel(int id) async {
    try {
      final res =
          _map(await _send('POST', '/api/v1/discovery/plugin-jobs/$id/cancel', const {}));
      return CancelResult(
        res['outcome'] == 'cancelled'
            ? CancelOutcome.cancelled
            : CancelOutcome.requested,
        job: DiscoveryJob.fromServerMap(res['job']),
      );
    } on DiscoveryPluginsException catch (e) {
      if (e.status == 409) {
        return CancelResult(CancelOutcome.alreadyFinished, message: e.message);
      }
      rethrow;
    }
  }

  /// `POST /api/v1/discovery/plugin-jobs/clear` ("Clear finished"): drops
  /// the caller's finished rows; how many went.
  Future<int> clearFinished() async {
    final removed =
        _map(await _send('POST', '/api/v1/discovery/plugin-jobs/clear', const {}))['removed'];
    return removed is num ? removed.toInt() : 0;
  }

  /// `POST /api/v1/discovery/plugin-jobs/lookup/batch`, in chunks of
  /// 100 (the route's cap; lookupChunks), one after another: each answer is
  /// the single lookup's for its recommendation, aligned with [recs]. A
  /// chunk that fails leaves its entries null (its rows keep what they
  /// had); when EVERY chunk fails the last failure is thrown.
  Future<List<JobLookup?>> lookupBatch(
      List<Map<String, dynamic>> recs) async {
    final out = <JobLookup?>[];
    DiscoveryPluginsException? lastError;
    var failed = 0;
    final chunks = lookupChunks(recs);
    for (final chunk in chunks) {
      try {
        final res = _map(await _send('POST',
            '/api/v1/discovery/plugin-jobs/lookup/batch', {'recommendations': chunk}));
        final results = res['results'];
        final list = results is List ? results : const [];
        for (var i = 0; i < chunk.length; i++) {
          out.add(i < list.length ? JobLookup.fromServerMap(list[i]) : null);
        }
      } on DiscoveryPluginsException catch (e) {
        lastError = e;
        failed += 1;
        out.addAll(List<JobLookup?>.filled(chunk.length, null));
      }
    }
    if (chunks.isNotEmpty && failed == chunks.length) throw lastError!;
    return out;
  }

  // ── links ───────────────────────────────────────────────────────────

  /// `POST /api/v1/discovery/plugins/links/resolve` — "Open elsewhere":
  /// canonical links first, then the catalogue searches. Asked only when
  /// the user taps.
  Future<List<PluginLink>> links(Map<String, dynamic> recommendation) async =>
      pluginLinksOf(await _send('POST',
          '/api/v1/discovery/plugins/$kLinksPlugin/resolve',
          {'recommendation': recommendation}));

  // ── transport ───────────────────────────────────────────────────────

  Server _own() {
    final s = server;
    if (s == null) {
      throw const DiscoveryPluginsException(0, 'your server is not linked');
    }
    return s;
  }

  Map<String, String> _headers(Server s) => {
        'Content-Type': 'application/json',
        'x-access-token': s.authToken ?? '',
      };

  Future<dynamic> _get(String location) async {
    final s = _own();
    return _decode(await _guard(
        () => _http.get(s.apiUri(location), headers: _headers(s))));
  }

  Future<dynamic> _send(String method, String location, Object body) async {
    final s = _own();
    final uri = s.apiUri(location);
    final encoded = jsonEncode(body);
    return _decode(await _guard(() => method == 'PUT'
        ? _http.put(uri, headers: _headers(s), body: encoded)
        : _http.post(uri, headers: _headers(s), body: encoded)));
  }

  Future<http.Response> _guard(Future<http.Response> Function() call) async {
    try {
      return await call().timeout(timeout);
    } on TimeoutException {
      throw const DiscoveryPluginsException(0, 'your server did not answer in time');
    } on DiscoveryPluginsException {
      rethrow;
    } catch (e) {
      throw DiscoveryPluginsException(0, '$e');
    }
  }

  static dynamic _decode(http.Response res) {
    dynamic body;
    if (res.body.isNotEmpty) {
      try {
        body = jsonDecode(res.body);
      } catch (_) {
        body = null;
      }
    }
    if (res.statusCode < 200 || res.statusCode > 299) {
      final error = body is Map ? body['error'] : null;
      if (error is String && error.trim().isNotEmpty) {
        throw DiscoveryPluginsException(res.statusCode, error, fromServer: true);
      }
      throw DiscoveryPluginsException(res.statusCode, 'HTTP ${res.statusCode}');
    }
    return body;
  }

  static Map _map(dynamic v) {
    if (v is Map) return v;
    throw const DiscoveryPluginsException(0, 'the server answered something else');
  }
}
