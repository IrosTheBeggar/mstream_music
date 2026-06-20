// auto_browse.dart — Android Auto browsable media tree.
//
// audio_service's native AudioService IS a MediaBrowserService; Android Auto
// binds it and calls getChildren / getMediaItem / playFromMediaId on the Dart
// AudioPlayerHandler (see audio_stuff.dart, which delegates here). This module
// turns the mStream server's library into the browsable tree Auto shows and
// resolves a tapped item back into a playable queue.
//
// Two hard constraints shape this code:
//   1. HEADLESS. Auto can bind the service with no Activity and before the user
//      has opened the app this process (verified: the service boots main() and
//      every singleton initialises, including ServerManager + HttpOverrides).
//      So we reuse the persisted server/session — but must never assume the UI
//      ran, never throw to Auto, and never trigger a permission prompt.
//   2. NO BrowserManager. ApiManager.makeServerCall brackets every fetch with
//      BrowserManager loading-bar / Back-to-cancel UI state, so it's unusable
//      from the background. AutoApi below is a thin, UI-free HTTP layer that
//      mirrors the same endpoints + parsing and returns plain DisplayItems
//      (so playback can reuse queue_actions.playFromHere unchanged).

import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:http/http.dart' as http;

import 'auto_buckets.dart';
import '../objects/display_item.dart';
import '../objects/metadata.dart';
import '../objects/server.dart';
import '../singletons/log_manager.dart';
import '../singletons/server_list.dart';
import '../util/queue_actions.dart';
import '../util/stream_url.dart';
import '../build_variant.dart';

/// Android Auto trims long browsable lists, and a whole-library response is a
/// big background payload. Cap each node and log the drop (A–Z bucketing of
/// large album/artist lists is a later enhancement). Nothing is silently lost
/// without a log line.
const int _maxChildren = 200;

/// Network budget for a single headless browse fetch — short enough that an
/// unreachable server fails fast (Auto shows a notice) rather than hanging the
/// car UI.
const Duration _fetchTimeout = Duration(seconds: 15);

/// Our opaque mediaId scheme. Encoded as a URI so album / artist names and
/// filepaths (which contain '/', spaces, ':') round-trip without delimiter
/// collisions: `mstreamauto://<type>?<params>`. Distinct from the http(s)
/// stream URLs used as queue-item ids, and from the plugin's bare 'root' /
/// 'recent' root ids.
const String _scheme = 'mstreamauto';

/// Content-style hints for a browse node's children (set on MediaItem.extras).
/// A node's hint governs how the head unit lays out ITS children, so set 'grid'
/// on nodes whose children carry cover art (albums) and 'list' on text-only
/// nodes (artists, playlists).
const Map<String, dynamic> _gridChildren = {
  AndroidContentStyle.browsableHintKey: AndroidContentStyle.gridItemHintValue,
};
const Map<String, dynamic> _listChildren = {
  AndroidContentStyle.browsableHintKey: AndroidContentStyle.listItemHintValue,
};
// For A–Z / # index nodes: a list of text rows with a tintable category icon
// (these have no artwork — the category style is what stops Android Auto from
// rendering them as broken art tiles).
const Map<String, dynamic> _categoryListChildren = {
  AndroidContentStyle.browsableHintKey:
      AndroidContentStyle.categoryListItemHintValue,
};

String _id(String type, Map<String, String?> params) {
  final qp = <String, String>{};
  params.forEach((k, v) {
    if (v != null) qp[k] = v;
  });
  return Uri(
    scheme: _scheme,
    host: type,
    queryParameters: qp.isEmpty ? null : qp,
  ).toString();
}

/// Wraps a remote album-art URL as a content:// URI served by the native
/// ArtContentProvider. Android Auto rejects a remote https artUri for browse
/// items ("Invalid album art uri") but loads a local content:// one — the
/// provider downloads + caches the bytes. The authority is flavor-scoped to
/// match the gradle applicationId (mstream.music[.plus]).
String _artContentUri(String remoteUrl) {
  final authority =
      '${isPlayBuild ? 'mstream.music' : 'mstream.music.plus'}.art';
  return Uri(
    scheme: 'content',
    host: authority,
    path: '/art',
    queryParameters: {'u': remoteUrl},
  ).toString();
}

