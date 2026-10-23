//! The dialing side, run on a SECOND host behind the same NAT as the server.
//! Each attempt binds a fresh endpoint, dials the ticket, opens the first
//! bi-stream, writes, and waits 10 s for the server's reply — the shape of a
//! first connection between two peers. Reports the selected path.
//!
//!   client <ticket> [attempts=5] [--lan-only]
//!
//! `--lan-only` strips the NAT-reflexive addresses from the ticket before
//! dialing (keeps the relay and the private-range addresses): the workaround.

#[path = "../common.rs"]
mod common;

use anyhow::{Context, Result};
use common::{is_lan, stamp, ALPN};
use iroh::{endpoint::presets, Endpoint, EndpointAddr};
use iroh_tickets::endpoint::EndpointTicket;
use std::time::{Duration, Instant};
use tokio::time::timeout;

#[tokio::main]
async fn main() -> Result<()> {
    let args: Vec<String> = std::env::args().collect();
    let ticket = args.get(1).context("usage: client <ticket> [attempts] [--lan-only]")?;
    let attempts: u32 = args.iter().skip(2).find_map(|a| a.parse().ok()).unwrap_or(5);
    let lan_only = args.iter().any(|a| a == "--lan-only");
    let ticket: EndpointTicket = ticket.parse().context("not an EndpointTicket")?;
    let full = ticket.endpoint_addr().clone();
    let addr = if lan_only {
        let mut a = EndpointAddr::new(full.id);
        for r in full.relay_urls() {
            a = a.with_relay_url(r.clone());
        }
        for ip in full.ip_addrs().filter(|s| is_lan(s)) {
            a = a.with_ip_addr(*ip);
        }
        a
    } else {
        full.clone()
    };
    println!(
        "dialing {} with relays [{}] and direct [{}]{}",
        addr.id,
        addr.relay_urls().map(|r| r.to_string()).collect::<Vec<_>>().join(" "),
        addr.ip_addrs().map(|s| format!("{s}{}", if is_lan(s) { "" } else { "(reflexive)" })).collect::<Vec<_>>().join(" "),
        if lan_only { "  [--lan-only]" } else { "" }
    );

    let mut stalls = 0;
    for i in 1..=attempts {
        let ep = Endpoint::builder(presets::N0).bind().await?;
        let _ = timeout(Duration::from_secs(5), ep.online()).await;
        let t0 = Instant::now();
        let conn = match timeout(Duration::from_secs(25), ep.connect(addr.clone(), ALPN)).await {
            Ok(Ok(c)) => c,
            Ok(Err(e)) => {
                println!("[{}] attempt {i}: connect failed after {:.1}s: {e}", stamp(), t0.elapsed().as_secs_f32());
                ep.close().await;
                continue;
            }
            Err(_) => {
                println!("[{}] attempt {i}: connect timed out (25s)", stamp());
                ep.close().await;
                continue;
            }
        };
        let connect_s = t0.elapsed().as_secs_f32();
        let path = || {
            conn.paths()
                .iter()
                .find(|p| p.is_selected())
                .map(|p| if p.is_relay() { "relay" } else { "direct" })
                .unwrap_or("none")
        };
        let (mut send, mut recv) = conn.open_bi().await?;
        send.write_all(b"hello").await?;
        send.finish()?;
        match timeout(Duration::from_secs(10), recv.read_to_end(8)).await {
            Ok(Ok(v)) if v == b"OK" => println!(
                "[{}] attempt {i}: OK — connected in {connect_s:.2}s, reply in {:.2}s, selected path={}",
                stamp(), t0.elapsed().as_secs_f32(), path()
            ),
            Ok(Ok(v)) => println!("[{}] attempt {i}: unexpected reply {v:?}", stamp()),
            Ok(Err(e)) => {
                stalls += 1;
                println!("[{}] attempt {i}: STALL — connected in {connect_s:.2}s, then the stream died: {e}; selected path={}", stamp(), path());
            }
            Err(_) => {
                stalls += 1;
                println!(
                    "[{}] attempt {i}: STALL — connected in {connect_s:.2}s, no reply to the first stream in 10s; selected path={}",
                    stamp(), path()
                );
            }
        }
        conn.close(0u32.into(), b"done");
        ep.close().await;
        tokio::time::sleep(Duration::from_secs(2)).await;
    }
    println!("== {stalls} of {attempts} attempts stalled{}", if lan_only { " (LAN-only ticket)" } else { "" });
    Ok(())
}
