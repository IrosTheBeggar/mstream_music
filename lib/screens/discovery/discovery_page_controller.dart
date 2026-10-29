import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../objects/discovery.dart';
import '../../objects/display_item.dart';
import '../../objects/metadata.dart';
import '../../objects/mood_filter.dart';
import '../../objects/server.dart';
import '../../singletons/api.dart';
import '../../singletons/server_list.dart';
import '../../singletons/settings.dart';
import '../../theme/velvet_theme.dart';
import 'discovery_jobs_controller.dart';

typedef TasteFetch = Future<DiscoveryFetchResult<TasteResponse>> Function(
    Server server, TasteRequest req);

/// Rows asked of the library call. The browser listing shows every one (it
/// scrolls), so there is no "See all".
const TasteLimits kDiscoveryMainLimits = TasteLimits(tracks: 24, albums: 8);

/// Rows per peer asked of the peers call.
const TasteLimits kDiscoveryPeersLimits = TasteLimits(peers: 10);

/// Album cards built from the connected servers' rows, at most (the
/// webapp's ALBUM_STRIP_MAX).
const int kDiscoveryPeerAlbumsMax = 12;

/// Discover's data for one server (plan §3.1, §4.2) — what the browser
/// listing (discovery_listing.dart) is built from: two taste calls — the
/// library, then peers on its own so the library never waits out the 4 s
/// peer deadline — with request-id guards, and a per-call 403 latch plus ONE
/// re-ping to tell "switched off" from "scan pending".
///
/// One batch per visit across the sections: every call draws its own random
/// batch of seeds, so the peers call goes out AFTER the library answer
/// lands, pinned to that answer's seeds ([peersRequest]) — the connected
/// servers' rows are built from the very batch the seeds sheet shows. A
/// random library answer makes no peers call (the server asks no connected
/// server for a random seed).
///
/// Discover is the play-now page (plan §2.13, 2026-10-11): it asks only for
/// songs you can play now — the library and the connected (federated)
/// servers. The P2P network's leads are a later Explore surface's, so the
/// main call asks `sources: [library]` only.
///
/// The feature is simple (plan §2.13, 2026-10-14): the server reads this
/// account's song history and seeds each call from a RANDOM batch of it, so
/// every open — and every tap — is a new answer, and that is the point.
/// Nothing is stored server-side and nothing is reused here: every open and
/// every refresh asks, and the answer on screen stays up until the new one
/// lands. Discover steers the seeds only for a targeted query, and only for
/// the visit: the window (remembered on this phone,
/// [SettingsManager.discoverWindow]), pins, and seeds dropped (sent in
/// `exclude`). The now-playing song is pinned ONCE, at open ([pinAtOpen])
/// — the controller never watches playback, so a track change never
/// reshuffles the listing under the user's thumb (plan §2.3).
class DiscoveryPageController extends ChangeNotifier {
  final Server server;

  /// The visit's plug-in jobs (Keep a copy): the listing and destination,
  /// the caller's jobs, and a batch lookup of the connected servers' rows
  /// after every answer of theirs (and their Try again) and after a job
  /// ends. Inert while the server's plug-ins are off. Its changes are this
  /// controller's (the markers are drawn from the listing).
  final DiscoveryJobsController jobs;
  final bool _ownsJobs;
  final TasteFetch _fetch;
  final Future<void> Function(Server) _reping;
  final void Function(int) _saveWindow;
  final DateTime Function() now;

  /// [readWindow] / [saveWindow] are the phone's remembered window
  /// (SettingsManager by default; tests inject their own). [jobs] is
  /// injected by tests (an injected one is the caller's to dispose).
  DiscoveryPageController({
    required this.server,
    TasteFetch? fetch,
    Future<void> Function(Server)? reping,
    int Function()? readWindow,
    void Function(int)? saveWindow,
    DateTime Function()? now,
    String? pinAtOpen,
    DiscoveryJobsController? jobs,
  })  : jobs = jobs ?? DiscoveryJobsController(server: server),
        _ownsJobs = jobs == null,
        _fetch = fetch ?? ApiManager().fetchDiscoveryTaste,
        _reping = reping ?? ServerManager().getServerPaths,
        _saveWindow = saveWindow ?? _defaultSaveWindow,
        now = now ?? DateTime.now {
    final w = (readWindow ?? _defaultReadWindow)();
    window = kTasteWindows.contains(w) ? w : kTasteDefaultWindow;
    if (pinAtOpen != null && pinAtOpen.trim().isNotEmpty) {
      _pins.add(_appPath(pinAtOpen));
    }
    this.jobs.addListener(_onJobs);
  }

