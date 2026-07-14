//! Host-side end-to-end tests: decode a generated sine WAV through the full
//! session engine (file and HTTP paths) and check that windows served for a
//! given playback position contain exactly the samples that live there —
//! position math, seek/chase, downmix, EOF clamp, and fail-open.
//!
//! Each test builds its own `Session`, so tests are parallel-safe (the global
//! single-session surface is just a Mutex around one of these).

use std::io::{Read, Write};
use std::net::TcpListener;
use std::sync::Arc;
use std::time::{Duration, Instant};

use viz_decoder::Session;

const RATE: u32 = 44100;
const FREQ: f64 = 440.0;
const AMP: f64 = 0.6;
const WIN: usize = 1024;

/// 16-bit PCM WAV containing sin(2π·FREQ·n/RATE)·AMP on every channel.
fn wav_sine(secs: f64, channels: u16) -> Vec<u8> {
    let frames = (secs * RATE as f64) as usize;
    let data_len = frames * channels as usize * 2;
    let byte_rate = RATE * channels as u32 * 2;
    let mut out = Vec::with_capacity(44 + data_len);
    out.extend_from_slice(b"RIFF");
    out.extend_from_slice(&(36 + data_len as u32).to_le_bytes());
    out.extend_from_slice(b"WAVEfmt ");
    out.extend_from_slice(&16u32.to_le_bytes());
    out.extend_from_slice(&1u16.to_le_bytes()); // PCM
    out.extend_from_slice(&channels.to_le_bytes());
    out.extend_from_slice(&RATE.to_le_bytes());
    out.extend_from_slice(&byte_rate.to_le_bytes());
    out.extend_from_slice(&(channels * 2).to_le_bytes()); // block align
    out.extend_from_slice(&16u16.to_le_bytes()); // bits per sample
    out.extend_from_slice(b"data");
    out.extend_from_slice(&(data_len as u32).to_le_bytes());
    for n in 0..frames {
        let s = (expected(n as u64) * 32767.0) as i16;
        for _ in 0..channels {
            out.extend_from_slice(&s.to_le_bytes());
        }
    }
    out
}

/// The float the decoder should produce for absolute sample index `n`.
fn expected(n: u64) -> f64 {
    (2.0 * std::f64::consts::PI * FREQ * n as f64 / RATE as f64).sin() * AMP
}

/// Poll `read` until the full window ending at `pos_ms` arrives (or panic).
fn poll_window(s: &Session, pos_ms: u64) -> Vec<f32> {
    let mut buf = vec![0.0f32; WIN];
    let deadline = Instant::now() + Duration::from_secs(15);
    loop {
        let n = s.read(pos_ms, &mut buf);
        if n == WIN as i32 {
            return buf;
        }
        assert_ne!(n, -1, "session died: {:?}", viz_decoder::last_error());
        assert!(
            Instant::now() < deadline,
            "window at {pos_ms}ms never arrived (last_error={:?})",
            viz_decoder::last_error()
        );
        std::thread::sleep(Duration::from_millis(20));
    }
}

/// Window served for `pos_ms` must equal source samples ending at `end_abs`.
fn assert_window(win: &[f32], end_abs: u64) {
    let start = end_abs - win.len() as u64;
    for (k, &v) in win.iter().enumerate() {
        let want = expected(start + k as u64);
        assert!(
            (v as f64 - want).abs() < 2e-3,
            "sample {k} (abs {}): got {v}, want {want}",
            start + k as u64
        );
    }
}

fn ms_to_end(pos_ms: u64) -> u64 {
    pos_ms * RATE as u64 / 1000
}

fn temp_wav(name: &str, secs: f64, channels: u16) -> std::path::PathBuf {
    let p = std::env::temp_dir().join(format!("viz_decoder_test_{}_{name}.wav", std::process::id()));
    std::fs::write(&p, wav_sine(secs, channels)).unwrap();
    p
}

