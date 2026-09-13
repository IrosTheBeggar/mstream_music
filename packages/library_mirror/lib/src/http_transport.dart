import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'transport.dart';

/// One mStream server as the headless transports see it: the base URL
/// (scheme, host, port, optional path prefix) and the token from
/// `POST /api/v1/auth/login` — or none in public mode. The URL shapes match
/// the app's (`buildServerDownloadUrl`, `buildAlbumArtUrl`) so a copy made
/// by the CLI and one made by the app are the same files.
class MirrorServer {
  final String base;
  final String? token;

  MirrorServer(String base, {this.token})
      : base = base.replaceFirst(RegExp(r'/+$'), '');

  Uri api(String location) => Uri.parse('$base$location');

  Map<String, String> get headers => {'x-access-token': token ?? ''};

  Map<String, String> get jsonHeaders =>
      {...headers, 'Content-Type': 'application/json'};

  /// The file behind a data path (`/<vpath>/<rel>`).
  Uri media(String dataPath) => Uri.parse(
      '$base/media${encodeDataPath(dataPath)}${token == null ? '' : '?token=$token'}');

  /// A cover by its content-addressed name, at the list-row size.
  Uri art(String artFile, {String compress = 'm'}) => Uri.parse(Uri.encodeFull(
      '$base/album-art/$artFile?compress=$compress${token == null ? '' : '&token=$token'}'));

  /// Each path segment percent-encoded, leading slash kept.
  static String encodeDataPath(String dataPath) => [
        for (final e in dataPath.split('/'))
          if (e.isNotEmpty) '/${Uri.encodeComponent(e)}'
      ].join();

  /// Signs in and returns the server bound to its token.
  static Future<MirrorServer> login(
      String base, String username, String password,
      {http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final s = MirrorServer(base);
      final res = await c
          .post(s.api('/api/v1/auth/login'),
              body: {'username': username, 'password': password})
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        throw HttpException('login: HTTP ${res.statusCode}');
      }
      final token = (jsonDecode(res.body) as Map)['token'];
      if (token is! String || token.isEmpty) {
        throw const HttpException('login: no token in the reply');
      }
      return MirrorServer(base, token: token);
    } finally {
      if (client == null) c.close();
    }
  }
}

const Duration _timeout = Duration(seconds: 60);

Future<dynamic> _json(Future<http.Response> send, String what) async {
  final res = await send.timeout(_timeout);
  if (res.statusCode != 200) throw HttpException('$what: HTTP ${res.statusCode}');
  return jsonDecode(res.body);
}

/// `POST /api/v1/sync/manifest`, one page at a time, with the revision
/// ETag so an unchanged library is a 304.
class HttpManifestClient implements ManifestClient {
  final MirrorServer server;
  final http.Client client;
  HttpManifestClient(this.server, this.client);

  @override
  Future<ManifestPage?> fetchPage(
      {int? cursor, int limit = 2000, String? ifNoneMatch}) async {
    final headers = {...server.jsonHeaders};
    if (ifNoneMatch != null) headers['If-None-Match'] = '"$ifNoneMatch"';
    final res = await client
        .post(server.api('/api/v1/sync/manifest'),
            headers: headers,
            body: jsonEncode({'cursor': ?cursor, 'limit': limit}))
        .timeout(_timeout);
    if (res.statusCode == 304) return null;
    if (res.statusCode != 200) {
      throw HttpException('manifest: HTTP ${res.statusCode}');
    }
    return ManifestPage.fromJson(
        (jsonDecode(res.body) as Map).cast<String, dynamic>());
  }
}

/// Streams `/media/<path>` straight to the destination file.
class HttpDownloader implements Downloader {
  final MirrorServer server;
  final http.Client client;
  HttpDownloader(this.server, this.client);

  @override
  Future<void> download(String path, String destination,
      {bool requiresWiFi = false}) async {
    final res = await client
        .send(http.Request('GET', server.media(path)))
        .timeout(_timeout);
    if (res.statusCode != 200) {
      await res.stream.drain<void>();
      throw HttpException('media$path: HTTP ${res.statusCode}');
    }
    final sink = File(destination).openWrite();
    try {
      await sink.addStream(res.stream);
    } finally {
      await sink.close();
    }
  }
}

/// The browse lists the index keeps for offline use.
class HttpListsClient implements LibraryListsClient {
  final MirrorServer server;
  final http.Client client;
  HttpListsClient(this.server, this.client);

  Future<dynamic> _get(String location) =>
      _json(client.get(server.api(location), headers: server.headers), location);

  Future<dynamic> _post(String location, Map<String, dynamic> body) => _json(
      client.post(server.api(location),
          headers: server.jsonHeaders, body: jsonEncode(body)),
      location);

  static String _dataPath(String fp) => fp.startsWith('/') ? fp : '/$fp';

  @override
  Future<List<AlbumRow>> albums() async {
    final res = await _get('/api/v1/db/albums');
    return [
      for (final e in (res['albums'] as List? ?? const []))
        if (e is Map && e['name'] is String)
          AlbumRow(
            name: e['name'] as String,
            albumArtist: (e['album_artist'] ?? e['albumArtist'] ?? e['artist'])
                ?.toString(),
            year: (e['year'] as num?)?.toInt(),
            art: e['album_art_file'] as String?,
          ),
    ];
  }

  @override
  Future<List<String>> artists() async {
    final res = await _get('/api/v1/db/artists');
    return [
      for (final e in (res['artists'] as List? ?? const []))
        if (e is String)
          e
        else if (e is Map && e['name'] is String)
          e['name'] as String,
    ];
  }

  @override
  Future<Map<String, int>> genres() async {
    final res = await _post('/api/v1/db/genres', {});
    return {
      for (final e in (res['genres'] as List? ?? const []))
        if (e is Map && e['name'] is String)
          e['name'] as String: (e['track_count'] as num?)?.toInt() ?? 0,
    };
  }

  @override
  Future<List<PlaylistRow>> playlists() async {
    final names = await _get('/api/v1/playlist/getall');
    final out = <PlaylistRow>[];
    for (final e in (names as List? ?? const [])) {
      final name = e is Map ? e['name'] : null;
      if (name is! String) continue;
      final items =
          await _post('/api/v1/playlist/load', {'playlistname': name});
      out.add(PlaylistRow(id: name, name: name, paths: [
        for (final t in (items as List? ?? const []))
          if (t is Map && t['filepath'] is String)
            _dataPath(t['filepath'] as String),
      ]));
    }
    return out;
  }

  @override
  Future<Map<String, int>> rated() async {
    final res = await _get('/api/v1/db/rated');
    return {
      for (final e in (res as List? ?? const []))
        if (e is Map &&
            e['filepath'] is String &&
            (e['metadata'] as Map?)?['rating'] is num)
          _dataPath(e['filepath'] as String):
              ((e['metadata'] as Map)['rating'] as num).toInt(),
    };
  }
}

/// Album art by its content-addressed name.
class HttpArtClient implements ArtClient {
  final MirrorServer server;
  final http.Client client;
  HttpArtClient(this.server, this.client);

  @override
  Future<void> fetchArt(String artFile, String destination) async {
    final res = await client.get(server.art(artFile)).timeout(_timeout);
    if (res.statusCode != 200) {
      throw HttpException('album-art/$artFile: HTTP ${res.statusCode}');
    }
    await File(destination).writeAsBytes(res.bodyBytes, flush: true);
  }
}
