//! mStream iroh remote-access tunnel — Android client core.
//!
//! A faithful port of the server's reference client `scripts/mstream-iroh-client.mjs`
//! (mStream PR #643). The wire protocol is FROZEN by that PR; this matches it
//! byte-for-byte:
//!
//!   * Pairing code = base64url(JSON{ t: <EndpointTicket>, s: <connectSecret b64> }).
//!   * ALPN = "mstream/tunnel/2".
//!   * Bind an ephemeral endpoint, wait for our home relay (`online`) BEFORE dialing.
//!   * Handshake on the FIRST bi-stream: write the 32-byte secret, expect ASCII "OK".
//!   * Then one bi-stream per inbound local TCP connection; raw byte pipe both ways
//!     (one bi-stream == one TCP connection → full HTTP semantics incl. range/seek).
//!
//! The app points its base URL at `http://127.0.0.1:<local_port>` and is otherwise
//! unchanged; mStream's JWT auth still gates the API inside the tunnel.
//!
//! The Dart/Android entry points live in [`ffi`] (owned Tokio runtime + start/stop);
//! [`c_api`] exposes those over a C ABI for `dart:ffi`.

pub mod c_api;
pub mod ffi;

// iOS-only dyld shim: netdev hard-links an iOS 18+ Network.framework symbol,
// which aborts the app at launch on iOS 15–17. See apple_compat.rs.
mod apple_compat;

// Android-only JNI entry point that registers the app Context with ndk_context
// (iroh needs it for network monitoring; without it the first call panics).
#[cfg(target_os = "android")]
mod android_init;

