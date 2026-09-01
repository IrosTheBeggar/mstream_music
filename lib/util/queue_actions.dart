// queue_actions.dart — shared queue/playback actions.
//
// Extracted from browser.dart so the album-detail screen and the file browser
// build identical MediaItems and run identical "play from here" semantics
// (clear the queue → enqueue the list in order → jump to the tapped track →
// play). Keeping one source of truth means a fix to the streaming-URL / local-
// cache logic lands everywhere at once.

import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:uuid/uuid.dart';

import '../objects/display_item.dart';
import '../objects/metadata.dart';
import '../objects/server.dart';
import '../singletons/api.dart';
import '../singletons/file_explorer.dart';
import '../singletons/media.dart';
import '../singletons/settings.dart';
import 'server_version.dart';
import 'stream_url.dart';

/// Pure builder for a localFile MediaItem (no I/O).
MediaItem buildLocalFileMediaItem(DisplayItem i) {
  return MediaItem(
    id: Uuid().v4(),
    title: i.name.split('/').last,
    extras: {'path': i.data, 'localPath': i.data!},
  );
}

/// Builds a server-file MediaItem, preferring a locally-cached copy when one is
/// present. Async because it has to check the download directory to decide
/// between a local path and a streaming URL. Returns null only if the configured
/// download location is unavailable (SD card removed / folder deleted).
///
/// The streaming URL is the MediaItem id for BOTH local and online items, so
/// playback can fall back to streaming if the local file goes missing; the local
/// path lives in extras and is re-checked at play time.
///
/// A search hit carries at most the lite metadata subset (PR #685, flagged
/// [DisplayItem.partialMetadata]) and an older server's hit carries none; either
/// way the full block is fetched here (POST /api/v1/db/metadata) before the
/// MediaItem is built, so the queued track has the fidelity / counts / play-count
/// the now-playing + Song Info screens show. Browsed/album rows already carry the
/// full block and skip the fetch. Best-effort: on a miss we keep whatever the row
/// had (the lite block, or null) and fall back to its altAlbumArt for the cover.
Future<MediaItem?> buildServerFileMediaItem(DisplayItem i) async {
  final dir = await FileExplorer()
      .getDownloadDir(i.server!.storageMode, i.server!.storageBasePath);
  return _buildServerFileMediaItemWithDir(i, dir);
}

/// [buildServerFileMediaItem] with the download dir already resolved — the
/// batch builder resolves it once per server instead of paying the
/// path_provider platform round-trip per row.
Future<MediaItem?> _buildServerFileMediaItemWithDir(
    DisplayItem i, Directory? dir) async {
  MusicMetadata? meta = i.metadata;
  if (meta == null || i.partialMetadata) {
    final full = await ApiManager().fetchTrackMetadata(i.server!, i.data!);
    if (full != null) meta = full;
  }

  final String downloadDirectory = i.server!.localname + i.data!;
  final String? finalString =
      dir == null ? null : '${dir.path}/media/$downloadDirectory';
  final bool isLocal =
      finalString != null && File(finalString).existsSync() == true;

  final String streamUrl = buildServerStreamUrl(i.server!, i.data!);

  // Prefer the (fetched) metadata cover; fall back to the search row's
  // altAlbumArt so a queued search hit keeps its art even when the metadata
  // fetch missed.
  final String? artFile = meta?.albumArt ?? i.altAlbumArt;
  final String? artUrl = artFile != null
      ? buildAlbumArtUrl(i.server!, artFile, compress: 'l')
      : null;

  return MediaItem(
    id: streamUrl,
    title: meta?.title ?? i.name,
    album: meta?.album,
    artist: meta?.artist,
    genre: meta?.genreLabel,
    // Duration when the server reported it — surfaces in the queue list and the
    // now-playing readout before playback loads (just_audio refines it later).
    duration: meta?.duration,
    // Promote album art to artUri so the notification, lock screen, and Android
    // Auto now-playing render artwork — those surfaces ignore extras['artUrl']
    // (which the in-app UI reads). Both are kept in sync.
    artUri: artUrl == null ? null : Uri.parse(artUrl),
    extras: {
      ...queueExtras(meta,
          server: i.server!.localname, path: i.data!, artUrl: artUrl),
      if (isLocal) 'localPath': finalString,
    },
  );
}

/// Builds the MediaItem for any playable row (file / localFile), or null for a
/// non-playable row / unavailable download dir.
Future<MediaItem?> buildMediaItemForRow(DisplayItem i) => i.type == 'localFile'
    ? Future.value(buildLocalFileMediaItem(i))
    : buildServerFileMediaItem(i);

