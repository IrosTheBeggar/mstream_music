import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import '../singletons/server_list.dart';
import '../singletons/settings.dart';
import '../singletons/migration_manager.dart';
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

  final List<DisplayItem> browserList = [];

  bool get isAlphabetical =>
      alphabeticalCache.isNotEmpty ? alphabeticalCache.last : false;

  String listName = 'Welcome';

  // In-flight server-call tracking for the browser's global loading bar.
  // makeServerCall (the chokepoint every browse fetch passes through)
  // brackets each request with beginLoading()/endLoading(); the counter
  // keeps the bar up across overlapping calls and flips the stream only
  // on the 0<->1 transition, so there are no redundant rebuilds.
  int _inFlightCalls = 0;
  late final BehaviorSubject<bool> _loading =
      BehaviorSubject<bool>.seeded(false);
  Stream<bool> get loadingStream => _loading.stream;
  bool get isLoading => _loading.value;

  void beginLoading() {
    _inFlightCalls++;
    if (_inFlightCalls == 1) _loading.add(true);
  }

  void endLoading() {
    if (_inFlightCalls > 0) _inFlightCalls--;
    if (_inFlightCalls == 0) _loading.add(false);
  }

  late final BehaviorSubject<List<DisplayItem>> _browserStream =
      BehaviorSubject<List<DisplayItem>>.seeded(browserList);
  late final BehaviorSubject<String> _browserLabel =
      BehaviorSubject<String>.seeded(listName);

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

  void clear() {
    List<DisplayItem> hold = browserCache[0];
    bool holdAlpha = alphabeticalCache.isNotEmpty ? alphabeticalCache[0] : false;

    browserCache.clear();
    browserList.clear();

    browserCache.add(hold);

    scrollCache.clear();
    alphabeticalCache
      ..clear()
      ..add(holdAlpha);
  }

  void goToNavScreen() {
    browserCache.clear();
    browserList.clear();
    // Invariant: scrollCache.length == browserCache.length - 1.
    // Reset alongside the cache or pops will pull stale offsets.
    scrollCache.clear();
    alphabeticalCache.clear();

    if (ServerManager().currentServer == null) {
      return;
    }

    DisplayItem newItem1 = new DisplayItem(
        ServerManager().currentServer!,
        'File Explorer',
        'execAction',
        'fileExplorer',
        Icon(Icons.folder, color: VelvetColors.warning),
        null);

    DisplayItem newItem2 = new DisplayItem(
        ServerManager().currentServer!,
        'Playlists',
        'execAction',
        'playlists',
        Icon(Icons.queue_music, color: VelvetColors.textSecondary),
        null);

    DisplayItem newItem3 = new DisplayItem(
        ServerManager().currentServer!,
        'Albums',
        'execAction',
        'albums',
        Icon(Icons.album, color: VelvetColors.textSecondary),
        null);

    DisplayItem newItem4 = new DisplayItem(
        ServerManager().currentServer!,
        'Artists',
        'execAction',
        'artists',
        Icon(Icons.library_music, color: VelvetColors.textSecondary),
        null);

    DisplayItem newItem5 = new DisplayItem(
        ServerManager().currentServer!,
        'Rated',
        'execAction',
        'rated',
        Icon(Icons.star, color: VelvetColors.textSecondary),
        null);

    DisplayItem newItem6 = new DisplayItem(
        ServerManager().currentServer!,
        'Recent',
        'execAction',
        'recent',
        Icon(Icons.query_builder, color: VelvetColors.textSecondary),
        null);

    DisplayItem newItem7 = new DisplayItem(
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
    browserCache.clear();
    browserList.clear();
    scrollCache.clear();
    alphabeticalCache.clear();

    browserList.add(new DisplayItem(null, 'Welcome To mStream', 'addServer', '',
        Icon(Icons.add, color: VelvetColors.textSecondary), 'Click here to add server'));

    _browserStream.sink.add(browserList);
  }

  void addListToStack(List<DisplayItem> newList, {bool alphabetical = false}) {
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

    browserList.clear();
    newList.forEach((element) {
      browserList.add(element);
    });

    // Reset to top synchronously BEFORE emitting so the upcoming
    // rebuild lays out at offset 0 in a single frame. Doing this
    // via addPostFrameCallback paints the new list at the inherited
    // offset for one frame, then visibly jumps to top.
    if (sc.hasClients) sc.jumpTo(0);

    _browserStream.sink.add(browserList);
  }

  updateStream() {
    _browserStream.sink.add(browserList);
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
    if (items.isEmpty) return;
    await Future.wait(items.map((i) => i.recheckDownloaded()));
    updateStream();
  }

  void popBrowser() {
    if (BrowserManager().browserCache.length < 2) {
      return;
    }

    browserCache.removeLast();
    if (alphabeticalCache.isNotEmpty) alphabeticalCache.removeLast();
    browserList.clear();
    browserCache[browserCache.length - 1].forEach((el) {
      browserList.add(el);
    });

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

    browserCache.forEach((b) {
      b.removeWhere(
          (e) => e.server == server && e.data == data && e.type == type);
    });
    // Known limitation: removing items shifts subsequent scroll
    // offsets but scrollCache isn't recalculated. On back-nav to a
    // filtered screen the saved offset may be too large — popBrowser
    // clamps to maxScrollExtent so the worst case is "lands at the
    // bottom" rather than crashing.
  }

  void dispose() {
    _migrationSub?.cancel();
    _browserStream.close();
    _browserLabel.close();
    _loading.close();
  }

  Stream<List<DisplayItem>> get browserListStream => _browserStream.stream;
  Stream<String> get browserLabelStream => _browserLabel.stream;
}
