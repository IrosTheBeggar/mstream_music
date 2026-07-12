//! mStream visualizer audio sidecar.
//!
//! Decodes the currently-playing source — a downloaded file path or the same
//! HTTP(S) stream URL the player uses (mStream direct, transcode endpoint, or
//! the iroh tunnel's loopback) — into a rolling ring of mono f32 PCM, and
//! serves fixed-size windows keyed to a playback position over a C ABI
//! (`src/c_api.rs`, consumed via `dart:ffi` from `lib/native/viz_decoder.dart`).
//! The Dart side runs its existing FFT on the window, so this crate never
//! touches frequency space: decode is the only thing Dart can't do fast.
//!
//! Everything fails OPEN: any error (unreachable server, unsupported codec —
//! e.g. opus, TLS to a self-signed cert) kills the session, `read` starts
//! returning -1, and the visualizer falls back to its synthesized signal.
//!
//! One session at a time (the visualizer shows one track); a track change is
//! `start` with the new URL, which replaces the previous session.

mod c_api;
mod engine;
mod http_source;

pub use engine::{last_error, set_last_error, Session};
pub use http_source::HttpSource;
