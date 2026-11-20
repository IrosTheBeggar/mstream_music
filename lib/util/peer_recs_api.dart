import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../objects/peer_recs.dart';
import '../objects/server.dart';
import '../singletons/api.dart';
import '../singletons/log_manager.dart';
import 'discovery_plugins_api.dart' show ownServerOf;

/// The Peer Recommendations page's own routes (mStream
/// docs/peer-recommendations-plan.md §3.2, §3.3): the peer strip's
/// `GET /api/v1/discovery/p2p/peers` and an admin's
/// `POST /api/v1/admin/discovery/p2p/peer-dbs/add`.
///
/// Spoken to the user's own server ([ownServerOf]: a connected server's
/// virtual Server goes to its parent, whose shelf the page searches) over
/// ApiManager's pooled direct client — the transport the taste call uses —
/// unless a client is injected (tests). Headless (no browser loading bar)
/// and bounded by [timeout]. Never throws: every outcome is a status the
/// page's rules read (peer_recs_rules.dart), 0 when no answer came, and the
/// server's words are never carried (the page never draws them).
class PeerRecsApi {
  static const String kPeersPath = '/api/v1/discovery/p2p/peers';
  static const String kAddPath = '/api/v1/admin/discovery/p2p/peer-dbs/add';

  /// The user's own server; null when [ownServerOf] found none (a connected
  /// server whose parent is not linked): nothing is sent, every call
  /// answers 0.
  final Server? server;

  /// An injected client (tests); null = ApiManager's pooled one, read per
  /// call ([ApiManager.resetDirectClient] replaces it).
  final http.Client? client;
  final Duration timeout;

  PeerRecsApi(Server server,
      {this.client, this.timeout = const Duration(seconds: 15)})
      : server = ownServerOf(server);

  http.Client get _http => client ?? ApiManager().directClient;

  /// `GET /api/v1/discovery/p2p/peers` (plan §3.2): a 200 carries the parsed
  /// view (null when the body is not an object); any other answer only its
  /// status — 403 is the network switched off or not an account (R7), 404
  /// a server without the route; 0 = no answer or the bound ran out.
  Future<PeersAnswer> peers() async {
    final res = await _call((own, headers) =>
        _http.get(own.apiUri(kPeersPath), headers: headers));
    if (res == null) return const PeersAnswer(0);
    if (res.statusCode != 200) return PeersAnswer(res.statusCode);
    return PeersAnswer(200, PeerView.fromServerMap(_decode(res.body)));
  }

  /// `POST /api/v1/admin/discovery/p2p/peer-dbs/add` {endpointId} (plan
  /// §3.3): a 202 (adding) or 200 (done, adding, or a failed pre-check with
  /// its code) carries the stored state the body names; any other answer
  /// only its status (404 not in the catalogue, 409 blocked or another
  /// model, 403 / 405 the admin gates, 400 a bad id); 0 = no answer.
  Future<PeerAddAnswer> add(String endpointId) async {
    final res = await _call((own, headers) => _http.post(own.apiUri(kAddPath),
        headers: headers, body: jsonEncode({'endpointId': endpointId})));
    if (res == null) return const PeerAddAnswer(0);
    final status = res.statusCode;
    if (status != 200 && status != 202) return PeerAddAnswer(status);
    return PeerAddAnswer(status, PeerAddState.fromServerMap(_decode(res.body)));
  }

  // ── transport ───────────────────────────────────────────────────────

  /// [send] on the own server with the token, bounded by [timeout]; null
  /// when nothing answered (no own server, a transport failure, the bound).
  Future<http.Response?> _call(
      Future<http.Response> Function(Server own, Map<String, String> headers)
          send) async {
    final own = server;
    if (own == null) return null;
    try {
      return await send(own, {
        'Content-Type': 'application/json',
        'x-access-token': own.authToken ?? '',
      }).timeout(timeout);
    } catch (err) {
      verboseLog('[api] peer recs call failed: $err');
      return null;
    }
  }

  /// The body as JSON, or null when it is none.
  static dynamic _decode(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }
}
