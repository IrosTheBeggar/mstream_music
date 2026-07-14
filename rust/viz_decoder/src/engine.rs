//! Decode session: one background thread chasing a wanted playback position.
//!
//! The reader (Dart, ~60 Hz) calls [`Session::read`] with the current playback
//! position; that both serves the PCM window ending there (when buffered) and
//! retargets the decode thread. The thread keeps a rolling ring of mono f32
//! covering roughly [wanted − ring, wanted + ahead]: it decodes forward while
//! behind, parks when comfortably ahead, and re-seeks (or, on a non-Range
//! stream, reopens/chases) when the wanted position jumps outside coverage —
//! i.e. the user scrubbed.
//!
//! `read` never blocks and returns either a FULL window or 0, matching the
//! AudioCapture contract in Dart: a short read means "fall back to the
//! synthesized signal for this frame".

use std::sync::atomic::{AtomicBool, AtomicU32, AtomicU64, Ordering};
use std::sync::{Arc, Condvar, Mutex};
use std::time::Duration;

use symphonia::core::audio::SampleBuffer;
use symphonia::core::codecs::{Decoder, DecoderOptions, CODEC_TYPE_NULL};
use symphonia::core::errors::Error as SymError;
use symphonia::core::formats::{FormatOptions, FormatReader, SeekMode, SeekTo};
use symphonia::core::io::{MediaSource, MediaSourceStream};
use symphonia::core::meta::MetadataOptions;
use symphonia::core::probe::Hint;
use symphonia::core::units::{Time, TimeBase};

use crate::http_source::HttpSource;

/// Ring capacity: how far back from the newest decoded sample reads can land.
const RING_MS: u64 = 12_000;
/// Decode-ahead budget past the wanted position before the thread parks.
const AHEAD_MS: u64 = 4_000;
/// A wanted position this far past buffered coverage is a scrub, not a chase.
const FORWARD_GAP_MS: u64 = 6_000;
/// Seeks land this far before the wanted position so its window (which ends at
/// the wanted position, i.e. starts ~93 ms before it) is servable right away.
const BACK_MARGIN_MS: u64 = 500;
/// Reader window slack used in coverage decisions (samples). Must stay below
/// BACK_MARGIN_MS worth of samples at any real rate; 4096 @ 44.1 kHz ≈ 93 ms.
const WINDOW_SLACK: u64 = 4096;

static LAST_ERROR: Mutex<Option<String>> = Mutex::new(None);

pub fn set_last_error(msg: String) {
    // Poison-tolerant: never panic across the decode thread / FFI boundary.
    *LAST_ERROR.lock().unwrap_or_else(|e| e.into_inner()) = Some(msg);
}

pub fn last_error() -> Option<String> {
    LAST_ERROR.lock().unwrap_or_else(|e| e.into_inner()).clone()
}

struct Ring {
    /// Circular buffer; the sample with absolute index `a` (valid while
    /// `end_abs - filled <= a < end_abs`) lives at `buf[a % buf.len()]`.
    buf: Vec<f32>,
    /// One past the newest stored sample, as an absolute track sample index.
    end_abs: u64,
    /// Valid samples ending at `end_abs`.
    filled: usize,
    /// Decoder reached end of stream; `end_abs` is the track end, and reads
    /// past it clamp to the final window instead of going dark.
    ended: bool,
}

struct Shared {
    wanted_ms: AtomicU64,
    stop: AtomicBool,
    dead: AtomicBool,
    sample_rate: AtomicU32,
    ring: Mutex<Ring>,
    wake: Condvar,
}

impl Shared {
    fn fail(&self, msg: String) {
        set_last_error(msg);
        self.dead.store(true, Ordering::Relaxed);
    }
}

/// A running decode of one source. Dropping it stops the thread.
pub struct Session {
    shared: Arc<Shared>,
}

impl Session {
    /// Spawn the decode thread for `source` (http(s):// URL, file:// URL, or a
    /// bare filesystem path). Never blocks: open/probe errors surface later as
    /// a dead session (`read` → -1, [`last_error`] says why).
    pub fn start(source: &str) -> Result<Session, String> {
        let shared = Arc::new(Shared {
            wanted_ms: AtomicU64::new(0),
            stop: AtomicBool::new(false),
            dead: AtomicBool::new(false),
            sample_rate: AtomicU32::new(0),
            ring: Mutex::new(Ring {
                buf: Vec::new(),
                end_abs: 0,
                filled: 0,
                ended: false,
            }),
            wake: Condvar::new(),
        });
        let thread_shared = shared.clone();
        let url = source.to_owned();
        std::thread::Builder::new()
            .name("viz_decoder".into())
            .spawn(move || run(thread_shared, url))
            .map_err(|e| format!("spawn decode thread: {e}"))?;
        Ok(Session { shared })
    }