  void _onJobs() => notifyListeners();

  static int _defaultReadWindow() => SettingsManager().discoverWindow;
  static void _defaultSaveWindow(int w) =>
      unawaited(SettingsManager().setDiscoverWindow(w));

  // ── state ────────────────────────────────────────────────────────────

  /// The latest library answer: seeds, seed source, window, this call's
  /// exclusions, scan state. Null until the first one lands.
  TasteResponse? seeded;
  TastePeers? peers;

  /// The library's song rows as playable DisplayItems, index-aligned with
  /// `library.tracks`, and its album cards as album DisplayItems — built once
  /// per answer so a rebuild does not mint new objects (queue actions mutate
  /// them: prefillMetadata fills the full block in place).
  List<DisplayItem> libraryRows = const [];
  List<DisplayItem> albumItems = const [];

  /// The connected servers' rows Discover can play now, as file
  /// DisplayItems on each peer's virtual Server: only peers that answered
  /// over the same sound model, only rows whose peer the app has mirrored
  /// (the stream proxy needs it), best match first across servers. And the
  /// album cards built from them ([discoveryPeerAlbumItems]). Built once
  /// per peers answer, like [libraryRows].
  List<DisplayItem> peerRows = const [];
  List<DisplayItem> peerAlbumItems = const [];

  bool loading = false;
  bool loadingPeers = false;

  /// The connected servers' last call failed transiently (not a 403): their
  /// section stays, with one line and Try again ([retryPeers]) — never a
  /// section that silently vanishes.
  bool peersError = false;

  /// The last library call failed transiently (not a 403); what is already
  /// shown stays.
  bool error = false;

  /// 403 latches, one per call: a refusal is not asked again until the user
  /// says so ([recheck]).
  bool disabled = false;
  bool peersDisabled = false;
  bool rechecking = false;
  bool _repinged = false;

  /// The window every call asks for (days; 0 = all time): the phone's
  /// remembered choice, [kTasteDefaultWindow] until there is one. After
  /// widening the answer's `window` is the one that produced seeds (often
  /// 0) — the bar shows this one, the user's own.
  late int window;

  /// The visit's steering, gone on a fresh open (a new controller): the
  /// pins, the seeds the user dropped (oldest first), and the random picks
  /// "Another pick" passed over this visit (oldest first; each the pick on
  /// screen when it was tapped — the webapp's `passed`, the terminal's
  /// `skipped`). Both lists ride in `exclude` on every call of the visit,
  /// the drops first ([_excludeSent]). The server stores neither.
  final List<String> _pins = [];
  final List<String> _exclude = [];
  final List<String> _passed = [];

  int _mainRid = 0;
  int _peersRid = 0;

  /// A peers call for the batch on screen is out: a newer library call
  /// that fails leaves it running, and the section loading.
  bool _peersOut = false;

  /// The batch on screen's peers call, as sent: what [retryPeers] sends
  /// again. Null when the batch makes none (a random seed).
  TasteRequest? _peersReq;
  bool _disposed = false;

  List<String> get pins => List.unmodifiable(_pins);
  List<String> get exclude => List.unmodifiable(_exclude);

  /// The random picks passed over this visit, oldest first.
  List<String> get passed => List.unmodifiable(_passed);

  /// The answer's exclusions the seeds sheet shows (and can use again): the
  /// server lists every `exclude` hash that resolves — the random picks
  /// passed over included, but those were never dropped.
  List<TasteExcluded> get excluded => [
        for (final e in seeded?.excluded ?? const <TasteExcluded>[])
          if (_exclude.contains(e.hash) || !_passed.contains(e.hash)) e,
      ];