/// Android Auto browse + playback for the active mStream server.
class AutoBrowse {
  // Short-lived per-server cache of the full albums/artists lists, so A–Z
  // bucket drill-ins reuse the parent tab's fetch instead of re-GETting the
  // whole library on every letter tap.
  static final Map<String, ({DateTime at, List<DisplayItem> rows})> _listCache =
      {};
  static Future<List<DisplayItem>> _list(
      String key, Future<List<DisplayItem>> Function() fetch) async {
    final hit = _listCache[key];
    if (hit != null && DateTime.now().difference(hit.at).inSeconds < 30) {
      return hit.rows;
    }
    final rows = await fetch();
    _listCache[key] = (at: DateTime.now(), rows: rows);
    return rows;
  }

  /// getChildren(parentMediaId): the tree Auto renders. Never throws — on no
  /// server / network failure it returns a single non-playable notice row.
  static Future<List<MediaItem>> children(String parentMediaId) async {
    try {
      await ServerManager().ensureLoaded();
      final Server? server = ServerManager().currentServer;
      if (server == null) {
        return [
          _notice('Open mStream on your phone',
              'Add a server there to browse it here'),
        ];
      }

      // Android 11 playback resumption requests the 'recent' root. Surfacing a
      // resume entry is a later enhancement; an empty list is valid.
      if (parentMediaId == AudioService.recentRootId) return const [];

      if (parentMediaId == AudioService.browsableRootId) {
        return _rootTabs(server);
      }

      final Uri? u = Uri.tryParse(parentMediaId);
      if (u == null || u.scheme != _scheme) return const [];
      final qp = u.queryParameters;
      final Server srv = ServerManager().byLocalname(qp['s']) ?? server;

      switch (u.host) {
        case 'cat':
          switch (qp['k']) {
            case 'recent':
              return _trackNodes(
                  await AutoApi.recent(srv), srv, 'recent', null);
            case 'albums':
              {
                final rows = await _list(
                    'albums:${srv.localname}', () => AutoApi.albums(srv));
                return rows.length > _maxChildren
                    ? _bucketView(rows, '', 'albums', srv)
                    : _albumNodes(rows, srv);
              }
            case 'artists':
              {
                final rows = await _list(
                    'artists:${srv.localname}', () => AutoApi.artists(srv));
                return rows.length > _maxChildren
                    ? _bucketView(rows, '', 'artists', srv)
                    : _artistNodes(rows, srv);
              }
            case 'playlists':
              return _playlistNodes(await AutoApi.playlists(srv), srv);
          }
          return const [];
        case 'artist':
          return _albumNodes(await AutoApi.artistAlbums(srv, qp['v']), srv);
        case 'album':
          return _trackNodes(
              await AutoApi.albumSongs(srv, qp['v']), srv, 'album', qp['v']);
        case 'playlist':
          return _trackNodes(await AutoApi.playlistSongs(srv, qp['v']), srv,
              'playlist', qp['v']);
        case 'bucket':
          {
            // A–Z(+deeper) drill-in: reuse the cached library list and keep
            // only the items under this prefix (sub-bucketing again if the
            // prefix itself still overflows — see _bucketView).
            final kind = qp['k'] == 'artists' ? 'artists' : 'albums';
            final all = await _list('$kind:${srv.localname}',
                () => kind == 'artists'
                    ? AutoApi.artists(srv)
                    : AutoApi.albums(srv));
            return _bucketView(all, qp['b'] ?? '', kind, srv);
          }
      }
      return const [];
    } catch (e) {
      // Never throw to Android Auto — degrade to a notice row. The try spans
      // ensureLoaded() too, so the no-throw contract is local to this file
      // (not dependent on loadServerList staying throw-free elsewhere).
      appLog('[auto] getChildren($parentMediaId) failed: $e');
      return [_notice('Couldn\'t load', 'Check your connection and try again')];
    }
  }