    /// Copy the mono window ENDING at `position_ms` into `out`. Returns
    /// `out.len()` when the whole window was served, 0 while it isn't buffered
    /// (priming, mid-scrub), and -1 once the session is dead. Also retargets
    /// the decode thread at `position_ms`.
    pub fn read(&self, position_ms: u64, out: &mut [f32]) -> i32 {
        let s = &*self.shared;
        if s.dead.load(Ordering::Relaxed) {
            return -1;
        }
        s.wanted_ms.store(position_ms, Ordering::Relaxed);
        let rate = s.sample_rate.load(Ordering::Relaxed);
        let n = out.len();
        let mut copied = 0;
        if rate > 0 && n > 0 {
            let r = s.ring.lock().unwrap_or_else(|e| e.into_inner());
            let mut want_end = ms_to_samples(position_ms, rate);
            if r.ended && want_end > r.end_abs {
                want_end = r.end_abs; // hold the final window at the tail
            }
            let lo = r.end_abs - r.filled as u64;
            if want_end <= r.end_abs && want_end >= lo + n as u64 {
                let cap = r.buf.len() as u64;
                let start = want_end - n as u64;
                for (k, slot) in out.iter_mut().enumerate() {
                    *slot = r.buf[((start + k as u64) % cap) as usize];
                }
                copied = n;
            }
        }
        s.wake.notify_all();
        copied as i32
    }

    /// Decoded sample rate; 0 until the probe finished.
    pub fn sample_rate(&self) -> u32 {
        self.shared.sample_rate.load(Ordering::Relaxed)
    }

    /// False once the session failed (see [`last_error`]).
    pub fn is_alive(&self) -> bool {
        !self.shared.dead.load(Ordering::Relaxed)
    }

    pub fn stop(&self) {
        self.shared.stop.store(true, Ordering::Relaxed);
        self.shared.wake.notify_all();
        // The thread is detached; it exits at the next park/packet boundary
        // (worst case one HTTP read timeout later, holding nothing we need).
    }
}

impl Drop for Session {
    fn drop(&mut self) {
        self.stop();
    }
}

// ---------------------------------------------------------------------------
// Global single-session surface for the C ABI.

static CURRENT: Mutex<Option<Session>> = Mutex::new(None);

fn current() -> std::sync::MutexGuard<'static, Option<Session>> {
    CURRENT.lock().unwrap_or_else(|e| e.into_inner())
}

/// Replace the active session (if any) with one decoding `source`.
pub fn global_start(source: &str) -> Result<(), String> {
    let session = Session::start(source)?;
    *current() = Some(session); // old session drops → stops
    Ok(())
}

pub fn global_stop() {
    *current() = None;
}

pub fn global_read(position_ms: u64, out: &mut [f32]) -> i32 {
    match &*current() {
        Some(s) => s.read(position_ms, out),
        None => -1,
    }
}

pub fn global_sample_rate() -> u32 {
    current().as_ref().map_or(0, |s| s.sample_rate())
}

pub fn global_is_active() -> bool {
    current().as_ref().is_some_and(|s| s.is_alive())
}

// ---------------------------------------------------------------------------
// Decode thread.

struct Opened {
    format: Box<dyn FormatReader>,
    decoder: Box<dyn Decoder>,
    track_id: u32,
    rate: u32,
    tb: Option<TimeBase>,
    seekable: bool,
    /// Total frames when the container declares them (used to keep scrub
    /// targets inside the stream — seeking past the end is a format error).
    total: Option<u64>,
}

fn ext_of(path: &str) -> Option<String> {
    let clean = path.split(['?', '#']).next().unwrap_or(path);
    let ext = clean.rsplit('/').next()?.rsplit_once('.')?.1;
    (!ext.is_empty() && ext.len() <= 4 && ext.chars().all(|c| c.is_ascii_alphanumeric()))
        .then(|| ext.to_ascii_lowercase())
}

