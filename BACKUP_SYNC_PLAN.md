# Backup & library sync plan (desktop first, Plus on mobile)

Design notes for keeping a local copy of a server's library in sync — as a
backup, and for offline browsing/playback — and for letting external tools
such as Syncthing do the transfer where the user prefers. Research + proposal
only; nothing here is implemented.

**Branches:** the desktop shell lives on `feat/windows-desktop` (PR #84); this
plan assumes it lands first. Server repo: `mStream`. Prior-art sources are
linked in §2.

---

## 0. TL;DR

- **Server stays the source of truth.** The desktop keeps a **one-way mirror**
  (pull). Server-side deletions move the local file into a dated trash with
  retention — the same convention the server's own backup worker uses. No
  two-way merge in v1; "backup my folder to the server" is a later, separate
  direction (§4.5).
- Three building blocks, each shippable on its own:
  1. **Local library index** — SQLite (drift) caching the server's entities
     (tracks/albums/artists/genres/playlists/ratings) keyed by server ids, plus
     local-file state. Drives offline browse, FTS search and local playback.
  2. **Mirror engine** — pure Dart package under `packages/` that diffs a server
     **manifest** against the index, transfers with resume + verify through the
     existing `background_downloader` stack, and reconciles (trash, rename
     detection by `audio_hash`).
  3. **External-sync bridge** — a per-server *mirror root* so a folder kept by
     Syncthing / rclone / a NAS share is recognised as local copies, plus
     optional Syncthing REST integration (status, events, one-tap pairing).
- **Server needs one new endpoint for v1** (`POST /api/v1/sync/manifest`).
  Everything else the engine needs already exists. Deltas with tombstones and a
  Syncthing pairing endpoint come later.
- **Don't bundle Syncthing; detect it.** On Android only the `full`/Plus flavor
  can read a Syncthing folder (all-files access). The official Syncthing
  Android app was discontinued in 2024; Syncthing-Fork is maintained.

---

## 1. What exists today

### 1.1 App

| Piece | Where | Notes |
|---|---|---|
| Download manager | `lib/singletons/downloads.dart` | `background_downloader` 9.5.5 (supports iOS/Android/macOS/Windows/Linux, pause/resume, Wi-Fi constraint). Layout is `<base>/media/<serverLocalname>/<dataPath>` — a path mirror per server. Dedupe key = `serverName+filepath`. Iroh re-resolve on tunnel rotation. |
| Storage location | `lib/singletons/file_explorer.dart` `getDownloadDir` | Per-server `storageMode`: `appLocal` / `appExternal` / `sdCardApp` / `permanent` / `sdCard`. Desktop branch: `permanent` = user-chosen folder, else App Support. FAT-name checks (`hasFatIllegalChars`, `isFatLikeDir`) already exist and double as NTFS reserved-name checks. |
| Keep-queue-offline | `lib/singletons/auto_download_ledger.dart`, `DownloadTracker.auto` | Auto-downloads the queue, FIFO cap eviction, manual downloads never evicted. This is already the "auto vs pinned" split every music app ends up with. |
| Local playback | `lib/media/local_playback_backend.dart`, `lib/singletons/api.dart:257-299`, `lib/util/queue_actions.dart:59-70` | Queue items carry `extras.localPath`; existence is re-checked at play time and playback falls back to streaming. Resolution is a `File.existsSync()` on the derived path — no index. |
| Local browsing | `FileExplorer.getLocalFiles` | Walks the filesystem: folders + files only. No albums/artists/search offline. |
| Persistence | `servers.json`, `queue.json` (`lib/singletons/queue_store.dart`), `auto_downloads.json`, settings | Single-JSON-file pattern with `WriteChain`. No database in the app. |
| Plus flavor | `lib/build_variant.dart`, `PLAY_COMPLIANCE.md` | `full` = `mstream.music.plus`: all-files access, self-signed SSL. The Play flavor can only use app-scoped storage. |

### 1.2 Server

| Piece | Where | Notes |
|---|---|---|
| Track identity | `src/db/schema.js` `tracks` | `file_size`, `modified` (mtime ms), `file_hash` (MD5 <25MB, sampled above), `audio_hash` (payload-only, stable across tag edits), `hash_v`, `created_at`. Both already reach clients via the metadata object (`hash`, `audio-hash`, `modified`, `file-size`, `created-at`) in `src/api/db.js`. |
| Media | `src/server.js:725` `/media/:vpath` | `express.static` per library → `Range` and `HEAD` work for free (resume, cheap size check). `/transcode` deliberately has no `Accept-Ranges`. |
| Listings | `POST /api/v1/file-explorer/recursive` | Paths only (no size/mtime) — usable as a fallback manifest for old servers, at the cost of a `db/metadata/batch` round-trip. |
| Bulk download | `src/api/download.js` | Zip streaming with `downloadSizeLimit`. Fine for one-off exports, wrong tool for a mirror (no per-file resume, no verify). |
| Server-side backup | `src/backup/manager.js`, `src/backup/worker.mjs`, `src/api/backup.js` | Admin-only, same-host mirror of a library to a `dest_path`: sorted merge-walk (rsync-style), `.mstream-trash/<YYYY-MM-DD>/` soft delete with `retention_days`, resume for ≥16MB files, mtime tolerance (2s + DST skew), after-scan / daily triggers, task-queue mutex with scans, history rows. **This is the algorithm the client engine should copy, not reinvent.** |
| Export pattern | `src/db/discovery-export.js` | Builds an allowlisted SQLite snapshot + `manifest.json` (row count, sha256). Precedent for handing a client a ready-made SQLite file. |
| Change signal | `GET /api/v1/db/status`, `GET /api/v1/scan/status` | Count + `locked`; no revision, no changes-since feed, no tombstones (orphan cleanup deletes rows outright, in both scanners). |
| Transport | `src/api/iroh.js`, app `rust/iroh_tunnel` | Iroh **core only** — no `iroh-blobs`. Downloads already flow through the tunnel via the loopback proxy. |

---

## 2. Prior art — what desktop apps do, and what to borrow

### 2.1 General file sync

| Tool | Mechanism | Borrow |
|---|---|---|
| **Syncthing** ([2.0, Aug 2025](https://github.com/syncthing/syncthing/releases/tag/v2.0.0)) | Block Exchange Protocol between device IDs; each side keeps an index (SQLite since 2.0, [LWN](https://lwn.net/Articles/1033634/)) and exchanges index deltas; variable block size; folder types `sendonly` / `receiveonly` / `sendreceive` / `receiveencrypted`; versioning (trash-can, staggered); `.stignore`; relays for NAT; [REST API](https://docs.syncthing.net/dev/rest.html) on `127.0.0.1:8384` with `X-API-Key` (`/rest/config/folders`, `/rest/db/completion`, `/rest/db/status`, `/rest/events` long-poll). Deleted items are forgotten after six months by default in 2.0. | The **index-exchange model** (client holds a manifest, diffs, pulls); `sendonly` on the server ↔ `receiveonly` on the client is exactly our one-way mirror; the REST/events surface is what the app integrates with (§4.4). |
| **Nextcloud / ownCloud desktop client** | Sync journal in a local SQLite; tree discovery by **ETag propagation** (a changed file changes its parent folder ETags, so unchanged subtrees are skipped); selective sync; **virtual files / files-on-demand** placeholders. | Cheap "did anything change?" check (a per-library revision ETag, §5); files-on-demand is the mental model for the browser: show everything, hydrate on play. |
| **Dropbox** | `list_folder` + `list_folder/continue` cursor (delta feed), `longpoll`; 4MB block hashes; Smart Sync placeholders. | The **cursor-based delta feed** is the phase-2 shape of the manifest endpoint. |
| **rclone** | `sync` one-way (size+modtime or `--checksum`), `--backup-dir` (moved/overwritten files go to a dir — same as `.mstream-trash`), `--track-renames` (hash-based rename detection), `--modify-window`, `bisync` two-way with listing snapshots. | `--track-renames` via `audio_hash`; `--backup-dir` semantics; keep two-way out of v1 (bisync needs snapshots of both sides and conflict rules). |
| **robocopy /MIR, rsync** | Merge-walk of two sorted trees. | The server's `worker.mjs` already implements this; the client engine mirrors it. |

### 2.2 Backup tools

| Tool | Mechanism | Verdict |
|---|---|---|
| **restic / kopia / borg / Duplicati** | Content-defined chunking, dedup, encryption, immutable snapshots in a repository; restore is a separate step. | Not a fit: the copy must stay a playable folder. But the "manifest + content-addressed verify" idea carries over (album art is already content-addressed on the server — MD5 stem since V50). |
| **Time Machine / File History** | Mirror + versions with retention. | Retention UI: "keep deleted files for N days" (server default 30). |
| **mStream's own backup destinations** | Server pushes a library to a same-host path. | Complementary zero-code route: mount the desktop (SMB) on the server host and add it as a destination. Worth documenting in the app's help text. |

### 2.3 Music apps

| App | What it does | Borrow |
|---|---|---|
| **iTunes / Music.app** | Sync to device by selection: playlists, artists, albums, genres; "Consolidate files" into the managed folder; library DB kept outside the media tree. | The **selection model** (§4.3) — users think in playlists/artists/albums, not paths. |
| **Plexamp** | Per-album/playlist/artist downloads at a chosen quality (server transcodes on download); a Downloads section; server keeps the download job list. | "Quality" as a per-rule setting: *original* for the mirror/backup, *transcoded* for pocket copies. Never mix them in one tree. |
| **Finamp** (Jellyfin) | Download system rebuilt on a local DB: collections → items → files as a graph with "required by" edges, so deleting a playlist doesn't remove tracks an album still pins; **sync** re-fetches each collection and adds/removes; full offline mode browses the local DB. | The **required-by graph** for subscriptions (§4.3) and the offline-mode source switch (§4.1). |
| **Symfonium** | Keeps a **full local SQLite copy of the library metadata** for every provider (browsing is always local; incremental sync where the provider supports it), plus an offline cache with rules (sync playlists/albums/filters, size cap, transcode). | The local index is the foundation, the file mirror sits on top — same layering as here. |
| **DSub / Tempo / Ultrasonic** | Pinned vs cached tracks, cache size cap with LRU, "keep playlist synced". | We already have this split (manual vs auto ledger). Reuse, don't duplicate. |
| **Spotify / Apple Music** | Per-album/playlist download toggles, playlists keep their downloads updated, Wi-Fi-only, storage cap, "Remove all downloads". | The UX vocabulary: a single "Keep offline" switch per entity, with the rule list under Manage Server. |
| **Calibre / beets / Lightroom** | Library = a folder with the DB inside it (Calibre `metadata.db`, beets' SQLite, Lightroom catalog). Calibre explicitly warns that syncing that folder with Dropbox/Syncthing corrupts the DB. | **Never put the app's SQLite inside a synced folder.** Sync media only; the index is per-device and rebuilt from the server. |

Android note: the official Syncthing Android app was
[archived in 2024](https://forum.syncthing.net/t/syncthing-android-public-archived/23360);
[Syncthing-Fork](https://f-droid.org/packages/com.github.catfriend1.syncthingfork/)
continues under a new maintainer (2.1.x on F-Droid, Aug 2026). iOS has no
first-party Syncthing at all.

---

## 3. Semantics: "backup" and "sync" pull in opposite directions

A mirror propagates deletions, which is what "stay synced" means but not what
"backup" means. Every tool above resolves this the same way: **mirror + dated
trash + retention**. Adopt the server's convention verbatim:

- Deleted-on-server → move local file to `<root>/.mstream-trash/<YYYY-MM-DD>/<same relative path>`.
- Sweep buckets older than `retention_days` (default 30, `0` = keep forever = true backup).
- Never delete a file the mirror didn't create (ownership is recorded in the index — files that arrived via Syncthing or a manual download are `external`/`manual` and untouched).
- Modified-on-server (size/mtime/hash differ) → download to `.mstream-tmp-*`, atomic rename over the old file, old file to trash.

Direction for v1: **pull only**. The client never writes into the server's
library. Uploading a desktop folder is §4.5 and lands in its own library, which
sidesteps merge conflicts entirely.

---

## 4. Architecture

### 4.1 Local library index (SQLite via drift)

Why a DB now: the app resolves local copies by `existsSync` on a derived path
and browses local files by walking the disk. A mirror of 25k files needs a
diffable table, and offline browsing needs albums/artists/search — neither is
JSON-file shaped.

**Choice: `drift`** (`sqlite3_flutter_libs` bundles SQLite with FTS5 on all six
platforms; typed queries; migrations; runs in an isolate). Not isar (v3
maintenance stalled), not sqflite (desktop only via FFI shim, untyped). The
server is SQLite too, so schema knowledge transfers.

**Principle: the index is a cache of server responses keyed by server ids, not
a re-derivation.** Album/artist grouping, compilations, album_artist rules and
the V51 cascades live on the server; the client must not re-implement them.
Store what `db/albums`, `db/artists`, `db/genres`, `playlist/getall`, `db/rated`
and the manifest return, as-is.

Tables (all keyed by `server` = localname):

| Table | Purpose |
|---|---|
| `remote_tracks` | id, path, size, modified, hash, audio_hash, hash_v, album_id, artist_id, title, artist, album, album_artist, track, disc, year, duration, format, art, created_at, `seen_rev` |
| `remote_albums`, `remote_artists`, `remote_genres` | as served; `track_count`, art |
| `remote_playlists`, `remote_playlist_items`, `remote_rated` | user state, for offline lists |
| `local_files` | server, path, local_path, size, mtime, hash, `state` (pending / downloading / ok / stale / trashed), `origin` (mirror / manual / auto / external), verified_at |
| `subscriptions` | server, kind, key, quality, wifi_only, enabled, last_run (§4.3) |
| `sync_runs` | per-run counters + errors (mirrors the server's history rows) |
| `tracks_fts` | FTS5 over title/artist/album/path for offline search |
| `outbox` | queued offline writes (rating, playlist edit) replayed when online — phase 3 |

**Offline browsing = a source switch in the API layer.** `Api().getAlbums()`,
`getArtists()`, `getAlbumSongs()`, `getPlaylists()`, `searchServer()` etc. all
end in `BrowserManager().addListToStack(List<DisplayItem>)`. Add a
`LibrarySource` with two implementations — HTTP (today) and Local (SQL) — that
produce the same `DisplayItem` rows. Screens don't change. Select Local when
the server ping fails, the user flips an "Offline" toggle, or the subscription
is "browse offline library". Rows whose `local_files.state == ok` get the
existing local badge; the rest stay visible and greyed (files-on-demand).

**Playback:** `buildServerFileMediaItem` consults the index instead of
`existsSync` on a guessed path — one lookup, and it also finds files under the
mirror root (§4.4). Keep the existence re-check at play time (the backend
already falls back to streaming).

Migration: leave `auto_downloads.json` and `queue.json` alone in phase 2. Import
existing `media/<localname>/` files into `local_files` as `origin=manual` on
first run (walk once, stat only; hash lazily).

### 4.2 Mirror engine (`packages/library_mirror`, pure Dart)

Pure Dart with no Flutter imports so the same code can later run headless
(`dart compile exe` → an `mstream-mirror` CLI, or inside the launcher). The
app is a pure client on desktop with no background service, so "backup runs
while the app is closed" needs that path eventually.

Pipeline per server, per run (one run at a time per server, like the server's
task queue):

1. **Fetch manifest** — `POST /api/v1/sync/manifest` (§5), paged. Send the last
   `revision` as `If-None-Match`; a 304 ends the run in one round-trip.
   Upsert into `remote_tracks`, stamp `seen_rev`. Rows not seen at the new
   revision are deletions.
   *Fallback for servers without the endpoint:* `file-explorer/recursive` per
   library + `db/metadata/batch` in chunks. Slower, no 304, still correct.
2. **Plan** — join `remote_tracks ⋈ local_files` for every path a subscription
   covers:
   - missing locally → `download`
   - size or mtime differ (server tolerance: 2s, DST ±1h skew — copy the
     constants from `worker.mjs`) → `download` (replace)
   - hash matches a local file at another path → `rename` (rclone
     `--track-renames`; `audio_hash` survives tag edits, `hash` doesn't)
   - gone from manifest, `origin=mirror` → `trash`
   - covered by no subscription any more → `trash` (or keep, per setting)
   Preflight: sum bytes vs free space (per-platform free-space query) and
   refuse to start a run that can't fit.
3. **Transfer** — hand the plan to `DownloadManager` in a dedicated
   `background_downloader` group (`mirror`) so it doesn't fight manual/auto
   downloads for the concurrency budget; `allowPause: true` (Range resume via
   `express.static`); `requiresWiFi` from the rule on mobile; a bandwidth cap
   on desktop (throttle setting — the server has no per-user QoS). Destination
   is the existing `<base>/media/<localname>/<path>` tree so today's local
   playback and FileExplorer keep working unchanged.
4. **Verify + stamp** — compare size; for rows with `hash_v` meaning
   full-MD5 (below the 25MB threshold) verify MD5; above it, size only (or
   port the sampled scheme from `audio-hash.js` later). Then
   `File.setLastModified(server modified)` so rclone/Syncthing/robocopy see
   consistent times if the user layers them on top.
5. **Reconcile** — apply `rename` / `trash`, write `sync_runs`, sweep trash
   buckets past retention, purge `.mstream-tmp-*` orphans.
6. **Art** — album art files are content-addressed (`<md5>.<ext>`); fetch the
   set referenced by mirrored tracks into an art cache keyed by filename.
   Cheap, dedups across albums, and offline album grids need it.

Triggers: app start (after N minutes online), every 6h while running, manual
"Sync now", and — cheap and decisive — a `db/status.totalFileCount` or
manifest-revision change observed on any browse. Over iroh nothing changes:
the manifest is an API call and `/media` already proxies through the tunnel.

### 4.3 Subscriptions — what to keep

Rules, not paths. Each rule expands to a path set at plan time:

| Kind | Expands via | Quality options |
|---|---|---|
| `library` (whole vpath) | manifest filter | original |
| `folder` | manifest prefix | original |
| `album` / `artist` / `genre` | `db/album-songs`, `db/artists-albums`, `db/genre-songs` | original / transcoded |
| `playlist` | `playlist/load` on each run (keeps synced, like Spotify) | original / transcoded |
| `rated` (≥ N stars) | `db/rated` | original / transcoded |
| `queue` | existing keep-queue-offline sweep, unchanged | as today |

A track pinned by several rules has several "required by" edges (Finamp's
model): removing a rule only trashes files no other rule needs. Transcoded
copies live under `media-transcoded/<codec>-<bitrate>/…`, never in the mirror
tree, because the mirror's contract is byte-identical originals.

**Desktop backup = one `library` rule per library, quality original, retention
30 days.** That is the whole "backup" feature from the user's point of view.

### 4.4 External-sync bridge, and where Syncthing fits

Three tiers; each is useful without the next.

**Tier A — Mirror root (no Syncthing code at all).** Add `mirrorRoot` to
`Server` (a folder that already contains `<library>/<path>` from any source).
`local_files` gains `origin=external` rows from a periodic stat walk (or a
`Directory.watch` on desktop) and the play-time resolver checks it. Result:
whatever keeps that folder current — Syncthing, rclone, robocopy, a NAS the
user already mirrors — makes the app play locally and browse offline. On
Android this needs all-files access → Plus flavor only (the Play flavor can't
take a `File` path outside app storage; SAF tree URIs don't fit the
`File`-based player path).

**Tier B — Syncthing status/events (desktop, read-only integration).** If
`127.0.0.1:8384` answers, read the API key from Syncthing's `config.xml`
(standard per-OS path) or let the user paste it. Then: list folders whose
path equals the mirror root, show `/rest/db/completion` progress and
`/rest/db/status` state in Manage Server, and long-poll
`/rest/events?events=ItemFinished,FolderCompletion` to refresh `local_files`
incrementally instead of re-walking. Zero transfer code, immediate value for
people who already run Syncthing.

**Tier C — One-tap pairing via the server.** Admin toggles "Share this library
with Syncthing" in mStream: the server talks to the Syncthing daemon on *its*
host (REST, same API-key discovery), creates a `sendonly` folder for the
library's `root_path`, and exposes `{deviceId, folderId, folderLabel}` at
`GET /api/v1/sync/syncthing`. The desktop app then adds the server's device
and accepts the folder as `receiveonly` at the mirror root through its local
Syncthing REST API; the server side auto-accepts the app's device ID via the
same endpoint (`POST` with the client's `myID` from `/rest/system/status`).
Device IDs travel over mStream's authenticated API, so no QR/manual ID
exchange. Docker and the launcher can ship Syncthing as a sidecar; nothing in
mStream depends on it being present.

Why not bundle Syncthing in the app: it's a Go daemon with its own updater,
GUI and open port; the app just became a pure client (server management moved
to the launcher) and bundling would reverse that. Detect and integrate.

Syncthing vs the native engine: Syncthing gives NAT traversal, block-level
resume, versioning and a mature two-way story for free, but it syncs
*folders*, not *subscriptions* (no "just this playlist"), needs a daemon on
both ends, is Plus-only on Android and unavailable on iOS. The native engine
covers every platform and every rule but only moves originals over HTTP.
Ship both: Tier A + the native engine first; Tier B/C once the mirror root
exists.

**iroh-blobs** is the third option — content-addressed, verified, resumable
transfer over the tunnel the app already has — but the shim deliberately
compiles iroh core only to keep the Android `.so` small, and the server uses
`@number0/iroh`. Revisit only if HTTP-over-tunnel resume proves inadequate.

### 4.5 Reverse direction — backup a desktop folder *to* the server

Later phase, and deliberately not a merge: the desktop folder becomes its own
library on the server ("Uploads from <device>"), populated by
`POST /api/v1/file-explorer/upload` (respecting `noupload` / `allow_upload`),
then scanned. Because that library has one writer, there's no conflict
resolution. With Syncthing present it's the mirror image of Tier C
(`sendonly` on the desktop, `receiveonly` on the server host). Requires a
"create library" call for non-admins or an admin pre-creating the vpath.

---

## 5. Server API additions

### 5.1 `POST /api/v1/sync/manifest` (v1, required)

> Superseded in detail by `BACKUP_SYNC_IMPLEMENTATION.md` §1: entries also
> carry the lite metadata block (title / artist / album / album artist /
> track / disc / year / duration / format) and `genres`, so offline lists
> never need a per-track metadata fetch. The shape below is the minimum.

```
POST /api/v1/sync/manifest
{ "cursor": "<opaque or absent>", "limit": 5000, "ignoreVPaths": ["…"] }
→ 200 { "revision": "<string>",
        "entries": [ { "id", "path", "size", "modified", "hash", "audioHash",
                       "hashV", "albumId", "artistId", "art", "createdAt" } ],
        "next": "<cursor>|null" }
→ 304 when If-None-Match matches the current revision
```

- Scope = `libraryFilter(req.user, …)` like every `db/*` route; paths are
  `vpath/relative` exactly as `file-explorer/recursive` renders them.
- Order by `t.id`, cursor = last id → stable paging under concurrent scans.
- `revision` = `<visible-library-ids>:<count>:<max(id)>:<max(modified)>`
  computed per request (one indexed query) — no schema change. Bump-on-scan
  via `task-queue`'s `onScanComplete` hook can replace it later.
- ~150 bytes/entry → 25k tracks ≈ 3.7MB uncompressed, well under 1MB gzipped.
  A full pull on every run is fine for a desktop; deltas are an optimisation.
- Add to the federation allowlist only if peer mirrors are ever wanted
  (currently not).

### 5.2 Later

| Endpoint | Purpose |
|---|---|
| `POST /api/v1/sync/manifest` with `since: <revision>` | Delta: changed rows + tombstones. Needs a `track_tombstones(library_id, filepath, deleted_at)` table written by **both** scanners' delete paths and orphan cleanup, with its own retention (Syncthing 2.0 chose six months). |
| `GET /api/v1/sync/snapshot` | Discovery-export-style SQLite snapshot of the visible library. Only worth it if the JSON path proves slow on phones; couples client to server schema. |
| `GET/POST /api/v1/sync/syncthing` | Tier C pairing (§4.4). Admin toggle in `/api/v1/admin/config/*`. |
| Ping flag `sync` (+ `syncthing`) | House rule: flags, never probes. |

Nothing else: `/media` already does `Range` + `HEAD`; metadata, albums,
artists, playlists and ratings endpoints are reused as-is.

---

## 6. Phasing (one visual change per PR, per the usual rule)

| Phase | Scope | Platforms | Effort |
|---|---|---|---|
| **0 — Mirror root** | `Server.mirrorRoot` + picker in Manage Server (desktop form; Plus on Android), resolver checks it, local badge appears for externally-synced files. | desktop, Plus | 🟢 1–2d |
| **1 — Manifest endpoint** | `sync/manifest` + ping flag + tests (server PR). | server | 🟢 1–2d |
| **2 — Index + engine** | drift DB, `packages/library_mirror`, `library` rule only, Manage Server: "Keep a full copy" toggle, status line, Sync now, retention. Import of existing downloads. | desktop first, then all | 🔴 6–9d |
| **3 — Offline browsing** | `LibrarySource` switch, Local implementation for albums/artists/genres/playlists/rated/search (FTS5), offline toggle + auto-fallback, art cache. | all | 🟡 4–6d |
| **4 — Rules** | album/artist/playlist/genre/rated subscriptions, required-by edges, transcoded quality tier, "Keep offline" on entity rows. Fold keep-queue-offline into the same ledger. | all | 🟡 3–5d |
| **5 — Syncthing B/C** | detect + status/events; server toggle + pairing endpoint; docker/launcher sidecar docs. | desktop (+server) | 🟡 3–5d |
| **6 — Upload direction** | per-device upload library, folder watch, Syncthing mirror image. | desktop | 🟡 3–5d |
| **7 — Headless** | `mstream-mirror` CLI from the engine package; launcher integration. | desktop | 🟡 2–3d |

Phase 2 is the only one that can't be split further; its PR should land the
package with unit tests around the planner (pure functions over manifest +
local rows, same style as `AutoDownloadLedger.selectEvictions`) before any
UI.

---

## 7. Gotchas (found now, so they don't cost a release later)

- **SQLite in a synced folder corrupts** (Calibre's lesson). The index lives in
  App Support, never under the mirror root.
- **Case-insensitive targets.** Windows/macOS/FAT fold case; a Linux server
  can hold `Live.flac` and `live.flac`. Detect collisions in the plan step
  (NFC + lowercase key) and skip with a per-file error rather than clobber —
  Syncthing reports the same as "case conflicts".
- **Unicode normalisation.** HFS+/APFS return NFD names; compare NFC keys
  (`worker.mjs` already does).
- **Windows paths.** Reserved names and `<>:"|?*` — reuse `hasFatIllegalChars`
  for Windows targets; enable long-path awareness in the Windows runner
  manifest or `\\?\`-prefix, or a 300-char classical path fails on
  `MAX_PATH`.
- **mtime tolerance.** 2s window + ±1h DST carve-out from `worker.mjs`; without
  it a FAT mirror re-downloads everything twice a year.
- **Big-file hashes are sampled** (≥25MB, `hash_v` 2). Size is the only
  byte-exact check there unless the sampled scheme is ported.
- **Transcode is not mirror.** `/transcode` has no `Accept-Ranges`, no
  `Content-Length`, and a different byte stream every time — keep transcoded
  copies in their own tree and never verify them against `hash`.
- **Trash headroom.** A replace needs old + new on disk briefly; the preflight
  must count that, and "retention 0 = forever" needs a visible size.
- **Desktop has no background service.** Runs happen while the app is open;
  say so in the UI until phase 7. `background_downloader` on desktop is
  in-process.
- **Tokens in URLs.** Downloads use `?token=`; tasks persisted by the
  downloader across restarts carry it — same as today, but a mirror queue
  is larger and lives longer. Prefer the header form if the downloader group
  is long-lived.
- **Play flavor.** Native mirror works (app-scoped storage); Tier A/Syncthing
  do not. Gate the picker on `!isPlayBuild`, as the storage modes already are.
- **Android downloads time out at 9 minutes** unless `allowPause`/foreground
  is set — set `allowPause: true` for the mirror group.

---

## 8. Open questions

1. Direction confirmed as **pull-only first**? (§3) The upload direction is
   a different feature with different permissions.
2. Should "Keep a full copy of this library" default to **original quality
   only** (true backup), with transcoded tiers reserved for entity rules?
3. Where does the desktop index live for multiple servers — one DB with a
   `server` column (proposed) or one DB per server (simpler deletes when a
   server is removed)?
4. Syncthing on the server host: sidecar in `docker-mstream` and the launcher,
   or documentation only?
5. Is a headless mirror (phase 7) wanted in the launcher, or is "app must be
   open" acceptable for the first release?
