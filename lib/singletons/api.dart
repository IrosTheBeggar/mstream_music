import './server_list.dart';
import './browser_list.dart';
import './log_manager.dart';
import './settings.dart';
import '../objects/server.dart';
import '../objects/display_item.dart';
import '../objects/metadata.dart';
import 'media.dart';
import '../util/stream_url.dart';
import '../theme/velvet_theme.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
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
      String getOrPost,
      {bool cancelable = true}) async {
    // Bracket every browse fetch so the browser can show one global loading bar,
    // block taps while it's in flight, and (when [cancelable]) let Back cancel
    // it. The per-call http.Client is what makes cancelLoading() actually abort
    // the request: closing the client makes the pending get/post throw. Mutating
    // calls (playlist create / rename / delete) pass cancelable: false so Back
    // can't abort them mid-flight — they still show the bar + block taps, they
    // just run to completion. The finally balances the in-flight set and closes
    // the client on every path (throw / HTTP error / cancel) so a socket is
    // never leaked.
    final client = http.Client();
    final int loadToken = BrowserManager()
        .beginLoading(onCancel: cancelable ? client.close : null);
    try {
      Server server = ServerManager().currentServer ??
          (throw Exception('No Server Selected'));

      if (server.unsupported) {
        throw Exception('Server Call Failed');
      }

      Uri currentUri = Uri.parse(server.url).resolve(location);

      final sw = Stopwatch()..start();
      var response;
      try {
        if (getOrPost == 'GET') {
          response = await client
              .get(currentUri, headers: {'x-access-token': server.jwt ?? ''});
        } else {
          response = await client.post(currentUri,
              body: json.encode(payload),
              headers: {
                'Content-Type': 'application/json',
                'x-access-token': server.jwt ?? ''
              });
        }
      } catch (e) {
        appLog('[api] $getOrPost $location → error: $e '
            '(${sw.elapsedMilliseconds}ms)');
        rethrow;
      }
      appLog('[api] $getOrPost $location → ${response.statusCode} '
          '(${sw.elapsedMilliseconds}ms)');

      if (response.statusCode > 299) {
        throw Exception('Server Call Failed');
      }

      // Back was pressed while this was in flight: drop the result so a slow
      // folder can't pop onto the stack after the user cancelled / navigated.
      // Skipped for non-cancelable mutations — those must run to completion.
      if (cancelable && BrowserManager().isLoadCancelled(loadToken)) {
        throw Exception('Navigation cancelled');
      }

      return jsonDecode(response.body);
    } finally {
      client.close();
      BrowserManager().endLoading(loadToken);
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

    res.forEach((e) {
      // Same transcode-aware stream URL as the rest of the app (honors the
      // /transcode endpoint + codec/bitrate when transcoding is on).
      final String streamUrl =
          buildServerStreamUrl(useThisServer!, e.toString());
      MediaItem lol = new MediaItem(
          id: streamUrl,
          title: e.split("/").last,
          extras: {'server': useThisServer.localname, 'path': e});
      MediaManager().audioHandler.addQueueItem(lol);
    });
  }

  // Builds 'playlist' DisplayItems from a getall response.
  List<DisplayItem> _playlistItems(dynamic res, Server? server) {
    final List<DisplayItem> newList = [];
    res.forEach((e) {
      newList.add(new DisplayItem(server, e['name'], 'playlist', e['name'],
          Icon(Icons.queue_music, color: VelvetColors.textSecondary), null));
    });
    return newList;
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
    BrowserManager().addListToStack(_playlistItems(res, useThisServer));
  }

  /// Re-fetches playlists and replaces the current view in place (no new
  /// back-stack frame) — used after a create / rename so the list updates
  /// without pushing a navigation entry.
  Future<void> refreshPlaylists() async {
    var res;
    try {
      res = await makeServerCall(null, '/api/v1/playlist/getall', {}, 'GET');
    } catch (err) {
      print(err);
      return;
    }
    BrowserManager()
        .replaceTop(_playlistItems(res, ServerManager().currentServer));
  }

  /// Creates an empty playlist (POST /playlist/new). Throws on failure (e.g. the
  /// server's 400 when the name already exists) so the caller can surface it.
  Future<void> createPlaylist(String title) async {
    await makeServerCall(null, '/api/v1/playlist/new', {'title': title}, 'POST',
        cancelable: false);
    await refreshPlaylists();
  }

  /// Renames a playlist (POST /playlist/rename). Throws on failure.
  Future<void> renamePlaylist(String oldName, String newName) async {
    await makeServerCall(null, '/api/v1/playlist/rename',
        {'oldName': oldName, 'newName': newName}, 'POST', cancelable: false);
    await refreshPlaylists();
  }

  Future<void> removePlaylist(String playlistId,
      {Server? useThisServer}) async {
    try {
      await makeServerCall(useThisServer, '/api/v1/playlist/delete',
          {'playlistname': playlistId}, 'POST', cancelable: false);
    } catch (err) {
      // TODO: Handle Errors
      print(err);
      return;
    }

    BrowserManager().removeAll(playlistId, useThisServer!, 'playlist');
  }

  Future<void> searchServer(String search) async {
    try {
      // The user's search-scope setting decides which of the endpoint's four
      // categories to query. `everything` (the default) reproduces mStream's
      // classic artists+albums+songs search; a single-category scope sends the
      // other three `no*` flags so the server only does the work that's asked.
      final scope = SettingsManager().searchScope;
      var res = await makeServerCall(null, '/api/v1/db/search', {
        'search': search,
        'noArtists': !scope.includeArtists,
        'noAlbums': !scope.includeAlbums,
        'noTitles': !scope.includeSongs,
        'noFiles': !scope.includeFiles,
      }, 'POST');

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

      // Files (filepath matches) — only populated when the scope is `files`.
      // Same shape as titles (name + filepath); guarded with `?.` because
      // older servers may omit the key entirely. The row renders as a file:
      // getText shows the filename, so we surface the folder as the subtitle.
      res['files']?.forEach((e) {
        final String fp = e['filepath'];
        final int slash = fp.lastIndexOf('/');
        DisplayItem newItem = new DisplayItem(
            ServerManager().currentServer,
            e['name'],
            'file',
            '/' + fp,
            Icon(Icons.insert_drive_file, color: VelvetColors.accent),
            slash > 0 ? fp.substring(0, slash) : null);
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
      // Newer servers include `album_artist`; fold it into the subtitle as
      // "Artist · Year" for the browse card/list. Older servers omit it, so the
      // subtitle gracefully falls back to just the year.
      final artist = (e['album_artist'] ?? e['albumArtist'] ?? e['artist'])
          ?.toString()
          .trim();
      final year = e['year']?.toString().trim();
      final subtitle = [
        if (artist != null && artist.isNotEmpty) artist,
        if (year != null && year.isNotEmpty) year,
      ].join(' · ');
      DisplayItem newItem = new DisplayItem(
          useThisServer,
          e['name'],
          'album',
          e['name'],
          Icon(Icons.album, color: VelvetColors.textSecondary),
          subtitle);
      newItem.altAlbumArt = e['album_art_file'];
      newList.add(newItem);
    });

    BrowserManager().addListToStack(newList, alphabetical: true);
  }

  /// Fetches an album's songs as a list of `file` DisplayItems WITHOUT touching
  /// the browser stack — used by the album detail screen, which renders its own
  /// tracklist. Throws on a server error so the caller can show its own state.
  Future<List<DisplayItem>> fetchAlbumSongs(String? album,
      {Server? useThisServer}) async {
    final res = await makeServerCall(
        useThisServer, '/api/v1/db/album-songs', {'album': album}, 'POST');

    final List<DisplayItem> newList = [];
    res.forEach((e) {
      MusicMetadata m = MusicMetadata.fromServerMap(e['metadata']);

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
    return newList;
  }

  Future<void> getAlbumSongs(String? album, {Server? useThisServer}) async {
    List<DisplayItem> newList;
    try {
      newList = await fetchAlbumSongs(album, useThisServer: useThisServer);
    } catch (err) {
      // TODO: Handle Errors
      print(err);
      return;
    }

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
      MusicMetadata m = MusicMetadata.fromServerMap(e['metadata']);

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
      MusicMetadata m = MusicMetadata.fromServerMap(e['metadata']);

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
      MusicMetadata m = MusicMetadata.fromServerMap(e['metadata']);

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
      final outer = e['metadata'];
      final inner = outer is Map ? outer['metadata'] : null;
      if (inner is Map) {
        newItem.metadata = MusicMetadata.fromServerMap(inner);
      }

      newList.add(newItem);
    });

    BrowserManager()
        .addListToStack(newList, alphabetical: true, path: res['path']);
  }
}
