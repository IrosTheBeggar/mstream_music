import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../objects/server.dart';
import '../singletons/api.dart';
import '../singletons/log_manager.dart';
import '../singletons/server_list.dart';

/// A non-2xx answer from one of the routes Add from YouTube uses, or a call
/// that never got one.
///
/// makeServerCall throws the status and the body away; every line of the
/// screen's error copy is decided by them (util/ytdl_errors.dart), so this
/// keeps both. [message] is the server's own `{error}` text, verbatim
/// ([fromServer] true): "FFmpeg is not available yet", "Library 'Music' not
/// found", Joi's `"outputCodec" must be one of [...]`. It is '' when the
/// answer carried none — Express's HTML 404 for a route the server does not
/// have, a reverse proxy's error page — and when there was no answer at all
/// ([status] 0: the transport failed, or the client's bound ran out,
/// [timedOut]).
class YtdlApiException implements Exception {
  final int status;
  final String message;
  final bool fromServer;
  final bool timedOut;

  /// What the transport threw (status 0), for the log; never shown.
  final Object? cause;

  const YtdlApiException(this.status, this.message,
      {this.fromServer = false, this.timedOut = false, this.cause});

  @override
  String toString() {
    if (timedOut) return 'YtdlApiException(timed out)';
    if (status == 0) return 'YtdlApiException(no answer: $cause)';
    return 'YtdlApiException($status${fromServer ? ': $message' : ''})';
  }
}

/// What yt-dlp read off a video (`GET /api/v1/ytdl/metadata`). The route
/// sends every key, each `x || null`; an empty string is read as null too.
///
/// [artist] is the route's `artist || creator || uploader`, so it can be a
/// channel name ("Daft Punk - Topic", "GorillazVEVO") — util/ytdl_guess.dart
/// strips those. [year] is stringified: the route sends yt-dlp's
/// `release_year` as a number, and POST /ytdl takes the year only as a
/// string. There is no duration and no channel.
class YtdlMetadata {
  final String? title;
  final String? artist;
  final String? album;
  final String? year;
  final String? thumbnail;

  const YtdlMetadata(
      {this.title, this.artist, this.album, this.year, this.thumbnail});

  static YtdlMetadata fromServerMap(Map m) => YtdlMetadata(
        title: _text(m['title']),
        artist: _text(m['artist']),
        album: _text(m['album']),
        year: _yearText(m['year']),
        thumbnail: _text(m['thumbnail']),
      );

  /// A number as its integer digits (2001, or 2001.0 from a lenient
  /// encoder), a string as sent; anything else is no year.
  static String? _yearText(dynamic v) {
    if (v is num && v.isFinite) {
      return v == v.truncate() ? '${v.toInt()}' : null;
    }
    return _text(v);
  }
}

/// One entry of the server's download tracker (`GET /api/v1/ytdl/downloads`).
///
/// The tracker is in memory, global across every account on the server, and
/// forgets an entry 30 s after it settles (and everything on a restart). It
/// carries no progress, no file path, no error text and no user — which is
/// why the hub claims entries by [url] + [directory] and follows the [pid].
class YtdlServerJob {
  final int pid;

  /// The link as the server sanitized it — the phone's own canonical link
  /// when it sent one (util/ytdl_link.dart), so the two compare equal.
  final String url;

  /// Exactly as the add sent it.
  final String directory;
  final String outputCodec;

  /// `downloading` · `complete` · `error` (kept raw: a value this build
  /// does not know is neither of the getters below).
  final String status;

  /// ms epoch on the SERVER's clock — never compared with the phone's.
  final int startTime;

  const YtdlServerJob({
    required this.pid,
    required this.url,
    required this.directory,
    required this.outputCodec,
    required this.status,
    required this.startTime,
  });

  bool get downloading => status == 'downloading';
  bool get complete => status == 'complete';
  bool get failed => status == 'error';

  /// Null when the entry has no pid, link or folder to match it by.
  static YtdlServerJob? fromServerMap(dynamic m) {
    if (m is! Map) return null;
    final pid = _int(m['pid']);
    final url = m['url'];
    final directory = m['directory'];
    if (pid == null || url is! String || directory is! String) return null;
    final codec = m['outputCodec'];
    final status = m['status'];
    return YtdlServerJob(
      pid: pid,
      url: url,
      directory: directory,
      outputCodec: codec is String ? codec : '',
      status: status is String ? status : '',
      startTime: _int(m['startTime']) ?? 0,
    );
  }
}

/// A folder listing (`POST /api/v1/file-explorer`), names only: enough to
/// know whether a folder exists and what is in it before an add.
class YtdlListing {
  /// The folder as the server names it: '/Music/Daft Punk/' — leading and
  /// trailing slash, on-disk casing.
  final String path;
  final List<String> directories;
  final List<String> files;

