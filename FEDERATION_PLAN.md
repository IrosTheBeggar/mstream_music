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

### Phase 6 — one tunnel per transport server ✅ done

Groundwork for reaching a peer directly (issue #143): the direct transport
needs a peer's own tunnel next to its parent's, and `ServerManager` was
single-tunnel throughout — one pairing code, one dial chain, one retry
ladder, one probe/kick/watchdog bookkeeping, a queue listener that picked
the first tunnel-carried track, a status strip fed by one value.

**The model.** [`TunnelHandle`](lib/singletons/tunnel_handle.dart) holds one
native tunnel's bookkeeping per *transport* server (a Quick Connect server
today; a directly-reached peer next), keyed by localname in the manager's
`_tunnels` table. Each handle owns its own chain, retry ladder, probe and
watchdog state, so a second tunnel is a second entry, not a second copy of
the lifecycle — and one server's cold dial never holds another's. The
native key a handle was started under is recorded on it (a re-pair swaps
the server's code before the old tunnel is stopped).

**Targets.** The browsed server's transport when that is a tunnel, plus
every tunnel-carried transport the play queue references — the queue
listener now reports the whole set (`setQueueIrohServers`), and each
transport it lets go of is released after `queueReleaseGrace`. `ensureTunnels`
reconciles handles against the targets; `ensureTunnelFor` (re)starts one
server's tunnel on demand, which is what the playback, download and car
paths ask for.

**What stays single.** The status strip shows one value: the browsed
server's tunnel when it is one, else the background playback tunnel in the
worst state (`bannerTargetAmong`, unit-tested) — `TunnelPolicy.showTunnelBanner`
still decides whether that state deserves a strip. Listeners that care about
one server's tunnel (the playback heal watches the parked track's) take
`tunnelTransitions`, so one tunnel's edge can never hide behind another's
state. The one-Quick-Connect-server cap in the add-server screen stays for
now; lifting it is a separate change.

**Log lines** keep their shapes (the smoke scripts grep them) and gain a
`for=<localname>` suffix, since two tunnels would otherwise be
indistinguishable in a Diagnostics export.

### Phase 7 — direct access: a peer over a tunnel of its own ✅ done

The point of issue #143: a peer's bytes no longer cross the parent's home
link twice, the peer stays usable while the parent is down, and there is one
hop less latency. Server side: mStream#943 (guest tokens, the parent's
`access` route, the `mstrfedg1:` guest ticket, `federationDirect` in the
`/api` user block). App side, this phase.

**The mode is the peer's own tunnel port.** `Server.isDirect` is true while
the peer holds a `tunnelPort` of its own — the manager binds it when the
peer's tunnel is up and clears it when that tunnel goes — and every accessor
reads through it: `transportServer` is the peer itself, `effectiveBaseUrl`
its loopback, `authToken` the guest token, `localTokenQuery` its own `__lt`,
`apiUri` the plain path. The three URL builders take the plain `/media` and
`/album-art` shapes for a direct peer and the parent's proxy shapes
otherwise; `albumArtFileFromUrl` already read both. `ownsTunnel` (a Quick
Connect server, or a direct peer) is the "has a tunnel of its own" question
the manager and the strip ask; `isIroh` stays identity.

**The manager.** A federated peer that is browsed or queued is a target of
its own when its parent advertises `federationDirect`, nobody declined this
session, and the parent still lists it — with the parent's tunnel kept as a
target too until the peer is direct (the proxy serves meanwhile). The peer's
handle keys by localname and dials with its guest ticket
(`TunnelHandle.credentialFor`), fetched from the parent on demand
(`GET …/peers/:id/access`, waiting for a Quick Connect parent's tunnel
first) and recorded on the peer with its expiry. A tunnel that is up gets a
fresh ticket swapped in place once three quarters of the lifetime is gone
(`IrohTunnel.setCredential` — same port, the queued URLs survive; only
upcoming items take the new token). A refused guest token is asked for
again rather than treated as a re-pair: at the first dial through one forced
refresh and a quick retry, on a running tunnel through the poll, on a browse
401 at once. A parent that answers `direct: false` puts the peer on the
proxy for the session. When a direct tunnel goes, the queued URLs are
rebuilt against the parent.

**What the user sees.** The strip follows a browsed direct peer's own
tunnel; a peer handle that is still an attempt never puts Repair or Retry on
the strip (the proxy is serving). Log lines: `[federation] <peer>: direct
access issued/unchanged/no direct access`, the peer's own `[iroh] … for=<peer>`
lifecycle with `mode=guest` in the native events.

**Also in this phase: the one-Quick-Connect-server cap is gone.** The native
layer keys tunnels by server and the manager runs one per server, so the
add-server screen and its backstop no longer refuse a second Quick Connect
server. A server that is neither browsed nor queued has no tunnel, so a phone
with several paired servers still runs one most of the time.

