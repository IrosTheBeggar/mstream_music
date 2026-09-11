# Play history & listening stats

Capturing what the mobile app plays, keeping a bounded copy on the device, and
feeding a redesigned server-side stats API so the webapp and the app agree on
what has been listened to.

Two findings shape this plan:

1. **The server already has most of the machinery** — a per-user
   `play_count` / `last_played` on every track, a raw `play_events` table with
   a "Wrapped" stats view, and Recently-played / Most-played list routes — and
   **the app never posts a single play**, so none of it reflects mobile
   listening today.
2. **That machinery is being redone.** The wrapped routes and the velvet stats
   stubs are unofficial velvet-era APIs, and the Subsonic API is going too.
   Rather than build the app against routes with server-stamped time and no
   origin concept, the plan defines **Stats API v2** ([§3](#3-stats-api-v2-server))
   first and builds the app against that.

The storage rule that answers the "ballooning size" worry is in
[§5](#5-on-device-storage): every on-device store has a hard cap, raw events
live in a fixed-size ring, and everything older survives only as compact
aggregates — **about 4 MB** at the ceiling, less than a long queue.json. The
server gets the same discipline: hourly rollups plus a retention sweep so the
raw event table finally has a ceiling ([§3.3](#33-storage-behind-it)).

---

## 1. What exists today

### 1.1 Server (IrosTheBeggar/mStream, master 2026-09-05, schema V69)

**Removed on 2026-09-04/05 (PRs #947–#952):** the velvet UI and every module
mounted only for it — `wrapped.js`, `velvet-stubs.js` (log-play and the two
reset stubs), `listenbrainz.js`, `user-settings.js`, `smart-playlists.js`,
`cuepoints.js` — and the Subsonic API. **V69 dropped `play_events`,
`user_settings`, `cue_points` and `smart_playlists`** ("a future stats
feature starts from an empty log"). Still there: `scrobble-by-filepath`,
`recently-played` / `most-played`, `lastfm/status`, and the `user_metadata`
counters. The table keeps the removed rows for the record.

| Route | Since | What it does | Fate |
|---|---|---|---|
| `POST /api/v1/lastfm/scrobble-by-filepath` `{filePath}` | 2022-03 | `play_count += 1`, `last_played = now`; Last.fm scrobble if the user linked one | shim over v2 for one release (the default webapp calls it at 30 s) |
| `POST /api/v1/db/stats/recently-played` / `most-played` `{limit, ignoreVPaths?}` | 2022-03 | rows ordered by `last_played` / `play_count` | keep — valid cheap reads over counters |
| `POST /api/v1/db/stats/log-play` `{filePath}` | v6.0.0 (velvet stub) | `play_count += 1`, `last_played = now`, no scrobble | **removed 2026-09-05** |
| `POST /api/v1/db/stats/reset-play-counts`, `…/reset-recently-played` | v6.0.0 (velvet stub) | per-user resets | **removed 2026-09-05**; `stats/reset` replaces them |
| `POST /api/v1/wrapped/play-start` → `{eventId}`; `play-end` / `play-skip` / `play-stop` / `pause` | v6.0.0 (velvet) | two-phase event row; **server-generated id, server-stamped `started_at`** | **removed 2026-09-05** with velvet; V69 dropped the table |
| `GET /api/v1/user/wrapped`, `…/periods` | v6.0.0 (velvet) | the stats view over `play_events`, mixed with copy (personality, fun facts, en-US strings) and radio/podcast stubs | **removed 2026-09-05**; `stats/summary` + `top` + `timeseries` replace it |
| `GET /api/v1/lastfm/status` | 2026 | `{serverEnabled, hasApiKey, linkedUser}` | keep |
| `POST /api/v1/listenbrainz/scrobble-by-filepath`, `playing-now` | 2026 | ListenBrainz only; did **not** touch `play_count` | **removed 2026-09-05** with velvet |
| Subsonic `scrobble` | — | counter bump with a client `time` | **removed 2026-09-04** |

Storage behind them:

| Table | Key | Growth |
|---|---|---|
| `user_metadata` (`play_count`, `last_played`, `rating`, `starred_at`) | `(user_id, track_hash)` — `audio_hash` first, `file_hash` fallback; survives renames; **no FK to tracks** | one row per track the user touched |
| `play_events` (`event_id` UNIQUE, `filepath`, `library_id`, `session_id`, `source`, `outcome`, `played_ms`, `track_duration_ms`, `started_at`, `ended_at`, `pause_count`) | autoincrement; keyed by **filepath**, rewritten by the orphan sweep on renames | **one row per play, never pruned** (2026-07 audit H2); indexed `(user_id, started_at)` since V65 |

Facts that drove the redesign:

- **Three write paths that disagree.** Counters come from scrobble / log-play,
  events from wrapped, and nothing ties them together.
- **The webapp counts every start and double-counts.** Velvet fires
  `log-play` the moment a track starts (its comment says "after 30 s"; the
  code does not wait) *and* `scrobble-by-filepath` at 30 s whenever the server
  has a Last.fm API key (`S.lastfmEnabled`, which even defaults to true when
  the status probe fails). Both bump `play_count`.
- **The counting rule lives in clients**, so numbers mean different things
  depending on who wrote them.
- **Events can't be back-dated**, so an offline play can never land at its
  true time.
- **Timezone-blind bucketing.** Period bounds are computed in server-local
  time and compared as UTC text; hour-of-day bins use the stored UTC digits.
  The first-day-of-month bug this caused has already been hit once.
- **Federated peers expose none of it**, by design: the allowlist in
  `federation-auth.js` excludes every write and the per-user stat reads.
- **No capability flag** advertises any of it.
- **Peer plumbing that v2 can reuse**: `fedFetch(peer, apiPath, opts)` in
  `src/state/federation-client.js` dials a peer with its key, and
  `src/api/federation-browse.js` proxies allowlisted reads (incl.
  `db/metadata`) for the app.

### 1.2 App

- Nothing posts a play. Song Info shows the server's `play-count` chip
  ([metadata_screen.dart:125](lib/screens/metadata_screen.dart#L125));
  `last-played` is on the wire but not parsed.
- **Persistence pattern.** One JSON file per store in the app documents
  directory, written through a [`WriteChain`](lib/util/write_chain.dart):
  `servers.json`, `settings.json`, `queue.json` (debounced 800 ms, 10 s
  position checkpoint, flushed from `didChangeAppLifecycleState` —
  [main.dart:556](lib/main.dart#L556)), `auto_downloads.json` (the capped
  FIFO ledger — the closest precedent for a bounded store). Loads swallow a
  corrupt file so startup never blocks.
- **Track identity** is `server localname + library path`; the handler's
  `_trackKey` joins the two with a NUL separator
  ([audio_stuff.dart:1078](lib/media/audio_stuff.dart#L1078)). Queue extras
  carry `server`, `path`, `localPath`, display metadata and `playCount`, but
  not the server `hash` — a one-line addition to `queueExtras`.
- **Federated servers** are modelled already: `Server.isFederated`,
  `federationParent`, `federationPeerId` (the peer's row id on the parent),
  `parentServer`, and `apiUri` rewriting onto the parent's proxy.
- **Where playback is observable.** `AudioPlayerHandler` re-broadcasts the
  active backend (local, DLNA, Chromecast) through `mediaItem`, `queue`,
  `playbackState` and `positionStream`. A mid-queue track end surfaces as a
  `currentIndexStream` change; `completed` fires only at the end of the
  queue. One tracker therefore covers local playback, casting, Android Auto
  and CarPlay.
- **Capability gating**: the layered `GET /api` `features` block is parsed in
  `_applyServerInfo` ([server_list.dart:470](lib/singletons/server_list.dart#L470))
  and persisted on `Server` (`discoveryAvailable` etc.); `_applyFederatedDefaults`
  zeroes the flags for peers. Version floors and learned rejections live in
  `server_version.dart` / `server_capabilities.dart`.
- **Server removal** cascades into the queue
  (`removeServerQueueItems`, [server_list.dart:1665](lib/singletons/server_list.dart#L1665)).
- `sqflite` 2.4.3 is linked transitively (via `flutter_cache_manager`) but
  unused. Android has `allowBackup="false"`; iOS backs up the documents
  directory except downloads.

---

## 2. Design

### 2.1 Principles

1. **Clients report facts, the server derives meaning.** Events carry what
   happened; the server decides what counts, in one place, with one rule.
2. **Every write is idempotent and batchable**, so an outbox can retry forever.
3. **Stats belong to the user, and the user belongs to their server.** A play
   is recorded where the user's identity lives — for a federated peer's track,
   that is the parent, never the peer.
4. **The device keeps a bounded working copy** for offline, local-file and
   cross-server views. Every store has a hard cap.
5. **Never lie to the time-series.** Events carry their true start time; the
   server never stamps its own clock onto a play.
6. **Data, not copy.** The API returns numbers and objects; personality types
   and fun facts are client-side presentation.

### 2.2 Where each fact lives

| Fact | Device | Server |
|---|---|---|
| "played at 21:04 for 3:52, then skipped" | ring of the last N events | `play_events` (all plays, incl. replayed offline ones, at true time) |
| per-track plays / skips / listened time / first + last | `track stats` map, LRU-capped | `user_metadata` counters |
| listening per hour / day / month | day + month rollups | `user_hour_stats` rollups |
| unsent plays | outbox, capped + aged out | — |
| a peer's track played through the parent | yes, under the peer's localname | on the **parent**, with origin + snapshot |
| local-device files | yes | never |

---

## 3. Stats API v2 (server)

Namespace `/api/v1/stats/*`, documented under the existing **Stats** tag in
`docs/openapi.yaml`, registered from a new `src/api/stats.js` in `server.js`
next to the other `setup(mstream)` calls. camelCase on the wire; times are
ISO 8601 UTC strings; lists return `{items, next}`; Joi-validated bodies with
the existing `"<key>" is not allowed` 400 the app already parses.

### 3.1 Write side

`POST /api/v1/stats/plays`

```json
{
  "client": { "name": "mstream-music", "version": "0.36.0", "instanceId": "uuid" },
  "plays": [{
    "id": "9f3c2a1e-…",                 
    "filePath": "music/Radiohead/OK Computer/05 Let Down.flac",
    "peerId": 3,                        
    "startedAt": "2026-09-04T19:04:00.000Z",
    "playedMs": 240000,
    "durationMs": 299000,
    "outcome": "completed",             
    "source": "manual",                 
    "sessionId": "uuid",
    "pauseCount": 0,
    "track": { "title": "Let Down", "artist": "Radiohead", "album": "OK Computer",
               "durationMs": 299000, "hash": "7c1e…", "artFile": "…" }
  }]
}
```

| Field | Rules |
|---|---|
| `id` | client UUID; the idempotency key |
| `filePath` | vpath-prefixed, no leading slash (the app strips it as `rateSong` does). For a federated play it is the **peer's** path |
| `peerId` | optional; the peer's row id **on this server**. Present = federated origin |
| `startedAt` | required; must be ≤ now + 5 min and, when retention is finite, ≥ now − retention. Outside → rejected `bad-time` |
| `playedMs`, `durationMs` | ≥ 0; duration optional |
| `outcome` | `completed` \| `skipped` \| `stopped` |
| `source` | `manual` \| `shuffle` \| `autodj` \| `playlist` \| `smart-playlist` \| `auto` \| `carplay` \| `cast` \| `other` |
| `track` | metadata snapshot. **Required** when `peerId` is set; optional otherwise (ignored for local tracks, which resolve from the library) |
| batch | ≤ 200 plays per call |

Response: `{ accepted: [id…], duplicates: [id…], rejected: [{ id, reason }] }`
with reasons `unknown-track`, `unknown-peer`, `bad-time`, `invalid`. A
duplicate is acknowledged, not re-inserted; a rejection means "drop it".
Unknown tracks are **rejected, not silently 200'd** as today, so an outbox
knows to discard them.

Per play, in one transaction:

1. **Resolve.** Local: `getVPathInfo` + the `tracks` row → `trackKey =
   audio_hash || file_hash`, `library_id`, relative path. Federated: the peer
   must be currently listed (`fedDb.getFederationPeers()`); `trackKey` is the
   snapshot's hash; `library_id` null; the snapshot is stored.
2. **Decide `counted`.** `playedMs ≥ stats.playThresholdMs` (default 30 000)
   **or** `durationMs` known and `playedMs ≥ stats.playThresholdFraction ×
   durationMs` (default 0.5). Stored on the row, so the rule can change later
   without rewriting history.
3. **Insert** the event (`INSERT OR IGNORE` on the unique id; an existing id
   for the same user is a duplicate, for another user a rejection).
4. **Bump counters** on `user_metadata` for `trackKey`: `play_count += counted`,
   `last_played = max(last_played, startedAt)`, `first_played =
   min(...)`, `listened_ms += playedMs`, `skip_count += (outcome ==
   skipped)`.
5. **Bump the rollup** `user_hour_stats` for the UTC hour of `startedAt`:
   `events += 1`, `plays += counted`, `skips`, `listened_ms`.

After commit, for counted plays only: a Last.fm scrobble with the event's
own time (`postScrobble` in `src/state/lastfm.js` gains a `song.timestamp`;
skip anything older than Last.fm's 14-day window). Federated plays use the
snapshot's strings. Best-effort, never fails the request. (ListenBrainz went
with the velvet UI.)

`POST /api/v1/stats/now-playing` `{filePath, peerId?, sessionId, track?}` —
ephemeral, in-memory per user with a 10-minute TTL, forwards the Last.fm
`updateNowPlaying` notice, writes no row.
`GET /api/v1/stats/now-playing` returns the caller's own entries.

### 3.2 Federated plays

Stats belong to the user, and the user exists only on the parent, so a play
of a peer's track is ingested **by the parent** as the user's own play of a
track that happens to live elsewhere. The peer never sees it:

- the peer has no user to attribute it to (the parent authenticates with a
  federation key, so the peer sees "parent X", not a person);
- the peer's allowlist forbids every write and the per-user stat reads, and
  should keep doing so;
- the peer owner's counts are about *their* listening.

What the parent needs: the origin (`peerId` + the peer's path), the metadata
snapshot (the parent's library has no row for the track, so history and top
lists render from the snapshot), and counters keyed by the peer-reported
hash. Keying on the raw hash rather than a peer-namespaced key means that if
the identical file later appears in the parent's library the plays merge —
the right answer. Caveat: the peer's metadata block exposes the **file**
hash while local counters prefer the **audio** hash, so the merge is exact
only once the peer's metadata also carries the canonical key (a small
server change: surface `audio-hash` in `renderMetadataObj`). Optional
enrichment at ingest — `fedFetch(peer, '/api/v1/db/metadata', …)` with a
short deadline when the snapshot is thin — is a follow-up, not a
prerequisite.

Every event carries its origin, so the summary can report the peer slice and
`top` / `history` accept `origin=local|peers|all`. A social "friends played
this album twelve times" counter on the peer side is a separate, opt-in,
identity-free feature and is **out of scope** for this redo.

### 3.3 Storage behind it

Schema **V70** (V68 dropped the Subsonic password column, V69 the velvet
tables) — **landed with S2 on `claude/stats-api-reads`**, together with
`src/stats/store.js`, the one write primitive every writer (the S1 ingest
route, the shim, test seeding) goes through:

| Change | Why |
|---|---|
| `play_events`, created fresh (V69 dropped the old one, so nothing to backfill): `event_id` UNIQUE, `track_hash`, `filepath` + `library_id` snapshot, `peer_id` (SET NULL on peer delete), `snapshot`, `client`, `session_id`, `source`, `outcome`, `counted`, `played_ms`, `duration_ms`, `pause_count`, `started_at` / `ended_at` as `YYYY-MM-DD HH:MM:SS.SSS` UTC; indexes `(user_id, started_at)`, `(user_id, track_hash)`, `library_id`, `peer_id` | rename-proof joins; origin; display for foreign tracks; SQLite's own datetime text (with ms) so `strftime`/`date` and TEXT comparison work |
| `user_metadata` + `skip_count`, `listened_ms`, `first_played` | derived per-track stats without a scan |
| new `user_hour_stats (user_id, hour, events, plays, skips, listened_ms, PRIMARY KEY (user_id, hour))` | the time-series source; exact re-bucketing for any whole-hour timezone; survives event pruning |
| no migration hook | the old log died with V69; the new one starts empty |
| `hash-migration.js` merge | add `skip_count` (sum), `listened_ms` (sum), `first_played` (min) next to the existing `play_count` / `last_played` merge |
| config `stats: { playThresholdMs: 30000, playThresholdFraction: 0.5, retentionMonths: 24 }` | in `src/state/config.js` next to `lastFM`, documented in `docs/json_config.md`; `retentionMonths: 0` = keep forever |
| daily sweep | delete `play_events` older than retention (rollups and counters keep the totals), then `PRAGMA incremental_vacuum` |

### 3.4 Read side

All GET, user-scoped, library-scoped through the existing `libraryFilter`
(peer rows pass), accepting either `period=week|month|quarter|half|year|all`
plus `offset ≤ 0`, or `from` / `to`; `tz` as an IANA name, default UTC
(no per-user setting — `user_settings` went with velvet); `ignoreVPaths`; `limit`
(default 20, max 200).

| Endpoint | Returns |
|---|---|
| `GET /api/v1/stats/summary` | `{period:{label,from,to,tz}, plays, counted, uniqueTracks, uniqueArtists, uniqueAlbums, listenedMs, skips, skipRate, completionRate, pauses, discoveries, libraryCoveragePct, sessions:{count, avgMs, longest}, streakDays:{current, longest}, topDay, peakHour, peakWeekday, origins:{local, peers}}` |
| `GET /api/v1/stats/top?entity=tracks\|artists\|albums\|genres&metric=plays\|time&origin=` | `{items:[{rank, plays, listenedMs, share, track\|artist\|album\|genre}]}` — the track object is the normal metadata object for local rows, the snapshot (with `peerId`) for federated rows |
| `GET /api/v1/stats/timeseries?bucket=hour\|day\|week\|month\|hourOfDay\|weekday` | `{items:[{bucket, events, plays, skips, listenedMs}]}` from `user_hour_stats`, re-bucketed in `tz` |
| `GET /api/v1/stats/history?before=&limit=&track=&origin=` | the user's events newest first with track objects; opaque cursor; replaces recently-played and lets a client rebuild a local cache |
| `POST /api/v1/stats/tracks` `{filePaths?, hashes?}` | `{items:[{hash, filePath, plays, skips, listenedMs, firstPlayed, lastPlayed}]}` from counters — Song Info and badges |
| `GET /api/v1/stats/periods` | periods that have data, as today |

Sessions are derived server-side from gaps over 30 minutes, with the client
`sessionId` as a hint. Personality and fun facts move to the client. Radio and
podcast stubs are dropped; if podcasts ever arrive they become a `kind` on the
event. Non-whole-hour timezones (India, Nepal, parts of Australia) get
half-hour bucket error from the hourly rollup — documented, not solved.

### 3.5 Management

| Endpoint | Behaviour |
|---|---|
| `DELETE /api/v1/stats/plays/:id`, `DELETE /api/v1/stats/plays?from=&to=` | remove events and decrement the derived counters and rollups exactly |
| `POST /api/v1/stats/reset` `{scope: counts\|history\|all}` | replaces the two velvet reset stubs |
| `GET /api/v1/stats/export` | NDJSON stream of every event — backup, migration, GDPR |
| `POST /api/v1/admin/stats/rebuild` | recompute `user_hour_stats` and the derived counter columns from events (never `play_count`, which predates events) |

### 3.6 Capability and compatibility

- `features.stats: 2` in `buildFeatures` (`src/api/server-info.js`) and
  `stats: 2` in ping (`src/api/playlist.js`). Clients gate on the flag, never
  on version strings. The federation allowlist is unchanged.
- **One shim, one release**: `scrobble-by-filepath` builds a synthetic
  counted event (`source: legacy`, `playedMs` unknown) through the same
  ingest path, so the default webapp's 30-second scrobble keeps counting and
  Last.fm keeps working until that webapp posts completed events itself.
  `db/stats/recently-played` / `most-played` stay — cheap reads over the
  counters. (Velvet, `log-play` and the `wrapped/*` routes are already gone.)

---

## 4. Capture (app) — `PlayTracker`

A new singleton (`lib/singletons/play_tracker.dart`) started right after
`QueueStore().init()` in [main.dart:220](lib/main.dart#L220), subscribed to
`MediaManager().audioHandler`. The session logic is a pure fold over signals
(unit-tested); the singleton only wires streams to it.

### 4.1 Signals → meaning

| Signal | Meaning |
|---|---|
| `mediaItem` emits an item whose track key differs from the open session's | close the open session, open a new one |
| same item, position drops from ≥ `duration − 2 s` to ≈ 0 with no seek in flight | repeat-one / replay: close as `completed`, open again |
| `playbackState.playing` true→false | `pauses += 1`; stop accumulating |
| `positionStream` sample while playing | `playedMs += Δpos` **only when** `0 < Δpos ≤ 2 × sample interval` — seeks, stalls and backwards jumps contribute nothing |
| `processingState == completed` (end of queue) | close as `completed` |
| `stop()`, queue cleared, item removed | close as `stopped` |
| a user seek (`seek()` on the handler — expose a tiny `onSeek` hook) | mark "seek in flight" so the replay rule doesn't misfire |
| app paused / hidden / detached | checkpoint the open session (§4.4) |

Duration comes from `MediaItem.duration` once the backend reports it. The
app records **every** closed session as an event; the server decides
`counted`. The app keeps the same rule locally (30 s / 50 %, same constants)
for its own on-device counts, so the two agree.

### 4.2 Outcome

`completed` (reached `duration − 2 s`, or queue end), `skipped` (another
track started first, or user skip / previous), `stopped` (stop, clear,
removal, or a session recovered from a checkpoint after a kill). Outcome and
counting are independent: a skip at 3:00 of a 5:00 track is `skipped` and a
counted play.

### 4.3 Event record

One immutable `PlayEvent` (`lib/objects/play_event.dart`), one JSON line:

```json
{"id":"9f3c…","t":1725400000000,"srv":"home","peer":null,"p":"/music/Radiohead/OK Computer/05 Let Down.flac",
 "h":"7c1e…","ti":"Let Down","ar":"Radiohead","al":"OK Computer","art":"…","dur":299000,
 "pl":299000,"o":"completed","s":"manual","pz":0,"c":true}
```

| Field | Notes |
|---|---|
| `id` | client UUID — the server's idempotency key |
| `t` | start, ms since epoch, device clock |
| `srv`, `p` | the app's identity: server localname + path. `srv` empty for a local-device file |
| `peer` | for a federated server: `federationPeerId` (the peer's id on its parent); the sync layer routes the event to `parentServer` |
| `h`, `ti`, `ar`, `al`, `art`, `dur` | the snapshot: rename-proof key + offline rendering + what the parent needs for a federated play. Needs `hash` added to `queueExtras`; art is the album-art file name from the item's `artUrl` |
| `pl`, `o`, `pz`, `c` | played ms, outcome, pauses, counted (local rule) |
| `s` | `manual` / `shuffle` / `autodj` in phase A2; `auto` / `carplay` once queue items carry an origin extra (follow-up) |

≈ 250–320 bytes per event.

### 4.4 Hard kills

Like `queue.json`'s position checkpoint: the open session is written into the
stats file header on the same debounce and on lifecycle pause; on the next
launch a leftover open session is closed as `stopped` with its checkpointed
`playedMs`. An album listened to in the car and killed by the OS still counts.

### 4.5 Not captured

Nothing-playing / blank items, the restore-parked item before play, renderer
errors. Local-device files *are* captured (device-only). Downloaded copies of
server tracks are captured under their server identity and posted normally.

---

## 5. On-device storage

Three JSON files next to `queue.json`, owned by `PlayHistory`
(`lib/singletons/play_history.dart`), one `WriteChain` each, no new dependency.

| File | Shape | Write pattern | Cap | Worst case |
|---|---|---|---|---|
| `play_history.jsonl` | one event per line, newest last | **append** one line per closed session | **5 000** events (compaction at 6 000) | ≈ 1.6 MB |
| `play_stats.json` | `{v, open, ring, tracks{…}, days{…}, months{…}}` | full rewrite, debounced 5 s + lifecycle flush, temp file + rename | tracks **10 000**; days **730**; months unbounded (~0.5 KB / year) | ≈ 2 MB |
| `play_outbox.json` | `{ "<target localname>": [PlayEvent…] }` | rewrite on change | **2 000** events, **30-day** age-out | ≈ 0.6 MB |
| **total** | | | | **< 4.5 MB hard ceiling** |

A 1 000-track queue.json is already ~0.5 MB; an unbounded raw log would be
~15 MB/year for a heavy listener.

### 5.1 The ring (`play_history.jsonl`)

Append-only, never rewritten in the hot path. The stats header keeps the line
count; past 6 000 a compaction writes the newest 5 000 lines to a temp file
and renames it over the old one, off the main isolate, on the chain.
Aggregates are folded at record time, so compaction loses nothing. Readers
skip a torn last line and any unparsable line. Loaded lazily — only the
History screen and compaction read it.

### 5.2 Aggregates (`play_stats.json`)

- `tracks`: keyed by the NUL-joined `server + path`, value `{n, sk, ms, f, l,
  ti, ar, al, dur, h}` ≈ 200 B. Bounded by distinct tracks played; above
  10 000, evict lowest `(n, l)` down to 9 000.
- `days`: `"2026-09-04" → {n, ms, sk}`; kept 730 days, then folded into
  `months`.
- Top artists / albums are grouped from `tracks` in memory.
- Rewritten whole, but only per closed session (debounced), via temp + rename.
  Loaded once at startup after servers, via `compute` when large; a corrupt
  file is logged and the app continues with empty stats.
- `open` is the checkpoint; `v` the schema version — **forward migration** on
  bump, never a drop, since history is not re-derivable.

### 5.3 Outbox (`play_outbox.json`)

Complete `PlayEvent`s, grouped by the **target** server (the parent for a
federated play), self-contained so ring compaction can't strand them.
Drop-oldest beyond 2 000; drop anything older than 30 days on load and drain.

### 5.4 Cascades

| Event | Effect |
|---|---|
| `ServerManager.removeServer` | purge that localname from ring, tracks and outbox (next to `removeServerQueueItems`). Removing a **parent** also purges its peers' entries and the outbox group addressed to it; `days` are left alone |
| federated peer hidden / missing | keep — same as queued items; its events still target the parent |
| "Clear listening history" | delete all three files + memory; optional second confirm calls `stats/reset` on each server (affects the webapp too) |
| "Keep listening history" off | stop recording, delete the files; server untouched |
| "Send plays to server" off | stop posting, empty the outbox; local recording continues |

### 5.5 Why files, not SQLite

`sqflite` is already linked, but the data fits in a few megabytes, every read
is a scan or group-by over a map already in memory, the write path is one
append per track, and the bounded-growth policy is thirty lines of pure Dart
that unit-tests like everything else. SQLite would add a second persistence
idiom, `sqflite_common_ffi` for tests and the desktop port, and a file that
only shrinks with `VACUUM`. Switch only if the requirement becomes multi-year
raw events on the device — which is what `stats/history` is for.

---

## 6. Server sync (app) — `PlaySync`

`lib/singletons/play_sync.dart`, fed by the tracker; HTTP in `ApiManager`
next to `rateSong` (same leading-slash strip, same 15 s timeout).

### 6.1 Routing an event

| Item | Target | Payload |
|---|---|---|
| server track | its server | `filePath` |
| federated peer track | `server.parentServer` | `filePath` = the peer path, `peerId` = `server.federationPeerId`, `track` = the snapshot |
| downloaded copy | as its server | same |
| local-device file | none | recorded locally only |

Gate: the **target's** `statsVersion ≥ 2` (parsed from `features.stats`,
persisted on `Server`; `_applyFederatedDefaults` nulls it for peers because
the parent's flag governs). No flag → no post, no probing — the same
no-probe contract as the discovery flags. iroh targets post only while
`ServerManager().tunnelServes(target)`; otherwise the outbox.

### 6.2 Draining the outbox

Triggers: a session close, app resume, a `connectivity_plus` change, an iroh
tunnel reaching `connected`, a 5-minute tick while playing. One drain at a
time; per target, oldest first, ≤ 200 events per POST:

| Result | Action |
|---|---|
| `accepted`, `duplicates` | drop |
| `rejected` | drop and log the reason (`unknown-track`, `unknown-peer`, `bad-time`) |
| network error / timeout | stop this drain; back off 1 → 2 → 4 … min, cap 30 min, per target |
| 401 / 403 | stop for that target until its credentials change |
| other 4xx / 5xx | stop this drain, retry on the next trigger |

Offline plays therefore land at their true time, counted by the server's
rule, and scrobbled with their true time. There is no "count only" replay
and no two-phase call.

### 6.3 Consent

Posting is what the webapp does for the same user; default on, with a
Settings toggle whose copy says plays go to *your* server, which forwards to
Last.fm / ListenBrainz only if you linked an account there. The Play
data-safety stance in [PLAY_COMPLIANCE.md](PLAY_COMPLIANCE.md) ("app
activity: sent only to the user's own server") already covers it.

---

## 7. Reading it back

- **Phase A1 (no device storage):** "Recently played" and "Most played" root
  nodes per server next to Rated and Recent
  ([browser_list.dart:323](lib/singletons/browser_list.dart#L323)), from
  `stats/history` and `stats/top?entity=tracks` on v2 servers, falling back
  to `db/stats/recently-played` / `most-played` elsewhere. Shown for a
  federated peer **through its parent** with `origin=peers` filtered to that
  peer. Song Info shows "last played · N plays" from `stats/tracks`, or the
  legacy `play-count` / `last-played` metadata fields.
- **Phase A4:** a History screen over the device store — recently played
  (consecutive duplicates collapsed), period cards (plays, time, top
  tracks / artists / albums, skip rate), an "on this device" chip on Song
  Info. Android Auto / CarPlay get a "Recently played" tab from the same
  store (`AutoBrowse` already has a `recent` root for recently *added*).
- The server's Wrapped view stays a webapp feature; the app can link to it.

---

## 8. Settings

| Key | Default | Effect |
|---|---|---|
| `historyEnabled` | on | record events + aggregates on the device |
| `historySendToServer` | on | post to v2 servers; outbox |
| "Clear listening history" | — | §5.4 |

Caps and thresholds are constants, not settings.

---

## 9. Testing

**Server** (`node:test`; `test/unit` for pure modules, `test/db` with
`applyAllMigrations` on an in-memory `node:sqlite`, `test/integration`
booting a real server like `db-stats.test.mjs`):

- unit: counting rule at the boundaries; `startedAt` window; source /
  outcome enums; cursor encoding; period → `[from, to)` in a given `tz`
  (the existing `wrapped-period-range` test moves here); hour → tz
  re-bucketing incl. DST
- db: V68 migration on a seeded V67 DB — backfilled `track_hash`, rollups
  equal to a recount, `hash-migration` merge of the new columns, `peer_id`
  SET NULL on peer delete
- integration: ingest a batch → counters, rollups, `duplicates` on replay,
  `rejected` reasons, one-transaction atomicity (a bad row rejects only
  itself); federated ingest with a peer row + snapshot; `summary` / `top` /
  `timeseries` / `history` / `tracks` against seeded events; delete
  decrements exactly; retention sweep; the shims still count; `features.stats`
  present; Last.fm forwarding carries the event time (stub the client)

**App** (pure-function tests in `test/objects` / `test/singletons`):

- session fold: start / pause / resume / seek / repeat-one / queue end /
  stop → outcome, `playedMs`, pauses; the Δpos guard
- local counting rule at the boundaries; event JSON round trip; ring reader
  tolerance; `foldEvent`; day → month rollup; eviction order; compaction
- outbox: routing (server / peer → parent / local), grouping, cap, age-out,
  per-result actions, backoff; `statsVersion` gate incl. federated defaults;
  server-removal purge incl. a parent's peers; checkpoint recovery

**Smoke** (`smoke/recipes/play-history.md` + adb script, same shape as the
others): play three tracks (one seeked to the end, one skipped at 10 s, one
at 45 s), kill, relaunch → three ring lines, plays = 2, the server's
`stats/tracks` up by 2, outbox empty. Airplane-mode variant: outbox holds 2,
drains on reconnect at the original times. Federation variant on the
`federation-lifecycle` rig: a peer track counts on the parent with
`peerId`, and never on the peer.

---

## 10. Implementation plan

Two lanes. The app's capture and device store depend only on the handler,
so they proceed in parallel with the server; the sync step joins once the
server lane has shipped through S3.

### Server lane (IrosTheBeggar/mStream)

| Step | Scope | Files | Size |
|---|---|---|---|
| **S1 ingest core** (next) | `stats` config, `ingestPlays()` (validate → resolve path / peer → count → `recordPlayEvents`), `POST /stats/plays`, `hash-migration` merge of the V70 counter columns, tests | `src/stats/ingest.js`, `src/api/stats.js`, `src/state/config.js`, `docs/json_config.md`, `src/db/hash-migration.js`, `test/**` | M |
| **S2 reads** — **done 2026-09-06**, branch `claude/stats-api-reads` (worktree `.claude/worktrees/stats-api-reads`, uncommitted) | `summary`, `top`, `timeseries`, `history`, `tracks`, `periods`; the V70 schema and `src/stats/store.js` (the write primitive S1 builds on); period + `tz` helpers; OpenAPI entries; 9 integration + 24 unit/db tests | `src/db/schema.js`, `src/stats/time.js`, `src/stats/store.js`, `src/stats/queries.js`, `src/api/stats.js`, `src/server.js`, `docs/openapi.yaml`, `test/**` | M |
| **S3 lifecycle** | `features.stats: 2` + ping flag; management routes; retention sweep + `incremental_vacuum`; admin rebuild; the `scrobble-by-filepath` shim with a deprecation log | `src/api/server-info.js`, `src/api/playlist.js`, `src/api/stats.js`, `src/api/scrobbler.js`, `src/api/velvet-stubs.js`, `src/api/admin.js` | S–M |
| **S4 federated origin** | `peerId` + snapshot acceptance, `unknown-peer`, `origin=` filters, `audio-hash` in `renderMetadataObj`; optional `fedFetch` enrichment | `src/stats/ingest.js`, `src/api/db.js`, tests | S |
| **S5 forwarding** | Last.fm timestamp + 14-day guard, ListenBrainz with event time, `stats/now-playing` | `src/state/lastfm.js`, `src/api/listenbrainz.js`, `src/api/stats.js` | S |
| **S6 webapp** | the default webapp posts one completed event per track (`sendBeacon` on unload) instead of the 30 s scrobble, or stays on the shim | `webapp/assets/js/mstream.player.js`, `webapp/alpha/api.js` | S |
| **S7 cleanup release** | delete the shim once the webapp posts events itself | | S |

Ship S1–S3 as one release (the flag must not advertise a partial surface),
S4–S6 as the next, S7 one release later.

### App lane (this repo)

| Step | Scope | Files | Size | Depends on |
|---|---|---|---|---|
| **A0 capability + API** | `Server.statsVersion` parse / persist / federated default; `ApiManager.postPlays`, `fetchStatsHistory`, `fetchStatsTop`, `fetchTrackStats`; `hash` in `queueExtras`; `last-played` parsing | `objects/server.dart`, `singletons/server_list.dart`, `singletons/api.dart`, `objects/metadata.dart`, tests | S | S3 on a dev server |
| **A1 server lists** | Recently played / Most played nodes with legacy fallback; Song Info stats line; hidden for peers unless routed through the parent | `singletons/browser_list.dart`, `screens/browser.dart`, `singletons/api.dart`, `screens/metadata_screen.dart`, ARB strings | S | A0 |
| **A2 capture** — **done 2026-09-06** on `claude/play-history-listening-stats-43fbb7` | `PlayEvent` / `TrackFacts` (JSON line + `toWire`), `PlaySessionFold` (pure, 19 tests), `PlayTracker` on the handler's streams with the `seekEvents` hook and the `play_session.json` kill checkpoint; `hash` in `queueExtras`; wired in `main.dart`. Events stay in memory (`PlayTracker().events` / `recent`) until A3/A4. | M | nothing |
| **A3 sync** | outbox store, `PlaySync` routing / drain / backoff, `historySendToServer`, server-removal purge, smoke recipe | `singletons/play_history.dart` (outbox part), `singletons/play_sync.dart`, `singletons/settings.dart`, `screens/settings_screen.dart`, `singletons/server_list.dart`, `smoke/` | M | A0, A2, server S1–S3 released |
| **A4 device history** | ring + compaction, aggregates + rollups + eviction, `historyEnabled` + clear, History screen, Auto / CarPlay tab | `singletons/play_history.dart`, `screens/history_screen.dart`, `media/auto_browse.dart`, `main.dart` drawer, ARB strings | M–L | A2 |
| **A5 verification** | simulator + emulator smoke, Galaxy S25 + iPhone X device rounds, federation rig variant | `smoke/` | S | A3, A4 |

Order: A2 first (pure, no server needed, and it de-risks the capture rules),
A4 alongside the server lane, then A0 → A1 → A3 once S1–S3 are on a server,
then A5.

---

## 11. Decisions taken here

- Build the app against Stats API v2, not the wrapped routes; hold A3 until
  S1–S3 ship. A2 and A4 start now.
- Counting rule 30 s / 50 %, owned by the server config; the app mirrors it
  locally.
- Federated plays count on the **parent** with origin + snapshot; the peer
  never sees them; the social peer-side counter is out of scope.
- Posting defaults on. Local-device files are never posted.
- Files over SQLite on the device; hourly rollups + retention on the server.
- Ring 5 000 events, tracks 10 000, days 730, outbox 2 000 / 30 days — all
  constants in `play_history.dart`.
- **Status 2026-09-06:** S2 (reads + V70 + store primitive) on
  `claude/stats-api-reads`; A2 (capture) on this branch. Next: S1 ingest,
  then S3, then A0 → A1 → A3.
- **Status 2026-09-11:** the server lane is complete on master (S1–S6 and
  the follow-ups; the Stats API is `features.stats: 2`, shipping as
  mStream **6.27** — the "6.26+" wording above is stale). Two server
  decisions changed from this plan: the legacy scrobble routes are KEPT
  for good (S7 became docs), and ListenBrainz is gone. Two server additions
  help the app: the counters route resolves either hash, and a federated
  play's thin snapshot is completed by the parent from the peer's metadata.
  App: A0, A1, A3 and A4 landed on this branch (`PlayHistory`,
  `PlaySync`, `StatsApi`, `Server.statsVersion`, the Listening page, the
  home node, the Auto/CarPlay tab, Song Info counts, the settings) with the
  smoke round in `smoke/android/play-history.sh` + `smoke/recipes/play-history.md`.