use std::collections::VecDeque;
use std::sync::atomic::{AtomicBool, AtomicU32, AtomicU8, AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use anyhow::{anyhow, bail, Context, Result};
use base64::Engine;
use iroh::endpoint::{presets, Connection, RecvStream, SendStream};
use iroh::{Endpoint, EndpointAddr, Watcher as _};
use iroh_tickets::endpoint::EndpointTicket;
use iroh_tickets::Ticket as _;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::tcp::{OwnedReadHalf, OwnedWriteHalf};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::{watch, Notify};
use tokio::task::JoinHandle;
use tokio::time::Instant;

/// ALPN both ends must present. Bump if the server bumps `mstream/tunnel/N`.
pub const TUNNEL_ALPN: &[u8] = b"mstream/tunnel/2";
/// The FEDERATION endpoint's ALPN (mStream `src/state/federation.js`) — what a
/// guest ticket dials. The same TCP-over-QUIC bridge sits behind it; only the
/// credential on the first bi-stream differs (a guest token, not a secret).
pub const FEDERATION_ALPN: &[u8] = b"mstream/federation/1";

const READ_CHUNK: usize = 64 * 1024;
const ONLINE_TIMEOUT: Duration = Duration::from_secs(8);
const CONNECT_TIMEOUT: Duration = Duration::from_secs(25);
// Deadline for the post-connect secret handshake. Without it, a half-dead server
// that accepts the bi-stream but never writes "OK"/FIN parks read_to_end forever
// (no idle timeout fires while it answers keep-alives), freezing the supervisor.
const HANDSHAKE_TIMEOUT: Duration = Duration::from_secs(10);
const HANDSHAKE_RESP_LIMIT: usize = 8;
const SECRET_LEN: usize = 32;
/// Highest pairing-code schema version this client understands. The pairing-code
/// version (the `mstr<V>:` envelope) is independent of the tunnel ALPN version.
const PAIRING_VERSION: u32 = 1;
/// Highest federation GUEST ticket version (`mstrfedg<V>:`) this client
/// understands — mStream `docs/federation-guest-ticket.md`.
const GUEST_TICKET_VERSION: u32 = 1;
/// The peer reads at most this much on the first bi-stream (mStream's
/// HANDSHAKE_LIMIT), so a longer guest token could never be accepted.
const GUEST_TOKEN_MAX: usize = 2048;

// A request that lands while the supervisor is mid-reconnect waits (bounded)
// for the swapped-in connection instead of hard-failing: ExoPlayer's read
// timeout is 8s and the app's API calls allow 15-20s, so a 1-3s reconnect is
// invisible to them. Past the deadline the socket is drained and closed
// cleanly (FIN, not RST) so the caller sees a plain connection close.
const BRIDGE_WAIT_FOR_CONN: Duration = Duration::from_secs(10);
// Sleep between failed reconnect attempts, doubling from 1s. Short on
// purpose: the sleep is cut even shorter by an app kick or by the home relay
// coming back (see wait_backoff), so it rarely matters — while a long cap was
// what made a reconnect trail service return by up to ~65s on real cellular
// (Galaxy S25, 2026-09-01: 108s from the drop, 65s after service was back).
const RECONNECT_BACKOFF_MAX: Duration = Duration::from_secs(10);
// The loopback listener is re-bound in place (same port) when it dies — iOS
// kills it during app suspension while the QUIC connection survives (iPhone
// X, 2026-09-01) — and on an app kick. The old socket is released when its
// accept task is aborted; a few short retries cover that window.
const REBIND_ATTEMPTS: u32 = 12;
const REBIND_DELAY: Duration = Duration::from_millis(250);
// Bounded native event ring the app drains into its diagnostics log.
const EVENT_RING_CAP: usize = 64;

// Graceful teardown: on stop/switch, let in-flight bridges finish before closing
// the connection, bounded so a long media stream can't hold the old endpoint open.
// Also caps endpoint.close() (see drain_and_close), so total background teardown is
// drain + close ≈ up to 2×DRAIN_TIMEOUT before the old UDP socket is released.
const DRAIN_TIMEOUT: Duration = Duration::from_secs(3);
const DRAIN_POLL: Duration = Duration::from_millis(50);

// Loopback hop auth: every local TCP client must present `__lt=<local_token>` in
// the first HTTP request line (the app appends it to loopback URLs). The shim
// PEEKs (does not consume) the request line and drops connections without the
// token, so other apps on the device can't use 127.0.0.1:<port> as a proxy.
const LOCAL_TOKEN_PEEK_MAX: usize = 8 * 1024;
const LOCAL_TOKEN_TIMEOUT: Duration = Duration::from_secs(10);

/// Tunnel status, shared with the C ABI / Dart (keep values in sync with
/// `lib/native/iroh_tunnel.dart`).
pub const STATUS_CONNECTING: u8 = 0;
pub const STATUS_CONNECTED: u8 = 1;
pub const STATUS_RECONNECTING: u8 = 2;
pub const STATUS_REJECTED: u8 = 3; // wrong/rotated secret — re-pair needed
pub const STATUS_DOWN: u8 = 4;

/// Selected-path kind, shared with the C ABI / Dart (`IrohPathKind`).
pub const PATH_UNKNOWN: u8 = 0;
pub const PATH_DIRECT: u8 = 1; // hole-punched direct path
pub const PATH_RELAY: u8 = 2; // routed via a relay server

/// State shared between the accept loop, the per-socket bridges, and the reconnect
/// supervisor. The live [`Connection`] is swapped in place on reconnect (it's a
/// cheap Arc handle to clone), so bridges always pick up the current one.
struct Shared {
    endpoint: Endpoint,
    /// Where to dial. Replaceable: a credential refresh may carry a newer
    /// ticket for the same server (its relay / direct addresses move).
    addr: Mutex<EndpointAddr>,
    alpn: &'static [u8],
    kind: PairingKind,
    /// What the first bi-stream carries — the connect secret, or a guest
    /// token. Replaceable in place, see [`Tunnel::set_credential`].
    payload: Mutex<Vec<u8>>,
    conn: Mutex<Connection>,
    status: AtomicU8,
    /// Same value as [`Shared::status`], as a watch channel so bridges can
    /// await the next status change instead of polling.
    status_tx: watch::Sender<u8>,
    /// In-flight TCP⇆bi-stream bridges, so teardown can drain them gracefully.
    active_bridges: AtomicUsize,
    /// Random per-tunnel token the local HTTP client must echo as `__lt=<token>`,
    /// so only this app (not other apps on the device) can use the loopback proxy.
    local_token: String,
    /// The loopback port, fixed for the tunnel's lifetime: the accept loop
    /// re-binds it in place when the listener dies, so the app's URLs stay valid.
    local_port: u16,
    /// The accept task, replaceable: a kick aborts it (dropping the listener)
    /// and spawns a fresh one on the same port.
    accept: Mutex<Option<JoinHandle<()>>>,
    /// The reconnect supervisor, replaceable too: it exits on a rejected
    /// handshake, and a credential refresh spawns a fresh one on the same
    /// port ([`Tunnel::set_credential`]).
    supervisor: Mutex<Option<JoinHandle<()>>>,
    /// App kick: wakes a supervisor that is sleeping out a backoff.
    kick: Notify,
    /// Native events for the app's diagnostics log (drained by the status poll).
    events: Mutex<EventRing>,
    started: Instant,
    /// Bridges that gave up waiting for a connection / were rejected at the
    /// loopback token check, reported in the drained events when they change.
    bridges_open_failed: AtomicU32,
    bridges_token_rejected: AtomicU32,
    reported_open_failed: AtomicU32,
    reported_token_rejected: AtomicU32,
}

/// Bounded ring of native events (newest last). `push` drops the oldest past
/// the cap and counts the drops so the app can see the ring overflowed.
struct EventRing {
    lines: VecDeque<String>,
    dropped: u32,
}

impl EventRing {
    fn new() -> Self {
        EventRing {
            lines: VecDeque::with_capacity(EVENT_RING_CAP),
            dropped: 0,
        }
    }
    fn push(&mut self, line: String) {
        if self.lines.len() >= EVENT_RING_CAP {
            self.lines.pop_front();
            self.dropped += 1;
        }
        self.lines.push_back(line);
    }
    /// Everything since the last drain, one event per line; None when empty.
    fn drain(&mut self) -> Option<String> {
        if self.lines.is_empty() {
            return None;
        }
        let mut out = String::new();
        if self.dropped > 0 {
            out.push_str(&format!("({} older events dropped)\n", self.dropped));
            self.dropped = 0;
        }
        for l in self.lines.drain(..) {
            out.push_str(&l);
            out.push('\n');
        }
        Some(out)
    }
}

impl Shared {
    fn set_status(&self, s: u8) {
        self.status.store(s, Ordering::Relaxed);
        let _ = self.status_tx.send_replace(s);
    }
    /// Record a native event (with seconds since bind) for the app's log and
    /// mirror it to the platform log (logcat on Android).
    fn event(&self, msg: impl AsRef<str>) {
        let line = format!("+{:.1}s {}", self.started.elapsed().as_secs_f32(), msg.as_ref());
        platform_log(PLATFORM_LOG_INFO, &line);
        if let Ok(mut ring) = self.events.lock() {
            ring.push(line);
        }
    }
    /// Whether any home relay is currently connected — the discriminator
    /// between "dead zone" (leave the supervisor alone) and "relay fine but the
    /// dial keeps failing" (worth a fresh endpoint) for the app's watchdog.
    fn relay_online(&self) -> bool {
        let mut w = self.endpoint.home_relay_status();
        w.get().iter().any(|r| r.is_connected())
    }
    /// Drain the events ring, appending the bridge counters when they moved.
    fn drain_events(&self) -> Option<String> {
        let mut out = self.events.lock().ok().and_then(|mut r| r.drain());
        let of = self.bridges_open_failed.load(Ordering::Relaxed);
        let tr = self.bridges_token_rejected.load(Ordering::Relaxed);
        if of != self.reported_open_failed.swap(of, Ordering::Relaxed)
            || tr != self.reported_token_rejected.swap(tr, Ordering::Relaxed)
        {
            let line = format!("bridges: open_failed={of} token_rejected={tr}\n");
            out = Some(out.unwrap_or_default() + &line);
        }
        out
    }
    fn current_conn(&self) -> Connection {
        self.conn.lock().unwrap().clone()
    }
    /// Classify the live connection's *selected* path: direct (hole-punched),
    /// relayed, or unknown (no path selected yet / not connected). A snapshot.
    fn path_kind(&self) -> u8 {
        if self.status.load(Ordering::Relaxed) != STATUS_CONNECTED {
            return PATH_UNKNOWN;
        }
        let conn = self.current_conn();
        for p in conn.paths().iter() {
            if p.is_selected() {
                return if p.is_relay() { PATH_RELAY } else { PATH_DIRECT };
            }
        }
        PATH_UNKNOWN
    }
}

pub(crate) const PLATFORM_LOG_INFO: i32 = 4; // ANDROID_LOG_INFO
pub(crate) const PLATFORM_LOG_ERROR: i32 = 6; // ANDROID_LOG_ERROR

/// Mirror a line to the platform log (`adb logcat -s iroh_tunnel`). No-op
/// elsewhere; iOS reads these through the app's drained events instead.
#[cfg(target_os = "android")]
pub(crate) fn platform_log(prio: i32, msg: &str) {
    use std::ffi::{c_char, CString};
    #[link(name = "log")]
    extern "C" {
        fn __android_log_write(prio: i32, tag: *const c_char, text: *const c_char) -> i32;
    }
    if let (Ok(tag), Ok(text)) = (CString::new("iroh_tunnel"), CString::new(msg)) {
        unsafe { __android_log_write(prio, tag.as_ptr(), text.as_ptr()) };
    }
}
#[cfg(not(target_os = "android"))]
pub(crate) fn platform_log(_prio: i32, _msg: &str) {}

/// RAII counter for [`Shared::active_bridges`]: increments on creation and
/// decrements on drop, so teardown can wait for in-flight bridges to finish on
/// every exit path (clean EOF, error, early return, panic).
struct BridgeGuard<'a>(&'a Arc<Shared>);
impl<'a> BridgeGuard<'a> {
    fn new(shared: &'a Arc<Shared>) -> Self {
        shared.active_bridges.fetch_add(1, Ordering::Relaxed);
        BridgeGuard(shared)
    }
}
impl Drop for BridgeGuard<'_> {
    fn drop(&mut self) {
        self.0.active_bridges.fetch_sub(1, Ordering::Relaxed);
    }
}