/// MediaItem builds allowed in flight at once. Each partial-metadata row (all
/// search hits) posts /db/metadata during its build, so a bulk action used to
/// run one SERIAL network round-trip per row before playback could start.
const int _kBuildPool = 4;

/// Builds MediaItems for [rows] with bounded concurrency, preserving order:
/// the returned list is index-aligned with [rows] (null = build failed /
/// download dir unavailable — callers compact it). The download dir is
/// resolved once per server up front instead of once per row (path_provider
/// re-does the platform call every time).
Future<List<MediaItem?>> buildMediaItemsForRows(List<DisplayItem> rows) async {
  final dirs = <Server, Directory?>{};
  for (final r in rows) {
    final s = r.server;
    if (r.type == 'localFile' || s == null) continue;
    if (!dirs.containsKey(s)) {
      dirs[s] =
          await FileExplorer().getDownloadDir(s.storageMode, s.storageBasePath);
    }
  }

  final out = List<MediaItem?>.filled(rows.length, null);
  var next = 0;
  Future<void> worker() async {
    while (true) {
      final k = next++;
      if (k >= rows.length) return;
      final r = rows[k];
      try {
        out[k] = r.type == 'localFile'
            ? buildLocalFileMediaItem(r)
            : await _buildServerFileMediaItemWithDir(r, dirs[r.server]);
      } catch (_) {
        // Drop just this row; the serial path would have aborted the whole
        // action on a throw.
      }
    }
  }

  await Future.wait([for (var i = 0; i < _kBuildPool; i++) worker()]);
  return out;
}

/// Clears the queue, fills it with every playable item from [rows] (in order),
/// jumps to the one at [tappedIndex], and plays. When [shuffle] is true the
/// playable order is shuffled first and playback starts from the top.
///
/// Non-playable rows (folders, headers) are skipped, and [tappedIndex] is
/// remapped onto the filtered list. All MediaItems are built before the queue is
/// touched, so a failed build never leaves a half-replaced queue.
/// Fill in the metadata these rows are missing, one request per server,
/// before the build loops below ask for it one track at a time.
///
/// Only search hits and discovery rows arrive without a full block — browsed
/// and album rows already carry one and skip the fetch entirely — so this is
/// about "queue all" on a search, where 50 hits meant 50 serial round trips
/// each with its own timeout. In the car that is the whole of voice search.
///
/// Purely an optimisation, and deliberately shaped so it cannot become
/// anything else: it fills DisplayItem.metadata in place, and every row it
/// does NOT fill is fetched by buildServerFileMediaItem exactly as before. A
/// server below the floor, a 404, a timeout, a partial answer and a row the
/// server can't resolve all land in that same path without a branch of their
/// own — which is what makes the version floor an optimisation too rather
/// than something that has to be right.
Future<void> prefillMetadata(List<DisplayItem> rows) async {
  // Grouped by server: one queue can span servers and each has its own
  // version. Keyed by localname rather than by the Server object, so two
  // rows holding different instances of the same server still share a
  // request.
  final byServer = <String, List<DisplayItem>>{};
  for (final i in rows) {
    if (i.type != 'file') continue;
    if (i.metadata != null && !i.partialMetadata) continue;
    final s = i.server;
    if (s == null || i.data == null) continue;
    if (metadataBatchKnownUnsupported(
        ServerVersion.tryParse(s.serverVersion))) {
      continue;
    }
    (byServer[s.localname] ??= []).add(i);
  }
  for (final group in byServer.values) {
    // One row is one request either way: batching buys nothing and adds a
    // second way to fail.
    if (group.length < 2) continue;
    final got = await ApiManager()
        .fetchTrackMetadataBatch(group.first.server!, [
      for (final i in group) i.data!,
    ]);
    if (got.isEmpty) continue;
    for (final i in group) {
      final path = i.data!;
      final md = got[path.startsWith('/') ? path.substring(1) : path];
      if (md == null) continue;
      i.metadata = md;
      // The block is now the full one, so the per-row fetch is a no-op.
      i.partialMetadata = false;
    }
  }
}

