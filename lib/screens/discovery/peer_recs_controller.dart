import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../objects/discovery.dart';
import '../../objects/peer_recs.dart';
import '../../objects/server.dart';
import '../../singletons/api.dart';
import '../../singletons/server_list.dart';
import '../../singletons/settings.dart';
import '../../util/peer_recs_rules.dart';
import 'discovery_jobs_controller.dart' show JobsTimerFactory;
import 'discovery_page_controller.dart' show TasteFetch;
import 'taste_seeds_host.dart';

/// One peers poll (GET /api/v1/discovery/p2p/peers). Never throws: a
/// failure is a status (0 = no answer).
typedef PeersFetch = Future<PeersAnswer> Function();

/// One Add (POST /api/v1/admin/discovery/p2p/peer-dbs/add). Never throws.
typedef PeerAddPost = Future<PeerAddAnswer> Function(String endpointId);

/// What told the page the network may be switched off (mStream plan §3.5
/// R7): a taste refusal, a history answer with no network section, a peers
/// poll refused, or a preview's resolve refused.
enum PeerRecsOffSource { taste, tasteNoNetwork, peers, clip }

/// The Peer Recommendations page's data for one visit (mStream
/// docs/peer-recommendations-plan.md §3.5 R1–R8; a port of the webapp's
/// peerRecsView, webapp/alpha/m.js). One controller per visit: a fresh open
/// is a new controller, so the visit fence is [dispose].
///
/// - Asking (R1, R8): one request id across every ask — a tab tap, New
///   seeds, the window, an R4 re-ask — so the last ask wins. A new batch
///   walks the network alone (`sources: [network]`, 12 seeds, 32 leads, a
///   random seed too) pinned to what the visit pins; its first answer is
///   the batch, whose seeds pin every later ask on it.
/// - Tabs (R2): each tab's answer for the batch is kept, so All and a tab
///   seen before ask nothing. A tab whose peer left the shelf goes back to
///   All (R5).
/// - New seeds (R3): a new batch that keeps the tab; on a random answer the
///   pick is passed over (sent in `exclude`), as Discover's Another pick.
/// - The strip polls (R6): at once, then every 15 s, every 3 s while an Add
///   is out or a row is being added; none while the page is covered or the
///   app is in the background, one at once on return. A poll that changes
///   nothing the strip draws does not notify.
/// - An Add of this page's that lands, the shelf filling under "No peers
///   yet" or emptying under the page asks the tab again on the batch (R4) —
///   once nothing holds the list ([setHolding]: a clip live, a sheet open).
/// - Off (R7): a refusal re-pings the server, one at a time. Off, or no
///   answer, sets [off] (the listing leaves); still on, the page stays.
///
/// It is the configuration bar's and the seeds sheet's [TasteSeedsHost],
/// and the toolbar's New seeds reads it as a [TasteRefreshable], with
/// Discover's semantics; the window is the one Discover remembers.
class PeerRecsController extends ChangeNotifier
    with WidgetsBindingObserver
    implements TasteSeedsHost, TasteRefreshable {
  @override
  final Server server;
  final PeersFetch _fetchPeers;
  final PeerAddPost _postAdd;
  final TasteFetch _fetch;
  final Future<bool> Function(Server) _reping;
  final void Function(int) _saveWindow;
  final JobsTimerFactory _timer;

  /// False leaves the app lifecycle to the caller
  /// ([didChangeAppLifecycleState]; tests).
  final bool watchLifecycle;

  @override
  final DateTime Function() now;

  /// [fetchPeers] / [postAdd] are the page's own routes (PeerRecsApi on the
  /// user's own server). [reping] answers whether the server answered the
  /// re-ping (by default ServerManager.getServerPaths with throwErr; a throw
  /// is no answer, which counts as off — the webapp's peerRecsOff).
  /// [readWindow] / [saveWindow] are the phone's remembered window, shared
  /// with Discover. [pinAtOpen] is the now-playing song when the page
  /// opened (discoveryNowPlayingPin): pinned on every ask of the visit
  /// until the seeds sheet replaces the pins.
  PeerRecsController({
    required this.server,
    required this._fetchPeers,
    required this._postAdd,
    TasteFetch? fetch,
    Future<bool> Function(Server)? reping,
    int Function()? readWindow,
    void Function(int)? saveWindow,
    DateTime Function()? now,
    String? pinAtOpen,
    JobsTimerFactory? timer,
    this.watchLifecycle = true,
  })  : _fetch = fetch ?? ApiManager().fetchDiscoveryTaste,
        _reping = reping ?? _defaultReping,
        _saveWindow = saveWindow ?? _defaultSaveWindow,
        _timer = timer ?? Timer.new,
        now = now ?? DateTime.now {
    final w = (readWindow ?? _defaultReadWindow)();
    _window = kTasteWindows.contains(w) ? w : kTasteDefaultWindow;
    if (pinAtOpen != null && pinAtOpen.trim().isNotEmpty) {
      _pins.add(_appPath(pinAtOpen));
    }
  }

  static int _defaultReadWindow() => SettingsManager().discoverWindow;
  static void _defaultSaveWindow(int w) =>
      unawaited(SettingsManager().setDiscoverWindow(w));

  /// R7's re-ping (plan §3.5): the server's flags read again. A ping that
  /// throws — no answer — is off, as on the web.
  static Future<bool> _defaultReping(Server s) async {
    try {
      await ServerManager().getServerPaths(s, throwErr: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── state ────────────────────────────────────────────────────────────

  late int _window;
  bool _loading = false;
  bool _disabled = false;
  bool _off = false;
  bool _rechecking = false;

  /// The batch's first answer: its seeds pin every tab's ask and draw the
  /// seeds sheet. Null while a new batch is asked, and until one lands.
  TasteResponse? _batch;

  /// The tab's answer on screen.
  TasteResponse? _shown;

  /// Each tab's answer for the batch ('all' or an endpoint id); never an
  /// answer whose walk failed.
  final Map<String, TasteResponse> _answers = {};

  /// The visit's steering, as Discover's: the pins (app paths), the seeds
  /// dropped (oldest first) and the random picks passed over (oldest
  /// first).
  final List<String> _pins = [];
  final List<String> _exclude = [];
  final List<String> _passed = [];
  int _rid = 0;

  PeerView? _peers;
  bool _noRoute = false;
  String? _selected;

  /// This page's Add states before the server says so: endpoint id → the
  /// state and the polls sent when it was stamped.
  Map<String, PeerLocalAdd> _local = {};

  /// The Adds of this page's whose landing re-asks (R4), and those still
  /// out.
  final Set<String> _posted = {};
  final Set<String> _posting = {};

  bool _polling = false;
  bool _paused = false;
  bool _covered = false;
  bool _foreground = true;
  Timer? _pollTimer;
  Duration? _pollDelay;

  /// Polls sent, and the newest one applied (an older one answering late is
  /// dropped).
  int _polls = 0;
  int _answered = 0;

  bool _holding = false;
  bool _pending = false;
  bool _checking = false;
  bool _opened = false;
  bool _observing = false;
  bool _disposed = false;

  /// The strip as last notified: a poll that leaves it alone notifies
  /// nothing.
  String? _drawn;

  @override
  int get window => _window;

  /// An ask is out: the bar's controls are off and its thin line shows.
  /// The answer on screen stays until the new one lands.
  @override
  bool get loading => _loading;

  /// The taste route refused (a 403) and the re-ping found the flags still
  /// on: the scan-pending card, until Check again ([recheck]).
  @override
  bool get disabled => _disabled;

  /// R7 decided: the network is off (or the server did not answer the
  /// re-ping). The listing leaves; nothing more is asked.
  bool get off => _off;

  /// Check again's re-ping is out.
  bool get rechecking => _rechecking;

  /// The batch the seeds sheet shows (the bar's More options is off without
  /// one).
  @override
  TasteResponse? get seeded => _batch;

  /// The tab's answer is on screen, so a call out shows the bar's thin
  /// line over it. This is [shown], not [seeded]: a new batch's ask lets
  /// go of the batch at once, while the old answer stays up until the new
  /// one lands.
  @override
  bool get answerShown => _shown != null;

  @override
  List<TasteSeed> get seeds => _batch?.seeds ?? const [];

  @override
  List<String> get pins => List.unmodifiable(_pins);

  /// The batch's exclusions the seeds sheet shows (and can use again): the
  /// drops, never a random pick passed over that was not dropped too.
  @override
  List<TasteExcluded> get excluded => [
        for (final e in _batch?.excluded ?? const <TasteExcluded>[])
          if (_exclude.contains(e.hash) || !_passed.contains(e.hash)) e,
      ];

  /// The batch was seeded from a random song, not the history.
  @override
  bool get isRandom =>
      _batch?.seedSource == TasteSeedSource.random || _batch?.fallback == true;

  /// The tab's answer on screen; null before one lands and for "Try again".
  TasteResponse? get shown => _shown;

  /// The tab's leads on screen, best first: the same list object until
  /// [shown] changes (what the previews and the grid key on).
  List<DiscoveryLead> get leads =>
      _shown?.network?.results ?? const <DiscoveryLead>[];

  /// What the page draws (plan §2 item 18).
  PeerRecsState get state => peerRecsStateOf(
      shown: _shown, loading: _loading, disabled: _disabled, peers: _peers);

  /// The last peers answer; null before the first and after a 404.
  PeerView? get peers => _peers;

  /// The peers route answered 404 (an older server): the strip is All
  /// alone, and nothing more is polled.
  bool get noRoute => _noRoute;

  /// The strip's tab: null = All, else an endpoint id.
  String? get selected => _selected;

  /// The strip as it is drawn now: every Add state of this page's stands
  /// until a poll answers past it.
  List<PeerStripItem> get stripItems =>
      peerStripItems(_peers, selected: _selected, local: _local).items;

  /// Whether the strip is drawn (webapp M:6630-6634): not before the first
  /// poll answers, nor when it would be All alone — unless the route is
  /// missing (All alone then).
  bool get stripVisible =>
      _noRoute || (_peers != null && stripItems.length >= 2);

  /// A clip is live or a sheet is open: an R4 re-ask waits.
  bool get holding => _holding;

  /// An R4 re-ask waits for holding to end.
  @visibleForTesting
  bool get pending => _pending;

  /// The wait before the poll scheduled now; null when none is.
  @visibleForTesting
  Duration? get nextPollIn =>
      _pollTimer != null && _pollTimer!.isActive ? _pollDelay : null;

  /// Whether the strip still polls (false after a 403, a 404, off, or
  /// dispose).
  @visibleForTesting
  bool get polling => _polling;

  // ── TasteRefreshable ─────────────────────────────────────────────────

  /// The toolbar's New seeds: an answer's batch is up, no ask is out, and
  /// nothing latched the page off.
  @override
  bool get canRefresh => !_off && !_disabled && !_loading && _batch != null;

  /// New seeds and pull to refresh (R3): a new batch that keeps the tab (so
  /// its `networkPeers` too). On a random batch its pick is passed over —
  /// sent in `exclude` from now on, newest last — as Discover's Another
  /// pick does, so the next walk starts from a song not seen this visit.
  /// Nothing happens while an ask is out, as on Discover: the "Nothing
  /// new" card's New seeds and pull to refresh stay live then, and a
  /// second tap would only send the same ask again.
  @override
  Future<void> refresh() async {
    if (_disposed || _off || _loading) return;
    if (isRandom) {
      for (final s in seeds) {
        if (s.pinned) continue;
        _passed
          ..remove(s.hash)
          ..add(s.hash);
      }
    }
    await _ask();
  }

  // ── opening ──────────────────────────────────────────────────────────

  /// The page opened: one R1 ask and the first poll, together. A server
  /// whose flags no longer say yes is [off] at once, with no call.
  Future<void> open() async {
    if (_disposed || _opened) return;
    _opened = true;
    if (server.peerRecsAvailable != true) {
      _off = true;
      notifyListeners();
      return;
    }
    _attachLifecycle();
    _polling = true;
    await Future.wait([_ask(), _poll()]);
  }

  // ── asking (R1, R2, R8) ──────────────────────────────────────────────

  String _tabKey(String? id) => id ?? 'all';

  /// One ask for the tab on screen. [batch]: on the batch on screen,
  /// pinned to its seeds (a tab, Try again, an R4 re-ask); a new batch when
  /// there is none to pin to — and without [batch] always (R3: its first
  /// answer becomes the batch, and the last batch's tab answers go).
  ///
  /// It says how the ask ended, for [setWindow]: false when it got no
  /// answer or was refused (a 403), true when its answer was taken, and
  /// null when it was not sent or was dropped, because a newer ask or a
  /// kept tab's answer took over, the page went off, or the visit ended.
  Future<bool?> _ask({bool batch = false}) async {
    if (_disposed || _off || _disabled) return null;
    final tab = _selected;
    final rid = ++_rid;
    final b = _batch;
    final pinned = batch && b != null
        ? peerRecsBatchRequest(b,
            window: _window, exclude: _excludeSent(), peer: tab)
        : null;
    if (pinned == null) {
      _batch = null;
      _answers.clear();
    }
    _loading = true;
    notifyListeners();
    var r = await _taste(pinned ?? _newBatchRequest(tab));
    if (_disposed || rid != _rid || _off) return null;
    if (pinned == null &&
        _passed.isNotEmpty &&
        r.data != null &&
        peerNoPickLeft(r.data!)) {
      // Every song the random fallback could draw was passed over this
      // visit: the empty answer would read as "scan pending", which it is
      // not. Let the passed picks go and ask once more (the list is empty
      // then, so once), so the picks start over.
      _passed.clear();
      r = await _taste(_newBatchRequest(tab));
      if (_disposed || rid != _rid || _off) return null;
    }
    _loading = false;
    return _answer(r, tab);
  }

  /// The taste call; a throw is no answer ("Try again"), never a page
  /// stuck loading.
  Future<DiscoveryFetchResult<TasteResponse>> _taste(TasteRequest req) async {
    try {
      return await _fetch(server, req);
    } catch (_) {
      return const DiscoveryFetchResult.error();
    }
  }

  TasteRequest _newBatchRequest(String? tab) => peerRecsRequest(
      window: _window, pins: _pins, exclude: _excludeSent(), peer: tab);

  /// The request's exclusions, oldest first: the drops (the newest
  /// [kTasteExcludeMax]), then the picks passed over that are not dropped
  /// too, the newest that fit — Discover's rule.
  List<String>? _excludeSent() {
    final drops = _exclude.length > kTasteExcludeMax
        ? _exclude.sublist(_exclude.length - kTasteExcludeMax)
        : _exclude;
    final passed = _passed.where((h) => !drops.contains(h)).toList();
    final room = kTasteExcludeMax - drops.length;
    final ex = [
      ...drops,
      if (room > 0)
        ...passed.sublist(passed.length > room ? passed.length - room : 0),
    ];
    return ex.isEmpty ? null : ex;
  }

  /// An ask's answer for [tab] (webapp peerRecsAnswer, M:6147-6164): a
  /// refusal, or no network on a history answer, may be the network
  /// switched off (R7); a tab whose peer left the shelf goes back to All
  /// (R5), the answer kept for no tab; otherwise it is shown and kept for
  /// its tab — the first of a batch as the batch — unless its walk failed.
  /// No answer at all is "Try again", kept for nothing. Returns how the
  /// ask ended, as [_ask] does.
  Future<bool?> _answer(
      DiscoveryFetchResult<TasteResponse> r, String? tab) async {
    if (r.disabled) {
      _disabled = true;
      notifyListeners();
      final rid = _rid;
      await offCheck(PeerRecsOffSource.taste);
      // Check again may have asked again during the re-ping. That ask
      // went out with the window in force, so this refusal no longer
      // speaks for it. Off bumps the request id too, and is still a
      // refusal.
      return _off || rid == _rid ? false : null;
    }
    final res = r.data;
    if (res == null) {
      _show(null);
      return false;
    }
    if (res.seedSource != TasteSeedSource.random && res.network == null) {
      notifyListeners();
      // The re-ping can take seconds. A tab tap, New seeds or a kept
      // answer shown meanwhile is newer than this answer (the last ask
      // wins), so it is not wiped with "Try again". When another check is
      // already out, offCheck returns at once: that check decides whether
      // the page goes off, and this answer is "Try again" now.
      final rid = _rid;
      await offCheck(PeerRecsOffSource.tasteNoNetwork);
      if (_disposed || _off || rid != _rid) return null;
      _show(null);
      return true;
    }
    if (res.network?.reason == NetworkReason.notOnShelf && _selected != null) {
      _selected = null;
      final all = _answers[_tabKey(null)];
      if (all != null) {
        _show(all);
        return true;
      }
      return _ask(batch: true);
    }
    _batch ??= res;
    final key = _tabKey(tab);
    if (res.network?.reason == NetworkReason.error) {
      _answers.remove(key);
    } else {
      _answers[key] = res;
    }
    _show(res);
    return true;
  }

  void _show(TasteResponse? res) {
    _shown = res;
    notifyListeners();
  }

  /// A strip tab (R2; null = All): its answer for this batch when the page
  /// has it — the ask still out (another tab's) dropped — else asked on the
  /// batch. The last tap wins.
  Future<void> select(String? endpointId) async {
    if (_disposed || _off) return;
    if (endpointId != null && !isEndpointId(endpointId)) return;
    _selected = endpointId;
    final kept = _batch != null ? _answers[_tabKey(endpointId)] : null;
    if (kept != null) {
      ++_rid;
      _loading = false;
      _show(kept);
      return;
    }
    notifyListeners();
    await _ask(batch: true);
  }

  /// "Try again": the tab asked again on the batch when there is one (a
  /// tab's failed ask is asked pinned), else a new batch.
  Future<void> retry() => _ask(batch: true);

  /// The configuration bar's window (Discover's setWindow): remembered on
  /// this phone — Discover's window too — and a new batch asked. Under the
  /// 403 latch nothing changes. A call that fails, or is refused, puts the
  /// old window back. A call dropped for a newer ask (a tab tap, a poll's
  /// re-ask) leaves the window alone: the newer ask went out with it.
  @override
  Future<void> setWindow(int w) async {
    if (_disposed ||
        _off ||
        _disabled ||
        w == _window ||
        !kTasteWindows.contains(w)) {
      return;
    }
    final before = _window;
    _window = w;
    _saveWindow(w);
    notifyListeners();
    final answered = await _ask();
    if (_disposed) return;
    if (answered == false && _window == w) {
      _window = before;
      _saveWindow(before);
      notifyListeners();
    }
  }

  /// The seeds sheet's "Use these N" (Discover's applySeeds): [drop] seed
  /// hashes left out for the visit, [restore] dropped ones used again,
  /// [pins] the visit's pins from now on. Then a new batch.
  @override
  Future<void> applySeeds({
    Set<String> drop = const {},
    Set<String> restore = const {},
    required List<String> pins,
  }) async {
    _exclude.removeWhere(restore.contains);
    for (final h in drop) {
      if (!_exclude.contains(h)) _exclude.add(h);
    }
    _pins
      ..clear()
      ..addAll(pins.map(_appPath).take(kTastePinMax));
    if (_disposed) return;
    await _ask();
  }

  // ── the strip's poll (R6) ────────────────────────────────────────────

  /// One poll (webapp peerRecsPoll, M:5973-6005): skipped while the page is
  /// covered or the app is in the background (one at once on return). A
  /// 403 may be the network switched off (R7), and stops the poll; a 404 is
  /// an older server: All alone, no more polls. Any other failure keeps the
  /// last strip.
  Future<void> _poll() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (_disposed || !_polling) return;
    if (_covered || !_foreground) {
      _paused = true;
      return;
    }
    final n = ++_polls;
    PeersAnswer a;
    try {
      a = await _fetchPeers();
    } catch (_) {
      a = const PeersAnswer(0); // no answer: the last strip stays
    }
    if (_disposed || !_polling) return;
    if (a.status == 403) {
      _polling = false;
      unawaited(offCheck(PeerRecsOffSource.peers));
      return;
    }
    if (a.status == 404) {
      _polling = false;
      _noRoute = true;
      _peers = null;
      notifyListeners();
      return;
    }
    final view = a.view;
    if (a.status == 200 && view != null && n > _answered) {
      _answered = n;
      _takePeers(view, n);
    }
    _pollIn(peerPollDelay(stripItems, _posting.length));
  }

  /// The one timer: the next poll in [delay]. None while the page is
  /// covered or the app is in the background (the poll is then owed: one
  /// at once on return), and none once polling stopped.
  void _pollIn(Duration delay) {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (_disposed || !_polling) return;
    if (_covered || !_foreground) {
      _paused = true;
      return;
    }
    _pollDelay = delay;
    _pollTimer = _timer(delay, () => unawaited(_poll()));
  }

  /// A poll's answer [view], poll [n] (webapp peerRecsTakePeers,
  /// M:6034-6061). The tab's peer gone from the shelf goes back to All
  /// (R5: its answer for the batch, else asked on it); an Add of this
  /// page's that landed, or the shelf filling while "No peers yet" shows,
  /// or emptying, asks the tab again on the batch (R4; plan §2 item 18) —
  /// every tab's answer goes at once, even while the re-ask waits. Someone
  /// else's Add, or a rotation, only moves the strip.
  void _takePeers(PeerView view, int n) {
    final land = peerLanded(_peers, view, _posted,
        showingNoPeers: state == PeerRecsState.noPeers);
    final emptied = peerEmptied(_peers, view);
    _posted
      ..removeAll(land.ids)
      ..removeAll(land.failed);
    _peers = view;
    final strip =
        peerStripItems(view, selected: _selected, local: _local, poll: n);
    _local = Map.of(strip.local);
    final reask = land.reask || emptied;
    if (reask) _answers.clear();
    if (strip.fallback) _selected = null;
    if (reask || strip.fallback || _stripSignature() != _drawn) {
      notifyListeners();
    }
    if (strip.fallback) {
      final all = _answers[_tabKey(null)];
      if (all != null) {
        ++_rid;
        _loading = false;
        _show(all);
      } else {
        unawaited(_ask(batch: true));
      }
    } else if (reask || (_pending && !_holding)) {
      _pending = false;
      _reask();
    }
  }

  /// What the strip draws, as one string: every item, whether the route is
  /// missing, and how many shelf snapshots are searchable (the state reads
  /// it: "No peers yet"; null before the first answer).
  String _stripSignature() => [
        for (final i in stripItems) i.signature,
        '$_noRoute',
        '${_peers?.searchable}',
      ].join('\u0001');

  /// R4's re-ask: the tab on the batch — once nothing holds the list (the
  /// list never changes under a preview or an open sheet).
  void _reask() {
    if (_holding) {
      _pending = true;
      return;
    }
    _answers.clear();
    unawaited(_ask(batch: true));
  }

  /// A clip is live or a sheet is open ([holding]): R4 re-asks wait. When
  /// it ends, a waiting re-ask runs at once (the web waits for the next
  /// poll; the phone build plan's D10.3).
  void setHolding(bool holding) {
    if (_disposed || holding == _holding) return;
    _holding = holding;
    if (!holding && _pending) {
      _pending = false;
      _reask();
    }
  }

  /// The page is covered (another frame, a pushed screen, album detail,
  /// Now Playing expanded): no poll until it is uncovered, then one at
  /// once (R6). A modal sheet over the page is not a cover.
  void setCovered(bool covered) {
    if (_disposed || covered == _covered) return;
    _covered = covered;
    if (covered) {
      _stopTimer();
    } else {
      _catchUp();
    }
  }

  void _stopTimer() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _paused = true;
  }

  /// Back in front with a poll owed: one at once.
  void _catchUp() {
    if (!_paused || _covered || !_foreground || _disposed) return;
    _paused = false;
    unawaited(_poll());
  }

  void _attachLifecycle() {
    if (!watchLifecycle || _observing) return;
    try {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    } catch (_) {
      // No binding (a plain unit test): the caller drives the lifecycle.
    }
  }

  /// In the background the poll stops; back in front, one at once (R6).
  /// `inactive` is a passing state (a system sheet, the app switcher).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bool fg;
    switch (state) {
      case AppLifecycleState.resumed:
        fg = true;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        fg = false;
      case AppLifecycleState.inactive:
        return;
    }
    if (fg == _foreground || _disposed) return;
    _foreground = fg;
    if (fg) {
      _catchUp();
    } else {
      _stopTimer();
    }
  }

  // ── Add (plan §3.3) ──────────────────────────────────────────────────

  /// An admin's "+" or its Try again (webapp peerRecsAdd, M:6106-6125):
  /// "Adding…" at once and the poll at 3 s, then the POST, read by its code
  /// alone ([peerAddOutcome]). Only an add item whose press Adds, and not
  /// one already posting: "Adding…" and "No room" are inert, and a member
  /// has no add item at all.
  Future<void> add(String endpointId) async {
    if (_disposed || _off || _posting.contains(endpointId)) return;
    final item = stripItems
        .where((i) => i.kind == PeerItemKind.add && i.id == endpointId)
        .firstOrNull;
    if (item == null || item.act != PeerItemAct.add) return;
    _local[endpointId] = (state: PeerAddView.adding, poll: _polls);
    _posted.add(endpointId);
    _posting.add(endpointId);
    notifyListeners();
    _pollIn(kPeerPollFast);
    PeerAddAnswer a;
    try {
      a = await _postAdd(endpointId);
    } catch (_) {
      a = const PeerAddAnswer(0); // no answer: "Try again"
    }
    _posting.remove(endpointId);
    if (_disposed) return;
    final o = peerAddOutcome(a);
    final local = o.local;
    if (local != null) {
      _local[endpointId] = (state: local, poll: _polls);
    } else {
      _local.remove(endpointId);
    }
    // Only an Add still on its way can land (R4).
    if (o.outcome != PeerAddOutcome.adding &&
        o.outcome != PeerAddOutcome.landed) {
      _posted.remove(endpointId);
    }
    notifyListeners();
    _pollIn(o.pollNow
        ? Duration.zero
        : peerPollDelay(stripItems, _posting.length));
  }

  // ── off (R7) ─────────────────────────────────────────────────────────

  /// R7 (webapp peerRecsOff, M:6185-6212): one re-ping at a time. No
  /// answer, or the flags off after it → [off] (the listing leaves). Still
  /// on: a taste refusal stays the scan-pending card ([disabled]); a
  /// history answer with no network is "Try again", which its ask shows
  /// unless a newer one took over; a refused poll leaves the page as it
  /// is, the poll stopped; a refused preview, nothing.
  Future<void> offCheck(PeerRecsOffSource source) async {
    if (_checking || _disposed || _off) return;
    _checking = true;
    final answered = await _repinged();
    _checking = false;
    if (_disposed) return;
    if (!answered || server.peerRecsAvailable != true) {
      _goOff();
      return;
    }
    switch (source) {
      case PeerRecsOffSource.taste:
        notifyListeners();
      case PeerRecsOffSource.tasteNoNetwork:
        // The answer's own ask shows "Try again" ([_answer]), and only
        // when no newer ask took over during the re-ping.
        break;
      case PeerRecsOffSource.peers:
      case PeerRecsOffSource.clip:
        break;
    }
  }

  /// The re-ping; a throw is no answer (off).
  Future<bool> _repinged() async {
    try {
      return await _reping(server);
    } catch (_) {
      return false;
    }
  }

  void _goOff() {
    _off = true;
    _rechecking = false;
    _polling = false;
    _loading = false;
    ++_rid;
    _pollTimer?.cancel();
    _pollTimer = null;
    notifyListeners();
  }

  /// "Check again" on the scan-pending card: re-ping first (config before
  /// data); off → as [offCheck]. Still on: the latch and the picks passed
  /// over go, and a new batch is asked.
  Future<void> recheck() async {
    if (_rechecking || _disposed || _off) return;
    _rechecking = true;
    notifyListeners();
    final answered = await _repinged();
    if (_disposed) return;
    if (!answered || server.peerRecsAvailable != true) {
      _goOff();
      return;
    }
    _disabled = false;
    _passed.clear();
    _rechecking = false;
    await _ask();
  }

  // ── copy, the sheet ──────────────────────────────────────────────────

  /// Copy list: the tab's leads on screen, one "Artist - Title" a line.
  String copyListText() => peerCopyListText(leads);

  /// The title of the batch seed [lead] sounds like (its `seedHash`), for
  /// the lead sheet's match line; null when none is known.
  String? seedTitleOf(DiscoveryLead lead) {
    final h = lead.seedHash;
    if (h == null) return null;
    for (final s in [...seeds, ...?_shown?.seeds]) {
      if (s.hash != h) continue;
      final t = s.metadata?.title;
      if (t != null && t.trim().isNotEmpty) return t;
    }
    return null;
  }

  // ── plumbing ─────────────────────────────────────────────────────────

  @override
  void notifyListeners() {
    if (_disposed) return;
    _drawn = _stripSignature();
    super.notifyListeners();
  }

  /// Idempotent: the listing lets go of its controller on its own, and a
  /// test may dispose the one it made. Stops the poll and the lifecycle
  /// watch; an answer still out is dropped.
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _polling = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    super.dispose();
  }
}

/// App-side paths carry the leading slash; TasteRequest.toJson strips it.
String _appPath(String p) => p.startsWith('/') ? p : '/$p';
