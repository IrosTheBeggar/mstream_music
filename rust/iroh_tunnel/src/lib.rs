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

use std::time::Duration;

use anyhow::{anyhow, bail, Context, Result};
use base64::Engine;
use iroh::endpoint::{presets, Connection, RecvStream, SendStream};
use iroh::Endpoint;
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

/// A running tunnel. Prefer [`Tunnel::shutdown`] for a graceful close; `Drop` is a
/// best-effort fallback.
pub struct Tunnel {
    /// Loopback port the app should treat as the server base URL.
    pub local_port: u16,
    endpoint: Endpoint,
    conn: Connection,
    accept_task: JoinHandle<()>,
}

impl Tunnel {
    /// Graceful teardown: stop accepting, send a clean QUIC CONNECTION_CLOSE, and
    /// drain the endpoint (so the server sees a clean close, not a timeout).
    pub async fn shutdown(self) {
        self.accept_task.abort();
        self.conn.close(0u32.into(), b"client shutdown");
        self.endpoint.close().await;
    }
}

impl Drop for Tunnel {
    fn drop(&mut self) {
        self.accept_task.abort();
        // Closing the connection makes every in-flight bridge stream error out, so
        // the detached pump tasks unwind promptly instead of parking.
        self.conn.close(0u32.into(), b"client dropped");
        // endpoint.close() is async and Drop can't await; schedule a best-effort
        // drain on the current runtime if there is one.
        if let Ok(handle) = tokio::runtime::Handle::try_current() {
            let endpoint = self.endpoint.clone();
            handle.spawn(async move { endpoint.close().await });
        }
    }
}

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

/// Parse the composite pairing code into its EndpointTicket + connect secret.
/// Pure; mirrors `parseCode` in the reference client.
fn parse_pairing_code(code: &str) -> Result<Pairing> {
    let json = b64_loose(code.trim()).context("pairing code is not valid base64")?;
    let v: serde_json::Value =
        serde_json::from_slice(&json).context("pairing code is not valid JSON")?;
    let ticket = v
        .get("t")
        .and_then(|x| x.as_str())
        .ok_or_else(|| anyhow!("pairing code missing ticket (t)"))?
        .to_string();
    let secret_b64 = v
        .get("s")
        .and_then(|x| x.as_str())
        .ok_or_else(|| anyhow!("pairing code missing secret (s)"))?;
    let secret = b64_loose(secret_b64).context("connect secret is not valid base64")?;
    if secret.len() != SECRET_LEN {
        bail!("connect secret must be {SECRET_LEN} bytes (got {})", secret.len());
    }
    Ok(Pairing { ticket, secret })
}

/// Dial a tunnel from a composite pairing code, complete the secret handshake,
/// and start a loopback TCP proxy. Returns once the tunnel is ready to serve.
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

    let conn = tokio::time::timeout(CONNECT_TIMEOUT, endpoint.connect(addr, TUNNEL_ALPN))
        .await
        .map_err(|_| {
            anyhow!(
                "connect timed out after {}s — server unreachable or pairing code stale",
                CONNECT_TIMEOUT.as_secs()
            )
        })?
        .context("iroh connect failed")?;

    // Shared-secret handshake on the first bi-stream (constant-time on the server).
    // A wrong/rotated secret shows up either as a "NO" reply OR as the server
    // resetting/closing the connection — both mean "re-pair".
    let (mut send, mut recv) = conn.open_bi().await.context("failed to open handshake stream")?;
    send.write_all(&pairing.secret)
        .await
        .context("failed to send connect secret")?;
    send.finish().context("failed to finish handshake stream")?;
    match recv.read_to_end(HANDSHAKE_RESP_LIMIT).await {
        Ok(resp) if resp == b"OK" => {}
        Ok(_) => bail!("tunnel handshake rejected — wrong or rotated connect secret; re-pair from the server's Remote Access panel"),
        Err(_) => bail!("tunnel handshake failed — server rejected the secret or the pairing code is stale; re-pair from the server's Remote Access panel"),
    }

    let listener = TcpListener::bind(("127.0.0.1", local_port))
        .await
        .context("failed to bind local proxy port")?;
    let bound_port = listener.local_addr()?.port();

    let conn_for_loop = conn.clone();
    let accept_task = tokio::spawn(async move {
        loop {
            match listener.accept().await {
                Ok((sock, _)) => {
                    let c = conn_for_loop.clone();
                    tokio::spawn(async move { bridge_socket(sock, c).await });
                }
                Err(_) => break,
            }
        }
    });

    Ok(Tunnel {
        local_port: bound_port,
        endpoint,
        conn,
        accept_task,
    })
}

/// One inbound TCP connection ⇆ one fresh iroh bi-stream (full duplex).
///
/// Mirrors the reference `bridge()`/`dispose()`: each direction ends cleanly on
/// EOF (finish/shutdown), but if either direction *errors* we cancel the partner
/// so a half-open stream can't park.
async fn bridge_socket(sock: TcpStream, conn: Connection) {
    let (send, recv) = match conn.open_bi().await {
        Ok(pair) => pair,
        Err(_) => return,
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