  const YtdlListing(
      {required this.path, this.directories = const [], this.files = const []});

  static YtdlListing fromServerMap(Map m, {required String asked}) {
    final path = m['path'];
    return YtdlListing(
      path: path is String && path.isNotEmpty ? path : asked,
      directories: _names(m['directories']),
      files: _names(m['files']),
    );
  }

  static List<String> _names(dynamic list) => [
        if (list is List)
          for (final e in list)
            if (e is Map && e['name'] is String && (e['name'] as String).isNotEmpty)
              e['name'] as String,
      ];
}

/// One row of the account's download record (`GET
/// /api/v1/discovery/downloads`, mStream 6.30+) that came from POST /ytdl
/// (`plugin == 'ytdl'`) — this phone's adds, the web app's and any other
/// device's, durable across restarts.
class YtdlRecord {
  final int id;
  final String vpath;

  /// `<vpath>/<relativePath>`, no leading slash.
  final String filepath;

  /// Inside the library, on-disk casing (the server resolves it).
  final String relativePath;

  /// The sanitized link the add was made from (matches the job's `url`).
  final String origin;
  final String? title;
  final String? artist;
  final String? album;
  final int? bytes;

  /// ms epoch, server clock.
  final int downloadedAt;

  /// Whether the library still has the song (its track row exists).
  final bool present;
  final int? trackId;

  const YtdlRecord({
    required this.id,
    required this.vpath,
    required this.filepath,
    required this.relativePath,
    required this.origin,
    this.title,
    this.artist,
    this.album,
    this.bytes,
    required this.downloadedAt,
    required this.present,
    this.trackId,
  });

  /// Null for a row with no id (nothing to page or match it by).
  static YtdlRecord? fromServerMap(dynamic m) {
    if (m is! Map) return null;
    final id = _int(m['id']);
    if (id == null) return null;
    String str(String key) => m[key] is String ? m[key] as String : '';
    return YtdlRecord(
      id: id,
      vpath: str('vpath'),
      filepath: str('filepath'),
      relativePath: str('relativePath'),
      origin: str('origin'),
      title: _text(m['title']),
      artist: _text(m['artist']),
      album: _text(m['album']),
      bytes: _int(m['bytes']),
      downloadedAt: _int(m['downloadedAt']) ?? 0,
      present: m['present'] == true,
      trackId: _int(m['trackId']),
    );
  }
}

/// One page of the download record ([YtdlApi.recordsPage]): its ytdl rows,
/// and what the whole page held — the route's `limit` counts every
/// plug-in's rows, so a page of Discover downloads or federation copies has
/// no ytdl row and is still not the end. Page on [oldestId], end on [end].
class YtdlRecordPage {
  /// The page's [kYtdlRecordPlugin] rows, newest first.
  final List<YtdlRecord> rows;

  /// Every plug-in's rows on the page (with an id).
  final int count;

  /// The `limit` the page was asked for.
  final int limit;

  /// The smallest and largest id on the page, any plug-in: the next
  /// page's `before`, and the newest record the server holds (a first
  /// page). Null on an empty page.
  final int? oldestId;
  final int? newestId;

  /// The page's earliest `downloadedAt` (ms, server clock), any plug-in.
  final int? oldestAt;

  const YtdlRecordPage({
    this.rows = const [],
    this.count = 0,
    this.limit = 0,
    this.oldestId,
    this.newestId,
    this.oldestAt,
  });

  /// Nothing older is left: the page held no row at all, or fewer than it
  /// asked for. Its own rows still count — a short last page has some.
  bool get end => count == 0 || count < limit;
}

/// The record's plug-in name for a POST /ytdl add.
const String kYtdlRecordPlugin = 'ytdl';

/// The tag keys POST /ytdl's `metadata` takes. Its schema refuses any other
/// key — and with it the whole add.
const List<String> kYtdlTagKeys = ['title', 'artist', 'album', 'year'];

/// The routes behind Add from YouTube (mStream src/api/ytdl.js, the file
/// explorer's listing and mkdir, and the download record).
///
/// Spoken to the server it is given — unlike DiscoveryPluginsApi, never a
/// connected server's parent: the feature is hidden on peers (/ytdl is off
/// the federation allowlist). Over ApiManager's pooled direct client unless
/// a client is injected (tests); headless, so it never drives the browser's
/// loading bar. Bounded by [timeout], or [irohTry] when the server rides a
/// tunnel; every failure throws [YtdlApiException] with the status and the
/// server's words.
///
/// Like makeServerCall, a call that gets no answer over a tunnel waits for
/// the tunnel and is sent once more — except the add. POST /ytdl starts a
/// yt-dlp job and answers before it runs; sent twice it starts two, which on
/// 6.30+ ends in a name-clash failure for the second and before that in a
/// re-tag. So the add is never retried, over a tunnel included: a lost
/// answer is the hub's to resolve against the server's own lists.
class YtdlApi {
  final Server server;

