// The native per-host TLS bypass, end-to-end (PR #119) — ANDROID ONLY,
// and meaningful only on the FULL flavor (run with `--flavor full`): the
// InsecureTls bridge is absent from the play source set by design.
//
// just_audio's ExoPlayer streams through the platform HttpsURLConnection
// stack, so a Dart-side badCertificateCallback can't cover it — the fix
// under test installs a DELEGATING trust manager scoped to the hosts the
// user opted into. These two phases pin both halves of that contract
// against a real TLS handshake with a self-signed in-process server:
//
//   1. Host opted in  → ExoPlayer streams and playback reaches ready and
//      advances (the bypass works, per host).
//   2. Host NOT opted in (set emptied → platform defaults restored) →
//      the handshake fails and playback never reaches ready (validation
//      is back; the old blanket trust-all would have kept playing).
//
// The server host is the IP literal 127.0.0.1 on purpose: LAN self-signed
// servers are typically configured by IP, and the Kotlin resolves the peer
// host from the connection (no SNI for IP literals) — this proves that
// path works.

import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/media.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/util/stream_url.dart';

import 'helpers/test_helpers.dart';

// Self-signed 2048-bit RSA cert, CN=127.0.0.1, SAN IP:127.0.0.1 +
// DNS:localhost, valid to 2036. Generated with openssl for this test only —
// the platform trust store must reject it (that IS phase 2's assertion).
const String _certPem = '''
-----BEGIN CERTIFICATE-----
MIICyTCCAbGgAwIBAgIJALxEOWbYx7/iMA0GCSqGSIb3DQEBCwUAMBQxEjAQBgNV
BAMMCTEyNy4wLjAuMTAeFw0yNjA5MDExMjA5MjFaFw0zNjA4MjkxMjA5MjFaMBQx
EjAQBgNVBAMMCTEyNy4wLjAuMTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoC
ggEBAJze9qIjWZwgrGemh5eGeoBPC9V/qu0yY3YWUDFUsmW3I6yj/KUm07xudzMu
zorFzes7/gtXJjHzMWLqzTMJH94/9MmLLZEWpetXcd/eGEZgMLqriRkdLEz0ANmD
igx21Gq7O+gQVgeZynlta2BW+lstP6yzjPhv8fa9RURo9HDbRQTzvk6QUjF3r6Bj
DKuNEi1Dy3HvVrS4AzDsVs/TNZ0G7j03RwV6msy1UT5zNvgxG9aIrEPhdUKldt9o
MBGT4uJBGiUtKqs4oh3vUq8euX2oX5SwxZIsUIgU39oUrLwtM4x4ha0QXvg9kaY8
/cMt5p/YQ5EjnEFpjC5Can/eZTECAwEAAaMeMBwwGgYDVR0RBBMwEYcEfwAAAYIJ
bG9jYWxob3N0MA0GCSqGSIb3DQEBCwUAA4IBAQB0v+XqjKnBWpnOYImYRHmOE50k
BM3TtJBa0kNQulPFmvIZlrRxNvGNYlB2k3epdz9bYmm6Kzb6KRnmbu7k+izXOBwU
ll16Bcw2lNcWCQiRL1Jg1vWE69xxZq45+bHbJVNSSnmiu6/xfy5Iesii60G8OBva
DvfJIxQGLhg30oTJaJ9+p372d0AAjuoTvwS4kw+6uHXqsXycjSaopIUj1lVAXcp/
jn1JfHjtt8ZLSqLSv5uU91x2foboGx5l3hi1//Vj2yFg1s37yzxFAduP3SGrRM5P
RsRzNDcW5QCvsaBw9pgBsG3WaKF6va0THFMT4yKfqjU6mOoL4nOOHZMdjXZp
-----END CERTIFICATE-----
''';

