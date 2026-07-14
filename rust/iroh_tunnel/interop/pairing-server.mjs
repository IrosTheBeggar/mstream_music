// Long-lived pairing server for manual / E2E testing of app builds:
// the server half of harness.mjs (steps 1-3 — stub backend, iroh endpoint,
// composite pairing code) WITHOUT the Rust-client spawn or the assertions,
// kept alive until killed. Point a dev build of the app at it (simulator,
// emulator, or a real device) to exercise the full Quick Connect path —
// pairing dial, loopback token auth, and Range/seek streaming — with no
// mStream server checkout needed.
//
// Usage:
//   cd rust/iroh_tunnel/interop && npm install
//   node pairing-server.mjs
//   → prints PAIRING_CODE=mstr1:... ; paste it into the app's Quick Connect
//     tab (or feed it to a test via --dart-define=IROH_CODE=...).
//
// The stub backend answers JSON on every path and honors Range on /media
// (AVPlayer on iOS refuses servers that ignore Range, so keep that fidelity).
// Auth note for test writers: the loopback __lt token is checked once per
// TCP connection (the shim peeks the first request line), so an
// "un-tokened request is rejected" check must use a FRESH connection, not
// a kept-alive socket that already authenticated.

import net from 'node:net';
import http from 'node:http';
import crypto from 'node:crypto';
import { Endpoint, EndpointTicket } from '@number0/iroh';

const TUNNEL_ALPN = Array.from(Buffer.from('mstream/tunnel/2'));
const READ_CHUNK = 64 * 1024;
const HANDSHAKE_LIMIT = 256;
const MEDIA = Buffer.alloc(4 * 1024 * 1024);
for (let i = 0; i < MEDIA.length; i++) MEDIA[i] = i & 0xff;
const delay = (ms) => new Promise((r) => setTimeout(r, ms));

async function pumpRecvToSocket(recv, socket) {
  for (;;) {
    const chunk = await recv.read(READ_CHUNK);
    if (chunk.length === 0) break;
    if (!socket.write(Buffer.from(chunk))) {
      await new Promise((resolve) => {
        const done = () => { socket.off('drain', done); socket.off('close', done); resolve(); };
        socket.once('drain', done); socket.once('close', done);
      });
    }
    if (socket.destroyed || socket.writableEnded) break;
  }
  if (!socket.destroyed) socket.end();
}
async function pumpSocketToSend(socket, send) {
  for await (const chunk of socket) await send.writeAll(Array.from(chunk));
  await send.finish();
}
function bridge(socket, bi) {
  let disposed = false;
  const dispose = () => {
    if (disposed) return; disposed = true;
    try { socket.destroy(); } catch { /* gone */ }
    bi.recv.stop(0n).catch(() => {});
    bi.send.reset(0n).catch(() => {});
  };
  socket.once('error', dispose);
  pumpRecvToSocket(bi.recv, socket).catch(dispose);
  pumpSocketToSend(socket, bi.send).catch(dispose);
}

async function main() {
  const stub = http.createServer((req, res) => {
    if (req.url.startsWith('/media')) {
      const range = req.headers.range && /bytes=(\d+)-(\d+)/.exec(req.headers.range);
      if (range) {
        const start = +range[1], end = +range[2];
        const chunk = MEDIA.subarray(start, end + 1);
        res.writeHead(206, {
          'Content-Range': `bytes ${start}-${end}/${MEDIA.length}`,
          'Accept-Ranges': 'bytes',
          'Content-Length': String(chunk.length),
          'Content-Type': 'application/octet-stream',
        });
        res.end(chunk);
      } else {
        res.writeHead(200, { 'Content-Length': String(MEDIA.length), 'Accept-Ranges': 'bytes' });
        res.end(MEDIA);
      }
      return;
    }
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true, path: req.url }));
  });
  await new Promise((r) => stub.listen(0, '127.0.0.1', r));
  const stubPort = stub.address().port;
  console.log(`[server] stub backend on 127.0.0.1:${stubPort}`);

  const secretKey = crypto.randomBytes(32);
  const connectSecret = crypto.randomBytes(32);
  const endpoint = await Endpoint.bind({ alpns: [TUNNEL_ALPN], secretKey: Array.from(secretKey) });
  await Promise.race([endpoint.online().catch(() => {}), delay(8000)]);
  console.log(`[server] endpointId=${endpoint.id().toString()}`);

  (async () => {
    for (;;) {
      let incoming;
      try { incoming = await endpoint.acceptNext(); } catch { break; }
      if (incoming === null) break;
      (async () => {
        const accepting = await incoming.accept();
        const conn = await accepting.connect();
        const authBi = await conn.acceptBi();
        const sent = Buffer.from(await authBi.recv.readToEnd(HANDSHAKE_LIMIT));
        const ok = sent.length === connectSecret.length && crypto.timingSafeEqual(sent, connectSecret);
        try { await authBi.send.writeAll(Array.from(Buffer.from(ok ? 'OK' : 'NO'))); await authBi.send.finish(); } catch { /* hung up */ }
        if (!ok) { try { conn.close(1n, Array.from(Buffer.from('unauthorized'))); } catch { /* noop */ } return; }
        console.log('[server] client authenticated');
        for (;;) {
          let bi;
          try { bi = await conn.acceptBi(); } catch { break; }
          const socket = net.connect({ host: '127.0.0.1', port: stubPort });
          socket.once('connect', () => bridge(socket, bi));
        }
      })().catch(() => {});
    }
  })();

  const ticketStr = EndpointTicket.fromAddr(endpoint.addr()).toString();
  const code = 'mstr1:' +
      Buffer.from(JSON.stringify({ t: ticketStr, s: connectSecret.toString('base64') })).toString('base64url');
  console.log(`PAIRING_CODE=${code}`);
  console.log('[server] serving until killed');
}

main().catch((e) => { console.error(e); process.exit(1); });