/// Bounded drain then graceful close: wait (up to [`DRAIN_TIMEOUT`]) for in-flight
/// bridges to finish, send a clean QUIC CONNECTION_CLOSE, then close the endpoint.
/// iroh's `endpoint.close()` retransmits the CONNECTION_CLOSE and can take ~3s on a
/// bad link, so we cap it too — a wedged close can't pin the old UDP socket open.
async fn drain_and_close(shared: Arc<Shared>) {
    let deadline = tokio::time::Instant::now() + DRAIN_TIMEOUT;
    while shared.active_bridges.load(Ordering::Relaxed) > 0
        && tokio::time::Instant::now() < deadline
    {
        tokio::time::sleep(DRAIN_POLL).await;
    }
    shared.current_conn().close(0u32.into(), b"client shutdown");
    let _ = tokio::time::timeout(DRAIN_TIMEOUT, shared.endpoint.close()).await;
}

/// A running tunnel. The loopback port is STABLE for the tunnel's lifetime (it
/// survives reconnects AND listener re-binds), so URLs the app builds against it
/// stay valid across a network blip / server restart / app suspension. Prefer
/// [`Tunnel::shutdown`]; `Drop` is a fallback.
pub struct Tunnel {
    /// Loopback port the app should treat as the server base URL.
    pub local_port: u16,
    shared: Arc<Shared>,
    /// Set by [`Tunnel::begin_shutdown`] so [`Drop`] doesn't slam the connection
    /// shut after a graceful, drained teardown was already scheduled.
    shutting_down: AtomicBool,
}

impl Tunnel {
    /// Current status (one of the `STATUS_*` constants).
    pub fn status(&self) -> u8 {
        self.shared.status.load(Ordering::Relaxed)
    }

    /// Current selected-path kind (one of the `PATH_*` constants).
    pub fn path_kind(&self) -> u8 {
        self.shared.path_kind()
    }

    /// The loopback auth token the local HTTP client must present (`__lt=<token>`).
    pub fn local_token(&self) -> String {
        self.shared.local_token.clone()
    }

    /// Whether any home relay is connected right now.
    pub fn relay_online(&self) -> bool {
        self.shared.relay_online()
    }

    /// Native events since the last call (one per line), or None when nothing
    /// happened. Drained by the app's status poll into its diagnostics log.
    pub fn drain_events(&self) -> Option<String> {
        self.shared.drain_events()
    }

    /// Fire-and-forget network nudge: tell iroh the network may have changed (Android
    /// can't self-detect) so it re-homes the relay + re-probes paths. Runs on `rt`
    /// and holds no lock during the re-probe — `tunnel_network_changed` is reached
    /// from the UI isolate, which also polls status and must not block.
    pub fn nudge_network(&self, rt: &tokio::runtime::Runtime) {
        let endpoint = self.shared.endpoint.clone();
        rt.spawn(async move {
            endpoint.network_change().await;
        });
    }

    /// Reconnect IN PLACE — same endpoint, same loopback port, same token — so
    /// nothing the app built against the tunnel goes stale: nudge iroh about
    /// the network, re-bind the loopback listener (iOS kills it during a
    /// suspension while the QUIC connection survives), then close the current
    /// connection so the supervisor wakes and re-dials at once, cutting any
    /// backoff sleep short. The app calls this after two failed liveness
    /// probes on a tunnel that still REPORTS connected; a hard stop/start is
    /// its fallback when this does not converge. Non-blocking (runs on `rt`).
    pub fn force_reconnect(&self, rt: &tokio::runtime::Runtime) {
        let shared = self.shared.clone();
        rt.spawn(async move {
            shared.event("app kick: network_change, listener re-bind, close");
            shared.endpoint.network_change().await;
            if !respawn_listener(&shared).await {
                // Port taken by something else: nothing in-place can fix that.
                shared.event("listener re-bind failed after kick — tunnel down");
                shared.set_status(STATUS_DOWN);
                return;
            }
            // No-op if the supervisor already saw this connection close.
            shared.current_conn().close(0u32.into(), b"app kick");
            shared.kick.notify_one();
        });
    }

    /// Which kind of server this tunnel dials.
    pub fn kind(&self) -> PairingKind {
        self.shared.kind
    }

    /// Swap the credential (and the endpoint address) this tunnel dials with,
    /// IN PLACE — same loopback port, same token, so nothing the app built
    /// against the tunnel goes stale. A federated peer's guest token expires
    /// daily and the parent hands out a fresh one; without this the only way
    /// to use it was a stop/start that rotated the port and every queued URL.
    ///
    /// The new code must be the same kind as the running one and name the
    /// same server (endpoint id) — a refreshed ticket may carry new relay or
    /// direct addresses, which are taken. It applies at the next dial:
    ///   - CONNECTED: the authenticated connection is kept; the supervisor's
    ///     next re-dial uses the new credential;
    ///   - RECONNECTING / CONNECTING: the backoff is cut short (a dial already
    ///     in flight with the old credential that gets rejected retries once
    ///     with the new one, see [`supervise`]);
    ///   - REJECTED (the supervisor gave up): a fresh supervisor is spawned
    ///     and re-dials at once — the listener never left the port.
    /// Non-blocking: parsing is pure and the re-dial runs on `rt`.
    pub fn set_credential(&self, code: &str, rt: &tokio::runtime::Runtime) -> Result<()> {
        let pairing = parse_pairing_code(code)?;
        if pairing.kind != self.shared.kind {
            bail!(
                "credential kind mismatch: this tunnel is {:?}, the new code is {:?}",
                self.shared.kind,
                pairing.kind
            );
        }
        let ticket = EndpointTicket::decode_string(&pairing.ticket)
            .map_err(|e| anyhow!("invalid endpoint ticket: {e}"))?;
        let addr = ticket.endpoint_addr().clone();
        if addr.id != self.shared.addr.lock().unwrap().id {
            bail!("the new credential is for a different server (endpoint id changed)");
        }
        *self.shared.addr.lock().unwrap() = addr;
        *self.shared.payload.lock().unwrap() = pairing.payload;

        let shared = self.shared.clone();
        match shared.status.load(Ordering::Relaxed) {
            STATUS_REJECTED => {
                // The supervisor returned. A new one starts by awaiting the
                // (already closed) connection's close, which returns at once,
                // so it re-dials immediately with the new credential.
                shared.event("credential updated after a rejected handshake — re-dialing");
                shared.set_status(STATUS_RECONNECTING);
                let h = rt.spawn(supervise(shared.clone()));
                if let Some(old) = shared.supervisor.lock().unwrap().replace(h) {
                    old.abort();
                }
            }
            STATUS_RECONNECTING | STATUS_CONNECTING => {
                shared.event("credential updated — cutting the backoff short");
                shared.kick.notify_one();
            }
            STATUS_DOWN => {
                shared.event("credential updated, but the tunnel is down (listener lost) — a restart is needed");
            }
            _ => {
                shared.event("credential updated — applies at the next dial");
            }
        }
        Ok(())
    }

