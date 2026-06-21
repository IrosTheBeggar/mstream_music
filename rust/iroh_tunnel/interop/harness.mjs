// Interop proof for M1: the Rust tunnel client must speak mStream PR #643's
// protocol. We stand up the JS *server* side (faithfully replicating
// src/state/iroh.js: ALPN, secret handshake, bi-stream<->backend bridge), build
// the composite pairing code, then spawn the compiled Rust client and drive real
// HTTP (incl. a Range/seek request) through the tunnel.
//
// Run unsandboxed (iroh needs UDP + relay). Exits non-zero on any failed check.

import net from 'node:net';
import http from 'node:http';
import crypto from 'node:crypto';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { fileURLToPath } from 'node:url';
import { Endpoint, EndpointTicket } from '@number0/iroh';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TUNNEL_ALPN = Array.from(Buffer.from('mstream/tunnel/2'));
const READ_CHUNK = 64 * 1024;
const HANDSHAKE_LIMIT = 256;
const MEDIA = Buffer.alloc(4 * 1024 * 1024);
for (let i = 0; i < MEDIA.length; i++) MEDIA[i] = i & 0xff;

const delay = (ms) => new Promise((r) => setTimeout(r, ms));
let failures = 0;
const check = (name, ok, extra = '') => {
  console.log(`  ${ok ? 'PASS' : 'FAIL'}  ${name}${extra ? `  (${extra})` : ''}`);
  if (!ok) failures++;
};

