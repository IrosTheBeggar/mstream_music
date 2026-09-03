// Pure decision logic for the iroh tunnel lifecycle — no I/O, no singletons —
// so the rules that keep Quick Connect alive on a flaky link are unit-tested
// instead of living in comments.
//
// Background (two drive logs, 2026-09-01): the Rust supervisor re-dials a
// dropped tunnel forever on the SAME loopback port and token, and playback
// resumes on its own when it reconnects. The Dart side used to probe the
// loopback on every network change WITHOUT reading the native status; during
// a reconnect the shim fails every loopback request within a second, so the
// probe always failed, and a failing probe meant stop the tunnel and start a
// fresh one with a single cold dial (8s relay wait + 25s connect). When that
// dial failed — likely, since service was still bad — nothing retried: every
// URL pointed at 127.0.0.1:0 until the user tapped something. These rules
// reserve the probe for the one case it was written for (commit 98d06c8: an
// iOS thaw leaves the native side REPORTING connected on a dead connection),
// leave a reconnecting tunnel to its supervisor, and guarantee that "no
// tunnel and nothing scheduled" is not a reachable state.
import 'dart:async';
import 'dart:io';

import '../native/iroh_tunnel.dart';

/// Timing constants, each chosen against an iroh 1.0 / noq constant.
class TunnelTiming {
  TunnelTiming._();

  /// Grace after the network_change nudge before the first probe: netwatch
  /// debounces 250ms, then iroh re-dials the relay and pings every path.
  /// Most hand-offs settle within ~3s.
  static const Duration probeFirstDelay = Duration(seconds: 3);

  /// The second probe, measured from the nudge. The relay actor's connect
  /// timeout is 10s, so two failures spanning it are not migration noise.
  static const Duration probeSecondAt = Duration(seconds: 10);

  /// Loopback TCP connect + request open: instant unless the listener is gone.
  static const Duration probeLoopbackTimeout = Duration(seconds: 2);

  /// One QUIC round trip through a relay on weak cellular (covers the Initial
  /// retransmits at ~1s and ~3s).
  static const Duration probeResponseTimeout = Duration(seconds: 6);

  /// A supervisor that has not converged in this long is escalated to a hard
  /// rebuild — only when the relay is known reachable, see
  /// [TunnelPolicy.shouldEscalate]; in a dead zone the supervisor's
  /// relay-back wake is the fastest path and must not be discarded.
  static const Duration reconnectingWatchdog = Duration(seconds: 120);

  /// The same watchdog when the binary cannot say whether the relay is up
  /// (no `relay_online` symbol yet). Long, because in a dead zone a fresh
  /// endpoint fails exactly like the supervisor and costs its relay-back
  /// wake — but not infinite, because a supervisor that never converges
  /// (a dead UDP socket after an iOS thaw) would otherwise spin forever with
  /// nothing else scheduled. The banner's Retry cuts it short.
  static const Duration reconnectingWatchdogBlind = Duration(minutes: 5);

  /// After an in-place kick (a native force-reconnect), how long to wait for
  /// CONNECTED before falling back to a fresh endpoint (iOS dead-socket case).
  static const Duration postKickWatchdog = Duration(seconds: 45);

  /// A hard rebuild rotates port + token: every stored URL goes stale, the
  /// player reloads, in-flight downloads die. At most one per minute unless
  /// the user asked.
  static const Duration hardRebuildMinGap = Duration(seconds: 60);

  /// A [none]→[x] connectivity edge inside this window is a modem re-attach;
  /// iroh's idle timeout + the supervisor handle those on their own.
  static const Duration recentlyOffline = Duration(seconds: 15);

  /// Retry schedule after a failed cold dial: fast for a blip, then at most one
  /// dial a minute, then [retryLongDelay] once it is clearly a long outage
  /// (each attempt holds the radio for up to ~43s).
  static const List<int> retryDelaySeconds = [5, 10, 20, 40, 60];
  static const Duration retryLongDelay = Duration(minutes: 5);
  static const int retryLongAfter = 10;

  /// A cold dial that was in flight when the network came back failed for
  /// reasons that are gone; the next one goes out almost at once (a small gap
  /// so a flapping transport does not stack dials).
  static const Duration retryAfterNetworkReturn = Duration(seconds: 2);

  /// Bound on a queue-end park waiting for the tunnel to come back.
  static const Duration parkMax = Duration(minutes: 30);

  /// How long a queue that stops referencing the iroh server keeps the tunnel
  /// before it is released. A restore, a clear-then-refill and the handler's
  /// initial empty queue all pass through "no iroh song queued" for a moment;
  /// releasing at once tore a fresh launch tunnel down mid-dial (Galaxy S25,
  /// 2026-09-02) and cost a full rebuild seconds later.
  static const Duration queueReleaseGrace = Duration(seconds: 10);

