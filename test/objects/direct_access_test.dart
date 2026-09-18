import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/direct_access.dart';
import 'package:mstream_music/singletons/tunnel_policy.dart';

void main() {
  group('DirectAccess.fromJson', () {
    final ok = {
      'direct': true,
      'endpointTicket': 'endpointabc',
      'endpointId': 'ca24f6e9',
      'guestToken': 'eyJhbGciOiJIUzI1NiJ9.eyJmZWRlcmF0aW9uR3Vlc3QiOnRydWV9.sig',
      'expiresAt': '2026-09-05T20:00:00.000Z',
      'directTicket': 'mstrfedg1:eyJ0IjoiZW5kcG9pbnRhYmMiLCJnIjoiZXlKIn0',
    };

    test('parses the parent\'s access answer', () {
      final a = DirectAccess.fromJson(ok)!;
      expect(a.endpointTicket, 'endpointabc');
      expect(a.endpointId, 'ca24f6e9');
      expect(a.guestToken, startsWith('eyJ'));
      expect(a.ticket, startsWith('mstrfedg1:'));
      expect(a.expiresAt, DateTime.utc(2026, 9, 5, 20));
    });

    test('a refusal is null, not an error', () {
      expect(DirectAccess.fromJson({'direct': false, 'reason': 'older build'}), isNull);
      expect(DirectAccess.fromJson({}), isNull);
    });

    test('a null endpoint id is allowed (no native module on the parent)', () {
      expect(DirectAccess.fromJson({...ok, 'endpointId': null})!.endpointId, isNull);
    });

    test('a malformed 200 throws, so it is retried rather than remembered', () {
      for (final broken in [
        {...ok}..remove('guestToken'),
        {...ok, 'directTicket': 'mstrfed1:not-a-guest-ticket'},
        {...ok, 'expiresAt': 'soon'},
        {...ok, 'endpointTicket': ''},
      ]) {
        expect(() => DirectAccess.fromJson(broken), throwsFormatException);
      }
    });
  });

  group('TunnelPolicy.directTicketStale', () {
    final fetched = DateTime.utc(2026, 9, 5, 0);
    final expires = DateTime.utc(2026, 9, 6, 0); // a day

    test('fresh for the first three quarters of its life, stale after', () {
      expect(
          TunnelPolicy.directTicketStale(
              fetchedAt: fetched, expiresAt: expires, now: fetched.add(const Duration(hours: 17))),
          isFalse);
      expect(
          TunnelPolicy.directTicketStale(
              fetchedAt: fetched, expiresAt: expires, now: fetched.add(const Duration(hours: 18))),
          isTrue);
      expect(
          TunnelPolicy.directTicketStale(
              fetchedAt: fetched, expiresAt: expires, now: expires.add(const Duration(hours: 1))),
          isTrue);
    });

    test('nothing fetched, or a life that already ended, is stale', () {
      expect(TunnelPolicy.directTicketStale(fetchedAt: null, expiresAt: null, now: fetched), isTrue);
      expect(TunnelPolicy.directTicketStale(fetchedAt: fetched, expiresAt: fetched, now: fetched), isTrue);
    });
  });

  // FEDERATION_PLAN 8a: the 401 path's gap only counts after an attempt
  // that worked. Galaxy S25, 2026-09-18: the poll's failed try 55 s earlier
  // blocked the renewal the lapsed token needed.
  group('TunnelPolicy.directAuthRefreshDue', () {
    test('inside the gap after a successful attempt → wait', () {
      expect(
          TunnelPolicy.directAuthRefreshDue(
              sinceLastAttempt: const Duration(seconds: 55),
              lastAttemptFailed: false),
          isFalse);
      expect(
          TunnelPolicy.directAuthRefreshDue(
              sinceLastAttempt: TunnelTiming.directRefusedRetryGap,
              lastAttemptFailed: false),
          isTrue);
    });

    test('after a failed attempt, or none, → ask now', () {
      expect(
          TunnelPolicy.directAuthRefreshDue(
              sinceLastAttempt: const Duration(seconds: 5),
              lastAttemptFailed: true),
          isTrue);
      expect(
          TunnelPolicy.directAuthRefreshDue(
              sinceLastAttempt: null, lastAttemptFailed: false),
          isTrue);
    });
  });

  // FEDERATION_PLAN 8b: a `direct: false` used to hold until the app
  // restarted — on a phone, days after the peer was upgraded to a build
  // that mints. It ages out instead.
  group('TunnelPolicy.directDenialExpired', () {
    final denied = DateTime.utc(2026, 9, 18, 12);

    test('never denied → ask', () {
      expect(TunnelPolicy.directDenialExpired(deniedAt: null, now: denied), isTrue);
    });

    test('holds inside the retry gap, expires at it', () {
      expect(
          TunnelPolicy.directDenialExpired(deniedAt: denied, now: denied),
          isFalse);
      expect(
          TunnelPolicy.directDenialExpired(
              deniedAt: denied, now: denied.add(const Duration(minutes: 59))),
          isFalse);
      expect(
          TunnelPolicy.directDenialExpired(
              deniedAt: denied, now: denied.add(TunnelTiming.directDeniedRetry)),
          isTrue);
      expect(
          TunnelPolicy.directDenialExpired(
              deniedAt: denied, now: denied.add(const Duration(days: 2))),
          isTrue);
    });
  });
}
