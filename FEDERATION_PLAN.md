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

### Phase 3 — capability gates ✅ done

Every surface whose route the federation allowlist refuses is gated on
`isFederated`, at the track level where a peer's track can sit in a queue
browsed from another server:

- **Auto DJ.** The panel's server dropdown skips peers; the queue-header
  toggle refuses a peer with a snack ("Auto DJ can't run on a shared
  server"); CarPlay's toggle and the car's Shuffle All refuse with a log
  line; and the handler's `setAutoDJ` action is the backstop for every entry
  point. A peer cannot host the DJ — random-songs is off the allowlist and
  its paths mean nothing to the parent.
- **Track sheet.** No rating badge and no lyrics badge for a peer's track,
  and no Add to playlist (the parent would store a path it cannot resolve).
  Download stays. The metadata screen's lyrics chip is gated the same way.
- **Share** blocks a queue of peer tracks with its own message, before the
  iroh "no public URL" block.
- **Torrent.** The add-torrent screen offers only the user's own servers.
- **Car root.** A peer's root has no Shuffle All and no Playlists
  (`AutoBrowse.rootTabs`, unit-tested).
- **Manage servers.** A peer row shows its name, a hub icon and "via
  <parent>" (or "No longer shared by <parent>"), and offers Info plus
  Hide/Show; no Edit, no pairing code. **The Forget decision:** peers are the
  parent admin's data, so a removed peer would come back on the next
  reconcile. Hiding (`federationHidden`, persisted, honoured by the picker
  and the car via `Server.isSelectable`) is the durable choice while the
  parent lists it; Forget appears only once the parent has stopped listing
  it (`federationMissing`). Hiding the browsed peer moves the browser to its
  parent first.

**`.m3u` rows** — verified on the rig with a playlist file in the peer's
library (see the Phase 3 PR).

### Phase 4 — the `isIroh` / transport split ✅ done

Landed in two steps. The rebase of Phases 1–2 onto the launch/tunnel work
found the first site in the manager itself: the tunnel target keyed on the
browsed server's own type, so selecting a peer of an iroh parent *released*
the parent's tunnel and every peer request resolved to the unroutable
origin — browsing failed, not just playback. That commit added the
primitives and moved the manager's tunnel decisions onto them; this phase
covers everything else.

**The distinction, on the model.** `Server.transportServer` is the parent
for a federated server and the server itself otherwise (null only for a
peer whose parent is not linked); `isIrohTransport` asks whether requests
for this server ride a loopback tunnel. `isIroh` stays the identity
question — the pairing-code menu, the one-iroh cap, the edit form, the
share block, the retry timer and the rotate-code path.

**The manager answers for the transport.** `tunnelAssignedTo`,
`tunnelServes`, `awaitTunnelReady` and `reverifyTunnel` resolve the server
they are handed to its transport, so every caller on the playback path —
the load-failure recovery, the parked-track heal, the DJ gates, the Android
Auto browse wait, downloads — is right with whichever server it holds.

**Sites moved to the transport question.** The queue's tunnel-follows-queue
listener; `isIrohDJ` / `shouldDeferDJPick` / the parked-pick reverify; the
art rebuild after a tunnel bind (`_withRebuiltArt`); `_phoneIsCastOrigin`;
`cast_origin.irohServerFor` (returns the transport, so a peer track is
relayed through `LocalMediaServer` like any tunnel track), `irohLoopbackUri`
and `rebindLoopbackArt` (the parent's port + token); `downloads`' stale-port
rotation; `makeServerCall`'s tunnel-drop retry. Queue restore and
`Playlist.toMediaItem` re-origin a persisted art URL through
`albumArtFileFromUrl`, which reads both URL shapes — a server's own
`/album-art/<file>` and a peer's `…/peers/<id>/art/<file>`. The stream URL
rebuild needed nothing: `buildServerStreamUrl` was already federation-aware,
and the rebuild walks every queue item.

**Verified** with `smoke/android/federation-rig.sh` in tunnel mode: a peer of
a Quick Connect parent reconciles, browses and plays; the parent's tunnel
survives selecting the peer and a switch to a standard server while a peer
track plays; and after a relaunch the restored peer track plays on the
parent's fresh port. Unit tests pin the extractor, the peer art rebind, and
the queue-restore re-origin. Casting a peer track through the LAN relay is
covered by the same code path as an iroh server's and is the one piece
not run on a renderer.

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
