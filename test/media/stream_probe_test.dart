// The loopback probe behind FEDERATION_PLAN 8a: one ranged GET, the status
// back, nothing else. Against a real socket, since the point is what the
// peer's HTTP layer says.

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

    test('reports the status of a one-byte range request', () async {
      expect(await AudioPlayerHandler.probeStreamStatus(url(401)), 401);
      expect(await AudioPlayerHandler.probeStreamStatus(url(206)), 206);
      expect(await AudioPlayerHandler.probeStreamStatus(url(404)), 404);
      expect(ranges, ['bytes=0-0', 'bytes=0-0', 'bytes=0-0']);
    });

    test('nothing listening → null, not a throw', () async {
      final port = server.port;
      await server.close(force: true);
      expect(
          await AudioPlayerHandler.probeStreamStatus(
              'http://127.0.0.1:$port/401?token=guest'),
          isNull);
    });
  });
}
