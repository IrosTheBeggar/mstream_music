import './server_list.dart';
import './browser_list.dart';
import './settings.dart';
import '../objects/server.dart';
import '../objects/display_item.dart';
import '../objects/metadata.dart';
import 'media.dart';
import '../theme/velvet_theme.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:audio_service/audio_service.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiManager {
  ApiManager._privateConstructor();
  static final ApiManager _instance = ApiManager._privateConstructor();
  factory ApiManager() {
    return _instance;
  }

  /// POST /api/v1/db/genres — returns the server's distinct genre
  /// list with track counts. Used by the AutoDJ screen to populate
  /// the genre-picker autocomplete.
  ///
  /// Each entry is `{ name: String, track_count: int }`.
  Future<List<Map<String, dynamic>>> getGenres({
    Server? useThisServer,
    List<String>? ignoreVPaths,
  }) async {
    final server = useThisServer ?? ServerManager().currentServer;
    if (server == null) throw Exception('No server selected');

    final body = <String, dynamic>{};
    if (ignoreVPaths != null && ignoreVPaths.isNotEmpty) {
      body['ignoreVPaths'] = ignoreVPaths;
    }

    final response = await http.post(
      Uri.parse(server.url).resolve('/api/v1/db/genres'),
      body: jsonEncode(body),
      headers: {
        'Content-Type': 'application/json',
        'x-access-token': server.jwt ?? '',
      },
    );
    if (response.statusCode > 299) {
      throw Exception('Failed to fetch genres (HTTP ${response.statusCode})');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(decoded['genres'] ?? []);
  }

  /// POST /api/v1/share — creates a share link for [filepaths] on
  /// [server]. [expiresInDays] null means the link never expires.
  /// Returns the raw server response (notably `playlistId`).
  Future<Map<String, dynamic>> sharePlaylist({
    required Server server,
    required List<String> filepaths,
    int? expiresInDays,
  }) async {
    final uri = Uri.parse(server.url).resolve('/api/v1/share');
    final body = <String, dynamic>{'playlist': filepaths};
    if (expiresInDays != null) body['time'] = expiresInDays;

    final response = await http.post(
      uri,
      body: json.encode(body),
      headers: {
        'Content-Type': 'application/json',
        'x-access-token': server.jwt ?? '',
      },
    );

    if (response.statusCode > 299) {
      throw Exception('Share failed (HTTP ${response.statusCode})');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future makeServerCall(Server? currentServer, String location, Map payload,
      String getOrPost) async {
    // Bracket every browse fetch so the browser can show one global
    // loading bar. The finally guarantees the in-flight counter is
    // balanced even on the early throws / HTTP-error / network paths.
    BrowserManager().beginLoading();
    try {
      Server server = ServerManager().currentServer ??
          (throw Exception('No Server Selected'));

      if (server.unsupported) {
        throw Exception('Server Call Failed');
      }

      Uri currentUri = Uri.parse(server.url).resolve(location);

      var response;
      if (getOrPost == 'GET') {
        response = await http
            .get(currentUri, headers: {'x-access-token': server.jwt ?? ''});
      } else {
        response = await http.post(currentUri,
            body: json.encode(payload),
            headers: {
              'Content-Type': 'application/json',
              'x-access-token': server.jwt ?? ''
            });
      }

      if (response.statusCode > 299) {
        throw Exception('Server Call Failed');
      }

      return jsonDecode(response.body);
    } finally {
      BrowserManager().endLoading();
    }
  }

  Future<void> getRecursiveFiles(String directory,
      {Server? useThisServer}) async {
    var res;
    try {
      res = await makeServerCall(useThisServer,
          '/api/v1/file-explorer/recursive', {"directory": directory}, 'POST');
    } catch (err) {
      // TODO: Handle Errors
      print(err);
      return;
    }

    // String prefix =
    //     TranscodeManager().transcodeOn == true ? '/transcode' : '/media';

    res.forEach((e) {
      String lolUrl = Uri.encodeFull(useThisServer!.url +
          '/media' +
          (e.toString()[0] != '/' ? '/' : '') +
          e +
          '?app_uuid=' +
          Uuid().v4() +
          (useThisServer.jwt == null ? '' : '&token=' + useThisServer.jwt!));

      MediaItem lol = new MediaItem(
          id: lolUrl,
          title: e.split("/").last,
          extras: {'server': useThisServer.localname, 'path': e});
      MediaManager().audioHandler.addQueueItem(lol);
    });
  }

  Future<void> getPlaylists({Server? useThisServer}) async {
    var res;
    try {
      res = await makeServerCall(
          useThisServer, '/api/v1/playlist/getall', {}, 'GET');
    } catch (err) {
      // TODO: Handle Errors
      print(err);
      return;
    }

    BrowserManager().setBrowserLabel('Playlists');

    List<DisplayItem> newList = [];
    res.forEach((e) {
      DisplayItem newItem = new DisplayItem(
          useThisServer,
          e['name'],
          'playlist',
          e['name'],
          Icon(Icons.queue_music, color: VelvetColors.textSecondary),
          null);
      newList.add(newItem);
    });

    BrowserManager().addListToStack(newList);
  }

  Future<void> removePlaylist(String playlistId,
      {Server? useThisServer}) async {
    try {
      await makeServerCall(useThisServer, '/api/v1/playlist/delete',
          {'playlistname': playlistId}, 'POST');
    } catch (err) {
      // TODO: Handle Errors
      print(err);
      return;
    }

    BrowserManager().removeAll(playlistId, useThisServer!, 'playlist');
  }

  Future<void> searchServer(String search) async {
    try {
      var res = await makeServerCall(null, '/api/v1/db/search',
          {'noFiles': true, 'search': search}, 'POST');

      BrowserManager().setBrowserLabel('Search');
      List<DisplayItem> newList = [];
      res['artists'].forEach((e) {
        DisplayItem newItem = new DisplayItem(
            ServerManager().currentServer,
            e['name'],
            'artist',
            e['name'],
            Icon(Icons.library_music, color: VelvetColors.textSecondary),
            'artist');
        newItem.altAlbumArt = e['album_art_file'];
        newList.add(newItem);
      });

      res['albums'].forEach((e) {
        DisplayItem newItem = new DisplayItem(
            ServerManager().currentServer,
            e['name'],
            'album',
            e['name'],
            Icon(Icons.library_music, color: VelvetColors.textSecondary),
            'album');
        newItem.altAlbumArt = e['album_art_file'];
        newList.add(newItem);
      });

      res['title'].forEach((e) {
        DisplayItem newItem = new DisplayItem(
            ServerManager().currentServer,
            e['name'],
            'file',
            '/' + e['filepath'],
            Icon(Icons.music_note, color: VelvetColors.accent),
            'song');
        newItem.altAlbumArt = e['album_art_file'];
        newList.add(newItem);
      });

      BrowserManager().addListToStack(newList);
    } catch (err) {
      print(err);
    }
  }

  Future<void> getAlbums({Server? useThisServer}) async {
    var res;
    try {
      res = await makeServerCall(useThisServer, '/api/v1/db/albums', {}, 'GET');
    } catch (err) {
      // TODO: Handle Errors
      print(err);
      return;
    }

    BrowserManager().setBrowserLabel('Albums');

    List<DisplayItem> newList = [];
    res['albums'].forEach((e) {
      DisplayItem newItem = new DisplayItem(
          useThisServer,
          e['name'],
          'album',
          e['name'],
          Icon(Icons.album, color: VelvetColors.textSecondary),
          e['year']?.toString() ?? '');
      newItem.altAlbumArt = e['album_art_file'];
      newList.add(newItem);
    });

    BrowserManager().addListToStack(newList, alphabetical: true);
  }

  Future<void> getAlbumSongs(String? album, {Server? useThisServer}) async {
    var res;
    try {
      res = await makeServerCall(
          useThisServer, '/api/v1/db/album-songs', {'album': album}, 'POST');
    } catch (err) {
      // TODO: Handle Errors
      print(err);
      return;
    }

    List<DisplayItem> newList = [];
    res.forEach((e) {
      MusicMetadata m = new MusicMetadata(
          e['metadata']['artist'],
          e['metadata']['album'],
          e['metadata']['title'],
          e['metadata']['track'],
          e['metadata']['disc'],
          e['metadata']['year'],
          e['metadata']['hash'],
          e['metadata']['rating'],
          e['metadata']['album-art'],
          bpm: e['metadata']['bpm'],
          musicalKey: e['metadata']['musical-key']);

      DisplayItem newItem = new DisplayItem(
          useThisServer,
          e['filepath'],
          'file',
          '/' + e['filepath'],
          Icon(Icons.music_note, color: VelvetColors.accent),
          null);

      newItem.metadata = m;

      newList.add(newItem);
    });

    BrowserManager().addListToStack(newList);
  }

  Future<void> getRecentlyAdded({Server? useThisServer}) async {
    var res;
    try {
      res = await makeServerCall(
          useThisServer, '/api/v1/db/recent/added', {'limit': 100}, 'POST');
    } catch (err) {
      // TODO: Handle Errors
      print(err);
      return;
    }

    BrowserManager().setBrowserLabel('Recent');

    List<DisplayItem> newList = [];
    res.forEach((e) {
      MusicMetadata m = new MusicMetadata(
          e['metadata']['artist'],
          e['metadata']['album'],
          e['metadata']['title'],
          e['metadata']['track'],
          e['metadata']['disc'],
          e['metadata']['year'],
          e['metadata']['hash'],
          e['metadata']['rating'],
          e['metadata']['album-art'],
          bpm: e['metadata']['bpm'],
          musicalKey: e['metadata']['musical-key']);

      DisplayItem newItem = new DisplayItem(
          useThisServer,
          e['filepath'],
          'file',
          '/' + e['filepath'],
          Icon(Icons.music_note, color: VelvetColors.accent),
          null);

      newItem.metadata = m;

      newList.add(newItem);
    });
    BrowserManager().addListToStack(newList);
  }

  Future<void> getRated({Server? useThisServer}) async {
    var res;
    try {
      res = await makeServerCall(useThisServer, '/api/v1/db/rated', {}, 'GET');
    } catch (err) {
      // TODO: Handle Errors
      print(err);
      return;
    }

    BrowserManager().setBrowserLabel('Rated');

    List<DisplayItem> newList = [];
    res.forEach((e) {
      MusicMetadata m = new MusicMetadata(
          e['metadata']['artist'],
          e['metadata']['album'],
          e['metadata']['title'],
          e['metadata']['track'],
          e['metadata']['disc'],
          e['metadata']['year'],
          e['metadata']['hash'],
          e['metadata']['rating'],
          e['metadata']['album-art'],
          bpm: e['metadata']['bpm'],
          musicalKey: e['metadata']['musical-key']);

      DisplayItem newItem = new DisplayItem(
          useThisServer,
          e['filepath'],
          'file',
          '/' + e['filepath'],
          Icon(Icons.music_note, color: VelvetColors.accent),
          m.artist);

      newItem.metadata = m;
      newItem.showRating = true;

      newList.add(newItem);
    });
    BrowserManager().addListToStack(newList);
  }

  Future<void> getArtists({Server? useThisServer}) async {
    var res;
    try {
      res =
          await makeServerCall(useThisServer, '/api/v1/db/artists', {}, 'GET');
    } catch (err) {
      // TODO: Handle Errors
      print(err);
      return;
    }

    BrowserManager().setBrowserLabel('Artists');

    List<DisplayItem> newList = [];
    res['artists'].forEach((e) {
      DisplayItem newItem = new DisplayItem(useThisServer, e, 'artist', e,
          Icon(Icons.library_music, color: VelvetColors.textSecondary), null);
      newList.add(newItem);
    });
    BrowserManager().addListToStack(newList, alphabetical: true);
  }

  Future<void> getArtistAlbums(String artist, {Server? useThisServer}) async {
    var res;
    try {
      res = await makeServerCall(useThisServer, '/api/v1/db/artists-albums',
          {'artist': artist}, 'POST');
    } catch (err) {
      // TODO: Handle Errors
      print(err);
      return;
    }

    List<DisplayItem> newList = [];
    res['albums'].forEach((e) {
      String name = e['name'] ?? 'SINGLES';

      // TODO: Errors on singles
      DisplayItem newItem = new DisplayItem(
          useThisServer,
          name,
          'album',
          e['name'],
          Icon(Icons.album, color: VelvetColors.textSecondary),
          e['year']?.toString() ?? '');
      newItem.altAlbumArt = e['album_art_file'];

      newList.add(newItem);
    });

    BrowserManager().addListToStack(newList);
  }

  Future<void> getPlaylistContents(String playlistName,
      {Server? useThisServer}) async {
    var res;
    try {
      res = await makeServerCall(useThisServer, '/api/v1/playlist/load',
          {'playlistname': playlistName}, 'POST');
    } catch (err) {
      // TODO: Handle Errors
      print(err);
      return;
    }

    List<DisplayItem> newList = [];
    res.forEach((e) {
      MusicMetadata m = new MusicMetadata(
          e['metadata']['artist'],
          e['metadata']['album'],
          e['metadata']['title'],
          e['metadata']['track'],
          e['metadata']['disc'],
          e['metadata']['year'],
          e['metadata']['hash'],
          e['metadata']['rating'],
          e['metadata']['album-art'],
          bpm: e['metadata']['bpm'],
          musicalKey: e['metadata']['musical-key']);

      DisplayItem newItem = new DisplayItem(
          useThisServer,
          e['filepath'],
          'file',
          '/' + e['filepath'],
          Icon(Icons.music_note, color: VelvetColors.accent),
          null);

      newItem.metadata = m;
      newList.add(newItem);
    });

    BrowserManager().addListToStack(newList);
  }

  Future<void> getFileList(String directory, {Server? useThisServer}) async {
    var res;
    try {
      res = await makeServerCall(useThisServer, '/api/v1/file-explorer', {
        "directory": directory,
        // Server defaults this to false (cheap listing). When the user
        // has the setting on, the server returns a `metadata` field on
        // each file entry — we attach it to the DisplayItem below so
        // that when the user taps to queue, browser.dart's addFile
        // sees a populated metadata object and the resulting MediaItem
        // carries title/artist/album/art into the player and the
        // notification.
        "pullMetadata": SettingsManager().fileExplorerMetadata,
      }, 'POST');
    } catch (err) {
      // TODO: Handle Errors
      print(err);
      return;
    }

    BrowserManager().setBrowserLabel('File Explorer');

    List<DisplayItem> newList = [];
    res['directories'].forEach((e) {
      DisplayItem newItem = new DisplayItem(
          useThisServer,
          e['name'],
          'directory',
          path.join(res['path'], e['name']),
          Icon(Icons.folder, color: VelvetColors.warning),
          null);
      newList.add(newItem);
    });

    res['files'].forEach((e) {
      DisplayItem newItem = new DisplayItem(
          useThisServer,
          e['name'],
          'file',
          path.join(res['path'], e['name']),
          Icon(Icons.music_note, color: VelvetColors.accent),
          null);

      // The server wraps each file's metadata as { filepath, metadata:
      // {…actual fields…} } — drill in one level. Only set when
      // pullMetadata=true was sent AND the file is in the library DB
      // (unscanned files still arrive without an inner metadata
      // object; we tolerate that and fall back to filename display).
      // Field name quirk: server uses `disk`, not `disc`.
      final outer = e['metadata'];
      final inner = outer is Map ? outer['metadata'] : null;
      if (inner is Map) {
        newItem.metadata = MusicMetadata(
            inner['artist'],
            inner['album'],
            inner['title'],
            inner['track'],
            inner['disk'] ?? inner['disc'],
            inner['year'],
            inner['hash'] ?? '',
            inner['rating'],
            inner['album-art'],
            bpm: inner['bpm'],
            musicalKey: inner['musical-key']);
      }

      newList.add(newItem);
    });

    BrowserManager().addListToStack(newList,
        alphabetical: true, directory: res['path']?.toString());
  }

  // ── yt-dlp ─────────────────────────────────────────────────────────
  // Download audio from a (YouTube) URL straight into a server library
  // directory, mirroring the webapp's file-explorer "ytdl" tab. These
  // hit the base mStream routes (not the velvet adapters) and auth with
  // the same x-access-token makeServerCall uses.

  Map<String, String> _ytdlHeaders(Server s) => {'x-access-token': s.jwt ?? ''};

  // Best-effort list of audio formats the server has enabled
  // (GET /api/v1/ping → supportedAudioFiles). Falls back to the server's
  // own default ('mp3') on any error so the picker always has a value.
  Future<List<String>> ytdlCodecs() async {
    final s = ServerManager().currentServer;
    if (s == null) return const ['mp3'];
    try {
      final res = await http
          .get(Uri.parse(s.url).resolve('/api/v1/ping'),
              headers: _ytdlHeaders(s))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final saf = (jsonDecode(res.body) as Map)['supportedAudioFiles'];
        if (saf is Map) {
          final codecs = saf.entries
              .where((e) => e.value == true)
              .map((e) => e.key.toString())
              .toList();
          if (codecs.isNotEmpty) return codecs;
        }
      }
    } catch (_) {}
    return const ['mp3'];
  }

  // Metadata preview for [url] (GET /api/v1/ytdl/metadata):
  // { title, artist, album, year, thumbnail } — any field may be absent.
  Future<Map<String, dynamic>> ytdlMetadata(String url) async {
    final s = ServerManager().currentServer;
    if (s == null) throw Exception('No server selected');
    final uri = Uri.parse(s.url)
        .resolve('/api/v1/ytdl/metadata')
        .replace(queryParameters: {'url': url});
    final res = await http
        .get(uri, headers: _ytdlHeaders(s))
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw Exception(_ytdlError(res) ?? 'Could not read metadata');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // Start an async download (POST /api/v1/ytdl/). Only non-empty
  // [metadata] fields are forwarded. Throws with the server's error text
  // on failure (403 uploads-disabled, 500 no yt-dlp/ffmpeg, …).
  Future<void> ytdl({
    required String url,
    required String directory,
    String? outputCodec,
    Map<String, String> metadata = const {},
  }) async {
    final s = ServerManager().currentServer;
    if (s == null) throw Exception('No server selected');
    final body = <String, dynamic>{
      'directory': directory,
      'url': url,
      if (outputCodec != null && outputCodec.isNotEmpty)
        'outputCodec': outputCodec,
      'metadata': metadata,
    };
    final res = await http
        .post(Uri.parse(s.url).resolve('/api/v1/ytdl/'),
            body: jsonEncode(body),
            headers: {'Content-Type': 'application/json', ..._ytdlHeaders(s)})
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception(_ytdlError(res) ?? 'Download failed');
    }
  }

  // Poll active/finished downloads (GET /api/v1/ytdl/downloads). Each
  // entry: { pid, url, directory, outputCodec, status, startTime }.
  Future<List<Map<String, dynamic>>> ytdlDownloads() async {
    final s = ServerManager().currentServer;
    if (s == null) return const [];
    final res = await http
        .get(Uri.parse(s.url).resolve('/api/v1/ytdl/downloads'),
            headers: _ytdlHeaders(s))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return const [];
    final list = (jsonDecode(res.body) as Map)['downloads'];
    if (list is List) return List<Map<String, dynamic>>.from(list);
    return const [];
  }

  // ── Torrent ────────────────────────────────────────────────────────
  // Add a magnet / .torrent to the server's torrent client, into a
  // library directory — mirrors the webapp's file-explorer torrent tab.

  // Capability + destination probe for [path] (GET /torrent/preflight):
  // { active, clientType, displayName, noUpload, userAllowed, vpath,
  // subPath, vpathConfirmed, daemonPath, reason }.
  Future<Map<String, dynamic>> torrentPreflight(String path,
      {Server? server}) async {
    final s = server ?? ServerManager().currentServer;
    if (s == null) throw Exception('No server selected');
    final uri = Uri.parse(s.url)
        .resolve('/api/v1/torrent/preflight')
        .replace(queryParameters: {'path': path});
    final res = await http
        .get(uri, headers: {'x-access-token': s.jwt ?? ''})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception(_ytdlError(res) ?? 'Torrent unavailable');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // Submit a torrent (POST /torrent/add, multipart). Provide exactly one
  // of [magnet] or [torrentBytes]. Throws the server's message on
  // failure; returns { ok, name, downloadPath, isDuplicate,
  // renameWarning?, … } on success.
  Future<Map<String, dynamic>> torrentAdd({
    required String vpath,
    String? subPath,
    required String directoryName,
    bool renameRoot = false,
    String? magnet,
    List<int>? torrentBytes,
    String? torrentFilename,
    Server? server,
  }) async {
    final s = server ?? ServerManager().currentServer;
    if (s == null) throw Exception('No server selected');
    final req = http.MultipartRequest(
        'POST', Uri.parse(s.url).resolve('/api/v1/torrent/add'));
    req.headers['x-access-token'] = s.jwt ?? '';
    req.fields['vpath'] = vpath;
    if (subPath != null && subPath.isNotEmpty) req.fields['subPath'] = subPath;
    req.fields['directoryName'] = directoryName;
    req.fields['renameRoot'] = renameRoot ? 'true' : 'false';
    if (magnet != null && magnet.isNotEmpty) {
      req.fields['magnet'] = magnet;
    } else if (torrentBytes != null) {
      req.files.add(http.MultipartFile.fromBytes('torrentFile', torrentBytes,
          filename: torrentFilename ?? 'upload.torrent'));
    }
    final res = await http.Response.fromStream(
        await req.send().timeout(const Duration(seconds: 30)));
    Map<String, dynamic> body;
    try {
      body = res.body.isNotEmpty
          ? jsonDecode(res.body) as Map<String, dynamic>
          : <String, dynamic>{};
    } catch (_) {
      body = <String, dynamic>{};
    }
    if (res.statusCode != 200 || body['ok'] != true) {
      throw Exception(body['message']?.toString() ??
          body['error']?.toString() ??
          'Torrent add failed (HTTP ${res.statusCode})');
    }
    return body;
  }

  // Per-library destination templates (GET /torrent/path-templates):
  // { vpaths: { <name>: { template } }, supportedVars, suggestedTemplate }.
  Future<Map<String, dynamic>> torrentPathTemplates({Server? server}) async {
    final s = server ?? ServerManager().currentServer;
    if (s == null) throw Exception('No server selected');
    final res = await http
        .get(Uri.parse(s.url).resolve('/api/v1/torrent/path-templates'),
            headers: {'x-access-token': s.jwt ?? ''})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception(_ytdlError(res) ?? 'Could not load path templates');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // Server-side metadata detection for a .torrent (POST /auto-detect,
  // multipart). Returns the raw body — the caller checks `ok` /
  // `confidence` / `metadata` / `message`. [vpath] enables the server's
  // Tier-3 tag fetch.
  Future<Map<String, dynamic>> torrentAutoDetect({
    required List<int> torrentBytes,
    String? torrentFilename,
    String? vpath,
    Server? server,
  }) async {
    final s = server ?? ServerManager().currentServer;
    if (s == null) throw Exception('No server selected');
    final req = http.MultipartRequest(
        'POST', Uri.parse(s.url).resolve('/api/v1/torrent/auto-detect'));
    req.headers['x-access-token'] = s.jwt ?? '';
    if (vpath != null && vpath.isNotEmpty) req.fields['vpath'] = vpath;
    req.files.add(http.MultipartFile.fromBytes('torrentFile', torrentBytes,
        filename: torrentFilename ?? 'upload.torrent'));
    final res = await http.Response.fromStream(
        await req.send().timeout(const Duration(seconds: 45)));
    try {
      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic>) return body;
    } catch (_) {}
    return {
      'ok': false,
      'message': 'Auto-detect failed (HTTP ${res.statusCode})'
    };
  }

  // Pull the server's { error: "…" } message out of a failed response.
  String? _ytdlError(http.Response res) {
    try {
      final m = jsonDecode(res.body);
      if (m is Map && m['error'] != null) return m['error'].toString();
    } catch (_) {}
    return null;
  }
}
