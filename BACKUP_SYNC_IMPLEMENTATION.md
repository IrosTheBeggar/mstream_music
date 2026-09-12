# Backup & sync — implementation plan (Syncthing excluded)

Work packages for `BACKUP_SYNC_PLAN.md` §4.1–4.3, §4.5, §5 and phases 0–4,
6, 7. **Excluded:** §4.4 Tier B/C (Syncthing detection, events, pairing) =
phase 5. Tier A (the per-server *mirror root*) is kept because it contains no
Syncthing code — it is a folder any tool can fill; drop A1 if that is not
wanted.

Conventions assumed throughout: one worktree per PR off `master` (server PRs
in `mStream`); one visual change per PR; a capability is a ping flag, never a
probe; new strings land in all nine ARB files; lean verification (analyzer +
tests + one device smoke); no repo-wide format.

**Two decisions this doc makes that the design doc left open**

1. **`package:sqlite3` + `sqlite3_flutter_libs`, not drift.** The repo has no
   codegen pipeline (no build_runner), the schema is small, and the server
   side already lives in raw SQL. drift can be layered on the same file later.
2. **The manifest carries the lite metadata block + genres, not only hashes.**
   Offline lists need title/artist/album for every row, and fetching them via
   `db/metadata/batch` would be thousands of calls. ~350 B/row → 25k tracks ≈
   9 MB raw / ~2 MB gzipped per full pull, and a 304 when nothing changed.
   This supersedes the entry list in design §5.1.

---

## 0. PR map