    /// Begin a graceful, NON-BLOCKING teardown: stop accepting + supervising, then on
    /// `rt` run [`drain_and_close`] (drain in-flight bridges, then close conn +
    /// endpoint — see it for the bounded teardown window). The app calls stop()
    /// synchronously on the UI isolate, so this must return promptly — hence the
    /// work runs on the runtime instead of blocking the caller.
    pub fn begin_shutdown(self, rt: &tokio::runtime::Runtime) {
        if let Some(h) = self.shared.accept.lock().unwrap().take() {
            h.abort();
        }
        if let Some(h) = self.shared.supervisor.lock().unwrap().take() {
            h.abort();
        }
        // Suppress the immediate-close Drop; the spawned drain owns the close now.
        self.shutting_down.store(true, Ordering::Relaxed);
        rt.spawn(drain_and_close(self.shared.clone()));
    }
}

impl Drop for Tunnel {
    fn drop(&mut self) {
        // A graceful, drained teardown was already scheduled by begin_shutdown.
        if self.shutting_down.load(Ordering::Relaxed) {
            return;
        }
        if let Ok(mut guard) = self.shared.accept.lock() {
            if let Some(h) = guard.take() {
                h.abort();
            }
        }
        if let Ok(mut guard) = self.shared.supervisor.lock() {
            if let Some(h) = guard.take() {
                h.abort();
            }
        }
        // Closing the connection makes in-flight bridge streams error out promptly.
        if let Ok(conn) = self.shared.conn.lock() {
            conn.close(0u32.into(), b"client dropped");
        }
        // endpoint.close() is async and Drop can't await; best-effort drain.
        if let Ok(handle) = tokio::runtime::Handle::try_current() {
            let endpoint = self.shared.endpoint.clone();
            handle.spawn(async move { endpoint.close().await });
        }
    }
}

/// Outcome of a dial + secret handshake.
enum DialResult {
    Connected(Connection),
    Rejected,       // server said "NO" → wrong/rotated secret
    Failed(String), // transient: unreachable / timeout / mid-handshake error, with why
}

/// Connect on `alpn` and run the handshake on the first bi-stream: write the
/// credential (the 32-byte connect secret, or a guest token), expect "OK".
async fn dial_and_handshake(
    endpoint: &Endpoint,
    addr: &EndpointAddr,
    alpn: &[u8],
    payload: &[u8],
) -> DialResult {
    let conn = match tokio::time::timeout(CONNECT_TIMEOUT, endpoint.connect(addr.clone(), alpn))
    .await
    {
        Ok(Ok(c)) => c,
        Ok(Err(e)) => return DialResult::Failed(format!("connect error: {e}")),
        Err(_) => {
            return DialResult::Failed(format!(
                "connect timed out after {}s",
                CONNECT_TIMEOUT.as_secs()
            ))
        }
    };
    // Bound the handshake so a stalled/half-dead server can't park the supervisor.
    let handshake = async {
        let (mut send, mut recv) = match conn.open_bi().await {
            Ok(pair) => pair,
            Err(e) => return DialResult::Failed(format!("open_bi: {e}")),
        };
        if send.write_all(payload).await.is_err() || send.finish().is_err() {
            return DialResult::Failed("handshake write failed".into());
        }
        match recv.read_to_end(HANDSHAKE_RESP_LIMIT).await {
            Ok(resp) if resp == b"OK" => DialResult::Connected(conn),
            Ok(resp) if resp == b"NO" => DialResult::Rejected,
            // Empty / unexpected reply (truncation, a non-conforming server) is
            // transient — retry rather than declaring a permanent "re-pair".
            Ok(resp) => DialResult::Failed(format!("unexpected handshake reply ({} bytes)", resp.len())),
            Err(e) => DialResult::Failed(format!("handshake read: {e}")),
        }
    };
    match tokio::time::timeout(HANDSHAKE_TIMEOUT, handshake).await {
        Ok(result) => result,
        Err(_) => DialResult::Failed("handshake stalled".into()), // transient
    }
}