  /// getMediaItem(mediaId): cheap metadata for a single id, synthesised from
  /// the id alone (no network). Auto mostly relies on getChildren; this is a
  /// best-effort fallback.
  static Future<MediaItem?> mediaItem(String mediaId) async {
    final Uri? u = Uri.tryParse(mediaId);
    if (u == null || u.scheme != _scheme) return null;
    final qp = u.queryParameters;
    switch (u.host) {
      case 'track':
        final p = qp['p'];
        if (p == null) return null;
        return MediaItem(id: mediaId, title: p.split('/').last, playable: true);
      case 'album':
      case 'artist':
      case 'playlist':
        return MediaItem(id: mediaId, title: qp['v'] ?? '', playable: false);
      case 'bucket':
        return MediaItem(id: mediaId, title: qp['b'] ?? '', playable: false);
      case 'cat':
        return MediaItem(id: mediaId, title: qp['k'] ?? '', playable: false);
    }
    return null;
  }

  /// playFromMediaId(mediaId): a tapped track plays its WHOLE container from
  /// that point (so the car's next/previous works), reusing the exact in-app
  /// queue semantics (queue_actions.playFromHere → clear → enqueue → jump →
  /// play, routed through the active local/cast backend). No-op on a bad id /
  /// missing server / fetch failure.
  static Future<void> play(String mediaId) async {
    try {
      await ServerManager().ensureLoaded();
      final Uri? u = Uri.tryParse(mediaId);
      if (u == null || u.scheme != _scheme || u.host != 'track') return;
      final qp = u.queryParameters;
      final Server? srv = ServerManager().byLocalname(qp['s']) ??
          ServerManager().currentServer;
      final String? path = qp['p'];
      if (srv == null || path == null) return;

      final List<DisplayItem> rows;
      switch (qp['ct']) {
        case 'album':
          rows = await AutoApi.albumSongs(srv, qp['cv']);
          break;
        case 'playlist':
          rows = await AutoApi.playlistSongs(srv, qp['cv']);
          break;
        case 'recent':
          rows = await AutoApi.recent(srv);
          break;
        case 'search':
          rows = (await AutoApi.search(srv, qp['cv'] ?? '')).titles;
          break;
        default:
          return;
      }
      int index = rows.indexWhere((r) => r.data == path);
      if (index < 0) {
        // Stale id: the container changed between the browse that produced this
        // id and the tap. Start at the top rather than guessing.
        appLog('[auto] play: "$path" not in its container, starting at 0');
        index = 0;
      }
      // All rows are 'file' DisplayItems, so playFromHere's playable-filter is
      // a no-op and the index maps straight through.
      await playFromHere(rows, index);
    } catch (e) {
      appLog('[auto] play($mediaId) failed: $e');
    }
  }

  /// search(query): Android Auto's in-car search results — playable song hits
  /// first, then browsable albums and artists (tapping those navigates via
  /// getChildren). Never throws.
  static Future<List<MediaItem>> search(String query) async {
    try {
      await ServerManager().ensureLoaded();
      final Server? server = ServerManager().currentServer;
      if (server == null) {
        return [
          _notice('Open mStream on your phone',
              'Add a server there to search it here'),
        ];
      }
      final q = query.trim();
      if (q.isEmpty) return const [];
      final r = await AutoApi.search(server, q);
      final out = <MediaItem>[
        ..._trackNodes(r.titles, server, 'search', q),
        ..._albumNodes(r.albums, server),
        ..._artistNodes(r.artists, server),
      ];
      if (out.length > _maxChildren) {
        appLog('[auto] search("$q"): ${out.length} results, showing first '
            '$_maxChildren');
        return out.sublist(0, _maxChildren);
      }
      return out;
    } catch (e) {
      appLog('[auto] search("$query") failed: $e');
      return [
        _notice('Couldn\'t search', 'Check your connection and try again'),
      ];
    }
  }