  TasteLibrary? get library => seeded?.library;
  List<TasteSeed> get seeds => seeded?.seeds ?? const [];

  /// Both flags the home card is gated on. False here means a re-ping since
  /// Discover opened found the feature switched off.
  bool get available =>
      server.discoveryAvailable == true &&
      server.discoveryTasteAvailable == true;

  /// The route refused (403) though the flags still say yes — no index yet —
  /// or answered that the scan has produced nothing to compare.
  bool get scanPending =>
      available && (disabled || seeded?.notAnalyzed == true);

  /// The peers call is only made when this account may query peers at all;
  /// otherwise the route would answer `peers: null` for nothing.
  bool get asksPeers => server.federationDiscoveryAvailable == true;

  /// The server filters Discover by mood (its `moodFilters` flag, on a
  /// taste route that takes the key): the toolbar offers Filters, and every
  /// call carries the page's filter.
  bool get moodsAvailable => server.moodFiltersAvailable == true;

  /// The page's mood filter — Discover's own, kept while the app runs.
  MoodFilter get moods => MoodFilters().of(MoodPage.discover);

  /// What a call sends as `moods`: the filter, where the server takes it.
  Map<String, dynamic>? get _moodsSent => moodsAvailable ? moods.toJson() : null;

  bool get isRandom =>
      seeded?.seedSource == TasteSeedSource.random || seeded?.fallback == true;

  /// Whether connected servers are part of this visit at all: asked, not
  /// refused, and (once answered) at least one paired. Without one Discover
  /// draws no connected-server section, not even its quiet line.
  bool get hasConnectedServers =>
      asksPeers &&
      !peersDisabled &&
      (peers == null ? loadingPeers || peersError : peers!.peers.isNotEmpty);

  /// The connected servers are being asked for the batch on screen: their
  /// album strip keeps its place (a placeholder the strip's height) so the
  /// answer landing never pushes the library's songs down.
  bool get peersPending =>
      hasConnectedServers && peers == null && loadingPeers && !peersError;

  /// "Albums from {name}" / "Songs from {name}" when ONE connected server
  /// answered (or, when none answered, when only one is paired); null for
  /// "… from connected servers".
  String? get connectedServerName {
    final all = peers?.peers ?? const <TastePeerGroup>[];
    final answered = all.where(_answered).toList();
    final named = answered.isNotEmpty ? answered : all;
    if (named.length != 1 || named.single.name.trim().isEmpty) return null;
    return named.single.name;
  }

  /// The request's exclusions, oldest first: the drops (the newest
  /// [kTasteExcludeMax]), then the picks passed over that are not dropped
  /// too, the newest that fit in the room left — a drop never gives way to
  /// a passed pick (the webapp's buildRequests does the same).
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

  /// `newArtistsOnly` is always false: it is the Explore surface's toggle,
  /// and Discover draws no control for it, so it must never thin the
  /// connected servers' rows unseen (the webapp's play page does the same).
  TasteRequest mainRequest() => TasteRequest(
        window: window,
        pin: _pins.isEmpty ? null : List.of(_pins),
        exclude: _excludeSent(),
        sources: const {TasteSource.library},
        limit: kDiscoveryMainLimits,
        newArtistsOnly: false,
        moods: _moodsSent,
      );

  /// The peers call of one ask, built once the library answer [main] has
  /// landed: the same window and exclusions, pinned to EVERY seed of that
  /// answer (the user's accepted pins are among them — the server lists
  /// them first; [kTastePinMax] = the seed cap, so a whole batch fits),
  /// with `limit.seeds` = those pins, so the server adds no seed of its own
  /// and the connected servers' rows come from the batch the seeds sheet
  /// shows (the webapp's DISCOVERYPAGE.peersRequest). Null when there is
  /// nothing to pin, or when [main] is the random fallback: the server asks
  /// no connected server for a random seed, and a pin would make it.
  TasteRequest? peersRequest(TasteResponse main) {
    if (main.seedSource == TasteSeedSource.random || main.fallback) {
      return null;
    }
    final pins = <String>[];
    for (final s in main.seeds) {
      if (pins.length >= kTastePinMax) break;
      final p = _appPath(s.filepath);
      if (s.filepath.isNotEmpty && !pins.contains(p)) pins.add(p);
    }
    if (pins.isEmpty) return null;
    return TasteRequest(
      window: window,
      pin: pins,
      exclude: _excludeSent(),
      sources: const {TasteSource.peers},
      limit:
          TasteLimits(seeds: pins.length, peers: kDiscoveryPeersLimits.peers),
      newArtistsOnly: false,
      // The connected servers filter too (the server hands it on, and
      // drops the rows of one that cannot).
      moods: _moodsSent,
    );
  }

