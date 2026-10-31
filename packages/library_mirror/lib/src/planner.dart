import 'models.dart';

/// Tunables. The defaults copy the server's own backup worker
/// (`src/backup/worker.mjs`): a 2 s mtime window, with the ±1 h carve-out
/// FAT volumes need after a DST change, and case-insensitive collision
/// detection for the filesystems that fold case.
class PlanOptions {
  /// The server is mid-scan: rows can be transiently absent, so nothing is
  /// trashed on this pass.
  final bool scanning;

  /// Trash mirror-owned files no enabled rule wants any more.
  final bool trashUnwanted;
  final int mtimeToleranceMs;
  final int dstSkewMs;

  const PlanOptions({
    this.scanning = false,
    this.trashUnwanted = true,
    this.mtimeToleranceMs = 2000,
    this.dstSkewMs = 3600 * 1000,
  });
}

/// A local file the server now lists under a different path: moved, not
/// re-downloaded.
class Rename {
  final LocalFile from;
  final RemoteTrack to;
  const Rename(this.from, this.to);
}

/// A copy the mirror did not write (an imported or manual download) whose
/// size matches the server's: verified and stamped in place, never
/// re-downloaded.
class Adoption {
  final RemoteTrack remote;
  final LocalFile local;
  const Adoption(this.remote, this.local);
}

class Plan {
  final List<RemoteTrack> downloads;
  final List<RemoteTrack> replaces;
  final List<Rename> renames;
  final List<Adoption> adoptions;
  final List<LocalFile> trashes;

  /// Wanted paths that would collide on a case-folding filesystem. Skipped,
  /// never clobbered.
  final List<String> conflicts;
  final int unchanged;

  /// Bytes the transfers need, counting a replace's old copy too (it sits in
  /// the trash until the sweep).
  final int bytesNeeded;

  /// What was planned: [Quality.original] or a [Tier] id. One plan per
  /// quality — the tiers never see each other's rows.
  final String quality;

  const Plan({
    required this.downloads,
    required this.replaces,
    required this.renames,
    required this.adoptions,
    required this.trashes,
    required this.conflicts,
    required this.unchanged,
    required this.bytesNeeded,
    this.quality = Quality.original,
  });

  bool get hasWork =>
      downloads.isNotEmpty ||
      replaces.isNotEmpty ||
      renames.isNotEmpty ||
      adoptions.isNotEmpty ||
      trashes.isNotEmpty;
}

/// Whether a local mtime and the server's agree — within the tolerance, or
/// off by exactly one hour (a FAT volume after a DST switch).
bool mtimesAgree(int deltaMs, PlanOptions o) {
  final d = deltaMs.abs();
  return d < o.mtimeToleranceMs || (d - o.dstSkewMs).abs() < o.mtimeToleranceMs;
}

