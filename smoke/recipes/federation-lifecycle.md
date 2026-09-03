# Federation peer lifecycle (by hand, on the rig)

Run `android/federation-rig.sh` with `SMOKE_RIG_KEEP=1` (HTTP mode is the
reliable transport for these; the rig's just-enabled Quick Connect stalls its
first dials), then drive the steps below against the kept servers. Admin calls
use the rig user (`rig` / `rigpw`); a small helper with `tok`, `revoke_key`,
`del_peer`, `add_peer`, `peer_list` lives in the session that ran it — the
routes are `POST /api/v1/auth/login`, `DELETE /api/v1/admin/federation/keys/:id`
(on A), `DELETE|POST /api/v1/admin/federation/peers[/:id]` (on B, the POST takes
`{ticket}` from a fresh mint on A: `POST /api/v1/admin/federation/keys
{name, vpaths:["demo"]}` → `.ticket`).

| Step | Do | Expect (2026-09-02 results) |
|---|---|---|
| Key revoked on the peer | revoke A's key; browse + play the peer | browse fails fast (`db/album-songs → 502` in 54 ms, "Failed To Connect To Server"); a queued track falls back to its download; a failed auto-download raises the generic toast. A's log then repeats `usage flush failed for key id=1: FOREIGN KEY constraint failed` every 15 s — server bug. |
| Peer removed and re-added (new row id) | `del_peer`, `add_peer`; switch to the parent | `[federation] peer-…: peer id 1 → 2 (re-added on rig-b)`, one record, downloads intact. B's first dial with the new key is rejected for ~60 s: A backs off an endpoint after 5 failed handshakes (`BACKOFF_MS`), and the revoked-key attempts count. |
| Parent's last peer removed while browsed | `del_peer`; relaunch with the peer as the default | `default server ready: peer-…` → `[federation] … no longer shared by rig-b — leaving it for the parent` → `[srv] switched to rig-b`; a second relaunch opens on the first selectable server. Manage Servers: "No longer shared by …", row tap → Info, menu = Info + Forget; Forget drops the record and its queued tracks (`[queue] server … removed — dropping 6`), keeps the folder unless ticked. |
| Peer offline, parent up | `kill` A's node; browse the peer | `album-songs → 502 (15108ms)` after B's dial deadline, then the error state; B's bridge recovers by itself once A is back. |
| Cheap taps | search, Artists, Recent, airplane-mode play of a downloaded peer track | `db/artists → 200`, `db/recent/added → 200`, PLAYING from disk. Search needed the home-list fix (the note row hid the search field). |
| Parent outage over Quick Connect, peer track streaming | tunnel-mode config, auto-download off, play, airplane 45 s | `status connected → reconnecting` at the idle timeout; buffer runs out → `[play] iroh recovery: tunnel not ready for peer-… — parked`; on reconnect `iroh tunnel back — resuming parked playback`, PLAYING within 1 s. |
