import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/singletons/file_explorer.dart';
import '../l10n/app_localizations.dart';
import '../l10n/enum_labels.dart';
import '../singletons/browser_list.dart';
import '../singletons/api.dart';
import '../singletons/settings.dart';
import '../objects/discovery_plugins.dart';
import '../objects/display_item.dart';
import '../objects/server.dart';
import '../theme/velvet_theme.dart';
import '../util/browse_keep_leads.dart';
import '../util/discover_badges.dart' show CopyMarker;
import '../util/head_ellipsis.dart';
import '../widgets/album_grid.dart';
import '../widgets/browse_keep_entry.dart';
import '../widgets/browse_keep_pill.dart' show KeepPageAction;
import '../widgets/browse_page_header.dart';
import '../widgets/letter_strip.dart';
import '../widgets/player_panel.dart';
import '../widgets/playlist_name_dialog.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../widgets/track_actions_sheet.dart';

import '../singletons/media.dart';
import '../singletons/track_capture.dart';
import '../util/media_format.dart';
import '../util/queue_actions.dart';
import '../util/image_cache.dart';
import '../util/server_version.dart';

import '../singletons/sonic_path_state.dart';
import 'federation/federation_screen.dart';
import 'p2p/p2p_screen.dart';
import 'add_server.dart';
import 'add_torrent_screen.dart';
import 'auto_dj.dart';
import 'discovery/browse_copy_marks.dart';
import 'discovery/copies_hub.dart';
import 'discovery/copies_sheet.dart';
import 'discovery/discovery_copy_marks.dart';
import 'discovery/discovery_listing.dart';
import 'discovery/discovery_page_controller.dart';
import 'discovery/discovery_widgets.dart';
import 'discovery/keep_copy_ui.dart';
import 'discovery/keep_toast.dart';
import 'discovery/peer_sheets.dart';
import 'sonic_path_screen.dart';

class Browser extends StatefulWidget {
  const Browser({super.key});

  @override
  State<Browser> createState() => _BrowserState();
}

/// What kind of list a connected server's frame is, for Keep a copy.
enum _PeerKind { explorer, m3u, albums, artist, recent, search, other }

/// A connected server's frame while it is the browser's top one: Keep a
/// copy's gate as the page first built with it (snapshotted once, read again
/// only when a Keep sheet closes on it — no way in appears or vanishes under
/// the thumb), its copy marks (an explorer folder, an albums list, an
/// artist's page), and the header's node focus falls back to.
class _PeerPage {
  final List<DisplayItem> frame;
  final Server peer;
  final _PeerKind kind;
  final ArtistContext? artist;
  final FolderContext? folder;
  KeepGateSnapshot gate;
  BrowseCopyMarks? marks;
  final FocusNode header = FocusNode(debugLabel: 'browse page header');

  /// The page header's box (an explorer folder's), for the letter strip's
  /// jump and the scroll's anchoring.
  final GlobalKey headerKey = GlobalKey();

  /// The folder rows last drawn with a mark (their extents grew).
  Set<String> drawnMarks = const {};

  _PeerPage({
    required this.frame,
    required this.peer,
    required this.kind,
    required this.gate,
    this.artist,
    this.folder,
  });

  String get peerName => peer.federationPeerName ?? peer.displayName;

  void dispose() {
    marks?.dispose();
    header.dispose();
  }
}

class _BrowserState extends State<Browser> {
  // ── a connected server's page: Keep a copy ──
  _PeerPage? _peerPage;
  StreamSubscription<DisplayItem?>? _albumSub;

  @override
  void initState() {
    super.initState();
    // A page the album detail covers is not in front: its marks rest.
    _albumSub = BrowserManager().albumDetailStream.listen((a) {
      _peerPage?.marks?.front = a == null;
    });
  }

  @override
  void dispose() {
    _albumSub?.cancel();
    _peerPage?.dispose();
    _peerPage = null;
    super.dispose();
  }

  /// The top frame's Keep a copy page: made when a connected server's
  /// frame comes to the top — keyed on its rows' server, never the current
  /// one, so a connected server's page on the user's own stack (Discover's
  /// Open artist) has its ways in too — and let go when another does (once
  /// this build has swapped its header out: its focus node is still the
  /// old header's until then).
  _PeerPage? _syncPage() {
    final bm = BrowserManager();
    final frame = bm.browserCache.isEmpty ? null : bm.browserCache.last;
    final have = _peerPage;
    if (have != null && identical(have.frame, frame)) return have;
    if (have != null) {
      have.marks?.removeListener(_onMarks);
      WidgetsBinding.instance.addPostFrameCallback((_) => have.dispose());
    }
    _peerPage = null;
    if (frame == null || BrowserManager.isHomeList(frame)) return null;
    final artist = bm.currentArtist;
    final path = bm.currentPath;
    final folder = path != null && !isM3u(path) ? bm.currentFolder : null;
    final peer = artist?.server ??
        folder?.server ??
        (frame.isNotEmpty ? frame.first.server : null);
    if (!isKeepPeer(peer)) return null;
    final _PeerKind kind;
    if (artist != null) {
      kind = _PeerKind.artist;
    } else if (path != null) {
      kind = isM3u(path) ? _PeerKind.m3u : _PeerKind.explorer;
    } else if (bm.currentSearchTerm != null) {
      kind = _PeerKind.search;
    } else if (bm.listName == 'Recent' && bm.currentArtist == null) {
      kind = _PeerKind.recent;
    } else if (frame.isNotEmpty && frame.every((e) => e.type == 'album')) {
      kind = _PeerKind.albums;
    } else {
      kind = _PeerKind.other;
    }
    final page = _PeerPage(
      frame: frame,
      peer: peer!,
      kind: kind,
      gate: CopiesHub().gateFor(peer),
      artist: artist,
      folder: folder,
    );
    final marked = kind == _PeerKind.explorer ||
        kind == _PeerKind.albums ||
        kind == _PeerKind.artist;
    if (marked && page.gate.marks) {
      page.marks = BrowseCopyMarks(jobs: CopiesHub().jobsFor(peer), peer: peer)
        ..front = bm.albumDetail == null
        ..addListener(_onMarks);
    }
    _peerPage = page;
    WidgetsBinding.instance.addPostFrameCallback((_) => _firstShown(page));
    return page;
  }

  /// A page's first frame: the page's own recommendation asked (the
  /// artist's, the open folder's — the rows ask theirs as they are laid
  /// out), and the one-time hint where long-press keeps a song.
  void _firstShown(_PeerPage page) {
    if (!mounted || !identical(page, _peerPage)) return;
    final marks = page.marks;
    if (marks != null) {
      final artist = page.artist;
      final artistRec = artist == null ? null : artistLeadOf(artist);
      final folderRec = page.folder?.ref?.rec(page.peer);
      marks.ask([
        ?artistRec,
        if (page.kind == _PeerKind.explorer) ?folderRec,
      ]);
    }
    _maybeHint(page);
  }

  /// The first time (per install) a connected server's song list shows with
  /// Keep a copy open for songs — an explorer folder with a song in it,
  /// Recent, search results with a song hit — a toast says long-press keeps
  /// one. Never while a screen reader navigates: its rows' actions say it.
  void _maybeHint(_PeerPage page) {
    final settings = SettingsManager();
    if (settings.keepBrowseHintShown || !page.gate.allows(kScopeSong)) return;
    if (page.kind != _PeerKind.explorer &&
        page.kind != _PeerKind.recent &&
        page.kind != _PeerKind.search) {
      return;
    }
    final song =
        page.frame.any((e) => e.type == 'file' && e.data != null && !isM3u(e.data));
    if (!song) return;
    if (MediaQuery.maybeOf(context)?.accessibleNavigation ?? false) return;
    KeepToast.show(context, AppLocalizations.of(context).browseKeepHoldHint);
    unawaited(settings.markKeepBrowseHintShown());
  }

  /// The page's marks changed: an explorer folder's marked rows are
  /// counted again (their extents, read on every layout and every letter
  /// jump, come from that set), and the row under the thumb stays where it
  /// is while rows above it grow a mark.
  void _onMarks() {
    if (!mounted) return;
    final page = _peerPage;
    if (page != null && page.kind == _PeerKind.explorer) {
      final now = _markedRows(page, BrowserManager().browserList);
      _anchorScroll(page, now);
      page.drawnMarks = now;
    }
    setState(() {});
  }

  /// The folder rows with a mark now.
  Set<String> _markedRows(_PeerPage page, List<DisplayItem> rows) {
    final marks = page.marks;
    if (marks == null) return const {};
    return {
      for (final r in rows)
        if (r.type == 'directory' && _folderMark(page, r) != null) r.data!,
    };
  }

