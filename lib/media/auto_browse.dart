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
import 'package:path/path.dart' as p;
import 'package:package_info_plus/package_info_plus.dart';

import 'auto_buckets.dart';
import '../objects/display_item.dart';
import '../objects/metadata.dart';
import '../objects/server.dart';
import '../singletons/log_manager.dart';
import '../singletons/media.dart';
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

// The album-art ContentProvider authority, resolved at startup from the real
// package name (== the gradle applicationId), so content:// URIs always match
// the manifest's ${applicationId}.art — even when the play flavor is built
// without --dart-define=VARIANT=play. Null until initAutoArt() runs; the
// fallback inference below is then used (correct for CI builds, where VARIANT
// matches the flavor).
String? _artAuthority;

/// Resolve the art ContentProvider authority from the real package name. Call
/// once at startup (main). Best-effort — on failure the fallback inference is
/// used.
Future<void> initAutoArt() async {
  try {
    final info = await PackageInfo.fromPlatform();
    if (info.packageName.isNotEmpty) _artAuthority = '${info.packageName}.art';
  } catch (_) {}
  appLog('[auto] art authority: ${_artAuthority ?? '(fallback inference)'}');
}

/// Wraps a remote album-art URL as a content:// URI served by the native
/// ArtContentProvider. Android Auto rejects a remote https artUri for browse
/// items ("Invalid album art uri") but loads a local content:// one — the
/// provider downloads + caches the bytes.
String _artContentUri(String remoteUrl) {
  final authority = _artAuthority ??
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

      // Android 11 playback resumption requests the 'recent' root: surface the
      // now-playing item (when the queue is warm) as a playable 'resume' entry.
      if (parentMediaId == AudioService.recentRootId) {
        final cur = MediaManager().audioHandler.mediaItem.value;
        if (cur == null) return const [];
        final art = cur.extras?['artUrl'];
        return [
          MediaItem(
            id: _id('resume', const {}),
            title: cur.title,
            artist: cur.artist,
            album: cur.album,
            artUri: art is String ? Uri.parse(_artContentUri(art)) : null,
            playable: true,
          ),
        ];
      }

      if (parentMediaId == AudioService.browsableRootId) {
        return _rootTabs(server);
      }

      final Uri? u = Uri.tryParse(parentMediaId);
      if (u == null || u.scheme != _scheme) return const [];
      final qp = u.queryParameters;
      // A node carries the server it was built on; if that server is gone, don't
      // silently re-fetch it from a different one — show the load notice.
      final Server? srv = _serverForId(qp['s']);
      if (srv == null) {
        return [_notice('Couldn\'t load', 'Check your connection and try again')];
      }

      switch (u.host) {
        case 'cat':
          switch (qp['k']) {
            case 'recent':
              return _orEmptyNotice(_paginate(
                  _trackNodes(await AutoApi.recent(srv), srv, 'recent', null),
                  u));
            case 'albums':
              {
                final rows = await _list(
                    'albums:${srv.localname}', () => AutoApi.albums(srv));
                return _orEmptyNotice(rows.length > _maxChildren
                    ? _bucketView(rows, '', 'albums', srv)
                    : _albumNodes(rows, srv));
              }
            case 'artists':
              {
                final rows = await _list(
                    'artists:${srv.localname}', () => AutoApi.artists(srv));
                return _orEmptyNotice(rows.length > _maxChildren
                    ? _bucketView(rows, '', 'artists', srv)
                    : _artistNodes(rows, srv));
              }
            case 'playlists':
              return _orEmptyNotice(_paginate(
                  _playlistNodes(await AutoApi.playlists(srv), srv), u));
          }
          return const [];
        case 'artist':
          return _orEmptyNotice(_paginate(
              _albumNodes(await AutoApi.artistAlbums(srv, qp['v']), srv), u,
              moreStyle: _gridChildren));
        case 'album':
          return _orEmptyNotice(_paginate(
              _trackNodes(await AutoApi.albumSongs(srv, qp['v']), srv, 'album',
                  qp['v']),
              u));
        case 'playlist':
          return _orEmptyNotice(_paginate(
              _trackNodes(await AutoApi.playlistSongs(srv, qp['v']), srv,
                  'playlist', qp['v']),
              u));
        case 'dir':
          {
            // A folder: its subfolders (browsable) then its tracks (playable).
            final fl = await AutoApi.fileList(srv, qp['p'] ?? '~');
            return _orEmptyNotice(_paginate([
              ..._dirNodes(fl.dirs, srv),
              ..._trackNodes(fl.files, srv, 'dir', qp['p']),
            ], u));
          }
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
            return _orEmptyNotice(_paginate(
                _bucketView(all, qp['b'] ?? '', kind, srv), u,
                moreStyle: kind == 'albums' ? _gridChildren : _listChildren));
          }
      }
      return const [];
    } catch (e) {
      // Never throw to Android Auto — degrade to a notice row. The try spans
      // ensureLoaded() too, so the no-throw contract is local to this file
      // (not dependent on loadServerList staying throw-free elsewhere).
      appLog('[auto] getChildren($parentMediaId) failed: $e');
      return [_errorNotice(e)];
    }
  }

  /// getMediaItem(mediaId): cheap metadata for a single id, synthesised from
  /// the id alone (no network). Auto mostly relies on getChildren; this is a
  /// best-effort fallback.
  static Future<MediaItem?> mediaItem(String mediaId) async {
    // Never throw to Android Auto. The synthesis below is throw-free today; this
    // guard hardens it against future edits, matching the other browse callbacks.
    try {
      return _mediaItem(mediaId);
    } catch (e) {
      appLog('[auto] getMediaItem($mediaId) failed: $e');
      return null;
    }
  }

  static MediaItem? _mediaItem(String mediaId) {
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
      case 'dir':
        return MediaItem(
            id: mediaId,
            title: (qp['p'] == null || qp['p'] == '~')
                ? 'Files'
                : p.basename(qp['p']!),
            playable: false);
      case 'bucket':
        return MediaItem(id: mediaId, title: qp['b'] ?? '', playable: false);
      case 'cat':
        return MediaItem(id: mediaId, title: qp['k'] ?? '', playable: false);
      case 'shuffle':
        return MediaItem(id: mediaId, title: 'Shuffle All', playable: true);
      case 'resume':
        return MediaItem(id: mediaId, title: 'Resume', playable: true);
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
      if (u == null || u.scheme != _scheme) return;
      final qp = u.queryParameters;
      final handler = MediaManager().audioHandler;

      // Resume the restored queue (no-op if there's nothing to resume).
      if (u.host == 'resume') {
        if (handler.queue.value.isNotEmpty) await handler.play();
        return;
      }

      // A track/album/etc. id carries the server it was minted on. If that
      // server is gone (removed / renamed since the browse), treat the id as
      // stale and no-op rather than playing from a different same-named server.
      final Server? srv = _serverForId(qp['s']);
      if (srv == null) {
        final s = qp['s'];
        if (s != null && s.isNotEmpty) {
          appLog('[auto] play: server "$s" no longer configured — stale id');
        }
        return;
      }

      // Shuffle All: hand the library to the app's Auto-DJ from a clean queue —
      // infinite random play, reusing its working random-songs payload + top-up.
      if (u.host == 'shuffle') {
        await handler.customAction('clearPlaylist');
        await handler.customAction('setAutoDJ', {'autoDJServer': srv});
        return;
      }

      if (u.host != 'track') return;
      final String? path = qp['p'];
      if (path == null) return;

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
        case 'dir':
          rows = (await AutoApi.fileList(srv, qp['cv'] ?? '~')).files;
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
      if (out.isEmpty) return [_notice('No results', 'Try a different search')];
      if (out.length > _maxChildren) {
        appLog('[auto] search("$q"): ${out.length} results, showing first '
            '$_maxChildren');
        return out.sublist(0, _maxChildren);
      }
      return out;
    } catch (e) {
      appLog('[auto] search("$query") failed: $e');
      return [_errorNotice(e, generic: 'Couldn\'t search')];
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
      // A playable quick-action: hand the whole library to Auto-DJ (infinite
      // shuffle). First, so it's the obvious "just play something" option.
      MediaItem(
          id: _id('shuffle', {'s': s}), title: 'Shuffle All', playable: true),
      _browse(_id('cat', {'s': s, 'k': 'recent'}), 'Recently Added'),
      _browse(_id('cat', {'s': s, 'k': 'playlists'}), 'Playlists',
          styleExtras: _listChildren),
      _browse(_id('cat', {'s': s, 'k': 'albums'}), 'Albums',
          styleExtras: _categoryListChildren),
      _browse(_id('cat', {'s': s, 'k': 'artists'}), 'Artists',
          styleExtras: _categoryListChildren),
      // The server's folder tree, starting at its '~' root.
      _browse(_id('dir', {'s': s, 'p': '~'}), 'Files',
          styleExtras: _listChildren),
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
    for (final r in rows) {
      // Skip a null-named album (mStream's untagged-tracks "Singles" bucket):
      // its id would carry no 'v', and album:null can't be loaded server-side
      // (matches _firstNamed / _dirNodes / _trackNodes).
      if (r.type != 'album' || r.data == null) continue;
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
    for (final r in rows) {
      if (r.type != 'artist' || r.data == null) continue;
      // Grid hint so this artist's albums (its browsable children) show as an
      // art grid instead of inheriting the 'list' hint from the Artists tab.
      out.add(_browse(_id('artist', {'s': srv.localname, 'v': r.data}), r.name,
          styleExtras: _gridChildren));
    }
    return out;
  }

  static List<MediaItem> _playlistNodes(List<DisplayItem> rows, Server srv) {
    final out = <MediaItem>[];
    for (final r in rows) {
      if (r.type != 'playlist' || r.data == null) continue;
      out.add(
          _browse(_id('playlist', {'s': srv.localname, 'v': r.data}), r.name));
    }
    return out;
  }

  static List<MediaItem> _dirNodes(List<DisplayItem> dirs, Server srv) {
    final out = <MediaItem>[];
    for (final r in dirs) {
      if (r.type != 'directory' || r.data == null) continue;
      out.add(_browse(_id('dir', {'s': srv.localname, 'p': r.data}), r.name,
          styleExtras: _listChildren));
    }
    return out;
  }

  static List<MediaItem> _trackNodes(
      List<DisplayItem> rows, Server srv, String containerType,
      String? containerValue) {
    final out = <MediaItem>[];
    for (final r in rows) {
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

  /// A user-navigated list (an album's tracks, a folder, a playlist, the recent
  /// list, etc.) that comes back empty shows a "nothing here" notice row instead
  /// of a blank Android Auto screen — matching the no-server / error paths.
  /// Unknown / intermediate nodes stay silently empty (not routed through here).
  static List<MediaItem> _orEmptyNotice(List<MediaItem> items) =>
      items.isEmpty ? [_notice('Nothing here', 'This list is empty')] : items;

  /// One [_maxChildren]-sized page of [all], with a browsable "Show more" node
  /// appended (re-entering [id] at the next page via a `pg` query param) when
  /// more remain — so a leaf list longer than the cap stays fully reachable
  /// while no single node ever approaches the Binder transaction limit (~1 MB;
  /// a 200-item page measures well under it). A no-op for lists within the cap.
  static List<MediaItem> _paginate(List<MediaItem> all, Uri id,
      {Map<String, dynamic>? moreStyle}) {
    if (all.length <= _maxChildren) return all;
    final page = int.tryParse(id.queryParameters['pg'] ?? '') ?? 0;
    final start = page * _maxChildren;
    // page < 0 only via a hand-tampered id (we mint pg=1,2,3…); guard the
    // negative-range sublist rather than rely on children()'s catch.
    if (page < 0 || start >= all.length) return const [];
    final end =
        start + _maxChildren < all.length ? start + _maxChildren : all.length;
    final window = all.sublist(start, end); // a new growable list
    if (end < all.length) {
      final qp = Map<String, String>.from(id.queryParameters)
        ..['pg'] = '${page + 1}';
      // List style by default; album-grid callers pass _gridChildren so the
      // continuation keeps page 0's grid layout instead of inheriting a list.
      window.add(_browse(id.replace(queryParameters: qp).toString(), 'Show more',
          styleExtras: moreStyle ?? _listChildren));
    }
    return window;
  }

  /// Resolve the server an id was minted on. A present-but-unknown localname
  /// (the server was removed / renamed since this id was built) returns null so
  /// callers no-op rather than silently acting on a DIFFERENT server; an
  /// absent / empty localname falls back to the current server.
  static Server? _serverForId(String? localname) =>
      (localname == null || localname.isEmpty)
          ? ServerManager().currentServer
          : ServerManager().byLocalname(localname);

  /// Map a browse / search failure to a user-facing notice that distinguishes a
  /// server we couldn't REACH (check the connection) from one that answered with
  /// an error (reopen mStream on the phone). NOTE on mStream: a missing/empty
  /// token returns 401, but an expired/invalid token comes back as 500 (the JWT
  /// verify throws and isn't mapped to 401), so a 5xx is shown as a server-side
  /// problem the user resolves on the phone — where an expired session is
  /// visible — rather than a connection error.
  static MediaItem _errorNotice(Object e, {String generic = 'Couldn\'t load'}) {
    if (e is AutoHttpException) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        return _notice('Sign in again', 'Open mStream on your phone');
      }
      if (e.statusCode >= 500) {
        return _notice('Server error', 'Open mStream on your phone');
      }
      // Another 4xx: the server answered but refused — not a connection issue.
      return _notice(generic, 'Open mStream on your phone');
    }
    // No usable HTTP response (timeout / offline / unparseable body).
    return _notice(generic, 'Check your connection and try again');
  }
}