/// Watches the live connection and, when it dies, re-dials on the SAME endpoint
/// (reusing the warmed relay + discovered addrs) and swaps in the new connection —
/// so a network change / server restart recovers without the app re-pairing and
/// without the loopback port changing. Exits only on a rejected handshake.
///
/// Between failed attempts it sleeps a short, doubling backoff that is cut
/// short by an app kick or by the home relay coming back ([`wait_backoff`]),
/// so an attempt that overlapped service returning costs at most one more
/// dial, not a timer's worth of silence. Every attempt is recorded in the
/// events ring with its elapsed time, relay state and failure reason.
async fn supervise(shared: Arc<Shared>) {
    loop {
        // Park until the current connection closes for any reason.
        let why = shared.current_conn().closed().await;
        shared.set_status(STATUS_RECONNECTING);
        shared.event(format!("conn closed: {why}"));

        let mut backoff = Duration::from_secs(1);
        let mut attempt = 0u32;
        loop {
            attempt += 1;
            let t0 = Instant::now();
            // Re-warm a relay path before re-dialing (cheap if already online).
            let relay_online = tokio::time::timeout(ONLINE_TIMEOUT, shared.endpoint.online())
                .await
                .is_ok();
            // Snapshot the credential per attempt: set_credential may swap it
            // (and the address) while this dial is in flight.
            let addr = shared.addr.lock().unwrap().clone();
            let payload = shared.payload.lock().unwrap().clone();
            match dial_and_handshake(&shared.endpoint, &addr, shared.alpn, &payload).await {
                DialResult::Connected(c) => {
                    *shared.conn.lock().unwrap() = c;
                    shared.set_status(STATUS_CONNECTED);
                    shared.event(format!(
                        "reconnected: attempt {attempt} in {:.1}s relay_online={relay_online}",
                        t0.elapsed().as_secs_f32()
                    ));
                    break; // resume watching the new connection
                }
                DialResult::Rejected => {
                    // A credential swapped in while this dial was in flight
                    // deserves one more try before giving up.
                    if *shared.payload.lock().unwrap() != payload {
                        shared.event("handshake rejected with a stale credential — retrying with the new one");
                        continue;
                    }
                    shared.set_status(STATUS_REJECTED);
                    shared.event(match shared.kind {
                        PairingKind::Tunnel => "handshake rejected — re-pair needed",
                        PairingKind::FederationGuest => {
                            "handshake rejected — guest token refused (expired or revoked); refresh it from the parent"
                        }
                    });
                    return; // the app must re-pair (or, for a guest, refresh the token)
                }
                DialResult::Failed(reason) => {
                    shared.event(format!(
                        "attempt {attempt} failed after {:.1}s relay_online={relay_online}: {reason}; backoff {}s",
                        t0.elapsed().as_secs_f32(),
                        backoff.as_secs()
                    ));
                    let woke = wait_backoff(&shared, backoff).await;
                    backoff = next_backoff(backoff, woke);
                }
            }
        }
    }
}

/// The backoff after a failed attempt: back to 1s when something woke us
/// (the relay came back, the app kicked) — the next dial is likely to work —
/// else doubled and capped. Pure; unit-tested.
fn next_backoff(prev: Duration, woke: bool) -> Duration {
    if woke {
        Duration::from_secs(1)
    } else {
        (prev * 2).min(RECONNECT_BACKOFF_MAX)
    }
}

/// Sleep `backoff`, returning early (true) on an app kick or on the home relay
/// going from down to up. Only a DOWN→UP relay edge counts: a relay that was
/// already up when the attempt failed says nothing about the next attempt.
async fn wait_backoff(shared: &Shared, backoff: Duration) -> bool {
    let mut relay = shared.endpoint.home_relay_status();
    let relay_was_up = relay.get().iter().any(|r| r.is_connected());
    let relay_back = async {
        if relay_was_up {
            std::future::pending::<()>().await;
        }
        loop {
            match relay.updated().await {
                Ok(v) if v.iter().any(|r| r.is_connected()) => return,
                Ok(_) => continue,
                Err(_) => std::future::pending::<()>().await,
            }
        }
    };
    tokio::select! {
        _ = tokio::time::sleep(backoff) => false,
        _ = shared.kick.notified() => {
            shared.event("backoff cut short: app kick");
            true
        }
        _ = relay_back => {
            shared.event("backoff cut short: home relay back");
            true
        }
    }
}

/// Which kind of server a code dials.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PairingKind {
    /// Quick Connect: `mstr<V>:{t,s}` — the 32-byte connect secret, ALPN
    /// `mstream/tunnel/2`.
    Tunnel,
    /// A federated peer, dialed directly: `mstrfedg<V>:{t,g}` — a guest token
    /// the parent server fetched for this device, ALPN `mstream/federation/1`
    /// (mStream `docs/federation-guest-ticket.md`).
    FederationGuest,
}

/// What a code resolves to: where to dial, on which ALPN, and what to write
/// on the first bi-stream.
#[derive(Debug)]
struct Pairing {
    ticket: String,
    alpn: &'static [u8],
    payload: Vec<u8>,
    kind: PairingKind,
}

/// Decode base64 tolerantly — accepts both the standard and URL-safe alphabets,
/// padded or not. Node's `Buffer.from(x, 'base64'|'base64url')` is equally lenient,
/// so this keeps us interoperable with whatever the server emits.
fn b64_loose(s: &str) -> Result<Vec<u8>> {
    let norm: String = s
        .chars()
        .filter_map(|c| match c {
            '-' => Some('+'),
            '_' => Some('/'),
            '=' => None,
            c if c.is_whitespace() => None,
            c => Some(c),
        })
        .collect();
    base64::engine::general_purpose::STANDARD_NO_PAD
        .decode(norm)
        .map_err(|e| anyhow!("invalid base64: {e}"))
}

/// Split `<prefix><digits>:<body>`; None when the prefix or a numeric version
/// is absent (then the string is not this envelope).
fn split_envelope<'a>(s: &'a str, prefix: &str) -> Option<(u32, &'a str)> {
    let rest = s.strip_prefix(prefix)?;
    let (ver, body) = rest.split_once(':')?;
    if ver.is_empty() || !ver.bytes().all(|b| b.is_ascii_digit()) {
        return None;
    }
    Some((ver.parse::<u32>().unwrap_or(u32::MAX), body))
}

fn decode_body(body: &str, label: &str) -> Result<serde_json::Value> {
    let json = b64_loose(body).with_context(|| format!("invalid {label} (not base64)"))?;
    serde_json::from_slice(&json).with_context(|| format!("invalid {label} (not JSON)"))
}

fn field_str(v: &serde_json::Value, key: &str) -> Option<String> {
    v.get(key).and_then(|x| x.as_str()).map(|s| s.to_string())
}

