//! Dev CLI: dial an mStream iroh tunnel from a pairing code and expose it locally.
//! Mirrors `scripts/mstream-iroh-client.mjs` and, importantly, drives the same
//! [`iroh_tunnel::ffi`] entry points the Android binding uses — a plain `main`
//! with NO ambient Tokio runtime, so the owned-runtime model is exercised exactly
//! as flutter_rust_bridge will exercise it.
//!
//!   iroh-tunnel-client <pairing-code> [--local <port>]
//!
//! Prints `LOCAL_PORT=<n>` on stdout (for the interop harness), then blocks until
//! killed.

use iroh_tunnel::ffi::{tunnel_start, tunnel_stop};

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

    eprintln!("[client] starting iroh endpoint…");
    match tunnel_start(code, local_port) {
        Ok(port) => {
            println!("LOCAL_PORT={port}");
            println!("mStream reachable at http://127.0.0.1:{port}/api/");
            eprintln!("[client] connected ✅  (Ctrl-C to quit)");
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
