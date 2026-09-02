import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/native/iroh_tunnel.dart';
import 'package:mstream_music/singletons/tunnel_policy.dart';

NetworkChangeRemedy change({
  IrohTunnelStatus native = IrohTunnelStatus.connected,
  bool assigned = true,
  bool starting = false,
  bool rejected = false,
  Duration? sinceOffline,
  bool userInitiated = false,
}) =>
    TunnelPolicy.onNetworkChange(
      native: native,
      assigned: assigned,
      starting: starting,
      rejected: rejected,
      sinceOffline: sinceOffline,
      userInitiated: userInitiated,
    );

void main() {
  group('TunnelPolicy.onNetworkChange', () {
    // The regression this exists for: a reconnecting tunnel is the
    // supervisor's — probing it always fails (the shim RSTs every loopback
    // request on a closed QUIC connection), and acting on that failure killed
    // the one component that was about to heal the tunnel in place.
    test('reconnecting → leave it to the supervisor', () {
      expect(change(native: IrohTunnelStatus.reconnecting),
          NetworkChangeRemedy.leaveToSupervisor);
      expect(change(native: IrohTunnelStatus.connecting),
          NetworkChangeRemedy.leaveToSupervisor);
    });

    test('reconnecting + the user tapped Retry → escalate', () {
      expect(change(native: IrohTunnelStatus.reconnecting, userInitiated: true),
          NetworkChangeRemedy.escalate);
    });

    test('connected → probe (the iOS thaw case)', () {
      expect(change(), NetworkChangeRemedy.probe);
    });

    test('connected within 15s of a [none] → leave it (modem re-attach)', () {
      expect(change(sinceOffline: const Duration(seconds: 5)),
          NetworkChangeRemedy.leaveToSupervisor);
      expect(change(sinceOffline: const Duration(seconds: 15)),
          NetworkChangeRemedy.probe);
      // A user tap still probes.
      expect(
          change(sinceOffline: const Duration(seconds: 5), userInitiated: true),
          NetworkChangeRemedy.probe);
    });

    test('rejected → leave rejected unless the user asked', () {
      expect(change(native: IrohTunnelStatus.rejected),
          NetworkChangeRemedy.leaveRejected);
      expect(change(rejected: true, assigned: false),
          NetworkChangeRemedy.leaveRejected);
      expect(change(rejected: true, assigned: false, userInitiated: true),
          NetworkChangeRemedy.ensureOnly);
    });

    test('no tunnel / dial in flight / native down → ensure only', () {
      expect(change(assigned: false), NetworkChangeRemedy.ensureOnly);
      expect(change(starting: true), NetworkChangeRemedy.ensureOnly);
      expect(change(native: IrohTunnelStatus.down),
          NetworkChangeRemedy.ensureOnly);
    });
  });

  group('TunnelPolicy.onProbeFailedTwice', () {
    test('kick when the binary can and no kick is pending', () {
      expect(
          TunnelPolicy.onProbeFailedTwice(
              canKick: true,
              sinceHardRebuild: null,
              sinceKick: null,
              userInitiated: false),
          DeadTunnelRemedy.kick);
      expect(
          TunnelPolicy.onProbeFailedTwice(
              canKick: true,
              sinceHardRebuild: null,
              sinceKick: const Duration(seconds: 45),
              userInitiated: false),
          DeadTunnelRemedy.kick);
    });

    test('a kick 20s ago that did not take → rebuild if the gap allows', () {
      expect(
          TunnelPolicy.onProbeFailedTwice(
              canKick: true,
              sinceHardRebuild: null,
              sinceKick: const Duration(seconds: 20),
              userInitiated: false),
          DeadTunnelRemedy.hardRebuild);
      expect(
          TunnelPolicy.onProbeFailedTwice(
              canKick: true,
              sinceHardRebuild: const Duration(seconds: 30),
              sinceKick: const Duration(seconds: 20),
              userInitiated: false),
          DeadTunnelRemedy.wait);
    });

    test('no kick support → rate-limited hard rebuild', () {
      expect(
          TunnelPolicy.onProbeFailedTwice(
              canKick: false,
              sinceHardRebuild: null,
              sinceKick: null,
              userInitiated: false),
          DeadTunnelRemedy.hardRebuild);
      expect(
          TunnelPolicy.onProbeFailedTwice(
              canKick: false,
              sinceHardRebuild: const Duration(seconds: 59),
              sinceKick: null,
              userInitiated: false),
          DeadTunnelRemedy.wait);
      expect(
          TunnelPolicy.onProbeFailedTwice(
              canKick: false,
              sinceHardRebuild: const Duration(seconds: 60),
              sinceKick: null,
              userInitiated: false),
          DeadTunnelRemedy.hardRebuild);
    });

    test('the user bypasses every gap', () {
      expect(
          TunnelPolicy.onProbeFailedTwice(
              canKick: false,
              sinceHardRebuild: const Duration(seconds: 1),
              sinceKick: null,
              userInitiated: true),
          DeadTunnelRemedy.hardRebuild);
      expect(
          TunnelPolicy.onProbeFailedTwice(
              canKick: true,
              sinceHardRebuild: const Duration(seconds: 1),
              sinceKick: const Duration(seconds: 1),
              userInitiated: true),
          DeadTunnelRemedy.kick);
    });
  });

  group('TunnelPolicy.onUserEscalate', () {
    test('Retry on a reconnecting tunnel kicks in place first', () {
      expect(TunnelPolicy.onUserEscalate(canKick: true, sinceKick: null),
          DeadTunnelRemedy.kick);
      expect(
          TunnelPolicy.onUserEscalate(
              canKick: true, sinceKick: const Duration(seconds: 45)),
          DeadTunnelRemedy.kick);
    });

    test('a second tap inside the post-kick window → fresh endpoint', () {
      expect(
          TunnelPolicy.onUserEscalate(
              canKick: true, sinceKick: const Duration(seconds: 20)),
          DeadTunnelRemedy.hardRebuild);
    });

    test('no kick support → hard rebuild', () {
      expect(TunnelPolicy.onUserEscalate(canKick: false, sinceKick: null),
          DeadTunnelRemedy.hardRebuild);
    });
  });

  group('TunnelPolicy.probeIsDefinitive', () {
    test('only "refused" skips the second probe', () {
      expect(TunnelPolicy.probeIsDefinitive('refused'), isTrue);
      expect(TunnelPolicy.probeIsDefinitive('timeout'), isFalse);
      expect(TunnelPolicy.probeIsDefinitive('reset'), isFalse);
      expect(TunnelPolicy.probeIsDefinitive('http 500'), isFalse);
    });
  });

  group('TunnelPolicy.retryAfterFailedDial', () {
    test('a dial the network returned under restarts the ladder at 2s', () {
      final r = TunnelPolicy.retryAfterFailedDial(
          attempt: 3, networkReturnedDuringDial: true);
      expect(r.attempt, 0);
      expect(r.delay, TunnelTiming.retryAfterNetworkReturn);
      expect(r.delay, const Duration(seconds: 2));
    });

    test('otherwise the ladder continues from the same rung', () {
      final r = TunnelPolicy.retryAfterFailedDial(
          attempt: 2, networkReturnedDuringDial: false);
      expect(r.attempt, 2);
      expect(r.delay, const Duration(seconds: 20));
    });
  });

  group('TunnelPolicy.shouldEscalate', () {
    bool esc({
      IrohTunnelStatus native = IrohTunnelStatus.reconnecting,
      Duration? notConnectedFor,
      Duration? sinceKick,
      bool? relayReachable,
    }) =>
        TunnelPolicy.shouldEscalate(
            native: native,
            notConnectedFor: notConnectedFor,
            sinceKick: sinceKick,
            relayReachable: relayReachable);

    test('only a reconnecting/connecting tunnel can be escalated', () {
      for (final st in [
        IrohTunnelStatus.connected,
        IrohTunnelStatus.down,
        IrohTunnelStatus.rejected,
      ]) {
        expect(
            esc(
                native: st,
                notConnectedFor: const Duration(minutes: 10),
                relayReachable: true),
            isFalse,
            reason: '$st');
      }
    });

    // A dead zone (relay unreachable) is the supervisor's to ride out; a fresh
    // endpoint would fail the same way and lose the relay-back wake.
    test('never while the relay is known unreachable', () {
      expect(
          esc(notConnectedFor: const Duration(minutes: 10), relayReachable: false),
          isFalse);
    });

    // A binary that cannot say (no relay_online symbol yet) gets a long
    // ceiling: a supervisor that never converges must still have an exit.
    test('relay state unknown: 5-minute ceiling', () {
      expect(
          esc(
              notConnectedFor: const Duration(minutes: 4, seconds: 59),
              relayReachable: null),
          isFalse);
      expect(
          esc(notConnectedFor: const Duration(minutes: 5), relayReachable: null),
          isTrue);
    });

    test('relay reachable: 119s → no, 120s → yes', () {
      expect(
          esc(notConnectedFor: const Duration(seconds: 119), relayReachable: true),
          isFalse);
      expect(
          esc(notConnectedFor: const Duration(seconds: 120), relayReachable: true),
          isTrue);
    });

    test('a kick that did not take within 45s → escalate unless relay is down',
        () {
      expect(esc(sinceKick: const Duration(seconds: 45), relayReachable: null),
          isTrue);
      expect(esc(sinceKick: const Duration(seconds: 45), relayReachable: false),
          isFalse);
      expect(esc(sinceKick: const Duration(seconds: 44), relayReachable: null),
          isFalse);
    });
  });

  group('TunnelPolicy.retryDelay', () {
    test('5, 10, 20, 40, 60 … then 5 minutes after ten attempts', () {
      expect(
          [for (var i = 0; i < 12; i++) TunnelPolicy.retryDelay(i).inSeconds],
          [5, 10, 20, 40, 60, 60, 60, 60, 60, 60, 300, 300]);
    });
  });

  group('TunnelPolicy.shouldSkipColdDial', () {
    test('a non-user caller waits for the timer', () {
      expect(
          TunnelPolicy.shouldSkipColdDial(
              sinceFailedDial: const Duration(seconds: 3),
              nextRetry: const Duration(seconds: 5),
              bypassBackoff: false),
          isTrue);
      expect(
          TunnelPolicy.shouldSkipColdDial(
              sinceFailedDial: const Duration(seconds: 5),
              nextRetry: const Duration(seconds: 5),
              bypassBackoff: false),
          isFalse);
    });

    test('no failure on record, or a bypass → dial', () {
      expect(
          TunnelPolicy.shouldSkipColdDial(
              sinceFailedDial: null,
              nextRetry: const Duration(seconds: 5),
              bypassBackoff: false),
          isFalse);
      expect(
          TunnelPolicy.shouldSkipColdDial(
              sinceFailedDial: const Duration(seconds: 1),
              nextRetry: const Duration(seconds: 60),
              bypassBackoff: true),
          isFalse);
    });
  });

  group('TunnelPolicy.classifyProbeError', () {
    test('timeout / refused / reset are told apart', () {
      expect(TunnelPolicy.classifyProbeError(TimeoutException('x')), 'timeout');
      expect(
          TunnelPolicy.classifyProbeError(const SocketException(
              'Connection refused',
              osError: OSError('Connection refused', 111))),
          'refused');
      expect(
          TunnelPolicy.classifyProbeError(
              const SocketException('Connection reset by peer')),
          'reset');
      expect(
          TunnelPolicy.classifyProbeError(const HttpException(
              'Connection closed before full header was received')),
          'reset');
    });
  });
}
