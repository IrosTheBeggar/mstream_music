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

// Android-only JNI entry point that registers the app Context with ndk_context
// (iroh needs it for network monitoring; without it the first call panics).
#[cfg(target_os = "android")]
mod android_init;

use std::sync::atomic::{AtomicBool, AtomicU8, AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use anyhow::{anyhow, bail, Context, Result};
use base64::Engine;
use iroh::endpoint::{presets, Connection, RecvStream, SendStream};
use iroh::{Endpoint, EndpointAddr};
use iroh_tickets::endpoint::EndpointTicket;
use iroh_tickets::Ticket as _;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::tcp::{OwnedReadHalf, OwnedWriteHalf};
use tokio::net::{TcpListener, TcpStream};
use tokio::task::JoinHandle;

/// ALPN both ends must present. Bump if the server bumps `mstream/tunnel/N`.
pub const TUNNEL_ALPN: &[u8] = b"mstream/tunnel/2";

const READ_CHUNK: usize = 64 * 1024;
const ONLINE_TIMEOUT: Duration = Duration::from_secs(8);
const CONNECT_TIMEOUT: Duration = Duration::from_secs(25);
const HANDSHAKE_RESP_LIMIT: usize = 8;
const SECRET_LEN: usize = 32;
/// Highest pairing-code schema version this client understands. The pairing-code
/// version (the `mstr<V>:` envelope) is independent of the tunnel ALPN version.
const PAIRING_VERSION: u32 = 1;

// Per-inbound-TCP open_bi retry: lets a request ride a reconnect (the supervisor
// swaps the live connection) instead of hard-failing during a brief drop.
const BRIDGE_OPEN_ATTEMPTS: u32 = 3;
const BRIDGE_RETRY_DELAY: Duration = Duration::from_millis(400);
const RECONNECT_BACKOFF_MAX: Duration = Duration::from_secs(30);

// Graceful teardown: on stop/switch, let in-flight bridges finish before closing
// the connection, bounded so a long media stream can't hold the old endpoint open.
// Also caps endpoint.close() (see drain_and_close), so total background teardown is
// drain + close ≈ up to 2×DRAIN_TIMEOUT before the old UDP socket is released.
const DRAIN_TIMEOUT: Duration = Duration::from_secs(3);
const DRAIN_POLL: Duration = Duration::from_millis(50);

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
    addr: EndpointAddr,
    secret: Vec<u8>,
    conn: Mutex<Connection>,
    status: AtomicU8,
    /// In-flight TCP⇆bi-stream bridges, so teardown can drain them gracefully.
    active_bridges: AtomicUsize,
}

