//! Dev CLI: dial an mStream iroh tunnel from a code and expose it locally.
//! Mirrors `scripts/mstream-iroh-client.mjs` and, importantly, drives the same
//! [`iroh_tunnel::ffi`] entry points the app binding uses — a plain `main`
//! with NO ambient Tokio runtime, so the owned-runtime model is exercised exactly
//! as `dart:ffi` exercises it. The tunnel runs under the key "cli".
//!
//!   iroh-tunnel-client <code> [--local <port>] [--kick-after <secs>] [--events]
//!                      [--swap-after <secs> <code>]
//!
//! `<code>` is a Quick Connect pairing code (`mstr1:…`) or a federation guest
//! ticket (`mstrfedg1:…`). Prints `LOCAL_PORT=<n>` on stdout (for the interop
//! harness), then blocks until killed. `--kick-after` forces an in-place
//! reconnect after N seconds (the harness's kick test); `--swap-after` swaps
//! the credential in place after N seconds (the guest test); `--events` prints
//! the native events ring to stderr every second (`[event] …`).

use iroh_tunnel::ffi::{
    tunnel_drain_events, tunnel_force_reconnect, tunnel_local_token, tunnel_set_credential,
    tunnel_start, tunnel_stop, ABI_VERSION,
};

const KEY: &str = "cli";

fn main() {
    let args: Vec<String> = std::env::args().collect();

    let code = match args.get(1) {
        Some(c) if !c.starts_with('-') => c.clone(),
        _ => {
            eprintln!("usage: iroh-tunnel-client <code> [--local <port>] [--kick-after <secs>] [--events] [--swap-after <secs> <code>]");
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
    let swap_after = args
        .iter()
        .position(|a| a == "--swap-after")
        .and_then(|i| Some((args.get(i + 1)?.parse::<u64>().ok()?, args.get(i + 2)?.clone())));
    let print_events = args.iter().any(|a| a == "--events");

    eprintln!("[client] starting iroh endpoint (abi v{ABI_VERSION})…");
    match tunnel_start(KEY.to_owned(), code, local_port) {
        Ok(port) => {
            println!("LOCAL_PORT={port}");
            if let Some(t) = tunnel_local_token(KEY) {
                println!("LOCAL_TOKEN={t}");
            }
            println!("mStream reachable at http://127.0.0.1:{port}/api/");
            eprintln!("[client] connected ✅  (Ctrl-C to quit)");
            if print_events {
                std::thread::spawn(|| loop {
                    if let Some(events) = tunnel_drain_events(KEY) {
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
                    tunnel_force_reconnect(KEY);
                });
            }
            if let Some((secs, new_code)) = swap_after {
                std::thread::spawn(move || {
                    std::thread::sleep(std::time::Duration::from_secs(secs));
                    match tunnel_set_credential(KEY, &new_code) {
                        Ok(()) => eprintln!("[client] credential swapped in place"),
                        Err(e) => eprintln!("[client] credential swap failed: {e}"),
                    }
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
    tunnel_stop(KEY);
}

/// Park until SIGINT/Ctrl-C without pulling in an async runtime here.
fn ctrlc_block() -> std::io::Result<()> {
    // Block forever; the process is terminated by the signal (the interop harness
    // kills the child). A real signal handler isn't needed for a dev tool.
    loop {
        std::thread::park();
    }
}