  /// playFromSearch(query): Google Assistant voice. Precedence: a matching song
  /// (starting on the exact-title hit when present, since the server's title
  /// results aren't relevance-ranked), else the first named album, else the
  /// first named artist's first named album. Never throws.
  static Future<void> playFromSearch(String query) async {
    try {
      await ServerManager().ensureLoaded();
      final Server? server = ServerManager().currentServer;
      final q = query.trim();
      if (server == null || q.isEmpty) return;
      final r = await AutoApi.search(server, q);

      if (r.titles.isNotEmpty) {
        // Start on the exact title match if there is one; queue the rest behind.
        final i =
            r.titles.indexWhere((t) => t.name.toLowerCase() == q.toLowerCase());
        await playFromHere(r.titles, i < 0 ? 0 : i);
        return;
      }
      // Skip null-named ('Singles') buckets — the server can't load album:null.
      final album = _firstNamed(r.albums);
      if (album != null) {
        final songs = await AutoApi.albumSongs(server, album);
        if (songs.isNotEmpty) {
          await playFromHere(songs, 0);
          return;
        }
      }
      final artist = _firstNamed(r.artists);
      if (artist != null) {
        final albumOf = _firstNamed(await AutoApi.artistAlbums(server, artist));
        if (albumOf != null) {
          final songs = await AutoApi.albumSongs(server, albumOf);
          if (songs.isNotEmpty) {
            await playFromHere(songs, 0);
            return;
          }
        }
      }
      appLog('[auto] playFromSearch("$q"): no playable match');
    } catch (e) {
      appLog('[auto] playFromSearch("$query") failed: $e');
    }
  }

  /// The [DisplayItem.data] of the first item with a non-null name (server
  /// list/album endpoints use a null name for the "Singles" bucket, which the
  /// album/artist-albums endpoints can't be asked to load).
  static String? _firstNamed(List<DisplayItem> items) {
    for (final i in items) {
      if (i.data != null) return i.data;
    }
    return null;
  }

  // ── tree nodes ──

  static List<MediaItem> _rootTabs(Server server) {
    final String s = server.localname;
    // Albums/Artists open onto an A–Z letter index (category list), or — for a
    // small library — straight to album/artist rows. The album-art grid is
    // applied one level down on the album leaves (see _bucketView childStyle).
    // Recent's children are playable tracks.
    return [
      _browse(_id('cat', {'s': s, 'k': 'recent'}), 'Recently Added'),
      _browse(_id('cat', {'s': s, 'k': 'playlists'}), 'Playlists',
          styleExtras: _listChildren),
      _browse(_id('cat', {'s': s, 'k': 'albums'}), 'Albums',
          styleExtras: _categoryListChildren),
      _browse(_id('cat', {'s': s, 'k': 'artists'}), 'Artists',
          styleExtras: _categoryListChildren),
    ];
  }