/// Parse a code into where to dial and what to present. Two envelopes:
///
///   * Quick Connect pairing code (docs/iroh-pairing-code.md in mStream PR
///     #643): `mstr<V>:<base64url(JSON{t,s})>`; a bare (un-prefixed) body is a
///     legacy code → implicit v1. `s` is the 32-byte connect secret.
///   * Federation guest ticket (mStream docs/federation-guest-ticket.md):
///     `mstrfedg<V>:<base64url(JSON{t,g})>`; `g` is the guest token, written
///     as-is on the first bi-stream of the federation ALPN. No bare form.
///
/// A federation TICKET (`mstrfed<V>:`, the admin-to-admin pairing that carries
/// a standing key) is refused by name — the app must never hold one. A version
/// newer than this client understands is rejected with an actionable "update
/// the app" error. Pure (no native module).
fn parse_pairing_code(code: &str) -> Result<Pairing> {
    let trimmed = code.trim();

    // The guest envelope first: its prefix extends the tunnel one, and the
    // tunnel branch would otherwise read `fedg1` as a missing version.
    if let Some((version, body)) = split_envelope(trimmed, "mstrfedg") {
        if version > GUEST_TICKET_VERSION {
            bail!(
                "Guest ticket is version {version}; this app supports up to v{GUEST_TICKET_VERSION}. Update to a newer version of the app."
            );
        }
        let v = decode_body(body, "guest ticket")?;
        let ticket =
            field_str(&v, "t").ok_or_else(|| anyhow!("invalid guest ticket (missing ticket)"))?;
        let token =
            field_str(&v, "g").ok_or_else(|| anyhow!("invalid guest ticket (missing token)"))?;
        if token.is_empty() || token.len() > GUEST_TOKEN_MAX {
            bail!("invalid guest ticket (token length {})", token.len());
        }
        return Ok(Pairing {
            ticket,
            alpn: FEDERATION_ALPN,
            payload: token.into_bytes(),
            kind: PairingKind::FederationGuest,
        });
    }
    if split_envelope(trimmed, "mstrfed").is_some() {
        bail!(
            "This is a federation ticket for pairing two servers, not a pairing code for the app."
        );
    }

    let (version, body) = split_envelope(trimmed, "mstr").unwrap_or((1, trimmed));
    if version > PAIRING_VERSION {
        bail!(
            "Pairing code is version {version}; this app supports up to v{PAIRING_VERSION}. Update to a newer version of the app."
        );
    }
    let v = decode_body(body, "pairing code")?;
    let ticket =
        field_str(&v, "t").ok_or_else(|| anyhow!("invalid pairing code (missing ticket)"))?;
    let secret_b64 =
        field_str(&v, "s").ok_or_else(|| anyhow!("invalid pairing code (missing secret)"))?;
    let secret = b64_loose(&secret_b64).context("invalid pairing code (bad secret)")?;
    if secret.len() != SECRET_LEN {
        bail!("connect secret must be {SECRET_LEN} bytes (got {})", secret.len());
    }
    Ok(Pairing {
        ticket,
        alpn: TUNNEL_ALPN,
        payload: secret,
        kind: PairingKind::Tunnel,
    })
}

/// Dial a tunnel from a pairing code, complete the secret handshake, and start a
/// loopback TCP proxy with a reconnect supervisor. Returns once it's ready to serve.
/// `local_port` of 0 picks an ephemeral port (the chosen port is in [`Tunnel`]).
pub async fn connect_tunnel(code: &str, local_port: u16) -> Result<Tunnel> {
    let pairing = parse_pairing_code(code)?;

    let endpoint = Endpoint::bind(presets::N0)
        .await
        .context("failed to bind iroh endpoint")?;

    // Cross-network: establish our own home relay BEFORE dialing, else the first
    // stream can reset on a not-ready path. Bounded; proceed even if it times out.
    let _ = tokio::time::timeout(ONLINE_TIMEOUT, endpoint.online()).await;

    let ticket = EndpointTicket::decode_string(&pairing.ticket)
        .map_err(|e| anyhow!("invalid endpoint ticket: {e}"))?;
    let addr = ticket.endpoint_addr().clone();

    // First dial + handshake; distinguish a rejected secret for a clear error.
    // The failure reason and relay state ride along: "may be offline" used to
    // hide "no home relay within 8s; connect timed out after 25s".
    let t0 = Instant::now();
    let conn = match dial_and_handshake(&endpoint, &addr, pairing.alpn, &pairing.payload).await {
        DialResult::Connected(c) => c,
        DialResult::Rejected => bail!(
            "{}",
            match pairing.kind {
                PairingKind::Tunnel =>
                    "tunnel handshake rejected — wrong or rotated connect secret; re-pair from the server's Remote Access panel",
                PairingKind::FederationGuest =>
                    "handshake rejected — the guest token was refused (expired or revoked); refresh it from the parent server",
            }
        ),
        DialResult::Failed(reason) => {
            let relay = if endpoint.home_relay_status().get().iter().any(|r| r.is_connected()) {
                "online"
            } else {
                "not reached"
            };
            bail!(
                "could not reach the server through the tunnel ({reason}; home relay {relay}; {:.1}s) — it may be offline or the pairing code is stale",
                t0.elapsed().as_secs_f32()
            )
        }
    };

    let listener = TcpListener::bind(("127.0.0.1", local_port))
        .await
        .context("failed to bind local proxy port")?;
    let bound_port = listener.local_addr()?.port();

    let (status_tx, _status_rx) = watch::channel(STATUS_CONNECTED);
    let path = {
        let mut kind = "unknown";
        for p in conn.paths().iter() {
            if p.is_selected() {
                kind = if p.is_relay() { "relay" } else { "direct" };
            }
        }
        kind
    };
    let mode = match pairing.kind {
        PairingKind::Tunnel => "tunnel",
        PairingKind::FederationGuest => "guest",
    };
    let shared = Arc::new(Shared {
        endpoint,
        addr: Mutex::new(addr),
        alpn: pairing.alpn,
        kind: pairing.kind,
        payload: Mutex::new(pairing.payload),
        conn: Mutex::new(conn),
        status: AtomicU8::new(STATUS_CONNECTED),
        status_tx,
        active_bridges: AtomicUsize::new(0),
        local_token: gen_local_token()?,
        local_port: bound_port,
        accept: Mutex::new(None),
        supervisor: Mutex::new(None),
        kick: Notify::new(),
        events: Mutex::new(EventRing::new()),
        started: Instant::now(),
        bridges_open_failed: AtomicU32::new(0),
        bridges_token_rejected: AtomicU32::new(0),
        reported_open_failed: AtomicU32::new(0),
        reported_token_rejected: AtomicU32::new(0),
    });
    shared.event(format!(
        "bound 127.0.0.1:{bound_port}, first dial OK in {:.1}s path={path} mode={mode}",
        t0.elapsed().as_secs_f32()
    ));

    let accept = tokio::spawn(serve_loopback(shared.clone(), listener));
    *shared.accept.lock().unwrap() = Some(accept);

    let supervisor = tokio::spawn(supervise(shared.clone()));
    *shared.supervisor.lock().unwrap() = Some(supervisor);

    Ok(Tunnel {
        local_port: bound_port,
        shared,
        shutting_down: AtomicBool::new(false),
    })
}

/// The loopback accept loop. A failed accept used to end it silently while
/// the status kept saying connected — that is how an iOS suspension (which
/// kills the listener socket but not the QUIC connection) left every local
/// request refused. Now it re-binds the SAME port in place and carries on;
/// only a port that cannot be re-bound takes the tunnel down.
async fn serve_loopback(shared: Arc<Shared>, mut listener: TcpListener) {
    loop {
        match listener.accept().await {
            Ok((sock, _)) => {
                let s = shared.clone();
                tokio::spawn(async move { bridge_socket(sock, s).await });
            }
            Err(e) => {
                shared.event(format!(
                    "accept failed: {e} — re-binding 127.0.0.1:{}",
                    shared.local_port
                ));
                match rebind_listener(&shared).await {
                    Some(l) => {
                        listener = l;
                        shared.event("listener re-bound");
                    }
                    None => {
                        shared.event("listener re-bind failed — tunnel down");
                        shared.set_status(STATUS_DOWN);
                        return;
                    }
                }
            }
        }
    }
}