**Verification (2026-09-05).** `smoke/android/federation-rig.sh` covers the
direct path (ticket, own tunnel, URLs moved, parent killed mid-track, renewal
in place, a Quick Connect parent released and re-dialed, a revoked key) in
both parent modes; `SMOKE_RIG_SERVERS_ONLY=1` starts a pair for the iOS
rounds. Playback resilience found on the way (the tunnel heal handing a
verified-path failure to the skip walk, two downloads per server) is its own
PR. Galaxy S25: the whole Android smoke suite green on the release
candidate; iOS simulator: the full direct round green; iPhone: needs
Developer Mode for a launched test.

### Phase 8 — direct access hardening ✅ 2026-09-18

Four gaps found while porting Phase 7's rules to the terminal player
(mstream-terminal-player, `docs/ux-contracts/multi-server.md` and the
"Per-server tunnels and guest tickets" plan in its PLAN.md, whose T3 slice
adopts the same 401 rule). Three are app-side, one is a server-side enabler.
Written against `origin/master` at `72501f4`; `feat/windows-desktop` carries
the same functions under the same names. Nothing here changes the wire, the
`TunnelTiming` constants Phase 7 set, or what the strip shows.

**8a — a direct peer's stream 401 refreshes the ticket instead of skipping
the track.** Today `_onPlaybackError` hands a failed direct-peer item to
`_recoverHttpError`, where `_isTransientNetworkError` lists `response code: 4`
as a bad source, so on iOS and web the track is skipped at once; on Android
the generic "Source error" walks the bounded retry ladder and is skipped
after it. Only the browse layer (`singletons/api.dart`, the
`statusCode == 401 && server.isDirect` check) calls `onDirectAuthRejected`,
and the poll (`_maintainDirect`) refreshes only on the device's own clock
(`stale`, `expired`) or a handshake refusal (`rejected`). A guest token the
peer stops honouring before the phone's clock says so — clock skew between
the phone and the peer, an app frozen past expiry before the 2 s poll
wakes — costs a skipped track, and with several of that peer's tracks in a
row the whole run: `_failedSkips` counts them and ends in "Can't play these
tracks — check the files or server." with the connectivity probe saying
online.

The change: in `_onPlaybackError`, before the iroh/http split, a failed
item whose server `isDirect` (its own tunnel is serving, so the transport
is not in question — the *answer* is) asks the stream URL what it thinks:
one `GET` with `Range: bytes=0-0` through the live loopback (an `HttpClient`
the `_probeTunnel` way, `probeLoopbackTimeout` to connect,
`probeResponseTimeout` to answer) and reads the status. 401 or 403 →
`_recoverDirectAuth(server)`: chained on `_switchChain` like
`_recoverIrohPlayback`, throttled per server by `_lastRecoveryByServer`
(10 s), it resets `_failedSkips` (an auth lapse is not a bad source), calls
`onDirectAuthRejected(server)` — which starts returning its
`DirectAccessOutcome` instead of `void`, with a new `throttled` member for
the 60 s gap refusing the attempt — and re-seeds: `issued` → rebuild every
URL (`_withRebuiltUrl` / `_withRebuiltArt`; `authToken` reads the new guest
token) and `_loadAtSpot(_reviveSpot())`, playing again when `_playIntent`
and not `_recentlyInterrupted`; `denied` → `_refreshDirectCredential` has
already released the peer's tunnel, `isDirect` is false, so the same
rebuild yields the parent's proxy URLs and the same re-seed plays the track
through the proxy; `failed` / `throttled` → the original error goes to
`_recoverHttpError`, the walk as today. Other statuses: 2xx → transient (the
walk, with the probed status in the log line); 404 → bad source (skip, as
today); no answer → the walk. This also cures the Android blindness for
direct rows: the status comes from the probe, not from the player's error
text.

The decision is pure — `AudioPlayerHandler.directAuthAction({isDirect,
probedStatus, recovering, skipPending, sinceLastRecovery})` → `refresh | walk
| skip` — and tested the way `healAction` is
(`test/media/tunnel_heal_action_test.dart` is the model;
`test/media/direct_auth_action_test.dart`). Log lines: `[play] direct auth
lapsed for=<peer> (http 401) — refreshing the guest ticket`, then Phase 7's
`[federation] <peer>: direct access issued` and `[iroh] guest credential
refreshed in place (401)`; on a denial `[play] direct access withdrawn
for=<peer> — the proxy takes over`.

**8b — a denial does not hold forever.** `Server.directDenied`
(runtime-only) is set by `_refreshDirectAccess` on `direct: false` and
cleared only by a later grant; `_directWanted` refuses while it is set and
nothing asks again. The parent's `direct-available` edge in
`getServerPaths` re-runs `ensureTunnels`, but `_directWanted` still says no.
A peer upgraded to a minting build, or federation switched back on there,
stays on the proxy until the app restarts — on a phone, days.