Future<void> playFromHere(List<DisplayItem> rows, int tappedIndex,
    {bool shuffle = false}) async {
  final playable = <DisplayItem>[];
  int newIndex = 0;
  for (var j = 0; j < rows.length; j++) {
    final t = rows[j].type;
    if (t == 'file' || t == 'localFile') {
      if (j == tappedIndex) newIndex = playable.length;
      playable.add(rows[j]);
    }
  }
  if (playable.isEmpty) return;

  if (shuffle) {
    playable.shuffle();
    newIndex = 0;
  }

  // One batched metadata request per server first (search/discovery rows),
  // then the concurrent builds below fetch only what the batch missed.
  await prefillMetadata(playable);

  final built = await buildMediaItemsForRows(playable);

  // Compact the nulls while remapping the tapped index onto the survivors —
  // a failed build used to shift every later index, landing the jump on the
  // wrong track. If the tapped row itself failed, land on the nearest earlier
  // survivor (or the top).
  final items = <MediaItem>[];
  int jumpTo = 0;
  for (var k = 0; k < built.length; k++) {
    final m = built[k];
    if (m == null) continue;
    if (k <= newIndex) jumpTo = items.length;
    items.add(m);
  }
  if (items.isEmpty) return;

  await MediaManager().audioHandler.customAction('clearPlaylist');
  await MediaManager().audioHandler.addQueueItems(items);
  await MediaManager().audioHandler.skipToQueueItem(jumpTo);
  await MediaManager().audioHandler.play();
}

/// Appends every playable item from [rows] to the queue WITHOUT clearing it.
/// If the queue was empty, playback starts automatically (so a first "add"
/// from a fresh state doesn't require a separate play press). Returns the
/// number of tracks enqueued.
Future<int> addRowsToQueue(List<DisplayItem> rows) async {
  final handler = MediaManager().audioHandler;
  final wasEmpty = handler.queue.value.isEmpty;
  final playable = [
    for (final i in rows)
      if (i.type == 'file' || i.type == 'localFile') i,
  ];
  // Same order as playFromHere: batch-prefill, then concurrent builds.
  await prefillMetadata(playable);
  final built = await buildMediaItemsForRows(playable);
  final items = built.whereType<MediaItem>().toList();
  if (items.isEmpty) return 0;
  await handler.addQueueItems(items);
  if (wasEmpty) await handler.play();
  return items.length;
}

/// Applies the user's TapBehavior (Settings — the same setting the file browser
/// uses) to a single-row tap within [rows] at [index]:
///   • playFromHere  → play the whole list from [index]
///   • appendAndJump → append the row, jump to it, and play
///   • addToQueue    → append the row (play only if the queue was empty)
/// Returns true only for a pure append (addToQueue onto a non-empty queue), so
/// the caller can show an "added to queue" toast.
Future<bool> handleTrackTap(List<DisplayItem> rows, int index) async {
  if (index < 0 || index >= rows.length) return false;
  final behavior = SettingsManager().tapBehavior;
  if (behavior == TapBehavior.playFromHere) {
    await playFromHere(rows, index);
    return false;
  }
  final handler = MediaManager().audioHandler;
  final wasEmpty = handler.queue.value.isEmpty;
  final m = await buildMediaItemForRow(rows[index]);
  if (m == null) return false;
  await handler.addQueueItem(m);
  if (behavior == TapBehavior.appendAndJump) {
    await handler.skipToQueueItem(handler.queue.value.length - 1);
    await handler.play();
    return false;
  }
  // addToQueue: also start playback when the queue was empty. Always report a
  // queued result so the caller shows the "added to queue" toast.
  if (wasEmpty) await handler.play();
  return true;
}

/// Inserts [row] immediately after the current track WITHOUT changing playback
/// ("add next"). The handler has no insert wired to the backend, so we append
/// then move the new item up to right after the current track; the original
/// tracks continue after it. Returns the index it landed at (or null on build
/// failure). Falls back to the end when nothing is playing / current is last.
Future<int?> addNext(DisplayItem row) async {
  final handler = MediaManager().audioHandler;
  final m = await buildMediaItemForRow(row);
  if (m == null) return null;
  final before = handler.queue.value.length; // index of the appended item
  final current = handler.playbackState.value.queueIndex;
  await handler.addQueueItem(m);
  final target = (current == null || current < 0) ? before : current + 1;
  if (target < before) {
    await handler.customAction('moveQueueItem', {'from': before, 'to': target});
  }
  return target;
}

/// Inserts [row] next (via [addNext]) and starts playing it immediately.
Future<void> playNow(DisplayItem row) async {
  final target = await addNext(row);
  if (target == null) return;
  await MediaManager().audioHandler.skipToQueueItem(target);
  await MediaManager().audioHandler.play();
}

/// Appends [row] to the END of the queue WITHOUT playing.
Future<void> addToQueueEnd(DisplayItem row) async {
  final m = await buildMediaItemForRow(row);
  if (m == null) return;
  await MediaManager().audioHandler.addQueueItem(m);
}