  /// An injected client (tests); null = ApiManager's pooled one.
  final http.Client? client;
  final Duration timeout;
  final Duration irohTry;

  /// Waits for [server]'s tunnel before the one retry; null =
  /// ServerManager.awaitTunnelReady (true at once where there is no tunnel
  /// to wait for). Tests stub it.
  final Future<bool> Function(Server server)? awaitTunnel;

  YtdlApi(this.server,
      {this.client,
      this.timeout = const Duration(seconds: 30),
      this.irohTry = const Duration(seconds: 20),
      this.awaitTunnel});

  http.Client get _http => client ?? ApiManager().directClient;

  // ── the lookup and the add ──────────────────────────────────────────

  /// `GET /api/v1/ytdl/metadata?url=` — yt-dlp's reading of the video. The
  /// route has no bound of its own (and a fresh server may fetch yt-dlp
  /// during the first one), so [timeout] is the only limit.
  Future<YtdlMetadata> metadata(String url) async => YtdlMetadata.fromServerMap(
      _map(await _get('/api/v1/ytdl/metadata?url=${Uri.encodeQueryComponent(url)}')));

  /// `POST /api/v1/ytdl/` (the route's own trailing slash): starts the
  /// download into [directory], which must exist. The 200 says only that it
  /// started — no pid, no id.
  ///
  /// [metadata] goes as the tags to write: only the [kYtdlTagKeys], only
  /// non-blank values, and no `metadata` key at all when none is left — the
  /// server writes no tag for an empty value anyway, and its schema refuses
  /// null. Never retried (see the class).
  Future<void> add(
      {required String directory,
      required String url,
      required String codec,
      Map<String, String> metadata = const {}}) async {
    final tags = <String, String>{
      for (final key in kYtdlTagKeys)
        if ((metadata[key] ?? '').trim().isNotEmpty) key: metadata[key]!,
    };
    // Any 2xx is "started", whatever its body says: reading a garbled 200
    // as a failure would invite an Add again, and a second job.
    await _post('/api/v1/ytdl/', {
      'directory': directory,
      'url': url,
      'outputCodec': codec,
      if (tags.isNotEmpty) 'metadata': tags,
    }, retry: false, needBody: false);
  }

  /// `GET /api/v1/ytdl/downloads` — the server's whole tracker, every
  /// account's entries mixed (see [YtdlServerJob]). Entries with nothing to
  /// match by are left out.
  Future<List<YtdlServerJob>> jobs() async {
    final list = _map(await _get('/api/v1/ytdl/downloads'))['downloads'];
    return [
      if (list is List)
        for (final e in list) ?YtdlServerJob.fromServerMap(e),
    ];
  }

  // ── folders ─────────────────────────────────────────────────────────

  /// `POST /api/v1/file-explorer` {directory, pullMetadata: false}. A folder
  /// that is not there answers 404 with the server's words (500 on
  /// 6.26–6.28.0).
  Future<YtdlListing> list(String directory) async => YtdlListing.fromServerMap(
      _map(await _post('/api/v1/file-explorer',
          {'directory': directory, 'pullMetadata': false})),
      asked: directory);

  /// `POST /api/v1/file-explorer/mkdir` {directory}: recursive, and fine
  /// when the folder is already there — which is what makes its one retry
  /// over a tunnel safe. 403 "Create Folder Disabled" for an account that
  /// may not make folders. Any 2xx means the folder is there.
  Future<void> mkdir(String directory) async {
    await _post('/api/v1/file-explorer/mkdir', {'directory': directory},
        needBody: false);
  }

  // ── the download record ─────────────────────────────────────────────

  /// `GET /api/v1/discovery/downloads?limit=&before=` — the account's record,
  /// newest first, narrowed to the [kYtdlRecordPlugin] rows. [limit]
  /// (1–500) counts every plug-in's rows, so a page can hold fewer; [before]
  /// is a record id (rows older than it).
  ///
  /// Null when the server has no such route — Express's own 404, with no
  /// `{error}` — which marks a server before 6.30 (the release that brought
  /// the record, the staging folder and the caps). Anything else that fails
  /// throws, a 404 that carries the server's words included.
  Future<List<YtdlRecord>?> records({int limit = 20, int? before}) async =>
      (await recordsPage(limit: limit, before: before))?.rows;

