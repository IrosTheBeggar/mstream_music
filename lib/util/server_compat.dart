import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Probes [baseUrl] to decide whether this client supports the server
/// build running there. Returns `true` for a supported server and
/// `false` for a build this client does not work with.
///
/// Detection is positive-only: network errors, timeouts, non-200
/// responses and unparseable bodies all resolve to `true` (supported),
/// so a temporarily-unreachable or otherwise-normal server is never
/// wrongly rejected — only an affirmative match marks a server
/// unsupported.
///
/// Two independent signals are probed in parallel; either is decisive.
/// [client] may be injected for testing.
Future<bool> isServerSupported(String baseUrl, {http.Client? client}) async {
  final c = client ?? http.Client();
  final ownsClient = client == null;
  try {
    final Uri base = Uri.parse(baseUrl);
    final results = await Future.wait([
      _matchesVersion(c, base),
      _matchesPublicPing(c, base),
    ]);
    return !(results[0] || results[1]);
  } catch (_) {
    return true;
  } finally {
    if (ownsClient) c.close();
  }
}

/// The version-discovery endpoint reports the server's build string.
/// Incompatible downstream builds tag that string with a known marker.
Future<bool> _matchesVersion(http.Client c, Uri base) async {
  try {
    final res =
        await c.get(base.resolve('/api/')).timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) return false;
    final body = jsonDecode(res.body);
    if (body is Map) {
      final server = body['server']?.toString().toLowerCase() ?? '';
      return server.contains('velvet');
    }
  } catch (_) {}
  return false;
}

/// A public endpoint exposed only by the incompatible build, identified
/// by its `hasUsers` field. Absent (404) on a supported server.
Future<bool> _matchesPublicPing(http.Client c, Uri base) async {
  try {
    final res = await c
        .get(base.resolve('/api/v1/ping/public'))
        .timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) return false;
    final body = jsonDecode(res.body);
    return body is Map && body.containsKey('hasUsers');
  } catch (_) {}
  return false;
}
