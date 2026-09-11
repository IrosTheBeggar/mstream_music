import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../objects/listening_stats.dart';
import '../objects/play_event.dart';
import '../objects/server.dart';
import '../singletons/play_sync.dart';

/// Thrown by the read calls; the write call throws [PostPlaysException].
class StatsApiException implements Exception {
  final int status;
  final String message;
  const StatsApiException(this.status, this.message);
  bool get isAuth => status == 401 || status == 403;
  bool get isMissing => status == 404;
  @override
  String toString() => 'StatsApiException($status: $message)';
}

/// What a server reports about the range of its log.
class StatsPeriods {
  final DateTime? earliest;
  final DateTime? latest;
  const StatsPeriods({this.earliest, this.latest});
}

/// One server's Stats API v2, on the app's own routing: `server.apiUri`
/// rewrites a proxied peer's path onto its parent and `server.authToken`
/// picks the right credential, so a federated server needs no special
/// case here. Every call is headless (no browser loading bar) and bounded.
///
/// The client is injectable, so the whole class runs under test with
/// `package:http/testing.dart`'s MockClient.
class StatsApi {
  final Server server;
  final http.Client _client;
  final Duration timeout;

  /// The `client` block every write carries (the server stores it on the
  /// event so history can name the app that played the track).
  static String appVersion = '0.0.0';
  static String instanceId = '';

