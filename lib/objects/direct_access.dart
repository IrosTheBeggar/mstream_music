// What a parent hands out for reaching one of its federated peers DIRECTLY —
// `GET /api/v1/federation/peers/:id/access` (mStream#943). Pure parsing, so
// the shape the app depends on is pinned by a unit test instead of by a
// two-server rig.
//
// The parent answers one of three ways, and the app treats them differently:
//   direct: true   — a guest token the peer minted for the parent's key, the
//                    peer's endpoint ticket, and both packaged as a
//                    `mstrfedg1:` ticket for the native dial → go direct;
//   direct: false  — the peer will not mint (an older build, or federation
//                    switched off there) → the proxy path is all there is;
//   anything else  — a malformed 200 → transient, try again later.

class DirectAccess {
  const DirectAccess({
    required this.endpointTicket,
    required this.endpointId,
    required this.guestToken,
    required this.ticket,
    required this.expiresAt,
  });

  /// The peer's iroh EndpointTicket (routing info, not a secret).
  final String endpointTicket;

  /// The peer's endpoint id (a public key), or null when the parent could
  /// not read the ticket. Lets a later step notice one peer listed by two
  /// parents.
  final String? endpointId;

  /// The guest JWT: what every request to the peer carries in the ordinary
  /// token slots (`x-access-token`, `?token=`).
  final String guestToken;

  /// The `mstrfedg1:` envelope of endpoint ticket + guest token — what the
  /// native dial (and the in-place credential swap) takes, verbatim.
  final String ticket;

  /// When the guest token expires (UTC). The parent re-mints past three
  /// quarters of the lifetime; the app asks again on the same schedule.
  final DateTime expiresAt;

  /// Null when the parent answered `direct: false`. Throws [FormatException]
  /// on a 200 that is missing fields, which callers treat as transient —
  /// unlike a refusal, which holds for the session.
  static DirectAccess? fromJson(Map json) {
    if (json['direct'] != true) return null;
    final t = json['endpointTicket'];
    final g = json['guestToken'];
    final d = json['directTicket'];
    final e = json['expiresAt'];
    if (t is! String ||
        t.isEmpty ||
        g is! String ||
        g.isEmpty ||
        d is! String ||
        !d.startsWith('mstrfedg') ||
        e is! String) {
      throw const FormatException('direct access payload is missing fields');
    }
    final expiresAt = DateTime.tryParse(e);
    if (expiresAt == null) {
      throw const FormatException('direct access expiresAt is not a date');
    }
    final id = json['endpointId'];
    return DirectAccess(
      endpointTicket: t,
      endpointId: id is String && id.isNotEmpty ? id : null,
      guestToken: g,
      ticket: d,
      expiresAt: expiresAt.toUtc(),
    );
  }
}