The change: `directDenied` becomes `DateTime? directDeniedAt`, and
`TunnelPolicy.directDenialExpired({deniedAt, now})` (pure, beside
`directTicketStale`) says when a denial is old enough to ask again —
`TunnelTiming.directDeniedRetry = Duration(hours: 1)`. An hour, not the
60 s `directRefusedRetryGap`: a refusal is a token problem, a denial is a
build problem, and the access call is one bridge round trip. Two events
clear it outright: the parent's capability refresh seeing
`federationDirectAvailable` go true (the edge that exists), and the
Federation screen's refresh (user intent; wherever it reaches
`_reconcilePeers`). Log: `[federation] <peer>: asking for direct access again
(denied <n>h ago)`. Tests: `tunnel_policy_test.dart` — null, 0, 59 min, 61
min; `server_list`'s denied → not wanted → wanted after the gap, through the
pure rule.

**8c — one peer listed by two parents.** The peers listing carries
`endpointId` (the server's projection: "how a client tells that two parents
list the same server") and the access payload carries it too
(`DirectAccess.endpointId` → `Server.directEndpointId`), but the app keeps
nothing from the listing and keys handles by `localname` — a peer reachable
through two parents is two `Server`s, two picker rows, two guest tickets and
two tunnels to one endpoint. No such setup is known, so only the groundwork
now: parse the listing's `endpointId` in `_reconcilePeers` and persist it on
the peer (`Server.fromJson` / `toJson`, `federated_server_test.dart`
round-trips it). When a listener has two parents, the cheap half is the
tunnel — `TunnelHandle.keyFor` a direct peer by its endpoint id when known,
one handle for both `Server`s, `tunnelPort` bound and cleared on every peer
sharing the id, each parent still supplying its own ticket (tokens are per
key, either one works on the peer). The picker half is a product question
(which parent's row wins; the download folder is per localname) and waits
for that listener.

**8d — the server-side enabler: a per-peer `direct` hint in the peers
listing** (mStream, its own PR). `federationDirect` in `/api/` says the
build has the route and a peer exists; whether a given peer mints is learned
one access call at a time, and 8b's denial state exists only because of
that. The parent already knows: `guestAccessFor` caches successes in
`guestAccess`, and `mintGuestFromPeer` answers `null` when the peer's wall
says 403 or 404. A `guestRefused` map beside the cache (set on the null,
cleared on a success, dropped with `forgetPeerAccess`) lets
`GET /api/v1/federation/peers` project `direct: true | false | null` — a
token is cached, the last mint was refused, never asked. No schema change;
an older server omits the key. App side: `_reconcilePeers` records it,
`_directWanted` treats `false` as denied-now (still aging by 8b) and `null`
as today; `true` still fetches the token through the access route but makes
the first dial certain. Both clients benefit; gated by the key's presence,
the house rule.

**Done (2026-09-18).** Server side: mStream #1003 (`guestRefused` beside
the mint cache, `direct` in the listing, `null` after a 502). App side:
`Server.federationDirectHint` (runtime-only) and
`ServerManager.applyDirectHint`, applied by the reconcile on change —
`true` lifts a denial, `false` files one once and never resets a denial
that aged out, so the hourly re-ask still reaches the parent and refreshes
its memory (a peer upgraded to a minting build is otherwise rediscovered
by nobody) — with `ensureTunnels('direct-hint')` when a denial lifts or
lands. Older servers omit the key and the app behaves as before; the rig's
peer always mints, so the `false` path is unit-tested only.

**Order and size.** 8a first — the wrongly skipped track is the one a
listener meets (M: the probe, the decision, the chain, one test file, one
rig leg). 8b next (S: a field, a pure rule, a constant, two tests). 8c's
parsing now (S), its dedupe later. 8d when the server PR lands (S on the
app side; the server half carries its own test in mStream's federation
suite).

**Verification.** `smoke/android/federation-rig.sh` gains a leg between the
renewal and the revoke: a short guest TTL on A
(`MSTREAM_TEST_FED_GUEST_TTL_MS`, the knob `federation-guest.js` reads), B
taken down after the ticket is issued so the phone's scheduled renewal at
three quarters fails (`directRefreshFailedAt`, next try in five minutes), B
back up once the token has lapsed, then a track change to another A track →
expect `direct auth lapsed … (http 401)`, `direct access issued`, `guest
credential refreshed in place (401)`, the new track playing, and no
`playback error — skipping track` in between. The same leg on the iOS
simulator round (`SMOKE_RIG_SERVERS_ONLY=1`). 8b is unit-tested only until a
peer can be upgraded under the rig.

**Done (2026-09-18) — 8a, 8b, 8c.** 8a as planned, with one refinement:
the loopback is asked about the URL as it would be built *now*
(`_withRebuiltUrl`), not the one the player tried, so a ticket renewed
under a playing item probes clean and takes the walk's fresh-URL reload
instead of a needless round trip through the parent. The decision is one
pure function called twice (`directAuthAction` — `probed` false for the
gate, true for the verdict), the probe is `probeStreamStatus`, the
recovery `_recoverDirectAuth`, chained and guarded like the iroh one;
`onDirectAuthRejected` and `_refreshDirectCredential` report their
`DirectAccessOutcome`, with `skipped` for an attempt not made. 8b:
`Server.directDeniedAt`, `TunnelPolicy.directDenialExpired`,
`TunnelTiming.directDeniedRetry` (an hour), and
`ServerManager.forgiveDirectDenials` on the parent's direct-available edge
and the Federation screen's load. 8c: `Server.federationEndpointId` from
the listing, on new and existing peers, persisted. Tests:
`test/media/direct_auth_action_test.dart`, `test/media/stream_probe_test.dart`
(a local `HttpServer`), the new group in `direct_access_test.dart`, the
round trips in `federated_server_test.dart`. The rig's lapse leg
(`SMOKE_RIG_LAPSE`, on by default with the TTL) is written and has not run
on a phone yet — the Galaxy and iPhone rounds are the next step.

**Galaxy S25 (2026-09-18), three rig runs.** The first: 17 pass, 0 fail,
the lapse leg skipped — the peer's log had the three "jwt expired" 401s,
but on Android the idle park lands a millisecond before the error callback,
so the tunnel heal's park trigger took the failure first, re-seeded with
the same expired token, and `_onPlaybackError` stepped aside as "already
recovering"; the player sat silent until the poll renewed. So the renewal
lives in one helper (`_renewLapsedGuestToken`) that both paths call: the
heal probes and renews before it re-seeds a direct peer's parked track, and
the error path keeps doing the same for the orderings where it gets there
first (iOS). The second: 20 pass, 1 fail — the heal saw the 401 and asked,
and `onDirectAuthRejected` answered `skipped`: the poll's failed attempt
55 s earlier sat inside the 60 s refusal gap. A failed attempt is exactly
when the gap must not count (the parent may be back), so
`TunnelPolicy.directAuthRefreshDue` holds the gap only after an attempt
that handed a ticket out. The third: **21 pass, 0 fail, 0 skip** — the
whole lapse in 70 ms: park, probe 401, ticket issued, credential swapped
in place (`(401)`), reload, ready, no track skipped, and the revocation
leg unchanged. Quick Connect mode (`SMOKE_RIG_IROH=1`): **26 pass, 0 fail,
0 skip** — the parent reached over its own tunnel, released once the peer
went direct, re-dialed for the renewal, and re-dialed again inside the
playback path's refresh after the lapse (the failed renewal there is the
parent's tunnel not coming up, which the rig's lapse leg now recognises).

