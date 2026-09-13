import 'dart:async';

import './file_explorer.dart';
import './server_capabilities.dart';
import './server_list.dart';
import './browser_list.dart';
import './app_messenger.dart';
import './log_manager.dart';
import './library_index.dart';
import './library_source.dart';
import './outbox.dart';
import '../objects/server.dart';
import '../util/local_copy.dart';
import 'auto_dj_manager.dart';
import '../objects/discovery.dart';
import '../objects/display_item.dart';
import '../objects/lyrics.dart';
import '../objects/metadata.dart';
import 'media.dart';
import '../util/decode_json.dart';
import '../util/seed_vector.dart';
import '../util/server_version.dart';
import '../util/stream_url.dart';
import '../theme/velvet_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:audio_service/audio_service.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';

class ApiManager {
  ApiManager._privateConstructor();
  static final ApiManager _instance = ApiManager._privateConstructor();
  factory ApiManager() {
    return _instance;
  }

  // One keep-alive client for the direct (non-browse) calls — ratings,
  // metadata / lyrics / discovery / search fetches fire in bursts (queue
  // enrichment posts one per track, the Discover screen 3-4 per seed), and
  // the top-level http.* functions create and close a Client per call, paying
  // a fresh TCP+TLS handshake every time. makeServerCall deliberately keeps
  // its per-request Client: closing that one is what makes Back-cancel
  // actually abort a browse fetch.
  http.Client _direct = http.Client();