  StatsApi(this.server, {http.Client? client, this.timeout = const Duration(seconds: 15)})
      : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'x-access-token': server.authToken ?? '',
        'Content-Type': 'application/json',
      };

  Future<dynamic> _get(String location) async {
    final res = await _client.get(server.apiUri(location), headers: _headers).timeout(timeout);
    if (res.statusCode > 299) throw StatsApiException(res.statusCode, _errorText(res));
    return jsonDecode(res.body);
  }

  Future<dynamic> _post(String location, Object body) async {
    final res = await _client.post(server.apiUri(location), headers: _headers, body: jsonEncode(body)).timeout(timeout);
    if (res.statusCode > 299) throw StatsApiException(res.statusCode, _errorText(res));
    return jsonDecode(res.body);
  }

  static String _errorText(http.Response res) {
    try {
      final v = jsonDecode(res.body);
      if (v is Map && v['error'] is String) return v['error'] as String;
    } catch (_) {
      // not json
    }
    return 'http ${res.statusCode}';
  }

  static String _query(Map<String, Object?> params) {
    final parts = <String>[];
    params.forEach((k, v) {
      if (v == null) return;
      parts.add('${Uri.encodeQueryComponent(k)}=${Uri.encodeQueryComponent(v.toString())}');
    });
    return parts.isEmpty ? '' : '?${parts.join('&')}';
  }

  static Map<String, Object?> _range({StatsPeriod? period, int offset = 0, String? tz}) => {
        if (period != null && period != StatsPeriod.all) 'period': period.wire,
        if (period != null && period != StatsPeriod.all) 'offset': offset,
        if (period == StatsPeriod.all) 'period': 'all',
        'tz': tz ?? _localTz(),
      };

  /// The zone the server should bucket hours and days in: the device's
  /// IANA name when the platform exposes one, else a fixed-offset `Etc/GMT`
  /// zone for the device's current offset (Flutter reports abbreviations
  /// like "PDT" on most platforms, which the server does not accept). A
  /// fixed offset ignores DST changes inside a long period and half-hour
  /// zones round to the hour — a bucketing difference, never a wrong count.
  static String? _localTz() {
    final now = DateTime.now();
    return localTzFor(now.timeZoneName, now.timeZoneOffset);
  }

  @visibleForTesting
  static String? localTzFor(String name, Duration offset) {
    if (name.contains('/')) return name;
    final minutes = offset.inMinutes;
    if (minutes % 60 != 0) return null;
    final hours = minutes ~/ 60;
    if (hours == 0) return 'UTC';
    // Etc/GMT signs are inverted: Etc/GMT-2 is UTC+2.
    return 'Etc/GMT${hours > 0 ? '-' : '+'}${hours.abs()}';
  }

  // ── Write ──

  /// `POST /api/v1/stats/plays`. Network trouble, an auth refusal and any
  /// other failure are told apart for the outbox's policy.
  Future<PostPlaysResult> postPlays(List<PlayEvent> plays) async {
    final body = {
      'client': {
        'name': 'mstream-music',
        'version': appVersion,
        if (instanceId.isNotEmpty) 'instanceId': instanceId,
      },
      'plays': plays.map((e) => e.toWire()).toList(),
    };
    http.Response res;
    try {
      res = await _client.post(server.apiUri('/api/v1/stats/plays'), headers: _headers, body: jsonEncode(body)).timeout(timeout);
    } on TimeoutException {
      throw const PostPlaysException(PostFailure.network, 'timeout');
    } on http.ClientException catch (e) {
      throw PostPlaysException(PostFailure.network, e.message);
    } catch (e) {
      throw PostPlaysException(PostFailure.network, e.toString());
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw PostPlaysException(PostFailure.unauthorized, 'http ${res.statusCode}');
    }
    if (res.statusCode > 299) {
      throw PostPlaysException(PostFailure.server, _errorText(res));
    }
    try {
      final v = jsonDecode(res.body);
      if (v is! Map) throw const PostPlaysException(PostFailure.server, 'unexpected answer');
      return PostPlaysResult.fromJson(v);
    } on PostPlaysException {
      rethrow;
    } catch (_) {
      throw const PostPlaysException(PostFailure.server, 'unexpected answer');
    }
  }

  /// `POST /api/v1/stats/now-playing` — best effort, never throws.
  Future<void> nowPlaying(PlayEvent open) async {
    try {
      final t = open.track;
      final filePath = t.path.startsWith('/') ? t.path.substring(1) : t.path;
      await _client
          .post(server.apiUri('/api/v1/stats/now-playing'),
              headers: _headers,
              body: jsonEncode({
                'filePath': filePath,
                if (t.peerId != null) 'peerId': t.peerId,
                if (t.peerId != null)
                  'track': {
                    if (t.title != null) 'title': t.title,
                    if (t.artist != null) 'artist': t.artist,
                    if (t.album != null) 'album': t.album,
                    if (t.durationMs != null) 'durationMs': t.durationMs,
                    if (t.hash != null) 'hash': t.hash,
                  },
              }))
          .timeout(timeout);
    } catch (_) {
      // a courtesy notice; nothing depends on it
    }
  }

  // ── Reads ──

  Future<ListeningSummary> summary({StatsPeriod period = StatsPeriod.month, int offset = 0, String origin = 'all', String? tz}) async {
    final v = await _get('/api/v1/stats/summary${_query({..._range(period: period, offset: offset, tz: tz), 'origin': origin})}');
    return v is Map ? ListeningSummary.fromServer(v) : const ListeningSummary();
  }

  Future<List<TopItem>> top({required String entity, String metric = 'plays', StatsPeriod period = StatsPeriod.month, int offset = 0, String origin = 'all', int limit = 10, String? tz}) async {
    final v = await _get('/api/v1/stats/top${_query({..._range(period: period, offset: offset, tz: tz), 'entity': entity, 'metric': metric, 'origin': origin, 'limit': limit})}');
    return v is Map ? TopItem.listFromServer(v['items'], entity) : const [];
  }

  /// Newest first; [before] is the opaque cursor the previous page returned
  /// (`next`), null for the first page.
  Future<({List<HistoryItem> items, String? next})> history({StatsPeriod? period, int offset = 0, String origin = 'all', int limit = 30, String? before, String? track, String? tz}) async {
    final v = await _get('/api/v1/stats/history${_query({
      ...(period == null ? {'tz': tz ?? _localTz()} : _range(period: period, offset: offset, tz: tz)),
      'origin': origin,
      'limit': limit,
      'before': before,
      'track': track,
    })}');
    if (v is! Map) return (items: const <HistoryItem>[], next: null);
    return (items: HistoryItem.listFromServer(v['items']), next: v['next'] is String ? v['next'] as String : null);
  }

  /// Counted plays per local hour of day, 24 buckets (`bucket=hourOfDay`).
  Future<List<int>> hourOfDay({StatsPeriod period = StatsPeriod.month, int offset = 0, String origin = 'all', String? tz}) async {
    final v = await _get('/api/v1/stats/timeseries${_query({..._range(period: period, offset: offset, tz: tz), 'bucket': 'hourOfDay', 'origin': origin})}');
    final out = List<int>.filled(24, 0);
    if (v is Map && v['items'] is List) {
      for (final it in v['items'] as List) {
        if (it is! Map) continue;
        final h = int.tryParse(it['bucket']?.toString() ?? '');
        if (h != null && h >= 0 && h < 24) out[h] = it['plays'] is num ? (it['plays'] as num).round() : 0;
      }
    }
    return out;
  }

  /// Per-track counters for a batch of paths and/or hashes (either the
  /// audio hash or the file hash — the server resolves both).
  Future<List<TrackCounters>> tracks({List<String> filePaths = const [], List<String> hashes = const []}) async {
    if (filePaths.isEmpty && hashes.isEmpty) return const [];
    final v = await _post('/api/v1/stats/tracks', {
      if (filePaths.isNotEmpty) 'filePaths': filePaths.map((p) => p.startsWith('/') ? p.substring(1) : p).toList(),
      if (hashes.isNotEmpty) 'hashes': hashes,
    });
    if (v is! Map || v['items'] is! List) return const [];
    return (v['items'] as List).whereType<Map>().map(TrackCounters.fromJson).whereType<TrackCounters>().toList();
  }

  Future<StatsPeriods> periods() async {
    final v = await _get('/api/v1/stats/periods${_query({'tz': _localTz()})}');
    if (v is! Map) return const StatsPeriods();
    DateTime? d(dynamic s) => s is String ? DateTime.tryParse(s) : null;
    return StatsPeriods(earliest: d(v['earliest']), latest: d(v['latest']));
  }
}

/// One item of `POST /api/v1/stats/tracks`.
class TrackCounters {
  final String hash;
  final String? filePath;
  final int plays;
  final int skips;
  final int listenedMs;
  final DateTime? firstPlayed;
  final DateTime? lastPlayed;
  const TrackCounters({required this.hash, this.filePath, required this.plays, required this.skips, required this.listenedMs, this.firstPlayed, this.lastPlayed});

  static TrackCounters? fromJson(Map<dynamic, dynamic> j) {
    final hash = j['hash'];
    if (hash is! String) return null;
    int i(dynamic v) => v is num ? v.round() : 0;
    DateTime? d(dynamic s) => s is String ? DateTime.tryParse(s) : null;
    return TrackCounters(
      hash: hash,
      filePath: j['filePath'] is String ? j['filePath'] as String : null,
      plays: i(j['plays']),
      skips: i(j['skips']),
      listenedMs: i(j['listenedMs']),
      firstPlayed: d(j['firstPlayed']),
      lastPlayed: d(j['lastPlayed']),
    );
  }
}
