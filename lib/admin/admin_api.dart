import 'dart:convert';
import 'package:http/http.dart' as http;

import 'admin_session.dart';

/// Thrown for any non-2xx admin response. [message] is the server's `{error}`
/// field when present, otherwise a generic status message.
class AdminApiException implements Exception {
  final int statusCode;
  final String message;
  AdminApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}

/// Dependency-light client for the entire mStream `/api/v1/admin/*` surface
/// (plus the public login + version endpoints). Depends only on
/// `package:http` and a plain [AdminSession] — no `dart:io`, no app
/// singletons — so it compiles unchanged for web and mobile.
///
/// Endpoint contract mirrors `src/api/admin.js`, `admin-torrent.js`,
/// `backup.js` and `auth.js` in the mStream server.
class AdminApi {
  final AdminSession session;
  final http.Client _client;

  AdminApi(this.session, {http.Client? client})
      : _client = client ?? http.Client();

  void dispose() => _client.close();

  Uri _u(String path, [Map<String, dynamic>? query]) {
    final uri = Uri.parse(session.baseUrl).resolve(path);
    final merged = <String, String>{
      ...session.query,
      ...?query?.map((k, v) => MapEntry(k, '$v')),
    };
    if (merged.isEmpty) return uri;
    return uri.replace(queryParameters: merged);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-access-token': ?session.token,
      };