const String _keyPem = '''
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCc3vaiI1mcIKxn
poeXhnqATwvVf6rtMmN2FlAxVLJltyOso/ylJtO8bnczLs6Kxc3rO/4LVyYx8zFi
6s0zCR/eP/TJiy2RFqXrV3Hf3hhGYDC6q4kZHSxM9ADZg4oMdtRquzvoEFYHmcp5
bWtgVvpbLT+ss4z4b/H2vUVEaPRw20UE875OkFIxd6+gYwyrjRItQ8tx71a0uAMw
7FbP0zWdBu49N0cFeprMtVE+czb4MRvWiKxD4XVCpXbfaDARk+LiQRolLSqrOKId
71KvHrl9qF+UsMWSLFCIFN/aFKy8LTOMeIWtEF74PZGmPP3DLeaf2EORI5xBaYwu
Qmp/3mUxAgMBAAECggEAb1vL4v+LLkz3dkD+Qi+BqLH0aaPOd8FsX7ipRsukNJaU
aYqj3603Y61bSucwUcznR9T3m59LCuxjo5+g+VjB2ai3IZd+Sl+0euNBgDUOMG86
SFla4owWFa6lJ8O77OsyEW5GsY9fMtgWpqppLiOwZ6cwa22uZfI55vknQc/rrmyt
BqyWWjCY4KQYqYV3qzlimskGrzTHSymIzjpJK86NA1VGpyX/b7/6DdonlKIWj+Tm
2Jin8CDLLQCrS/c37v7ORW/O7aQ/tKpBgBvm+Udl3fj8gy6BF6PdB3ykgeA88UDC
2Q7xiH0cV6QwSdk1svSoyomn9k1fjj3mlsPHewHHTQKBgQDIsjB3UfgC0TVk8VGP
ALazbsqaGgoxjDZRyS6jYlWUAY02OZLQ5LylYMCmMgvnpTSfXuwTe8daFeQbtNHq
MRxhdyS96YCutn4f2b3uxvGDCnPQgU/QmluNPuj2KUBQFQLYu0BkCH+ERZPgXfhb
ze78NDoMjuJlWLDROwBfQF2b9wKBgQDIGTI3Vp/JrTxY4gAL4phxtIsL2NNDp34I
rbv58v9oKQYvZcG12DLA6/wfMxxtvMiD2sRLpvHH8Vrg56ZeaA8lb0gHAACDaZxT
bP+XPX5EGDVuX1v7Ir3vQAcmT4WhhYHhIe7v9mXUeGMHHjVkjY6pXIWTpW8iilUB
sE4e9EkuFwKBgBQ8Y0akrS0bixayfla8668L7MG8/mogiRmV/23Z7GcQAP0GsRb+
+UZzivk28pxYvAWVvJf6Uw9yRZ3FjaTfbs0lBj9f2+nB3NW5Tr1UseVUmHjdkP6n
kbOcNEEdx65LcA4KU2PCt5jOqypkTzZyfTZQzcmWXp15Y9q06ESyaL3hAoGBAMb0
3oxNckVqHYXW+OrYXHE6bcLSzYUIZfWlITHunmtn1wGLsObpV9WhDqfK/ypRuiH4
hJMgJGmEnrLfQfm+h8jV9A0ZwGjpuojs6NntR73XQFFFOcTkD2xzAmjiSuGGSNSc
E+K+4RM4vGYYcEhRxBa7qwlaRb1XRByQu6xlgtnzAoGBAI7XsnOj24IAJB19W0/n
NHfH2hcg0qocvBckqRAbgvhiYSlbEbpunyS99BCUK20ZyJ1YrCKiGFP1qMK3WJfu
ItNS+jfzkf9OLVhEwJqEwk8vLPTRkKklV8kg2q80teiURPCkIfZxSAwUU4nCzz3l
Bz2V8ENlMhrWkMCNlcPYnQBR
-----END PRIVATE KEY-----
''';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await MediaManager().start();
  });

  testWidgets('native TLS bypass is scoped to opted-in hosts',
      (WidgetTester tester) async {
    if (!Platform.isAndroid) {
      markTestSkipped('native InsecureTls bridge is Android-only');
      return;
    }
    await resetAppState();

    final ctx = SecurityContext()
      ..useCertificateChainBytes(utf8.encode(_certPem))
      ..usePrivateKeyBytes(utf8.encode(_keyPem));
    final mock = await MockServer.start(
      const {},
      // Every non-API path is a stream URL — serve a wav long enough that
      // playback can't complete mid-assertion.
      defaultHandler: (_) => buildSilentWav(seconds: 60),
      securityContext: ctx,
    );
    addTearDown(mock.close);

    final handler = MediaManager().audioHandler;
    final srv = Server(mock.url, null, null, null, 'tls-test-server')
      ..allowSelfSigned = true;
    ServerManager().serverList.add(srv);
    addTearDown(() async {
      ServerManager().serverList.remove(srv);
      ServerManager().syncInsecureTls();
      await handler.customAction('clearPlaylist');
    });

    Future<void> queueAndPlay() async {
      await handler.customAction('clearPlaylist');
      await handler.addQueueItem(MediaItem(
        id: buildServerStreamUrl(srv, '/demo/tone.wav'),
        title: 'TLS probe',
        extras: {'server': srv.localname, 'path': '/demo/tone.wav'},
      ));
      await handler.play();
    }

    bool readyAndPlaying() {
      final s = handler.playbackState.value;
      return s.playing &&
          s.processingState == AudioProcessingState.ready &&
          s.position > const Duration(milliseconds: 300);
    }

    // ── Phase 1: host opted in → the stream plays over the bypass. ──
    ServerManager().syncInsecureTls();
    await queueAndPlay();
    final okDeadline = DateTime.now().add(const Duration(seconds: 25));
    while (!readyAndPlaying()) {
      if (DateTime.now().isAfter(okDeadline)) {
        fail('opted-in self-signed host never reached playing/ready — the '
            'per-host bypass is not letting ExoPlayer stream');
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    // ── Phase 2: opt-out → platform validation is back and blocks it. ──
    await handler.customAction('clearPlaylist');
    srv.allowSelfSigned = false;
    ServerManager().syncInsecureTls();
    // Let the channel round-trip land before the next handshake.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await queueAndPlay();
    final failWindow = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(failWindow)) {
      expect(readyAndPlaying(), isFalse,
          reason: 'with the host no longer opted in, the self-signed '
              'handshake must fail — reaching ready means validation is '
              'still bypassed (the old process-wide trust-all behavior)');
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  });
}
