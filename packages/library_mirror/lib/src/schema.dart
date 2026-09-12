/// On-disk schema of the index. Bump [kSchemaVersion] with a migration step
/// in `LibraryIndex.migrate` whenever the shape changes; an index newer than
/// the running app is refused rather than guessed at.
///
/// Every table carries `server` = the app's `Server.localname`, so removing a
/// server is one `DELETE` per table. Albums and artists are keyed by NAME
/// because that is how the server's `db/albums` / `db/artists` /
/// `db/album-songs` identify them (no ids on the wire); `album_id` /
/// `artist_id` from the manifest are kept for exact grouping.
///
/// `remote_tracks` has a surrogate `rt_id INTEGER PRIMARY KEY` instead of a
/// composite key: the FTS5 external-content table addresses rows by it, and an
/// implicit rowid on a WITHOUT-INTEGER-PRIMARY-KEY table may change on VACUUM,
/// which would silently desync the search index.
const int kSchemaVersion = 1;

const List<String> _v1 = [
  '''
  CREATE TABLE meta (
    server TEXT NOT NULL,
    key    TEXT NOT NULL,
    value  TEXT,
    PRIMARY KEY (server, key)
  )''',
  '''
  CREATE TABLE remote_tracks (
    rt_id      INTEGER PRIMARY KEY,
    server     TEXT NOT NULL,
    id         INTEGER NOT NULL,
    path       TEXT NOT NULL,           -- '/<vpath>/<rel>', the app's data path
    size       INTEGER,
    modified   INTEGER,                 -- server mtime, epoch ms
    hash       TEXT,
    audio_hash TEXT,
    hash_v     INTEGER,
    album_id   INTEGER,
    artist_id  INTEGER,
    art        TEXT,
    created_at TEXT,
    title      TEXT,
    artist     TEXT,
    album      TEXT,
    track      INTEGER,
    disc       INTEGER,
    year       INTEGER,
    duration   REAL,
    format     TEXT,
    genres     TEXT NOT NULL DEFAULT '[]',   -- JSON array of names
    rating     INTEGER,                 -- the caller's own, from the lite block
    seen_rev   TEXT,                    -- manifest revision that last listed it
    UNIQUE (server, id),
    UNIQUE (server, path)
  )''',
  'CREATE INDEX rt_album      ON remote_tracks (server, album)',
  'CREATE INDEX rt_artist     ON remote_tracks (server, artist)',
  'CREATE INDEX rt_audio_hash ON remote_tracks (server, audio_hash)',
  'CREATE INDEX rt_created    ON remote_tracks (server, created_at)',
  '''
  CREATE TABLE remote_albums (
    server       TEXT NOT NULL,
    name         TEXT NOT NULL,
    album_artist TEXT,
    year         INTEGER,
    art          TEXT,
    PRIMARY KEY (server, name)
  )''',
  '''
  CREATE TABLE remote_artists (
    server TEXT NOT NULL,
    name   TEXT NOT NULL,
    PRIMARY KEY (server, name)
  )''',
  '''
  CREATE TABLE remote_genres (
    server      TEXT NOT NULL,
    name        TEXT NOT NULL,
    track_count INTEGER,
    PRIMARY KEY (server, name)
  )''',
  '''
  CREATE TABLE remote_playlists (
    server TEXT NOT NULL,
    id     TEXT NOT NULL,
    name   TEXT NOT NULL,
    PRIMARY KEY (server, id)
  )''',
  '''
  CREATE TABLE remote_playlist_items (
    server      TEXT NOT NULL,
    playlist_id TEXT NOT NULL,
    pos         INTEGER NOT NULL,
    path        TEXT NOT NULL,
    PRIMARY KEY (server, playlist_id, pos)
  )''',
  '''
  CREATE TABLE remote_rated (
    server TEXT NOT NULL,
    path   TEXT NOT NULL,
    rating INTEGER,
    PRIMARY KEY (server, path)
  )''',
  '''
  CREATE TABLE local_files (
    server      TEXT NOT NULL,
    path        TEXT NOT NULL,
    quality     TEXT NOT NULL DEFAULT 'original',
    local_path  TEXT NOT NULL,
    size        INTEGER,
    mtime       INTEGER,                -- epoch ms
    hash        TEXT,
    state       TEXT NOT NULL,          -- pending|downloading|ok|stale|trashed|failed
    origin      TEXT NOT NULL,          -- mirror|manual|auto|external
    verified_at INTEGER,                -- epoch ms
    error       TEXT,
    PRIMARY KEY (server, path, quality)
  )''',
  'CREATE INDEX lf_origin     ON local_files (server, origin, verified_at)',
  'CREATE INDEX lf_local_path ON local_files (server, local_path)',
  '''
  CREATE TABLE subscriptions (
    id        INTEGER PRIMARY KEY,
    server    TEXT NOT NULL,
    kind      TEXT NOT NULL,
    key       TEXT NOT NULL,
    quality   TEXT NOT NULL DEFAULT 'original',
    wifi_only INTEGER NOT NULL DEFAULT 0,
    enabled   INTEGER NOT NULL DEFAULT 1,
    last_run  INTEGER,
    UNIQUE (server, kind, key, quality)
  )''',
  '''
  CREATE TABLE subscription_files (      -- required-by edges
    subscription_id INTEGER NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
    server          TEXT NOT NULL,
    path            TEXT NOT NULL,
    PRIMARY KEY (subscription_id, server, path)
  )''',
  'CREATE INDEX sf_path ON subscription_files (server, path)',
  '''
  CREATE TABLE sync_runs (
    id         INTEGER PRIMARY KEY,
    server     TEXT NOT NULL,
    started    INTEGER NOT NULL,        -- epoch ms
    finished   INTEGER,
    trigger    TEXT,
    downloaded INTEGER NOT NULL DEFAULT 0,
    replaced   INTEGER NOT NULL DEFAULT 0,
    renamed    INTEGER NOT NULL DEFAULT 0,
    trashed    INTEGER NOT NULL DEFAULT 0,
    unchanged  INTEGER NOT NULL DEFAULT 0,
    failed     INTEGER NOT NULL DEFAULT 0,
    conflicts  INTEGER NOT NULL DEFAULT 0,
    bytes      INTEGER NOT NULL DEFAULT 0,
    error      TEXT
  )''',
  'CREATE INDEX sr_server ON sync_runs (server, started)',
  // External-content FTS over remote_tracks; the three triggers keep it in
  // step. tokenize=unicode61 folds case and diacritics for prefix search.
  '''
  CREATE VIRTUAL TABLE tracks_fts USING fts5(
    title, artist, album, path,
    content='remote_tracks', content_rowid='rt_id', tokenize='unicode61'
  )''',
  '''
  CREATE TRIGGER rt_ai AFTER INSERT ON remote_tracks BEGIN
    INSERT INTO tracks_fts (rowid, title, artist, album, path)
      VALUES (new.rt_id, new.title, new.artist, new.album, new.path);
  END''',
  '''
  CREATE TRIGGER rt_ad AFTER DELETE ON remote_tracks BEGIN
    INSERT INTO tracks_fts (tracks_fts, rowid, title, artist, album, path)
      VALUES ('delete', old.rt_id, old.title, old.artist, old.album, old.path);
  END''',
  '''
  CREATE TRIGGER rt_au AFTER UPDATE ON remote_tracks BEGIN
    INSERT INTO tracks_fts (tracks_fts, rowid, title, artist, album, path)
      VALUES ('delete', old.rt_id, old.title, old.artist, old.album, old.path);
    INSERT INTO tracks_fts (rowid, title, artist, album, path)
      VALUES (new.rt_id, new.title, new.artist, new.album, new.path);
  END''',
];

/// Statements that take an empty database to [kSchemaVersion].
List<String> schemaStatements() => List.unmodifiable(_v1);
