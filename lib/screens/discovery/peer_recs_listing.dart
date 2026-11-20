import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../media/preview_player.dart';
import '../../objects/discovery.dart';
import '../../objects/discovery_plugins.dart';
import '../../objects/display_item.dart';
import '../../objects/server.dart';
import '../../singletons/app_messenger.dart';
import '../../singletons/app_route_observer.dart';
import '../../singletons/browser_list.dart';
import '../../util/discovery_plugins_api.dart' show ownServerOf;
import '../../util/peer_recs_api.dart';
import '../../util/peer_recs_rules.dart';
import 'copies_hub.dart';
import 'discovery_jobs_controller.dart';
import 'discovery_listing.dart' show discoveryNowPlayingPin;
import 'keep_toast.dart';
import 'peer_recs_controller.dart';
import 'peer_recs_previews.dart';

/// The Peer Recommendations frame's one item's type (mStream
/// docs/peer-recommendations-plan.md §4.2 PH6). The frame is that one
/// marker: the view draws from the controller itself, so a poll or an
/// answer never rebuilds the browser's list.
const String kPeerRecsBar = 'peerRecsBar';

/// The toolbar's label on the Peer Recommendations frame
/// (browserChromeLabel translates it).
const String kPeerRecsLabel = 'Peer Recommendations';

/// Owns one Peer Recommendations visit behind its frame on the browser
/// stack (mStream plan §2 items 14–16, §3.5 R6–R7; the shape of
/// DiscoveryListing): the page's controller, its clip session and the own
/// server's plug-in jobs. One at a time: opening the page again replaces
/// the visit. The visit lives as long as its frame: Back, a server switch
/// or anything else that takes the frame off the stack ends it — the clip
/// ends (`sheetClosed`, the song comes back), the poll stops — and the
/// next open is a fresh visit.
///
/// While the frame is covered — another browser frame on top, a page route
/// over the home (pushed straight over it or over a sheet), album detail,
/// Now Playing expanded, the app drawer open — the page's clip ends
/// (`stopped`) and the poll pauses; back in front, one poll at once (R6)
/// and the toolbar's label again. A modal bottom sheet over the page is no
/// cover: the poll goes on under it. A frame pushed over the page keeps the
/// page's scroll offset, and the page is drawn there again on Back.
///
/// Off (R7): when the controller finds the network switched off, the frame
/// pops — only from the top, and never under a sheet, a dialog or a page
/// over the page: a covered page, or one with any route over it, pops once
/// it is the top again with that route gone — and the home is drawn again
/// without the card.
class PeerRecsListing {
  PeerRecsListing._();
  static final PeerRecsListing _instance = PeerRecsListing._();
  factory PeerRecsListing() => _instance;

  PeerRecsController? _c;
  PeerRecsPreviews? _previews;
  DiscoveryJobsController? _jobs;
  List<DisplayItem>? _frame;
  StreamSubscription<List<DisplayItem>>? _stackSub;
  StreamSubscription<DisplayItem?>? _albumSub;
  bool _watchingCovers = false;

  bool _covered = false;
  bool _sheetOpen = false;

  // R7 found the page off while it could not pop: it pops once it is the
  // top again with no route over it and no lead sheet up.
  bool _popOnUncover = false;

  // The view's route (the home). R7 waits while another route is over it.
  // It outlives the view: the route stays while a frame covers the page.
  Route<dynamic>? _viewRoute;

  // The frame was on top at the last cover check.
  bool _wasOnTop = false;

  // The page's scroll offset when a frame was pushed over it. The view
  // scrolls back to it when it is drawn again.
  double? _restoreOffset;

  // The leads the previews were last told about (by identity).
  List<DiscoveryLead>? _leadsSeen;

  // The view on screen: where a toast the listing sends itself finds its
  // words.
  BuildContext? _viewContext;

  /// The open visit's controller, or null.
  PeerRecsController? get controller => _c;

