// FEDERATION_PLAN 8a: a failed track from a direct peer whose own tunnel is
// serving is not a bad source until the peer has said so. The decision is
// pure — the same rules for the Galaxy's "Source error" and the iPhone's
// "response code: 401" — and pinned here the way healAction is.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/audio_stuff.dart';

DirectAuthAction act({
  bool isDirect = true,
  bool tunnelServes = true,
  Duration? sinceLastRecovery,
  bool probed = false,
  int? probedStatus,
  Duration? retryAfter,
}) =>
    AudioPlayerHandler.directAuthAction(
      isDirect: isDirect,
      tunnelServes: tunnelServes,
      sinceLastRecovery: sinceLastRecovery,
      probed: probed,
      probedStatus: probedStatus,
      retryAfter: retryAfter,
    );

void main() {
  group('AudioPlayerHandler.directAuthAction', () {
    test('a direct peer with a serving tunnel is worth a probe', () {
      expect(act(), DirectAuthAction.probe);
    });

    // A peer on the proxy path failed on the parent's transport, and a
    // direct peer whose tunnel is down is the iroh recovery's case: neither
    // is a question the loopback can answer.
    test('not direct, or a tunnel that is not serving → walk', () {
      expect(act(isDirect: false), DirectAuthAction.walk);
      expect(act(tunnelServes: false), DirectAuthAction.walk);
      expect(act(isDirect: false, probed: true, probedStatus: 401),
          DirectAuthAction.walk);
    });

    // The probe is one ranged GET, so every failure gets one — a 429 inside
    // the gap is still the cap, and walking it blind cost three retries
    // into the cap and a skip (Galaxy, 2026-10-20). The gap gates the
    // RENEWAL: a token the parent renewed seconds ago cannot have lapsed,
    // so a 401 inside it is the walk's — not another round trip.
    test('inside the gap: still a probe; a 401 walks, a 429 backs off', () {
      const inside = Duration(seconds: 9);
      expect(act(sinceLastRecovery: inside), DirectAuthAction.probe);
      expect(act(sinceLastRecovery: inside, probed: true, probedStatus: 401),
          DirectAuthAction.walk);
      expect(act(sinceLastRecovery: inside, probed: true, probedStatus: 429),
          DirectAuthAction.backoff);
      expect(
          act(
              sinceLastRecovery: AudioPlayerHandler.kDirectAuthRecoveryGap,
              probed: true,
              probedStatus: 401),
          DirectAuthAction.refresh);
      expect(act(sinceLastRecovery: null), DirectAuthAction.probe);
    });

    test('the peer refusing the token → refresh', () {
      expect(act(probed: true, probedStatus: 401), DirectAuthAction.refresh);
      expect(act(probed: true, probedStatus: 403), DirectAuthAction.refresh);
    });

    test('the peer saying the file is gone → skip', () {
      expect(act(probed: true, probedStatus: 404), DirectAuthAction.skip);
      expect(act(probed: true, probedStatus: 410), DirectAuthAction.skip);
    });

    // The federation key's concurrent-stream cap, which a guest shares with
    // the parent: the streams a run of skips left open close on their own,
    // so the track is worth a short wait and a reload, not a skip (the Auto
    // DJ rig's rapid skips tripped it on the S25, 2026-09-19).
    test('the peer at its stream cap → back off and reload', () {
      expect(act(probed: true, probedStatus: 429), DirectAuthAction.backoff);
      expect(
          act(
              probed: true,
              probedStatus: 429,
              retryAfter: const Duration(seconds: 5)),
          DirectAuthAction.backoff);
      expect(
          act(
              probed: true,
              probedStatus: 429,
              retryAfter: AudioPlayerHandler.kDirectBusyMaxWait),
          DirectAuthAction.backoff);
      expect(AudioPlayerHandler.kDirectBusyAttempts, greaterThan(0));
      expect(AudioPlayerHandler.kDirectBusyBackoff,
          greaterThanOrEqualTo(const Duration(seconds: 1)));
    });

    // The peer's other 429: its daily transfer quota, with a Retry-After at
    // UTC midnight. Three 3 s waits and a walk, track after track, had
    // nothing to wait for.
    test('a 429 with a Retry-After past the busy wait → quota', () {
      expect(
          act(
              probed: true,
              probedStatus: 429,
              retryAfter: const Duration(hours: 13)),
          DirectAuthAction.quota);
      expect(
          act(
              probed: true,
              probedStatus: 429,
              retryAfter: AudioPlayerHandler.kDirectBusyMaxWait +
                  const Duration(seconds: 1)),
          DirectAuthAction.quota);
    });

    // A source that answers fine now was a blip; a 5xx or silence is the
    // walk's connectivity probe to judge.
    test('anything else the loopback says, or no answer → walk', () {
      for (final s in [200, 206, 500, 502, 503]) {
        expect(act(probed: true, probedStatus: s), DirectAuthAction.walk,
            reason: 'http $s is not the token');
      }
      expect(act(probed: true, probedStatus: null), DirectAuthAction.walk);
    });
  });

  group('AudioPlayerHandler.retryAfterOf', () {
    test('delay-seconds, as the peer sends it', () {
      expect(AudioPlayerHandler.retryAfterOf('5'), const Duration(seconds: 5));
      expect(AudioPlayerHandler.retryAfterOf(' 43200 '),
          const Duration(hours: 12));
      expect(AudioPlayerHandler.retryAfterOf('0'), Duration.zero);
    });

    test('absent, malformed or an HTTP-date → null', () {
      expect(AudioPlayerHandler.retryAfterOf(null), isNull);
      expect(AudioPlayerHandler.retryAfterOf(''), isNull);
      expect(AudioPlayerHandler.retryAfterOf('-1'), isNull);
      expect(AudioPlayerHandler.retryAfterOf('Wed, 21 Oct 2026 00:00:00 GMT'),
          isNull);
    });
  });
}