  /// Decides a browse node's children: a flat leaf list when the items fit, or
  /// letter sub-bucket nodes when they overflow, so a multi-thousand-item
  /// library stays reachable on a head unit (which truncates long lists).
  /// [prefix] is '' at the tab root and the accumulated letters on drill-in. An
  /// overflowing bucket sub-buckets by one more character (capped depth — see
  /// autoBucketPrefixes), and bucketing is by the real first character(s), so
  /// non-Latin names get their own buckets instead of collapsing together.
  static List<MediaItem> _bucketView(
      List<DisplayItem> all, String prefix, String kind, Server srv) {
    // '#' is the synthetic non-letter top bucket — its items render as leaves.
    if (prefix == '#') {
      final matched = [for (final r in all) if (autoTopBucket(r.name) == '#') r];
      return _leafNodes(matched, kind, srv);
    }

    // Top level: one bucket per first letter, '#' (digits/symbols) last.
    if (prefix.isEmpty) {
      final counts = <String, int>{};
      for (final r in all) {
        counts.update(autoTopBucket(r.name), (n) => n + 1, ifAbsent: () => 1);
      }
      final labels = autoTopBuckets(all.map((r) => r.name));
      appLog('[auto] $kind "*": ${all.length} items → ${labels.length} buckets');
      return _bucketNodes(labels, counts, kind, srv);
    }

    // Drill into a letter prefix; sub-bucket again if it still overflows.
    final matched = [
      for (final r in all)
        if (autoBucketKey(r.name).startsWith(prefix)) r
    ];
    final subs = autoBucketPrefixes(
        matched.map((r) => autoBucketKey(r.name)), prefix, _maxChildren);
    if (subs.isEmpty) return _leafNodes(matched, kind, srv);
    final counts = <String, int>{};
    for (final r in matched) {
      final k = autoBucketKey(r.name);
      if (k.length > prefix.length) {
        counts.update(
            k.substring(0, prefix.length + 1), (n) => n + 1, ifAbsent: () => 1);
      }
    }
    // Names equal to the prefix can't extend — render them as leaves alongside.
    final exact = [
      for (final r in matched)
        if (autoBucketKey(r.name).length <= prefix.length) r
    ];
    appLog('[auto] $kind "$prefix": '
        '${matched.length} items → ${subs.length} buckets');
    return [
      ..._bucketNodes(subs, counts, kind, srv),
      ..._leafNodes(exact, kind, srv),
    ];
  }

  /// Builds bucket browse nodes for [labels] (with per-label membership
  /// [counts]). A bucket's content style depends on what drilling into it
  /// shows: album leaves want an art grid, but a bucket that itself sub-buckets
  /// (an album letter over the cap, below the depth limit) shows letter
  /// sub-buckets, which want a list — otherwise they'd render as art-less grid
  /// tiles. Artist buckets are always a list.
  static List<MediaItem> _bucketNodes(
      List<String> labels, Map<String, int> counts, String kind, Server srv) {
    return [
      for (final b in labels)
        _browse(_id('bucket', {'s': srv.localname, 'k': kind, 'b': b}), b,
            styleExtras: _bucketChildStyle(kind, b, counts[b] ?? 0)),
    ];
  }

  static Map<String, dynamic> _bucketChildStyle(
      String kind, String label, int count) {
    final willSubBucket = label != '#' &&
        count > _maxChildren &&
        label.length < autoBucketMaxDepth;
    // A bucket that sub-buckets shows a letter index → category list. Otherwise
    // it shows leaves: album covers in a grid, artists in a plain list.
    if (willSubBucket) return _categoryListChildren;
    return kind == 'albums' ? _gridChildren : _listChildren;
  }

  static List<MediaItem> _leafNodes(
          List<DisplayItem> rows, String kind, Server srv) =>
      kind == 'artists' ? _artistNodes(rows, srv) : _albumNodes(rows, srv);

  static List<MediaItem> _albumNodes(List<DisplayItem> rows, Server srv) {
    final out = <MediaItem>[];
    for (final r in _capped(rows, 'albums')) {
      if (r.type != 'album') continue;
      final art = r.altAlbumArt != null
          ? buildAlbumArtUrl(srv, r.altAlbumArt!, compress: 'm')
          : null;
      out.add(_browse(
        _id('album', {'s': srv.localname, 'v': r.data}),
        r.name,
        subtitle: r.subtext,
        artUri: art == null ? null : _artContentUri(art),
      ));
    }
    return out;
  }

  static List<MediaItem> _artistNodes(List<DisplayItem> rows, Server srv) {
    final out = <MediaItem>[];
    for (final r in _capped(rows, 'artists')) {
      if (r.type != 'artist') continue;
      // Grid hint so this artist's albums (its browsable children) show as an
      // art grid instead of inheriting the 'list' hint from the Artists tab.
      out.add(_browse(_id('artist', {'s': srv.localname, 'v': r.data}), r.name,
          styleExtras: _gridChildren));
    }
    return out;
  }

  static List<MediaItem> _playlistNodes(List<DisplayItem> rows, Server srv) {
    final out = <MediaItem>[];
    for (final r in _capped(rows, 'playlists')) {
      if (r.type != 'playlist') continue;
      out.add(
          _browse(_id('playlist', {'s': srv.localname, 'v': r.data}), r.name));
    }
    return out;
  }

