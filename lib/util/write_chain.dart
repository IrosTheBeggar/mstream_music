/// Serializes writes to a single file through one chain so overlapping
/// truncate+write cycles can't interleave and corrupt it.
///
/// This is the servers.json pattern (ServerManager's write chain), extracted
/// so the other persistence files — settings.json, auto_dj.json,
/// playlists.json, queue.json, auto_downloads.json — get the same guarantee.
/// Their loads all swallow a corrupt file (by design: startup must not block),
/// which makes silent interleaved-write corruption a silent settings/data
/// reset; serializing the writes removes the hazard at the source.
class WriteChain {
  Future<void> _chain = Future.value();

  /// Run [action] after every previously queued action has settled.
  ///
  /// The returned future completes (or errors) with [action]'s own outcome;
  /// the internal baton swallows errors so one failed write can't block
  /// every write that comes after it.
  Future<void> run(Future<void> Function() action) {
    final next = _chain.then((_) => action());
    _chain = next.catchError((_) {});
    return next;
  }
}
