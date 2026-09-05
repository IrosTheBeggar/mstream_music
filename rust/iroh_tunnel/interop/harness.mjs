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

  const { localPort, localToken } = await new Promise((resolve, reject) => {
    let buf = '';
    const to = setTimeout(() => reject(new Error('client did not report LOCAL_PORT/TOKEN within 45s')), 45000);
    child.stdout.on('data', (d) => {
      buf += d.toString();
      const mp = /LOCAL_PORT=(\d+)/.exec(buf);
      const mt = /LOCAL_TOKEN=([0-9a-f]+)/.exec(buf);
      if (mp && mt) { clearTimeout(to); resolve({ localPort: Number(mp[1]), localToken: mt[1] }); }
    });
    child.once('exit', (c) => { clearTimeout(to); reject(new Error(`client exited early (code ${c})`)); });
  });
  const base = `http://127.0.0.1:${localPort}`;
  // The shim authenticates the loopback hop: every request must carry __lt=<token>.
  const lurl = (p) => `${base}${p}${p.includes('?') ? '&' : '?'}__lt=${localToken}`;
  console.log(`[client] tunnel entrance: ${base}`);

  // 5) Drive HTTP through the Rust tunnel.
  console.log('\n=== INTEROP TESTS (Rust client ⇆ JS server) ===');
  const r1 = await fetch(lurl('/probe?x=1'));
  const j1 = await r1.json();
  check('JSON request tunnels (200)', r1.status === 200, `status ${r1.status}`);
  check('request path preserved through tunnel', j1.path.startsWith('/probe?x=1'), j1.path);

  // Loopback auth: a request WITHOUT the token must be dropped by the shim.
  let untokenedRejected = false;
  try {
    await fetch(`${base}/probe?x=1`, { signal: AbortSignal.timeout(4000) });
  } catch { untokenedRejected = true; }
  check('un-tokened local request is rejected', untokenedRejected,
      untokenedRejected ? 'dropped' : 'NOT rejected — open proxy!');

  const start = 1048576, end = 1049599;
  const r2 = await fetch(lurl('/media/test.bin'), { headers: { Range: `bytes=${start}-${end}` } });
  const body = Buffer.from(await r2.arrayBuffer());
  check('Range request → 206 (audio seek path)', r2.status === 206, `status ${r2.status}`);
  check('Content-Range forwarded', r2.headers.get('content-range') === `bytes ${start}-${end}/${MEDIA.length}`, r2.headers.get('content-range') ?? 'missing');
  check('partial length exact', body.length === end - start + 1, `${body.length} bytes`);
  let bytesOk = body.length === 1024;
  for (let k = 0; k < body.length && bytesOk; k++) if (body[k] !== (k & 0xff)) bytesOk = false;
  check('partial bytes correct (seek fidelity)', bytesOk);

  const conc = await Promise.all(Array.from({ length: 6 }, (_, i) => fetch(lurl(`/c/${i}`)).then((r) => r.status)));
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
      const r = await fetch(lurl('/probe/after-reconnect'), { signal: AbortSignal.timeout(2500) });
      if (r.status === 200) recovered = true;
    } catch { /* still reconnecting */ }
  }
  check('tunnel auto-reconnects after the connection drops', recovered,
      recovered ? 'recovered' : 'no recovery within 20s');
  check('server accepted a NEW connection (re-dial)', serverConns.length > connsBefore,
      `${connsBefore} -> ${serverConns.length}`);

  // 7) KICK: a second client instance forces an in-place reconnect after 2s.
  //    Same LOCAL_PORT must keep answering afterwards, the server must see
  //    exactly one more connection, and the events ring must narrate it.
  console.log('\n=== KICK TEST (in-place reconnect) ===');
  const connsBeforeKick = serverConns.length;
  const child2 = spawn(exe, [code, '--kick-after', '2', '--events'], { stdio: ['ignore', 'pipe', 'pipe'] });
  let events2 = '';
  child2.stderr.on('data', (d) => { events2 += d.toString(); process.stdout.write(`    [rust2] ${d}`); });
  const port2 = await new Promise((resolve, reject) => {
    let buf = '';
    const to = setTimeout(() => reject(new Error('client2 did not report LOCAL_PORT within 45s')), 45000);
    child2.stdout.on('data', (d) => {
      buf += d.toString();
      const mp = /LOCAL_PORT=(\d+)/.exec(buf);
      const mt = /LOCAL_TOKEN=([0-9a-f]+)/.exec(buf);
      if (mp && mt) { clearTimeout(to); resolve({ port: Number(mp[1]), token: mt[1] }); }
    });
    child2.once('exit', (c) => { clearTimeout(to); reject(new Error(`client2 exited early (code ${c})`)); });
  });
  const lurl2 = (p) => `http://127.0.0.1:${port2.port}${p}${p.includes('?') ? '&' : '?'}__lt=${port2.token}`;
  const before = await fetch(lurl2('/probe/before-kick'));
  check('client2 serves before the kick', before.status === 200, `status ${before.status}`);
  let kicked = false, reconnected = false;
  for (let i = 0; i < 20 && !reconnected; i++) {
    await delay(1000);
    kicked = kicked || /app kick/.test(events2);
    reconnected = /reconnected: attempt/.test(events2);
  }
  check('events ring narrates the kick', kicked, kicked ? 'app kick seen' : 'no "app kick" event');
  check('supervisor reconnected after the kick', reconnected, reconnected ? 'seen' : 'no "reconnected" event within 20s');
  let afterOk = false;
  for (let i = 0; i < 10 && !afterOk; i++) {
    try {
      const r = await fetch(lurl2('/probe/after-kick'), { signal: AbortSignal.timeout(2500) });
      afterOk = r.status === 200;
    } catch { /* not yet */ }
    if (!afterOk) await delay(1000);
  }
  check('same LOCAL_PORT answers after the kick', afterOk, afterOk ? `port ${port2.port} kept` : 'no answer');
  check('server accepted exactly one more connection for the kick', serverConns.length === connsBeforeKick + 2,
      `${connsBeforeKick} -> ${serverConns.length} (client2 first dial + re-dial)`);
  child2.kill();

  // 8) GUEST MODE: a federation endpoint (ALPN mstream/federation/1) whose
  //    first bi-stream carries a guest TOKEN, dialed from a `mstrfedg1:` guest
  //    ticket — then the credential is swapped IN PLACE: the server flips to
  //    accepting only token B and drops the connection, the supervisor's
  //    re-dial with A is rejected (status REJECTED, supervisor exits), and the
  //    client's timed swap to B must re-dial on the SAME port.
  console.log('\n=== GUEST TEST (federation ALPN + in-place credential swap) ===');
  const FED_ALPN = Array.from(Buffer.from('mstream/federation/1'));
  const fedEndpoint = await Endpoint.bind({ alpns: [FED_ALPN] });
  await Promise.race([fedEndpoint.online().catch(() => {}), delay(8000)]);
  let acceptedToken = 'guest-token-A';
  const fedConns = [];
  let fedRejections = 0;
  (async () => {
    for (;;) {
      let incoming;
      try { incoming = await fedEndpoint.acceptNext(); } catch { break; }
      if (incoming === null) break;
      (async () => {
        const accepting = await incoming.accept();
        const conn = await accepting.connect();
        const authBi = await conn.acceptBi();
        // The server reads up to 2 KB here (HANDSHAKE_LIMIT on the peer).
        const sent = Buffer.from(await authBi.recv.readToEnd(2048)).toString('utf8');
        const ok = sent === acceptedToken;
        try { await authBi.send.writeAll(Array.from(Buffer.from(ok ? 'OK' : 'NO'))); await authBi.send.finish(); } catch { /* hung up */ }
        if (!ok) { fedRejections++; try { conn.close(1n, Array.from(Buffer.from('unauthorized'))); } catch { /* noop */ } return; }
        fedConns.push(conn);
        for (;;) {
          let bi;
          try { bi = await conn.acceptBi(); } catch { break; }
          const socket = net.connect({ host: '127.0.0.1', port: stubPort });
          socket.once('connect', () => bridge(socket, bi));
        }
      })().catch(() => {});
    }
  })();
  const fedTicket = EndpointTicket.fromAddr(fedEndpoint.addr()).toString();
  const guestCode = (g) => 'mstrfedg1:' + Buffer.from(JSON.stringify({ t: fedTicket, g })).toString('base64url');

  // Rejected up front: a wrong token must fail the start with "rejected".
  const bad = spawn(exe, [guestCode('not-a-valid-token')], { stdio: ['ignore', 'pipe', 'pipe'] });
  let badErr = '';
  bad.stderr.on('data', (d) => { badErr += d.toString(); });
  const badExit = await new Promise((resolve) => bad.once('exit', resolve));
  check('a refused guest token fails the start with "rejected"', badExit !== 0 && /rejected/.test(badErr),
      `exit ${badExit}: ${badErr.trim().split('\n').pop()}`);

  const child3 = spawn(exe, [guestCode('guest-token-A'), '--events', '--swap-after', '6', guestCode('guest-token-B')],
      { stdio: ['ignore', 'pipe', 'pipe'] });
  let events3 = '';
  child3.stderr.on('data', (d) => { events3 += d.toString(); process.stdout.write(`    [rust3] ${d}`); });
  const port3 = await new Promise((resolve, reject) => {
    let buf = '';
    const to = setTimeout(() => reject(new Error('client3 did not report LOCAL_PORT within 45s')), 45000);
    child3.stdout.on('data', (d) => {
      buf += d.toString();
      const mp = /LOCAL_PORT=(\d+)/.exec(buf);
      const mt = /LOCAL_TOKEN=([0-9a-f]+)/.exec(buf);
      if (mp && mt) { clearTimeout(to); resolve({ port: Number(mp[1]), token: mt[1] }); }
    });
    child3.once('exit', (c) => { clearTimeout(to); reject(new Error(`client3 exited early (code ${c})`)); });
  });
  const lurl3 = (p) => `http://127.0.0.1:${port3.port}${p}${p.includes('?') ? '&' : '?'}__lt=${port3.token}`;
  const g1 = await fetch(lurl3('/guest/before'));
  check('guest ticket dials the federation ALPN and bridges HTTP', g1.status === 200, `status ${g1.status}`);
  check('events say mode=guest', /mode=guest/.test(events3));

  // Flip the server to token B and drop the pipe: the re-dial with A is refused.
  acceptedToken = 'guest-token-B';
  const rejectionsBefore = fedRejections;
  for (const c of fedConns.splice(0)) { try { c.close(0n, Array.from(Buffer.from('drop'))); } catch { /* noop */ } }
  let rejected = false;
  for (let i = 0; i < 15 && !rejected; i++) { await delay(1000); rejected = /handshake rejected/.test(events3); }
  check('a stale guest token is rejected on re-dial (supervisor gives up)', rejected,
      rejected ? `server refused ${fedRejections - rejectionsBefore}` : 'no rejection within 15s');

  // The timed swap (6s after start) hands the tunnel token B: a fresh
  // supervisor re-dials at once, on the SAME port.
  let swapped = false, back = false;
  for (let i = 0; i < 20 && !back; i++) {
    await delay(1000);
    swapped = swapped || /credential updated/.test(events3);
    back = /reconnected: attempt/.test(events3.slice(events3.indexOf('handshake rejected')));
  }
  check('credential swap after a rejected handshake respawns the supervisor', swapped && back,
      `${swapped ? 'swap seen' : 'no swap event'}, ${back ? 'reconnected' : 'no reconnect within 20s'}`);
  let g2ok = false;
  for (let i = 0; i < 10 && !g2ok; i++) {
    try { g2ok = (await fetch(lurl3('/guest/after-swap'), { signal: AbortSignal.timeout(2500) })).status === 200; } catch { /* not yet */ }
    if (!g2ok) await delay(1000);
  }
  check('same LOCAL_PORT serves with the new token', g2ok, g2ok ? `port ${port3.port} kept` : 'no answer');
  check('server accepted the swapped token (one new connection)', fedConns.length === 1, `${fedConns.length} live`);
  child3.kill();
  try { await fedEndpoint.close(); } catch { /* noop */ }

  console.log(`\n=== RESULT: ${failures === 0 ? 'ALL PASS' : failures + ' FAILURE(S)'} ===`);

  child.kill();
  stub.close();
  try { await endpoint.close(); } catch { /* noop */ }
  await once(child, 'exit').catch(() => {});
  process.exit(failures === 0 ? 0 : 1);
}

const guard = setTimeout(() => { console.error('[harness] TIMEOUT 180s'); process.exit(2); }, 180000);
guard.unref();
main().catch((e) => { console.error('[harness] ERROR', e); process.exit(3); });
