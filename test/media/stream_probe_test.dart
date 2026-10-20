// The loopback probe behind FEDERATION_PLAN 8a: one ranged GET, the status
// (and a 429's Retry-After) back, nothing else. Against a real socket, since
// the point is what the peer's HTTP layer says.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/audio_stuff.dart';

void main() {
  group('AudioPlayerHandler.probeStreamStatus', () {
    late HttpServer server;
    final ranges = <String?>[];

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) {
        ranges.add(req.headers.value(HttpHeaders.rangeHeader));
        final status = int.tryParse(req.uri.path.substring(1)) ?? 200;
        req.response.statusCode = status;
        if (status == 429) {
          req.response.headers.set(HttpHeaders.retryAfterHeader, '5');
        }
        if (status == 206) {
          req.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes 0-0/9');
          req.response.add([0]);
        }
        req.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
      ranges.clear();
    });

    String url(int status) =>
        'http://127.0.0.1:${server.port}/$status?token=guest&__lt=lt';

    Future<int?> status(int s) async =>
        (await AudioPlayerHandler.probeStreamStatus(url(s))).status;

    test('reports the status of a one-byte range request', () async {
      expect(await status(401), 401);
      expect(await status(206), 206);
      expect(await status(404), 404);
      expect(ranges, ['bytes=0-0', 'bytes=0-0', 'bytes=0-0']);
    });

    // The peer's stream cap says how long it wants (5 s); its daily quota
    // sends the seconds to UTC midnight. The header rides along so the
    // verdict can tell the two 429s apart.
    test('a 429 carries its Retry-After', () async {
      final probe = await AudioPlayerHandler.probeStreamStatus(url(429));
      expect(probe.status, 429);
      expect(probe.retryAfter, const Duration(seconds: 5));
      expect(
          (await AudioPlayerHandler.probeStreamStatus(url(401))).retryAfter,
          isNull);
    });

    test('nothing listening → no status, not a throw', () async {
      final port = server.port;
      await server.close(force: true);
      final probe = await AudioPlayerHandler.probeStreamStatus(
          'http://127.0.0.1:$port/401?token=guest');
      expect(probe.status, isNull);
      expect(probe.retryAfter, isNull);
    });
  });
}