  // ── loading ──────────────────────────────────────────────────────────

  /// Ask the library, then — once its answer lands — the peers, pinned to
  /// that answer's seeds ([peersRequest]). Every open and every tap asks —
  /// the server draws a new random batch of seeds each time, which is what
  /// makes the answer new. The answer on screen stays up until the new one
  /// lands.
  ///
  /// Only the library answer's own success lets go of the peers side: the
  /// old batch's rows go (never the old rows under the new seeds) and an
  /// older peers call still out is dropped. A library call that fails, is
  /// refused or is overtaken leaves both alone — the batch on screen is
  /// unchanged, and its peers call may still land.
  Future<void> load() async {
    if (_disposed) return;
    if (!available || disabled) {
      notifyListeners();
      return;
    }
    final rid = ++_mainRid;
    // The plug-in listing, the destination and the job list: once a visit.
    unawaited(jobs.activate());
    // The peers section shows its loading state from the start: its call
    // only waits on the library's answer.
    if (asksPeers && !peersDisabled) loadingPeers = true;
    final main = await _loadMain(rid);
    if (_disposed || rid != _mainRid) return;
    if (main == null) {
      loadingPeers = _peersOut;
      notifyListeners();
      return;
    }
    final peersRid = ++_peersRid;
    _peersOut = false;
    peersError = false;
    _applyPeers(null);
    final req = asksPeers && !peersDisabled ? peersRequest(main) : null;
    _peersReq = req;
    if (req == null) {
      // A random or seedless answer: no connected-server section.
      loadingPeers = false;
      notifyListeners();
      return;
    }
    await _loadPeers(req, peersRid);
  }

  /// The toolbar's refresh ("New seeds"), Try again, pull to refresh: a
  /// plain re-ask with the same window, pins, drops and passed picks.
  Future<void> refresh() => load();

  /// The connected servers' Try again: their last call again, as it was
  /// sent (the same pins — the batch on screen — window and limits). The
  /// library batch on screen, the visit's pins and drops stay as they are.
  /// Does nothing while a call is out: a library call asks the servers
  /// itself once it lands (and its answer drops this one's), and a peers
  /// call is already asking.
  Future<void> retryPeers() async {
    final req = _peersReq;
    if (_disposed || req == null || loading || loadingPeers) return;
    await _loadPeers(req, ++_peersRid);
  }

  /// Whether the toolbar's refresh can do anything now: an answer is up, no
  /// call is out (the bar's thin line shows it), and the route is not
  /// latched off.
  bool get canRefresh =>
      available && !disabled && !loading && seeded != null;

  /// The library call [rid]. Returns the answer it applied — null when it
  /// failed, was refused, or a newer call took over.
  Future<TasteResponse?> _loadMain(int rid) async {
    loading = true;
    error = false;
    notifyListeners();
    var r = await _fetch(server, mainRequest());
    if (_disposed || rid != _mainRid) return null;
    if (_passed.isNotEmpty && r.data != null && _noPickLeft(r.data!)) {
      // Every song the random fallback could draw was passed over this
      // visit: the empty answer would read as "scan pending", which it is
      // not. Let the passed picks go and ask once more (the list is empty
      // then, so once), so the picks start over.
      _passed.clear();
      r = await _fetch(server, mainRequest());
      if (_disposed || rid != _mainRid) return null;
    }
    loading = false;
    if (r.disabled) {
      disabled = true;
      notifyListeners();
      await _repingOnce();
      return null;
    }
    final data = r.data;
    if (data == null) {
      error = true;
    } else {
      _apply(data);
    }
    notifyListeners();
    return data;
  }

