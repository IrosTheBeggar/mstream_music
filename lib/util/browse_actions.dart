// browse_actions.dart — the shared tap dispatch for DisplayItem lists.
//
// Extracted from _BrowserState.handleTap so surfaces OTHER than the main
// browser (the desktop search page's sectioned results, future dashboard
// shelves) act on items with byte-identical semantics: the same navigation
// per type, the same tap-behavior preference on files, the same sonic-path
// capture guard. The browser delegates here; behavior is unchanged.

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../objects/display_item.dart';
import '../screens/add_server.dart';
import '../screens/sonic_path_screen.dart';
import '../singletons/api.dart';
import '../singletons/browser_list.dart';
import '../singletons/file_explorer.dart';
import '../singletons/media.dart';
import '../singletons/settings.dart';
import '../singletons/track_capture.dart';
import 'queue_actions.dart';

// Item types whose tap loads a new list (vs. file/localFile, which just
// enqueue and leave the current list in place). Tapping any of these closes
// local search.
const Set<String> browseNavTypes = {
  'addServer',
  'directory',
  'playlist',
  'execAction',
  'artist',
  'album',
  'localDirectory',
};

/// Dispatch a tap on [browserList]'s [index] item — the one shared browse
/// action table. Returns after kicking off the action; loading/queue state
/// flows through the usual singletons.
void handleBrowseTap(
    List<DisplayItem> browserList, int index, BuildContext context) {
  // A browse fetch is already in flight — ignore taps until it resolves (or
  // is cancelled with Back). Without this, tapping a second folder before the
  // first finished kicked off a racing request and the screen showed whichever
  // returned last. addServer stays actionable (the no-server screen never has
  // a load in flight, but never lock the user out of adding a server).
  if (BrowserManager().isLoading && browserList[index].type != 'addServer') {
    return;
  }

  if (browseNavTypes.contains(browserList[index].type)) {
    BrowserManager().closeSearch();
  }

  if (browserList[index].type == 'addServer') {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddServerScreen()),
    );
    return;
  }

  if (browserList[index].type == 'directory') {
    ApiManager().getFileList(browserList[index].data ?? '',
        useThisServer: browserList[index].server);
    return;
  }

  if (browserList[index].type == 'playlist') {
    ApiManager().getPlaylistContents(browserList[index].data ?? '',
        useThisServer: browserList[index].server);
    return;
  }

  if (browserList[index].type == 'execAction') {
    final data = browserList[index].data;
    final server = browserList[index].server;
    switch (data) {
      case 'playlists':
        ApiManager().getPlaylists(useThisServer: server);
        return;
      case 'fileExplorer':
        ApiManager().getFileList("~", useThisServer: server);
        return;
      case 'recent':
        ApiManager().getRecentlyAdded(useThisServer: server);
        return;
      case 'rated':
        ApiManager().getRated(useThisServer: server);
        return;
      case 'albums':
        ApiManager().getAlbums(useThisServer: server);
        return;
      case 'localFiles':
        FileExplorer().getPathForServer(server!);
        return;
      case 'artists':
        ApiManager().getArtists(useThisServer: server);
        return;
    }
    return;
  }

  if (browserList[index].type == 'artist') {
    ApiManager().getArtistAlbums(browserList[index].data ?? '',
        useThisServer: browserList[index].server);
    return;
  }

  if (browserList[index].type == 'album') {
    // Open the album detail over the browser body (no route) — keeps the
    // file-explorer model and the mini-player visible. See main.dart's
    // IndexedStack and BrowserManager.albumDetail.
    BrowserManager().openAlbumDetail(browserList[index]);
    return;
  }

  if (browserList[index].type == 'file') {
    // An armed sonic-path pick eats the tap BEFORE tap-behavior dispatch
    // — nothing may queue (or play-from-here) mid-pick.
    if (_captureTap(browserList[index], context)) return;
    if (SettingsManager().tapBehavior == TapBehavior.playFromHere) {
      playFromHere(browserList, index);
    } else {
      enqueueServerFile(browserList[index]);
    }
    return;
  }

  if (browserList[index].type == 'localDirectory') {
    FileExplorer()
        .getLocalFiles(browserList[index].data, browserList[index].server!);
    return;
  }

  if (browserList[index].type == 'localFile') {
    // Local files can't seed the server's index — an armed pick rejects
    // them (toast) instead of queueing.
    if (_captureTap(browserList[index], context)) return;
    if (SettingsManager().tapBehavior == TapBehavior.playFromHere) {
      playFromHere(browserList, index);
    } else {
      enqueueLocalFile(browserList[index]);
    }
    return;
  }
}

/// True when an armed TrackCapture consumed the tap: a captured pick
/// returns to the sonic path screen (its state already holds the song),
/// a rejected one toasts and stays armed.
bool _captureTap(DisplayItem item, BuildContext context) {
  switch (TrackCapture.tryCapture(item)) {
    case CaptureResult.captured:
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SonicPathScreen()),
      );
      return true;
    case CaptureResult.rejected:
      showCaptureRejectedToast(context);
      return true;
    case CaptureResult.pass:
      return false;
  }
}

// Side-effect entry points. Build the MediaItem then run it through
// _enqueue, which applies the user's tap behavior preference.
Future<void> enqueueLocalFile(DisplayItem i) async {
  await _enqueue(buildLocalFileMediaItem(i));
}

Future<void> enqueueServerFile(DisplayItem i) async {
  final item = await buildServerFileMediaItem(i);
  if (item != null) await _enqueue(item);
}

// Adds the item to the queue, then dispatches on the user's tap
// behavior preference. Pattern A (playFromHere) doesn't reach here
// — it's handled directly in handleBrowseTap because it needs the
// surrounding list context to know what to fill the queue with.
Future<void> _enqueue(MediaItem item) async {
  final wasEmpty = MediaManager().audioHandler.queue.value.isEmpty;
  await MediaManager().audioHandler.addQueueItem(item);

  switch (SettingsManager().tapBehavior) {
    case TapBehavior.addToQueue:
      // Convenience: first tap from a fresh state shouldn't require
      // a separate Play press to actually start anything.
      if (wasEmpty) {
        await MediaManager().audioHandler.play();
      }
      break;
    case TapBehavior.appendAndJump:
      final queueLen = MediaManager().audioHandler.queue.value.length;
      await MediaManager().audioHandler.skipToQueueItem(queueLen - 1);
      await MediaManager().audioHandler.play();
      break;
    case TapBehavior.playFromHere:
      // Unreachable — see handleBrowseTap.
      break;
  }
}