/// Bind the tunnel's loopback port again, retrying briefly while a dying
/// socket still holds it.
async fn rebind_listener(shared: &Shared) -> Option<TcpListener> {
    for _ in 0..REBIND_ATTEMPTS {
        match TcpListener::bind(("127.0.0.1", shared.local_port)).await {
            Ok(l) => return Some(l),
            Err(_) => tokio::time::sleep(REBIND_DELAY).await,
        }
    }
    None
}

/// Replace the accept task with a fresh listener on the same port (the kick
/// path). True when the port was re-bound.
async fn respawn_listener(shared: &Arc<Shared>) -> bool {
    if let Some(h) = shared.accept.lock().unwrap().take() {
        h.abort(); // drops the old listener, releasing the port
    }
    match rebind_listener(shared).await {
        Some(l) => {
            let h = tokio::spawn(serve_loopback(shared.clone(), l));
            *shared.accept.lock().unwrap() = Some(h);
            shared.event("listener re-bound");
            true
        }
        None => false,
    }
}

/// Generate a random 128-bit loopback token, hex-encoded (32 chars).
fn gen_local_token() -> Result<String> {
    let mut b = [0u8; 16];
    getrandom::getrandom(&mut b).map_err(|e| anyhow!("rng failure: {e}"))?;
    Ok(b.iter().map(|x| format!("{x:02x}")).collect())
}

/// Authenticate the LOCAL hop: peek (WITHOUT consuming) the first HTTP request
/// line and require `__lt=<local_token>` in it. Returns false (→ drop the socket)
/// for any client that doesn't present the token — i.e. another app on the device.
/// Peeking (not reading) means the request bytes are still delivered to the server
/// untouched, and validating once per connection is keep-alive-safe.
async fn local_token_ok(sock: &TcpStream, token: &str) -> bool {
    let needle = format!("__lt={token}");
    let needle = needle.as_bytes();
    let mut buf = vec![0u8; LOCAL_TOKEN_PEEK_MAX];
    let deadline = tokio::time::Instant::now() + LOCAL_TOKEN_TIMEOUT;
    loop {
        let n = match tokio::time::timeout_at(deadline, sock.peek(&mut buf)).await {
            Ok(Ok(n)) if n > 0 => n,
            _ => return false,
        };
        let head = &buf[..n];
        if let Some(pos) = head.windows(2).position(|w| w == b"\r\n") {
            return head[..pos].windows(needle.len()).any(|w| w == needle);
        }
        if n >= LOCAL_TOKEN_PEEK_MAX {
            return false; // request line too long / not HTTP
        }
        tokio::time::sleep(Duration::from_millis(20)).await;
    }
}

/// One inbound TCP connection ⇆ one fresh iroh bi-stream (full duplex).
///
/// Mirrors the reference `bridge()`/`dispose()`: each direction ends cleanly on
/// EOF (finish/shutdown), but if either direction *errors* we cancel the partner
/// so a half-open stream can't park.
async fn bridge_socket(sock: TcpStream, shared: Arc<Shared>) {
    // Count this bridge as in-flight for its whole lifetime (drops on every exit
    // path), so a graceful teardown can wait for it before closing the connection.
    let _bridge = BridgeGuard::new(&shared);
    // Authenticate the local hop first: only our app knows the token, so other apps
    // on the device that connect to 127.0.0.1:<port> are dropped before any bi-stream.
    if !local_token_ok(&sock, &shared.local_token).await {
        shared.bridges_token_rejected.fetch_add(1, Ordering::Relaxed);
        return;
    }
    // Open a bi-stream on the CURRENT connection. While the supervisor is
    // mid-reconnect, wait (bounded) for the swapped-in connection rather than
    // hard-failing, so a request landing inside a 1-3s reconnect rides it.
    let mut rx = shared.status_tx.subscribe();
    let deadline = Instant::now() + BRIDGE_WAIT_FOR_CONN;
    let (send, recv) = loop {
        if shared.status.load(Ordering::Relaxed) == STATUS_CONNECTED {
            if let Ok(pair) = shared.current_conn().open_bi().await {
                break pair;
            }
            // The connection died between the status read and open_bi: fall
            // through and wait for the supervisor's swap.
        }
        tokio::select! {
            r = rx.changed() => {
                if r.is_err() {
                    return;
                }
            }
            _ = tokio::time::sleep_until(deadline) => {
                shared.bridges_open_failed.fetch_add(1, Ordering::Relaxed);
                // Consume what the client sent so the drop is a clean FIN, not
                // an RST with unread bytes.
                let mut sink = vec![0u8; 8192];
                let _ = tokio::time::timeout(Duration::from_millis(50), sock.readable()).await;
                let _ = sock.try_read(&mut sink);
                return;
            }
        }
    };
    let _ = sock.set_nodelay(true);
    let (r, w) = sock.into_split();
    let mut up = tokio::spawn(pump_reader_to_send(r, send));
    let mut down = tokio::spawn(pump_recv_to_writer(recv, w));

    // `false` == that direction errored → tear down the sibling (aborting the task
    // drops its stream half, which sends RESET/STOP). `true`/clean → let the other
    // direction finish (an HTTP request finishes long before its response).
    tokio::select! {
        res = &mut up => { if matches!(res, Ok(false)) { down.abort(); } else { let _ = down.await; } }
        res = &mut down => { if matches!(res, Ok(false)) { up.abort(); } else { let _ = up.await; } }
    }
}

/// TCP → iroh send stream. Returns `true` on clean EOF, `false` on error.
async fn pump_reader_to_send(mut r: OwnedReadHalf, mut send: SendStream) -> bool {
    let mut buf = vec![0u8; READ_CHUNK];
    loop {
        match r.read(&mut buf).await {
            Ok(0) => {
                let _ = send.finish();
                return true;
            }
            Ok(n) => {
                if send.write_all(&buf[..n]).await.is_err() {
                    let _ = send.reset(0u32.into());
                    return false;
                }
            }
            Err(_) => {
                let _ = send.reset(0u32.into());
                return false;
            }
        }
    }
}