  /// The open visit's clip session, or null.
  PeerRecsPreviews? get previews => _previews;

  /// The own server's plug-in jobs (CopiesHub's: shared, never disposed
  /// here), or null when its plug-ins are off.
  DiscoveryJobsController? get jobs => _jobs;

  /// Whether [list] is the Peer Recommendations frame: its first item is
  /// the page's marker.
  static bool isListing(List<DisplayItem> list) =>
      list.isNotEmpty && list.first.type == kPeerRecsBar;

  /// Push the page for [server] onto the browser stack and ask it: one R1
  /// ask and the first poll. [controller], [previews] and [jobs] are
  /// injected by tests; [jobs] stands for the own server's CopiesHub jobs.
  void open(Server server,
      {PeerRecsController? controller,
      PeerRecsPreviews? previews,
      DiscoveryJobsController? jobs}) {
    _detach();
    // The own server's plug-ins (plan §2 item 16): the sheet's gate and the
    // listing the preview plug-in is read from. Never CopiesHub().visit:
    // the page's cards carry no copy state. The listing is read again each
    // visit, as on the web.
    final own = ownServerOf(server);
    var j = jobs;
    if (j == null && own != null && own.discoveryPluginsAvailable == true) {
      j = CopiesHub().jobsFor(own);
    }
    if (j != null) unawaited(j.listing == null ? j.activate() : j.regate());
    _jobs = j;

    final PeerRecsController c;
    if (controller != null) {
      c = controller;
    } else {
      final api = PeerRecsApi(server);
      c = PeerRecsController(
        server: server,
        fetchPeers: api.peers,
        postAdd: api.add,
        pinAtOpen: discoveryNowPlayingPin(server),
      );
    }
    _c = c;

    final p = previews ??
        PeerRecsPreviews(
          resolve: (plugin, rec) => j == null
              ? Future<PluginPreview?>.value(null)
              : j.api.preview(plugin, rec),
          provider: () => peerPreviewProvider(j?.listing),
          onRefused: _refused,
          onMiss: _miss,
        );
    _previews = p;

    final frame = [
      DisplayItem(server, kPeerRecsLabel, kPeerRecsBar, null, null, null),
    ];
    _frame = frame;
    BrowserManager().setBrowserLabel(kPeerRecsLabel);
    BrowserManager().addListToStack(frame);

    _stackSub = BrowserManager().browserListStream.listen((_) => _onStack());
    _albumSub =
        BrowserManager().albumDetailStream.listen((_) => _syncCover());
    nowPlayingExpanded.addListener(_syncCover);
    appRouteObserver.pageRouteOverHome.addListener(_syncCover);
    appDrawerOpen.addListener(_syncCover);
    _watchingCovers = true;

    _leadsSeen = c.leads;
    p.listChanged(c.leads);
    c.addListener(_onController);
    p.addListener(_onPreviews);
    j?.addListener(_onJobs);
    _syncCover();
    unawaited(c.open());
  }

  /// The view's route, told again whenever a route rises over it or goes
  /// (a sheet, a dialog, a page). A page R7 found off while a route was over
  /// it pops once its route is the top again.
  void setViewRoute(Route<dynamic>? route) {
    _viewRoute = route;
    if (_popOnUncover && _routeOnTop) {
      // Told from the view's didChangeDependencies, inside a build. The pop
      // and the clip's end wait until the build is over.
      scheduleMicrotask(() {
        if (_popOnUncover) _leave();
      });
    }
  }

  /// The offset the page had when a frame was pushed over it, given once.
  /// The view takes it as it is drawn again; a fresh visit has none.
  double? takeRestoreOffset() {
    final o = _restoreOffset;
    _restoreOffset = null;
    return o;
  }