  static List<MediaItem> _trackNodes(
      List<DisplayItem> rows, Server srv, String containerType,
      String? containerValue) {
    final out = <MediaItem>[];
    for (final r in _capped(rows, containerType)) {
      if (r.type != 'file' || r.data == null) continue;
      final m = r.metadata;
      final artFile = r.altAlbumArt ?? m?.albumArt;
      final art =
          artFile != null ? buildAlbumArtUrl(srv, artFile, compress: 'l') : null;
      out.add(MediaItem(
        id: _id('track', {
          's': srv.localname,
          'p': r.data,
          'ct': containerType,
          'cv': containerValue,
        }),
        title: m?.title ?? r.data!.split('/').last,
        artist: m?.artist,
        album: m?.album,
        duration: m?.duration,
        artUri: art == null ? null : Uri.parse(_artContentUri(art)),
        playable: true,
      ));
    }
    return out;
  }

  static MediaItem _browse(String id, String title,
      {String? subtitle, String? artUri, Map<String, dynamic>? styleExtras}) {
    return MediaItem(
      id: id,
      title: title,
      artist: subtitle,
      playable: false,
      artUri: artUri == null ? null : Uri.parse(artUri),
      extras: styleExtras,
    );
  }

  /// A non-playable informational row (no server / load error). Tapping it
  /// returns no children (the id isn't in our scheme).
  static MediaItem _notice(String title, String subtitle) => MediaItem(
        id: '$_scheme://notice',
        title: title,
        artist: subtitle,
        playable: false,
      );

  static Iterable<DisplayItem> _capped(List<DisplayItem> rows, String label) {
    if (rows.length <= _maxChildren) return rows;
    appLog('[auto] $label: ${rows.length} items, showing first $_maxChildren');
    return rows.take(_maxChildren);
  }
}

/// Headless, BrowserManager-free reads of the mStream library. Mirrors the
/// endpoints + response parsing in ApiManager but returns plain DisplayItems
/// (server + metadata populated) and never touches UI state. Throws on a
/// network / non-2xx error so the caller can show an Auto notice.
class AutoApi {
  static Future<dynamic> _call(Server server, String location,
      {Map<String, dynamic>? body}) async {
    final uri = Uri.parse(server.url).resolve(location);
    final headers = <String, String>{'x-access-token': server.jwt ?? ''};
    late http.Response resp;
    if (body == null) {
      resp = await http.get(uri, headers: headers).timeout(_fetchTimeout);
    } else {
      headers['Content-Type'] = 'application/json';
      resp = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(_fetchTimeout);
    }
    if (resp.statusCode > 299) {
      throw Exception('HTTP ${resp.statusCode} for $location');
    }
    return jsonDecode(resp.body);
  }

  static Future<List<DisplayItem>> albums(Server s) async {
    final res = await _call(s, '/api/v1/db/albums');
    final out = <DisplayItem>[];
    for (final e in (res['albums'] as List? ?? const [])) {
      final artist = (e['album_artist'] ?? e['albumArtist'] ?? e['artist'])
          ?.toString()
          .trim();
      final year = e['year']?.toString().trim();
      final subtitle = [
        if (artist != null && artist.isNotEmpty) artist,
        if (year != null && year.isNotEmpty) year,
      ].join(' · ');
      final di = DisplayItem(
          s, e['name'] ?? '', 'album', e['name'], null,
          subtitle.isEmpty ? null : subtitle);
      di.altAlbumArt = e['album_art_file'];
      out.add(di);
    }
    return out;
  }

  static Future<List<DisplayItem>> artists(Server s) async {
    final res = await _call(s, '/api/v1/db/artists');
    final out = <DisplayItem>[];
    for (final e in (res['artists'] as List? ?? const [])) {
      out.add(DisplayItem(s, e.toString(), 'artist', e.toString(), null, null));
    }
    return out;
  }