/// Thrown by [AutoApi._call] on a non-2xx response so the browse / search catch
/// can tell an HTTP error (the server was reached) from a transport failure
/// (offline / timeout) and branch the user notice on the status. (mStream: 401 =
/// missing token, 500 = a token that failed to verify, e.g. expired.)
class AutoHttpException implements Exception {
  final int statusCode;
  final String location;
  AutoHttpException(this.statusCode, this.location);
  @override
  String toString() => 'HTTP $statusCode for $location';
}

/// Headless, BrowserManager-free reads of the mStream library. Mirrors the
/// endpoints + response parsing in ApiManager but returns plain DisplayItems
/// (server + metadata populated) and never touches UI state. Throws on a
/// network / non-2xx error so the caller can show an Auto notice.
class AutoApi {
  static Future<dynamic> _call(Server server, String location,
      {Map<String, dynamic>? body}) async {
    final uri = server.apiUri(location);
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
      throw AutoHttpException(resp.statusCode, location);
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
      final name = e['name']?.toString();
      if (name == null || name.isEmpty) continue; // skip a malformed row
      out.add(DisplayItem(s, name, 'playlist', name, null, null));
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

  /// Lists a server [directory] ('~' is the root). Returns its subfolders and
  /// playable files as DisplayItems, with file paths joined the same way the
  /// in-app file browser does so playback (buildServerFileMediaItem) is
  /// identical. pullMetadata is on so tracks show real titles + art in the car.
  static Future<({List<DisplayItem> dirs, List<DisplayItem> files})> fileList(
      Server s, String directory) async {
    final res = await _call(s, '/api/v1/file-explorer',
        body: {'directory': directory, 'pullMetadata': true});
    final base = res['path'] as String? ?? '';
    final dirs = <DisplayItem>[];
    for (final e in (res['directories'] as List? ?? const [])) {
      final name = e['name'] as String?;
      if (name == null) continue;
      dirs.add(
          DisplayItem(s, name, 'directory', p.join(base, name), null, null));
    }
    final files = <DisplayItem>[];
    for (final e in (res['files'] as List? ?? const [])) {
      final name = e['name'] as String?;
      if (name == null) continue;
      final di = DisplayItem(s, name, 'file', p.join(base, name), null, null);
      // The server wraps each file's metadata as { metadata: {…} }; drill in.
      final inner = e['metadata'] is Map ? e['metadata']['metadata'] : null;
      if (inner is Map) di.metadata = MusicMetadata.fromServerMap(inner);
      files.add(di);
    }
    return (dirs: dirs, files: files);
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
      // Voice/car search wants name matches, not noisy full-text lyric hits, and
      // this parser ignores the `lyrics` array anyway — opt out so the server
      // skips the lyric FTS work.
      'noLyrics': true,
    });
    final artists = <DisplayItem>[];
    for (final e in (res['artists'] as List? ?? const [])) {
      final name = e['name']?.toString();
      if (name == null || name.isEmpty) continue;
      final di = DisplayItem(s, name, 'artist', name, null, null);
      di.altAlbumArt = e['album_art_file'];
      artists.add(di);
    }
    final albums = <DisplayItem>[];
    for (final e in (res['albums'] as List? ?? const [])) {
      final name = e['name']?.toString();
      if (name == null || name.isEmpty) continue;
      final di = DisplayItem(s, name, 'album', name, null, null);
      di.altAlbumArt = e['album_art_file'];
      albums.add(di);
    }
    final titles = <DisplayItem>[];
    for (final e in (res['title'] as List? ?? const [])) {
      final fp = e['filepath']?.toString();
      if (fp == null || fp.isEmpty) continue; // skip a hit with no play target
      final title = e['name']?.toString() ?? fp;
      final di = DisplayItem(s, title, 'file', '/$fp', null, null);
      di.metadata = MusicMetadata.fromServerMap({
        'title': title,
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
      final fp = e['filepath']?.toString();
      if (fp == null || fp.isEmpty) continue; // skip a row with no play target
      final di = DisplayItem(s, fp, 'file', '/$fp', null, null);
      // Tolerate one malformed / typed row: a bad metadata block (or any parse
      // slip) drops just that track instead of failing the whole album/playlist
      // (mirrors getFileList's per-row guard; _trackNodes tolerates null meta).
      try {
        final md = e['metadata'];
        if (md is Map) di.metadata = MusicMetadata.fromServerMap(md);
      } catch (_) {/* keep the filename-titled row */}
      out.add(di);
    }
    return out;
  }
}