**iPhone (iPhone X, iOS 16.7.16, release build), one hand-driven round
against `SMOKE_RIG_SERVERS_ONLY=1` servers, read from the peer's log and
the app's Diagnostics share.** Direct access holds up on iOS: the ticket
is fetched at launch for a restored peer queue, the peer's own tunnel is up
in 3.2 s on a direct path, the restored queue is rebuilt onto it, and
three albums played through without a gap. A lapsed token was renewed
twice by two different paths and never surfaced to the listener: (1)
tapping an album sends `album-songs` over the direct tunnel first, the
401 hit the browse hook, and the ticket was renewed in 47 ms — with the
poll's failed attempt only 8 s earlier, which the old gap rule would have
refused (8b's `directAuthRefreshDue`, exercised for real); (2) a seek to
the end of a track advanced the queue onto a track AVPlayer had preloaded
under the old token, and the refusal landed on the *preload of the item
after next* — silent to the player, no error event — which the poll had
re-tokened before it was due. So on iOS the playback-path renewal (8a)
was never reached in normal queue play: AVPlayer's preload-ahead absorbs
the lapse, and the browse hook or the poll renews first. No regression,
and `[play] playback error` never appears in the session. Two tooling
findings on the way, both in `smoke/README.md`: a `flutter run` app on
this iOS 16 device halts for good if it is backgrounded and resumed
(ios-deploy's lldb loop ignores a later stop with no reason), and an
Xcode 26 debug-dylib build crashes at a cold home-screen launch in the
background-downloader plugin's registration (nil messenger) — a release
build is the one to hand-drive.

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

**8a probes on the failure path only.** A direct peer whose loopback answers
slowly holds the decision for `probeResponseTimeout` (6 s) before the walk
takes over — bounded, and only after a load already failed. 8d's `direct`
key is new: an older server omits it and the app behaves as today.