  static Future<List<DisplayItem>> artistAlbums(Server s, String? artist) async {
    final res =
        await _call(s, '/api/v1/db/artists-albums', body: {'artist': artist});
    final out = <DisplayItem>[];
    for (final e in (res['albums'] as List? ?? const [])) {
      final di = DisplayItem(
          s, e['name'] ?? 'Singles', 'album', e['name'], null,
          e['year']?.toString());
      di.altAlbumArt = e['album_art_file'];
      out.add(di);
    }
    return out;
  }

  static Future<List<DisplayItem>> albumSongs(Server s, String? album) async {
    final res = await _call(s, '/api/v1/db/album-songs', body: {'album': album});
    return _fileItems(res, s);
  }

  static Future<List<DisplayItem>> playlists(Server s) async {
    final res = await _call(s, '/api/v1/playlist/getall');
    final out = <DisplayItem>[];
    for (final e in (res as List? ?? const [])) {
      out.add(DisplayItem(s, e['name'], 'playlist', e['name'], null, null));
    }
    return out;
  }

  static Future<List<DisplayItem>> playlistSongs(Server s, String? name) async {
    final res =
        await _call(s, '/api/v1/playlist/load', body: {'playlistname': name});
    return _fileItems(res, s);
  }

  static Future<List<DisplayItem>> recent(Server s) async {
    final res = await _call(s, '/api/v1/db/recent/added', body: {'limit': 100});
    return _fileItems(res, s);
  }

  /// Library search (artists + albums + song titles; raw files excluded).
  /// Returns the three result groups as DisplayItems. Title hits carry a
  /// synthesised MusicMetadata (title + art) — the search endpoint returns only
  /// name/filepath/art per hit, not the full metadata block — so they play with
  /// a proper label and cover rather than a bare filename.
  static Future<
      ({
        List<DisplayItem> artists,
        List<DisplayItem> albums,
        List<DisplayItem> titles,
      })> search(Server s, String query) async {
    final res = await _call(s, '/api/v1/db/search', body: {
      'search': query,
      'noArtists': false,
      'noAlbums': false,
      'noTitles': false,
      'noFiles': true,
    });
    final artists = <DisplayItem>[];
    for (final e in (res['artists'] as List? ?? const [])) {
      final di = DisplayItem(s, e['name'], 'artist', e['name'], null, null);
      di.altAlbumArt = e['album_art_file'];
      artists.add(di);
    }
    final albums = <DisplayItem>[];
    for (final e in (res['albums'] as List? ?? const [])) {
      final di = DisplayItem(s, e['name'], 'album', e['name'], null, null);
      di.altAlbumArt = e['album_art_file'];
      albums.add(di);
    }
    final titles = <DisplayItem>[];
    for (final e in (res['title'] as List? ?? const [])) {
      final di =
          DisplayItem(s, e['name'], 'file', '/${e['filepath']}', null, null);
      di.metadata = MusicMetadata.fromServerMap({
        'title': e['name'],
        'album-art': e['album_art_file'],
      });
      titles.add(di);
    }
    return (artists: artists, albums: albums, titles: titles);
  }

  /// Shared parser for the `[{ filepath, metadata }]` track-list responses
  /// (album-songs / playlist-load / recent). Builds the same 'file'
  /// DisplayItems the in-app browser does, so queue_actions can play them.
  static List<DisplayItem> _fileItems(dynamic res, Server s) {
    final out = <DisplayItem>[];
    for (final e in (res as List? ?? const [])) {
      final di = DisplayItem(
          s, e['filepath'], 'file', '/${e['filepath']}', null, null);
      // Guard the metadata parse so one unscanned / metadata-less track
      // degrades to a filename-titled row instead of failing the whole
      // album/playlist (mirrors getFileList's `inner is Map` guard);
      // _trackNodes already tolerates null metadata.
      final md = e['metadata'];
      if (md is Map) di.metadata = MusicMetadata.fromServerMap(md);
      out.add(di);
    }
    return out;
  }
}
