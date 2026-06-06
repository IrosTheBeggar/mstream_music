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
import '../objects/server.dart';
import '../singletons/file_explorer.dart';
import '../singletons/media.dart';
import '../singletons/settings.dart';
import '../singletons/transcode.dart';

/// Pure builder for a localFile MediaItem (no I/O).
MediaItem buildLocalFileMediaItem(DisplayItem i) {
  return MediaItem(
    id: Uuid().v4(),
    title: i.name.split('/').last,
    extras: {'path': i.data, 'localPath': i.data!},
  );
}

/// Builds the streaming URL for a server file [path] (the leading-slash data
/// path, e.g. "/Music/foo.mp3"). Honors the current transcode setting and
/// appends a fresh cache-busting app_uuid plus the server token. Shared by the
/// browse-time MediaItem builder and the queue-restore rebuild so both stay in
/// lockstep — and so the rebuilt URL always carries the CURRENT token (a saved
/// URL's token can go stale between sessions).
String buildServerStreamUrl(Server server, String path) {
  String p = '';
  path.split('/').forEach((element) {
    if (element.isEmpty) return;
    p += '/' + Uri.encodeComponent(element);
  });
  final String prefix =
      TranscodeManager().transcodeOn == true ? '/transcode' : '/media';
  return server.url +
      prefix +
      p +
      '?app_uuid=' +
      Uuid().v4() +
      (server.jwt == null ? '' : '&token=' + server.jwt!);
}

/// Builds a server-file MediaItem, preferring a locally-cached copy when one is
/// present. Async because it has to check the download directory to decide
/// between a local path and a streaming URL. Returns null only if the configured
/// download location is unavailable (SD card removed / folder deleted).
///
/// The streaming URL is the MediaItem id for BOTH local and online items, so
/// playback can fall back to streaming if the local file goes missing; the local
/// path lives in extras and is re-checked at play time.
Future<MediaItem?> buildServerFileMediaItem(DisplayItem i) async {
  final String downloadDirectory = i.server!.localname + i.data!;
  final dir = await FileExplorer()
      .getDownloadDir(i.server!.storageMode, i.server!.storageBasePath);
  final String? finalString =
      dir == null ? null : '${dir.path}/media/$downloadDirectory';
  final bool isLocal =
      finalString != null && File(finalString).existsSync() == true;

  final String streamUrl = buildServerStreamUrl(i.server!, i.data!);

  final String? artUrl = i.metadata?.albumArt != null
      ? Uri.parse(i.server!.url.toString())
          .resolve('/album-art/' +
              i.metadata!.albumArt! +
              '?compress=l&token=' +
              (i.server!.jwt ?? ''))
          .toString()
      : null;

  return MediaItem(
    id: streamUrl,
    title: i.metadata?.title ?? i.name,
    album: i.metadata?.album,
    artist: i.metadata?.artist,
    genre: i.metadata?.genreLabel,
    // Duration when the server reported it — surfaces in the queue list and the
    // now-playing readout before playback loads (just_audio refines it later).
    duration: i.metadata?.duration,
    extras: {
      'server': i.server!.localname,
      'path': i.data,
      if (isLocal) 'localPath': finalString,
      'year': i.metadata?.year,
      'track': i.metadata?.track,
      'disc': i.metadata?.disc,
      'artUrl': artUrl,
      // bpm + musicalKey power AutoDJ's BPM-continuity / harmonic-mixing modes.
      'bpm': i.metadata?.bpm,
      'musicalKey': i.metadata?.musicalKey,
    },
  );
}

/// Builds the MediaItem for any playable row (file / localFile), or null for a
/// non-playable row / unavailable download dir.
Future<MediaItem?> buildMediaItemForRow(DisplayItem i) => i.type == 'localFile'
    ? Future.value(buildLocalFileMediaItem(i))
    : buildServerFileMediaItem(i);

/// Clears the queue, fills it with every playable item from [rows] (in order),
/// jumps to the one at [tappedIndex], and plays. When [shuffle] is true the
/// playable order is shuffled first and playback starts from the top.
///
/// Non-playable rows (folders, headers) are skipped, and [tappedIndex] is
/// remapped onto the filtered list. All MediaItems are built before the queue is
/// touched, so a failed build never leaves a half-replaced queue.
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

  final items = <MediaItem>[];
  for (final i in playable) {
    final m = await buildMediaItemForRow(i);
    if (m != null) items.add(m);
  }
  if (items.isEmpty) return;

  await MediaManager().audioHandler.customAction('clearPlaylist');
  for (final m in items) {
    await MediaManager().audioHandler.addQueueItem(m);
  }
  await MediaManager().audioHandler.skipToQueueItem(newIndex);
  await MediaManager().audioHandler.play();
}

/// Appends every playable item from [rows] to the queue WITHOUT clearing it.
/// If the queue was empty, playback starts automatically (so a first "add"
/// from a fresh state doesn't require a separate play press). Returns the
/// number of tracks enqueued.
Future<int> addRowsToQueue(List<DisplayItem> rows) async {
  final wasEmpty = MediaManager().audioHandler.queue.value.isEmpty;
  int n = 0;
  for (final i in rows) {
    if (i.type != 'file' && i.type != 'localFile') continue;
    final m = await buildMediaItemForRow(i);
    if (m == null) continue;
    await MediaManager().audioHandler.addQueueItem(m);
    n++;
  }
  if (n > 0 && wasEmpty) {
    await MediaManager().audioHandler.play();
  }
  return n;
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
