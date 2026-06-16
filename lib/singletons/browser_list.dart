import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import '../singletons/server_list.dart';
import '../singletons/settings.dart';
import '../singletons/migration_manager.dart';
import '../singletons/file_explorer.dart';
import '../singletons/downloads.dart';
import '../objects/display_item.dart';
import '../objects/server.dart';
import '../theme/velvet_theme.dart';

class BrowserManager {
  final List<List<DisplayItem>> browserCache = [];
  final List<double> scrollCache = [];
  // 1:1 with browserCache. Drives whether the letter-scrub strip
  // overlays the current screen. Tracked per stack frame so back-nav
  // brings the strip back when returning to an alphabetical screen.
  final List<bool> alphabeticalCache = [];
  // 1:1 with browserCache. The File Explorer's current directory path per frame
  // (null for non-file-explorer frames), so the path row shows the right folder
  // and reverts on back-nav. Display-only — no navigation logic reads it.
  final List<String?> pathCache = [];
  // 1:1 with browserCache. The DB-search query per frame (null for non-search
  // frames), so the search-results subheader shows the term and reverts on
  // back-nav, mirroring pathCache. Display-only.
  final List<String?> searchTermCache = [];

  final List<DisplayItem> browserList = [];

  // True from launch until a configured non-browser "startup view" finishes
  // loading. While set, the browser shows a loading spinner instead of the home
  // grid, so the app lands directly on the chosen section without a home-grid
  // flash. Set in MStreamApp.initState; cleared once the section loads (or the
  // load fails). See _maybeOpenStartupView.
  bool awaitingStartupView = false;

  bool get isAlphabetical =>
      alphabeticalCache.isNotEmpty ? alphabeticalCache.last : false;

  /// Current File Explorer directory path for the top frame, or null when the
  /// current view isn't the file explorer.
  String? get currentPath => pathCache.isNotEmpty ? pathCache.last : null;

  /// The DB-search query for the top frame, or null when the current view
  /// isn't a search-results list.
  String? get currentSearchTerm =>
      searchTermCache.isNotEmpty ? searchTermCache.last : null;

  String listName = 'Welcome';

  // In-flight server-call tracking. makeServerCall (the chokepoint every browse
  // fetch passes through) brackets each request with beginLoading()/endLoading().
  // This drives three things:
  //   1. the browser's global loading bar (the _loading stream),
  //   2. the tap-guard — the browser ignores item taps while [isLoading] is
  //      true, so tapping a second folder before the first resolves can't kick
  //      off a racing request (whichever finished last used to win the screen),
  //   3. Back-to-cancel — [cancelLoading] aborts every in-flight request via the
  //      registered cancelers (which close the http client) and marks their
  //      tokens cancelled so a late response is dropped instead of navigated to.
  // Each call gets a monotonic token and we track the live set (not a bare
  // counter) so a cancelled call's late endLoading() can't zero out a newer one.
  final Set<int> _inFlight = {};
  final Map<int, void Function()> _loadCancelers = {};
  int _lastLoadToken = 0;
  // Tokens <= this were cancelled by Back; their results must be discarded.
  int _cancelledThrough = 0;
  late final BehaviorSubject<bool> _loading =
      BehaviorSubject<bool>.seeded(false);
  Stream<bool> get loadingStream => _loading.stream;
  bool get isLoading => _inFlight.isNotEmpty;

  /// Begin tracking a server call. [onCancel] (e.g. closing the http client) is
  /// invoked if Back cancels the load while it's still in flight. Returns a
  /// token to pass to [endLoading] / [isLoadCancelled].
  int beginLoading({void Function()? onCancel}) {
    final token = ++_lastLoadToken;
    _inFlight.add(token);
    if (onCancel != null) _loadCancelers[token] = onCancel;
    if (_inFlight.length == 1) _loading.add(true);
    return token;
  }

  void endLoading(int token) {
    _loadCancelers.remove(token);
    if (_inFlight.remove(token) && _inFlight.isEmpty) _loading.add(false);
  }

  /// True if load [token] was cancelled (Back pressed) — the caller should drop
  /// whatever the request returned rather than pushing it onto the stack.
  bool isLoadCancelled(int token) => token <= _cancelledThrough;