// ---- byte pumps (copied from src/state/iroh.js) ----
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
  // 1) Stub backend: JSON for most paths, real Range support on /media.
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

  // 2) JS server endpoint (replicates src/state/iroh.js start()/accept/auth).
  const secretKey = crypto.randomBytes(32);
  const connectSecret = crypto.randomBytes(32);
  const endpoint = await Endpoint.bind({ alpns: [TUNNEL_ALPN], secretKey: Array.from(secretKey) });
  await Promise.race([endpoint.online().catch(() => {}), delay(8000)]);
  console.log(`[server] endpointId=${endpoint.id().toString()}`);

  const serverConns = []; // captured so the reconnect test can kill them
  (async () => {
    for (;;) {
      let incoming;
      try { incoming = await endpoint.acceptNext(); } catch { break; }
      if (incoming === null) break;
      (async () => {
        const accepting = await incoming.accept();
        const conn = await accepting.connect();
        serverConns.push(conn);
        const authBi = await conn.acceptBi();
        const sent = Buffer.from(await authBi.recv.readToEnd(HANDSHAKE_LIMIT));
        const ok = sent.length === connectSecret.length && crypto.timingSafeEqual(sent, connectSecret);
        try { await authBi.send.writeAll(Array.from(Buffer.from(ok ? 'OK' : 'NO'))); await authBi.send.finish(); } catch { /* hung up */ }
        if (!ok) { try { conn.close(1n, Array.from(Buffer.from('unauthorized'))); } catch { /* noop */ } return; }
        for (;;) {
          let bi;
          try { bi = await conn.acceptBi(); } catch { break; }
          const socket = net.connect({ host: '127.0.0.1', port: stubPort });
          socket.once('connect', () => bridge(socket, bi));
        }
      })().catch(() => {});
    }
  })();

  // 3) Pairing code = versioned envelope "mstr1:<base64url(JSON{ t, s })>".
  const ticketStr = EndpointTicket.fromAddr(endpoint.addr()).toString();
  const code = 'mstr1:' +
      Buffer.from(JSON.stringify({ t: ticketStr, s: connectSecret.toString('base64') })).toString('base64url');

  // 4) Spawn the compiled Rust client and read its chosen local port.
  const exe = path.join(__dirname, '..', 'target', 'debug', process.platform === 'win32' ? 'iroh-tunnel-client.exe' : 'iroh-tunnel-client');
  console.log(`[client] spawning ${path.basename(exe)} …`);
  const child = spawn(exe, [code], { stdio: ['ignore', 'pipe', 'pipe'] });
  child.stderr.on('data', (d) => process.stdout.write(`    [rust] ${d}`));

  const localPort = await new Promise((resolve, reject) => {
    let buf = '';
    const to = setTimeout(() => reject(new Error('client did not report LOCAL_PORT within 45s')), 45000);
    child.stdout.on('data', (d) => {
      buf += d.toString();
      const m = /LOCAL_PORT=(\d+)/.exec(buf);
      if (m) { clearTimeout(to); resolve(Number(m[1])); }
    });
    child.once('exit', (c) => { clearTimeout(to); reject(new Error(`client exited early (code ${c})`)); });
  });
  const base = `http://127.0.0.1:${localPort}`;
  console.log(`[client] tunnel entrance: ${base}`);

  // 5) Drive HTTP through the Rust tunnel.
  console.log('\n=== INTEROP TESTS (Rust client ⇆ JS server) ===');
  const r1 = await fetch(`${base}/probe?x=1`);
  const j1 = await r1.json();
  check('JSON request tunnels (200)', r1.status === 200, `status ${r1.status}`);
  check('request path preserved through tunnel', j1.path === '/probe?x=1', j1.path);

  const start = 1048576, end = 1049599;
  const r2 = await fetch(`${base}/media/test.bin`, { headers: { Range: `bytes=${start}-${end}` } });
  const body = Buffer.from(await r2.arrayBuffer());
  check('Range request → 206 (audio seek path)', r2.status === 206, `status ${r2.status}`);
  check('Content-Range forwarded', r2.headers.get('content-range') === `bytes ${start}-${end}/${MEDIA.length}`, r2.headers.get('content-range') ?? 'missing');
  check('partial length exact', body.length === end - start + 1, `${body.length} bytes`);
  let bytesOk = body.length === 1024;
  for (let k = 0; k < body.length && bytesOk; k++) if (body[k] !== (k & 0xff)) bytesOk = false;
  check('partial bytes correct (seek fidelity)', bytesOk);

  const conc = await Promise.all(Array.from({ length: 6 }, (_, i) => fetch(`${base}/c/${i}`).then((r) => r.status)));
  check('6 concurrent requests all 200 (multiplexing)', conc.every((s) => s === 200), conc.join(','));

  // 6) RECONNECT: kill the server-side connection(s); the client's supervisor
  //    should re-dial automatically — same loopback port, no re-pair.
  console.log('\n=== RECONNECT TEST ===');
  const connsBefore = serverConns.length;
  for (const c of serverConns) {
    try { c.close(0n, Array.from(Buffer.from('drop'))); } catch { /* noop */ }
  }
  let recovered = false;
  for (let i = 0; i < 20 && !recovered; i++) {
    await delay(1000);
    try {
      const r = await fetch(`${base}/probe/after-reconnect`, { signal: AbortSignal.timeout(2500) });
      if (r.status === 200) recovered = true;
    } catch { /* still reconnecting */ }
  }
  check('tunnel auto-reconnects after the connection drops', recovered,
      recovered ? 'recovered' : 'no recovery within 20s');
  check('server accepted a NEW connection (re-dial)', serverConns.length > connsBefore,
      `${connsBefore} -> ${serverConns.length}`);

  console.log(`\n=== RESULT: ${failures === 0 ? 'ALL PASS' : failures + ' FAILURE(S)'} ===`);

  child.kill();
  stub.close();
  try { await endpoint.close(); } catch { /* noop */ }
  await once(child, 'exit').catch(() => {});
  process.exit(failures === 0 ? 0 : 1);
}

const guard = setTimeout(() => { console.error('[harness] TIMEOUT 120s'); process.exit(2); }, 120000);
guard.unref();
main().catch((e) => { console.error('[harness] ERROR', e); process.exit(3); });