  /// An answer with no pick left (the webapp's DISCOVERYPAGE.noPickLeft):
  /// no seed at all, from the random fallback or with the scan-pending
  /// flag — with picks passed over, the exclusions, not the scan, left the
  /// server nothing to draw.
  static bool _noPickLeft(TasteResponse r) =>
      r.seeds.isEmpty &&
      (r.seedSource == TasteSeedSource.random || r.notAnalyzed);

  Future<void> _loadPeers(TasteRequest req, int rid) async {
    _peersOut = true;
    loadingPeers = true;
    peersError = false;
    notifyListeners();
    final r = await _fetch(server, req);
    if (_disposed || rid != _peersRid) return;
    _peersOut = false;
    loadingPeers = false;
    if (r.disabled) {
      peersDisabled = true;
      notifyListeners();
      await _repingOnce();
      return;
    }
    // A failure draws no rows (the old batch's went when this batch
    // landed) but keeps the section: one line and Try again.
    peersError = r.data == null;
    _applyPeers(r.data?.peers);
    notifyListeners();
  }

  void _apply(TasteResponse? r) {
    seeded = r;
    final lib = r?.library;
    libraryRows = [
      for (final t in lib?.tracks ?? const <TasteTrack>[])
        discoveryTrackItem(server, t),
    ];
    albumItems = [
      for (final a in lib?.albums ?? const <TasteAlbum>[])
        discoveryAlbumItem(server, a),
    ];
  }

  void _applyPeers(TastePeers? p) {
    peers = p;
    peerRows = discoveryPeerRows(p, peerTrackItem);
    peerAlbumItems = discoveryPeerAlbumItems(peerRows);
    // Every connected-servers answer — its Try again's too — is looked up
    // (what the caller already copied); a batch let go of lets go of its
    // lookup. The rows go exactly as received.
    unawaited(jobs.setRows([
      for (final r in peerRows) ?discoveryLeadOf(r),
    ]));
  }

  static bool _answered(TastePeerGroup g) => g.reachable && !g.mismatched;

  /// Settle WHY a taste call refused, once per page (DiscoverScreen's
  /// _probeAfterRefusal, same reasoning): a 403 from a route the flags
  /// advertised almost always means discovery was switched off since the
  /// last ping, and only a re-ping can say so. If the flags survive, it is
  /// the rare no-index case and the scan-pending card is right.
  Future<void> _repingOnce() async {
    if (_repinged) return;
    _repinged = true;
    await _reping(server);
    if (!_disposed) notifyListeners();
  }

  /// "Check again" on the scan-pending card: re-ping first (config before
  /// data), then drop the latches — the one thing that should clear them is
  /// the user asking — and the picks passed over, and ask again.
  Future<void> recheck() async {
    if (rechecking || _disposed) return;
    rechecking = true;
    notifyListeners();
    await _reping(server);
    if (_disposed) return;
    rechecking = false;
    disabled = false;
    peersDisabled = false;
    _passed.clear();
    await load();
  }

  // ── the user's steering ──────────────────────────────────────────────

  /// The window chooser in the configuration bar: remembered on this phone
  /// and asked again of every source with the visit's pins and drops.
  ///
  /// Under the 403 latch nothing would be asked, so nothing changes: a
  /// window set then would name rows it never produced. The bar's chooser
  /// is off then too. A call that fails puts the old window back (the rows
  /// still shown came from it — the peers rows too: a failed library call
  /// leaves them be), remembered again.
  Future<void> setWindow(int w) async {
    if (w == window || !kTasteWindows.contains(w) || disabled || !available) {
      return;
    }
    final before = window;
    window = w;
    _saveWindow(w);
    notifyListeners();
    await load();
    if (_disposed) return;
    if ((error || disabled) && window == w) {
      window = before;
      _saveWindow(before);
      notifyListeners();
    }
  }

  /// The Filters sheet's Done, or the strip's Clear: [filter] becomes the
  /// page's, shown at once, and every source is asked again under it (a new
  /// random batch of seeds, the history songs that match first — the
  /// server's choice).
  Future<void> setMoods(MoodFilter filter) async {
    if (_disposed || !moodsAvailable || filter == moods) return;
    MoodFilters().set(MoodPage.discover, filter);
    notifyListeners();
    await load();
  }

