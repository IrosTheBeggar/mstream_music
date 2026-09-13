import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'models.dart';
import 'schema.dart';

/// The local library index — one SQLite file per device, every table scoped
/// by `server` (the app's `Server.localname`). Synchronous: every call is a
/// handful of indexed statements; the heavy writers (a manifest page, an
/// import walk) wrap themselves in one transaction and are meant to run on
/// a background isolate with their own [LibraryIndex.open].
class LibraryIndex {
  final Database _db;

  LibraryIndex._(this._db);

  /// Opens (creating and migrating as needed) the index at [path]. WAL so a
  /// reader on the UI isolate never blocks a writer on a sync isolate;
  /// busy_timeout so the two wait for each other instead of failing.
  static LibraryIndex open(String path) => _init(sqlite3.open(path));

  /// A throwaway in-memory index (tests).
  static LibraryIndex inMemory() => _init(sqlite3.openInMemory());

  static LibraryIndex _init(Database db) {
    db.execute('PRAGMA journal_mode = WAL');
    db.execute('PRAGMA busy_timeout = 5000');
    db.execute('PRAGMA foreign_keys = ON');
    migrate(db);
    return LibraryIndex._(db);
  }

  /// Brings [db] to [kSchemaVersion]. An index written by a NEWER app is
  /// refused: guessing at unknown columns is how data gets corrupted.
  static void migrate(Database db) {
    final v = db.select('PRAGMA user_version').first.columnAt(0) as int;
    if (v > kSchemaVersion) {
      throw StateError('library index is schema v$v; this app knows v$kSchemaVersion');
    }
    if (v == kSchemaVersion) return;
    db.execute('BEGIN');
    try {
      for (final s in upgradeStatements(v)) {
        db.execute(s);
      }
      db.execute('PRAGMA user_version = $kSchemaVersion');
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  void close() => _db.close();

  /// Runs [fn] in one write transaction; rolls back on throw.
  T transaction<T>(T Function() fn) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      final out = fn();
      _db.execute('COMMIT');
      return out;
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  // ── meta ──────────────────────────────────────────────────────────────

  String? meta(String server, String key) {
    final r = _db.select(
        'SELECT value FROM meta WHERE server = ? AND key = ?', [server, key]);
    return r.isEmpty ? null : r.first['value'] as String?;
  }

  void setMeta(String server, String key, String? value) => _db.execute(
      'INSERT INTO meta (server, key, value) VALUES (?, ?, ?) '
      'ON CONFLICT (server, key) DO UPDATE SET value = excluded.value',
      [server, key, value]);

  // ── remote tracks (the manifest) ──────────────────────────────────────

  /// Upserts one manifest page, stamping every row with [rev] so
  /// [pruneUnseen] can find what the server stopped listing. A path already
  /// held under a different id (the server deleted and re-added the file)
  /// is replaced, not duplicated.
  void upsertTracks(String server, Iterable<RemoteTrack> rows, String rev) {
    final evict = _db.prepare(
        'DELETE FROM remote_tracks WHERE server = ? AND path = ? AND id <> ?');
    final upsert = _db.prepare('''
      INSERT INTO remote_tracks (server, id, path, size, modified, hash, audio_hash,
        hash_v, album_id, artist_id, art, created_at, title, artist, album, track,
        disc, year, duration, format, genres, rating, seen_rev)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT (server, id) DO UPDATE SET
        path = excluded.path, size = excluded.size, modified = excluded.modified,
        hash = excluded.hash, audio_hash = excluded.audio_hash, hash_v = excluded.hash_v,
        album_id = excluded.album_id, artist_id = excluded.artist_id, art = excluded.art,
        created_at = excluded.created_at, title = excluded.title, artist = excluded.artist,
        album = excluded.album, track = excluded.track, disc = excluded.disc,
        year = excluded.year, duration = excluded.duration, format = excluded.format,
        genres = excluded.genres, rating = excluded.rating, seen_rev = excluded.seen_rev
    ''');
    try {
      transaction(() {
        for (final t in rows) {
          evict.execute([server, t.path, t.id]);
          upsert.execute([
            server, t.id, t.path, t.size, t.modified, t.hash, t.audioHash,
            t.hashV, t.albumId, t.artistId, t.art, t.createdAt, t.title,
            t.artist, t.album, t.track, t.disc, t.year, t.duration, t.format,
            jsonEncode(t.genres), t.rating, rev,
          ]);
        }
      });
    } finally {
      evict.close();
      upsert.close();
    }
  }

  /// Removes every row of [server] the manifest at [rev] did not list, and
  /// returns their paths — the mirror engine's deletion list.
  List<String> pruneUnseen(String server, String rev) {
    final r = _db.select(
        'DELETE FROM remote_tracks WHERE server = ? '
        'AND (seen_rev IS NULL OR seen_rev <> ?) RETURNING path',
        [server, rev]);
    return [for (final row in r) row['path'] as String];
  }

  int remoteCount(String server) => _db.select(
      'SELECT COUNT(*) AS n FROM remote_tracks WHERE server = ?',
      [server]).first['n'] as int;

  RemoteTrack? remoteTrack(String server, String path) {
    final r = _db.select(
        'SELECT * FROM remote_tracks WHERE server = ? AND path = ?',
        [server, path]);
    return r.isEmpty ? null : RemoteTrack.fromRow(r.first);
  }

  List<RemoteTrack> remoteTracks(String server) => [
        for (final r in _db.select(
            'SELECT * FROM remote_tracks WHERE server = ? ORDER BY id', [server]))
          RemoteTrack.fromRow(r)
      ];

  // ── the small lists: albums / artists / genres / playlists / rated ─────

  void replaceAlbums(String server, Iterable<AlbumRow> albums) =>
      _replace(server, 'remote_albums', () {
        final ins = _db.prepare(
            'INSERT OR REPLACE INTO remote_albums (server, name, album_artist, year, art) '
            'VALUES (?, ?, ?, ?, ?)');
        try {
          for (final a in albums) {
            ins.execute([server, a.name, a.albumArtist, a.year, a.art]);
          }
        } finally {
          ins.close();
        }
      });

  void replaceArtists(String server, Iterable<String> names) =>
      _replace(server, 'remote_artists', () {
        final ins = _db.prepare(
            'INSERT OR REPLACE INTO remote_artists (server, name) VALUES (?, ?)');
        try {
          for (final n in names) {
            ins.execute([server, n]);
          }
        } finally {
          ins.close();
        }
      });

  void replaceGenres(String server, Map<String, int> counts) =>
      _replace(server, 'remote_genres', () {
        final ins = _db.prepare(
            'INSERT OR REPLACE INTO remote_genres (server, name, track_count) '
            'VALUES (?, ?, ?)');
        try {
          counts.forEach((n, c) => ins.execute([server, n, c]));
        } finally {
          ins.close();
        }
      });

  void replacePlaylists(String server, Iterable<PlaylistRow> playlists) =>
      transaction(() {
        _db.execute(
            'DELETE FROM remote_playlist_items WHERE server = ?', [server]);
        _db.execute('DELETE FROM remote_playlists WHERE server = ?', [server]);
        final pl = _db.prepare(
            'INSERT INTO remote_playlists (server, id, name) VALUES (?, ?, ?)');
        final item = _db.prepare(
            'INSERT INTO remote_playlist_items (server, playlist_id, pos, path) '
            'VALUES (?, ?, ?, ?)');
        try {
          for (final p in playlists) {
            pl.execute([server, p.id, p.name]);
            for (var i = 0; i < p.paths.length; i++) {
              item.execute([server, p.id, i, p.paths[i]]);
            }
          }
        } finally {
          pl.close();
          item.close();
        }
      });

  void replaceRated(String server, Map<String, int> ratingByPath) =>
      _replace(server, 'remote_rated', () {
        final ins = _db.prepare(
            'INSERT OR REPLACE INTO remote_rated (server, path, rating) '
            'VALUES (?, ?, ?)');
        try {
          ratingByPath.forEach((p, r) => ins.execute([server, p, r]));
        } finally {
          ins.close();
        }
      });

  void _replace(String server, String table, void Function() fill) =>
      transaction(() {
        _db.execute('DELETE FROM $table WHERE server = ?', [server]);
        fill();
      });

  // ── local files ───────────────────────────────────────────────────────

  LocalFile? localFile(String server, String path,
      {String quality = 'original'}) {
    final r = _db.select(
        'SELECT * FROM local_files WHERE server = ? AND path = ? AND quality = ?',
        [server, path, quality]);
    return r.isEmpty ? null : LocalFile.fromRow(r.first);
  }

  /// Rows for [paths], keyed by path. Chunked so a whole-album or
  /// whole-listing lookup never trips SQLite's bound-variable limit.
  Map<String, LocalFile> localFiles(String server, Iterable<String> paths,
      {String quality = 'original'}) {
    final out = <String, LocalFile>{};
    final list = paths.toList();
    const chunk = 500;
    for (var i = 0; i < list.length; i += chunk) {
      final part = list.sublist(i, i + chunk > list.length ? list.length : i + chunk);
      final marks = List.filled(part.length, '?').join(',');
      for (final r in _db.select(
          'SELECT * FROM local_files WHERE server = ? AND quality = ? '
          'AND path IN ($marks)',
          [server, quality, ...part])) {
        out[r['path'] as String] = LocalFile.fromRow(r);
      }
    }
    return out;
  }

  /// `local_path` is stored normalised (`p.normalize`): the app builds
  /// download paths with '/' on every platform, so on Windows they arrive
  /// with mixed separators, and the prefix matches below need one form.
  void upsertLocal(LocalFile f) => _db.execute('''
      INSERT INTO local_files (server, path, quality, local_path, size, mtime, hash,
        state, origin, verified_at, error)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT (server, path, quality) DO UPDATE SET
        local_path = excluded.local_path, size = excluded.size, mtime = excluded.mtime,
        hash = excluded.hash, state = excluded.state, origin = excluded.origin,
        verified_at = excluded.verified_at, error = excluded.error
      ''', [
        f.server, f.path, f.quality, p.normalize(f.localPath), f.size, f.mtime,
        f.hash, f.state, f.origin, f.verifiedAt, f.error,
      ]);

  /// Batched [upsertLocal] in one transaction (the import walk).
  void upsertLocals(Iterable<LocalFile> files) =>
      transaction(() => files.forEach(upsertLocal));

  /// Every local-copy row of [server] — the planner's input.
  List<LocalFile> localFilesAll(String server) => [
        for (final r in _db.select(
            'SELECT * FROM local_files WHERE server = ? ORDER BY path', [server]))
          LocalFile.fromRow(r)
      ];

  void markState(String server, String path, String state,
          {String quality = 'original', String? error}) =>
      _db.execute(
          'UPDATE local_files SET state = ?, error = ? '
          'WHERE server = ? AND path = ? AND quality = ?',
          [state, error, server, path, quality]);

  void removeLocal(String server, String path, {String quality = 'original'}) =>
      _db.execute(
          'DELETE FROM local_files WHERE server = ? AND path = ? AND quality = ?',
          [server, path, quality]);

  /// Re-labels who owns a copy — e.g. an auto-cached track the user then
  /// downloaded explicitly becomes `manual` and can no longer be evicted.
  /// With [ifOrigin], only rows currently of that origin change.
  void setOrigin(String server, String path, String origin,
          {String? ifOrigin, String quality = 'original'}) =>
      _db.execute(
          'UPDATE local_files SET origin = ? WHERE server = ? AND path = ? '
          'AND quality = ? AND (? IS NULL OR origin = ?)',
          [origin, server, path, quality, ifOrigin, ifOrigin]);

  /// Forgets the row whose on-disk file is [localPath] (a user deleted it).
  /// [server] null = whichever server it belonged to.
  void removeLocalByLocalPath(String? server, String localPath) => _db.execute(
      'DELETE FROM local_files WHERE (? IS NULL OR server = ?) AND local_path = ?',
      [server, server, p.normalize(localPath)]);

  /// Forgets every row whose file lives under [dirPath] (a folder was
  /// deleted). Prefix-matched on the stored (normalised) absolute path.
  void removeLocalUnder(String? server, String dirPath) {
    final base = p.normalize(dirPath);
    final sep = base.endsWith('/') || base.endsWith('\\') ? '' : p.separator;
    final prefix = '$base$sep';
    _db.execute(
        'DELETE FROM local_files WHERE (? IS NULL OR server = ?) '
        'AND substr(local_path, 1, ?) = ?',
        [server, server, prefix.length, prefix]);
  }

  int localCount(String server, {String? origin, String? state}) => _db.select(
      'SELECT COUNT(*) AS n FROM local_files WHERE server = ? '
      'AND (? IS NULL OR origin = ?) AND (? IS NULL OR state = ?)',
      [server, origin, origin, state, state]).first['n'] as int;

  /// Bytes on disk for [server]'s rows (by [origin] when given), from the
  /// sizes recorded at verification time.
  int localBytes(String server, {String? origin}) => _db.select(
      'SELECT COALESCE(SUM(size), 0) AS b FROM local_files WHERE server = ? '
      "AND state = 'ok' AND (? IS NULL OR origin = ?)",
      [server, origin, origin]).first['b'] as int;

  /// Rows whose last transfer failed, with their error, for the status
  /// screen.
  List<LocalFile> localFailed(String server) => [
        for (final r in _db.select(
            "SELECT * FROM local_files WHERE server = ? AND state = 'failed' "
            'ORDER BY path',
            [server]))
          LocalFile.fromRow(r)
      ];

  /// Oldest-first by verification time — the keep-queue-offline eviction
  /// order once that ledger moves here (A8).
  List<LocalFile> localByOrigin(String server, String origin) => [
        for (final r in _db.select(
            'SELECT * FROM local_files WHERE server = ? AND origin = ? '
            'ORDER BY verified_at, rowid',
            [server, origin]))
          LocalFile.fromRow(r)
      ];

  // ── subscriptions (what to keep) ──────────────────────────────────────

  List<Subscription> subscriptionsFor(String server) => [
        for (final r in _db.select(
            'SELECT * FROM subscriptions WHERE server = ? ORDER BY id', [server]))
          Subscription.fromRow(r)
      ];

  /// Adds (or re-enables) a rule and returns its id.
  int addSubscription(Subscription s) {
    _db.execute('''
      INSERT INTO subscriptions (server, kind, key, quality, wifi_only, enabled)
      VALUES (?, ?, ?, ?, ?, 1)
      ON CONFLICT (server, kind, key, quality) DO UPDATE SET
        wifi_only = excluded.wifi_only, enabled = 1
      ''', [s.server, s.kind, s.key, s.quality, s.wifiOnly ? 1 : 0]);
    return _db.select(
        'SELECT id FROM subscriptions WHERE server = ? AND kind = ? AND key = ? '
        'AND quality = ?',
        [s.server, s.kind, s.key, s.quality]).first['id'] as int;
  }

  void removeSubscription(int id) =>
      _db.execute('DELETE FROM subscriptions WHERE id = ?', [id]);

  /// Rewrites the required-by edges of one rule after expansion.
  void setSubscriptionFiles(int id, String server, Iterable<String> paths) =>
      transaction(() {
        _db.execute(
            'DELETE FROM subscription_files WHERE subscription_id = ?', [id]);
        final ins = _db.prepare(
            'INSERT OR IGNORE INTO subscription_files (subscription_id, server, path) '
            'VALUES (?, ?, ?)');
        try {
          for (final p in paths) {
            ins.execute([id, server, p]);
          }
        } finally {
          ins.close();
        }
      });

  /// How many enabled rules still pin [path] — zero means the mirror may
  /// let it go.
  int requiredBy(String server, String path) => _db.select(
      'SELECT COUNT(*) AS n FROM subscription_files sf '
      'JOIN subscriptions s ON s.id = sf.subscription_id '
      'WHERE sf.server = ? AND sf.path = ? AND s.enabled = 1',
      [server, path]).first['n'] as int;

  /// Every path some enabled rule pins.
  Set<String> wantedPaths(String server) => {
        for (final r in _db.select(
            'SELECT DISTINCT sf.path FROM subscription_files sf '
            'JOIN subscriptions s ON s.id = sf.subscription_id '
            'WHERE sf.server = ? AND s.enabled = 1',
            [server]))
          r['path'] as String
      };

  // ── runs ──────────────────────────────────────────────────────────────

  int recordRun(SyncRun r) {
    _db.execute('''
      INSERT INTO sync_runs (server, started, finished, trigger, downloaded, replaced,
        renamed, trashed, unchanged, failed, conflicts, bytes, error)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
      r.server, r.started, r.finished, r.trigger, r.downloaded, r.replaced,
      r.renamed, r.trashed, r.unchanged, r.failed, r.conflicts, r.bytes, r.error,
    ]);
    return _db.lastInsertRowId;
  }

  SyncRun? lastRun(String server) {
    final r = _db.select(
        'SELECT * FROM sync_runs WHERE server = ? ORDER BY started DESC, id DESC LIMIT 1',
        [server]);
    return r.isEmpty ? null : SyncRun.fromRow(r.first);
  }

  // ── offline browse ────────────────────────────────────────────────────

  List<AlbumRow> albums(String server) => [
        for (final r in _db.select(
            'SELECT * FROM remote_albums WHERE server = ? ORDER BY name COLLATE NOCASE',
            [server]))
          AlbumRow.fromRow(r)
      ];

  List<String> artists(String server) => [
        for (final r in _db.select(
            'SELECT name FROM remote_artists WHERE server = ? ORDER BY name COLLATE NOCASE',
            [server]))
          r['name'] as String
      ];

  /// Albums credited to [artist]: as the album artist, or holding a track
  /// by them — close to `db/artists-albums`, which unions the same sources.
  List<AlbumRow> artistAlbums(String server, String artist) => [
        for (final r in _db.select(
            'SELECT * FROM remote_albums WHERE server = ? AND (album_artist = ? '
            'OR name IN (SELECT album FROM remote_tracks WHERE server = ? '
            'AND artist = ? AND album IS NOT NULL)) '
            'ORDER BY year, name COLLATE NOCASE',
            [server, artist, server, artist]))
          AlbumRow.fromRow(r)
      ];

  /// One level of the library as a folder tree: the sub-folders and the
  /// tracks directly under [dir] (a data path such as `/music/Artist`; `/`
  /// lists the libraries). Derived from the paths alone, so it works for
  /// every server the manifest has been pulled for.
  ({List<String> dirs, List<RemoteTrack> files}) directoryListing(
      String server, String dir) {
    final prefix = dir.endsWith('/') ? dir : '$dir/';
    final n = prefix.length;
    final dirs = <String>{};
    final files = <RemoteTrack>[];
    // Prefix by substr, not LIKE: paths may contain '%' and '_'.
    for (final r in _db.select(
        'SELECT * FROM remote_tracks WHERE server = ? AND substr(path, 1, ?) = ? '
        'ORDER BY path',
        [server, n, prefix])) {
      final rest = (r['path'] as String).substring(n);
      final slash = rest.indexOf('/');
      if (slash < 0) {
        files.add(RemoteTrack.fromRow(r));
      } else {
        dirs.add(rest.substring(0, slash));
      }
    }
    return (dirs: dirs.toList(), files: files);
  }

  /// Every track under [dir], in path order (the folder "play / download
  /// all" listing).
  List<RemoteTrack> tracksUnder(String server, String dir) {
    final prefix = dir.endsWith('/') ? dir : '$dir/';
    return [
      for (final r in _db.select(
          'SELECT * FROM remote_tracks WHERE server = ? AND substr(path, 1, ?) = ? '
          'ORDER BY path',
          [server, prefix.length, prefix]))
        RemoteTrack.fromRow(r)
    ];
  }

  /// Tracks of the album named [album], in disc / track / path order — the
  /// same identity `db/album-songs` uses.
  List<RemoteTrack> albumSongs(String server, String album) => [
        for (final r in _db.select(
            'SELECT * FROM remote_tracks WHERE server = ? AND album = ? '
            'ORDER BY disc, track, path',
            [server, album]))
          RemoteTrack.fromRow(r)
      ];

  /// Prefix search over title / artist / album / path, best match first.
  /// Each whitespace-separated term must match; quotes in the input are
  /// escaped, never interpreted.
  List<RemoteTrack> search(String server, String query, {int limit = 50}) {
    final q = ftsQuery(query);
    if (q.isEmpty) return const [];
    return [
      for (final r in _db.select(
          'SELECT rt.* FROM tracks_fts f '
          'JOIN remote_tracks rt ON rt.rt_id = f.rowid '
          'WHERE tracks_fts MATCH ? AND rt.server = ? '
          'ORDER BY f.rank LIMIT ?',
          [q, server, limit]))
        RemoteTrack.fromRow(r)
    ];
  }

  /// The FTS5 MATCH expression for a user query: every term quoted (so FTS
  /// syntax in the input is inert) and prefix-matched.
  static String ftsQuery(String raw) => raw
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .map((t) => '"${t.replaceAll('"', '""')}"*')
      .join(' ');

  // ── the other lists (A5) ──────────────────────────────────────────────

  List<GenreRow> genres(String server) => [
        for (final r in _db.select(
            'SELECT name, track_count FROM remote_genres WHERE server = ? '
            'ORDER BY name COLLATE NOCASE',
            [server]))
          GenreRow(
              name: r['name'] as String,
              trackCount: (r['track_count'] as int?) ?? 0)
      ];

  /// The playlists by name, without their tracks.
  List<PlaylistRow> playlists(String server) => [
        for (final r in _db.select(
            'SELECT id, name FROM remote_playlists WHERE server = ? '
            'ORDER BY name COLLATE NOCASE',
            [server]))
          PlaylistRow(id: r['id'] as String, name: r['name'] as String)
      ];

  /// The slots of playlist [id] in order, each with its track when the
  /// manifest knows the path — the shape `playlist/load` returns.
  List<PlaylistItem> playlistItems(String server, String id) => [
        for (final r in _db.select(
            'SELECT i.pos AS item_pos, i.path AS item_path, rt.* '
            'FROM remote_playlist_items i '
            'LEFT JOIN remote_tracks rt ON rt.server = i.server AND rt.path = i.path '
            'WHERE i.server = ? AND i.playlist_id = ? ORDER BY i.pos',
            [server, id]))
          (
            pos: r['item_pos'] as int,
            path: r['item_path'] as String,
            track: r['rt_id'] == null ? null : RemoteTrack.fromRow(r),
          )
      ];

  /// The tracks the caller rated, best first — `db/rated`'s order. The
  /// rating comes from the rated list, which is fresher than the manifest's
  /// lite block.
  List<RemoteTrack> rated(String server) => [
        for (final r in _db.select(
            'SELECT rt.*, rr.rating AS user_rating FROM remote_rated rr '
            'JOIN remote_tracks rt ON rt.server = rr.server AND rt.path = rr.path '
            'WHERE rr.server = ? AND rr.rating > 0 '
            'ORDER BY rr.rating DESC, rt.path',
            [server]))
          RemoteTrack.fromRow(r).withRating(r['user_rating'] as int?)
      ];

  /// The newest additions — `db/recent/added`'s order.
  List<RemoteTrack> recent(String server, {int limit = 100}) => [
        for (final r in _db.select(
            'SELECT * FROM remote_tracks WHERE server = ? '
            'ORDER BY created_at DESC, id DESC LIMIT ?',
            [server, limit]))
          RemoteTrack.fromRow(r)
      ];

  /// Artists whose name contains [query] (case-insensitive), for the
  /// grouped search offline. [albumsMatching] is the same over albums.
  List<String> artistsMatching(String server, String query,
          {int limit = 50}) =>
      [
        for (final r in _db.select(
            "SELECT name FROM remote_artists WHERE server = ? "
            "AND name LIKE ? ESCAPE '\\' ORDER BY name COLLATE NOCASE LIMIT ?",
            [server, _like(query), limit]))
          r['name'] as String
      ];

  List<AlbumRow> albumsMatching(String server, String query,
          {int limit = 50}) =>
      [
        for (final r in _db.select(
            "SELECT * FROM remote_albums WHERE server = ? "
            "AND name LIKE ? ESCAPE '\\' ORDER BY name COLLATE NOCASE LIMIT ?",
            [server, _like(query), limit]))
          AlbumRow.fromRow(r)
      ];

  static String _like(String q) =>
      '%${q.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_')}%';

  // ── the caller's own writes (mirrored so the offline copy shows them) ──

  /// Records the caller's rating for [path] in the rated list and on the
  /// track's row; null or 0 clears it.
  void setRating(String server, String path, int? rating) => transaction(() {
        final r = rating == null || rating <= 0 ? null : rating;
        if (r == null) {
          _db.execute('DELETE FROM remote_rated WHERE server = ? AND path = ?',
              [server, path]);
        } else {
          _db.execute(
              'INSERT OR REPLACE INTO remote_rated (server, path, rating) '
              'VALUES (?, ?, ?)',
              [server, path, r]);
        }
        _db.execute(
            'UPDATE remote_tracks SET rating = ? WHERE server = ? AND path = ?',
            [r, server, path]);
      });

  /// Creates playlist [name] when it does not exist. Playlists are keyed by
  /// name: the server puts no id on the wire.
  void createPlaylist(String server, String name) => _db.execute(
      'INSERT OR IGNORE INTO remote_playlists (server, id, name) VALUES (?, ?, ?)',
      [server, name, name]);

  /// Appends [path] to playlist [name], creating it first like
  /// `playlist/add-song` does.
  void addPlaylistItem(String server, String name, String path) =>
      transaction(() {
        createPlaylist(server, name);
        final next = _db.select(
            'SELECT COALESCE(MAX(pos), -1) + 1 AS n FROM remote_playlist_items '
            'WHERE server = ? AND playlist_id = ?',
            [server, name]).first['n'] as int;
        _db.execute(
            'INSERT INTO remote_playlist_items (server, playlist_id, pos, path) '
            'VALUES (?, ?, ?, ?)',
            [server, name, next, path]);
      });

  /// Replaces the tracks of playlist [name] (`playlist/save`).
  void savePlaylist(String server, String name, List<String> paths) =>
      transaction(() {
        createPlaylist(server, name);
        _db.execute(
            'DELETE FROM remote_playlist_items WHERE server = ? AND playlist_id = ?',
            [server, name]);
        final ins = _db.prepare(
            'INSERT INTO remote_playlist_items (server, playlist_id, pos, path) '
            'VALUES (?, ?, ?, ?)');
        try {
          for (var i = 0; i < paths.length; i++) {
            ins.execute([server, name, i, paths[i]]);
          }
        } finally {
          ins.close();
        }
      });

  void renamePlaylist(String server, String oldName, String newName) =>
      transaction(() {
        _db.execute(
            'UPDATE remote_playlists SET id = ?, name = ? WHERE server = ? AND id = ?',
            [newName, newName, server, oldName]);
        _db.execute(
            'UPDATE remote_playlist_items SET playlist_id = ? '
            'WHERE server = ? AND playlist_id = ?',
            [newName, server, oldName]);
      });

  void deletePlaylist(String server, String name) => transaction(() {
        _db.execute(
            'DELETE FROM remote_playlist_items WHERE server = ? AND playlist_id = ?',
            [server, name]);
        _db.execute('DELETE FROM remote_playlists WHERE server = ? AND id = ?',
            [server, name]);
      });

  // ── outbox ────────────────────────────────────────────────────────────

  /// Queues a write for replay; returns its id. Entries replay in id order,
  /// so a later write to the same thing wins.
  int enqueue(String server, String op, Map<String, dynamic> payload,
      {required int created}) {
    _db.execute(
        'INSERT INTO outbox (server, op, payload, created) VALUES (?, ?, ?, ?)',
        [server, op, jsonEncode(payload), created]);
    return _db.lastInsertRowId;
  }

  List<OutboxEntry> outbox(String server) => [
        for (final r in _db.select(
            'SELECT * FROM outbox WHERE server = ? ORDER BY id', [server]))
          OutboxEntry.fromRow(r)
      ];

  int outboxCount(String server) => _db.select(
      'SELECT COUNT(*) AS n FROM outbox WHERE server = ?',
      [server]).first['n'] as int;

  void outboxDone(int id) => _db.execute('DELETE FROM outbox WHERE id = ?', [id]);

  void outboxFailed(int id, String error) => _db.execute(
      'UPDATE outbox SET attempts = attempts + 1, last_error = ? WHERE id = ?',
      [error, id]);

  // ── server removal ────────────────────────────────────────────────────

  /// Drops everything the index knows about [server]. Files on disk are the
  /// caller's business (Manage Server already asks about them).
  void removeServer(String server) => transaction(() {
        for (final t in const [
          'subscription_files', 'subscriptions', 'sync_runs', 'local_files',
          'remote_rated', 'remote_playlist_items', 'remote_playlists',
          'remote_genres', 'remote_artists', 'remote_albums', 'remote_tracks',
          'outbox', 'meta',
        ]) {
          _db.execute('DELETE FROM $t WHERE server = ?', [server]);
        }
      });
}
