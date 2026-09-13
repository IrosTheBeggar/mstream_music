import 'dart:io';

import 'package:library_mirror/library_mirror.dart' show Tier;
import 'package:path/path.dart' as p;

import '../objects/server.dart';

/// Where a local copy of [dataPath] (the server's `/<vpath>/<rel>` path) on
/// [s] may live, in preference order:
///
///  1. the app's own download tree — `<downloadDir>/media/<localname><data>`,
///     the same formula DownloadManager writes with, so a download is found
///     exactly where it landed;
///  2. the server's mirror root — a folder something else keeps in sync
///     (Syncthing, rclone, robocopy, a NAS mirror) in `<vpath>/<rel>` shape,
///     so `mirrorRoot + data` is the file. The app only ever reads it;
///  3. the library copy's transcoded tiers (A7) —
///     `<downloadDir>/media-transcoded/<tier>/<localname><data>` with the
///     tier's extension, one per tier in [Server.mirrorTiers]. Smaller
///     stand-ins, so last — and left out with [transcoded] false: a download
///     must never be satisfied by one.
///
/// [downloadDir] is the already-resolved download location (null = currently
/// unavailable, e.g. SD card out); callers that check many rows resolve it
/// once per server. Pure — no disk access — so a caller stats only what it
/// needs (see [firstExistingSync]).
List<String> localCopyCandidates(
    Server s, Directory? downloadDir, String dataPath,
    {bool transcoded = true}) {
  final root = s.mirrorRoot;
  return [
    if (downloadDir != null)
      '${downloadDir.path}/media/${s.localname}$dataPath',
    // Normalised so a Windows root ('C:\Music') and the server's '/'
    // separators produce one well-formed native path.
    if (root != null && root.isNotEmpty) p.normalize(root + dataPath),
    if (transcoded && downloadDir != null)
      for (final q in s.mirrorTiers)
        if (Tier.parse(q) case final tier?)
          '${downloadDir.path}/media-transcoded/${tier.id}/${s.localname}'
              '${tier.pathFor(dataPath)}',
  ];
}

/// The first candidate that exists on disk, or null. Sync because every
/// caller already stats from a sync context (play-time resolution, the
/// per-row badge check) and a candidate list is a few paths at most.
String? firstExistingSync(Iterable<String> candidates) {
  for (final c in candidates) {
    if (File(c).existsSync()) return c;
  }
  return null;
}