  // Rows above the first one on screen grew (or lost) a mark after the
  // first paint: the scroll moves by what they changed, in the same frame,
  // so the row under the thumb stays put.
  void _anchorScroll(_PeerPage page, Set<String> now) {
    final sc = BrowserManager().sc;
    if (!sc.hasClients || BrowserManager().search.open) return;
    final rows = BrowserManager().browserList;
    final before = page.drawnMarks;
    if (now.length == before.length && now.containsAll(before)) return;
    final ts = MediaQuery.textScalerOf(context);
    final headerBox =
        page.headerKey.currentContext?.findRenderObject() as RenderBox?;
    var pos = headerBox?.hasSize == true ? headerBox!.size.height : 0.0;
    final offset = sc.offset;
    var delta = 0.0;
    for (final r in rows) {
      final was = _rowExtent(r, ts, marked: before.contains(r.data));
      if (pos + was > offset) break;
      delta += _rowExtent(r, ts, marked: now.contains(r.data)) - was;
      pos += was;
    }
    if (delta != 0) sc.jumpTo(offset + delta);
  }

  /// A Keep sheet closed on [page]: its gate is read again (it applies from
  /// this build).
  void _afterKeep(_PeerPage page) {
    if (!mounted) return;
    page.gate = CopiesHub().gateFor(page.peer);
    setState(() {});
  }

  /// Open [req]'s Keep sheet from [page] with its marks ([rec]: the page's
  /// own mark of the opener, a card's); focus comes back to its opener,
  /// else the page's header — on a page with none, its list.
  void _openKeep(BuildContext c, _PeerPage page, BrowseKeepRequest req,
      {Map<String, dynamic>? rec, FocusNode? from}) {
    unawaited(BrowseKeepEntry.open(c, req,
        marks: page.marks,
        markRec: rec,
        from: from,
        fallback: page.header,
        closed: () => _afterKeep(page)));
  }

  /// [item]'s page when it is the top frame's connected server's.
  _PeerPage? _pageOf(DisplayItem item) {
    final page = _peerPage;
    if (page == null || !identical(item.server, page.peer)) return null;
    return page;
  }

  /// A folder row's copy mark (its folder copies only).
  CopyMarker? _folderMark(_PeerPage page, DisplayItem item) {
    final marks = page.marks;
    final ref = FolderRef.of(item.data);
    if (marks == null || ref == null) return null;
    return marks.folderMarker(ref.rec(page.peer));
  }

  // Item types whose tap loads a new list (vs. file/localFile, which
  // just enqueue and leave the current list in place). Tapping any of
  // these closes local search.
  static const Set<String> _navTypes = {
    'addServer',
    'directory',
    'playlist',
    'execAction',
    'artist',
    'album',
    'localDirectory',
  };