  /// Holding while the lead sheet is up (R4 waits). A no-op unless [visit]
  /// is still the attached visit's controller: the sheet can outlive the
  /// visit (a pop, an R7 leave, a detach). A sheet closing on a page R7
  /// found off lets it pop.
  void setSheetOpen(bool open, {required PeerRecsController visit}) {
    final c = _c;
    final p = _previews;
    if (c == null || p == null || !identical(visit, c)) return;
    if (open == _sheetOpen) return;
    _sheetOpen = open;
    c.setHolding(p.isLive || _sheetOpen);
    if (!open && _popOnUncover) _leave();
  }

  /// Whether the visit's lead sheet is up.
  @visibleForTesting
  bool get sheetOpen => _sheetOpen;

  /// Whether the frame counts as covered now.
  @visibleForTesting
  bool get covered => _covered;

  /// Every toast the page sends (Copy list's and a card's "Copied", the
  /// band link's failure, a refused or missed preview's). The band itself
  /// tells KeepToast how tall it is while it shows, so every toast floats
  /// over it, this page's or not.
  void toast(String message) {
    final ctx = _viewContext;
    KeepToast.show(ctx != null && ctx.mounted ? ctx : null, message);
  }

  /// The view on screen at [context] (PeerRecsView): where a toast the
  /// listing sends itself finds its words.
  void attachView(BuildContext context) => _viewContext = context;

  /// The view at [context] went away.
  void detachView(BuildContext context) {
    if (identical(_viewContext, context)) _viewContext = null;
  }

  // ── the visit ────────────────────────────────────────────────────────

  void _onController() {
    final c = _c;
    final p = _previews;
    if (c == null || p == null) return;
    final leads = c.leads;
    if (!identical(leads, _leadsSeen)) {
      _leadsSeen = leads;
      p.listChanged(leads);
    }
    if (c.off) _leave();
  }

  void _onPreviews() {
    final c = _c;
    final p = _previews;
    if (c == null || p == null) return;
    c.setHolding(p.isLive || _sheetOpen);
  }

  void _onJobs() => _previews?.providerCheck();

  /// Every browser-stack change: let go once the frame is off the stack;
  /// else the cover may have moved, and a page R7 found off pops once it is
  /// the top again.
  void _onStack() {
    final frame = _frame;
    if (frame == null) return;
    final stack = BrowserManager().browserCache;
    if (!stack.any((f) => identical(f, frame))) {
      _detach();
      return;
    }
    _syncCover();
    if (_popOnUncover) _leave();
  }

  bool get _onTop {
    final frame = _frame;
    final stack = BrowserManager().browserCache;
    return frame != null && stack.isNotEmpty && identical(stack.last, frame);
  }

  /// Covered: another frame on top, a page route over the home, album
  /// detail, Now Playing expanded or the app drawer open. Covering ends the
  /// page's clip (`stopped`) and pauses the poll; uncovering polls once at
  /// once. On top, the toolbar is named again (the browser keeps one label,
  /// not one per frame).
  void _syncCover() {
    final c = _c;
    final p = _previews;
    if (c == null || p == null) return;
    final onTop = _onTop;
    if (_wasOnTop && !onTop) _keepOffset();
    _wasOnTop = onTop;
    final covered = !onTop ||
        appRouteObserver.pageRouteOverHome.value ||
        BrowserManager().albumDetail != null ||
        nowPlayingExpanded.value ||
        appDrawerOpen.value;
    if (covered != _covered) {
      _covered = covered;
      if (covered) {
        unawaited(p.leave(PreviewEnd.stopped));
        c.setCovered(true);
      } else {
        c.setCovered(false);
      }
    }
    if (onTop && BrowserManager().listName != kPeerRecsLabel) {
      BrowserManager().setBrowserLabel(kPeerRecsLabel);
    }
  }