  /// How long after an audio-focus interruption began an auto rebuild must not
  /// resume playback. A window, not a flag: Android never delivers the `end`
  /// for a permanent loss (6 begins, 0 ends across the two drive logs).
  static const Duration interruptionWindow = Duration(seconds: 90);
}

/// What [handleNetworkChange] does after nudging iroh.
enum NetworkChangeRemedy {
  /// No tunnel (or a dial in flight): make sure one is coming up.
  ensureOnly,

  /// Native says connected; verify with the loopback probe (98d06c8 case).
  probe,

  /// Native says reconnecting: the supervisor owns it, do nothing.
  leaveToSupervisor,

  /// Stop the native tunnel and dial fresh (user asked, or watchdog).
  escalate,

  /// Pairing rejected: only a repair helps; do not re-dial on every event.
  leaveRejected,
}

/// What to do about a tunnel that reports connected but failed two probes.
enum DeadTunnelRemedy { kick, hardRebuild, wait }

class TunnelPolicy {
  TunnelPolicy._();

  /// Decide the remedy for a network change / app resume / Retry tap.
  ///
  /// [assigned]: a native tunnel is up for this server (code matches and a
  /// port is recorded). [starting]: a Dart-side dial is in flight.
  /// [rejected]: native status is rejected OR a cold dial answered "NO" (then
  /// no native tunnel exists to report it). [sinceOffline]: time since the
  /// last `[none]` connectivity event, null if never.
  static NetworkChangeRemedy onNetworkChange({
    required IrohTunnelStatus native,
    required bool assigned,
    required bool starting,
    required bool rejected,
    required Duration? sinceOffline,
    required bool userInitiated,
  }) {
    if (rejected) {
      // A user-initiated Retry may re-dial (the code may have been fixed on
      // the server side); anything automatic waits for a repair.
      return userInitiated
          ? NetworkChangeRemedy.ensureOnly
          : NetworkChangeRemedy.leaveRejected;
    }
    if (starting || !assigned) return NetworkChangeRemedy.ensureOnly;
    switch (native) {
      case IrohTunnelStatus.rejected:
        return NetworkChangeRemedy.leaveRejected;
      case IrohTunnelStatus.reconnecting:
      case IrohTunnelStatus.connecting:
        // The supervisor is already re-dialing on the same port. Only the
        // user may cut it short (the banner's Retry).
        return userInitiated
            ? NetworkChangeRemedy.escalate
            : NetworkChangeRemedy.leaveToSupervisor;
      case IrohTunnelStatus.connected:
        // A modem that just re-attached: the connection is either fine or
        // about to hit the idle timeout, after which the supervisor heals it
        // in place. Probing now would only race iroh's own re-homing.
        if (!userInitiated &&
            sinceOffline != null &&
            sinceOffline < TunnelTiming.recentlyOffline) {
          return NetworkChangeRemedy.leaveToSupervisor;
        }
        return NetworkChangeRemedy.probe;
      case IrohTunnelStatus.down:
        return NetworkChangeRemedy.ensureOnly;
    }
  }

  /// Two consecutive probes failed on a tunnel whose native status is
  /// connected. Prefer the in-place kick when the native side offers one
  /// (same port/token, no reload); fall back to a rate-limited hard rebuild.
  static DeadTunnelRemedy onProbeFailedTwice({
    required bool canKick,
    required Duration? sinceHardRebuild,
    required Duration? sinceKick,
    required bool userInitiated,
  }) {
    if (canKick &&
        (userInitiated ||
            sinceKick == null ||
            sinceKick >= TunnelTiming.postKickWatchdog)) {
      return DeadTunnelRemedy.kick;
    }
    if (userInitiated ||
        sinceHardRebuild == null ||
        sinceHardRebuild >= TunnelTiming.hardRebuildMinGap) {
      return DeadTunnelRemedy.hardRebuild;
    }
    return DeadTunnelRemedy.wait;
  }

  /// The banner's Retry on a tunnel whose supervisor is already re-dialing.
  /// A kick first — same port and token: the native side nudges iroh, re-binds
  /// the loopback listener and re-dials at once — because a fresh endpoint
  /// would cold-dial into the same dead zone (33s per attempt on cellular,
  /// Galaxy S25 round) and rotate every URL. A second tap inside the
  /// post-kick window means the kick did not take: the user gets the fresh
  /// endpoint.
  static DeadTunnelRemedy onUserEscalate({
    required bool canKick,
    required Duration? sinceKick,
  }) {
    if (canKick &&
        (sinceKick == null || sinceKick >= TunnelTiming.postKickWatchdog)) {
      return DeadTunnelRemedy.kick;
    }
    return DeadTunnelRemedy.hardRebuild;
  }

  /// A probe outcome that needs no second opinion: "refused" means the
  /// loopback listener is gone (iOS reaps it during a suspension while the
  /// QUIC connection under it survives), which no path migration produces.
  static bool probeIsDefinitive(String reason) => reason == 'refused';