/// iroh recv stream → TCP. Returns `true` on clean EOF, `false` on error.
async fn pump_recv_to_writer(mut recv: RecvStream, mut w: OwnedWriteHalf) -> bool {
    let mut buf = vec![0u8; READ_CHUNK];
    loop {
        match recv.read(&mut buf).await {
            Ok(Some(n)) => {
                if w.write_all(&buf[..n]).await.is_err() {
                    let _ = recv.stop(0u32.into());
                    return false;
                }
            }
            Ok(None) => {
                let _ = w.shutdown().await;
                return true;
            }
            Err(_) => {
                let _ = recv.stop(0u32.into());
                return false;
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use base64::Engine;

    fn body(t: &str, secret: &[u8]) -> String {
        let s = base64::engine::general_purpose::STANDARD.encode(secret);
        let json = format!(r#"{{"t":"{t}","s":"{s}"}}"#);
        base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(json.as_bytes())
    }

    #[test]
    fn parses_versioned_envelope() {
        let secret = [7u8; SECRET_LEN];
        let p = parse_pairing_code(&format!("mstr1:{}", body("endpointabc", &secret))).unwrap();
        assert_eq!(p.ticket, "endpointabc");
        assert_eq!(p.payload, secret.to_vec());
        assert_eq!(p.alpn, TUNNEL_ALPN);
        assert_eq!(p.kind, PairingKind::Tunnel);
    }

    #[test]
    fn parses_legacy_bare_as_v1() {
        let p = parse_pairing_code(&body("endpointlegacy", &[1u8; SECRET_LEN])).unwrap();
        assert_eq!(p.ticket, "endpointlegacy");
    }

    #[test]
    fn trims_surrounding_whitespace() {
        let code = format!("  mstr1:{}\n", body("endpointws", &[2u8; SECRET_LEN]));
        assert_eq!(parse_pairing_code(&code).unwrap().ticket, "endpointws");
    }

    #[test]
    fn rejects_newer_version_with_update_hint() {
        let err = parse_pairing_code(&format!("mstr2:{}", body("x", &[0u8; SECRET_LEN])))
            .unwrap_err()
            .to_string();
        assert!(err.contains("version 2"), "got: {err}");
        assert!(err.to_lowercase().contains("update"), "got: {err}");
    }

    #[test]
    fn backoff_doubles_and_caps_unless_woken() {
        let mut b = Duration::from_secs(1);
        let mut seen = vec![];
        for _ in 0..6 {
            b = next_backoff(b, false);
            seen.push(b.as_secs());
        }
        assert_eq!(seen, vec![2, 4, 8, 10, 10, 10]);
        assert_eq!(next_backoff(Duration::from_secs(10), true).as_secs(), 1);
    }

    #[test]
    fn event_ring_caps_and_counts_drops() {
        let mut r = EventRing::new();
        assert!(r.drain().is_none());
        for i in 0..(EVENT_RING_CAP + 3) {
            r.push(format!("e{i}"));
        }
        let out = r.drain().unwrap();
        assert!(out.starts_with("(3 older events dropped)\n"), "got: {out}");
        assert!(out.contains("e3\n"));
        assert!(!out.contains("e2\n"));
        assert!(out.trim_end().ends_with(&format!("e{}", EVENT_RING_CAP + 2)));
        assert!(r.drain().is_none(), "drain empties the ring");
    }

    #[test]
    fn rejects_garbage() {
        assert!(parse_pairing_code("not-a-real-ticket!!").is_err());
    }

    #[test]
    fn rejects_missing_secret() {
        let b = base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(br#"{"t":"only"}"#);
        assert!(parse_pairing_code(&format!("mstr1:{b}")).is_err());
    }

    #[test]
    fn rejects_wrong_secret_length() {
        assert!(parse_pairing_code(&format!("mstr1:{}", body("endpointx", &[9u8; 10]))).is_err());
    }

    // ── federation guest tickets (mstrfedg<V>:) ──

    fn guest_body(t: &str, g: &str) -> String {
        let json = format!(r#"{{"t":"{t}","g":"{g}"}}"#);
        base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(json.as_bytes())
    }

    #[test]
    fn parses_guest_ticket_onto_the_federation_alpn() {
        let token = "eyJhbGciOiJIUzI1NiJ9.eyJmZWRlcmF0aW9uR3Vlc3QiOnRydWV9.sig";
        let p = parse_pairing_code(&format!("mstrfedg1:{}", guest_body("endpointpeer", token))).unwrap();
        assert_eq!(p.ticket, "endpointpeer");
        assert_eq!(p.payload, token.as_bytes());
        assert_eq!(p.alpn, FEDERATION_ALPN);
        assert_eq!(p.kind, PairingKind::FederationGuest);
    }

    #[test]
    fn guest_ticket_refuses_empty_oversized_and_missing_tokens() {
        assert!(parse_pairing_code(&format!("mstrfedg1:{}", guest_body("e", ""))).is_err());
        let huge = "x".repeat(GUEST_TOKEN_MAX + 1);
        assert!(parse_pairing_code(&format!("mstrfedg1:{}", guest_body("e", &huge))).is_err());
        let fits = "x".repeat(GUEST_TOKEN_MAX);
        assert!(parse_pairing_code(&format!("mstrfedg1:{}", guest_body("e", &fits))).is_ok());
        let no_token = base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(br#"{"t":"only"}"#);
        assert!(parse_pairing_code(&format!("mstrfedg1:{no_token}")).is_err());
    }

    #[test]
    fn guest_ticket_rejects_newer_version_with_update_hint() {
        let err = parse_pairing_code(&format!("mstrfedg2:{}", guest_body("e", "tok")))
            .unwrap_err()
            .to_string();
        assert!(err.contains("version 2"), "got: {err}");
        assert!(err.to_lowercase().contains("update"), "got: {err}");
    }

    #[test]
    fn a_federation_ticket_is_refused_by_name() {
        // mstrfed1: carries a standing server key — the app must never hold one.
        let fed = base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(br#"{"t":"e","k":"fedk_x"}"#);
        let err = parse_pairing_code(&format!("mstrfed1:{fed}")).unwrap_err().to_string();
        assert!(err.contains("federation ticket"), "got: {err}");
    }

    #[test]
    fn the_envelopes_stay_disjoint() {
        // A guest ticket never parses as a tunnel code and vice versa.
        let secret = [3u8; SECRET_LEN];
        let tunnel = format!("mstr1:{}", body("e", &secret));
        assert_eq!(parse_pairing_code(&tunnel).unwrap().kind, PairingKind::Tunnel);
        let guest = format!("mstrfedg1:{}", guest_body("e", "tok"));
        assert_eq!(parse_pairing_code(&guest).unwrap().kind, PairingKind::FederationGuest);
    }
}