impl Shared {
    fn set_status(&self, s: u8) {
        self.status.store(s, Ordering::Relaxed);
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
/// survives reconnects), so URLs the app builds against it stay valid across a
/// network blip / server restart. Prefer [`Tunnel::shutdown`]; `Drop` is a fallback.
pub struct Tunnel {
    /// Loopback port the app should treat as the server base URL.
    pub local_port: u16,
    shared: Arc<Shared>,
    accept_task: JoinHandle<()>,
    supervisor: JoinHandle<()>,
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

    /// Notify iroh the network may have changed (Android can't self-detect), so it
    /// promptly re-homes the relay and re-probes direct paths.
    pub async fn network_changed(&self) {
        self.shared.endpoint.network_change().await;
    }

    /// Begin a graceful, NON-BLOCKING teardown: stop accepting + supervising, then on
    /// `rt` run [`drain_and_close`] (drain in-flight bridges, then close conn +
    /// endpoint — see it for the bounded teardown window). The app calls stop()
    /// synchronously on the UI isolate, so this must return promptly — hence the
    /// work runs on the runtime instead of blocking the caller.
    pub fn begin_shutdown(self, rt: &tokio::runtime::Runtime) {
        self.accept_task.abort();
        self.supervisor.abort();
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
        self.accept_task.abort();
        self.supervisor.abort();
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
    Rejected, // server said "NO" → wrong/rotated secret
    Failed,   // transient: unreachable / timeout / mid-handshake error
}

/// Connect on the ALPN and run the 32-byte secret handshake on the first bi-stream.
async fn dial_and_handshake(endpoint: &Endpoint, addr: &EndpointAddr, secret: &[u8]) -> DialResult {
    let conn = match tokio::time::timeout(
        CONNECT_TIMEOUT,
        endpoint.connect(addr.clone(), TUNNEL_ALPN),
    )
    .await
    {
        Ok(Ok(c)) => c,
        _ => return DialResult::Failed,
    };
    let (mut send, mut recv) = match conn.open_bi().await {
        Ok(pair) => pair,
        Err(_) => return DialResult::Failed,
    };
    if send.write_all(secret).await.is_err() || send.finish().is_err() {
        return DialResult::Failed;
    }
    match recv.read_to_end(HANDSHAKE_RESP_LIMIT).await {
        Ok(resp) if resp == b"OK" => DialResult::Connected(conn),
        Ok(_) => DialResult::Rejected,
        Err(_) => DialResult::Failed,
    }
}

/// Watches the live connection and, when it dies, re-dials on the SAME endpoint
/// (reusing the warmed relay + discovered addrs) and swaps in the new connection —
/// so a network change / server restart recovers without the app re-pairing and
/// without the loopback port changing. Exits only on a rejected handshake.
async fn supervise(shared: Arc<Shared>) {
    loop {
        // Park until the current connection closes for any reason.
        shared.current_conn().closed().await;
        shared.set_status(STATUS_RECONNECTING);

        let mut backoff = Duration::from_secs(1);
        loop {
            // Re-warm a relay path before re-dialing (cheap if already online).
            let _ = tokio::time::timeout(ONLINE_TIMEOUT, shared.endpoint.online()).await;
            match dial_and_handshake(&shared.endpoint, &shared.addr, &shared.secret).await {
                DialResult::Connected(c) => {
                    *shared.conn.lock().unwrap() = c;
                    shared.set_status(STATUS_CONNECTED);
                    break; // resume watching the new connection
                }
                DialResult::Rejected => {
                    shared.set_status(STATUS_REJECTED);
                    return; // rotated/wrong secret — the app must re-pair
                }
                DialResult::Failed => {
                    tokio::time::sleep(backoff).await;
                    backoff = (backoff * 2).min(RECONNECT_BACKOFF_MAX);
                }
            }
        }
    }
}

#[derive(Debug)]
struct Pairing {
    ticket: String,
    secret: Vec<u8>,
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

/// Parse the pairing code into its EndpointTicket + connect secret.
///
/// Format (docs/iroh-pairing-code.md in mStream PR #643): a versioned envelope
/// `mstr<V>:<base64url(JSON{t,s})>`. A bare (un-prefixed) base64url body is a
/// legacy code → implicit v1. A version newer than this client understands is
/// rejected with an actionable "update the app" error. Pure (no native module).
fn parse_pairing_code(code: &str) -> Result<Pairing> {
    let trimmed = code.trim();
    // Split the `mstr<V>:` envelope; anything without a valid prefix is a legacy
    // bare body (implicit v1).
    let (version, body): (u32, &str) = match trimmed.strip_prefix("mstr").and_then(|rest| {
        rest.split_once(':').filter(|(ver, _)| {
            !ver.is_empty() && ver.bytes().all(|b| b.is_ascii_digit())
        })
    }) {
        Some((ver, body)) => (ver.parse::<u32>().unwrap_or(u32::MAX), body),
        None => (1, trimmed),
    };
    if version > PAIRING_VERSION {
        bail!(
            "Pairing code is version {version}; this app supports up to v{PAIRING_VERSION}. Update to a newer version of the app."
        );
    }

    let json = b64_loose(body).context("invalid pairing code (not base64)")?;
    let v: serde_json::Value =
        serde_json::from_slice(&json).context("invalid pairing code (not JSON)")?;
    let ticket = v
        .get("t")
        .and_then(|x| x.as_str())
        .ok_or_else(|| anyhow!("invalid pairing code (missing ticket)"))?
        .to_string();
    let secret_b64 = v
        .get("s")
        .and_then(|x| x.as_str())
        .ok_or_else(|| anyhow!("invalid pairing code (missing secret)"))?;
    let secret = b64_loose(secret_b64).context("invalid pairing code (bad secret)")?;
    if secret.len() != SECRET_LEN {
        bail!("connect secret must be {SECRET_LEN} bytes (got {})", secret.len());
    }
    Ok(Pairing { ticket, secret })
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
    let conn = match dial_and_handshake(&endpoint, &addr, &pairing.secret).await {
        DialResult::Connected(c) => c,
        DialResult::Rejected => bail!(
            "tunnel handshake rejected — wrong or rotated connect secret; re-pair from the server's Remote Access panel"
        ),
        DialResult::Failed => bail!(
            "could not reach the server through the tunnel — it may be offline or the pairing code is stale"
        ),
    };

    let listener = TcpListener::bind(("127.0.0.1", local_port))
        .await
        .context("failed to bind local proxy port")?;
    let bound_port = listener.local_addr()?.port();

    let shared = Arc::new(Shared {
        endpoint,
        addr,
        secret: pairing.secret,
        conn: Mutex::new(conn),
        status: AtomicU8::new(STATUS_CONNECTED),
        active_bridges: AtomicUsize::new(0),
    });

    let accept_shared = shared.clone();
    let accept_task = tokio::spawn(async move {
        loop {
            match listener.accept().await {
                Ok((sock, _)) => {
                    let s = accept_shared.clone();
                    tokio::spawn(async move { bridge_socket(sock, s).await });
                }
                Err(_) => break,
            }
        }
    });

    let supervisor = tokio::spawn(supervise(shared.clone()));

    Ok(Tunnel {
        local_port: bound_port,
        shared,
        accept_task,
        supervisor,
        shutting_down: AtomicBool::new(false),
    })
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
    // Open a bi-stream on the CURRENT connection, retrying briefly so a request
    // mid-reconnect can ride the swapped-in connection instead of hard-failing.
    let mut attempt = 0u32;
    let (send, recv) = loop {
        match shared.current_conn().open_bi().await {
            Ok(pair) => break pair,
            Err(_) => {
                attempt += 1;
                if attempt >= BRIDGE_OPEN_ATTEMPTS {
                    return;
                }
                tokio::time::sleep(BRIDGE_RETRY_DELAY).await;
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
        assert_eq!(p.secret, secret.to_vec());
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
}