  /// Status-poll watchdog: escalate a supervisor that is not converging.
  ///
  /// [relayReachable] is the native side's word on whether its home relay is
  /// up (null when the running binary cannot say). A reconnect that is failing
  /// WITH the relay reachable is the iOS dead-socket case and deserves a
  /// fresh endpoint after [TunnelTiming.reconnectingWatchdog]; one failing
  /// WITHOUT it is a dead zone, where a fresh endpoint would fail exactly the
  /// same way and cost the supervisor's relay-back wake, so never. Unknown
  /// gets the long [TunnelTiming.reconnectingWatchdogBlind] ceiling. After a
  /// kick, the post-kick watchdog applies unless the relay is known down.
  static bool shouldEscalate({
    required IrohTunnelStatus native,
    required Duration? notConnectedFor,
    required Duration? sinceKick,
    required bool? relayReachable,
  }) {
    if (native != IrohTunnelStatus.reconnecting &&
        native != IrohTunnelStatus.connecting) {
      return false;
    }
    if (sinceKick != null && sinceKick >= TunnelTiming.postKickWatchdog) {
      return relayReachable != false;
    }
    if (relayReachable == false) return false;
    final ceiling = relayReachable == true
        ? TunnelTiming.reconnectingWatchdog
        : TunnelTiming.reconnectingWatchdogBlind;
    return (notConnectedFor ?? Duration.zero) >= ceiling;
  }

  /// Whether the tunnel status strip belongs on screen. Browsing the iroh
  /// server: every state (it is the server on screen). Browsing another
  /// server while the tunnel serves queued playback in the background: only
  /// the actionable states — a rejected code (Repair) and a hard-down tunnel
  /// (Retry). "Connecting…" / "Reconnecting…" spinners over a standard server
  /// that is already usable read as that server being unreachable.
  static bool showTunnelBanner({
    required IrohTunnelStatus status,
    required bool browsingTunnelServer,
  }) {
    if (browsingTunnelServer) return true;
    return status == IrohTunnelStatus.rejected ||
        status == IrohTunnelStatus.down;
  }

  /// Delay before retry number [attempt] (0-based) after a failed cold dial.
  static Duration retryDelay(int attempt) {
    if (attempt >= TunnelTiming.retryLongAfter) {
      return TunnelTiming.retryLongDelay;
    }
    final i = attempt.clamp(0, TunnelTiming.retryDelaySeconds.length - 1);
    return Duration(seconds: TunnelTiming.retryDelaySeconds[i]);
  }

  /// After a failed cold dial: where the retry ladder continues. A dial that
  /// was already in flight when the network came back was doomed from its
  /// first packet (lost in the dead zone; QUIC's retransmit backoff does the
  /// rest — Galaxy S25: Wi-Fi back at :19, that dial still timed out at :25,
  /// the next one took 3s), so the ladder restarts with a near-immediate
  /// attempt instead of taking the next rung.
  static ({int attempt, Duration delay}) retryAfterFailedDial({
    required int attempt,
    required bool networkReturnedDuringDial,
  }) {
    if (networkReturnedDuringDial) {
      return (attempt: 0, delay: TunnelTiming.retryAfterNetworkReturn);
    }
    return (attempt: attempt, delay: retryDelay(attempt));
  }

  /// Whether an ensure should skip a cold dial because one failed recently and
  /// the retry timer owns the next attempt. Without this gate every caller
  /// that wants the tunnel (a DJ pick re-fired every ~30s by the player's
  /// index re-emissions, a browse, a download re-enqueue, a playback error)
  /// would queue its own 33–43s cold dial behind the last one, defeating the
  /// backoff. [bypassBackoff] is for the retry timer itself and for
  /// user-driven callers.
  static bool shouldSkipColdDial({
    required Duration? sinceFailedDial,
    required Duration nextRetry,
    required bool bypassBackoff,
  }) =>
      !bypassBackoff && sinceFailedDial != null && sinceFailedDial < nextRetry;

  /// Collapse a probe exception into the three cases that mean different
  /// things — the old probe swallowed them into one line.
  ///   timeout — the request went out and nothing came back: a QUIC zombie
  ///             (the 98d06c8 case) or a path mid-migration;
  ///   refused — the loopback listener is gone (the tunnel was stopped);
  ///   reset   — the shim accepted the socket and dropped it: open_bi failed,
  ///             i.e. the supervisor is RECONNECTING and will heal in place.
  static String classifyProbeError(Object e) {
    if (e is TimeoutException) return 'timeout';
    final m = e.toString().toLowerCase();
    if (m.contains('refused')) return 'refused';
    if (m.contains('reset') ||
        m.contains('before full header') ||
        m.contains('closed')) {
      return 'reset';
    }
    if (e is SocketException) return 'socket:${e.osError?.errorCode ?? '?'}';
    return 'error:${e.runtimeType}';
  }
}