  /// The seeds sheet's "Use these N": [drop] are seed hashes switched off
  /// (left out of every call this visit), [restore] are dropped ones used
  /// again, [pins] replaces the visit's pins (app paths). Then one new call.
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
    await load();
  }

  /// Pin one more song ("Choose a song…" on the random card).
  Future<void> pinSong(String path) async {
    final p = _appPath(path);
    if (!_pins.contains(p) && _pins.length < kTastePinMax) _pins.add(p);
    await load();
  }

  /// "Another pick" on the nothing-finished card: the pick on screen joins
  /// the visit's passed picks, and the page asks again — every call sends
  /// them in `exclude` (after the drops), so the server, which draws a
  /// fresh random song per call, never repeats one this visit. When none is
  /// left (the answer has no pick) the passed picks are let go and the call
  /// asked once more ([_loadMain]), so the picks start over instead of a
  /// false scan-pending card.
  Future<void> anotherPick() async {
    if (_disposed) return;
    if (isRandom) {
      for (final s in seeds) {
        if (!s.pinned && !_passed.contains(s.hash)) _passed.add(s.hash);
      }
    }
    await load();
  }

  // ── rows ─────────────────────────────────────────────────────────────

  /// The virtual Server a federated peer's row plays through: the one
  /// ServerManager mirrors from this server's peer list with the same peer
  /// id. Null when the app has not mirrored it (the peer list refreshes with
  /// the server; a brand-new peer may not be there yet).
  Server? peerServerFor(DiscoveryLead lead) =>
      discoveryPeerServer(server, lead.peerId);

  /// A peers row as a playable DisplayItem on its peer's virtual Server, so
  /// the queue builds the parent's federation stream-proxy URL exactly as it
  /// does for a browsed peer track (buildServerStreamUrl). Null when the row
  /// has no peer path or the peer is not mirrored.
  DisplayItem? peerTrackItem(DiscoveryLead lead) {
    final fp = lead.filepath;
    final peer = peerServerFor(lead);
    if (fp == null || fp.isEmpty || peer == null) return null;
    final row = DisplayItem(peer, lead.title, 'file', '/$fp',
        Icon(Icons.music_note, color: VelvetColors.accent),
        discoveryRowSubtext(lead.artist, lead.album));
    // The row's albumArt (the peer's cached cover name) resolves against
    // the peer's virtual Server, so the browser's art tile is fetched the
    // way a browsed peer track's is (buildAlbumArtUrl): on the proxy path
    // through the parent's federation art proxy
    // (<parent>/api/v1/federation/peers/<id>/art/<file>?compress=s); while
    // the peer is direct (its own tunnel, issue #143), from the peer's own
    // /album-art/<file> over that tunnel with its guest token, as every
    // other direct-peer byte is. No albumArt (an older peer, a track
    // without a cover): the note tile.
    row.metadata = MusicMetadata(lead.artist.isEmpty ? null : lead.artist,
        lead.album, lead.title, null, null, lead.year, '', null, lead.art,
        durationSeconds: lead.durationSeconds);
    // The lead carries a handful of fields; db/metadata is on the federation
    // allowlist, so the queue fetches the peer's full block before playing.
    row.partialMetadata = true;
    _leadOfRow[row] = lead;
    return row;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  /// Idempotent: the browser listing lets go of its controller on its own
  /// (DiscoveryListing), and a test may dispose the one it injected.
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    jobs.removeListener(_onJobs);
    if (_ownsJobs) jobs.dispose();
    super.dispose();
  }
}

/// The lead a connected server's row was built from ([DiscoveryPageController
/// .peerTrackItem]) — its raw row is the recommendation every plug-in call
/// sends unchanged. Null for any other row.
DiscoveryLead? discoveryLeadOf(DisplayItem row) => _leadOfRow[row];
final Expando<DiscoveryLead> _leadOfRow = Expando('discovery lead');

