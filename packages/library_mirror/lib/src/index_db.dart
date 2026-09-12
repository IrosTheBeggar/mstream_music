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
      if (v < 1) {
        for (final s in schemaStatements()) {
          db.execute(s);
        }
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

  // ── server removal ────────────────────────────────────────────────────

  /// Drops everything the index knows about [server]. Files on disk are the
  /// caller's business (Manage Server already asks about them).
  void removeServer(String server) => transaction(() {
        for (final t in const [
          'subscription_files', 'subscriptions', 'sync_runs', 'local_files',
          'remote_rated', 'remote_playlist_items', 'remote_playlists',
          'remote_genres', 'remote_artists', 'remote_albums', 'remote_tracks',
          'meta',
        ]) {
          _db.execute('DELETE FROM $t WHERE server = ?', [server]);
        }
      });
}
