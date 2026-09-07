import 'dart:convert';

/// What is wrong with a pasted string, when it is not a usable ticket.
enum FederationTicketError {
  /// No `mstrfed<V>:` token anywhere in the text.
  notFound,

  /// A ticket from a newer format than this app understands.
  tooNew,

  /// The token is there but its payload does not decode or lacks the
  /// required fields.
  malformed,
}

/// The parse of a pasted / scanned / texted string: either a [ticket] or
/// an [error] saying why not.
class FederationTicketResult {
  final FederationTicket? ticket;
  final FederationTicketError? error;
  const FederationTicketResult.ok(FederationTicket this.ticket) : error = null;
  const FederationTicketResult.failed(FederationTicketError this.error)
      : ticket = null;
  bool get isOk => ticket != null;
}

/// A federation ticket — `mstrfed<V>:<base64url(JSON)>` — as the friend's
/// side reads it (spec: mStream `docs/federation-ticket.md`).
///
/// The payload carries the minting server's iroh endpoint ticket (`t`) and
/// the read-only API key (`k`); the display name (`n`), granted libraries
/// (`l`) and expiry (`e`) are informational — the preview shown before the
/// user adds the peer. The server re-parses the raw string itself, so this
/// class never rebuilds one: [raw] is what gets posted.
class FederationTicket {
  final String raw;
  final int version;
  final String endpointTicket;
  final String apiKey;
  final String? serverName;
  final List<String> libraries;
  final DateTime? expiresAt;

  const FederationTicket({
    required this.raw,
    required this.version,
    required this.endpointTicket,
    required this.apiKey,
    this.serverName,
    this.libraries = const [],
    this.expiresAt,
  });

  /// The newest format this app can read (the server's
  /// FEDERATION_TICKET_VERSION).
  static const int maxVersion = 1;

  /// A ticket token inside arbitrary text: the prefix, a version, a colon
  /// and a base64url body. `mstrfedg1:` (a guest ticket, device-facing)
  /// never matches — the version must follow `mstrfed` directly.
  static final RegExp _token = RegExp(r'mstrfed(\d{1,3}):([A-Za-z0-9_-]+=*)');

  /// The first ticket token in [text], or null. Accepts the bare ticket, a
  /// message with one pasted into it, and a link carrying it in the URL
  /// fragment (`https://…/f#mstrfed1:…`) — the tappable form of issue #162.
  static String? extract(String text) {
    final m = _token.firstMatch(text);
    return m?.group(0);
  }


  /// Parse [text] leniently (see [extract]) and validate the payload the way
  /// the server does: required `t`/`k` strings, a version this app knows.
  static FederationTicketResult parse(String text) {
    final m = _token.firstMatch(text);
    if (m == null) {
      return const FederationTicketResult.failed(
          FederationTicketError.notFound);
    }
    final version = int.tryParse(m.group(1)!) ?? 0;
    if (version < 1) {
      return const FederationTicketResult.failed(
          FederationTicketError.malformed);
    }
    if (version > maxVersion) {
      return const FederationTicketResult.failed(FederationTicketError.tooNew);
    }
    final body = m.group(2)!.replaceAll('=', '');
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(body))));
    } catch (_) {
      return const FederationTicketResult.failed(
          FederationTicketError.malformed);
    }
    if (decoded is! Map) {
      return const FederationTicketResult.failed(
          FederationTicketError.malformed);
    }
    final t = decoded['t'];
    final k = decoded['k'];
    if (t is! String || t.isEmpty || k is! String || k.isEmpty) {
      return const FederationTicketResult.failed(
          FederationTicketError.malformed);
    }
    final n = decoded['n'];
    final l = decoded['l'];
    final e = decoded['e'];
    DateTime? expires;
    if (e is String && e.isNotEmpty) {
      expires = DateTime.tryParse(e)?.toLocal();
    }
    return FederationTicketResult.ok(FederationTicket(
      raw: m.group(0)!,
      version: version,
      endpointTicket: t,
      apiKey: k,
      serverName: n is String && n.trim().isNotEmpty ? n.trim() : null,
      libraries: l is List ? [for (final x in l) if (x is String) x] : const [],
      expiresAt: expires,
    ));
  }

  /// Past its expiry, as far as the ticket itself says (the minting server
  /// is the truth once paired).
  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());
}