fn open_source(url: &str) -> Result<Opened, String> {
    let (src, ext): (Box<dyn MediaSource>, Option<String>) =
        if url.starts_with("http://") || url.starts_with("https://") {
            let http = HttpSource::open(url).map_err(|e| format!("http open: {e}"))?;
            (Box::new(http), ext_of(url))
        } else {
            let path = url.strip_prefix("file://").unwrap_or(url);
            let file = std::fs::File::open(path).map_err(|e| format!("open {path}: {e}"))?;
            (Box::new(file), ext_of(path))
        };
    let seekable = src.is_seekable();
    let mss = MediaSourceStream::new(src, Default::default());
    let mut hint = Hint::new();
    if let Some(e) = &ext {
        hint.with_extension(e);
    }
    let probed = symphonia::default::get_probe()
        .format(
            &hint,
            mss,
            &FormatOptions::default(),
            &MetadataOptions::default(),
        )
        .map_err(|e| format!("probe: {e}"))?;
    let format = probed.format;
    let track = format
        .tracks()
        .iter()
        .find(|t| t.codec_params.codec != CODEC_TYPE_NULL && t.codec_params.sample_rate.is_some())
        .ok_or("no decodable audio track")?;
    let rate = track.codec_params.sample_rate.unwrap();
    let tb = track.codec_params.time_base;
    let track_id = track.id;
    let total = track.codec_params.n_frames;
    let decoder = symphonia::default::get_codecs()
        .make(&track.codec_params, &DecoderOptions::default())
        .map_err(|e| format!("decoder: {e}"))?;
    Ok(Opened {
        format,
        decoder,
        track_id,
        rate,
        tb,
        seekable,
        total,
    })
}

fn ms_to_samples(ms: u64, rate: u32) -> u64 {
    ms * rate as u64 / 1000
}

fn time_to_samples(t: Time, rate: u32) -> u64 {
    // round(), not truncate: frac is an f64 division artifact, and e.g.
    // (22004/44100)·44100 = 22003.999… would shift every served window by one
    // sample when truncated.
    t.seconds * rate as u64 + (t.frac * rate as f64).round() as u64
}

/// Packet/seek timestamp (in `tb` units) → absolute sample index. Audio
/// timebases are almost always 1/rate, where the timestamp already IS the
/// sample index — take it exactly and only go through float time otherwise.
fn ts_to_samples(ts: u64, tb: Option<TimeBase>, rate: u32) -> u64 {
    match tb {
        Some(tb) if tb.numer == 1 && tb.denom == rate => ts,
        Some(tb) => time_to_samples(tb.calc_time(ts), rate),
        None => ts,
    }
}

fn samples_to_time(s: u64, rate: u32) -> Time {
    Time::new(s / rate as u64, (s % rate as u64) as f64 / rate as f64)
}

