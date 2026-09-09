// browse_actions.dart — the shared tap dispatch for DisplayItem lists.
//
// Extracted from _BrowserState.handleTap so surfaces OTHER than the main
// browser (the desktop search page's sectioned results, future dashboard
// shelves) act on items with byte-identical semantics: the same navigation
// per type, the same tap-behavior preference on files, the same sonic-path
// capture guard. The browser delegates here; behavior is unchanged.

import 'package:audio_service/audio_service.dart';
import 'package:material_ui/material_ui.dart';

import '../objects/display_item.dart';
import '../screens/add_server.dart';
import '../screens/add_torrent_screen.dart';
import '../screens/auto_dj.dart';
import '../screens/federation/federation_screen.dart';
import '../screens/p2p/p2p_screen.dart';
import '../screens/sonic_path_screen.dart';
import '../singletons/api.dart';
import '../singletons/browser_list.dart';
import '../singletons/file_explorer.dart';
import 'media_format.dart';
import '../singletons/media.dart';
import '../singletons/settings.dart';
import '../singletons/sonic_path_state.dart';
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

  // An .m3u is a text file listing other files. Queued as audio it
  // stalls the player on a payload it cannot decode; the server will
  // read it for us and hand back the tracks it names.
  if (browserList[index].type == 'file' && isM3u(browserList[index].data)) {
    ApiManager().getM3uContents(browserList[index].data ?? '',
        useThisServer: browserList[index].server);
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
      // The feature cards: screens of their own rather than browser frames,
      // so the browser stays where it is behind them.
      case 'autoDj':
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AutoDJScreen()));
        return;
      case 'sonicPath':
        if (server != null) SonicPathState().beginSetup(server);
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SonicPathScreen()));
        return;
      case 'torrents':
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => AddTorrentScreen()));
        return;
      case 'federation':
        if (server != null) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => FederationScreen(parent: server)));
        }
        return;
      case 'p2pNetwork':
        if (server != null) {
          Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => P2pScreen(server: server)));
        }
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
      _playFromHereGuarded(browserList, index);
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
      _playFromHereGuarded(browserList, index);
    } else {
      enqueueLocalFile(browserList[index]);
    }
    return;
  }
}

/// True when the current frame is an ORDERED collection — a file-explorer
/// folder or a playlist — rather than an aggregate the server assembled
/// (search results, Rated, Recently added).
///
/// The two frame markers are the same ones the subheader and toolbar read,
/// so this can't drift out of step with what the user sees named above the
/// list. Album detail never reaches here: it has its own row-tap path.
bool get _isOrderedCollection =>
    BrowserManager().currentPath != null ||
    BrowserManager().currentPlaylist != null;

/// Play-from-here fills the queue with the list you're looking at, which is
/// what you want inside an album, playlist or folder. On an aggregate it is
/// not: tapping one search hit would queue every other hit, and Rated is
/// unbounded. Spotify and Apple Music both play just the tapped song from a
/// search result, so aggregates get a single-item queue.
Future<void> _playFromHereGuarded(
        List<DisplayItem> browserList, int tappedIndex) =>
    _isOrderedCollection
        ? playFromHere(browserList, tappedIndex)
        : playFromHere([browserList[tappedIndex]], 0);

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