/// A connected server's album card's rows' leads, best first
/// ([discoveryPeerAlbumItems]): the first is what its album copy sends
/// (scope album). Empty for any other item.
List<DiscoveryLead> discoveryCardLeads(DisplayItem card) =>
    _leadsOfCard[card] ?? const [];
final Expando<List<DiscoveryLead>> _leadsOfCard = Expando('discovery card');

/// Whether a connected server's album card is a compilation: grouped by an
/// album artist that is not its best row's track artist ("Various
/// Artists"). Its copy is the album only — the rows' artists are guests.
bool discoveryCardIsCompilation(DisplayItem card) {
  final leads = discoveryCardLeads(card);
  if (leads.isEmpty) return false;
  final credit = leads.first.albumArtist?.trim().toLowerCase() ?? '';
  return credit.isNotEmpty &&
      credit != leads.first.artist.trim().toLowerCase();
}

/// The virtual Server ServerManager mirrors from [parent]'s peer list for
/// peer [id], or null when it is not mirrored (or [id] is null).
Server? discoveryPeerServer(Server? parent, int? id) {
  if (parent == null || id == null) return null;
  for (final s in ServerManager().federatedChildren(parent)) {
    if (s.federationPeerId == id) return s;
  }
  return null;
}

/// A federation lead's cover as an art-only DisplayItem on its peer's
/// virtual Server — so getAlbumThumb fetches the lead's albumArt through
/// [parent]'s federation art proxy, as the Discover page's peer rows do.
/// Null (the caller keeps its own icon) for a P2P lead, a lead without
/// albumArt, or a peer the app has not mirrored. More like this's "From
/// your peers" rows use it; a lead there stays a lead (tap copies).
DisplayItem? discoveryLeadArtItem(Server? parent, DiscoveryLead lead) {
  final art = lead.art;
  if (art == null) return null;
  final peer = discoveryPeerServer(parent, lead.peerId);
  if (peer == null) return null;
  return DisplayItem(peer, lead.title, 'file', null, null, null)
    ..altAlbumArt = art;
}

/// App-side paths carry the leading slash ([DisplayItem.data], MediaItem
/// extras); TasteRequest.toJson strips it on the way out.
String _appPath(String p) => p.startsWith('/') ? p : '/$p';

/// A Discover song row's second line: "Artist · Album" (no genre, year,
/// play facts or match) — null when the row has neither.
String? discoveryRowSubtext(String? artist, String? album) {
  final line = [
    if ((artist ?? '').trim().isNotEmpty) artist!.trim(),
    if ((album ?? '').trim().isNotEmpty) album!.trim(),
  ].join(' · ');
  return line.isEmpty ? null : line;
}

/// A library row (wire path without the leading slash) as the playable
/// DisplayItem every queue action takes — DiscoverScreen's mapping, with
/// the "Artist · Album" line as its subtext. LITE metadata, so partial: the
/// queue fetches the full block first.
DisplayItem discoveryTrackItem(Server server, DiscoveryTrack t) {
  final m = t.metadata;
  final row = DisplayItem(server, t.filepath, 'file', '/${t.filepath}',
      Icon(Icons.music_note, color: VelvetColors.accent),
      discoveryRowSubtext(m?.artistDisplay ?? m?.artist, m?.album));
  row.metadata = m;
  row.partialMetadata = true;
  return row;
}

/// The connected servers' playable rows, best match first: only peers that
/// answered over the same sound model (an offline or mismatched peer is
/// simply not shown — no per-server header says so), only rows [item] can
/// make playable (its peer mirrored, a path to stream). A tie keeps the
/// server's order (group, then row).
List<DisplayItem> discoveryPeerRows(
    TastePeers? peers, DisplayItem? Function(DiscoveryLead) item) {
  final ranked = <(DiscoveryLead, int)>[];
  for (final g in peers?.peers ?? const <TastePeerGroup>[]) {
    if (!g.reachable || g.mismatched) continue;
    for (final lead in g.results) {
      ranked.add((lead, ranked.length));
    }
  }
  ranked.sort((a, b) {
    final bySim = b.$1.similarity.compareTo(a.$1.similarity);
    return bySim != 0 ? bySim : a.$2.compareTo(b.$2);
  });
  return [
    for (final (lead, _) in ranked) ?item(lead),
  ];
}