  /// Cancel every in-flight server call — used by Back to stop a long load.
  /// Fires each canceler (aborting the http request) and marks the tokens
  /// cancelled so any response that still lands is discarded. Returns true if
  /// anything was in flight (so the Back handler knows it consumed the press).
  bool cancelLoading() {
    if (_inFlight.isEmpty) return false;
    _cancelledThrough = _lastLoadToken;
    final cancelers = List.of(_loadCancelers.values);
    _loadCancelers.clear();
    _inFlight.clear();
    _loading.add(false);
    for (final c in cancelers) {
      c(); // closes the http client → the pending request throws → dropped
    }
    return true;
  }

  late final BehaviorSubject<List<DisplayItem>> _browserStream =
      BehaviorSubject<List<DisplayItem>>.seeded(browserList);
  late final BehaviorSubject<String> _browserLabel =
      BehaviorSubject<String>.seeded(listName);

  // Album-detail overlay. When non-null, the browser body shows the album detail
  // view over the file list (same browser model — no Navigator route — so the
  // mini-player stays visible). Cleared by Back and by a server switch.
  late final BehaviorSubject<DisplayItem?> _albumDetail =
      BehaviorSubject<DisplayItem?>.seeded(null);

  // The album-detail view publishes its loaded songs here so the top toolbar's
  // download / add-all act on them (the songs live in the view's state).
  List<DisplayItem>? albumDetailSongs;

  // Browser local-search state, shared so the top toolbar owns the field/toggle
  // while the body does the filtering. open = field shown; query = filter text.
  late final BehaviorSubject<({bool open, String query})> _search =
      BehaviorSubject<({bool open, String query})>.seeded(
          (open: false, query: ''));

  // Whether the home "search the whole server" field is focused. The toolbar
  // owns the field and reports focus here; the body shows a subheader previewing
  // which categories a search will cover, so stale defaults are visible before
  // the user types.
  late final BehaviorSubject<bool> _searchFocused =
      BehaviorSubject<bool>.seeded(false);

  StreamSubscription<int>? _letterStripSub;
  StreamSubscription<MigrationProgress?>? _migrationSub;

  BrowserManager._privateConstructor() {
    // When the letter-strip threshold changes, re-emit the current
    // list so the browser rebuilds — row builders and the strip both
    // read the threshold at build time, so a rebuild applies the new
    // value (strip visibility + folder/file title wrapping) without
    // requiring the user to navigate away and back.
    _letterStripSub =
        SettingsManager().letterStripStream.listen((_) => updateStream());
    // When a storage move finishes, re-check on-device download badges so a
    // background "Move them" re-marks files now present at the new location
    // (the edit-time refresh ran before the move had finished).
    _migrationSub = MigrationManager().progressStream.listen((p) {
      if (p?.done == true) refreshAllDownloadStatus();
    });
  }
  static final BrowserManager _instance = BrowserManager._privateConstructor();

  // scroll controller in stream format
  ScrollController sc = ScrollController();

  factory BrowserManager() {
    return _instance;
  }

  void setBrowserLabel(String label) {
    listName = label;
    _browserLabel.sink.add(label);
  }

  /// Show the album-detail view over the browser body (no route).
  void openAlbumDetail(DisplayItem album) {
    albumDetailSongs = null; // new album — its songs load asynchronously
    _albumDetail.add(album);
  }

  /// Hide the album-detail view. Returns true if it was open, so the back
  /// handler knows it consumed the gesture.
  bool closeAlbumDetail() {
    if (_albumDetail.value == null) return false;
    albumDetailSongs = null;
    _albumDetail.add(null);
    return true;
  }

  // ── browser local search (field lives in the top toolbar) ──
  // Each mutation re-emits the browser list so the body re-filters live (the
  // body reads `search` synchronously at build time).
  void openSearch() {
    if (_search.value.open) return;
    _search.add((open: true, query: ''));
    updateStream();
  }

  void setSearchQuery(String q) {
    _search.add((open: _search.value.open, query: q));
    updateStream();
  }

