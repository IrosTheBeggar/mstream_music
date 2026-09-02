//! Dev CLI: dial an mStream iroh tunnel from a pairing code and expose it locally.
//! Mirrors `scripts/mstream-iroh-client.mjs` and, importantly, drives the same
//! [`iroh_tunnel::ffi`] entry points the Android binding uses — a plain `main`
//! with NO ambient Tokio runtime, so the owned-runtime model is exercised exactly
//! as flutter_rust_bridge will exercise it.
//!
//!   iroh-tunnel-client <pairing-code> [--local <port>] [--kick-after <secs>] [--events]
//!
//! Prints `LOCAL_PORT=<n>` on stdout (for the interop harness), then blocks until
//! killed. `--kick-after` forces an in-place reconnect after N seconds (the
//! harness's kick test); `--events` prints the native events ring to stderr
//! every second (`[event] …`).

use iroh_tunnel::ffi::{
    tunnel_drain_events, tunnel_force_reconnect, tunnel_local_token, tunnel_start, tunnel_stop,
};

fn main() {
    let args: Vec<String> = std::env::args().collect();

    let code = match args.get(1) {
        Some(c) if !c.starts_with('-') => c.clone(),
        _ => {
            eprintln!("usage: iroh-tunnel-client <pairing-code> [--local <port>]");
            eprintln!("get the code from the mStream admin panel → Remote Access (Copy code).");
            std::process::exit(2);
        }
    };
    let local_port = args
        .iter()
        .position(|a| a == "--local")
        .and_then(|i| args.get(i + 1))
        .and_then(|p| p.parse::<u16>().ok())
        .unwrap_or(0);
    let kick_after = args
        .iter()
        .position(|a| a == "--kick-after")
        .and_then(|i| args.get(i + 1))
        .and_then(|p| p.parse::<u64>().ok());
    let print_events = args.iter().any(|a| a == "--events");

    eprintln!("[client] starting iroh endpoint…");
    match tunnel_start(code, local_port) {
        Ok(port) => {
            println!("LOCAL_PORT={port}");
            if let Some(t) = tunnel_local_token() {
                println!("LOCAL_TOKEN={t}");
            }
            println!("mStream reachable at http://127.0.0.1:{port}/api/");
            eprintln!("[client] connected ✅  (Ctrl-C to quit)");
            if print_events {
                std::thread::spawn(|| loop {
                    if let Some(events) = tunnel_drain_events() {
                        for line in events.lines() {
                            eprintln!("[event] {line}");
                        }
                    }
                    std::thread::sleep(std::time::Duration::from_secs(1));
                });
            }
            if let Some(secs) = kick_after {
                std::thread::spawn(move || {
                    std::thread::sleep(std::time::Duration::from_secs(secs));
                    eprintln!("[client] kicking the tunnel (in-place reconnect)");
                    tunnel_force_reconnect();
                });
            }
        }
        Err(e) => {
            eprintln!("[client] {e}");
            std::process::exit(1);
        }
    }

    // Best-effort graceful close on Ctrl-C; the accept loop runs on the owned runtime.
    let _ = ctrlc_block();
    tunnel_stop();
}

/// Park until SIGINT/Ctrl-C without pulling in an async runtime here.
fn ctrlc_block() -> std::io::Result<()> {
    // Block forever; the process is terminated by the signal (the interop harness
    // kills the child). A real signal handler isn't needed for a dev tool.
    loop {
        std::thread::park();
    }
}