/// "Albums from …": [rows] (best first) grouped by server + album + the
/// album's credit — its album artist when the row names one, else the track
/// artist — rows without an album tag are left out — so an album ranks by
/// its best row; capped at [kDiscoveryPeerAlbumsMax]. Each card is an album
/// DisplayItem on the peer's virtual Server, so a tap opens it in the album
/// detail through that peer (album-songs is on the federation allowlist),
/// exactly as browsing the peer's Albums does.
///
/// A row that names its album artist (`albumArtist`) groups under it, so a
/// compilation is ONE card whose artist line is that credit ("Various
/// Artists"), opened by name + `album_artist` ([DisplayItem.albumArtist]) —
/// the whole album, which is what its album copy takes. A row without one
/// carries only the TRACK artist, which is not always the album's credit,
/// so that card opens by name plus the artist as album-songs' `artist`
/// filter ([DisplayItem.trackArtist], as the webapp's
/// discoveryOpenPeerAlbum does): a peer holding several same-named albums
/// ("Greatest Hits") does not merge them.
///
/// Each card keeps its rows' leads, best first ([discoveryCardLeads]).
List<DisplayItem> discoveryPeerAlbumItems(List<DisplayItem> rows) {
  String fold(String? v) => (v ?? '').trim().toLowerCase();
  final byKey = <(String, String, String), DisplayItem>{};
  for (final r in rows) {
    final album = r.metadata?.album?.trim() ?? '';
    final server = r.server;
    if (album.isEmpty || server == null) continue;
    final lead = discoveryLeadOf(r);
    final artist = r.metadata?.artist?.trim();
    final albumArtist = lead?.albumArtist?.trim();
    final credit =
        (albumArtist ?? '').isNotEmpty ? albumArtist : artist;
    final key = (server.localname, fold(album), fold(credit));
    var card = byKey[key];
    if (card == null) {
      if (byKey.length >= kDiscoveryPeerAlbumsMax) continue;
      card = byKey[key] = DisplayItem(server, album, 'album', album,
          Icon(Icons.album, color: VelvetColors.textSecondary),
          (credit ?? '').isEmpty ? null : credit);
      if ((albumArtist ?? '').isNotEmpty) {
        card.albumArtist = albumArtist;
      } else {
        card.trackArtist = (artist ?? '').isEmpty ? null : artist;
      }
      _leadsOfCard[card] = <DiscoveryLead>[];
    }
    if (lead != null) _leadsOfCard[card]!.add(lead);
    // The first row that has art lends it to the card (through the same
    // proxy: the card is on the peer's virtual Server too).
    card.altAlbumArt ??= r.metadata?.albumArt;
  }
  for (final card in byKey.values) {
    _leadsOfCard[card] = List.unmodifiable(_leadsOfCard[card]!);
  }
  return byKey.values.toList();
}

/// A seed as a DisplayItem — for its art in the seeds sheet.
DisplayItem discoverySeedItem(Server server, TasteSeed s) {
  final row = DisplayItem(server, s.filepath, 'file', '/${s.filepath}',
      Icon(Icons.music_note, color: VelvetColors.accent), null);
  row.metadata = s.metadata;
  row.partialMetadata = true;
  return row;
}

/// An album card as the album DisplayItem getAlbums builds, so the album
/// detail opens through the same album-songs body (name + year + album
/// artist; see albumSongsBody). Its face is the title and the artist only:
/// the year rides along for album-songs, it is not drawn.
DisplayItem discoveryAlbumItem(Server server, TasteAlbum a) {
  final credit = (a.albumArtist ?? '').trim().isNotEmpty
      ? a.albumArtist!.trim()
      : a.artists.where((x) => x.trim().isNotEmpty).join(', ');
  final item = DisplayItem(server, a.name, 'album', a.name,
      Icon(Icons.album, color: VelvetColors.textSecondary),
      credit.isEmpty ? null : credit);
  item.altAlbumArt = a.albumArtFile;
  item.albumArtist = a.albumArtist;
  item.year = a.year;
  return item;
}