  /// Clears an active search. Returns true if there was one (so the back
  /// handler can consume the gesture).
  bool closeSearch() {
    final s = _search.value;
    if (!s.open && s.query.isEmpty) return false;
    _search.add((open: false, query: ''));
    updateStream();
    return true;
  }

  /// Report whether the home server-search field is focused (called by the
  /// toolbar). Drives the search-category preview subheader in the body.
  void setSearchFocused(bool focused) {
    if (_searchFocused.value != focused) _searchFocused.add(focused);
  }

  void clear() {
    List<DisplayItem> hold = browserCache[0];
    bool holdAlpha = alphabeticalCache.isNotEmpty ? alphabeticalCache[0] : false;
    String? holdPath = pathCache.isNotEmpty ? pathCache[0] : null;
    String? holdTerm =
        searchTermCache.isNotEmpty ? searchTermCache[0] : null;

    browserCache.clear();
    browserList.clear();

    browserCache.add(hold);

    scrollCache.clear();
    alphabeticalCache
      ..clear()
      ..add(holdAlpha);
    pathCache
      ..clear()
      ..add(holdPath);
    searchTermCache
      ..clear()
      ..add(holdTerm);
  }

  void goToNavScreen() {
    _albumDetail.add(null);
    browserCache.clear();
    browserList.clear();
    // Invariant: scrollCache.length == browserCache.length - 1.
    // Reset alongside the cache or pops will pull stale offsets.
    scrollCache.clear();
    alphabeticalCache.clear();
    pathCache.clear();
    searchTermCache.clear();

    if (ServerManager().currentServer == null) {
      return;
    }

    DisplayItem newItem1 = DisplayItem(
        ServerManager().currentServer!,
        'File Explorer',
        'execAction',
        'fileExplorer',
        Icon(Icons.folder, color: VelvetColors.warning),
        null);

    DisplayItem newItem2 = DisplayItem(
        ServerManager().currentServer!,
        'Playlists',
        'execAction',
        'playlists',
        Icon(Icons.queue_music, color: VelvetColors.textSecondary),
        null);

    DisplayItem newItem3 = DisplayItem(
        ServerManager().currentServer!,
        'Albums',
        'execAction',
        'albums',
        Icon(Icons.album, color: VelvetColors.textSecondary),
        null);

    DisplayItem newItem4 = DisplayItem(
        ServerManager().currentServer!,
        'Artists',
        'execAction',
        'artists',
        Icon(Icons.library_music, color: VelvetColors.textSecondary),
        null);

    DisplayItem newItem5 = DisplayItem(
        ServerManager().currentServer!,
        'Rated',
        'execAction',
        'rated',
        Icon(Icons.star, color: VelvetColors.textSecondary),
        null);

    DisplayItem newItem6 = DisplayItem(
        ServerManager().currentServer!,
        'Recent',
        'execAction',
        'recent',
        Icon(Icons.query_builder, color: VelvetColors.textSecondary),
        null);

    DisplayItem newItem7 = DisplayItem(
        ServerManager().currentServer!,
        'Local Files',
        'execAction',
        'localFiles',
        Icon(Icons.folder_open_outlined, color: VelvetColors.textSecondary),
        null);

    browserCache.add(
        [newItem1, newItem2, newItem3, newItem4, newItem5, newItem6, newItem7]);
    // Nav screen isn't alphabetical content — just the section list.
    alphabeticalCache.add(false);
    pathCache.add(null); // home nav isn't the file explorer — no path row
    searchTermCache.add(null); // home nav isn't a search result — no term row
    browserList.add(newItem1);
    browserList.add(newItem2);
    browserList.add(newItem3);
    browserList.add(newItem4);
    browserList.add(newItem5);
    browserList.add(newItem6);
    browserList.add(newItem7);

    _browserLabel.sink.add('Browser');
    _browserStream.sink.add(browserList);
  }

  void noServerScreen() {
    _albumDetail.add(null);
    browserCache.clear();
    browserList.clear();
    scrollCache.clear();
    alphabeticalCache.clear();
    pathCache.clear();
    searchTermCache.clear();

    browserList.add(DisplayItem(null, 'Welcome To mStream', 'addServer', '',
        Icon(Icons.add, color: VelvetColors.textSecondary), 'Click here to add server'));

    _browserStream.sink.add(browserList);
  }

