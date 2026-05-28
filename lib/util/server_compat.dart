import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Probes [baseUrl] to decide whether this client supports the server
/// build running there. Returns `true` for a supported server and
/// `false` for a build this client does not work with.
///
/// Only the public `/api/` version-discovery endpoint is queried. That
/// endpoint sits in front of the server's auth wall, so the probe never
/// triggers a spurious 401 the way hitting an authenticated `/api/v1/*`
/// path without a token would.
///
/// Detection is positive-only: network errors, timeouts, non-200
/// responses and unparseable bodies all resolve to `true` (supported),
/// so a temporarily-unreachable or otherwise-normal server is never
/// wrongly rejected — only an affirmative match marks a server
/// unsupported.
///
/// [client] may be injected for testing.
Future<bool> isServerSupported(String baseUrl, {http.Client? client}) async {
  final c = client ?? http.Client();
  final ownsClient = client == null;
  try {
    final res = await c
        .get(Uri.parse(baseUrl).resolve('/api/'))
        .timeout(const Duration(seconds: 5));
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body is Map) {
        // The version-discovery endpoint reports the server's build
        // string; incompatible downstream builds tag it with a marker.
        final server = body['server']?.toString().toLowerCase() ?? '';
        if (server.contains('velvet')) return false;
      }
    }
    return true;
  } catch (_) {
    return true;
  } finally {
    if (ownsClient) c.close();
  }
}