  /// A frame was just pushed over the page. addListToStack saved the
  /// page's offset as the frame's scrollCache entry (scrollCache[i] belongs
  /// to frame i), then jumped the list to the top. Keep that offset for the
  /// view to restore.
  void _keepOffset() {
    final frame = _frame;
    final bm = BrowserManager();
    final i = bm.browserCache.indexWhere((f) => identical(f, frame));
    _restoreOffset =
        i >= 0 && i < bm.scrollCache.length ? bm.scrollCache[i] : null;
  }

  /// Whether the view's route is the top route: no sheet, dialog or page
  /// over it. A route no longer on a navigator holds nothing.
  bool get _routeOnTop {
    final r = _viewRoute;
    return r == null || !r.isActive || r.isCurrent;
  }

  /// R7: the network is off. On top with no route over the page and no lead
  /// sheet up, the frame pops and the home is drawn again (its cached frame
  /// still holds the card). Else it pops once it is the top again with that
  /// route gone and the sheet closed. Only the top is ever popped, and the
  /// frame never changes under a sheet (the lead sheet, the seeds sheet,
  /// any other) or a page over it.
  void _leave() {
    if (_frame == null) return;
    if (!_onTop || _sheetOpen || !_routeOnTop) {
      _popOnUncover = true;
      return;
    }
    _popOnUncover = false;
    BrowserManager().popBrowser();
    _detach();
    if (BrowserManager.isHomeList(BrowserManager().browserList)) {
      BrowserManager().goToNavScreen();
    }
  }

  void _detach() {
    final c = _c;
    final p = _previews;
    final j = _jobs;
    final stackSub = _stackSub;
    final albumSub = _albumSub;
    _stackSub = null;
    _albumSub = null;
    // Possibly inside this subscription's own event: cancelling there is
    // safe, it only stops later events.
    unawaited(stackSub?.cancel());
    unawaited(albumSub?.cancel());
    if (_watchingCovers) {
      nowPlayingExpanded.removeListener(_syncCover);
      appRouteObserver.pageRouteOverHome.removeListener(_syncCover);
      appDrawerOpen.removeListener(_syncCover);
      _watchingCovers = false;
    }
    // Let go at once, so a sheet's late setSheetOpen(false) finds no visit.
    _c = null;
    _previews = null;
    _jobs = null;
    _frame = null;
    _sheetOpen = false;
    _popOnUncover = false;
    _covered = false;
    _wasOnTop = false;
    // A fresh visit starts at the top.
    _restoreOffset = null;
    _leadsSeen = null;
    c?.removeListener(_onController);
    j?.removeListener(_onJobs);
    if (p != null) {
      // Unhooked first: the clip ending must not let a waiting R4 re-ask
      // go out as the page is left.
      p.removeListener(_onPreviews);
      // The page is left: its clip ends and the song comes back; with none
      // live this frees the clip player.
      unawaited(p.leave(PreviewEnd.sheetClosed));
    }
    // Possibly inside the controller's own notifyListeners (R7), where
    // disposing would assert: after it returns. The answers store is never
    // disposed (a sheet still open may put into it); the jobs are the
    // hub's.
    if (c != null || p != null) {
      scheduleMicrotask(() {
        c?.dispose();
        p?.dispose();
      });
    }
  }

  /// A resolve answered 403 / 404 (the session is idle by now): the
  /// listing is read again, the user is told, and R7 checks the network.
  void _refused() {
    unawaited(_jobs?.regate());
    final l = _words();
    if (l != null) toast(l.discoverLeadOptionOff);
    unawaited(_c?.offCheck(PeerRecsOffSource.clip));
  }

  /// A single press found no clip.
  void _miss() {
    final l = _words();
    if (l != null) toast(l.peerRecsNoPreview);
  }

  AppLocalizations? _words() {
    for (final ctx in [_viewContext, rootNavigatorKey.currentContext]) {
      if (ctx == null || !ctx.mounted) continue;
      final l = Localizations.of<AppLocalizations>(ctx, AppLocalizations);
      if (l != null) return l;
    }
    return null;
  }
}