  /// [records] with what the whole page held ([YtdlRecordPage]): page with
  /// `before` = its [YtdlRecordPage.oldestId]; an empty page, or one
  /// shorter than [limit], is the end. Null on a server before 6.30, as
  /// [records].
  Future<YtdlRecordPage?> recordsPage({int limit = 20, int? before}) async {
    final asked = limit.clamp(1, 500);
    final q = {
      'limit': '$asked',
      if (before != null) 'before': '$before',
    };
    final dynamic body;
    try {
      body = await _get(
          '/api/v1/discovery/downloads?${Uri(queryParameters: q).query}');
    } on YtdlApiException catch (e) {
      if (e.status == 404 && !e.fromServer) return null;
      rethrow;
    }
    final list = _map(body)['downloads'];
    final rows = <YtdlRecord>[];
    var count = 0;
    int? oldestId, newestId, oldestAt;
    if (list is List) {
      for (final e in list) {
        if (e is! Map) continue;
        final id = _int(e['id']);
        if (id == null) continue;
        count++;
        oldestId = oldestId == null ? id : math.min(oldestId, id);
        newestId = newestId == null ? id : math.max(newestId, id);
        final at = _int(e['downloadedAt']);
        if (at != null) {
          oldestAt = oldestAt == null ? at : math.min(oldestAt, at);
        }
        if (e['plugin'] == kYtdlRecordPlugin) {
          final r = YtdlRecord.fromServerMap(e);
          if (r != null) rows.add(r);
        }
      }
    }
    return YtdlRecordPage(
      rows: rows,
      count: count,
      limit: asked,
      oldestId: oldestId,
      newestId: newestId,
      oldestAt: oldestAt,
    );
  }

  // ── transport ───────────────────────────────────────────────────────

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-access-token': server.authToken ?? '',
      };

  Future<dynamic> _get(String location) async => _decode(await _call(
      (uri) => _http.get(uri, headers: {'x-access-token': server.authToken ?? ''}),
      location,
      retry: true));

  Future<dynamic> _post(String location, Object body,
      {bool retry = true, bool needBody = true}) async {
    final encoded = jsonEncode(body);
    return _decode(
        await _call((uri) => _http.post(uri, headers: _headers, body: encoded),
            location,
            retry: retry),
        needBody: needBody);
  }

  /// One send, bounded; over a tunnel, and when [retry] allows, one more
  /// after the tunnel says it is back. Only a call that got NO answer is
  /// retried — an HTTP error is the server's answer, and stands.
  Future<http.Response> _call(
      Future<http.Response> Function(Uri uri) send, String location,
      {required bool retry}) async {
    final overTunnel = server.isIrohTransport;
    try {
      return await send(server.apiUri(location))
          .timeout(overTunnel ? irohTry : timeout);
    } catch (e) {
      if (!overTunnel || !retry) throw _noAnswer(e);
      final route = location.split('?').first;
      final ready = await (awaitTunnel ?? _awaitTunnel)(server);
      if (!ready) {
        appLog('[ytdl] tunnel down; $route failed: $e');
        throw _noAnswer(e);
      }
      appLog('[ytdl] $route got no answer over the tunnel ($e); retrying once');
    }
    try {
      // The URI again: a re-dialled tunnel has a new port and token.
      return await send(server.apiUri(location)).timeout(irohTry);
    } catch (e) {
      throw _noAnswer(e);
    }
  }

  static Future<bool> _awaitTunnel(Server server) => ServerManager()
      .awaitTunnelReady(
          server: server,
          timeout: const Duration(seconds: 12),
          extendWhileDialing: false,
          caller: 'ytdl');

  static YtdlApiException _noAnswer(Object e) => e is YtdlApiException
      ? e
      : YtdlApiException(0, '', timedOut: e is TimeoutException, cause: e);

  /// The body of a 2xx; otherwise the status and the server's `{error}`.
  /// A 2xx whose body is not JSON throws with that status and no words,
  /// unless the caller does not [needBody].
  static dynamic _decode(http.Response res, {bool needBody = true}) {
    dynamic body;
    var garbled = false;
    if (res.body.isNotEmpty) {
      try {
        body = jsonDecode(res.body);
      } catch (_) {
        garbled = true;
      }
    }
    if (res.statusCode < 200 || res.statusCode > 299) {
      final error = body is Map ? body['error'] : null;
      if (error is String && error.trim().isNotEmpty) {
        throw YtdlApiException(res.statusCode, error, fromServer: true);
      }
      throw YtdlApiException(res.statusCode, '');
    }
    if (garbled && needBody) throw YtdlApiException(res.statusCode, '');
    return body;
  }

  /// A 2xx's body as the map every route answers; anything else is an
  /// answer this client cannot read (a 200 with no words).
  static Map _map(dynamic v) {
    if (v is Map) return v;
    throw const YtdlApiException(200, '');
  }
}

int? _int(dynamic v) => v is int
    ? v
    : (v is num && v.isFinite && v == v.truncate() ? v.toInt() : null);

String? _text(dynamic v) => v is String && v.isNotEmpty ? v : null;
