/// Which embedding model each server answers sonic queries in, remembered
/// for a while.
///
/// A cross-server Auto DJ seed only means something inside one model space,
/// and a server refuses a foreign vector with a hard 400 (mStream #929) — a
/// caller is expected to read the model first and skip a server that
/// disagrees. So a session asks each server up front (`GET
/// /api/v1/federation/health`, `discovery.modelId`), the way the webapp does
/// (mStream #946), instead of discovering the mismatch by erroring.
///
/// A known model is kept for [okTtl]: a rescan under a new model is rare and
/// slow. "No model" — discovery off there, nothing analysed yet, or the
/// server not answering — is retried after [retryTtl], since a scan finishing
/// or a server coming back is exactly the change worth noticing soon.
/// Pure; unit-tested.
class SessionModelCache {
  SessionModelCache({
    this.okTtl = const Duration(minutes: 5),
    this.retryTtl = const Duration(minutes: 1),
  });

  final Duration okTtl;
  final Duration retryTtl;
  final Map<String, ({String? modelId, DateTime at})> _entries = {};

  /// The remembered answer for [key], or null when none is fresh enough to
  /// trust — ask the server again. A fresh entry with a null modelId is a
  /// real answer: that server has no model to offer right now.
  ({String? modelId})? lookup(String key, DateTime now) {
    final e = _entries[key];
    if (e == null) return null;
    final ttl = e.modelId == null ? retryTtl : okTtl;
    if (now.difference(e.at) >= ttl) return null;
    return (modelId: e.modelId);
  }

  void record(String key, String? modelId, DateTime now) =>
      _entries[key] = (modelId: modelId, at: now);

  void clear() => _entries.clear();
}
