import '../objects/server.dart';
import '../util/server_version.dart';
import 'log_manager.dart';

/// Which request parameters a given server will actually accept.
///
/// mStream validates bodies with Joi and no `allowUnknown`, so sending a key
/// an older server doesn't know is a hard 400 whose message names the key:
///
///     {"error":"\"minSimilarity\" is not allowed"}
///
/// That makes the server self-describing, which beats any table we could
/// maintain: [noteRejection] reads the key straight out of the error and
/// remembers it, so the same request never fails twice for the same reason.
/// [ServerParam]'s version floors are only a pre-filter that saves the first
/// failed round trip where we can already tell the server is too old.
///
/// Deliberately IN MEMORY and per-process. Persisting "this server rejected X"
/// would outlive the upgrade that fixes it — the user updates their server and
/// the app keeps refusing to use the feature until someone clears a cache
/// nobody knows about. A process lifetime is long enough to stop repeated
/// failures and short enough to notice an upgrade.
class ServerCapabilities {
  ServerCapabilities._();
  static final ServerCapabilities instance = ServerCapabilities._();
  factory ServerCapabilities() => instance;

  /// server.localname → wire names that server has rejected this session.
  final Map<String, Set<String>> _rejected = {};

  /// Strip from [payload] anything [server] is known — or can be predicted —
  /// not to accept, and say what was dropped.
  ///
  /// Two sources, cheapest first: what the server has already rejected this
  /// session, then the version table. A caller passes the full payload it
  /// would like to send and gets back the one it should.
  ({Map<String, dynamic> body, List<String> dropped}) filter(
      Server server, Map<String, dynamic> payload) {
    final learned = _rejected[server.localname] ?? const <String>{};
    final version = ServerVersion.tryParse(server.serverVersion);
    final out = <String, dynamic>{};
    final dropped = <String>[];
    for (final entry in payload.entries) {
      if (learned.contains(entry.key)) {
        dropped.add(entry.key);
        continue;
      }
      final known = _paramByWireName[entry.key];
      if (known != null && paramKnownUnsupported(version, known)) {
        dropped.add(entry.key);
        continue;
      }
      out[entry.key] = entry.value;
    }
    return (body: out, dropped: dropped);
  }

  /// Record a rejection parsed out of a 400 body. Returns the wire name that
  /// was learned, or null when [errorBody] isn't a not-allowed rejection —
  /// in which case the caller must NOT retry, because the request failed for
  /// some other reason (auth, a bad value, the server being unwell) and
  /// resending a smaller body would just fail again with less information.
  String? noteRejection(Server server, String? errorBody) {
    final key = parseNotAllowedKey(errorBody);
    if (key == null) return null;
    // Log only on the FIRST learn. Concurrent callers (the seeded Auto DJ
    // start fires several picks at once) all send the same doomed payload
    // before any of them has learned, so each gets its own rejection for the
    // same key — one fact, not three. Set.add reports whether it was new.
    final added = (_rejected[server.localname] ??= <String>{}).add(key);
    if (added) {
      appLog('[caps] ${server.localname} rejected "$key" — '
          'dropping it for the rest of this session');
    }
    return key;
  }

  /// Stop sending [keys] to [server] for the rest of this session, for a
  /// reason other than the schema rejecting them.
  ///
  /// The schema case ([noteRejection]) is "this server has never heard of the
  /// key". This one is "the key is valid but the server cannot act on it yet"
  /// — sonic similarity against a library the discovery scan has not reached.
  /// Different causes, identical remedy: stop sending it, keep playing. Both
  /// live in the same set because the set's meaning is simply "wire names not
  /// to send to this server this session", and [forget] clears both on the
  /// upgrade or reconnect that could change either answer.
  void suppress(Server server, Iterable<String> keys, String reason) {
    final set = _rejected[server.localname] ??= <String>{};
    final added = keys.where(set.add).toList();
    if (added.isNotEmpty) {
      appLog('[caps] ${server.localname}: dropping '
          '${added.join(", ")} for this session — $reason');
    }
  }

  /// True when every one of [keys] is already suppressed for [server], so a
  /// caller can skip building them at all rather than building and stripping.
  bool allSuppressed(Server server, Iterable<String> keys) {
    final set = _rejected[server.localname];
    return set != null && keys.every(set.contains);
  }

  /// Everything [server] has rejected so far, for diagnostics.
  Set<String> rejectedFor(Server server) =>
      Set.unmodifiable(_rejected[server.localname] ?? const <String>{});

  /// Forget what we learned about [server] — call when its version changes,
  /// since an upgrade is exactly the event that makes old verdicts wrong.
  void forget(Server server) => _rejected.remove(server.localname);
}

/// Pull the offending key out of a Joi rejection.
///
/// Joi's message is `"<key>" is not allowed`, and mStream returns it as
/// `{"error": ...}`. Matching on the quoted key rather than the whole sentence
/// keeps this working if the surrounding wording changes. Pure; unit-tested.
String? parseNotAllowedKey(String? errorBody) {
  if (errorBody == null) return null;
  // An optional backslash on both sides: callers pass the RAW response body,
  // which is JSON, so the quotes around the key arrive escaped — the bytes are
  // {"error":"\"minSimilarity\" is not allowed"}. Accepting either form means
  // this works on the raw body and on an already-decoded message.
  final m = RegExp(r'\\?"([A-Za-z_][A-Za-z0-9_]*)\\?"\s+is not allowed')
      .firstMatch(errorBody);
  return m?.group(1);
}

final Map<String, ServerParam> _paramByWireName = {
  for (final p in ServerParam.values) paramWireName(p): p,
};