/// Minimal HTTP server for one shared body. `honor_range: false` emulates a
/// transcode-style endpoint that answers 200 from byte 0 no matter what.
fn serve(body: Arc<Vec<u8>>, honor_range: bool) -> String {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let addr = listener.local_addr().unwrap();
    std::thread::spawn(move || {
        for conn in listener.incoming() {
            let Ok(mut sock) = conn else { break };
            let body = body.clone();
            std::thread::spawn(move || {
                let mut req = Vec::new();
                let mut byte = [0u8; 1];
                while !req.ends_with(b"\r\n\r\n") {
                    match sock.read(&mut byte) {
                        Ok(1) => req.push(byte[0]),
                        _ => return,
                    }
                }
                let req = String::from_utf8_lossy(&req);
                let range = req
                    .lines()
                    .find_map(|l| l.strip_prefix("Range: bytes="))
                    .and_then(|r| {
                        let (start, end) = r.trim().split_once('-')?;
                        let start: u64 = start.parse().ok()?;
                        let end: u64 = end
                            .parse()
                            .map(|e: u64| e + 1)
                            .unwrap_or(body.len() as u64);
                        Some((start, end.min(body.len() as u64)))
                    });
                let resp = match range {
                    Some((start, _)) if honor_range && start >= body.len() as u64 => {
                        format!(
                            "HTTP/1.1 416 Range Not Satisfiable\r\nContent-Range: bytes */{}\r\nContent-Length: 0\r\nConnection: close\r\n\r\n",
                            body.len()
                        )
                        .into_bytes()
                    }
                    Some((start, end)) if honor_range => {
                        let chunk = &body[start as usize..end as usize];
                        let mut r = format!(
                            "HTTP/1.1 206 Partial Content\r\nContent-Range: bytes {}-{}/{}\r\nAccept-Ranges: bytes\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                            start,
                            end - 1,
                            body.len(),
                            chunk.len()
                        )
                        .into_bytes();
                        r.extend_from_slice(chunk);
                        r
                    }
                    _ => {
                        let mut r = format!(
                            "HTTP/1.1 200 OK\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                            body.len()
                        )
                        .into_bytes();
                        r.extend_from_slice(&body);
                        r
                    }
                };
                let _ = sock.write_all(&resp);
            });
        }
    });
    format!("http://{addr}/track.wav")
}

#[test]
fn file_read_seek_and_rewind() {
    let path = temp_wav("file", 30.0, 1);
    let s = Session::start(path.to_str().unwrap()).unwrap();
    // Prime + read near the start.
    assert_window(&poll_window(&s, 2_000), ms_to_end(2_000));
    assert_eq!(s.sample_rate(), RATE);
    // Scrub far forward (out of ring coverage → seek).
    assert_window(&poll_window(&s, 20_000), ms_to_end(20_000));
    // Scrub back before coverage (→ seek back).
    assert_window(&poll_window(&s, 1_000), ms_to_end(1_000));
    s.stop();
    let _ = std::fs::remove_file(path);
}

#[test]
fn stereo_downmixes_to_mono() {
    let path = temp_wav("stereo", 5.0, 2);
    let s = Session::start(path.to_str().unwrap()).unwrap();
    // L == R == sine, so the downmixed average is the sine again.
    assert_window(&poll_window(&s, 1_500), ms_to_end(1_500));
    s.stop();
    let _ = std::fs::remove_file(path);
}

#[test]
fn http_range_read_seek_and_rewind() {
    let url = serve(Arc::new(wav_sine(30.0, 1)), true);
    let s = Session::start(&url).unwrap();
    assert_window(&poll_window(&s, 2_000), ms_to_end(2_000));
    assert_window(&poll_window(&s, 20_000), ms_to_end(20_000));
    assert_window(&poll_window(&s, 1_000), ms_to_end(1_000));
    assert_eq!(s.sample_rate(), RATE);
    s.stop();
}

#[test]
fn http_without_range_chases_forward() {
    // 200-only server (transcode-style): starting mid-track must chase from
    // byte 0 and still serve the right window.
    let url = serve(Arc::new(wav_sine(10.0, 1)), false);
    let s = Session::start(&url).unwrap();
    assert_window(&poll_window(&s, 4_000), ms_to_end(4_000));
    s.stop();
}

#[test]
fn eof_clamps_to_final_window() {
    let path = temp_wav("eof", 5.0, 1);
    let total = (5.0 * RATE as f64) as u64;
    let s = Session::start(path.to_str().unwrap()).unwrap();
    // Position past the end (player at 7 s of a 5 s file after a bad seek, or
    // clock skew at the tail): serve the final window instead of going dark.
    assert_window(&poll_window(&s, 7_000), total);
    s.stop();
    let _ = std::fs::remove_file(path);
}

#[test]
fn unreachable_source_fails_open() {
    // Nothing listens on port 1; the session must die (read → -1) with an
    // error message, not hang or panic.
    let s = Session::start("http://127.0.0.1:1/x.mp3").unwrap();
    let mut buf = vec![0.0f32; WIN];
    let deadline = Instant::now() + Duration::from_secs(15);
    loop {
        let n = s.read(1_000, &mut buf);
        if n == -1 {
            break;
        }
        assert_eq!(n, 0, "no real window can exist");
        assert!(Instant::now() < deadline, "session never died");
        std::thread::sleep(Duration::from_millis(20));
    }
    assert!(!s.is_alive());
    assert!(viz_decoder::last_error().is_some());
}