  Future<dynamic> _send(String method, String path,
      {Map<String, dynamic>? body, Map<String, dynamic>? query}) async {
    late http.Response res;
    final uri = _u(path, query);
    final encoded = body == null ? null : jsonEncode(body);
    switch (method) {
      case 'GET':
        res = await _client.get(uri, headers: _headers);
        break;
      case 'POST':
        res = await _client.post(uri, headers: _headers, body: encoded);
        break;
      case 'PUT':
        res = await _client.put(uri, headers: _headers, body: encoded);
        break;
      case 'PATCH':
        res = await _client.patch(uri, headers: _headers, body: encoded);
        break;
      case 'DELETE':
        res = await _client.delete(uri, headers: _headers, body: encoded);
        break;
      default:
        throw ArgumentError('bad method $method');
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      try {
        return jsonDecode(res.body);
      } catch (_) {
        return res.body; // non-JSON (shouldn't happen for these routes)
      }
    }
    // Surface the server's structured {error} message when we can.
    String msg = 'HTTP ${res.statusCode}';
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['error'] != null) {
        msg = decoded['error'].toString();
      }
    } catch (_) {/* keep generic */}
    throw AdminApiException(res.statusCode, msg);
  }

  Future<dynamic> _get(String p, [Map<String, dynamic>? q]) =>
      _send('GET', p, query: q);
  Future<dynamic> _post(String p, [Map<String, dynamic>? b]) =>
      _send('POST', p, body: b);
  Future<dynamic> _put(String p, [Map<String, dynamic>? b]) =>
      _send('PUT', p, body: b);
  Future<dynamic> _patch(String p, [Map<String, dynamic>? b]) =>
      _send('PATCH', p, body: b);
  Future<dynamic> _delete(String p, [Map<String, dynamic>? b]) =>
      _send('DELETE', p, body: b);

  // ── Public (no /admin) ────────────────────────────────────────────────────

  /// `POST /api/v1/auth/login` — exchanges credentials for a JWT. Static
  /// because it runs before there is a session/token (standalone web login).
  /// Returns `{vpaths: List, token: String}`.
  static Future<Map<String, dynamic>> login(
      String baseUrl, String username, String password,
      {http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final res = await c.post(
        Uri.parse(baseUrl).resolve('/api/v1/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      String msg = 'Login failed (HTTP ${res.statusCode})';
      try {
        final d = jsonDecode(res.body);
        if (d is Map && d['error'] != null) msg = d['error'].toString();
      } catch (_) {}
      throw AdminApiException(res.statusCode, msg);
    } finally {
      if (client == null) c.close();
    }
  }

  /// Probes whether the admin API is reachable WITHOUT authentication — true in
  /// the server's public/no-user mode (or when a same-origin session cookie is
  /// already present on web). Lets the standalone web app skip the login screen
  /// when no login is required or even possible (public mode has no users to
  /// authenticate against). Any non-200 (401 auth-required, 403 network gate,
  /// 405 admin-locked, network error) → false → show login.
  static Future<bool> isOpenAdmin(String baseUrl, {http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final res =
          await c.get(Uri.parse(baseUrl).resolve('/api/v1/admin/config'));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      if (client == null) c.close();
    }
  }

  /// `GET /api` — public server descriptor `{server: <version>, ...}`.
  Future<Map<String, dynamic>> serverInfo() async =>
      Map<String, dynamic>.from(await _get('/api'));

  // ── Directories / libraries ───────────────────────────────────────────────

  /// `{ name: {id, root, type, followSymlinks} }`
  Future<Map<String, dynamic>> getDirectories() async =>
      Map<String, dynamic>.from(await _get('/api/v1/admin/directories'));

  Future<void> addDirectory(String directory, String vpath,
          {bool autoAccess = false, bool isAudioBooks = false}) =>
      _put('/api/v1/admin/directory', {
        'directory': directory,
        'vpath': vpath,
        'autoAccess': autoAccess,
        'isAudioBooks': isAudioBooks,
      });

  Future<void> removeDirectory(String vpath) =>
      _delete('/api/v1/admin/directory', {'vpath': vpath});

  Future<void> setFollowSymlinks(String vpath, bool follow) =>
      _post('/api/v1/admin/directory/follow-symlinks',
          {'vpath': vpath, 'followSymlinks': follow});

  /// Admin file-explorer (can see the whole filesystem). `~` = home dir.
  /// Returns `{path, directories: [{name}], files: [{name}]}`.
  Future<Map<String, dynamic>> browseDirectory(String directory,
      {String? joinDirectory}) async {
    final body = <String, dynamic>{'directory': directory};
    if (joinDirectory != null) body['joinDirectory'] = joinDirectory;
    return Map<String, dynamic>.from(
        await _post('/api/v1/admin/file-explorer', body));
  }

  /// Windows-only: drive letters for the file-explorer root picker.
  Future<List<String>> winDrives() async {
    final r = await _get('/api/v1/admin/file-explorer/win-drives');
    return (r is List) ? r.map((e) => e.toString()).toList() : <String>[];
  }

  // ── Users ─────────────────────────────────────────────────────────────────

  /// `{ username: {admin, vpaths, allowMkdir, allowUpload, allowFileModify,
  /// allowServerAudio, allowTorrent} }`
  Future<Map<String, dynamic>> getUsers() async =>
      Map<String, dynamic>.from(await _get('/api/v1/admin/users'));

  Future<void> addUser(String username, String password,
          {bool admin = false,
          List<String> vpaths = const [],
          bool allowMkdir = true,
          bool allowUpload = true,
          bool allowServerAudio = false}) =>
      _put('/api/v1/admin/users', {
        'username': username,
        'password': password,
        'admin': admin,
        'vpaths': vpaths,
        'allowMkdir': allowMkdir,
        'allowUpload': allowUpload,
        'allowServerAudio': allowServerAudio,
      });

  Future<void> deleteUser(String username) =>
      _delete('/api/v1/admin/users', {'username': username});

  Future<void> setUserPassword(String username, String password) =>
      _post('/api/v1/admin/users/password',
          {'username': username, 'password': password});

  Future<void> setUserVPaths(String username, List<String> vpaths) =>
      _post('/api/v1/admin/users/vpaths',
          {'username': username, 'vpaths': vpaths});

  Future<void> setUserAccess(String username,
          {required bool admin,
          required bool allowMkdir,
          required bool allowUpload,
          bool allowFileModify = true,
          bool allowServerAudio = false}) =>
      _post('/api/v1/admin/users/access', {
        'username': username,
        'admin': admin,
        'allowMkdir': allowMkdir,
        'allowUpload': allowUpload,
        'allowFileModify': allowFileModify,
        'allowServerAudio': allowServerAudio,
      });

  Future<void> setUserTorrentAccess(String username, bool allow) =>
      _post('/api/v1/admin/users/torrent-access',
          {'username': username, 'allowTorrent': allow});

  // ── Database: scan params ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> getScanParams() async =>
      Map<String, dynamic>.from(await _get('/api/v1/admin/db/params'));

  Future<void> _param(String path, Map<String, dynamic> body) =>
      _post('/api/v1/admin/db/params/$path', body);

  Future<void> setScanInterval(int v) =>
      _param('scan-interval', {'scanInterval': v});
  Future<void> setSkipImg(bool v) => _param('skip-img', {'skipImg': v});
  Future<void> setBootScanDelay(int v) =>
      _param('boot-scan-delay', {'bootScanDelay': v});
  Future<void> setCompressImage(bool v) =>
      _param('compress-image', {'compressImage': v});
  Future<void> setScanCommitInterval(int v) =>
      _param('scan-commit-interval', {'scanCommitInterval': v});
  Future<void> setScanThreads(int v) =>
      _param('scan-threads', {'scanThreads': v});
  Future<void> setGenerateWaveforms(bool v) =>
      _param('generate-waveforms', {'generateWaveforms': v});
  Future<void> setAnalyzeBpm(bool v) => _param('analyze-bpm', {'analyzeBpm': v});
  Future<void> setAutoAlbumArt(bool v) =>
      _param('auto-album-art', {'autoAlbumArt': v});
  Future<void> setAutoAlbumArtMode(String mode) =>
      _param('auto-album-art-mode', {'autoAlbumArtMode': mode}); // missing|all
  Future<void> setAutoAlbumArtWriteToFolder(bool v) => _param(
      'auto-album-art-write-to-folder', {'autoAlbumArtWriteToFolder': v});
  Future<void> setAutoAlbumArtPerRun(int v) =>
      _param('auto-album-art-per-run', {'autoAlbumArtPerRun': v});
  Future<void> setAlbumArtWriteToFolder(bool v) =>
      _param('album-art-write-to-folder', {'albumArtWriteToFolder': v});
  Future<void> setAlbumArtWriteToFile(bool v) =>
      _param('album-art-write-to-file', {'albumArtWriteToFile': v});

  /// services: subset of ['musicbrainz','itunes','deezer']
  Future<void> setAlbumArtServices(List<String> services) =>
      _param('album-art-services', {'albumArtServices': services});

  // ── Database: actions / stats ─────────────────────────────────────────────

  Future<void> scanAll() => _post('/api/v1/admin/db/scan/all');
  Future<void> forceRescan() => _post('/api/v1/admin/db/scan/force-rescan');
  Future<void> forceCompressImages() =>
      _post('/api/v1/admin/db/force-compress-images');

  /// `{fileCount: int}`
  Future<int> scanStats() async {
    final r = await _get('/api/v1/admin/db/scan/stats');
    return (r is Map && r['fileCount'] is num)
        ? (r['fileCount'] as num).toInt()
        : 0;
  }

  // ── Shared playlists ──────────────────────────────────────────────────────

  /// `[{playlistId, user, playlist, expires, created}]`
  Future<List<dynamic>> getSharedPlaylists() async {
    final r = await _get('/api/v1/admin/db/shared');
    return (r is List) ? r : <dynamic>[];
  }

  Future<void> deleteSharedPlaylist(String id) =>
      _delete('/api/v1/admin/db/shared', {'id': id});
  Future<void> deleteExpiredShares() =>
      _delete('/api/v1/admin/db/shared/expired');
  Future<void> deleteEternalShares() =>
      _delete('/api/v1/admin/db/shared/eternal');

  // ── Server config (Settings) ──────────────────────────────────────────────

  Future<Map<String, dynamic>> getConfig() async =>
      Map<String, dynamic>.from(await _get('/api/v1/admin/config'));

  Future<void> _config(String path, Map<String, dynamic> body) =>
      _post('/api/v1/admin/config/$path', body);

  Future<void> setDbSynchronous(String mode) =>
      _config('db-synchronous', {'synchronous': mode}); // FULL|NORMAL
  Future<void> setDbCacheSize(int mb) =>
      _config('db-cache-size', {'cacheSizeMb': mb});
  Future<void> setCompression(String mode) =>
      _config('compression', {'mode': mode}); // none|gzip|brotli
  Future<void> setMaxRequestSize(String size) =>
      _config('max-request-size', {'maxRequestSize': size}); // e.g. 50MB
  Future<void> setUi(String ui) =>
      _config('ui', {'ui': ui}); // default|velvet
  Future<void> setPort(int port) => _config('port', {'port': port});
  Future<void> setAddress(String address) =>
      _config('address', {'address': address});
  Future<void> setTrustProxy(bool v) =>
      _config('trust-proxy', {'trustProxy': v});
  Future<void> setNoUpload(bool v) => _config('noupload', {'noUpload': v});
  Future<void> setNoMkdir(bool v) => _config('nomkdir', {'noMkdir': v});
  Future<void> setNoFileModify(bool v) =>
      _config('nofilemodify', {'noFileModify': v});
  Future<void> setWriteLogs(bool v) => _config('write-logs', {'writeLogs': v});
  Future<void> setLogBufferSize(int v) =>
      _config('log-buffer-size', {'logBufferSize': v});
  Future<void> setAutoBootServerAudio(bool v) =>
      _config('auto-boot-server-audio', {'autoBootServerAudio': v});
  Future<void> setRustPlayerPort(int port) =>
      _config('rust-player-port', {'rustPlayerPort': port});
  Future<void> regenerateSecret(int strength) =>
      _config('secret', {'strength': strength});

  /// adminAccess: `{mode: all|none|localhost|whitelist, whitelist?: [..]}`
  Future<void> setAdminAccess(String mode, {List<String>? whitelist}) =>
      _config('admin-access', {
        'mode': mode,
        'whitelist': ?whitelist,
      });

  /// Globally lock/unlock the entire admin API.
  Future<void> lockAdminApi(bool lock) =>
      _post('/api/v1/admin/lock-api', {'lock': lock});

  // ── Server audio backends ─────────────────────────────────────────────────

  /// `{backend, player, detectedCliPlayers}`
  Future<Map<String, dynamic>> serverAudioInfo() async =>
      Map<String, dynamic>.from(await _get('/api/v1/admin/server-audio/info'));

  /// Re-probe installed CLI players. `{detectedCliPlayers}`
  Future<Map<String, dynamic>> detectServerAudio() async =>
      Map<String, dynamic>.from(await _post('/api/v1/admin/server-audio/detect'));

  // ── SSL ───────────────────────────────────────────────────────────────────

  Future<void> setSsl(String certPath, String keyPath) =>
      _post('/api/v1/admin/ssl', {'cert': certPath, 'key': keyPath});
  Future<void> removeSsl() => _delete('/api/v1/admin/ssl');

  // ── Transcoding ───────────────────────────────────────────────────────────

  /// `{enabled, defaultCodec, defaultBitrate, autoUpdate, downloaded, ...}`
  Future<Map<String, dynamic>> getTranscode() async =>
      Map<String, dynamic>.from(await _get('/api/v1/admin/transcode'));

  Future<void> setDefaultCodec(String codec) =>
      _post('/api/v1/admin/transcode/default-codec', {'defaultCodec': codec});
  Future<void> setDefaultBitrate(String bitrate) => _post(
      '/api/v1/admin/transcode/default-bitrate', {'defaultBitrate': bitrate});
  Future<void> setTranscodeAutoUpdate(bool v) =>
      _post('/api/v1/admin/transcode/auto-update', {'autoUpdate': v});
  Future<void> downloadFfmpeg() =>
      _post('/api/v1/admin/transcode/download');

  // ── Logs ──────────────────────────────────────────────────────────────────

  /// `{logs: [{seq, level, message, timestamp}], lastSeq, capacity}`
  Future<Map<String, dynamic>> recentLogs({int? since}) async =>
      Map<String, dynamic>.from(await _get(
          '/api/v1/admin/logs/recent', since == null ? null : {'since': since}));

  /// URL the browser/app can hit directly to download the logs zip. The token
  /// rides as a query param because the server's auth middleware accepts
  /// `?token=` — a plain navigation/anchor can't set the x-access-token header.
  Uri logsDownloadUrl() => _u('/api/v1/admin/logs/download',
      session.token == null ? null : {'token': session.token});

  // ── DLNA ──────────────────────────────────────────────────────────────────

  /// `{mode, port, name, uuid, browse}`
  Future<Map<String, dynamic>> getDlna() async =>
      Map<String, dynamic>.from(await _get('/api/v1/admin/dlna'));

  Future<void> setDlnaMode(String mode, {int? port}) => _post(
      '/api/v1/admin/dlna/mode',
      {'mode': mode, 'port': ?port}); // disabled|same-port|separate-port
  Future<void> setDlnaName(String name) =>
      _post('/api/v1/admin/dlna/name', {'name': name});
  Future<void> setDlnaUuid(String uuid) =>
      _post('/api/v1/admin/dlna/uuid', {'uuid': uuid});
  Future<void> setDlnaBrowse(String browse) =>
      _post('/api/v1/admin/dlna/browse', {'browse': browse}); // flat|dirs|artist|album|genre

  // mDNS advertising is still a server feature (`discovery.mdns` in the config
  // file) but its admin routes were removed — it is config-file-only now, with
  // no endpoint to read or change it. There is deliberately no client for it.

  // ── Federation ────────────────────────────────────────────────────────────
  //
  // Mirrors `src/api/admin-federation.js`. Two halves that read alike but point
  // opposite ways: *keys* are credentials this server hands out so others may
  // read from it; *peers* are tickets it has been given so it can read from
  // them. `available: false` means the iroh native binary is missing for this
  // platform — the feature cannot run here at all, which is distinct from
  // `enabled: false` (switched off).

  /// `{enabled, available, running, endpointId, online, relayUrl, limitDefaults}`
  Future<Map<String, dynamic>> getFederation() async =>
      Map<String, dynamic>.from(await _get('/api/v1/admin/federation'));

  /// Returns `{enabled, available}` — `available: false` when the toggle was
  /// stored but the endpoint could not start on this platform.
  Future<Map<String, dynamic>> setFederationEnabled(bool enabled) async =>
      Map<String, dynamic>.from(
          await _post('/api/v1/admin/federation', {'enabled': enabled}));

  /// Rows carry `library_names`, `ticket`, `usage_today_bytes`, `is_expired`,
  /// `stream_kbps`, `daily_mb`, `max_streams`, `bound_endpoint_id`.
  Future<List<dynamic>> federationKeys() async {
    final r = await _get('/api/v1/admin/federation/keys');
    return r is List ? r : const [];
  }

  /// Mints a key for [vpaths]. Response includes the one-time `ticket` to hand
  /// to the other server. Limits of 0 mean "unlimited"; [expiresAt] must be a
  /// future ISO-8601 instant, or null for never.
  Future<Map<String, dynamic>> mintFederationKey(
    String name,
    List<String> vpaths, {
    int? streamKbps,
    int? dailyMb,
    int? maxStreams,
    String? expiresAt,
  }) async =>
      Map<String, dynamic>.from(
          await _post('/api/v1/admin/federation/keys', {
        'name': name,
        'vpaths': vpaths,
        'streamKbps': ?streamKbps,
        'dailyMb': ?dailyMb,
        'maxStreams': ?maxStreams,
        'expiresAt': ?expiresAt,
      }));

  /// Live limit edit. All three limits are required by the server; `expiresAt`
  /// is tri-state — omit to leave unchanged, null for never, ISO to renew.
  Future<void> setFederationKeyLimits(
    int id, {
    required int streamKbps,
    required int dailyMb,
    required int maxStreams,
    bool changeExpiry = false,
    String? expiresAt,
  }) =>
      _post('/api/v1/admin/federation/keys/$id/limits', {
        'streamKbps': streamKbps,
        'dailyMb': dailyMb,
        'maxStreams': maxStreams,
        if (changeExpiry) 'expiresAt': expiresAt,
      });

  /// Revokes the key and severs any live streams riding it.
  Future<void> deleteFederationKey(int id) =>
      _delete('/api/v1/admin/federation/keys/$id');

  /// Clears the TOFU endpoint binding so the key can be presented from a new
  /// endpoint (i.e. after the far side rebuilt its server identity).
  Future<void> resetFederationKeyBinding(int id) =>
      _post('/api/v1/admin/federation/keys/$id/reset-binding');

  /// Rows carry `name`, `last_seen`, `last_status`, `use_discovery`.
  Future<List<dynamic>> federationPeers() async {
    final r = await _get('/api/v1/admin/federation/peers');
    return r is List ? r : const [];
  }

  /// Adds a peer from a ticket pasted from the other server. [name] overrides
  /// the name embedded in the ticket.
  Future<Map<String, dynamic>> addFederationPeer(String ticket,
          {String? name}) async =>
      Map<String, dynamic>.from(
          await _post('/api/v1/admin/federation/peers', {
        'ticket': ticket,
        if (name != null && name.isNotEmpty) 'name': name,
      }));

  /// Health check; response is the probe result plus the refreshed `peer` row.
  Future<Map<String, dynamic>> testFederationPeer(int id) async =>
      Map<String, dynamic>.from(
          await _post('/api/v1/admin/federation/peers/$id/test'));

  /// Per-peer opt-out for OUTBOUND discovery queries (sending this peer our
  /// seed vectors). Inbound answering is unaffected.
  Future<void> setFederationPeerDiscovery(int id, bool enabled) =>
      _post('/api/v1/admin/federation/peers/$id/discovery', {'enabled': enabled});

  Future<void> deleteFederationPeer(int id) =>
      _delete('/api/v1/admin/federation/peers/$id');

  // ── Torrent ───────────────────────────────────────────────────────────────

  /// `{client, enabledFor, transmission, qbittorrent, deluge}`
  Future<Map<String, dynamic>> getTorrent() async =>
      Map<String, dynamic>.from(await _get('/api/v1/admin/torrent'));

  Future<void> setTorrentClient(String client) =>
      _post('/api/v1/admin/torrent/client', {'client': client});
  Future<void> setTorrentEnabledFor(String enabledFor) =>
      _post('/api/v1/admin/torrent/enabled-for', {'enabledFor': enabledFor});

  /// `{connected, configured, clientType, version?, rpcVersion?, reason?}`
  Future<Map<String, dynamic>> torrentStatus() async =>
      Map<String, dynamic>.from(await _get('/api/v1/admin/torrent/status'));

  /// `{torrents: [...], error, clientType}`
  Future<Map<String, dynamic>> torrentList() async =>
      Map<String, dynamic>.from(await _get('/api/v1/admin/torrent/list'));

  Future<Map<String, dynamic>> torrentTest(
          String client, Map<String, dynamic> creds) async =>
      Map<String, dynamic>.from(
          await _post('/api/v1/admin/torrent/$client/test', creds));
  Future<Map<String, dynamic>> torrentConnect(
          String client, Map<String, dynamic> creds) async =>
      Map<String, dynamic>.from(
          await _post('/api/v1/admin/torrent/$client/connect', creds));
  Future<void> torrentDisconnect(String client) =>
      _post('/api/v1/admin/torrent/$client/disconnect');

  Future<Map<String, dynamic>> removeTorrent(String infoHash) async =>
      Map<String, dynamic>.from(
          await _delete('/api/v1/admin/torrent/$infoHash'));

  /// `{clientType, vpaths: {name: {daemonPath, verified, source, ...}}}`
  Future<Map<String, dynamic>> torrentVpathAccess() async =>
      Map<String, dynamic>.from(await _get('/api/v1/admin/torrent/vpath-access'));

  Future<Map<String, dynamic>> torrentVpathAutoDetect({String? vpathName}) async =>
      Map<String, dynamic>.from(await _post(
          '/api/v1/admin/torrent/vpath-access/auto-detect',
          {'vpathName': ?vpathName}));

  Future<Map<String, dynamic>> torrentVpathManual(
          String vpathName, String daemonPath) async =>
      Map<String, dynamic>.from(await _post(
          '/api/v1/admin/torrent/vpath-access/manual',
          {'vpathName': vpathName, 'daemonPath': daemonPath}));

  /// `{vpaths: {name: {template}}, supportedVars, suggestedTemplate, sampleMetadata}`
  Future<Map<String, dynamic>> torrentPathTemplates() async =>
      Map<String, dynamic>.from(
          await _get('/api/v1/admin/torrent/path-templates'));

  Future<Map<String, dynamic>> setTorrentPathTemplate(
          String vpath, String? template) async =>
      Map<String, dynamic>.from(await _put(
          '/api/v1/admin/torrent/path-templates/$vpath', {'template': template}));

  // ── Backups ───────────────────────────────────────────────────────────────

  /// `{platform, homedir}`
  Future<Map<String, dynamic>> backupPlatform() async =>
      Map<String, dynamic>.from(await _get('/api/v1/admin/backup/platform'));

  /// `{destinations: [...]}`
  Future<List<dynamic>> backupDestinations() async {
    final r = await _get('/api/v1/admin/backup/destinations');
    return (r is Map && r['destinations'] is List)
        ? r['destinations']
        : <dynamic>[];
  }

  Future<Map<String, dynamic>> createBackupDestination(
          Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(
          await _post('/api/v1/admin/backup/destinations', body));

  Future<Map<String, dynamic>> updateBackupDestination(
          int id, Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(
          await _patch('/api/v1/admin/backup/destinations/$id', body));

  Future<void> deleteBackupDestination(int id) =>
      _delete('/api/v1/admin/backup/destinations/$id');

  /// `{status: queued|skipped, historyId?}`
  Future<Map<String, dynamic>> runBackup(int id) async =>
      Map<String, dynamic>.from(
          await _post('/api/v1/admin/backup/destinations/$id/run'));

  /// `{history: [...]}`
  Future<List<dynamic>> backupHistory(int id, {int limit = 50}) async {
    final r = await _get(
        '/api/v1/admin/backup/destinations/$id/history', {'limit': limit});
    return (r is Map && r['history'] is List) ? r['history'] : <dynamic>[];
  }

  /// `{active: {...}|null, queueLength}`
  Future<Map<String, dynamic>> backupStatus() async =>
      Map<String, dynamic>.from(await _get('/api/v1/admin/backup/status'));

  /// `{ok, errors, warnings, info}`
  Future<Map<String, dynamic>> backupCheckPath(
          int libraryId, String destPath) async =>
      Map<String, dynamic>.from(await _post('/api/v1/admin/backup/check-path',
          {'libraryId': libraryId, 'destPath': destPath}));
}
