import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mstream_music/util/server_compat.dart';

void main() {
  group('isServerSupported', () {
    test('rejects a server whose version string carries the marker', () async {
      final client = MockClient((req) async {
        if (req.url.path == '/api/') {
          return http.Response(
              '{"server":"7.3.0-velvet","apiVersions":["1"]}', 200);
        }
        return http.Response('not found', 404);
      });
      expect(await isServerSupported('https://x.example.com', client: client),
          isFalse);
    });

    test('accepts a standard server', () async {
      final client = MockClient((req) async {
        if (req.url.path == '/api/') {
          return http.Response('{"server":"6.7.0","apiVersions":["1"]}', 200);
        }
        return http.Response('not found', 404);
      });
      expect(await isServerSupported('https://x.example.com', client: client),
          isTrue);
    });

    // Regression: an earlier version also probed /api/v1/ping/public,
    // which doesn't exist on a standard server and falls through to the
    // auth wall — returning a spurious 401 on every Test Connection,
    // Save, and app launch. The probe must touch ONLY the public /api/.
    test('only probes the public /api/ endpoint (no auth-walled paths)',
        () async {
      final requested = <String>[];
      final client = MockClient((req) async {
        requested.add(req.url.path);
        if (req.url.path == '/api/') {
          return http.Response('{"server":"6.7.0","apiVersions":["1"]}', 200);
        }
        // Mimic the server's auth wall for any authenticated /api/v1 path.
        return http.Response('{"error":"Authentication Error"}', 401);
      });
      final supported =
          await isServerSupported('https://x.example.com', client: client);
      expect(supported, isTrue);
      expect(requested, ['/api/']);
    });

    test('treats a network failure as supported (fail open)', () async {
      final client = MockClient((req) async {
        throw http.ClientException('connection refused');
      });
      expect(await isServerSupported('https://x.example.com', client: client),
          isTrue);
    });

    test('treats an unparseable body as supported', () async {
      final client =
          MockClient((req) async => http.Response('<html>nope</html>', 200));
      expect(await isServerSupported('https://x.example.com', client: client),
          isTrue);
    });
  });
}
