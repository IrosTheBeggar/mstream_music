//! A symphonia [`MediaSource`] over HTTP(S) using Range requests for seeks.
//!
//! The opening request sends `Range: bytes=0-`: a 206 answer marks the source
//! seekable (total length from `Content-Range`), a 200 answer marks it a
//! linear stream (e.g. a transcode endpoint) where only forward "seeks" work,
//! by reading and discarding. Seeks on a seekable source are lazy — they just
//! record the target offset and the next `read` opens `Range: bytes=<pos>-`,
//! so the seek-happy probing of e.g. mp4 containers doesn't burn one request
//! per hop. A mid-stream connection drop on a seekable source is retried
//! transparently once at the current offset.

use std::io::{self, ErrorKind, Read, Seek, SeekFrom};
use std::sync::Mutex;
use std::time::Duration;

use symphonia::core::io::MediaSource;

struct Inner {
    /// Current response body, if a request is open. `None` after a (lazy)
    /// seek and after a retriable read error.
    reader: Option<Box<dyn Read + Send>>,
    /// Absolute byte offset the next `read` serves.
    pos: u64,
    /// One transparent reconnect per drop; reset by a successful read.
    retried: bool,
}

pub struct HttpSource {
    agent: ureq::Agent,
    url: String,
    len: Option<u64>,
    seekable: bool,
    // Mutex only to satisfy MediaSource's `Sync` bound; all access is from the
    // single decode thread, so it's never contended.
    state: Mutex<Inner>,
}

impl HttpSource {
    pub fn open(url: &str) -> io::Result<HttpSource> {
        let agent = ureq::AgentBuilder::new()
            .timeout_connect(Duration::from_secs(8))
            // A stalled server kills the session (fail-open to synth) instead
            // of wedging the decode thread forever.
            .timeout_read(Duration::from_secs(15))
            .build();
        let resp = match agent.get(url).set("Range", "bytes=0-").call() {
            Ok(r) => r,
            Err(ureq::Error::Status(code, _)) => {
                return Err(io::Error::other(format!("HTTP {code}")))
            }
            Err(e) => return Err(io::Error::other(e.to_string())),
        };
        let seekable = resp.status() == 206;
        let len = if seekable {
            // Content-Range: bytes 0-…/<total>
            resp.header("Content-Range")
                .and_then(|v| v.rsplit('/').next())
                .and_then(|t| t.trim().parse().ok())
        } else {
            resp.header("Content-Length").and_then(|v| v.trim().parse().ok())
        };
        Ok(HttpSource {
            agent,
            url: url.to_owned(),
            len,
            seekable,
            state: Mutex::new(Inner {
                reader: Some(Box::new(resp.into_reader())),
                pos: 0,
                retried: false,
            }),
        })
    }

    /// Open the body at an absolute offset. `Ok(None)` = at/past EOF (416).
    fn body_at(&self, pos: u64) -> io::Result<Option<Box<dyn Read + Send>>> {
        match self
            .agent
            .get(&self.url)
            .set("Range", &format!("bytes={pos}-"))
            .call()
        {
            Ok(r) if r.status() == 206 => Ok(Some(Box::new(r.into_reader()))),
            // The server honored Range at open time but stopped — bail rather
            // than silently decoding from byte 0 as if it were offset `pos`.
            Ok(r) => Err(io::Error::other(
                format!("range request answered {}", r.status()),
            )),
            Err(ureq::Error::Status(416, _)) => Ok(None),
            Err(ureq::Error::Status(code, _)) => {
                Err(io::Error::other(format!("HTTP {code}")))
            }
            Err(e) => Err(io::Error::other(e.to_string())),
        }
    }
}

impl Read for HttpSource {
    fn read(&mut self, buf: &mut [u8]) -> io::Result<usize> {
        let inner = &mut *self.state.lock().unwrap();
        loop {
            if inner.reader.is_none() {
                if self.len.is_some_and(|l| inner.pos >= l) {
                    return Ok(0);
                }
                match self.body_at(inner.pos)? {
                    Some(r) => inner.reader = Some(r),
                    None => return Ok(0), // 416: past the end
                }
            }
            match inner.reader.as_mut().unwrap().read(buf) {
                Ok(n) => {
                    inner.pos += n as u64;
                    inner.retried = false;
                    return Ok(n);
                }
                Err(e) => {
                    if self.seekable && !inner.retried {
                        // Dropped mid-stream (idle keep-alive closed while the
                        // decoder was parked, network blip): reconnect once at
                        // the current offset.
                        inner.retried = true;
                        inner.reader = None;
                        continue;
                    }
                    return Err(e);
                }
            }
        }
    }
}

impl Seek for HttpSource {
    fn seek(&mut self, from: SeekFrom) -> io::Result<u64> {
        let inner = &mut *self.state.lock().unwrap();
        let target: i128 = match from {
            SeekFrom::Start(s) => s as i128,
            SeekFrom::Current(d) => inner.pos as i128 + d as i128,
            SeekFrom::End(d) => match self.len {
                Some(l) => l as i128 + d as i128,
                None => {
                    return Err(io::Error::other(
                        "seek from end of unsized stream",
                    ))
                }
            },
        };
        if target < 0 {
            return Err(io::Error::new(ErrorKind::InvalidInput, "seek before start"));
        }
        let target = target as u64;
        if target == inner.pos {
            return Ok(target);
        }
        if !self.seekable {
            if target < inner.pos {
                return Err(io::Error::other(
                    "backward seek on a non-Range stream",
                ));
            }
            // Forward: read and discard on the live body.
            let mut remaining = target - inner.pos;
            let mut sink = [0u8; 8192];
            while remaining > 0 {
                let reader = inner
                    .reader
                    .as_mut()
                    .ok_or_else(|| io::Error::other("stream exhausted"))?;
                let want = remaining.min(sink.len() as u64) as usize;
                let n = reader.read(&mut sink[..want])?;
                if n == 0 {
                    break; // EOF before target; pos is honest
                }
                inner.pos += n as u64;
                remaining -= n as u64;
            }
            return Ok(inner.pos);
        }
        // Lazy: the next read opens Range: bytes=<target>-.
        inner.reader = None;
        inner.retried = false;
        inner.pos = target;
        Ok(target)
    }
}

impl MediaSource for HttpSource {
    fn is_seekable(&self) -> bool {
        self.seekable
    }

    fn byte_len(&self) -> Option<u64> {
        self.len
    }
}