  void addListToStack(List<DisplayItem> newList,
      {bool alphabetical = false, String? path, String? searchTerm}) {
    // Capture the current screen's scroll position before navigating
    // forward. sc.hasClients is false when navigation is triggered
    // from a non-Browser context (e.g. tapping File Explorer in the
    // drawer while on the Queue tab) — in that case the user wasn't
    // viewing the previous screen anyway, so 0 is fine. Push happens
    // before the new entry so scrollCache.length stays at
    // browserCache.length - 1 after the next line.
    scrollCache.add(sc.hasClients ? sc.offset : 0.0);

    browserCache.add(newList);
    alphabeticalCache.add(alphabetical);
    pathCache.add(path);
    searchTermCache.add(searchTerm);

    browserList
      ..clear()
      ..addAll(newList);

    // Re-attach any in-flight download to its new row instance (seed progress +
    // re-point the tracker) BEFORE emitting, so re-opening a folder mid-download
    // shows the progress bar immediately instead of a blank row.
    DownloadManager().rebindActiveDownloads(newList);

    // Reset to top synchronously BEFORE emitting so the upcoming
    // rebuild lays out at offset 0 in a single frame. Doing this
    // via addPostFrameCallback paints the new list at the inherited
    // offset for one frame, then visibly jumps to top.
    if (sc.hasClients) sc.jumpTo(0);

    _browserStream.sink.add(browserList);

    // Resolve the on-device download badges for this list's file rows in one
    // batched pass (replaces the per-item probe the DisplayItem constructor
    // used to fire). Fire-and-forget: the list is already on screen and the
    // badges flip in with a single re-emit once the disk checks finish.
    unawaited(_resolveDownloadBadges(newList));
  }

  void updateStream() {
    _browserStream.sink.add(browserList);
  }

  // Coalesced re-emit for the high-frequency download-progress path: a
  // "Download all" fires progress ticks across many rows (one per 5% bucket per
  // file), which can land dozens a second. Collapse them to <=1 emit / 100 ms so
  // the whole list isn't rebuilt on every tick. Interactive callers (live search
  // filtering, navigation) keep using updateStream() / the direct sink, so they
  // stay immediate.
  Timer? _downloadRefreshTimer;
  void updateStreamCoalesced() {
    if (_downloadRefreshTimer != null) return; // a flush is already scheduled
    _downloadRefreshTimer = Timer(const Duration(milliseconds: 100), () {
      _downloadRefreshTimer = null;
      _browserStream.sink.add(browserList);
    });
  }

  /// Replaces the current (top) frame's list in place — no push/pop, so the
  /// back-stack is unchanged. Used to refresh a view (e.g. after a playlist
  /// create/rename) without adding a navigation entry.
  void replaceTop(List<DisplayItem> newList) {
    if (browserCache.isNotEmpty) {
      browserCache[browserCache.length - 1] = newList;
    }
    browserList
      ..clear()
      ..addAll(newList);
    DownloadManager().rebindActiveDownloads(newList);
    _browserStream.sink.add(browserList);
    unawaited(_resolveDownloadBadges(newList));
  }

  // Re-check the on-device download badge for cached file rows against their
  // server's CURRENT storage location, then refresh the browser once. Used
  // after a server's download location changes (and when a storage move
  // finishes) so a badge computed against the old path corrects itself —
  // including clearing a "downloaded" mark for a file that's no longer there.
  Future<void> refreshDownloadStatus(Server server) =>
      _refreshDownloadStatus((i) => i.server == server);

  Future<void> refreshAllDownloadStatus() =>
      _refreshDownloadStatus((_) => true);

  Future<void> _refreshDownloadStatus(bool Function(DisplayItem) match) async {
    final items = <DisplayItem>{};
    for (final frame in browserCache) {
      for (final item in frame) {
        if (item.type == 'file' && match(item)) items.add(item);
      }
    }
    for (final item in browserList) {
      if (item.type == 'file' && match(item)) items.add(item);
    }
    await _resolveDownloadBadges(items);
  }