fn run(shared: Arc<Shared>, url: String) {
    // Outer loop: one iteration per stream open. Re-entered only for a
    // backward scrub on a non-Range stream (restart from byte 0 and chase).
    'open: loop {
        if shared.stop.load(Ordering::Relaxed) {
            return;
        }
        let mut o = match open_source(&url) {
            Ok(o) => o,
            Err(e) => {
                shared.fail(e);
                return;
            }
        };
        let rate = o.rate;
        let cap = ms_to_samples(RING_MS, rate) as usize;
        {
            let mut r = shared.ring.lock().unwrap_or_else(|e| e.into_inner());
            if r.buf.len() != cap {
                r.buf = vec![0.0; cap];
            }
            r.end_abs = 0;
            r.filled = 0;
            r.ended = false;
        }
        shared.sample_rate.store(rate, Ordering::Relaxed);

        let mut sample_buf: Option<SampleBuffer<f32>> = None;
        let mut mono: Vec<f32> = Vec::new();
        // Absolute sample index of the next decoded frame; None = resync the
        // ring position from the next packet's timestamp (after open / seek /
        // a skipped corrupt packet).
        let mut cursor: Option<u64> = None;
        let mut ended = false;
        // Last scrub target, so a coarse seek that lands past the wanted
        // position (mp3 byte estimation can overshoot) doesn't re-trigger the
        // same seek forever. Clears itself when the wanted position moves.
        let mut last_seek_target: Option<u64> = None;

        loop {
            if shared.stop.load(Ordering::Relaxed) {
                return;
            }
            let wanted = ms_to_samples(shared.wanted_ms.load(Ordering::Relaxed), rate);
            let (lo, hi) = {
                let r = shared.ring.lock().unwrap_or_else(|e| e.into_inner());
                (r.end_abs - r.filled as u64, r.end_abs)
            };

            // The window ending at `wanted` starts before ring coverage and
            // can't be reached by decoding forward → scrub backward.
            let needs_back = lo > 0 && wanted.saturating_sub(WINDOW_SLACK) < lo;
            // Far past coverage → scrub forward (chasing would take longer
            // than a coarse seek). On a non-Range stream chasing is all there is.
            let needs_fwd = !ended && wanted > hi + ms_to_samples(FORWARD_GAP_MS, rate);

            let mut target = wanted.saturating_sub(ms_to_samples(BACK_MARGIN_MS, rate));
            if let Some(total) = o.total {
                // Seeking past the end is a format error; land before it and
                // let EOF + the read-side clamp handle the tail.
                target = target.min(total.saturating_sub(ms_to_samples(BACK_MARGIN_MS, rate)));
            }
            if !needs_back && !needs_fwd {
                // Coverage is healthy; allow a future scrub back to the same
                // spot to seek again.
                last_seek_target = None;
            }
            if (needs_back || needs_fwd) && last_seek_target != Some(target) {
                if o.seekable {
                    let to = SeekTo::Time {
                        time: samples_to_time(target, rate),
                        track_id: Some(o.track_id),
                    };
                    last_seek_target = Some(target);
                    match o.format.seek(SeekMode::Coarse, to) {
                        Ok(seeked) => {
                            o.decoder.reset();
                            cursor = None;
                            ended = false;
                            // Point ring coverage at the landing spot so the
                            // reposition checks don't run off stale coverage
                            // (the first decoded packet re-syncs it exactly).
                            let abs = ts_to_samples(seeked.actual_ts, o.tb, rate);
                            let mut r = shared.ring.lock().unwrap_or_else(|e| e.into_inner());
                            r.end_abs = abs;
                            r.filled = 0;
                            r.ended = false;
                        }
                        Err(e) => {
                            // A refused scrub (e.g. out-of-range on a stream
                            // with no declared length) isn't fatal: keep
                            // decoding from where we are; last_seek_target
                            // stops this exact target from spinning.
                            set_last_error(format!("seek: {e}"));
                        }
                    }
                } else if needs_back {
                    continue 'open;
                }
                // Non-Range forward scrub: fall through and chase by decoding.
            }

            // Comfortably ahead (or at EOF): park until the reader retargets.
            if ended || hi >= wanted + ms_to_samples(AHEAD_MS, rate) {
                let r = shared.ring.lock().unwrap_or_else(|e| e.into_inner());
                drop(
                    shared
                        .wake
                        .wait_timeout(r, Duration::from_millis(100))
                        .unwrap_or_else(|e| e.into_inner()),
                );
                continue;
            }

            let packet = match o.format.next_packet() {
                Ok(p) => p,
                Err(SymError::IoError(ref e))
                    if e.kind() == std::io::ErrorKind::UnexpectedEof =>
                {
                    ended = true;
                    shared
                        .ring
                        .lock()
                        .unwrap_or_else(|e| e.into_inner())
                        .ended = true;
                    continue;
                }
                Err(e) => {
                    shared.fail(format!("read packet: {e}"));
                    return;
                }
            };
            if packet.track_id() != o.track_id {
                continue;
            }
            if cursor.is_none() {
                let abs = ts_to_samples(packet.ts(), o.tb, rate);
                cursor = Some(abs);
                let mut r = shared.ring.lock().unwrap_or_else(|e| e.into_inner());
                r.end_abs = abs;
                r.filled = 0;
            }
            match o.decoder.decode(&packet) {
                Ok(audio) => {
                    let spec = *audio.spec();
                    let ch = spec.channels.count().max(1);
                    let need = audio.capacity() * ch;
                    if sample_buf.as_ref().is_none_or(|b| b.capacity() < need) {
                        sample_buf = Some(SampleBuffer::new(audio.capacity() as u64, spec));
                    }
                    let sb = sample_buf.as_mut().unwrap();
                    sb.copy_interleaved_ref(audio);
                    let interleaved = sb.samples();
                    let frames = interleaved.len() / ch;
                    mono.clear();
                    mono.reserve(frames);
                    for f in 0..frames {
                        let mut acc = 0.0f32;
                        for c in 0..ch {
                            acc += interleaved[f * ch + c];
                        }
                        mono.push(acc / ch as f32);
                    }
                    let mut r = shared.ring.lock().unwrap_or_else(|e| e.into_inner());
                    let ring_cap = r.buf.len() as u64;
                    let mut end = r.end_abs;
                    for &v in &mono {
                        let idx = (end % ring_cap) as usize;
                        r.buf[idx] = v;
                        end += 1;
                    }
                    r.end_abs = end;
                    r.filled = (r.filled + mono.len()).min(r.buf.len());
                    *cursor.as_mut().unwrap() += frames as u64;
                }
                Err(SymError::DecodeError(_)) => {
                    // Corrupt packet: skip it and resync position from the
                    // next packet's timestamp.
                    cursor = None;
                }
                Err(e) => {
                    shared.fail(format!("decode: {e}"));
                    return;
                }
            }
        }
    }
}
