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

    test('rejects a server exposing the incompatible-only endpoint', () async {
      final client = MockClient((req) async {
        if (req.url.path == '/api/') {
          return http.Response('{"server":"6.7.0","apiVersions":["1"]}', 200);
        }
        if (req.url.path == '/api/v1/ping/public') {
          return http.Response(
              '{"status":"ok","instanceId":"abc","hasUsers":true}', 200);
        }
        return http.Response('not found', 404);
      });
      expect(await isServerSupported('https://x.example.com', client: client),
          isFalse);
    });

    test('accepts a standard server (version present, no extra endpoint)',
        () async {
      final client = MockClient((req) async {
        if (req.url.path == '/api/') {
          return http.Response('{"server":"6.7.0","apiVersions":["1"]}', 200);
        }
        return http.Response('not found', 404);
      });
      expect(await isServerSupported('https://x.example.com', client: client),
          isTrue);
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