  // Resolve the on-device "downloaded" badge for the file rows in [items],
  // then re-emit the browser once — but only if a badge actually changed, so a
  // list with no local copies doesn't trigger a redundant full-list rebuild.
  //
  // Groups rows by their server's storage location so getDownloadDir() (a
  // platform-channel / stat call) runs ONCE per distinct location instead of
  // once per row — the per-item cost the DisplayItem constructor used to pay.
  // Within a location the File.exists() probes run in parallel. No-ops when
  // there are no file rows.
  Future<void> _resolveDownloadBadges(Iterable<DisplayItem> items) async {
    final byLocation = <(String, String?), List<DisplayItem>>{};
    for (final i in items) {
      if (i.type != 'file' || i.server == null || i.data == null) continue;
      final key = (i.server!.storageMode, i.server!.storageBasePath);
      (byLocation[key] ??= <DisplayItem>[]).add(i);
    }
    if (byLocation.isEmpty) return;

    var changed = false;
    for (final entry in byLocation.entries) {
      final (mode, base) = entry.key;
      final dir = await FileExplorer().getDownloadDir(mode, base);
      final rows = entry.value;
      final before = [for (final i in rows) i.downloadProgress];
      await Future.wait(rows.map((i) => i.recheckDownloadedIn(dir)));
      for (var k = 0; k < rows.length; k++) {
        if (rows[k].downloadProgress != before[k]) changed = true;
      }
    }
    if (changed) updateStream();
  }

  void popBrowser() {
    if (BrowserManager().browserCache.length < 2) {
      return;
    }

    browserCache.removeLast();
    if (alphabeticalCache.isNotEmpty) alphabeticalCache.removeLast();
    if (pathCache.isNotEmpty) pathCache.removeLast();
    if (searchTermCache.isNotEmpty) searchTermCache.removeLast();
    browserList
      ..clear()
      ..addAll(browserCache.last);

    // Restore scroll BEFORE emitting so the rebuilt ListView lays
    // out at the target offset in its first frame. Going through
    // addPostFrameCallback paints the list at the top first, then
    // visibly jumps — the jank the user reported. Flutter auto-
    // clamps out-of-bounds offsets in the new layout (worst case:
    // content shrunk since we left, lands at the new bottom), so
    // no explicit clamp is needed here.
    if (scrollCache.isNotEmpty && sc.hasClients) {
      sc.jumpTo(scrollCache.removeLast());
    } else if (scrollCache.isNotEmpty) {
      // No clients to restore against, but keep the stack invariant.
      scrollCache.removeLast();
    }

    _browserStream.sink.add(browserList);

    if (BrowserManager().browserCache.length == 1) {
      _browserLabel.sink.add('Browser');
    }
  }

  void removeAll(String data, Server? server, String type) {
    browserList.removeWhere(
        (e) => e.server == server && e.data == data && e.type == type);
    _browserStream.sink.add(browserList);

    for (var b in browserCache) {
      b.removeWhere(
          (e) => e.server == server && e.data == data && e.type == type);
    }
    // Known limitation: removing items shifts subsequent scroll
    // offsets but scrollCache isn't recalculated. On back-nav to a
    // filtered screen the saved offset may be too large — popBrowser
    // clamps to maxScrollExtent so the worst case is "lands at the
    // bottom" rather than crashing.
  }

  void dispose() {
    _migrationSub?.cancel();
    _letterStripSub?.cancel();
    _downloadRefreshTimer?.cancel();
    _browserStream.close();
    _browserLabel.close();
    _albumDetail.close();
    _search.close();
    _searchFocused.close();
    _loading.close();
  }

  Stream<List<DisplayItem>> get browserListStream => _browserStream.stream;
  Stream<String> get browserLabelStream => _browserLabel.stream;
  Stream<DisplayItem?> get albumDetailStream => _albumDetail.stream;
  DisplayItem? get albumDetail => _albumDetail.value;
  Stream<({bool open, String query})> get searchStream => _search.stream;
  ({bool open, String query}) get search => _search.value;
  Stream<bool> get searchFocusedStream => _searchFocused.stream;
  bool get searchFocused => _searchFocused.value;
}