  /// Drop pooled connections. Called when the server list changes so sockets
  /// to a removed or re-credentialed server don't linger.
  void resetDirectClient() {
    _direct.close();
    _direct = http.Client();
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
    // Browsing the library copy: the counts the last run stored.
    final local = _localSource(server);
    if (local != null) {
      return [
        for (final g in local.index.genres(server.localname))
          {'name': g.name, 'track_count': g.trackCount},
      ];
    }

    final body = <String, dynamic>{};
    if (ignoreVPaths != null && ignoreVPaths.isNotEmpty) {
      body['ignoreVPaths'] = ignoreVPaths;
    }

    final response = await _direct
        .post(
          server.apiUri('/api/v1/db/genres'),
          body: jsonEncode(body),
          headers: {
            'Content-Type': 'application/json',
            'x-access-token': server.authToken ?? '',
          },
        )
        .timeout(const Duration(seconds: 15));
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
    final uri = server.apiUri('/api/v1/share');
    final body = <String, dynamic>{'playlist': filepaths};
    if (expiresInDays != null) body['time'] = expiresInDays;

    final response = await _direct
        .post(
          uri,
          body: json.encode(body),
          headers: {
            'Content-Type': 'application/json',
            'x-access-token': server.authToken ?? '',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode > 299) {
      throw Exception('Share failed (HTTP ${response.statusCode})');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// `GET /api/v1/lyrics?path=<vpath/relpath>` — fetches the lyrics the server has
  /// stored for a track (embedded plain text and/or a synced LRC). Returns null
  /// when there are none for this track (404) or the server predates the lyrics
  /// API; throws only on an unexpected transport / HTTP error so the lyrics
  /// screen can offer a retry. Direct http (like [rateSong]) so it stays off the
  /// browser loading bar. [filepath] is the track's data path — a leading slash
  /// is tolerated, and each segment is encoded like the stream-URL builder so
  /// spaces / specials are escaped while the `/` separators stay literal.
  Future<LyricsResult?> fetchLyrics(Server server, String filepath) async {
    final encodedPath = filepath
        .split('/')
        .where((s) => s.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('/');
    final uri = Uri.parse('${server.effectiveBaseUrl}/api/v1/lyrics'
        '?path=$encodedPath${server.localTokenQuery}');

    final response = await _direct
        .get(uri, headers: {'x-access-token': server.authToken ?? ''})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 404) return null; // no lyrics for this track
    if (response.statusCode > 299) {
      throw Exception('Lyrics fetch failed (HTTP ${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;
    final result = LyricsResult.fromJson(decoded);
    return result.isEmpty ? null : result;
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

      Uri currentUri = server.apiUri(location);

      final sw = Stopwatch()..start();
      Future<http.Response> send() => getOrPost == 'GET'
          ? client.get(currentUri, headers: {'x-access-token': server.authToken ?? ''})
          : client.post(currentUri, body: json.encode(payload), headers: {
              'Content-Type': 'application/json',
              'x-access-token': server.authToken ?? ''
            });
      http.Response response;
      // Transport, not identity: a peer of an iroh parent rides that tunnel.
      final bool isIroh = server.isIrohTransport;
      try {
        // For iroh, bound the request so a wedged tunnel fails fast instead of
        // hanging the global loading bar. HTTP gets a generous bound too — a
        // black-holed server (wrong LAN IP, firewalled port) used to hang the
        // bar for the OS TCP timeout, minutes. Back-cancel still aborts sooner.
        response = await send()
            .timeout(Duration(seconds: isIroh ? 20 : 30));
      } catch (e) {
        // An iroh connection error usually means the tunnel is mid-drop; give the
        // self-healing tunnel a moment to recover, then retry once. (Skip on a
        // user cancel — closing the client throws too.)
        if (isIroh && !BrowserManager().isLoadCancelled(loadToken)) {
          // Wait for THIS call's server (the tunnel may be serving a background
          // playback server instead of the browsed one).
          final ready = await ServerManager()
              .awaitTunnelReady(server: server, caller: 'browse');
          if (!ready) {
            appLog('[api] iroh tunnel down; $getOrPost $location failed: $e');
            rethrow;
          }
          currentUri = server.apiUri(location);
          response = await send().timeout(const Duration(seconds: 20));
        } else {
          appLog('[api] $getOrPost $location → error: $e '
              '(${sw.elapsedMilliseconds}ms)');
          rethrow;
        }
      }
      appLog('[api] $getOrPost $location → ${response.statusCode} '
          '(${sw.elapsedMilliseconds}ms)');

      // A direct peer refusing our guest token: the parent can hand out a
      // fresh one, and the tunnel keeps its port meanwhile.
      if (response.statusCode == 401 && server.isDirect) {
        unawaited(ServerManager().onDirectAuthRejected(server));
      }
      if (response.statusCode > 299) {
        throw Exception('Server Call Failed');
      }

      // Back was pressed while this was in flight: drop the result so a slow
      // folder can't pop onto the stack after the user cancelled / navigated.
      // Skipped for non-cancelable mutations — those must run to completion.
      if (cancelable && BrowserManager().isLoadCancelled(loadToken)) {
        throw Exception('Navigation cancelled');
      }

      // Whole-library payloads (artists / albums / playlist loads / recursive
      // listings) run multi-MB — decode those off the UI isolate.
      return decodeJsonBody(response.body);
    } finally {
      client.close();
      BrowserManager().endLoading(loadToken);
    }
  }

  Future<void> getRecursiveFiles(String directory,
      {required Server useThisServer}) async {
    try {
      final List<String> paths;
      var meta = const <String, MusicMetadata>{};
      final local = _localSource(useThisServer);
      if (local != null) {
        // Offline: the index knows every path under the folder and its
        // metadata, no round-trip at all.
        (paths, meta) = await local.recursiveTracks(useThisServer, directory);
      } else {
        final res = await makeServerCall(useThisServer,
            '/api/v1/file-explorer/recursive', {"directory": directory}, 'POST');
        paths = [for (final e in res as List) e.toString()];
        // The recursive endpoint returns bare paths, so fetch the metadata in
        // ONE batched request — never per row, because a recursive folder can
        // be thousands of files. Version-gated and best-effort exactly like
        // prefillMetadata: on an older server, a request failure, or a track
        // the DB doesn't know, the row queues bare (today's behaviour) and
        // tops itself up as it becomes current.
        if (paths.isNotEmpty &&
            !metadataBatchKnownUnsupported(
                ServerVersion.tryParse(useThisServer.serverVersion))) {
          meta = await fetchTrackMetadataBatch(useThisServer, paths);
        }
      }
      if (paths.isEmpty) return;

      // Resolve the download dir ONCE; the per-file existence check is a
      // cheap stat. Carrying localPath means an already-downloaded copy
      // plays from disk immediately, instead of streaming until the offline
      // sweep happens to re-mark it.
      final dir = await FileExplorer().getDownloadDir(
          useThisServer.storageMode, useThisServer.storageBasePath);

      final items = <MediaItem>[];
      for (final p in paths) {
        final m = meta[p.startsWith('/') ? p.substring(1) : p];
        final artUrl = m?.albumArt != null
            ? buildAlbumArtUrl(useThisServer, m!.albumArt!, compress: 'l')
            : null;
        // The download tree (the same on-disk formula the sweep writes with)
        // or the server's mirror root — see localCopyCandidates.
        final localPath =
            firstExistingSync(localCopyCandidates(useThisServer, dir, p));
        final isLocal = localPath != null;
        items.add(MediaItem(
          // Same transcode-aware stream URL as the rest of the app (honors
          // the /transcode endpoint + codec/bitrate when transcoding is on).
          id: buildServerStreamUrl(useThisServer, p),
          title: m?.title ?? p.split("/").last,
          album: m?.album,
          artist: m?.artist,
          genre: m?.genreLabel,
          duration: m?.duration,
          artUri: artUrl == null ? null : Uri.parse(artUrl),
          extras: {
            if (m != null)
              // The same full map a browse-added track gets.
              ...queueExtras(m,
                  server: useThisServer.localname, path: p, artUrl: artUrl)
            else ...{
              // No metadata block — keep the bare shape. Deliberately NOT
              // queueExtras(null): that writes hasLyrics, whose presence
              // marks an item as complete and would stop _topUpExtras from
              // lazily filling it in as it plays.
              'server': useThisServer.localname,
              'path': p,
            },
            if (isLocal) 'localPath': localPath,
          },
        ));
      }
      final handler = MediaManager().audioHandler;
      final wasEmpty = handler.queue.value.isEmpty;
      // One batch append: a single queue emission + one backend call, instead
      // of N of each (every per-item add re-ran the whole-queue listeners —
      // iroh scan + offline sweep — making a big "Add all" O(N²)).
      await handler.addQueueItems(items);
      // "Add all" onto an EMPTY queue starts playing from the first track —
      // the same contract addRowsToQueue documents (a first add from a fresh
      // state shouldn't require a separate play press). addQueueItems parked
      // the spot on track 1, so the idle re-seed opens there rather than on
      // the idle stub's landing row.
      if (wasEmpty) await handler.play();
    } catch (err) {
      appLog('[api] getRecursiveFiles failed: $err');
    }
  }

  Future<void> getPlaylists({Server? useThisServer}) async {
    try {
      final server = _browseServer(useThisServer);
      final list = await _sourceFor(server).playlists(server);
      BrowserManager().setBrowserLabel('Playlists');
      BrowserManager().addListToStack(list);
    } catch (err) {
      // TODO: Handle Errors
      appLog('[api] getPlaylists failed: $err');
    }
  }

  /// Re-fetches playlists and replaces the current view in place (no new
  /// back-stack frame) — used after a create / rename so the list updates
  /// without pushing a navigation entry.
  Future<void> refreshPlaylists() async {
    try {
      final server = _browseServer(null);
      BrowserManager().replaceTop(await _sourceFor(server).playlists(server));
    } catch (err) {
      appLog('[api] refreshPlaylists failed: $err');
    }
  }

  /// Creates an empty playlist (POST /playlist/new). Throws on failure (e.g. the
  /// server's 400 when the name already exists) so the caller can surface it.
  Future<void> createPlaylist(String title) async {
    final server = _browseServer(null);
    final payload = {'title': title};
    if (server.browseOffline) {
      if (!OutboxManager().enqueue(server, OutboxOp.playlistNew, payload)) {
        throw Exception('Playlist create failed (offline, no index)');
      }
    } else {
      await makeServerCall(server, '/api/v1/playlist/new', payload, 'POST',
          cancelable: false);
      OutboxManager().applyLocally(server, OutboxOp.playlistNew, payload);
    }
    await refreshPlaylists();
  }

  /// POST /api/v1/playlist/add-song — appends the track at [filepath] to
  /// [playlist] on [server], which creates the playlist server-side when it
  /// doesn't exist yet (so "new playlist" needs no separate create call).
  /// [server] is explicit so a mixed-server context adds to the track's own
  /// server. The endpoint stores the vpath-relative filepath — the same form
  /// playlist/load returns — so the client's leading slash is stripped
  /// ([rateSong] convention). Throws on failure so callers can surface it.
  Future<void> addSongToPlaylist(
      Server server, String playlist, String filepath) async {
    final fp = filepath.startsWith('/') ? filepath.substring(1) : filepath;
    final payload = {'playlist': playlist, 'song': fp};
    if (server.browseOffline) {
      if (!OutboxManager().enqueue(server, OutboxOp.playlistAdd, payload)) {
        throw Exception('Add to playlist failed (offline, no index)');
      }
      return;
    }
    final response = await http
        .post(
          server.apiUri('/api/v1/playlist/add-song'),
          body: jsonEncode({'playlist': playlist, 'song': fp}),
          headers: {
            'Content-Type': 'application/json',
            'x-access-token': server.authToken ?? '',
          },
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode > 299) {
      throw Exception('Add to playlist failed (HTTP ${response.statusCode})');
    }
    OutboxManager().applyLocally(server, OutboxOp.playlistAdd, payload);
  }

  /// POST /api/v1/playlist/save — create-or-OVERWRITE [playlist] on
  /// [server] with exactly [filepaths] (vpath form; leading slashes
  /// stripped): the bulk, atomic counterpart of [addSongToPlaylist], used
  /// by "Save as playlist" flows. Throws on failure.
  Future<void> savePlaylist(
      Server server, String playlist, List<String> filepaths) async {
    final songs = [
      for (final f in filepaths) f.startsWith('/') ? f.substring(1) : f,
    ];
    final payload = {'title': playlist, 'songs': songs};
    if (server.browseOffline) {
      if (!OutboxManager().enqueue(server, OutboxOp.playlistSave, payload)) {
        throw Exception('Playlist save failed (offline, no index)');
      }
      return;
    }
    final response = await http
        .post(
          server.apiUri('/api/v1/playlist/save'),
          body: jsonEncode({'title': playlist, 'songs': songs}),
          headers: {
            'Content-Type': 'application/json',
            'x-access-token': server.authToken ?? '',
          },
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode > 299) {
      throw Exception('Playlist save failed (HTTP ${response.statusCode})');
    }
    OutboxManager().applyLocally(server, OutboxOp.playlistSave, payload);
  }

  /// Renames a playlist (POST /playlist/rename). Throws on failure.
  Future<void> renamePlaylist(String oldName, String newName) async {
    final server = _browseServer(null);
    final payload = {'oldName': oldName, 'newName': newName};
    if (server.browseOffline) {
      if (!OutboxManager().enqueue(server, OutboxOp.playlistRename, payload)) {
        throw Exception('Playlist rename failed (offline, no index)');
      }
    } else {
      await makeServerCall(server, '/api/v1/playlist/rename', payload, 'POST',
          cancelable: false);
      OutboxManager().applyLocally(server, OutboxOp.playlistRename, payload);
    }
    await refreshPlaylists();
  }

  Future<void> removePlaylist(String playlistId,
      {Server? useThisServer}) async {
    final server = _browseServer(useThisServer);
    final payload = {'playlistname': playlistId};
    if (server.browseOffline) {
      if (!OutboxManager().enqueue(server, OutboxOp.playlistDelete, payload)) {
        appLog('[api] removePlaylist failed: offline, no index');
        return;
      }
    } else {
      try {
        await makeServerCall(server, '/api/v1/playlist/delete', payload, 'POST',
            cancelable: false);
      } catch (err) {
        // TODO: Handle Errors
        appLog('[api] removePlaylist failed: $err');
        return;
      }
      OutboxManager().applyLocally(server, OutboxOp.playlistDelete, payload);
    }

    BrowserManager().removeAll(playlistId, server, 'playlist');
  }

  Future<void> searchServer(String search) async {
    try {
      final server = _browseServer(null);
      final list = await _sourceFor(server).search(server, search);
      BrowserManager().setBrowserLabel('Search');
      // Stash the query on the frame so the results view shows a "Results for
      // …" subheader (and it reverts on back-nav, like the file-explorer path).
      BrowserManager().addListToStack(list, searchTerm: search);
    } catch (err) {
      appLog('[api] searchServer failed: $err');
    }
  }

  /// The server the browse lists are for: the one asked for, else the
  /// current one. Throws like makeServerCall did when there is none.
  Server _browseServer(Server? useThisServer) =>
      useThisServer ??
      ServerManager().currentServer ??
      (throw Exception('No Server Selected'));

  /// The library index, when this server is being browsed offline and the
  /// index is open — otherwise null and the server answers.
  LocalLibrarySource? _localSource(Server s) {
    final ix = LibraryIndexManager().index;
    return s.browseOffline && ix != null ? LocalLibrarySource(ix) : null;
  }

  LibrarySource _sourceFor(Server s) =>
      _localSource(s) ?? HttpLibrarySource(this);

  Future<void> getAlbums({Server? useThisServer}) async {
    try {
      final server = _browseServer(useThisServer);
      final list = await _sourceFor(server).albums(server);
      BrowserManager().setBrowserLabel('Albums');
      BrowserManager().addListToStack(list, alphabetical: true);
    } catch (err) {
      // TODO: Handle Errors
      appLog('[api] getAlbums failed: $err');
    }
  }

  /// Fetches an album's songs as a list of `file` DisplayItems WITHOUT touching
  /// the browser stack — used by the album detail screen, which renders its own
  /// tracklist. Throws on a server error so the caller can show its own state.
  Future<List<DisplayItem>> fetchAlbumSongs(String? album,
      {Server? useThisServer}) async {
    final server = _browseServer(useThisServer);
    return _sourceFor(server).albumSongs(server, album);
  }

  Future<void> getAlbumSongs(String? album, {Server? useThisServer}) async {
    List<DisplayItem> newList;
    try {
      newList = await fetchAlbumSongs(album, useThisServer: useThisServer);
    } catch (err) {
      // TODO: Handle Errors
      appLog('[api] getAlbumSongs failed: $err');
      return;
    }

    BrowserManager().addListToStack(newList);
  }

  Future<void> getRecentlyAdded({Server? useThisServer}) async {
    try {
      final server = _browseServer(useThisServer);
      final list = await _sourceFor(server).recent(server);
      BrowserManager().setBrowserLabel('Recent');
      BrowserManager().addListToStack(list);
    } catch (err) {
      // TODO: Handle Errors
      appLog('[api] getRecentlyAdded failed: $err');
    }
  }

  Future<void> getRated({Server? useThisServer}) async {
    try {
      final server = _browseServer(useThisServer);
      final list = await _sourceFor(server).rated(server);
      BrowserManager().setBrowserLabel('Rated');
      BrowserManager().addListToStack(list);
    } catch (err) {
      // TODO: Handle Errors
      appLog('[api] getRated failed: $err');
    }
  }

  /// POST /api/v1/db/rate-song — set [rating] (0–10 server scale, or null to
  /// clear) for the track at [filepath] on [server]. Per-user and server-side;
  /// [server] is explicit so a mixed-server queue rates each track on its own
  /// server. The endpoint resolves the track by its vpath-relative filepath, so
  /// strip the client's leading slash (DisplayItem.data / MediaItem 'path' carry
  /// a leading "/").
  Future<void> rateSong(Server server, String filepath, int? rating) async {
    final fp = filepath.startsWith('/') ? filepath.substring(1) : filepath;
    final payload = {'filepath': fp, 'rating': rating};
    // Browsing the library copy: queued, replayed after the next good ping.
    if (server.browseOffline) {
      if (!OutboxManager().enqueue(server, OutboxOp.rate, payload)) {
        throw Exception('Rating failed (offline, no index)');
      }
      return;
    }
    // Timeout matters here: the star-rating UI updates optimistically and its
    // catch is the ONLY revert path — an unbounded hang against a black-holed
    // server left a rating showing that the server never received.
    final response = await _direct
        .post(
          server.apiUri('/api/v1/db/rate-song'),
          body: jsonEncode({'filepath': fp, 'rating': rating}),
          headers: {
            'Content-Type': 'application/json',
            'x-access-token': server.authToken ?? '',
          },
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode > 299) {
      throw Exception('Rating failed (HTTP ${response.statusCode})');
    }
    OutboxManager().applyLocally(server, OutboxOp.rate, payload);
  }

  /// POST /api/v1/db/metadata/batch — the full metadata block for many tracks
  /// in ONE request, keyed by the filepath as sent (leading slash stripped).
  /// Paths the server couldn't resolve are simply absent from the map.
  ///
  /// The same renderer as the single-track route, on every version that has
  /// this endpoint — 6.11+ resolves the whole list in one query, and 5.16
  /// through 6.10 looped pullMetaData per path. So a batched fetch is never a
  /// LITE fetch: the reduced 13-field shape belongs to search and discovery
  /// (server-side toLiteMetadata), which is what the callers of this are
  /// repairing in the first place.
  ///
  /// Best-effort like [fetchTrackMetadata] — an empty map on ANY failure,
  /// which the caller reads as "fall back to per-track". That covers a 404
  /// from a server below the floor, a timeout, and a body in a shape we don't
  /// recognise, so none of those needs a branch of its own.
  Future<Map<String, MusicMetadata>> fetchTrackMetadataBatch(
      Server server, List<String> filepaths) async {
    final fps = filepaths
        .map((p) => p.startsWith('/') ? p.substring(1) : p)
        .toSet()
        .toList();
    if (fps.isEmpty) return const {};
    try {
      final response = await http
          .post(
            server.apiUri('/api/v1/db/metadata/batch'),
            // A bare JSON ARRAY, not an object: the route iterates req.body
            // itself rather than reading a field off it.
            body: jsonEncode(fps),
            headers: {
              'Content-Type': 'application/json',
              'x-access-token': server.authToken ?? '',
            },
          )
          // Longer than the single-track 15s because it stands in for N of
          // them, but still bounded — the whole point of batching is that one
          // stalled connection must not cost N timeouts, and an unbounded
          // wait here would trade N bounded stalls for one unbounded one.
          .timeout(const Duration(seconds: 20));
      if (response.statusCode > 299) return const {};
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return const {};
      final out = <String, MusicMetadata>{};
      decoded.forEach((key, value) {
        // Each value is the {filepath, metadata} wrapper the single-track
        // route returns, with metadata null for a path this user cannot see.
        final md = value is Map ? value['metadata'] : null;
        if (md is Map) out[key.toString()] = MusicMetadata.fromServerMap(md);
      });
      return out;
    } catch (_) {
      return const {};
    }
  }

  /// POST /api/v1/db/metadata — the full metadata block for a single track by its
  /// (library-prefixed) [filepath]. Used to enrich queue items built from the
  /// lightweight search endpoint, which returns only name/filepath/art. Returns
  /// null on a miss (the server 200s with `metadata: null`), any error, or an
  /// older server without the route — so callers degrade to what they already
  /// have. Best-effort: never throws. Direct http (like [rateSong]) so it stays
  /// off the browser loading bar. A leading slash on [filepath] is tolerated.
  Future<MusicMetadata?> fetchTrackMetadata(
      Server server, String filepath) async {
    final fp = filepath.startsWith('/') ? filepath.substring(1) : filepath;
    try {
      // 15s, matching the other direct-http calls in this file. Untimed,
      // this had no deadline at all on a path that runs ONE POST PER TRACK,
      // serially, from a car tap (queue_actions -> buildServerFileMediaItem
      // for every row without a metadata block). A stalled connection there
      // hangs Android Auto for as long as the socket takes to give up, which
      // defeats the bounded wait AutoApi._call exists to provide. Returns
      // null on timeout like every other failure here — the caller falls back
      // to the row's own lite metadata.
      final response = await _direct
          .post(
            server.apiUri('/api/v1/db/metadata'),
            body: jsonEncode({'filepath': fp}),
            headers: {
              'Content-Type': 'application/json',
              'x-access-token': server.authToken ?? '',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode > 299) return null;
      final decoded = jsonDecode(response.body);
      final md = decoded is Map ? decoded['metadata'] : null;
      return md is Map ? MusicMetadata.fromServerMap(md) : null;
    } catch (_) {
      return null;
    }
  }

  /// Shared plumbing for the discovery (sonic-similarity) endpoints: POST
  /// [body] to [location] on [server] and classify the outcome per
  /// [DiscoveryFetchResult]. Direct http (like [fetchTrackMetadata]) so these
  /// stay off the browser loading bar; never throws. A 403 means the feature
  /// is switched off server-side — reported distinctly so the section hides
  /// itself for the session. Anything else that fails (including the server's
  /// uniform 404 for an unknown / not-yet-embedded seed) is a plain error and
  /// the caller just skips that refresh.
  Future<DiscoveryFetchResult<T>> _postDiscovery<T>(
      Server server,
      String location,
      Map<String, dynamic> body,
      T Function(Map) parse) async {
    try {
      final response = await _direct
          .post(
            server.apiUri(location),
            body: jsonEncode(body),
            headers: {
              'Content-Type': 'application/json',
              'x-access-token': server.authToken ?? '',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 403) {
        return DiscoveryFetchResult<T>.disabled();
      }
      if (response.statusCode > 299) return DiscoveryFetchResult<T>.error();
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return DiscoveryFetchResult<T>.error();
      return DiscoveryFetchResult.ok(parse(decoded));
    } catch (err) {
      verboseLog('[api] discovery $location failed: $err');
      return DiscoveryFetchResult<T>.error();
    }
  }

  /// POST /api/v1/discovery/local/similar/tracks — library tracks sonically
  /// similar to the seed at [filepath]. The endpoint wants the vpath-form path
  /// WITHOUT the client's leading slash (same convention as [rateSong]).
  /// Results carry standard library filepaths, so they queue/play like any
  /// browse row. Only call when the server advertised `discovery` on ping.
  Future<DiscoveryFetchResult<DiscoverySimilarTracks>>
      fetchDiscoverySimilarTracks(Server server, String filepath,
          {int limit = 10,
          bool excludeSameArtist = false,
          bool excludeSameAlbum = false}) {
    final fp = filepath.startsWith('/') ? filepath.substring(1) : filepath;
    return _postDiscovery(
      server,
      '/api/v1/discovery/local/similar/tracks',
      {
        'filePath': fp,
        'limit': limit,
        if (excludeSameArtist) 'excludeSameArtist': true,
        if (excludeSameAlbum) 'excludeSameAlbum': true,
      },
      (m) => DiscoverySimilarTracks.fromServerMap(m),
    );
  }

  /// POST /api/v1/discovery/local/similar/artists — artists whose overall
  /// sound (centroid of their analyzed tracks) is closest to [artist]'s, each
  /// with up to two playable entry-point tracks.
  Future<DiscoveryFetchResult<DiscoverySimilarArtists>>
      fetchDiscoverySimilarArtists(Server server, String artist,
          {int limit = 5}) {
    return _postDiscovery(
      server,
      '/api/v1/discovery/local/similar/artists',
      {'artist': artist, 'limit': limit},
      (m) => DiscoverySimilarArtists.fromServerMap(m),
    );
  }

  /// POST /api/v1/discovery/p2p/similar — "From the network": similar tracks
  /// from fetched snapshots of public P2P peers. Metadata-only leads (nothing
  /// playable). Gated on the ping's `discoveryP2p` flag.
  Future<DiscoveryFetchResult<DiscoveryLeads>> fetchDiscoveryP2pSimilar(
      Server server, String filepath,
      {int limit = 10, bool newArtistsOnly = false}) {
    final fp = filepath.startsWith('/') ? filepath.substring(1) : filepath;
    return _postDiscovery(
      server,
      '/api/v1/discovery/p2p/similar',
      {'filePath': fp, 'limit': limit, 'newArtistsOnly': newArtistsOnly},
      (m) => DiscoveryLeads.fromServerMap(m),
    );
  }

  /// POST /api/v1/discovery/local/path — an ordered, playable "journey" from
  /// [startPath] to [endPath]: waypoints along the arc between the two
  /// tracks' embeddings, snapped to real library tracks. Seeds are included
  /// in the results, and [length] counts the TOTAL rows (server clamps
  /// 4..32). Only call when the server advertised `discoveryPath` on ping —
  /// the flag means "this server version has the route" (mStream #762).
  Future<DiscoveryFetchResult<DiscoveryPath>> fetchDiscoveryPath(
      Server server, String startPath, String endPath,
      {int length = 14}) {
    String norm(String p) => p.startsWith('/') ? p.substring(1) : p;
    return _postDiscovery(
      server,
      '/api/v1/discovery/local/path',
      {
        'startFilePath': norm(startPath),
        'endFilePath': norm(endPath),
        'length': length,
      },
      (m) => DiscoveryPath.fromServerMap(m),
    );
  }

  /// POST /api/v1/db/search, titles only — data-returning song search for
  /// pickers (the Auto DJ sonic-seed sheet). Returns up to [limit] playable
  /// file rows with lite metadata attached; empty list on any error
  /// (best-effort, direct http like [fetchTrackMetadata], off the browser
  /// loading bar).
  Future<List<DisplayItem>> fetchSongSearch(Server server, String search,
      {int limit = 25}) async {
    try {
      final response = await _direct
          .post(
            server.apiUri('/api/v1/db/search'),
            // Pre-filtered for the same reason as [searchServer]: an
            // older server rejects `noLyrics` outright, and this method
            // swallows errors, so a blind send would turn every query in the
            // picker into "no results". Only reachable from sonic-path
            // surfaces today (6.18.1+, well past noLyrics), but the picker
            // shouldn't carry a version assumption its callers happen to
            // satisfy.
            body: jsonEncode(ServerCapabilities().filter(server, {
              'search': search,
              'noArtists': true,
              'noAlbums': true,
              'noTitles': false,
              'noFiles': true,
              'noLyrics': true,
            }).body),
            headers: {
              'Content-Type': 'application/json',
              'x-access-token': server.authToken ?? '',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode > 299) return const [];
      final decoded = jsonDecode(response.body);
      final hits = decoded is Map ? decoded['title'] : null;
      if (hits is! List) return const [];
      final out = <DisplayItem>[];
      for (final e in hits) {
        if (e is! Map) continue;
        final fp = e['filepath'];
        if (fp is! String || fp.isEmpty) continue;
        final md = e['metadata'];
        final item = DisplayItem(
            server,
            (e['name'] ?? fp.split('/').last).toString(),
            'file',
            '/$fp',
            Icon(Icons.music_note, color: VelvetColors.accent),
            null);
        item.altAlbumArt =
            e['album_art_file'] is String ? e['album_art_file'] : null;
        item.metadata = md is Map ? MusicMetadata.fromServerMap(md) : null;
        item.partialMetadata = true;
        out.add(item);
        if (out.length >= limit) break;
      }
      return out;
    } catch (err) {
      verboseLog('[api] song search failed: $err');
      return const [];
    }
  }

  /// The discovery embeddings for [filePaths] on [server], so a seed can be
  /// carried to a server that has never seen those files.
  ///
  /// Returns the model identity alongside the vectors: embeddings only
  /// compare within one model space, so a caller must know which space it is
  /// holding before offering the seed to anyone else. Null when the server
  /// can't answer at all (too old, discovery off, unreachable) — the caller
  /// treats that as "this server sits this session out", not an error.
  ///
  /// Vectors come back base64 float32 little-endian, the same wire form the
  /// server's federation routes use.
  ///
  /// Works for a federated peer too: the route is on the federation
  /// allowlist (mStream #946), and [Server.apiUri] / [Server.authToken] put
  /// the request on the parent's proxy or the peer's own tunnel.
  Future<({String modelId, int dim, List<Float32List> vectors})?>
      fetchEmbeddings(Server server, List<String> filePaths) async {
    if (filePaths.isEmpty) return null;
    try {
      final res = await _direct
          .post(
            server.apiUri('/api/v1/discovery/local/embeddings'),
            headers: {
              'Content-Type': 'application/json',
              'x-access-token': server.authToken ?? '',
            },
            // The route caps at 8 to match the sonic seed cap; trim here
            // rather than let the whole request 400 on a longer anchor.
            body: jsonEncode({'filePaths': filePaths.take(8).toList()}),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode > 299) {
        verboseLog('[dj] embeddings HTTP ${res.statusCode} on ${server.localname}');
        return null;
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      final modelId = (decoded['model'] is Map)
          ? decoded['model']['id']?.toString()
          : null;
      final dim = decoded['dim'];
      if (modelId == null || dim is! int || dim <= 0) return null;

      final vectors = <Float32List>[];
      for (final t in (decoded['tracks'] as List? ?? const [])) {
        if (t is! Map) continue;
        final b64 = t['embedding'];
        // notAnalyzed tracks come back with a null embedding — a normal
        // transient state while the worker catches up, not a failure.
        if (b64 is! String || b64.isEmpty) continue;
        // Null for a payload that isn't exactly dim floats — a server
        // answering with a different dim than it advertised is skipped.
        final vec = decodeWireVector(b64, dim);
        if (vec == null) continue;
        vectors.add(vec);
      }
      if (vectors.isEmpty) return null;
      return (modelId: modelId, dim: dim, vectors: vectors);
    } catch (e) {
      verboseLog('[dj] embeddings failed on ${server.localname}: $e');
      return null;
    }
  }

  /// GET /api/v1/federation/health — the model a server answers sonic
  /// queries in (`discovery.modelId`), read before a cross-server Auto DJ
  /// session sends it a vector: the server refuses a foreign one with a hard
  /// 400 (mStream #929), so a caller is expected to ask first. Served to a
  /// logged-in user on the server's own wall, to a peer through the parent's
  /// proxy and to a guest over a direct tunnel alike (it is on the federation
  /// allowlist). `modelId` is null when discovery is off there or nothing is
  /// analysed yet; the whole answer is null when the server did not answer.
  Future<({String? modelId, int analyzedCount})?> fetchFederationHealth(
      Server server) async {
    try {
      final res = await _direct
          .get(
            server.apiUri('/api/v1/federation/health'),
            headers: {'x-access-token': server.authToken ?? ''},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode > 299) {
        verboseLog('[dj] health HTTP ${res.statusCode} on ${server.localname}');
        return null;
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      final d = decoded['discovery'];
      if (d is! Map) return (modelId: null, analyzedCount: 0);
      final id = d['modelId'];
      final n = d['analyzedCount'];
      return (
        modelId: id is String && id.isNotEmpty ? id : null,
        analyzedCount: n is num ? n.toInt() : 0,
      );
    } catch (e) {
      verboseLog('[dj] health failed on ${server.localname}: $e');
      return null;
    }
  }

  /// Pick Auto DJ's opening track for a "Surprise me" start.
  ///
  /// Unlike [fetchRandomSong] this honours the Auto DJ library filters. The
  /// opener is part of the session, and handing back a track the user has
  /// explicitly filtered out is the one thing this must not do — which is
  /// exactly what it did before, since the plain random fetch sends only
  /// vpaths and rating.
  ///
  /// `noMatch` distinguishes "your filters leave nothing" from a network or
  /// auth failure. The server refuses an empty pool with a 400 rather than
  /// relaxing the window, so that is a real answer the user can act on, not
  /// an error to swallow.
  Future<({DisplayItem? item, bool noMatch})> fetchAutoDjSeed(
      Server server) async {
    final wanted = AutoDJManager().libraryFilters(server);
    // The same drop-what-this-server-cannot-take pass the DJ makes: one
    // unrecognised key 400s the whole request on a Joi-validated server, so
    // an older server would fail here for the wrong reason entirely.
    final filtered = ServerCapabilities().filter(server, wanted);
    final constrained = filtered.body.isNotEmpty;
    try {
      final response = await http
          .post(
            server.apiUri('/api/v1/db/random-songs'),
            body: jsonEncode(filtered.body),
            headers: {
              'Content-Type': 'application/json',
              'x-access-token': server.authToken ?? '',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode > 299) {
        verboseLog('[api] auto-dj seed HTTP ${response.statusCode}');
        // Only a 400 means "nothing matched" — anything else (401, 5xx) is a
        // failure the user can't fix by loosening a filter.
        return (item: null, noMatch: response.statusCode == 400 && constrained);
      }
      final decoded = jsonDecode(response.body);
      final songs = decoded is Map ? decoded['songs'] : null;
      if (songs is! List || songs.isEmpty) {
        return (item: null, noMatch: constrained);
      }
      final song = songs.first;
      if (song is! Map) return (item: null, noMatch: false);
      final fp = song['filepath'];
      if (fp is! String || fp.isEmpty) return (item: null, noMatch: false);
      final md = song['metadata'];
      final item = DisplayItem(server, fp.split('/').last, 'file', '/$fp',
          Icon(Icons.music_note, color: VelvetColors.accent), null);
      item.metadata = md is Map ? MusicMetadata.fromServerMap(md) : null;
      return (item: item, noMatch: false);
    } catch (err) {
      verboseLog('[api] auto-dj seed failed: $err');
      return (item: null, noMatch: false);
    }
  }

  /// An unconstrained random track. Used by Discover and the song picker,
  /// which are not Auto DJ sessions and must not inherit its filters — see
  /// [fetchAutoDjSeed] for the one caller that should.
  Future<DisplayItem?> fetchRandomSong(Server server) async {
    final ignoreVPaths = <String>[
      for (final e in server.autoDJPaths.entries)
        if (e.value == false) e.key,
    ];
    try {
      final response = await _direct
          .post(
            server.apiUri('/api/v1/db/random-songs'),
            body: jsonEncode({
              if (ignoreVPaths.isNotEmpty) 'ignoreVPaths': ignoreVPaths,
              if (server.autoDJminRating != null)
                'minRating': server.autoDJminRating,
            }),
            headers: {
              'Content-Type': 'application/json',
              'x-access-token': server.authToken ?? '',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode > 299) return null;
      final decoded = jsonDecode(response.body);
      final songs = decoded is Map ? decoded['songs'] : null;
      if (songs is! List || songs.isEmpty) return null;
      final song = songs.first;
      if (song is! Map) return null;
      final fp = song['filepath'];
      if (fp is! String || fp.isEmpty) return null;
      final md = song['metadata'];
      final item = DisplayItem(server, fp.split('/').last, 'file', '/$fp',
          Icon(Icons.music_note, color: VelvetColors.accent), null);
      item.metadata = md is Map ? MusicMetadata.fromServerMap(md) : null;
      return item;
    } catch (err) {
      verboseLog('[api] random-song seed failed: $err');
      return null;
    }
  }

  /// POST /api/v1/discovery/federation/similar — "From your peers": live
  /// similarity queries against paired federation peers. Leads only at this
  /// server version (peer-stream playback landed later upstream). Gated on
  /// the ping's `federationDiscovery` flag. Server caps limit at 50.
  Future<DiscoveryFetchResult<DiscoveryLeads>> fetchDiscoveryFederationSimilar(
      Server server, String filepath,
      {int limit = 10, bool newArtistsOnly = false}) {
    final fp = filepath.startsWith('/') ? filepath.substring(1) : filepath;
    return _postDiscovery(
      server,
      '/api/v1/discovery/federation/similar',
      {'filePath': fp, 'limit': limit, 'newArtistsOnly': newArtistsOnly},
      (m) => DiscoveryLeads.fromServerMap(m),
    );
  }

  Future<void> getArtists({Server? useThisServer}) async {
    try {
      final server = _browseServer(useThisServer);
      final list = await _sourceFor(server).artists(server);
      BrowserManager().setBrowserLabel('Artists');
      BrowserManager().addListToStack(list, alphabetical: true);
    } catch (err) {
      // TODO: Handle Errors
      appLog('[api] getArtists failed: $err');
    }
  }

  Future<void> getArtistAlbums(String artist, {Server? useThisServer}) async {
    try {
      final server = _browseServer(useThisServer);
      final list = await _sourceFor(server).artistAlbums(server, artist);
      BrowserManager().addListToStack(list);
    } catch (err) {
      // TODO: Handle Errors
      appLog('[api] getArtistAlbums failed: $err');
    }
  }

  Future<void> getPlaylistContents(String playlistName,
      {Server? useThisServer}) async {
    try {
      final server = _browseServer(useThisServer);
      final list =
          await _sourceFor(server).playlistContents(server, playlistName);
      // Name the frame so the subheader can label it, the toolbar can offer
      // the album-style controls, and an empty result reads as "playlist is
      // empty" rather than a blank list.
      BrowserManager().addListToStack(list, playlist: playlistName);
    } catch (err) {
      // TODO: Handle Errors
      appLog('[api] getPlaylistContents failed: $err');
    }
  }

  Future<void> getFileList(String directory, {Server? useThisServer}) async {
    try {
      final server = _browseServer(useThisServer);
      final listing = await _sourceFor(server).fileList(server, directory);
      BrowserManager().setBrowserLabel('File Explorer');
      BrowserManager()
          .addListToStack(listing.items, alphabetical: true, path: listing.path);
    } catch (err) {
      // TODO: Handle Errors
      appLog('[api] getFileList failed: $err');
    }
  }

  /// POST /api/v1/file-explorer/m3u — read a playlist FILE and push what it
  /// names as a browse list.
  ///
  /// The alternative is what used to happen: an .m3u tapped in the file
  /// explorer went to the queue like any other file, and the player stalled
  /// trying to decode a text file. The server already parses these (since
  /// 4.7.0, below the support floor, so no gate) and resolves each entry
  /// against the playlist's own directory, dropping anything that escapes the
  /// library root.
  ///
  /// Pushed as a NON-alphabetical list: an m3u's order is the point of an
  /// m3u. Sorting it — or offering a letter strip over it — would throw away
  /// the one thing the file is for.
  Future<void> getM3uContents(String filepath,
      {Server? useThisServer}) async {
    dynamic res;
    try {
      res = await makeServerCall(useThisServer, '/api/v1/file-explorer/m3u',
          {'path': filepath}, 'POST');
    } catch (err) {
      appLog('[api] getM3uContents failed: $err');
      return;
    }

    final List<DisplayItem> newList = [];
    for (final e in (res['files'] as List? ?? const [])) {
      final name = e['name']?.toString();
      final p = e['path']?.toString();
      if (name == null || p == null) continue;
      newList.add(DisplayItem(
        useThisServer ?? ServerManager().currentServer,
        name,
        'file',
        p.startsWith('/') ? p : '/$p',
        Icon(Icons.music_note, color: VelvetColors.accent),
        null,
      ));
    }

    // The server counts entries it refused to resolve. Saying nothing would
    // present a short playlist as a complete one.
    final skipped = res['skipped'];
    if (skipped is int && skipped > 0) {
      showGlobalSnack('$skipped track(s) in this playlist are outside '
          'the library and were skipped');
    }

    // Label stays "File Explorer" and the playlist's own path goes in the
    // breadcrumb: popBrowser restores the path stack but there is no label
    // stack, so a per-list title would still be showing after you backed out
    // of it. The breadcrumb names the file, which is the part that changed.
    BrowserManager()
        .addListToStack(newList, alphabetical: false, path: filepath);
  }

  // ── Torrent ─────────────────────────────────────────────────────────
  // Add a magnet / .torrent to the server's torrent client, into a library
  // directory — the webapp's torrent panel, driving /api/v1/torrent/*.
  // All URIs go through Server.apiUri so iroh-tunnel servers work.

  /// Capability + destination probe (GET /torrent/preflight): { active,
  /// clientType, displayName, noUpload, userAllowed, vpath, subPath,
  /// vpathConfirmed, daemonPath, reason }. Throws with the server's
  /// message when the route is missing/denied.
  Future<Map<String, dynamic>> torrentPreflight(String path,
      {Server? server}) async {
    final s = server ?? ServerManager().currentServer;
    if (s == null) throw Exception('No server selected');
    final uri = s.apiUri(
        '/api/v1/torrent/preflight?path=${Uri.encodeQueryComponent(path)}');
    final res = await http
        .get(uri, headers: {'x-access-token': s.authToken ?? ''})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception(_torrentError(res) ?? 'Torrent unavailable');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Per-library destination templates (GET /torrent/path-templates):
  /// `{ vpaths: { <name>: { template } }, supportedVars, suggestedTemplate }`.
  Future<Map<String, dynamic>> torrentPathTemplates({Server? server}) async {
    final s = server ?? ServerManager().currentServer;
    if (s == null) throw Exception('No server selected');
    final res = await http
        .get(s.apiUri('/api/v1/torrent/path-templates'),
            headers: {'x-access-token': s.authToken ?? ''})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception(_torrentError(res) ?? 'Could not load path templates');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Submit a torrent (POST /torrent/add, multipart). Provide exactly one
  /// of [magnet] or [torrentBytes]. Throws the server's message on failure;
  /// returns { ok, name, downloadPath, isDuplicate, renameWarning?, … }.
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
    final req = http.MultipartRequest('POST', s.apiUri('/api/v1/torrent/add'));
    req.headers['x-access-token'] = s.authToken ?? '';
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

  /// Server-side metadata detection for a .torrent (POST /auto-detect,
  /// multipart). Returns the raw body — the caller checks `ok` /
  /// `confidence` / `metadata` / `message`. [vpath] enables the server's
  /// tag-fetch tier.
  Future<Map<String, dynamic>> torrentAutoDetect({
    required List<int> torrentBytes,
    String? torrentFilename,
    String? vpath,
    Server? server,
  }) async {
    final s = server ?? ServerManager().currentServer;
    if (s == null) throw Exception('No server selected');
    final req = http.MultipartRequest(
        'POST', s.apiUri('/api/v1/torrent/auto-detect'));
    req.headers['x-access-token'] = s.authToken ?? '';
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

  /// Check whether the torrent's files already exist on the server
  /// (POST /seed-existing, multipart). Returns the raw body — the caller
  /// switches on `outcome` (seeded / already_in_daemon / partial_match /
  /// no_match / invalid_torrent / daemon_error). Omitting [vpaths] scans
  /// all of the user's libraries.
  Future<Map<String, dynamic>> torrentSeedExisting({
    required List<int> torrentBytes,
    String? torrentFilename,
    List<String>? vpaths,
    Server? server,
  }) async {
    final s = server ?? ServerManager().currentServer;
    if (s == null) throw Exception('No server selected');
    final req = http.MultipartRequest(
        'POST', s.apiUri('/api/v1/torrent/seed-existing'));
    req.headers['x-access-token'] = s.authToken ?? '';
    if (vpaths != null && vpaths.isNotEmpty) {
      req.fields['vpaths'] = jsonEncode(vpaths);
    }
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
      'outcome': 'daemon_error',
      'error': 'Seed check failed (HTTP ${res.statusCode})'
    };
  }

  // Pull the server's { error: "…" } message out of a failed response.
  String? _torrentError(http.Response res) {
    try {
      final m = jsonDecode(res.body);
      if (m is Map && m['error'] != null) return m['error'].toString();
    } catch (_) {}
    return null;
  }
}