| ID | Repo | Title | Depends on | Ships UI? | Size |
|---|---|---|---|---|---|
| S1 | mStream | `sync/manifest` endpoint + `sync` ping flag — **[mStream #984](https://github.com/IrosTheBeggar/mStream/pull/984)** | — | no | 🟢 2d |
| A1 | app | Mirror root per server (Tier A) — **[#173](https://github.com/IrosTheBeggar/mstream_music/pull/173)** | — | yes (picker row) | 🟢 1–2d |
| A2 | app | `packages/library_mirror`: index DB + import of existing downloads — **[#174](https://github.com/IrosTheBeggar/mstream_music/pull/174)** (`package:sqlite3` 3.x build hook, no flutter-libs package) | — | no | 🟡 2–3d |
| A3 | app | Mirror engine + "Keep a full copy" in Manage Server | S1, A2 | yes (one section) | 🔴 5–7d |
| A4 | app | Offline browsing: albums, artists, album songs, art cache | A3 | yes (offline chip) | 🟡 3–4d |
| A5 | app | Offline: playlists, rated, genres, recent, search (FTS5) | A4 | yes (search offline) | 🟡 3–4d |
| A6a | app | Rules: album / artist "Keep offline" | A3 | yes | 🟡 2–3d |
| A6b | app | Rules: playlist + rated | A6a, A5 | yes | 🟡 1–2d |
| A7 | app | Transcoded quality tier for entity rules | A6a | yes (quality picker) | 🟡 2–3d |
| A8 | app | Fold the keep-queue-offline ledger into the index | A3 | no | 🟡 1–2d |
| S2 | mStream | Tombstones + `since` deltas | S1 | no | 🟡 2–3d |
| A9 | app | Consume deltas | S2, A3 | no | 🟢 1d |
| S3 | mStream | Device upload libraries | — | admin toggle | 🟡 2d |
| A10 | app | Back up a desktop folder *to* the server | S3, A2 | yes | 🟡 3–5d |
| A11 | app | Headless `mstream_mirror` CLI | A3 | no | 🟡 2–3d |

Critical path: **S1 ∥ A2 → A3 → A4 → A5.** A1 is independent and the
cheapest visible win. A8, S2/A9, S3/A10 and A11 are optional and can trail
indefinitely. The server release with S1 precedes the app release with A3
(the app gates strictly on the flag; an older server simply shows no
"Library copy" section).

---

## 1. S1 — server: `POST /api/v1/sync/manifest`

**Files**

- new `src/db/sync-manifest.js` — the SQL as pure functions over a db handle
  (testable with `node:sqlite` + `test/helpers/apply-migrations.mjs`).
- new `src/api/sync.js` — `setup(mstream)`: Joi validation, ETag / 304, JSON.
- `src/server.js` — import + `syncApi.setup(mstream)` next to `dbApi`.
- `src/api/playlist.js` (home of the `/api/v1/ping` handler) — `sync: true`
  beside `discoveryP2p`.
- `docs/openapi.yaml`, `CHANGELOG.md`, tests. **Not** `federation-auth.js`.

**Contract (as shipped in mStream #984 — the app implements against this)**

```
POST /api/v1/sync/manifest
{ "cursor": 0, "limit": 2000, "ignoreVPaths": [] }          // all optional
If-None-Match: "<revision>"                                  // optional; honoured on the first page only

200 { "revision": "…", "scanning": false, "next": 4812 | null,
      "entries": [ { "filepath": "music/Artist/Album/01.flac",
                     "metadata": { …the lite block: title, artist, album, album-art,
                                   year, track, disk, duration, rating, bpm,
                                   musical-key, genres, has-lyrics,
                                   has-synced-lyrics, replaygain-track },
                     "id": 4812, "file-size": 31337, "modified": 1725000000000,
                     "hash": "…", "audio-hash": "…", "hash-v": 2, "format": "flac",
                     "album-id": 12, "artist-id": 7,
                     "created-at": "2026-08-01 10:00:00" } ] }
304 (empty body)  when If-None-Match equals the current revision and no cursor was sent
```

- Entry = the same `{filepath, metadata}` row every list endpoint returns
  (`toLiteMetadata(renderMetadataObj(row))`, genres via the batched
  `enrichRowsWithGenres`), so the app parses `metadata` with the existing
  `MusicMetadata.fromServerMap`; the sync identity fields sit beside it,
  kebab-cased like the rest of the wire vocabulary. Album artist is not per
  track — it comes from `db/albums` (keyed by name), which A4 fetches anyway.
- `rating` in the lite block is the caller's own (user_metadata join), so
  offline "rated" lists need no separate call — but rating changes do not
  move the revision (see below).
- Scope: `libraryFilter(req.user, ignoreVPaths)`, exactly like `db/*`.
- Page query: `trackQuery(userId) WHERE <filter> AND t.id > ? ORDER BY t.id
  LIMIT limit + 1` — the extra row says whether a next page exists, no COUNT.
  `filepath = <vpath>/<rel>` with `\` → `/`. `next` = last id, `null` on the
  last page (a full last page still ends with `null`). `limit` 1..5000,
  default 2000.
- Revision: one indexed pass `COUNT(*), MAX(id), MAX(modified),
  COUNT(album_art_file)` over the visible set, prefixed with the library ids
  → `"<ids>:<n>:<maxId>:<maxModified>:<withArt>"`. Sent as the `ETag` on every
  response (304 included) and as `revision` in the body; compared only when
  `cursor` is absent. Moves on add / delete / mtime change / art backfill /
  scope change; returns to its old value when the set is restored. Covers
  library content only — never per-user ratings or play counts.
- `scanning: dbQueue.isScanning()` — the client downloads but never trashes
  while true (rows can be transiently absent mid-scan).
- The flag is `sync: true` in `buildFeatures()` (`src/api/server-info.js`):
  under `features` on `GET /api/` (what the app reads) and flat on
  `/api/v1/ping`.
- Compression: the existing middleware covers it; nothing to add.

**Tests** (`test/db/sync-manifest.test.mjs`): stable paging with inserts
mid-walk; filter scope + `ignoreVPaths`; path rendering for nested dirs and
backslashes; revision changes on insert / delete / mtime bump and not on a
no-op; empty visibility (`1=0`) → empty page; genres present; lite fields
equal `toLiteMetadata`. Validation errors (limit 0 / 5001, non-integer cursor).

**Acceptance:** full pull of 25k rows < 1 s locally; 304 path < 5 ms; no
other route changes.

---

## 2. A1 — app: mirror root (Tier A)

Folder contract: `<mirrorRoot>/<vpath>/<relative path>` — the download tree's
shape minus the `media/<localname>` prefix, so `mirrorRoot + item.data` is the
candidate (`data` already begins with `/<vpath>/`).

**Files**

- `lib/objects/server.dart` — `String? mirrorRoot;` persisted in JSON;
  round-trip case in `test/objects/server_test.dart`.
- `lib/singletons/file_explorer.dart` — `Future<List<String>>
  localCandidates(Server s, String dataPath)` → `[<downloadDir>/media/<localname><data>,
  <mirrorRoot><data>]` (mirror root only when set and the directory exists),
  separators normalised for Windows. The one place that knows both shapes.
- `lib/util/queue_actions.dart` `_buildServerFileMediaItemWithDir` and
  `lib/objects/display_item.dart` `recheckDownloadedIn` — first existing
  candidate wins. `lib/singletons/browser_list.dart` `_resolveDownloadBadges`
  groups by `(storageMode, storageBasePath, mirrorRoot)`.
- `lib/singletons/downloads.dart` `downloadOneFile` — the "already on disk"
  check uses the candidates, so a mirrored file is not re-downloaded into the
  app tree.
- `lib/screens/add_server.dart` — one row under the storage-mode picker:
  "Local copy folder (optional)" via `file_selector.getDirectoryPath`. Shown
  on desktop always, on Android only when `!isPlayBuild` and all-files access
  is granted (same gate as `permanent`), never on iOS.
- l10n: 3 strings × 9 ARBs.

**Tests:** candidate-path builder (Windows separators, missing root, unset
root) — pure, in `test/singletons/`.
**Smoke:** Windows release build with a robocopy'd library folder → rows show
the downloaded badge and playback logs a `file://` source; S25 `--flavor
full` with a folder under `/sdcard/Music`.

---

## 3. A2 — app: `packages/library_mirror` (index only, no UI)

Pure Dart package (`publish_to: none`, path dependency like
`wifi_lock_shim`); deps `sqlite3`, `path`, `crypto`, `meta`. The app adds
`sqlite3_flutter_libs` (bundles SQLite with FTS5 on Android / iOS / macOS /
Windows / Linux; ships armeabi-v7a, matching `ndk.abiFilters`).

**Layout**

```
packages/library_mirror/
  lib/library_mirror.dart        exports
  lib/src/schema.dart            DDL + PRAGMA user_version migrations
  lib/src/index_db.dart          LibraryIndex: open/close, upserts, queries
  lib/src/models.dart            RemoteTrack, LocalFile, Subscription, SyncRun, PlanAction
  lib/src/planner.dart           (A3) pure plan()
  lib/src/runner.dart            (A3) MirrorRunner
  lib/src/transport.dart         (A3) ManifestClient + Downloader interfaces
  bin/mstream_mirror.dart        (A11)
  test/…
```

**Schema v1.** Every table carries `server` = `Server.localname`; albums and
artists are keyed by **name** because that is how `db/albums`, `db/artists`,
`db/album-songs` and `db/artists-albums` identify them (no ids on the wire).
`album_id` / `artist_id` from the manifest are kept for exact grouping.

```sql
PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000; PRAGMA foreign_keys=ON;

CREATE TABLE meta(server TEXT, key TEXT, value TEXT, PRIMARY KEY(server, key));  -- revision, last_run, imported
CREATE TABLE remote_tracks(
  server TEXT, id INTEGER, path TEXT NOT NULL, size INTEGER, modified INTEGER,
  hash TEXT, audio_hash TEXT, hash_v INTEGER, album_id INTEGER, artist_id INTEGER, art TEXT,
  created_at TEXT, title TEXT, artist TEXT, album TEXT, album_artist TEXT,
  track INTEGER, disc INTEGER, year INTEGER, duration REAL, format TEXT,
  genres TEXT,            -- JSON array
  seen_rev TEXT,
  PRIMARY KEY(server, id));
CREATE UNIQUE INDEX rt_path   ON remote_tracks(server, path);
CREATE INDEX rt_album         ON remote_tracks(server, album);
CREATE INDEX rt_artist        ON remote_tracks(server, artist);
CREATE INDEX rt_audio_hash    ON remote_tracks(server, audio_hash);
CREATE INDEX rt_created       ON remote_tracks(server, created_at);
CREATE TABLE remote_albums(server TEXT, name TEXT, album_artist TEXT, year INTEGER, art TEXT, PRIMARY KEY(server, name));
CREATE TABLE remote_artists(server TEXT, name TEXT, PRIMARY KEY(server, name));
CREATE TABLE remote_genres(server TEXT, name TEXT, track_count INTEGER, PRIMARY KEY(server, name));
CREATE TABLE remote_playlists(server TEXT, id TEXT, name TEXT, PRIMARY KEY(server, id));
CREATE TABLE remote_playlist_items(server TEXT, playlist_id TEXT, pos INTEGER, path TEXT, PRIMARY KEY(server, playlist_id, pos));
CREATE TABLE remote_rated(server TEXT, path TEXT, rating INTEGER, PRIMARY KEY(server, path));
CREATE TABLE local_files(
  server TEXT, path TEXT, local_path TEXT NOT NULL, size INTEGER, mtime INTEGER, hash TEXT,
  state TEXT NOT NULL,                        -- pending | downloading | ok | stale | trashed | failed
  origin TEXT NOT NULL,                       -- mirror | manual | auto | external
  quality TEXT NOT NULL DEFAULT 'original',
  verified_at INTEGER, error TEXT,
  PRIMARY KEY(server, path, quality));
CREATE TABLE subscriptions(
  id INTEGER PRIMARY KEY, server TEXT, kind TEXT, key TEXT, quality TEXT DEFAULT 'original',
  wifi_only INTEGER DEFAULT 0, enabled INTEGER DEFAULT 1, last_run INTEGER,
  UNIQUE(server, kind, key, quality));
CREATE TABLE subscription_files(                -- required-by edges
  subscription_id INTEGER REFERENCES subscriptions(id) ON DELETE CASCADE,
  server TEXT, path TEXT, PRIMARY KEY(subscription_id, server, path));
CREATE TABLE sync_runs(
  id INTEGER PRIMARY KEY, server TEXT, started INTEGER, finished INTEGER, trigger TEXT,
  downloaded INTEGER, replaced INTEGER, renamed INTEGER, trashed INTEGER, unchanged INTEGER,
  failed INTEGER, conflicts INTEGER, bytes INTEGER, error TEXT);
CREATE VIRTUAL TABLE tracks_fts USING fts5(title, artist, album, path,
  content='remote_tracks', content_rowid='rowid');
-- plus the three content-sync triggers on remote_tracks (insert / delete / update)
```

`remote_tracks` keeps an implicit rowid despite the composite PK; that rowid is
the FTS content rowid.

**API surface (`LibraryIndex`)** — `open(path)`, `upsertTracks(server, rows,
rev)` (one transaction per manifest page), `pruneUnseen(server, rev)` →
deleted paths, `localFile(server, path)`, `localStates(server, paths)`,
`upsertLocal(...)`, `markState(...)`, `subscriptionsFor(server)`,
`requiredBy(server, path)`, `recordRun(SyncRun)`, `albums(server)`,
`artists(server)`, `albumSongs(server, name)`, `search(server, q)`,
`removeServer(server)`.

**App side**

- `lib/singletons/library_index.dart` — singleton opening
  `<appDataDir>/library_index.db` (next to `servers.json`: documents dir on
  mobile, App Support on the desktop branch) at boot right after
  `SettingsManager().load()`. One main-isolate connection for reads; sync runs
  open their own connection inside `Isolate.run`.
- First run: import existing downloads — walk `<downloadDir>/media/<localname>`
  per server, stat only, insert `origin=manual, state=ok, hash=NULL` inside
  `Isolate.run`. Idempotent behind `meta.imported`.
- `ServerManager.removeServer` (`lib/singletons/server_list.dart:2056`) calls
  `removeServer`.
- Failure policy: if the native library fails to load, the index is disabled
  for the session and everything falls back to today's `existsSync` path.

**Tests:** package `dart test` on `sqlite3.openInMemory()`: schema creation
+ migration from an older `user_version`; upsert idempotence; `pruneUnseen`;
FTS results after insert / update / delete; required-by counting;
`removeServer` cascade. App: the import walk against a temp dir.

---

## 4. A3 — app: mirror engine + "Keep a full copy of this library"

### 4.1 Planner (`planner.dart`, pure, exhaustively unit-tested)

```dart
Plan plan({required List<RemoteTrack> remote, required Map<String, LocalFile> local,
           required Set<String> wanted, required PlanOptions o});
class Plan { downloads, replaces, renames, trashes, conflicts, unchanged, bytesNeeded }
```

Rules (design §4.2 step 2), evaluated per path in this order:

1. Case-insensitive / NFC-normalised duplicate among `wanted` → `conflict`
   (skip both).
2. No local row, or `state != ok` → `download`.
3. `size` differs, or `|mtime − modified|` outside 2000 ms **and** not within
   2000 ms of ±3600 s → `replace` (constants copied from `worker.mjs`).
4. A local file with the same `audio_hash` (fallback `hash`) at a path absent
   from `remote` → `rename`.
5. `origin == mirror` and path absent from `remote` → `trash`, unless
   `o.scanning`.
6. `origin == mirror`, path not in `wanted`, `o.trashUnwanted` → `trash`.

`bytesNeeded` = Σ sizes of downloads + replaces (old + new for a replace).
Test matrix: each rule; DST skew; sampled-hash rows (`hashV ≥ 2` and size ≥
25 MB → size only); manual / external never trashed; scanning suppresses
trash; rename beats download; conflict pair; empty inputs.

### 4.2 Runner (`runner.dart`)

`MirrorRunner(index, ManifestClient, Downloader, Fs)` —
`Future<SyncRun> run(server, {trigger})`:

1. Manifest pages with `If-None-Match` → 304 ⇒ record `unchanged` and
   return; else upsert per page, then `pruneUnseen`.
2. Expand subscriptions → `wanted` (A3: `library` kind only — every manifest
   path under that vpath).
3. `plan()`; preflight `bytesNeeded` against free space (Windows
   `GetDiskFreeSpaceExW` and POSIX `statvfs` through the existing `ffi` dep,
   or the `disk_space_plus` package if simpler); abort with `error` when
   short.
4. Renames + trashes first (frees space). Trash = `rename()` into
   `<root>/.mstream-trash/<YYYY-MM-DD>/<path>`, copy + delete fallback across
   volumes.
5. Downloads / replaces via `Downloader.enqueue(DownloadJob)` → completion
   stream. On completion: size check; MD5 via `crypto` when `hashV` means
   full (< 25 MB); `File.setLastModified(modified)`; atomic rename from
   `.mstream-tmp-<rand>` (replace: old file to trash first); `local_files`
   `state=ok, origin=mirror`. Mismatch → `failed` + error, tmp removed.
6. Sweep trash buckets older than retention; purge stray `.mstream-tmp-*`;
   write `sync_runs`; art (A4).

Runs are serialised per server (in-memory lock); a trigger arriving mid-run
is skipped with a log line, like the server's after-scan policy.

### 4.3 App adapters

- `lib/singletons/mirror_manager.dart` — `MirrorManager` singleton: a
  `MirrorRunner` per server; schedules (2 min after start when online, every
  6 h while running, `syncNow(server)`); `Stream<MirrorStatus>` for the UI;
  defers on `connectivity_plus` "none".
- `ManifestClient` over `ApiManager.makeServerCall`, which treats any status
  > 299 as failure — add an `allow304` parameter (or a sibling call) so a 304
  returns cleanly.
- `Downloader` in `lib/singletons/downloads.dart`: `enqueueMirror(server,
  path, tmpDest, {requiresWiFi})` → `DownloadTask(group: 'mirror',
  allowPause: true, retries: 5, priority: low, headers: {'x-access-token':
  …})` (header auth for the JWT; the iroh loopback `__lt` param stays on the
  URL as today). `_onUpdate` routes `group == 'mirror'` to the runner's
  completion sink instead of the queue-patch path.
  `FileDownloader().configure([(Config.holdingQueue, (null, null, 3))])`
  caps the mirror group at three concurrent transfers without starving
  manual downloads; `(Config.checkAvailableSpace, 500)` backs up the
  preflight. The iroh tunnel proxies full HTTP semantics including Range
  (`rust/iroh_tunnel/src/lib.rs`), so pause / resume works unchanged.
- `Server` gains `int mirrorRetentionDays = 30` (persisted); subscriptions
  live in the index.
- The play-time resolver from A1 additionally consults `local_files` when the
  index is open — one indexed lookup instead of `existsSync` per row —
  and `_resolveDownloadBadges` batches through `localStates(server, paths)`.

### 4.4 UI — one section in Manage Server (`lib/screens/manage_server.dart`)

"Library copy": per vpath a switch "Keep a full copy on this device"; a
status line (`Last synced 12 min ago · 4,812 files · 31 GB · 2 errors`);
"Sync now"; retention dropdown (7 / 30 / 90 days / keep forever); on mobile
a "Wi-Fi only" switch (hidden on desktop). Tapping the error count opens a
plain list from `sync_runs.error` + failed `local_files`. The Downloads
screen is untouched. l10n: ~10 strings × 9 ARBs.

### 4.5 Verification

`flutter analyze`, `flutter test`, `dart test` in the package. Smoke against
the local test server (`storage.dbDirectory` set, two vpaths, ~200 files):
full run → files under `media/<localname>/…` carrying server mtimes; delete
a server file + rescan → local file lands in `.mstream-trash/<date>/`; edit a
tag + rescan → replaced; rename on the server + rescan → local rename with
zero bytes downloaded (`sync_runs.renamed == 1`); kill the app mid-run →
relaunch resumes without duplicates; a 260+ character path on Windows.
Devices: Windows release build; S25 `--flavor full`; Pixel_4_API_31
`--flavor play` (mirror works in app storage, no folder picker).

---

## 5. A4 — offline browsing: albums, artists, album songs, art

**Refactor first, behaviour-neutral.** `lib/singletons/library_source.dart`:

```dart
abstract class LibrarySource {
  Future<List<DisplayItem>> albums(Server s);
  Future<List<DisplayItem>> artists(Server s);
  Future<List<DisplayItem>> artistAlbums(Server s, String artist);
  Future<List<DisplayItem>> albumSongs(Server s, String? album);
  // A5: genres, genreSongs, playlists, playlistContents, rated, recentlyAdded, search
}
```

`HttpLibrarySource` = the mapping bodies lifted verbatim from
`ApiManager.getAlbums / getArtists / getArtistAlbums / fetchAlbumSongs`; the
`ApiManager` methods shrink to `source(s).albums(s)` + label +
`addListToStack`. `LocalLibrarySource` maps index rows to the same
`DisplayItem` shapes (`type 'album'` + `altAlbumArt`; `type 'file'` with `data
'/<path>'` and a `MusicMetadata` built by a new `MusicMetadata.fromIndexRow`).
Artist → albums is `SELECT DISTINCT album FROM remote_tracks WHERE artist = ?
OR album_artist = ?` — close to `db/artists-albums`, not identical; accepted
and labelled by the offline chip.

**Index population:** runner step 1b fetches `db/albums` and `db/artists`
(two whole-library calls) into `remote_albums` / `remote_artists` on every
non-304 run.

**Art cache:** runner step 6 downloads `album-art/<file>?compress=m` for every
distinct `art` of mirrored tracks into `<appData>/art/<server>/<file>`
(content-addressed names → no invalidation). `DisplayItem.getImage /
getAlbumThumb` and the `queueExtras` art URL prefer the cached file when
present, via `ArtCache.pathFor(server, file)` backed by an in-memory set
loaded at boot — no per-row stat.

**Switch policy:** a runtime `offline` flag on the current server, set by a
"Browse offline copy" toggle in the browser toolbar overflow and automatically
when the `getServerPaths` ping fails while the index has rows for that server;
cleared on a successful ping. `LibrarySource source(Server s) => s.offline ?
local : http`. The visual change is the offline chip in the toolbar; every
list looks identical.

**Tests:** `LocalLibrarySource` over an in-memory index — row shapes equal the
HTTP mapping for a fixture response; existing capability tests unchanged.

---

## 6. A5 — offline: playlists, rated, genres, recent, search

- Runner fetches `playlist/getall` then `playlist/load` per playlist,
  `db/rated`, `db/genres` (all small) on non-304 runs. Recent = `ORDER BY
  created_at DESC LIMIT 100` over `remote_tracks`.
- Search: `tracks_fts MATCH ?` with prefix tokens (`"term"*`), grouped like
  the online search screen; rows carry full metadata (no `partialMetadata`
  refetch offline).
- Offline writes: `outbox(server, op, payload, created)`; `rateSong` and
  playlist edits enqueue when offline and replay after the next successful
  ping (last-writer-wins; failures logged). Split into A5b if it grows.
- Visual change: search works offline (badge on the results header).

---

## 7. A6a / A6b — rules

Expansion is local SQL now that the index holds everything:

| kind | expansion |
|---|---|
| `album` | `remote_tracks WHERE album = key` |
| `artist` | `… WHERE artist = key OR album_artist = key` |
| `genre` | `… WHERE genres LIKE '%"key"%'` (a `remote_track_genres` table if it ever matters) |
| `playlist` | `remote_playlist_items WHERE playlist_id = key` (refreshed each run) |
| `rated` | `remote_rated WHERE rating >= key` |
| `library` / `folder` | path prefix |

`subscription_files` is rewritten per run; a path is `wanted` when any
enabled subscription references it; removing a rule re-plans and trashes only
paths with no remaining edge. UI — A6a: "Keep offline" switch in the album
detail toolbar (`lib/screens/album_detail_view.dart` /
`lib/widgets/browser_toolbar.dart`) and in the artist row's actions sheet;
A6b: playlist row action in `lib/widgets/more_actions_sheet.dart` + "Keep
rated ≥ N" in Manage Server. Mobile rules default `wifi_only` from the
existing `offlineQueueWifiOnly` setting.

---

## 8. A7 — transcoded tier

Rule `quality = 'mp3-192'` etc.: destination
`media-transcoded/<codec>-<kbps>/<localname>/<path>` with the extension
swapped; URL from `buildServerStreamUrl` with transcode params; no Range and
no verify (size unknown → completion = ok); `local_files.quality`
distinguishes rows; the resolver prefers `original`, then transcoded; the
planner ignores transcoded rows entirely. Quality picker on the "Keep
offline" sheet, hidden when `transcodeAvailable == false`.

---

## 9. A8 — fold keep-queue-offline into the index

`AutoDownloadLedger` becomes a thin façade over `local_files WHERE
origin='auto'` ordered by `verified_at`; `selectEvictions` keeps its signature
and its tests (`test/singletons/auto_download_cap_test.dart`,
`auto_download_test.dart`). Migration: import `auto_downloads.json` once,
then delete it. No UI.

---

## 10. S2 + A9 — deltas (only when full pulls hurt: >100k tracks, or phones on cellular)

Server: a migration adds `track_tombstones(library_id, filepath, deleted_at)`,
written at the two delete sites — the `DELETE FROM tracks WHERE (id,
filepath) IN …` batch in `src/db/orphan-cleanup.js` and its twin in
`rust-parser/src/main.rs` — plus vpath removal; swept after 180 days. The
manifest accepts `since: {maxId, maxModified, at}` and returns `entries`
(`id > maxId OR modified > maxModified`) + `deleted: [paths]` from tombstones
with `deleted_at > at`, or `full: true` when the tombstone window has been
swept. Ping flag `syncDelta`.
App: the runner sends `since` when the flag is set; any inconsistency
(unknown path in `deleted`, count mismatch) forces a full pull.

---

## 11. S3 + A10 — back up a desktop folder *to* the server

Server: admin toggle `allowDeviceLibraries`; `POST /api/v1/sync/upload-library
{deviceName}` idempotently creates library `uploads-<user>-<device>` under a
configured parent and returns its vpath. Upload stays
`POST /api/v1/file-explorer/upload` (busboy, `data-location` header), gated by
`allow_upload`. After a batch the client calls a user-scoped
`POST /api/v1/sync/upload-library/scan` that queues a scan of that vpath only
(the admin scan routes stay admin).
App: Manage Server → "Back up a folder to this server": pick a folder,
`Directory.watch` on desktop plus a stat walk per run, upload new / changed
by size + mtime, never delete remotely, progress in the same status section.
Needs a product decision first: who may create libraries.

---

## 12. A11 — headless CLI

`packages/library_mirror/bin/mstream_mirror.dart`: `--server URL --token T
--dest DIR [--rules rules.json] [--index path]`; a `Downloader` over
`package:http` streaming to file with Range resume; `dart compile exe`; exit
codes mirror the server worker (0 ok, 1 fatal, per-file errors counted).
Launcher scheduling is a separate mStream ticket.

---

## 13. Release checklist

- S1 released and deployed before the app release containing A3.
- App PRs: `flutter analyze`, `flutter test`, package `dart test`, the §4.5
  smoke, one screenshot of the single visual change.
- Server PRs: `npm test`, `npm run lint`, `docs/openapi.yaml`, CHANGELOG line.
- Retarget stacked PR bases before merging (A6b on A6a, A9 on A3).

---

## 14. Risks and mitigations

| Risk | Mitigation |
|---|---|
| 32-bit Android device without the SQLite native lib | `ndk.abiFilters` packages armeabi-v7a and `sqlite3_flutter_libs` ships it; still catch the load failure and disable the index for the session |
| Two SQLite connections (UI isolate + run isolate) | WAL + `busy_timeout` 5 s; writes come from the run isolate except tiny UI writes (subscriptions) |
| Manifest size on big libraries | ~2 MB gzipped at 25k; S2 deltas when it hurts; smaller pages on cellular |
| Case-insensitive collisions on Windows / macOS | planner `conflicts`, surfaced in the status errors list |
| Windows `MAX_PATH` | `longPathAware` in `windows/runner/runner.exe.manifest` on the desktop branch; smoke with a 260+ char path |
| Trash needs headroom for replaces | preflight counts old + new; "keep forever" shows trash size in the status line |
| App closed = no sync on desktop | say so in the status line; A11 for a scheduled headless run |
| `makeServerCall` treats 304 as failure | `allow304` on the manifest call |
| Album / artist identity by name | mirrors the API exactly; exact grouping stays available via `album_id` / `artist_id` if a screen ever needs it |