/// Decides what one sync run does for one [quality]. Pure over its inputs:
///
///  - [remote]: the server's current listing (the manifest rows);
///  - [local]: every local-copy row of the server, any origin or quality —
///    only the rows of [quality] take part;
///  - [wanted]: the paths the enabled rules of that quality pin.
///
/// Rules, per wanted path: a case-folded duplicate is a conflict; no usable
/// local copy is a download — unless a mirror-owned file with the same
/// content hash sits at a path the server no longer lists, which is a
/// rename; a copy without a recorded hash (imported or downloaded by hand,
/// so its mtime is when it landed, not the server's) is adopted when the
/// sizes agree and replaced when they differ; otherwise a size or mtime
/// disagreement is a replace, and the rest is unchanged. Then, unless the
/// server is scanning, mirror-owned rows the server dropped or no rule wants
/// are trashed. Manual, auto and external copies are never trashed or moved
/// — the mirror only ever removes what it created.
///
/// A transcoded tier ([Tier]) has no bytes to compare with the server's: its
/// rows carry the source's hash and mtime, so a copy is replaced when the
/// source changed and never for its size; there is nothing to adopt; the
/// bytes needed are estimated from the duration; and the duplicate check
/// runs on the tier's file names, since swapping extensions can make two
/// sources meet at one file.
Plan plan({
  required Iterable<RemoteTrack> remote,
  required Iterable<LocalFile> local,
  required Set<String> wanted,
  PlanOptions options = const PlanOptions(),
  String quality = Quality.original,
}) {
  final tier = Tier.parse(quality);
  final remoteByPath = {for (final t in remote) t.path: t};
  final localByPath = {
    for (final f in local)
      if (f.quality == quality) f.path: f,
  };
  int needed(RemoteTrack r) => tier?.estimateBytes(r) ?? r.size ?? 0;

  final byFoldedKey = <String, List<String>>{};
  for (final path in wanted) {
    final name = tier == null ? path : tier.pathFor(path);
    (byFoldedKey[name.toLowerCase()] ??= []).add(path);
  }
  final conflicts = <String>{
    for (final group in byFoldedKey.values)
      if (group.length > 1) ...group,
  };

  // Mirror-owned files the server no longer lists, by content hash: a wanted
  // path with the same hash is that file under a new name.
  final orphansByHash = <String, LocalFile>{};
  for (final f in localByPath.values) {
    if (f.origin != LocalOrigin.mirror || f.state != LocalState.ok) continue;
    if (remoteByPath.containsKey(f.path) || f.hash == null) continue;
    orphansByHash.putIfAbsent(f.hash!, () => f);
  }

  final downloads = <RemoteTrack>[];
  final replaces = <RemoteTrack>[];
  final renames = <Rename>[];
  final adoptions = <Adoption>[];
  final claimed = <String>{};
  var unchanged = 0;
  var bytes = 0;

  for (final path in wanted) {
    if (conflicts.contains(path)) continue;
    final r = remoteByPath[path];
    if (r == null) continue; // pinned by a rule but gone from the server
    final l = localByPath[path];
    if (l == null || l.state != LocalState.ok) {
      final orphan = r.hash == null ? null : orphansByHash[r.hash!];
      if (orphan != null && claimed.add(orphan.path)) {
        renames.add(Rename(orphan, r));
      } else {
        downloads.add(r);
        bytes += needed(r);
      }
    } else if (tier == null && l.hash == null) {
      if (r.size != null && l.size != null && r.size != l.size) {
        replaces.add(r);
        bytes += (r.size ?? 0) + (l.size ?? 0);
      } else {
        adoptions.add(Adoption(r, l));
      }
    } else if (_changed(r, l, options, tier)) {
      replaces.add(r);
      bytes += needed(r) + (l.size ?? 0);
    } else {
      unchanged++;
    }
  }

  final trashes = <LocalFile>[];
  if (!options.scanning) {
    for (final f in localByPath.values) {
      if (f.origin != LocalOrigin.mirror || claimed.contains(f.path)) continue;
      final gone = !remoteByPath.containsKey(f.path);
      final unwanted = options.trashUnwanted && !wanted.contains(f.path);
      if (gone || unwanted) trashes.add(f);
    }
  }

  return Plan(
    downloads: downloads,
    replaces: replaces,
    renames: renames,
    adoptions: adoptions,
    trashes: trashes,
    conflicts: conflicts.toList()..sort(),
    unchanged: unchanged,
    bytesNeeded: bytes,
    quality: quality,
  );
}

/// Whether the server's file moved on from the local copy. The original
/// compares bytes (size) and mtime; a tier compares the source it was made
/// from (the recorded hash) and mtime — its own size says nothing.
bool _changed(RemoteTrack r, LocalFile l, PlanOptions o, Tier? tier) {
  if (tier == null) {
    if (r.size != null && l.size != null && r.size != l.size) return true;
  } else if (r.hash != null && l.hash != null && r.hash != l.hash) {
    return true;
  }
  if (r.modified != null &&
      l.mtime != null &&
      !mtimesAgree(l.mtime! - r.modified!, o)) {
    return true;
  }
  return false;
}
