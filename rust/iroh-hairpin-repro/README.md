# iroh: a same-NAT dialer selects a hairpinned reflexive path that only works one way

Two hosts behind one home router. The server's `EndpointAddr` (and so its
ticket) carries its LAN address **and** the NAT-reflexive public addresses
iroh learned through the relays. A dialer on the same LAN selects a "direct"
path to one of the reflexive addresses: the router hairpins the first packet
back in with its own LAN address as the source, the server's handshake flight
makes it back through that NAT state, the dialer's `connect()` resolves and it
opens its first stream — and nothing it sends after that reaches the server.
The server's `Connecting` never completes; the dialer sits on the dead path for
as long as it waits, with a working relay path available the whole time.

Two binaries, only `iroh` + `iroh-tickets` + `tokio` as dependencies.

## Run

Host A (behind the NAT):

```bash
cargo run --release --bin server
# prints its relay, each direct address tagged LAN / NAT-reflexive, and TICKET=…
```

Host B, a **second machine behind the same NAT** (a laptop on the same Wi-Fi;
or an Android phone via `adb shell`, see below):

```bash
cargo run --release --bin client -- <ticket> 5            # the ticket as advertised
cargo run --release --bin client -- <ticket> 5 --lan-only # the same ticket without the reflexive addresses
```

Each attempt binds a fresh endpoint, dials, opens the first bi-stream, writes
5 bytes and waits 10 s for the server's `OK` — the shape of a first connection
between two peers.

Android as host B: `cargo ndk -t arm64-v8a --platform 26 build --release --bin client`,
then `adb push target/aarch64-linux-android/release/client /data/local/tmp/hairpin-client`
and `adb shell /data/local/tmp/hairpin-client <ticket> 5`.

## What we see (iroh 1.0.0 both sides; macOS server, Android arm64 client, one home router)

Server:

```
direct: 73.60.222.134:58294  [NAT-reflexive]
direct: 73.60.222.134:62054  [NAT-reflexive]
direct: 192.168.1.120:58294  [LAN]
[14:20:30.218] incoming from Ip(192.168.1.1:47257)          ← the ROUTER's LAN address
[14:21:00.222] STALL: handshake from Ip(192.168.1.1:47257) not complete after 30s
…
[14:21:33.027] incoming from Ip(192.168.1.204:40839)         ← the phone's own address
[14:21:33.035] connected in 0.01s … paths=direct*
[14:21:33.035] handshake OK in 0.01s (5 bytes from the client)
```

Client, the ticket as advertised — **4 of 5 attempts stalled**:

```
attempt 1: STALL — connected in 0.02s, no reply to the first stream in 10s; selected path=direct
attempt 2: STALL — connected in 0.13s, no reply to the first stream in 10s; selected path=direct
attempt 3: STALL — connected in 0.03s, no reply to the first stream in 10s; selected path=direct
attempt 4: STALL — connected in 0.01s, no reply to the first stream in 10s; selected path=direct
attempt 5: OK — connected in 0.01s, reply in 0.02s, selected path=direct
```

Client, `--lan-only` — **0 of 5 stalled** (four direct, one relay). Same-host
control from the server's machine: 0 of 3.

The two reflexive addresses have different mapped ports for the same local
port: this router hands out a mapping per destination. Whether it hairpins a
flow for one packet or for a few seconds does not matter to the point:

- a path whose only evidence is one hairpinned round trip is selected over a
  LAN candidate and over the relay, without the reverse direction ever being
  validated;
- once that path stops delivering, the connection stays on it instead of
  falling back to the relay, which is up and was used to learn the peer.

## Workaround we shipped

The server builds its tickets from an `EndpointAddr` holding only the direct
addresses present on its own interfaces (holepunching still discovers the
reflexive ones through the relay). That is what `--lan-only` simulates on the
dialing side. mStream#956 for the server-side change; the app-side trace that
found it is in `../iroh_tunnel`.
