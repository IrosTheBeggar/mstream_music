//! The accepting side. Prints its ticket (the full EndpointAddr: relay +
//! every direct address iroh knows, LAN and NAT-reflexive alike), then
//! traces each incoming connection: when the QUIC handshake completes, where
//! the packets come from, and whether the client's first stream ever arrives.
//!
//!   cargo run --release --bin server

#[path = "../common.rs"]
mod common;

use anyhow::Result;
use common::{is_lan, stamp, ALPN};
use iroh::{endpoint::presets, Endpoint};
use iroh_tickets::endpoint::EndpointTicket;
use std::time::{Duration, Instant};
use tokio::time::timeout;

#[tokio::main]
async fn main() -> Result<()> {
    let ep = Endpoint::builder(presets::N0)
        .alpns(vec![ALPN.to_vec()])
        .bind()
        .await?;
    let online = timeout(Duration::from_secs(10), ep.online()).await.is_ok();
    let addr = ep.addr();
    println!("endpoint id: {}", ep.id());
    println!("online: {online}");
    for r in addr.relay_urls() {
        println!("relay: {r}");
    }
    for a in addr.ip_addrs() {
        println!("direct: {a}  [{}]", if is_lan(a) { "LAN" } else { "NAT-reflexive" });
    }
    println!("TICKET={}", EndpointTicket::new(addr.clone()));
    println!("[{}] accepting on {:?}", stamp(), String::from_utf8_lossy(ALPN));

    while let Some(incoming) = ep.accept().await {
        tokio::spawn(async move {
            let t0 = Instant::now();
            let from = format!("{:?}", incoming.remote_addr());
            println!("[{}] incoming from {from}", stamp());
            let connecting = match incoming.accept() {
                Ok(c) => c,
                Err(e) => {
                    println!("[{}] accept error from {from}: {e}", stamp());
                    return;
                }
            };
            let conn = match timeout(Duration::from_secs(30), connecting).await {
                Ok(Ok(c)) => c,
                Ok(Err(e)) => {
                    println!(
                        "[{}] STALL: handshake from {from} failed after {:.1}s: {e}",
                        stamp(),
                        t0.elapsed().as_secs_f32()
                    );
                    return;
                }
                Err(_) => {
                    println!("[{}] STALL: handshake from {from} not complete after 30s", stamp());
                    return;
                }
            };
            let paths: Vec<String> = conn
                .paths()
                .iter()
                .map(|p| format!("{}{}", if p.is_relay() { "relay" } else { "direct" }, if p.is_selected() { "*" } else { "" }))
                .collect();
            println!(
                "[{}] connected in {:.2}s from {from}: remote_id={} paths={}",
                stamp(),
                t0.elapsed().as_secs_f32(),
                conn.remote_id(),
                paths.join(",")
            );
            match timeout(Duration::from_secs(10), conn.accept_bi()).await {
                Ok(Ok((mut send, mut recv))) => {
                    let got = recv.read_to_end(64).await.unwrap_or_default();
                    let _ = send.write_all(b"OK").await;
                    let _ = send.finish();
                    println!(
                        "[{}] handshake OK in {:.2}s ({} bytes from the client)",
                        stamp(),
                        t0.elapsed().as_secs_f32(),
                        got.len()
                    );
                }
                Ok(Err(e)) => println!("[{}] stream error after {:.1}s: {e}", stamp(), t0.elapsed().as_secs_f32()),
                Err(_) => println!("[{}] STALL: connected but no stream from the client within 10s", stamp()),
            }
            tokio::time::sleep(Duration::from_secs(2)).await;
            conn.close(0u32.into(), b"done");
        });
    }
    Ok(())
}
