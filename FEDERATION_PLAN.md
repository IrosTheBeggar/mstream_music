# Federated server support

Bringing mStream's federation feature to the mobile app: browse and play a
paired peer's library from inside the app, using the existing multi-server
machinery rather than a parallel one.

Server side is already done and merged:

| PR | What it added |
|---|---|
| (pre-existing, 6.24.0) | `GET /api/v1/federation/peers/:id/stream/*path` — peer audio, ranges forwarded |
| [#927](https://github.com/IrosTheBeggar/mStream/pull/927) | the browse half: peers projection, API proxy, art proxy, `federationBrowse` ping flag |
| [#932](https://github.com/IrosTheBeggar/mStream/pull/932) | layered `GET /api/`, added to the federation allowlist |
| [#934](https://github.com/IrosTheBeggar/mStream/pull/934) | `/api/` back behind the auth wall; version returns to every response |

---

## 1. What the server offers

### Routes reachable from the app

| Route | Purpose |
|---|---|
| `GET /api/v1/federation/peers` | `{peers:[{id,name,lastSeen,lastStatus,useDiscovery}]}` — any logged-in user, never credentials |
| `ALL /api/v1/federation/peers/:id/api/<local-path>` | one allowlisted read, executed on the peer |
| `GET /api/v1/federation/peers/:id/art/<file>?compress=` | that peer's album art |
| `GET /api/v1/federation/peers/:id/stream/<path>` | that peer's audio |

Gated by the ping flag `federationBrowse` (federation enabled **and** at least
one peer). Flags, never probes — the house rule on both sides.

### Three constraints that shape everything

**The path prefix is literal.** `/api/v1/federation/peers/{id}/api` + the
normal local path, so `…/peers/3/api/api/v1/db/albums`. The doubled `api` is
correct.

**Query params are dropped.** The API proxy forwards none; art forwards only
`compress`. Deliberate — the app's `?token=` is the *parent's* JWT and
forwarding it would hand a peer a working credential for the parent. Every
call the allowlist covers puts its params in a POST body or the path, so
nothing is lost today. Any future call that relies on a query string will
silently lose it.

**The allowlist is the entire feature surface**
([`federation-auth.js`](https://github.com/IrosTheBeggar/mStream/blob/master/src/api/federation-auth.js)).

Reachable: `GET /api` · `GET /api/` · `db/status` · `db/metadata{,/batch}` ·
`db/artists` · `db/artists-albums` · `db/albums` · `db/genres` ·
`db/genre-songs` · `db/album-songs` · `db/recent/added` · `db/search` ·
`file-explorer{,/recursive,/m3u}` · `GET /media/*` · `GET /album-art/*`

Not reachable, so the app must hide it: **all `playlist/*`** · `db/rated` ·
`rate-song` · **`db/random-songs` (Auto DJ is impossible)** · `/transcode` ·
`/api/v1/lyrics` · `/api/v1/share` · `torrent/*` · `album-art/search` ·
**`/api/v1/ping`** (403s a federation key — pinned by test).

### `GET /api` is the one capability call

Post-#934, a federation key gets the full response: `server` (version),
`features.{discoveryReady, discovery, discoveryP2p, transcode,
supportedAudioFiles}`, and a key-scoped `user.{username, admin, federation,
vpaths, noMkdir, noUpload, noFileModify, federationDiscovery, vpathMetaData}`.

Because ping 403s a federation key, this is the *only* capability route for a
peer. Call it as `/api` without the trailing slash — both spellings are
allowlisted, but the bare form sidesteps how Express 5's `*path` wildcard
hands a trailing slash to the proxy's segment join.

> **Trap:** a peer's advertised capability is not what the app can reach. A
> peer may report `features.transcode` or `features.discovery: true` while
> `/transcode` and `/api/v1/discovery/*` stay off the allowlist. Federated
> servers force `transcodeAvailable = false` and all discovery flags false
> regardless of the payload. Read through only: `server`, `user.vpaths`,
> `user.vpathMetaData`, and the permission flags.

---

## 2. Architecture: a federated server is a virtual `Server`

The app's entire request layer funnels through three functions:

- [`Server.apiUri`](lib/objects/server.dart) — 25 call sites
- [`buildServerStreamUrl`](lib/util/stream_url.dart)
- [`buildAlbumArtUrl`](lib/util/stream_url.dart)

Teach those three about federation and browse + playback follow, the same way
iroh's loopback rewrite already works.

```dart
String? federationParent;   // parent server's localname
int? federationPeerId;      // peer id on that parent
bool federationMissing;     // parent no longer lists this peer
bool get isFederated => federationParent != null;
```

- `effectiveBaseUrl` → the parent's, so **an iroh parent works with no extra
  code** (the request rides the parent's loopback tunnel).
- `jwt` → the parent's, always.
- `apiUri(loc)` → `parent.apiUri('/api/v1/federation/peers/$id/api$loc')`,
  which also picks up the `__lt` loopback token for an iroh parent.
- stream → `…/peers/{id}/stream{p}?app_uuid=…&token={parent.jwt}{parent.localTokenQuery}`
- art → `…/peers/{id}/art/{encodeComponent(artFile)}?compress={c}&token=…`
  (art files are single-segment hashes — `/album-art/:file` — so
  one-component encoding is right).

Setting `transcodeAvailable = false` routes `buildServerStreamUrl` to `/media`
through its **existing** branch. The one capability that is genuinely gone
needs no new code path.

### Parent link

Held as a runtime-only `Server? parentServer`, resolved by `ServerManager`
after load and on every reconcile — matching the existing runtime-only pattern
(`tunnelPort`, `tunnelToken`) and avoiding an import cycle between
`objects/server.dart` and `singletons/server_list.dart`. When the link is
missing the accessors return an unroutable origin so a stray request fails
fast, exactly as `effectiveBaseUrl` already does for a null `tunnelPort`.

### `localname`

Keys both queue restore (`byLocalname`) and the download directory
`media/<localname>`, so it must be stable, unique, and filesystem-safe.
Federated servers get their **own independent** localname, generated once at
first discovery and persisted forever — *not* derived from the parent's,
because the parent's localname is user-editable and a rename would otherwise
force a download-folder migration for every child.

`federationParent` stores the parent's localname, so the edit path in
`add_server.dart` must update children when a parent is renamed.

### Lifecycle: persist a stub, reconcile from the parent

Peers are the parent admin's data, but the app cannot be purely derived —
`QueueStore` resolves tracks by `localname` at launch, before any network
call. So:

- Persist a minimal record in `servers.json` (localname, name, parent,
  peerId) so resolution works cold and downloads keep their folder.
- After each successful capability refresh of a parent advertising
  `federationBrowse`, fetch `GET /api/v1/federation/peers` and reconcile: add
  new, rename changed, **flag** vanished peers rather than deleting them (a
  queued or downloaded track would otherwise lose its home). Hidden from the
  picker; deleted only on explicit user action or when the parent goes.
- Removing a parent removes its children.

---

## 3. Phases

### Phase 1 — model + transport (no UI) ✅ done

1. `Server`: federation fields, `isFederated`, parent-aware
   `effectiveBaseUrl` / `jwt` / `apiUri` / `localTokenQuery`, JSON round-trip.
2. `stream_url.dart`: federated stream + art URL rewrites.
3. `ServerManager`: parent linking, `refreshFederatedPeers` + reconcile,
   federated branch in the capability refresh (one `GET /api` call),
   cascade delete with the parent, rename propagation.
4. Unit tests — URL building is pure and cheap to pin.

### Phase 1b — migrate capability refresh to `GET /api` ✅ done

Now that `/api/` carries version *and* capabilities for every caller type
including federation keys, `getServerPaths` moves off `/api/v1/ping`
entirely and uses one call for regular and federated servers alike. This
folds the federated path into the normal one instead of adding a sibling,
and drops the separate `fetchServerVersion` round trip since the version
rides along.

Two wrinkles:

- `/api/` deliberately omits `playlists` (a resource, not a capability) —
  read them from `/api/v1/playlist/getall`, which `ApiManager` already
  wraps. Federated servers skip this: playlists are off the allowlist.
- `/api/` omits `discoveryPath`, a ping-only legacy field that #934 notes is
  always identical to `discovery` on any build carrying this code — so
  `discoveryPathAvailable` tracks `features.discovery`.

Older servers (pre-#932) return the old flat `/api/` shape — version only, no
`features`/`user`. Keep the ping call as the fallback when the response has no
`features` key, so the app still works against every released server.

### Phase 2 — the server picker ✅ done

The picker at `main.dart` iterates `serverList` by index, so federated servers
appear the moment they are in the list. Refinements:

- render federated rows indented, with a distinct icon and a "via &lt;parent&gt;"
  subtitle
- add `Server.displayName` — a federated row has no meaningful `url` (also
  used by the app-bar subtitle)
- the `throwErr: true` capability call on select must take the federated path
  instead of throwing

`goToNavScreen()` builds seven fixed rows — drop **Playlists** and **Rated**
for a federated server, keeping File Explorer / Albums / Artists / Recent /
Local Files, plus a read-only note mirroring the webapp's left-nav
explanation.

### Phase 3 — capability gates

`isFederated` checks for: Auto DJ (picker + `toggleAutoDJ`), star rating, the
lyrics badge, share, and the torrent panel. `manage_server.dart` offers
federated rows nothing but "Forget" — no edit, no pairing code, no storage
settings.

**`.m3u` rows.** The webapp hides them on a peer (mStream 9dfc3bfb): its row
handlers called local APIs with a peer path, which poisoned the breadcrumb or
loaded a same-named *local* playlist. The app's equivalents thread the server
through (`makeServerCall(useThisServer, …)`) and `POST
/api/v1/file-explorer/m3u` is allowlisted, so it may well work — but this is
the one place the webapp found a path-namespace collision, so verify it on a
peer before deciding to keep the rows.

### Phase 4 — the `isIroh` / transport split (blocks release on iroh)

Bigger than "verify playback". A federated server has
`connectionType == 'http'`, so **`isIroh` is false for it even when its parent
is iroh** — and every site that asks "is this an iroh server?" in order to
apply loopback handling will answer wrong for a peer of an iroh parent.

There are ~29 `isIroh` call sites and they are asking two different questions:

- **"Is this server itself an iroh server?"** — config and identity: the
  one-iroh-max rule, the pairing-code menu item, the edit form, the whole
  tunnel lifecycle in `ServerManager`. These stay on `isIroh`, untouched.
- **"Do this server's bytes travel over a loopback tunnel?"** — transport.
  For a peer of an iroh parent the answer is *yes*, and these are wrong today.

The fix is to make that distinction explicit on `Server` — a `transportServer`
getter (`parentServer ?? this`) and an `isIrohTransport` built on it — then
audit each site for which question it is asking. `getServerPaths` already
computes exactly this as a local; it wants promoting to the model.

Triage list for the transport half (from a grep — confirm per site, this is
not a find-and-replace):

| Site | Why it matters |
|---|---|
| `cast_origin.dart:23` `irohServerFor` | hands a DLNA renderer an unreachable `127.0.0.1` URL |
| `audio_stuff.dart` ×5 (231, 890, 905, 1378, 2407) | URL rebinding and tunnel waits on the playback path |
| `downloads.dart:231` | "only loopback URLs rotate this way" — a federated URL through an iroh parent IS one, and needs the same stale-port rotation |
| `queue_store.dart:340`, `playlist.dart:89` | art URL rebinding |
| `api.dart:148` | the retry-on-tunnel-drop branch in `makeServerCall` |
| `auto_browse.dart:810` | tunnel-serving check |

**Blast radius is bounded but the failure mode is nasty.** Only peers of an
*iroh* parent are affected; with a plain HTTP parent every one of these sites
answers correctly today. But iroh is the roaming transport, so it is a real
configuration — and the symptom is that browsing works fine while playback,
casting and downloads break in ways that do not point at federation.

Treat this as **blocking release for iroh users**, not as cleanup. Phases 2
and 3 are shippable against an HTTP parent without it.

Also in this phase:

- queue restore across a restart (a federated server must resolve by
  localname before `QueueStore.init`)
- downloads: `/media` and ranges are allowlisted and `_ensureDownloadDir` now
  covers both entry points, so this should work once the URL is rewritten —
  verify on a peer.

### Phase 5 — optional: make Discover leads actionable

`/api/v1/discovery/federation/similar` already returns `peer:{id,name}` on the
wire, but `DiscoveryLead` parses only the name. Parsing `peer.id` lets a
"From your peers" row become "Open on &lt;peer&gt;" → search that federated
server. Leads carry no filepath, so it is a search hop, not direct playback.

---

## 4. Risks

**Peer ids are parent-side rowids.** An admin who removes and re-adds a peer
gets a new id, silently orphaning queue entries and the download folder.
Reconciling by name as well as id mitigates it. Decide before Phase 1 fixes
the localname format.

**Stale server comment.** The allowlist comment at `federation-auth.js:42-43`
still says the route "is mounted before the wall and resolves the key itself"
— untrue as of #934, though the both-spellings justification below it still
holds. Server-side nit, not an app blocker.
