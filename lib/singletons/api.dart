import './server_list.dart';
import './browser_list.dart';
import './log_manager.dart';
import './settings.dart';
import '../objects/server.dart';
import '../objects/discovery.dart';
import '../objects/display_item.dart';
import '../objects/lyrics.dart';
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
      server.apiUri('/api/v1/db/genres'),
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
    final uri = server.apiUri('/api/v1/share');
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

    final response =
        await http.get(uri, headers: {'x-access-token': server.jwt ?? ''});
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
          ? client.get(currentUri, headers: {'x-access-token': server.jwt ?? ''})
          : client.post(currentUri, body: json.encode(payload), headers: {
              'Content-Type': 'application/json',
              'x-access-token': server.jwt ?? ''
            });
      http.Response response;
      final bool isIroh = server.isIroh;
      try {
        // For iroh, bound the request so a wedged tunnel fails fast instead of
        // hanging the global loading bar.
        response =
            isIroh ? await send().timeout(const Duration(seconds: 20)) : await send();
      } catch (e) {
        // An iroh connection error usually means the tunnel is mid-drop; give the
        // self-healing tunnel a moment to recover, then retry once. (Skip on a
        // user cancel — closing the client throws too.)
        if (isIroh && !BrowserManager().isLoadCancelled(loadToken)) {
          // Wait for THIS call's server (the tunnel may be serving a background
          // playback server instead of the browsed one).
          final ready = await ServerManager().awaitTunnelReady(server: server);
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
    dynamic res;
    try {
      res = await makeServerCall(useThisServer,
          '/api/v1/file-explorer/recursive', {"directory": directory}, 'POST');
    } catch (err) {
      // TODO: Handle Errors
      appLog('[api] getRecursiveFiles failed: $err');
      return;
    }

    res.forEach((e) {
      // Same transcode-aware stream URL as the rest of the app (honors the
      // /transcode endpoint + codec/bitrate when transcoding is on).
      final String streamUrl =
          buildServerStreamUrl(useThisServer!, e.toString());
      // The recursive endpoint returns bare paths (no metadata), so these items
      // carry only server + path — no rating / fidelity / tags. They populate
      // if the same track is later reached via a metadata-bearing browse.
      MediaItem lol = MediaItem(
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
      newList.add(DisplayItem(server, e['name'], 'playlist', e['name'],
          Icon(Icons.queue_music, color: VelvetColors.textSecondary), null));
    });
    return newList;
  }

  Future<void> getPlaylists({Server? useThisServer}) async {
    dynamic res;
    try {
      res = await makeServerCall(
          useThisServer, '/api/v1/playlist/getall', {}, 'GET');
    } catch (err) {
      // TODO: Handle Errors
      appLog('[api] getPlaylists failed: $err');
      return;
    }

    BrowserManager().setBrowserLabel('Playlists');
    BrowserManager().addListToStack(_playlistItems(res, useThisServer));
  }

  /// Re-fetches playlists and replaces the current view in place (no new
  /// back-stack frame) — used after a create / rename so the list updates
  /// without pushing a navigation entry.
  Future<void> refreshPlaylists() async {
    dynamic res;
    try {
      res = await makeServerCall(null, '/api/v1/playlist/getall', {}, 'GET');
    } catch (err) {
      appLog('[api] refreshPlaylists failed: $err');
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
    final response = await http
        .post(
          server.apiUri('/api/v1/playlist/add-song'),
          body: jsonEncode({'playlist': playlist, 'song': fp}),
          headers: {
            'Content-Type': 'application/json',
            'x-access-token': server.jwt ?? '',
          },
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode > 299) {
      throw Exception('Add to playlist failed (HTTP ${response.statusCode})');
    }
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
      appLog('[api] removePlaylist failed: $err');
      return;
    }

    BrowserManager().removeAll(playlistId, useThisServer!, 'playlist');
  }

  Future<void> searchServer(String search) async {
    try {
      // The user's ticked search categories map 1:1 onto the endpoint's five
      // `no*` flags — the server only does the work that's asked. The default
      // set (artists+albums+songs) reproduces mStream's classic search.
      final cats = SettingsManager().searchCategories;
      var res = await makeServerCall(null, '/api/v1/db/search', {
        'search': search,
        'noArtists': !cats.contains(SearchCategory.artists),
        'noAlbums': !cats.contains(SearchCategory.albums),
        'noTitles': !cats.contains(SearchCategory.songs),
        'noFiles': !cats.contains(SearchCategory.files),
        'noLyrics': !cats.contains(SearchCategory.lyrics),
      }, 'POST');

      BrowserManager().setBrowserLabel('Search');
      List<DisplayItem> newList = [];
      res['artists'].forEach((e) {
        DisplayItem newItem = DisplayItem(
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
        DisplayItem newItem = DisplayItem(
            ServerManager().currentServer,
            e['name'],
            'album',
            e['name'],
            Icon(Icons.library_music, color: VelvetColors.textSecondary),
            'album');
        newItem.altAlbumArt = e['album_art_file'];
        newList.add(newItem);
      });

      // Track hits carry the LITE metadata subset (PR #685, same kebab-case keys
      // as the full block, so fromServerMap parses it directly). Attach it so the
      // row renders a real card (title / artist) and flag it partial so the queue
      // refetches the full block (fidelity / counts) on enqueue. Older servers
      // omit the key → metadata stays null (still partial → still fetched). With
      // metadata the artist is the subtitle, so the 'song' type hint only matters
      // on the metadata-less path.
      res['title'].forEach((e) {
        final md = e['metadata'];
        final meta = md is Map ? MusicMetadata.fromServerMap(md) : null;
        DisplayItem newItem = DisplayItem(
            ServerManager().currentServer,
            e['name'],
            'file',
            '/${e['filepath']}',
            Icon(Icons.music_note, color: VelvetColors.accent),
            meta != null ? null : 'song');
        newItem.altAlbumArt = e['album_art_file'];
        newItem.metadata = meta;
        newItem.partialMetadata = true;
        newList.add(newItem);
      });

      // Files (filepath matches) — only populated when the scope is `files`.
      // Carries the lite metadata block too (PR #685); `?.` because older servers
      // may omit the `files` key entirely. We keep the folder as the subtitle (the
      // match context — getSubText shows an explicit subtext over the metadata
      // artist); getText shows the title once metadata is attached, the filename
      // otherwise. Flagged partial so the queue refetches the full block.
      res['files']?.forEach((e) {
        final String fp = e['filepath'];
        final int slash = fp.lastIndexOf('/');
        final md = e['metadata'];
        DisplayItem newItem = DisplayItem(
            ServerManager().currentServer,
            e['name'],
            'file',
            '/$fp',
            Icon(Icons.insert_drive_file, color: VelvetColors.accent),
            slash > 0 ? fp.substring(0, slash) : null);
        newItem.altAlbumArt = e['album_art_file'];
        if (md is Map) newItem.metadata = MusicMetadata.fromServerMap(md);
        newItem.partialMetadata = true;
        newList.add(newItem);
      });

      // Lyric matches (only when the `lyrics` category is ticked; `?.` since
      // older servers omit the key). Carries the lite metadata block (PR #685)
      // plus a `snippet` excerpt. We keep the snippet as the subtitle so the user
      // sees WHY it matched (getSubText prefers an explicit subtext over the
      // metadata artist); getText shows the real title once metadata is attached.
      // `snippet` is null on the LIKE / non-FTS path → plain label. Flagged
      // partial so the queue refetches the full block.
      res['lyrics']?.forEach((e) {
        final snippet = (e['snippet'] as String?)?.trim();
        final md = e['metadata'];
        DisplayItem newItem = DisplayItem(
            ServerManager().currentServer,
            e['name'],
            'file',
            '/${e['filepath']}',
            Icon(Icons.lyrics, color: VelvetColors.accent),
            snippet != null && snippet.isNotEmpty ? snippet : 'lyrics');
        newItem.altAlbumArt = e['album_art_file'];
        if (md is Map) newItem.metadata = MusicMetadata.fromServerMap(md);
        newItem.partialMetadata = true;
        newList.add(newItem);
      });

      // Stash the query on the frame so the results view shows a "Results for
      // …" subheader (and it reverts on back-nav, like the file-explorer path).
      BrowserManager().addListToStack(newList, searchTerm: search);
    } catch (err) {
      appLog('[api] searchServer failed: $err');
    }
  }

  Future<void> getAlbums({Server? useThisServer}) async {
    dynamic res;
    try {
      res = await makeServerCall(useThisServer, '/api/v1/db/albums', {}, 'GET');
    } catch (err) {
      // TODO: Handle Errors
      appLog('[api] getAlbums failed: $err');
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
      DisplayItem newItem = DisplayItem(
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

      DisplayItem newItem = DisplayItem(
          useThisServer,
          e['filepath'],
          'file',
          '/${e['filepath']}',
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
      appLog('[api] getAlbumSongs failed: $err');
      return;
    }

    BrowserManager().addListToStack(newList);
  }

  Future<void> getRecentlyAdded({Server? useThisServer}) async {
    dynamic res;
    try {
      res = await makeServerCall(
          useThisServer, '/api/v1/db/recent/added', {'limit': 100}, 'POST');
    } catch (err) {
      // TODO: Handle Errors
      appLog('[api] getRecentlyAdded failed: $err');
      return;
    }

    BrowserManager().setBrowserLabel('Recent');

    List<DisplayItem> newList = [];
    res.forEach((e) {
      MusicMetadata m = MusicMetadata.fromServerMap(e['metadata']);

      DisplayItem newItem = DisplayItem(
          useThisServer,
          e['filepath'],
          'file',
          '/${e['filepath']}',
          Icon(Icons.music_note, color: VelvetColors.accent),
          null);

      newItem.metadata = m;

      newList.add(newItem);
    });
    BrowserManager().addListToStack(newList);
  }

  Future<void> getRated({Server? useThisServer}) async {
    dynamic res;
    try {
      res = await makeServerCall(useThisServer, '/api/v1/db/rated', {}, 'GET');
    } catch (err) {
      // TODO: Handle Errors
      appLog('[api] getRated failed: $err');
      return;
    }

    BrowserManager().setBrowserLabel('Rated');

    List<DisplayItem> newList = [];
    res.forEach((e) {
      MusicMetadata m = MusicMetadata.fromServerMap(e['metadata']);

      DisplayItem newItem = DisplayItem(
          useThisServer,
          e['filepath'],
          'file',
          '/${e['filepath']}',
          Icon(Icons.music_note, color: VelvetColors.accent),
          m.artist);

      newItem.metadata = m;

      newList.add(newItem);
    });
    BrowserManager().addListToStack(newList);
  }

  /// POST /api/v1/db/rate-song — set [rating] (0–10 server scale, or null to
  /// clear) for the track at [filepath] on [server]. Per-user and server-side;
  /// [server] is explicit so a mixed-server queue rates each track on its own
  /// server. The endpoint resolves the track by its vpath-relative filepath, so
  /// strip the client's leading slash (DisplayItem.data / MediaItem 'path' carry
  /// a leading "/").
  Future<void> rateSong(Server server, String filepath, int? rating) async {
    final fp = filepath.startsWith('/') ? filepath.substring(1) : filepath;
    final response = await http.post(
      server.apiUri('/api/v1/db/rate-song'),
      body: jsonEncode({'filepath': fp, 'rating': rating}),
      headers: {
        'Content-Type': 'application/json',
        'x-access-token': server.jwt ?? '',
      },
    );
    if (response.statusCode > 299) {
      throw Exception('Rating failed (HTTP ${response.statusCode})');
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
      final response = await http.post(
        server.apiUri('/api/v1/db/metadata'),
        body: jsonEncode({'filepath': fp}),
        headers: {
          'Content-Type': 'application/json',
          'x-access-token': server.jwt ?? '',
        },
      );
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
      final response = await http
          .post(
            server.apiUri(location),
            body: jsonEncode(body),
            headers: {
              'Content-Type': 'application/json',
              'x-access-token': server.jwt ?? '',
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
      final response = await http
          .post(
            server.apiUri('/api/v1/db/search'),
            body: jsonEncode({
              'search': search,
              'noArtists': true,
              'noAlbums': true,
              'noTitles': false,
              'noFiles': true,
              'noLyrics': true,
            }),
            headers: {
              'Content-Type': 'application/json',
              'x-access-token': server.jwt ?? '',
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

  /// POST /api/v1/db/random-songs — one random pick, for "surprise me"
  /// seeds. Honors the server's Auto DJ source settings (disabled vpaths +
  /// min rating) so a random seed can't come from an excluded library.
  /// Null on any error.
  Future<DisplayItem?> fetchRandomSong(Server server) async {
    final ignoreVPaths = <String>[
      for (final e in server.autoDJPaths.entries)
        if (e.value == false) e.key,
    ];
    try {
      final response = await http
          .post(
            server.apiUri('/api/v1/db/random-songs'),
            body: jsonEncode({
              if (ignoreVPaths.isNotEmpty) 'ignoreVPaths': ignoreVPaths,
              if (server.autoDJminRating != null)
                'minRating': server.autoDJminRating,
            }),
            headers: {
              'Content-Type': 'application/json',
              'x-access-token': server.jwt ?? '',
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
    dynamic res;
    try {
      res =
          await makeServerCall(useThisServer, '/api/v1/db/artists', {}, 'GET');
    } catch (err) {
      // TODO: Handle Errors
      appLog('[api] getArtists failed: $err');
      return;
    }

    BrowserManager().setBrowserLabel('Artists');

    List<DisplayItem> newList = [];
    res['artists'].forEach((e) {
      DisplayItem newItem = DisplayItem(useThisServer, e, 'artist', e,
          Icon(Icons.library_music, color: VelvetColors.textSecondary), null);
      newList.add(newItem);
    });
    BrowserManager().addListToStack(newList, alphabetical: true);
  }

  Future<void> getArtistAlbums(String artist, {Server? useThisServer}) async {
    dynamic res;
    try {
      res = await makeServerCall(useThisServer, '/api/v1/db/artists-albums',
          {'artist': artist}, 'POST');
    } catch (err) {
      // TODO: Handle Errors
      appLog('[api] getArtistAlbums failed: $err');
      return;
    }

    List<DisplayItem> newList = [];
    res['albums'].forEach((e) {
      String name = e['name'] ?? 'SINGLES';

      // TODO: Errors on singles
      DisplayItem newItem = DisplayItem(
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
    dynamic res;
    try {
      res = await makeServerCall(useThisServer, '/api/v1/playlist/load',
          {'playlistname': playlistName}, 'POST');
    } catch (err) {
      // TODO: Handle Errors
      appLog('[api] getPlaylistContents failed: $err');
      return;
    }

    List<DisplayItem> newList = [];
    res.forEach((e) {
      MusicMetadata m = MusicMetadata.fromServerMap(e['metadata']);

      DisplayItem newItem = DisplayItem(
          useThisServer,
          e['filepath'],
          'file',
          '/${e['filepath']}',
          Icon(Icons.music_note, color: VelvetColors.accent),
          null);

      newItem.metadata = m;
      newList.add(newItem);
    });

    BrowserManager().addListToStack(newList);
  }

  Future<void> getFileList(String directory, {Server? useThisServer}) async {
    dynamic res;
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
      appLog('[api] getFileList failed: $err');
      return;
    }

    BrowserManager().setBrowserLabel('File Explorer');

    List<DisplayItem> newList = [];
    res['directories'].forEach((e) {
      DisplayItem newItem = DisplayItem(
          useThisServer,
          e['name'],
          'directory',
          path.join(res['path'], e['name']),
          Icon(Icons.folder, color: VelvetColors.warning),
          null);
      newList.add(newItem);
    });

    res['files'].forEach((e) {
      DisplayItem newItem = DisplayItem(
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
