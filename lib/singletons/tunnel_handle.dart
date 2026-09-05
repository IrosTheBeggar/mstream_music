// One native tunnel's bookkeeping, per TRANSPORT server — a Quick Connect
// server today, a directly-reached federated peer next. ServerManager keeps
// one handle for every server that needs a tunnel and runs the same
// lifecycle on each (dial, supervise, probe, kick, rebuild, retry), so a
// second tunnel is a second entry in its table, not a second copy of the
// lifecycle. No I/O here: the rules are in tunnel_policy.dart and the native
// calls in server_list.dart, which keeps this state readable in one place and
// unit-testable.
import 'dart:async';

import '../native/iroh_tunnel.dart';
import '../objects/server.dart';

/// A status edge on one tunnel, tagged with the transport it belongs to.
typedef TunnelTransition = ({
  Server server,
  IrohTunnelStatus from,
  IrohTunnelStatus to,
});

class TunnelHandle {
  TunnelHandle(this.server);

  /// The transport server this tunnel carries (never a federated peer riding
  /// its parent — the parent is the handle).
  final Server server;

  /// The id the native table holds a server's tunnel under. A Quick Connect
  /// server's pairing code IS its identity — the add-server test dials under
  /// it and registerActiveTunnel adopts that tunnel — while a federated
  /// peer's credential rotates daily, so it keys by localname. Recorded on
  /// the handle at start ([nativeKey]) rather than recomputed: a re-pair
  /// swaps the server's code before the old tunnel is stopped.
  static String keyFor(Server transport) =>
      transport.isIroh && transport.irohPairingCode != null
          ? transport.irohPairingCode!
          : transport.localname;

  /// The key the running native tunnel was started under; null when none.
  String? nativeKey;

  /// The credential the running tunnel was started with, and its loopback
  /// port + token. Mirrored onto [Server.tunnelPort] / [Server.tunnelToken],
  /// which the URL builders read.
  String? code;
  int? port;
  String? token;

  /// A dial is in flight (the native side reports nothing until it returns).
  bool starting = false;

  /// A cold dial answered "NO": surface Repair (not Retry) and stop
  /// re-dialing on every network event — no native tunnel exists to report
  /// `rejected`.
  bool startRejected = false;

  // ── Reconnect bookkeeping (the rules live in tunnel_policy.dart) ──
  /// When the reported status last left `connected` (null while connected).
  DateTime? notConnectedSince;

  /// Last in-place kick (native force-reconnect; null when never).
  DateTime? kickedAt;

  /// Last hard rebuild (stop + fresh dial) from ANY caller — rate-limited,
  /// since it rotates the loopback port and token.
  DateTime? lastHardRebuildAt;

  /// Last failed cold dial; gates every non-user ensure behind the retry timer.
  DateTime? lastFailedDialAt;
  DateTime? lastSkipLogAt;

  /// The retry loop that makes "no tunnel and nothing scheduled" unreachable
  /// while this server is a target.
  Timer? retryTimer;
  int retryAttempt = 0;

  /// A connectivity event landed while a cold dial was in flight: that dial
  /// was doomed from its first packet, so its failure restarts the ladder fast.
  bool networkReturnedDuringDial = false;

  /// Ensures queued on [chain] but not finished (awaitTunnelReady extends
  /// its deadline while one is pending, not just while a dial is in flight).
  int pendingEnsures = 0;

  /// A ground-truth probe is running (reverifyTunnel).
  bool reverifying = false;

  /// Serializes this tunnel's native mutations — start, stop, kick, code swap
  /// — so a resume, a connectivity burst and a server switch cannot race
  /// them. Per handle on purpose: one server's cold dial must not hold
  /// another's.
  Future<void> chain = Future.value();

  /// Last status / path the poll reported, for transition logging.
  IrohTunnelStatus lastStatus = IrohTunnelStatus.down;
  IrohPathKind lastPath = IrohPathKind.unknown;

  /// A native tunnel was started (or adopted) for this server.
  bool get assigned => nativeKey != null && code != null && port != null;

  /// Whether this is still the tunnel a probe was taken against — the
  /// re-check every probe consequence runs inside the chain before acting.
  bool sameTunnel(String? c, int? p) =>
      c != null && code == c && port == p && server.irohPairingCode == c;

  /// Record a started (or adopted) tunnel.
  void bind(
      {required String key,
      required String credential,
      required int localPort,
      required String? localToken}) {
    nativeKey = key;
    code = credential;
    port = localPort;
    token = localToken;
    server.tunnelPort = localPort;
    server.tunnelToken = localToken;
  }

  /// Forget the tunnel (after a stop, or a failed dial).
  void clearRuntime() {
    nativeKey = null;
    code = null;
    port = null;
    token = null;
    server.tunnelPort = null;
    server.tunnelToken = null;
  }

  void cancelRetry() {
    retryTimer?.cancel();
    retryTimer = null;
    retryAttempt = 0;
  }
}

/// How much a state matters to the person looking at the status strip.
int statusSeverity(IrohTunnelStatus s) => switch (s) {
      IrohTunnelStatus.connected => 0,
      IrohTunnelStatus.connecting => 1,
      IrohTunnelStatus.reconnecting => 2,
      IrohTunnelStatus.down => 3,
      IrohTunnelStatus.rejected => 4,
    };

/// The tunnel the status strip and the repair sheet talk about: the browsed
/// server's transport when that is a tunnel — every state matters there, it
/// is the server on screen — else, among the tunnels serving queued playback
/// in the background, the one in the worst state (TunnelPolicy.showTunnelBanner
/// then decides whether that state is worth a strip at all). Null when no
/// tunnel has a server to serve. Pure; unit-tested.
Server? bannerTargetAmong(
    {required Server? browsed,
    required List<({Server server, IrohTunnelStatus status})> background}) {
  if (browsed != null && browsed.isIroh) return browsed;
  Server? worst;
  var worstRank = -1;
  for (final b in background) {
    final rank = statusSeverity(b.status);
    if (rank > worstRank) {
      worst = b.server;
      worstRank = rank;
    }
  }
  return worst;
}