  void handleTap(
      List<DisplayItem> browserList, int index, BuildContext context) {
    // A browse fetch is already in flight — ignore taps until it resolves (or
    // is cancelled with Back). Without this, tapping a second folder before the
    // first finished kicked off a racing request and the screen showed whichever
    // returned last. addServer stays actionable (the no-server screen never has
    // a load in flight, but never lock the user out of adding a server).
    if (BrowserManager().isLoading &&
        browserList[index].type != 'addServer') {
      return;
    }

    if (_navTypes.contains(browserList[index].type)) {
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
    if (browserList[index].type == 'file' &&
        isM3u(browserList[index].data)) {
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

    if (browserList[index].type == 'execAction' &&
        browserList[index].data == 'playlists') {
      ApiManager().getPlaylists(useThisServer: browserList[index].server);
      return;
    }

    if (browserList[index].type == 'execAction' &&
        browserList[index].data == 'fileExplorer') {
      ApiManager().getFileList("~", useThisServer: browserList[index].server);
      return;
    }

    if (browserList[index].type == 'execAction' &&
        browserList[index].data == 'recent') {
      ApiManager().getRecentlyAdded(useThisServer: browserList[index].server);
      return;
    }

    if (browserList[index].type == 'execAction' &&
        browserList[index].data == 'rated') {
      ApiManager().getRated(useThisServer: browserList[index].server);
      return;
    }

    if (browserList[index].type == 'execAction' &&
        browserList[index].data == 'albums') {
      ApiManager().getAlbums(useThisServer: browserList[index].server);
      return;
    }

    if (browserList[index].type == 'execAction' &&
        browserList[index].data == 'localFiles') {
      FileExplorer().getPathForServer(browserList[index].server!);
      return;
    }

    if (browserList[index].type == 'execAction' &&
        browserList[index].data == 'artists') {
      ApiManager().getArtists(useThisServer: browserList[index].server);
      return;
    }

    // Discover is a browser listing like Albums: a frame on this stack that
    // fills itself in as the server answers (discovery_listing.dart), so it
    // draws with the browser's own rows and Back returns to the home.
    if (browserList[index].type == 'execAction' &&
        browserList[index].data == 'discover') {
      final s = browserList[index].server;
      if (s != null) DiscoveryListing().open(s);
      return;
    }

    // The feature cards: screens of their own rather than browser frames, so
    // the browser stays where it is behind them.
    if (browserList[index].type == 'execAction' &&
        browserList[index].data == 'autoDj') {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const AutoDJScreen()));
      return;
    }
    if (browserList[index].type == 'execAction' &&
        browserList[index].data == 'sonicPath') {
      final s = browserList[index].server;
      if (s != null) SonicPathState().beginSetup(s);
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const SonicPathScreen()));
      return;
    }
    if (browserList[index].type == 'execAction' &&
        browserList[index].data == 'torrents') {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => AddTorrentScreen()));
      return;
    }
    // Copies: what the server is copying for you (Discover's Keep a copy),
    // a sheet over the home.
    if (browserList[index].type == 'execAction' &&
        browserList[index].data == 'copies') {
      final s = browserList[index].server;
      if (s != null) {
        // A connected server's home shows the copies on the user's own
        // server (jobsFor is the parent's); its empty state offers no
        // "Open Discover", which is the user's own server's.
        unawaited(showCopiesSheet(context, CopiesHub().jobsFor(s),
            fromHome: !s.isFederated));
      }
      return;
    }
    if ((browserList[index].type == 'execAction' ||
            browserList[index].type == 'banner') &&
        browserList[index].data == 'federation') {
      final s = browserList[index].server;
      if (s != null) {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => FederationScreen(parent: s)));
      }
      return;
    }
    if (browserList[index].type == 'execAction' &&
        browserList[index].data == 'p2pNetwork') {
      final s = browserList[index].server;
      if (s != null) {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => P2pScreen(server: s)));
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
        _playFromHere(browserList, index);
      } else {
        addFile(browserList[index]);
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
        _playFromHere(browserList, index);
      } else {
        addLocalFile(browserList[index]);
      }
      return;
    }
  }

  /// True when an armed TrackCapture consumed the tap: a captured pick
  /// returns to whichever screen armed it (its state already holds the song),
  /// a rejected one toasts and stays armed.
  bool _captureTap(DisplayItem item, BuildContext context) {
    // Read before tryCapture — a capture clears the pending request.
    final route = TrackCapture.pending?.returnScreen;
    switch (TrackCapture.tryCapture(item)) {
      case CaptureResult.captured:
        if (route != null) {
          Navigator.push(context, MaterialPageRoute(builder: route));
        }
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
  Future<void> addLocalFile(DisplayItem i) async {
    await _enqueue(buildLocalFileMediaItem(i));
  }

  Future<void> addFile(DisplayItem i) async {
    final item = await buildServerFileMediaItem(i);
    if (item != null) await _enqueue(item);
  }

  // Adds the item to the queue, then dispatches on the user's tap
  // behavior preference. Pattern A (playFromHere) doesn't reach here
  // — it's handled directly in handleTap because it needs the
  // surrounding browser context to know what to fill the queue with.
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
        // Unreachable — see handleTap.
        break;
    }
  }

  // Pattern A: clear the queue, fill it with every playable item from the
  // current browser view (in order), jump to the tapped one, play. Delegates to
  // the shared helper (util/queue_actions.dart) so the album-detail screen plays
  // albums with identical semantics.
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
  Future<void> _playFromHere(List<DisplayItem> browserList, int tappedIndex) =>
      _isOrderedCollection
          ? playFromHere(browserList, tappedIndex)
          : playFromHere([browserList[tappedIndex]], 0);

  Widget makeListItem(List<DisplayItem> b, int i, BuildContext c) {
    switch (b[i].type) {
      case "album":
        {
          return makeAlbumWidget(b, i, c);
        }
      case "file":
        {
          return makeFileWidget(b, i, c);
        }
      case "playlist":
        {
          return makePlaylistWidget(b, i, c);
        }
      case "directory":
        {
          return makeFolderWidget(b, i, c);
        }
      case "localDirectory":
        {
          return makeLocalFolderWidget(b, i, c);
        }
      case "localFile":
        {
          return makeLocalFileWidget(b, i, c);
        }
      default:
        {
          return makeBasicWidget(b, i, c);
        }
    }
  }

  // Per-row extent for the browser list, shared by the ListView's
  // itemExtentBuilder AND the letter-strip jump math so a jump lands exactly on
  // the target row — no estimation, no multi-frame settle on long lists.
  // 1-line rows (directories / artists) vs 2-line (albums / files with
  // metadata), mirroring getText/getSubText. max(base, scaled) tracks the text
  // scaler upward so larger accessibility text never clips, while staying at the
  // tuned base at the default (and smaller) text scales. A folder row a copy
  // marks ([marked], "copying 2 of 3") has its second line too.
  static double _rowExtent(DisplayItem it, TextScaler ts,
      {bool marked = false}) {
    final base = (it.metadata?.artist != null || it.subtext != null || marked)
        ? 74.0
        : 58.0;
    final scaled = ts.scale(base);
    return scaled > base ? scaled : base;
  }

  /// [it]'s extent on the page now: a folder row's mark counted (the set
  /// the page's marks last drew — no lookup per row on a long list's jump).
  double _extentOf(DisplayItem it, TextScaler ts) {
    final page = _peerPage;
    final marked = page != null &&
        it.type == 'directory' &&
        page.drawnMarks.contains(it.data);
    return _rowExtent(it, ts, marked: marked);
  }

  /// A browse row's screen-reader actions (its long-press is its only
  /// handle, by design — the letter strip lands where a trailing control
  /// would): [more] the menu a long-press opens, and Keep a copy straight
  /// to its sheet when the row's server is a connected one with the gate
  /// open for it ([keep]).
  Map<CustomSemanticsAction, VoidCallback> _rowActions({
    String? moreLabel,
    VoidCallback? more,
    String? keepLabel,
    VoidCallback? keep,
  }) =>
      {
        if (moreLabel != null && more != null)
          CustomSemanticsAction(label: moreLabel): more,
        if (keepLabel != null && keep != null)
          CustomSemanticsAction(label: keepLabel): keep,
      };

  Widget makePlaylistWidget(List<DisplayItem> b, int i, BuildContext c) {
    final l = AppLocalizations.of(c);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => handleTap(b, i, c),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(color: VelvetColors.border, width: 0.5)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: VelvetColors.raised,
                  borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
                ),
                child: Icon(Icons.queue_music, color: VelvetColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  b[i].name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: VelvetColors.textPrimary,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: VelvetColors.textSecondary),
                color: VelvetColors.surface,
                tooltip: l.mainMore,
                onSelected: (v) {
                  if (v == 'rename') _renamePlaylist(c, b[i]);
                  if (v == 'delete') _deletePlaylist(c, b[i]);
                },
                itemBuilder: (_) => [
                  // Rename is 5.16.0; delete predates the support floor. On an
                  // older server the rename call 404s and surfaces as a
                  // generic playlist error, so drop the item instead of
                  // offering an action that cannot work.
                  if (!playlistRenameKnownUnsupported(
                      ServerVersion.tryParse(b[i].server?.serverVersion)))
                    PopupMenuItem(value: 'rename', child: Text(l.rename)),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(l.delete,
                        style: TextStyle(color: VelvetColors.error)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Server playlists view: New-playlist button + the playlist rows ──
  Widget _playlistsView(BuildContext context, List<DisplayItem> playlists) {
    final l = AppLocalizations.of(context);
    return Container(
      color: VelvetColors.bg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _createPlaylist(context),
                icon: const Icon(Icons.add, size: 20),
                label: Text(l.playlistsNew),
                style: OutlinedButton.styleFrom(
                  foregroundColor: VelvetColors.primary,
                  side: BorderSide(
                      color: VelvetColors.primary.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(VelvetColors.radiusSmall)),
                ),
              ),
            ),
          ),
          Expanded(
            child: playlists.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l.playlistsEmptyTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: VelvetColors.textSecondary, fontSize: 14),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: BrowserManager().sc,
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: playlists.length,
                    itemBuilder: (context, i) =>
                        makePlaylistWidget(playlists, i, context),
                  ),
          ),
        ],
      ),
    );
  }

  // Name-entry dialog shared by create + rename. Returns the trimmed name, or
  // null if cancelled. The controller lives inside PlaylistNameDialog (a
  // StatefulWidget) so it's disposed safely after the dialog closes.
  Future<String?> _playlistNameDialog(BuildContext context,
      {required String title, required String action, String? initial}) {
    return PlaylistNameDialog.show(context,
        title: title, action: action, initial: initial);
  }

  Future<void> _createPlaylist(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final name = await _playlistNameDialog(context,
        title: l.playlistsNew, action: l.create);
    if (name == null || name.isEmpty) return;
    try {
      await ApiManager().createPlaylist(name);
    } catch (_) {
      if (context.mounted) _playlistError(context);
    }
  }

  Future<void> _renamePlaylist(BuildContext context, DisplayItem item) async {
    final l = AppLocalizations.of(context);
    final name = await _playlistNameDialog(context,
        title: l.playlistsRename, action: l.rename, initial: item.name);
    if (name == null || name.isEmpty || name == item.name) return;
    try {
      await ApiManager().renamePlaylist(item.name, name);
    } catch (_) {
      if (context.mounted) _playlistError(context);
    }
  }

  void _deletePlaylist(BuildContext context, DisplayItem item) {
    final l = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VelvetColors.surface,
        title: Text(l.browserConfirmDeletePlaylist),
        content:
            Text(item.name, style: TextStyle(color: VelvetColors.textPrimary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.cancel,
                style: TextStyle(color: VelvetColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              ApiManager()
                  .removePlaylist(item.data!, useThisServer: item.server);
              Navigator.of(ctx).pop();
            },
            child: Text(l.delete, style: TextStyle(color: VelvetColors.error)),
          ),
        ],
      ),
    );
  }

  // Floating so it clears the docked mini-player overlay (a plain bottom
  // snackbar renders behind it).
  void _playlistError(BuildContext context) {
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l.playlistActionFailed),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: PlayerPanel.kCollapsedHeight +
            MediaQuery.of(context).viewPadding.bottom +
            8,
      ),
    ));
  }

  Widget makeLocalFolderWidget(List<DisplayItem> b, int i, BuildContext c) {
    final l = AppLocalizations.of(c);
    // Same rationale as makeFolderWidget — wrap long names below the
    // letter-strip threshold.
    final allowWrap = !LetterStrip.showsFor(b);
    return Container(
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: VelvetColors.border))),
        child: Slidable(
            endActionPane: ActionPane(
              motion: DrawerMotion(),
              children: [
                SlidableAction(
                    backgroundColor: Colors.red,
                    icon: Icons.delete,
                    label: l.delete,
                    onPressed: (context) {
                      showDialog(
                          context: c,
                          builder: (BuildContext context) {
                            return AlertDialog(
                                title: Text(l.browserConfirmDeleteFolder),
                                content: b[i].getText(),
                                actions: <Widget>[
                                  TextButton(
                                    child: Text(l.goBack),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                  TextButton(
                                      child: Text(
                                        l.delete,
                                        style: TextStyle(color: Colors.red),
                                      ),
                                      onPressed: () {
                                        FileExplorer().deleteDirectory(
                                            b[i].data!, b[i].server);
                                        Navigator.of(context).pop();
                                      })
                                ]);
                          });
                    })
              ],
            ),
            child: Builder(
              builder: (context) => ListTile(
                  leading: b[i].icon,
                  title: b[i].getText(truncate: !allowWrap),
                  subtitle: b[i].getSubText(),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.keyboard_arrow_left,
                      size: 20.0,
                      color: VelvetColors.textTertiary,
                    ),
                    onPressed: () {
                      Slidable.of(context)?.openEndActionPane();
                    },
                  ),
                  onTap: () {
                    handleTap(b, i, c);
                  }),
            )));
  }

  Widget makeLocalFileWidget(List<DisplayItem> b, int i, BuildContext c) {
    final l = AppLocalizations.of(c);
    final allowWrap = !LetterStrip.showsFor(b);
    return Container(
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: VelvetColors.border))),
        child: Slidable(
            endActionPane: ActionPane(
              motion: DrawerMotion(),
              children: [
                SlidableAction(
                    backgroundColor: Colors.red,
                    icon: Icons.delete,
                    label: l.delete,
                    onPressed: (context) {
                      FileExplorer().deleteFile(b[i].data!, b[i].server);
                    })
              ],
            ),
            child: Builder(
              builder: (context) => ListTile(
                  leading: b[i].icon,
                  title: b[i].getText(truncate: !allowWrap),
                  subtitle: b[i].getSubText(),
                  // Same overflow a server track row carries, so the queue
                  // actions sit in the same place whichever kind of track
                  // you're looking at. Delete stays on the swipe.
                  trailing: IconButton(
                    icon: Icon(Icons.more_vert,
                        size: 20, color: VelvetColors.textSecondary),
                    tooltip: l.browserMoreActions,
                    onPressed: () => _showTrackActions(b[i], c),
                  ),
                  // Same long-press context sheet as server rows — the queue
                  // actions apply to local files too (Find similar hides
                  // itself: a local path can't seed the similarity index).
                  onLongPress: () => _showTrackActions(b[i], c),
                  onTap: () {
                    handleTap(b, i, c);
                  }),
            )));
  }

  Widget makeFolderWidget(List<DisplayItem> b, int i, BuildContext c) {
    final l = AppLocalizations.of(c);
    // Below the letter-strip threshold there's no strip math to keep
    // uniform — let long folder names wrap and show in full. Smaller
    // folders tend to have longer / more descriptive names.
    final allowWrap = !LetterStrip.showsFor(b);
    // A connected server's folder below its library's root: a copy of it
    // marks its subtitle ("copying 2 of 3", "in your collection" — folder
    // copies only), and a screen reader gets Keep a copy beside the menu.
    final page = _pageOf(b[i]);
    final ref = page == null ? null : FolderRef.of(b[i].data);
    final rec = ref?.rec(page!.peer);
    if (rec != null) page!.marks?.askSoon([rec]);
    final mark = page == null ? null : _folderMark(page, b[i]);
    final keep = ref != null && page!.gate.allows(kScopeFolder)
        ? BrowseKeepRequest.ofFolder(ref, page.peer, variant: KeepVariant.menu)
        : null;
    return Semantics(
      customSemanticsActions: _rowActions(
        moreLabel: l.browserMoreForFolder(b[i].name),
        more: () => _showFolderActions(b[i], c),
        keepLabel: keep == null ? null : l.browseKeepOfFolder(b[i].name),
        keep: keep == null ? null : () => _openKeep(c, page!, keep),
      ),
      child: Container(
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: VelvetColors.border))),
        child: Slidable(
            endActionPane: ActionPane(
              motion: DrawerMotion(),
              children: [
                SlidableAction(
                    backgroundColor: Colors.blueGrey,
                    icon: Icons.add_to_queue,
                    label: l.addAll,
                    onPressed: (context) {
                      ApiManager().getRecursiveFiles(b[i].data!,
                          useThisServer: b[i].server!);
                    })
              ],
            ),
            child: Builder(
              builder: (context) => KeepFocusAnchor(
                focusKey: keep?.focusKey,
                builder: (context, node) => ListTile(
                    focusNode: node,
                    // Long-press = this row's actions, the same convention the
                    // track rows use. The swipe pane has carried Add all for a
                    // while, but a swipe is only found by accident.
                    onLongPress: () => _showFolderActions(b[i], c),
                    leading: b[i].icon,
                    title: b[i].getText(truncate: !allowWrap),
                    subtitle: mark != null
                        ? DiscoveryRowMarkerLine(marker: mark, counts: true)
                        : b[i].getSubText(),
                    // No caret: it opened the swipe pane, whose only action is
                    // the Add all the long-press above now offers — two handles
                    // on one action, the second sitting under the letter strip.
                    // The swipe itself still works. makeLocalFolderWidget keeps
                    // its caret: that pane is Delete, and nothing else reaches
                    // it.
                    onTap: () {
                      handleTap(b, i, c);
                    }),
              ),
            ))));
  }

  // Album list rows. Unlike makeBasicWidget, the leading is a FIXED-size
  // thumbnail (cover art or a same-size placeholder) so the title/subtitle
  // start at the same x whether or not a row has art — getImage() returns a
  // full-height image for art rows but a tiny Icon for the rest, which
  // misaligns the text.
  Widget makeAlbumWidget(List<DisplayItem> b, int i, BuildContext c) {
    final l = AppLocalizations.of(c);
    // A connected server's album on Discover (the album grid off): the
    // long-press opens its album sheet, and a copy's marker leads its line.
    final page = DiscoveryListing().controller;
    final leads = discoveryCardLeads(b[i]);
    final peerCard = page != null && leads.isNotEmpty;
    final marker =
        peerCard ? page.jobs.cardMarker(leads, album: b[i].name) : null;
    // While browsing a connected server: its copy's badge, glyph only, on
    // the thumb, and a long-press (or a screen reader's action) for Keep a
    // copy — the card's way in, in list form.
    final browse = peerCard ? null : _pageOf(b[i]);
    final marked = browse != null && _cardsMarked(browse);
    final rec = !marked || browse.marks == null ? null : albumLeadOf(b[i]);
    if (rec != null) browse!.marks!.askSoon([rec]);
    final badge =
        rec == null ? null : browse!.marks!.cardMarker(rec, album: b[i].name);
    final keep = browse == null ? null : _cardKeep(browse, b[i]);
    final thumb = b[i].getAlbumThumb();
    // The badge is drawn only (a glyph): the row's node says its word, the
    // row's own texts left out of it so nothing is read twice.
    final sub = b[i].getSubText(l: l);
    final said = badge == null
        ? null
        : [
            b[i].name,
            if (b[i].subtext?.isNotEmpty == true) b[i].subtext!,
            keepMarkerWord(l, badge, card: true),
          ].join(', ');
    return Semantics(
      container: said != null,
      label: said,
      customSemanticsActions: _rowActions(
        keepLabel: keep == null ? null : l.browseKeepOfItem(b[i].name),
        keep: keep == null ? null : () => _openKeep(c, browse!, keep, rec: rec),
      ),
      child: Container(
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: VelvetColors.border))),
        child: KeepFocusAnchor(
          focusKey: keep?.focusKey,
          builder: (context, node) => ListTile(
              focusNode: node,
              leading: badge == null
                  ? thumb
                  : Stack(
                      children: [
                        thumb,
                        Positioned(
                          left: 2,
                          bottom: 2,
                          child:
                              DiscoveryCardBadge(marker: badge, glyphOnly: true),
                        ),
                      ],
                    ),
              title: said == null
                  ? b[i].getText(l: l)
                  : ExcludeSemantics(child: b[i].getText(l: l)),
              subtitle: marker != null
                  ? DiscoveryRowMarkerLine(
                      marker: marker, rest: b[i].subtext, counts: true)
                  : (said == null || sub == null
                      ? sub
                      : ExcludeSemantics(child: sub)),
              onLongPress: peerCard
                  ? () => showPeerAlbumSheet(c, b[i], page)
                  : (keep == null
                      ? null
                      : () => _openKeep(c, browse!, keep, rec: rec)),
              onTap: () {
                handleTap(b, i, c);
              }),
        ),
      ),
    );
  }

  /// The Keep a copy an album card or row of a connected server's Albums
  /// list or artist page offers: its album, when the gate is open for
  /// albums and the card knows its credit (never for the singles bucket or
  /// credits that disagree). Never a search's Album hit — open it — even
  /// once its album page resolved the credit onto the same item.
  BrowseKeepRequest? _cardKeep(_PeerPage page, DisplayItem item) {
    if (!_cardsMarked(page) || !page.gate.allows(kScopeAlbum)) return null;
    return BrowseKeepRequest.album(item, variant: KeepVariant.item);
  }

  /// The pages whose album cards and rows carry Keep a copy and a copy's
  /// badge: the Albums list and an artist's page.
  static bool _cardsMarked(_PeerPage page) =>
      page.kind == _PeerKind.albums || page.kind == _PeerKind.artist;

  /// A connected server's artist page's header: whose page it is, its
  /// albums there, and Keep a copy of the artist's own albums.
  Widget? _artistHeader(BuildContext c, _PeerPage page) {
    final artist = page.artist;
    if (artist == null) return null;
    final rec = artistLeadOf(artist);
    final keep = BrowseKeepRequest.artistPage(artist);
    return KeepFocusAnchor(
      focusKey: keep?.focusKey,
      builder: (context, node) => ArtistPageHeader(
        artist: artist,
        peerName: page.peerName,
        open: keep != null && page.gate.allows(kScopeArtist),
        pick: rec == null ? null : page.marks?.pillJob(rec, kScopeArtist),
        onKeep: () {
          if (keep != null) _openKeep(c, page, keep);
        },
        pillFocus: node,
        headerFocus: page.header,
      ),
    );
  }

  /// The open folder's header (a connected server's folder below its
  /// library's root): with the gate closed, only for an earlier copy of it.
  /// Its counts are this listing's own.
  Widget? _folderHeader(
      BuildContext c, _PeerPage page, List<DisplayItem> rows) {
    final l = AppLocalizations.of(c);
    final ref = page.folder?.ref;
    if (ref == null) return null;
    final rec = ref.rec(page.peer);
    final pick = page.marks?.pillJob(rec, kScopeFolder);
    final open = page.gate.allows(kScopeFolder);
    if (!KeepPageAction.shows(l, open, pick)) return null;
    final keep =
        BrowseKeepRequest.ofFolder(ref, page.peer, variant: KeepVariant.page);
    final folders = rows.where((r) => r.type == 'directory').length;
    final songs =
        rows.where((r) => r.type == 'file' && !isM3u(r.data)).length;
    return KeepFocusAnchor(
      focusKey: keep?.focusKey,
      builder: (context, node) => FolderPageHeader(
        name: ref.name,
        folders: folders,
        songs: songs,
        peerName: page.peerName,
        open: open,
        pick: pick,
        onKeep: () {
          if (keep != null) _openKeep(c, page, keep);
        },
        pillFocus: node,
        headerFocus: page.header,
      ),
    );
  }

  /// A connected server's album card in the grid: Keep a copy's ⋯ and
  /// long-press, its copy's badge (whatever the gate), the badge's word for
  /// a screen reader. The cards a scroll brings in ask their marks.
  AlbumCardExtras? _cardExtras(
      BuildContext c, _PeerPage? page, DisplayItem item) {
    if (page == null || !identical(item.server, page.peer)) return null;
    if (!_cardsMarked(page)) return null;
    final l = AppLocalizations.of(c);
    final rec = page.marks == null ? null : albumLeadOf(item);
    if (rec != null) page.marks!.askSoon([rec]);
    final badge =
        rec == null ? null : page.marks!.cardMarker(rec, album: item.name);
    final keep = _cardKeep(page, item);
    // A long-pressed card gets focus back itself, its ⋯ the ⋯.
    final cardKey = keep == null ? null : '${keep.focusKey}|card';
    return AlbumCardExtras(
      onMore: keep == null ? null : () => _openKeep(c, page, keep, rec: rec),
      onLongPress: keep == null
          ? null
          : () => _openKeep(c, page, keep,
              rec: rec, from: BrowseKeepEntry.anchorOf(cardKey!)),
      moreLabel: keep == null ? null : l.browseKeepOfItem(item.name),
      moreFocusKey: keep?.focusKey,
      cardFocusKey: cardKey,
      coverBadge:
          badge == null ? null : DiscoveryCardBadge(marker: badge, fit: true),
      mark: badge == null ? null : keepMarkerWord(l, badge, card: true),
    );
  }

  Widget makeBasicWidget(List<DisplayItem> b, int i, BuildContext c) {
    final l = AppLocalizations.of(c);
    return Container(
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: VelvetColors.border))),
        child: ListTile(
            leading: b[i].getImage(),
            title: b[i].getText(l: l),
            subtitle: b[i].getSubText(l: l),
            onTap: () {
              handleTap(b, i, c);
            }));
  }

  // ── Default browser landing: section shortcuts as a card grid ──
  //
  // Cards sit on VelvetColors.card, the token the palette has always defined
  // and this screen never used: face and page were both `surface`, so a card
  // was a 1px border around nothing and the grid read flat. On the real
  // surface the border is redundant and gone.
  //
  // Laid out as rows rather than a GridView because an odd item count left
  // the last card stranded beside a hole — the trailing one spans the row
  // instead. IntrinsicHeight pairs each row to its taller card, so a row is
  // as tall as its content needs and no taller: with a fixed aspect ratio the
  // card height fell out of the screen WIDTH, which on a narrow phone (or at
  // a large text scale) squeezed the tile and label into less room than they
  // occupy and overflowed.
  Widget _homeView(BuildContext context, List<DisplayItem> allItems) {
    final rows = <Widget>[];
    // A note (a federated peer's "read-only server") is a full-width banner
    // above the cards, never a card: it has no action and reads as a caption
    // for the sections, not one of them. A 'section' row is a header; the
    // cards that follow it, up to the next header, are its group.
    var group = <DisplayItem>[];
    var first = true;
    void flush() {
      if (group.isEmpty) return;
      final items = group;
      group = [];
      for (var i = 0; i < items.length; i += 2) {
        final pair = items.skip(i).take(2).toList();
        rows.add(Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : _homeCardGap),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = 0; j < pair.length; j++) ...[
                  if (j > 0) SizedBox(width: _homeCardGap),
                  Expanded(child: _homeCard(context, items, i + j)),
                ],
              ],
            ),
          ),
        ));
      }
    }

    for (final it in allItems) {
      if (it.type == 'note') {
        flush();
        rows.add(Padding(
          padding: EdgeInsets.only(bottom: _homeCardGap),
          child: _homeNote(context, it),
        ));
      } else if (it.type == 'banner') {
        flush();
        rows.add(Padding(
          padding: EdgeInsets.only(bottom: _homeCardGap),
          child: _homeBanner(context, allItems, it),
        ));
      } else if (it.type == 'section') {
        flush();
        rows.add(_homeSectionHeader(context, it, first: first));
        first = false;
      } else {
        group.add(it);
      }
    }
    flush();
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      children: rows,
    );
  }

  static const double _homeCardGap = 10;

  /// A group's header — the Auto DJ panel's section style (uppercase, small,
  /// in the accent), so the home reads like the rest of the app's settings
  /// surfaces. The first header sits closer to the top than the rest.
  Widget _homeSectionHeader(BuildContext context, DisplayItem section,
      {required bool first}) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(6, first ? 8 : 18, 6, 8),
      child: Text(
        browserChromeLabel(l, section.name).toUpperCase(),
        style: TextStyle(
          color: VelvetColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _homeNote(BuildContext context, DisplayItem note) {
    final l = AppLocalizations.of(context);
    return Material(
      color: VelvetColors.card,
      borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          if (note.icon != null) ...[
            Icon(note.icon!.icon, color: VelvetColors.textSecondary),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(browserChromeLabel(l, note.name),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: VelvetColors.textPrimary)),
                if (note.subtext != null)
                  Text(browserChromeLabel(l, note.subtext!),
                      style: TextStyle(
                          fontSize: 13, color: VelvetColors.textSecondary)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  /// A tappable strip above the sections — news that wants an action (the
  /// federation inbox), where [_homeNote] is the inert caption.
  Widget _homeBanner(
      BuildContext context, List<DisplayItem> items, DisplayItem it) {
    final l = AppLocalizations.of(context);
    final (title, sub) = homeBannerText(l, it.name, it.subtext);
    return Material(
      color: VelvetColors.primary.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => handleTap(items, items.indexOf(it), context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            if (it.icon != null) ...[
              Icon(it.icon!.icon, color: VelvetColors.primary),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: VelvetColors.textPrimary)),
                  if (sub != null)
                    Text(sub,
                        style: TextStyle(
                            fontSize: 13, color: VelvetColors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: VelvetColors.primary),
          ]),
        ),
      ),
    );
  }

  Widget _homeCard(BuildContext context, List<DisplayItem> items, int i) {
    final l = AppLocalizations.of(context);
    final item = items[i];
    final iconData = item.icon?.icon ?? Icons.chevron_right;
    return Material(
      color: VelvetColors.card,
      borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => handleTap(items, i, context),
        child: Padding(
          // The label sits beside the icon, not under it: with four groups
          // on this screen the vertical axis is the one that runs out, and a
          // row-shaped card is half the height of the stacked one.
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: VelvetColors.primaryDim,
                  borderRadius:
                      BorderRadius.circular(VelvetColors.radiusSmall),
                ),
                child: Icon(iconData, color: VelvetColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      browserChromeLabel(l, item.name),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: VelvetColors.textPrimary,
                      ),
                    ),
                    // A second line only where there is live state to
                    // show: the DJ's on/off, the shared-library count.
                    if (item.data == 'autoDj')
                      StreamBuilder<dynamic>(
                        stream: MediaManager().audioHandler.customState,
                        initialData: MediaManager()
                            .audioHandler
                            .customState
                            .valueOrNull,
                        builder: (context, snap) {
                          // The subject is untyped (audio_service's
                          // customState); the DJ screen reads it the same way.
                          final on = snap.data?.autoDJState != null;
                          return Text(
                              on ? l.browserAutoDjOn : l.browserAutoDjOff,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: on
                                      ? VelvetColors.primary
                                      : VelvetColors.textSecondary));
                        },
                      )
                    else if (item.data == 'copies' && item.server != null)
                      // Live counts only: "Copying 2" / "1 failed".
                      CopiesHomeLines(jobs: CopiesHub().jobsFor(item.server!))
                    else if (item.subtext != null)
                      Text(
                        homeCardSubtext(l, item.subtext!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13, color: VelvetColors.textSecondary),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Long-press sheet for a folder row: the one thing you can do to a folder
  /// without opening it. Same sheet shape as the track one so a long-press
  /// means the same thing everywhere in the browser. A connected server's
  /// folder below its library's root adds "Keep a copy…" under Add All,
  /// with the gate open for folders (a library at `/` never has it).
  void _showFolderActions(DisplayItem item, BuildContext c) {
    final l = AppLocalizations.of(c);
    final page = _pageOf(item);
    final ref = page == null ? null : FolderRef.of(item.data);
    final keep = ref != null && page!.gate.allows(kScopeFolder)
        ? BrowseKeepRequest.ofFolder(ref, page.peer, variant: KeepVariant.menu)
        : null;
    final marks = page?.marks;
    final KeepMenuState state = keep != null && marks != null &&
            marks.knows(keep.lead)
        ? KeepMenuState.known(marks.folderMarker(keep.lead))
        : const KeepMenuState.ask();
    // Scroll-controlled, its rows in a scroll view, as the track sheet's: at
    // large text the two-line Keep row would push it past the screen.
    showModalBottomSheet(
      context: c,
      backgroundColor: VelvetColors.surface,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(c).size.height * kPeerSheetMaxHeight,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            key: const ValueKey('browse-folder-sheet'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                child: Row(children: [
                  Icon(Icons.folder,
                      color: keepTone(VelvetColors.warning), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: VelvetColors.textPrimary),
                    ),
                  ),
                ]),
              ),
              Divider(color: VelvetColors.border, height: 17),
              ListTile(
                leading: Icon(Icons.library_add, color: VelvetColors.primary),
                title: Text(l.addAll,
                    style: TextStyle(color: VelvetColors.textPrimary)),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  // A browsed folder row always carries its server; the
                  // parameter went non-null in the recursive-files hardening.
                  ApiManager().getRecursiveFiles(item.data!,
                      useThisServer: item.server!);
                },
              ),
              if (keep != null)
                KeepMenuRow(
                  label: l.browseKeepOfFolder(item.name),
                  peerName: page!.peerName,
                  state: state,
                  ask: () => KeepMenuState.lookup(
                      CopiesHub().jobsFor(page.peer), keep.lead, kScopeFolder),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    _openKeep(c, page, keep);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // Long-press context sheet for track rows: the album-detail queue actions
  // (Add next / Play now / Add to end) plus Find similar when the track's
  // server supports discovery. Long-press = item context menu is the
  // convention everywhere (Apple Music / Spotify / Symfonium).
  //
  // A connected server's song on Discover gets its own sheet instead: the
  // same listen verbs, its album and artist, Keep a copy, Open elsewhere,
  // Browse that server, and Download to this phone last.
  //
  // A connected server's song while browsing it adds "Keep a copy…" (the gate
  // open for songs): its Keep sheet on that server, with the Folder choice for
  // an explorer file below its library's root.
  void _showTrackActions(DisplayItem item, BuildContext c) {
    final lead = discoveryLeadOf(item);
    final page = DiscoveryListing().controller;
    if (lead != null && page != null) {
      showPeerSongSheet(c, item, lead, page);
      return;
    }
    showTrackActionsSheet(c, item, keep: _fileKeep(item));
  }

  /// A connected server's song row's Keep a copy: the song, and in the file
  /// explorer the folder it sits in (none at a library's root, none with
  /// the gate closed for folders). Null with the gate closed for songs.
  BrowseKeepRequest? _songKeep(DisplayItem item) {
    final page = _pageOf(item);
    if (page == null || !page.gate.allows(kScopeSong)) return null;
    final folder =
        page.kind == _PeerKind.explorer && page.gate.allows(kScopeFolder)
            ? FolderRef.parentOf(item.data)
            : null;
    return BrowseKeepRequest.song(item, folder: folder);
  }

  TrackSheetKeep? _fileKeep(DisplayItem item) {
    final req = _songKeep(item);
    if (req == null) return null;
    final page = _peerPage!;
    return TrackSheetKeep(
      request: req,
      marks: page.marks,
      fallback: page.header,
      closed: () => _afterKeep(page),
    );
  }

  Widget makeFileWidget(List<DisplayItem> b, int i, BuildContext c) {
    final l = AppLocalizations.of(c);
    // Same wrap-on-small-list rule as folders: below the letter-strip
    // threshold there's no uniform-row constraint, so long song names
    // get to show in full.
    final allowWrap = !LetterStrip.showsFor(b);
    final m3u = isM3u(b[i].data);
    final title = b[i].metadata?.title ?? (b[i].data ?? b[i].name).split('/').last;
    final keep = m3u ? null : _songKeep(b[i]);
    // A connected server's row on Discover: what the user's copy of it is
    // doing ("copying…", "in your collection"…) leads its second line, and
    // its strip fills with the copy (primary — a phone download keeps the
    // green).
    final lead = discoveryLeadOf(b[i]);
    final marker = lead == null
        ? null
        : DiscoveryListing().controller?.jobs.markerFor(lead);
    final copyStrip = discoveryRowCopyStrip(marker);
    // A screen reader's handles for what the long-press opens, on the row's
    // own node — the ListTile's, which holds its texts, its tap and its
    // focus (the outer InkWell takes the long-press and never focus: focus
    // coming back to the row is the node a screen reader hears).
    final actions = m3u
        ? const <CustomSemanticsAction, VoidCallback>{}
        : _rowActions(
            moreLabel: l.browserMoreActionsFor(title),
            more: () => _showTrackActions(b[i], c),
            keepLabel: keep == null ? null : l.browseKeepOfItem(title),
            keep: keep == null ? null : () => _openKeep(c, _peerPage!, keep),
          );
    return Container(
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: VelvetColors.border))),
        child: Material(
            color: VelvetColors.bg,
            child: KeepFocusAnchor(
              focusKey: keep?.focusKey,
              builder: (context, node) => InkWell(
                canRequestFocus: false,
                splashColor: VelvetColors.primaryDim,
                // Nothing for an .m3u: the track sheet rates, queues and finds
                // similar music for the row it opens on, and none of that
                // means anything for a playlist file.
                //
                // A no-op rather than null, deliberately. With no long-press
                // recognizer the tap one wins and fires on release however
                // long the press was, so `null` made holding an .m3u OPEN it
                // — measured, not assumed. An empty handler claims the
                // gesture and the press ends where it started: nothing.
                onLongPress: m3u
                    ? () {}
                    : () => _showTrackActions(b[i], c),
                child: Semantics(
                  customSemanticsActions: actions,
                  child: IntrinsicHeight(
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                      SizedBox(
                        width: 4,
                        child: copyStrip ?? RotatedBox(
                          quarterTurns: 3,
                          child: LinearProgressIndicator(
                            // value: displayList[index].downloadProgress/100,
                            // Index against the passed list `b` (the
                            // possibly search-filtered view), not the
                            // manager's unfiltered browserList — otherwise
                            // the bar reads the wrong row while searching.
                            value: b[i].downloadProgress / 100,
                            valueColor: AlwaysStoppedAnimation(
                                VelvetColors.success),
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      ),
                      Expanded(
                          child: ListTile(
                              focusNode: node,
                              leading: b[i].getImage(),
                              title: b[i].getText(truncate: !allowWrap),
                              subtitle: marker != null
                                  ? DiscoveryRowMarkerLine(
                                      marker: marker, rest: b[i].subtext)
                                  : b[i].getSubText(),
                              // No trailing control: it sat exactly where
                              // the letter strip lands, and long-press opens
                              // the same sheet.
                              onTap: () {
                                handleTap(b, i, c);
                              }))
                    ])),
                ),
              ),
            )));
  }

  // ── Discover: the listing DiscoveryListing keeps on the stack ──
  //
  // The browser's own album items and song rows (makeListItem, so taps and
  // long-presses do what they do everywhere), between the pieces only
  // Discover has: the configuration bar first, state cards, section
  // headers, the footers. Albums run as a horizontal strip of the album
  // grid's cards when the album-grid setting is on (the browser's album
  // look), as album rows when it is off. Pull to refresh and the toolbar's
  // New seeds — where other lists have local search, which this frame does
  // not offer — both ask again, and the server answers from a new random
  // batch of seeds.
  // A search still open from another list narrows the songs and albums;
  // the chrome stays.
  Widget _discoveryView(
      BuildContext context, List<DisplayItem> all, String query) {
    final c = DiscoveryListing().controller;
    final items = query.isEmpty
        ? all
        : all
            .where((it) =>
                it.type == kDiscoverBar ||
                ((it.type == 'file' || it.type == 'album') &&
                    it.matchesQuery(query)))
            .toList();
    return StreamBuilder<bool>(
      stream: SettingsManager().albumGridStream,
      initialData: SettingsManager().albumGrid,
      builder: (context, gridSnap) {
        final grid = gridSnap.data ?? true;
        final children = <Widget>[];
        var firstHeader = true;
        for (var i = 0; i < items.length; i++) {
          final it = items[i];
          switch (it.type) {
            case kDiscoverBar:
              if (c != null) {
                children.add(DiscoveryConfigBar(controller: c));
                // What the server is copying for you, under the bar.
                children.add(DiscoveryCopiesStrip(controller: c));
              }
            case kDiscoverState:
              children.add(discoveryStateWidget(context, it, c, grid: grid));
            case kDiscoverFoot:
              if (c != null) {
                children.add(DiscoveryFooter(controller: c, which: it.data!));
              }
            case 'section':
              children.add(
                  _discoverySectionHeader(context, it, first: firstHeader));
              firstHeader = false;
            case 'album' when grid:
              // The run of album items from here is one strip.
              var end = i;
              while (end + 1 < items.length && items[end + 1].type == 'album') {
                end++;
              }
              children.add(_discoveryAlbumStrip(context, items, i, end));
              i = end;
            default:
              children.add(makeListItem(items, i, context));
          }
        }
        // Same row density as the browser's list (see the main ListView).
        return ListTileTheme.merge(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          horizontalTitleGap: 10,
          minLeadingWidth: 32,
          child: RefreshIndicator(
            color: VelvetColors.primary,
            onRefresh: c?.refresh ?? () async {},
            child: ListView(
              controller: BrowserManager().sc,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: children,
            ),
          ),
        );
      },
    );
  }

  /// A Discover header, in the home's section style (small accent caps).
  Widget _discoverySectionHeader(BuildContext context, DisplayItem section,
      {required bool first}) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(14, first ? 14 : 22, 14, 6),
      child: Text(
        discoverySectionLabel(l, section).toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          // The canvas's --ptext on the page: the primary only where it
          // reads at 4.5:1 there (Velvet's violet does not; Light's amber
          // is darkened).
          color: keepInkOnPage(),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  // DiscoveryStripSkeleton holds a strip's place at the same size.
  static const double _stripCardWidth = kDiscoverStripCardWidth;

  /// Album items [from]..[to] of [items] as one horizontal strip of the
  /// album grid's cards; a tap goes through handleTap, as a grid card's
  /// does.
  Widget _discoveryAlbumStrip(
      BuildContext context, List<DisplayItem> items, int from, int to) {
    final cacheW = artCacheSize(_stripCardWidth);
    return SizedBox(
      height: kDiscoverStripHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: to - from + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AlbumGrid.spacing),
        itemBuilder: (context, k) {
          final item = items[from + k];
          // A connected server's card: its copy's badge in the cover, and
          // a long-press or its ⋯ for the album sheet. The tap still opens
          // the album.
          final page = DiscoveryListing().controller;
          final leads = discoveryCardLeads(item);
          final peerCard = page != null && leads.isNotEmpty;
          final marker =
              peerCard ? page.jobs.cardMarker(leads, album: item.name) : null;
          void sheet() => showPeerAlbumSheet(context, item, page!);
          return SizedBox(
            width: _stripCardWidth,
            child: AlbumGridCard(
              item: item,
              cacheWidth: cacheW,
              onTap: () => handleTap(items, from + k, context),
              onLongPress: peerCard ? sheet : null,
              onMore: peerCard ? sheet : null,
              moreLabel: peerCard
                  ? AppLocalizations.of(context).discoverAlbumCardMore(item.name)
                  : null,
              coverBadge:
                  marker == null ? null : DiscoveryCardBadge(marker: marker),
              mark: marker == null
                  ? null
                  : keepMarkerWord(AppLocalizations.of(context), marker,
                      card: true),
            ),
          );
        },
      ),
    );
  }

  // In-flow context strip under the toolbar: the query on a search-results list,
  // or the current directory in the file explorer. Both are persistent context
  // for their view (tracked per stack frame, so they revert on back-nav). The
  // transient search-scope preview is a separate slide-over overlay so it
  // doesn't shove the list down — see _searchScopePreview.
  Widget _browserSubheader(BuildContext context, AppLocalizations l) {
    return StreamBuilder<List<DisplayItem>>(
      stream: BrowserManager().browserListStream,
      builder: (context, _) {
        final term = BrowserManager().currentSearchTerm;
        if (term != null) {
          return _subheaderStrip(Icons.search, l.searchSubheaderResults(term));
        }
        final path = BrowserManager().currentPath;
        if (path != null) {
          return _subheaderStrip(
              Icons.folder_outlined, path.isEmpty ? '/' : path,
              mono: true, headFirst: true);
        }
        final playlist = BrowserManager().currentPlaylist;
        if (playlist != null) {
          // Same strip the file explorer uses for its path — the toolbar no
          // longer carries a label on this view, so this is what names it.
          return _subheaderStrip(Icons.queue_music, playlist);
        }
        return const SizedBox.shrink();
      },
    );
  }

  // Transient search-scope preview that SLIDES OVER the list (rather than
  // pushing it down) while the home search field is focused, so the user can
  // see — and fix — a stale category selection before typing. Driven by
  // BrowserManager.searchFocused; wrapped in IgnorePointer so it never blocks
  // taps on the list beneath it.
  Widget _searchScopePreview(BuildContext context, AppLocalizations l) {
    return IgnorePointer(
      child: StreamBuilder<bool>(
        stream: BrowserManager().searchFocusedStream,
        initialData: BrowserManager().searchFocused,
        builder: (context, focusSnap) {
          return ClipRect(
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              offset:
                  (focusSnap.data ?? false) ? Offset.zero : const Offset(0, -1),
              child: StreamBuilder<Set<SearchCategory>>(
                stream: SettingsManager().searchCategoriesStream,
                initialData: SettingsManager().searchCategories,
                builder: (context, catSnap) {
                  final cats =
                      catSnap.data ?? SettingsManager().searchCategories;
                  final names = SearchCategory.values
                      .where(cats.contains)
                      .map((c) => c.label(l))
                      .join(' · ');
                  return _subheaderStrip(
                      Icons.manage_search, l.searchSubheaderCategories(names));
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // [headFirst]: the explorer's path, cut from its head — the folder you
  // are in is what matters, so "…/Various Artists/Night Market Sampler/"
  // rather than "/music/Various Art…" (a screen reader hears it whole).
  Widget _subheaderStrip(IconData icon, String text,
      {bool mono = false, bool headFirst = false}) {
    final style = TextStyle(
      fontFamily: mono ? 'monospace' : null,
      fontFamilyFallback: mono ? kMonoFallback : null,
      fontSize: 11.5,
      color: VelvetColors.textSecondary,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 4, 12, 5),
      decoration: BoxDecoration(
        color: VelvetColors.raised,
        border: Border(bottom: BorderSide(color: VelvetColors.border)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: VelvetColors.textTertiary),
          const SizedBox(width: 6),
          Expanded(
            child: !headFirst
                ? Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  )
                : LayoutBuilder(builder: (context, box) {
                    final ts = MediaQuery.textScalerOf(context);
                    bool fits(String t) {
                      final p = TextPainter(
                        text: TextSpan(text: t, style: style),
                        textDirection: TextDirection.ltr,
                        textScaler: ts,
                        maxLines: 1,
                      )..layout();
                      final w = p.width;
                      p.dispose();
                      return w <= box.maxWidth;
                    }

                    final cut = headEllipsis(text, fits);
                    return Semantics(
                      label: text,
                      excludeSemantics: true,
                      child: Text(
                        cut.text,
                        key: const ValueKey('browser-path-strip'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style,
                      ),
                    );
                  }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Stack(children: <Widget>[
      Column(children: <Widget>[
      // In-flow context strip under the toolbar (search term / file path) —
      // see _browserSubheader.
      _browserSubheader(context, l),
      // Thin indeterminate bar while any browser server call is in
      // flight (all go through ApiManager.makeServerCall). Fixed 3px
      // slot — empty when idle — so the list never jumps.
      StreamBuilder<bool>(
        stream: BrowserManager().loadingStream,
        initialData: BrowserManager().isLoading,
        builder: (context, snap) {
          final loading = snap.data ?? false;
          return SizedBox(
            height: 3,
            child: loading
                ? LinearProgressIndicator(
                    minHeight: 3,
                    color: VelvetColors.primary,
                    backgroundColor: Colors.transparent,
                  )
                : null,
          );
        },
      ),
      Expanded(
          child: SizedBox(
              child: StreamBuilder<List<DisplayItem>>(
                  stream: BrowserManager().browserListStream,
                  builder: (context, snapshot) {
                    final List<DisplayItem> rawList = snapshot.data ?? [];
                    // A connected server's frame: Keep a copy's page state
                    // (its gate snapshot, its marks).
                    final page = _syncPage();

                    // Discover draws its own listing (the bar, sections and
                    // footers around the browser's rows).
                    if (DiscoveryListing.isListing(rawList)) {
                      final search = BrowserManager().search;
                      return _discoveryView(context, rawList,
                          search.open ? search.query.trim() : '');
                    }

                    // Local search filters only the *displayed* list; the
                    // manager's browserList (hence navigation / back-stack
                    // / scroll restore) is untouched. The execAction home
                    // menu is fixed section shortcuts, not content, so it
                    // is never filtered.
                    final bool isHome = BrowserManager.isHomeList(rawList);
                    // Search state lives in BrowserManager (the top toolbar owns
                    // the field) and re-emits this list on every change, so
                    // reading it synchronously here re-filters live.
                    final search = BrowserManager().search;
                    final String q = search.query.trim();
                    final bool filtering =
                        search.open && q.isNotEmpty && !isHome;
                    final List<DisplayItem> browserList = filtering
                        ? rawList.where((it) => it.matchesQuery(q)).toList()
                        : rawList;

                    if (filtering && browserList.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            l.browserNoMatches(q),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: VelvetColors.textSecondary,
                                fontSize: 14),
                          ),
                        ),
                      );
                    }

                    // The default browser landing (section shortcuts) gets a
                    // modern card grid instead of plain list rows.
                    if (isHome) {
                      // While a configured "startup view" loads on launch, show
                      // a spinner instead of the home grid so the app lands
                      // straight on the chosen section (no home-grid flash).
                      if (BrowserManager().awaitingStartupView) {
                        return Center(
                          child: CircularProgressIndicator(
                              color: VelvetColors.primary),
                        );
                      }
                      return _homeView(context, browserList);
                    }

                    // An open playlist with nothing in it. Without this the
                    // user gets a blank screen that's indistinguishable from
                    // a failed load. Keyed off the frame's playlist name, so
                    // an empty FOLDER is unaffected.
                    if (browserList.isEmpty &&
                        BrowserManager().currentPlaylist != null) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            l.playlistEmpty,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: VelvetColors.textTertiary,
                                fontSize: 14),
                          ),
                        ),
                      );
                    }

                    // The server "Playlists" view gets its own layout: a New-
                    // playlist button + modern rows with a rename/delete menu.
                    // Detected by item type ('playlist'); the empty-list case is
                    // keyed off the section label.
                    final isPlaylistView =
                        browserList.every((e) => e.type == 'playlist') &&
                            (browserList.isNotEmpty ||
                                (BrowserManager().listName == 'Playlists' &&
                                    BrowserManager().currentArtist == null));
                    if (isPlaylistView) {
                      return _playlistsView(context, browserList);
                    }

                    // If the whole list is albums and the user has the
                    // album-grid setting on, show a grid of album cards
                    // instead of the plain list.
                    final allAlbums = browserList.isNotEmpty &&
                        browserList.every((e) => e.type == 'album');
                    return StreamBuilder<bool>(
                      stream: SettingsManager().albumGridStream,
                      initialData: SettingsManager().albumGrid,
                      builder: (context, gridSnap) {
                        final useGrid = (gridSnap.data ?? true) && allAlbums;
                        final ts = MediaQuery.textScalerOf(context);
                        // Reserve the strip's width only when the strip will
                        // actually be there — the same three conditions the
                        // overlay below uses, plus the strip's own
                        // will-I-render check. Otherwise a list short enough
                        // to hide the strip would still get an empty gutter.
                        final stripShowing = BrowserManager().isAlphabetical &&
                            browserList.isNotEmpty &&
                            !filtering &&
                            LetterStrip.showsFor(browserList);
                        final gutter =
                            stripShowing ? LetterStrip.gutterWidth : 0.0;
                        final stripOnLeft = LetterStrip.onLeft;
                        // A connected server's artist page and open folder
                        // lead with their header, the first thing scrolled.
                        final Widget? header = page == null
                            ? null
                            : switch (page.kind) {
                                _PeerKind.artist => _artistHeader(context, page),
                                _PeerKind.explorer =>
                                  _folderHeader(context, page, rawList),
                                _ => null,
                              };
                        Widget content = useGrid
                            ? AlbumGrid(
                                items: browserList,
                                gutter: gutter,
                                // Pass the shared controller so the
                                // letter-strip's jumpTo actually
                                // moves the grid (and so the existing
                                // scroll-restore logic works in grid
                                // mode too).
                                controller: BrowserManager().sc,
                                onTap: (i) =>
                                    handleTap(browserList, i, context),
                                header: header == null
                                    ? null
                                    : KeyedSubtree(
                                        key: page!.headerKey, child: header),
                                extrasOf: page == null
                                    ? null
                                    : (i) => _cardExtras(
                                        context, page, browserList[i]),
                              )
                            // ListTileTheme override so the browser's rows
                            // are denser than the global ListTile
                            // default — gains ~26px of horizontal
                            // space for the title (less truncation)
                            // without affecting Settings/About/etc.
                            // (.merge, not a full Theme copyWith, so a
                            // list rebuild doesn't allocate a whole
                            // ThemeData — see the download-tick rebuilds.)
                            //   contentPadding: 16 -> 10 (saves 12)
                            //   horizontalTitleGap: 16 -> 10 (saves 6)
                            //   minLeadingWidth: 40 -> 32 (saves 8)
                            // Heights are unchanged by these knobs,
                            // so the letter-scrub cumulative math
                            // stays correct.
                            : ListTileTheme.merge(
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                horizontalTitleGap: 10,
                                minLeadingWidth: 32,
                                // The gutter is padding on the LIST, not on
                                // the rows' contents: a row draws its own
                                // bottom border across its full width, so
                                // insetting only the content left the divider
                                // running on under the strip.
                                child: Padding(
                                  padding: EdgeInsets.only(
                                      left: stripOnLeft ? gutter : 0,
                                      right: stripOnLeft ? 0 : gutter),
                                  // Slivers, so a page's header scrolls
                                  // away with its rows.
                                  child: CustomScrollView(
                                    controller: BrowserManager().sc,
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    slivers: [
                                      if (header != null)
                                        SliverToBoxAdapter(
                                          child: KeyedSubtree(
                                              key: page!.headerKey,
                                              child: header),
                                        ),
                                      // Known per-row extents give the sliver
                                      // O(1) seek, so the letter-strip jumpTo
                                      // lands instantly instead of estimating
                                      // + settling over frames on long lists
                                      // (the scrub lag). Rows already draw
                                      // their own bottom border, so the old
                                      // Divider separator is dropped. See
                                      // _rowExtent: a folder row's mark is
                                      // counted in it.
                                      SliverVariedExtentList(
                                        itemExtentBuilder: (index, _) =>
                                            index < browserList.length
                                                ? _extentOf(
                                                    browserList[index], ts)
                                                : null,
                                        delegate: SliverChildBuilderDelegate(
                                          (BuildContext context, int index) =>
                                              makeListItem(
                                                  browserList, index, context),
                                          childCount: browserList.length,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );

                        // A connected server's page with no header: focus
                        // a closed Keep sheet's gone opener hands back
                        // lands on its list, never the page's root.
                        if (page != null && header == null) {
                          content = Focus(
                              key: const ValueKey('browse-page-list-focus'),
                              focusNode: page.header,
                              child: content);
                        }

                        // Only overlay the letter scrubber for views
                        // the server sorts alphabetically (Albums,
                        // Artists, File Explorer) — see BrowserManager
                        // .alphabeticalCache. `stripShowing` carries the
                        // strip's own will-I-render check too, so the rule
                        // below can never be drawn beside nothing.
                        if (!stripShowing) {
                          return content;
                        }
                        return Stack(
                          children: [
                            content,
                            // A hairline between the rows and the strip, in
                            // the row divider's own colour so the two read as
                            // one grid. Drawn here rather than as a border on
                            // the strip: the strip's visible pill is rounded
                            // and only as tall as its letters, and this has to
                            // run the full height of the list.
                            Positioned(
                              left: stripOnLeft
                                  ? LetterStrip.stripWidth
                                  : null,
                              right: stripOnLeft
                                  ? null
                                  : LetterStrip.stripWidth,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                  width: 1, color: VelvetColors.border),
                            ),
                            Positioned(
                              left: stripOnLeft ? 0 : null,
                              right: stripOnLeft ? null : 0,
                              top: 0,
                              bottom: 0,
                              child: LetterStrip(
                                items: browserList,
                                onJump: (i) {
                                  final sc = BrowserManager().sc;
                                  if (!sc.hasClients) return;
                                  // The page's header scrolls first: the
                                  // rows start under its laid-out height.
                                  final headerBox = header == null
                                      ? null
                                      : page!.headerKey.currentContext
                                          ?.findRenderObject() as RenderBox?;
                                  final top = headerBox?.hasSize == true
                                      ? headerBox!.size.height
                                      : 0.0;
                                  final double offset;
                                  if (useGrid) {
                                    final w = MediaQuery.of(context)
                                        .size
                                        .width;
                                    final cols =
                                        AlbumGrid.columnsFor(w, gutter);
                                    final rowH =
                                        AlbumGrid.rowHeightFor(w, gutter);
                                    final row = i ~/ cols;
                                    offset = top +
                                        AlbumGrid.padTop +
                                        row * (rowH + AlbumGrid.spacing);
                                  } else {
                                    // Sum the SAME per-row extents the ListView
                                    // lays out with (see _rowExtent) so the jump
                                    // lands exactly on the target row. File
                                    // Explorer mixes 1- and 2-line rows, hence
                                    // the walk-and-sum. O(i), microseconds even
                                    // at 10k+ items.
                                    double sum = top;
                                    final stop =
                                        i.clamp(0, browserList.length);
                                    for (var k = 0; k < stop; k++) {
                                      sum += _extentOf(browserList[k], ts);
                                    }
                                    offset = sum;
                                  }
                                  sc.jumpTo(offset
                                      .clamp(
                                          0.0, sc.position.maxScrollExtent)
                                      .toDouble());
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  })))
      ]),
      // Slide-over search-scope preview over the top of the list (focus-driven).
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: _searchScopePreview(context, l),
      ),
    ]);
  }
}
