import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../objects/discovery.dart';
import '../../objects/display_item.dart';
import '../../objects/metadata.dart';
import '../../objects/server.dart';
import '../../singletons/api.dart';
import '../../singletons/server_list.dart';
import '../../theme/velvet_theme.dart';

typedef TasteFetch = Future<DiscoveryFetchResult<TasteResponse>> Function(
    Server server, TasteRequest req);
typedef TastePrefsFetch = Future<DiscoveryFetchResult<TastePrefs>> Function(
    Server server);
typedef TastePrefsSave = Future<DiscoveryFetchResult<TastePrefs>> Function(
    Server server, TastePrefs patch);

/// How long a visit's answer stands before re-entering Discover refetches.
/// The taste route pays an index rebuild and a library pass per seed, and the
/// server caches its own answer for the same five minutes (plan §2.4) — so a
/// client that refetched on every open would only ever buy the same rows.
const Duration kDiscoveryPageTtl = Duration(minutes: 5);

/// Rows asked of the library call. The browser listing shows every one (it
/// scrolls), so there is no "See all".
const TasteLimits kDiscoveryMainLimits = TasteLimits(tracks: 24, albums: 8);

/// Rows per peer asked of the peers call.
const TasteLimits kDiscoveryPeersLimits = TasteLimits(peers: 10);

/// Album cards built from the connected servers' rows, at most (the
/// webapp's ALBUM_STRIP_MAX).
const int kDiscoveryPeerAlbumsMax = 12;

/// What a visit holds, kept per server past the listing's lifetime so
/// leaving and coming back (Back to the home, then Discover again) does not
/// refetch.
class _Snapshot {
  final String key;
  final DateTime at;
  final TasteResponse? seeded;
  final TastePeers? peers;
  final bool peersDone;
  _Snapshot(this.key, this.at, this.seeded, this.peers, this.peersDone);
}

/// Discover's data for one server (plan §3.1, §4.2) — what the browser
/// listing (discovery_listing.dart) is built from: two taste calls in
/// parallel — the library, then peers on its own so the library never waits
/// out the 4 s peer deadline — with request-id guards, a per-call 403 latch
/// plus ONE re-ping to tell "switched off" from "scan pending", and a client
/// TTL so re-entering Discover is free.
///
/// Discover is the play-now page (plan §2.13, 2026-10-11): it asks only for
/// songs you can play now — the library and the connected (federated)
/// servers. The P2P network's leads are a later Explore surface's, so the
/// main call asks `sources: [library]` only.
///
/// Seeds are the server's to choose (history, then counters, then a random
/// pick); Discover only steers them: the window, songs dropped (remembered
/// server-side, so every client agrees), pins, and the one library filter
/// ("Include songs I've played lately"). The now-playing song is pinned
/// ONCE, at open ([pinAtOpen]) — the controller never watches playback, so a
/// track change never reshuffles the listing under the user's thumb (plan
/// §2.3).
class DiscoveryPageController extends ChangeNotifier {
  final Server server;
  final TasteFetch _fetch;
  final TastePrefsFetch _fetchPrefs;
  final TastePrefsSave _savePrefs;
  final Future<void> Function(Server) _reping;
  final Future<String?> Function(Server) _randomPick;
  final DateTime Function() now;

  DiscoveryPageController({
    required this.server,
    TasteFetch? fetch,
    TastePrefsFetch? fetchPrefs,
    TastePrefsSave? savePrefs,
    Future<void> Function(Server)? reping,
    Future<String?> Function(Server)? randomPick,
    DateTime Function()? now,
    String? pinAtOpen,
  })  : _fetch = fetch ?? ApiManager().fetchDiscoveryTaste,
        _fetchPrefs = fetchPrefs ?? ApiManager().fetchDiscoveryTastePrefs,
        _savePrefs = savePrefs ?? ApiManager().saveDiscoveryTastePrefs,
        _reping = reping ?? ServerManager().getServerPaths,
        _randomPick = randomPick ?? _defaultRandomPick,
        now = now ?? DateTime.now {
    if (pinAtOpen != null && pinAtOpen.trim().isNotEmpty) {
      _pins.add(_appPath(pinAtOpen));
    }
  }

  static Future<String?> _defaultRandomPick(Server s) async =>
      (await ApiManager().fetchRandomSong(s))?.data;

  static final Map<String, _Snapshot> _cache = {};

  /// Forget every server's cached visit (tests; a server removed).
  @visibleForTesting
  static void clearCache() => _cache.clear();

  /// The cache slot: the server entry AND the account on it. Editing an
  /// entry to another account keeps its localname, and the request (the
  /// snapshot key) carries no user — so without the name a reopen inside
  /// the TTL would show the previous account's history-seeded rows.
  String get _slot => '${server.localname}\u0000${server.username ?? ''}';

  // ── state ────────────────────────────────────────────────────────────

  /// The latest library answer: seeds, seed source, window, the remembered
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

  /// The last library call failed transiently (not a 403); what is already
  /// shown stays.
  bool error = false;

  /// 403 latches, one per call: a refusal is not asked again until the user
  /// says so ([recheck]).
  bool disabled = false;
  bool peersDisabled = false;
  bool rechecking = false;
  bool _repinged = false;
  bool _peersDone = false;

  /// The user's choices this visit; null = the saved pref applies.
  int? window;
  TasteFilter? filter;
  final List<String> _pins = [];
  final List<String> _exclude = [];

  int _mainRid = 0;
  int _peersRid = 0;
  bool _disposed = false;

  List<String> get pins => List.unmodifiable(_pins);
  List<String> get exclude => List.unmodifiable(_exclude);

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

  bool get isRandom =>
      seeded?.seedSource == TasteSeedSource.random || seeded?.fallback == true;

  TasteFilter get effectiveFilter =>
      filter ?? library?.filter ?? TasteFilter.fresh;

  /// The one library checkbox, "Include songs I've played lately": ticked
  /// asks for `all`, unticked for `fresh`. The old never-played-only mode is
  /// gone — a saved `unplayed` reads (and is re-asked) as `fresh`, see
  /// [_loadMain].
  bool get includesPlayed => effectiveFilter == TasteFilter.all;

  /// The filter the checkbox asks for.
  static TasteFilter filterFor({required bool includePlayed}) =>
      includePlayed ? TasteFilter.all : TasteFilter.fresh;

  /// Whether connected servers are part of this visit at all: asked, not
  /// refused, and (once answered) at least one paired. Without one Discover
  /// draws no connected-server section, not even its quiet line.
  bool get hasConnectedServers =>
      asksPeers &&
      !peersDisabled &&
      (peers == null ? loadingPeers : peers!.peers.isNotEmpty);

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

  /// The window ASKED for — this visit's choice, else the saved pref the
  /// server applied. After widening the answer's `window` is the one that
  /// produced seeds (often 0, all time) and `widenedFrom` the requested
  /// one; the configuration bar must show the user's own window, and
  /// picking "All time" there must count as a change worth sending and
  /// remembering.
  int get effectiveWindow =>
      window ?? seeded?.widenedFrom ?? seeded?.window ?? kTasteDefaultWindow;

  /// A choice this visit is worth remembering (window, filter, a dropped
  /// seed): the route then saves it in `discovery:page`, the same on every
  /// client. Pins are never remembered (plan §2.3).
  bool get _remember => window != null || filter != null || _exclude.isNotEmpty;

  /// `newArtistsOnly` is always false: it is the Explore surface's toggle,
  /// and Discover draws no control for it, so it must never thin the
  /// connected servers' rows unseen (the webapp's play page does the same).
  TasteRequest mainRequest() => TasteRequest(
        window: window,
        pin: _pins.isEmpty ? null : List.of(_pins),
        exclude: _exclude.isEmpty ? null : List.of(_exclude),
        remember: _remember ? true : null,
        filter: filter,
        sources: const {TasteSource.library},
        limit: kDiscoveryMainLimits,
        newArtistsOnly: false,
      );

  /// The same seeds as [mainRequest] (so the centroid matches) asking only
  /// for peers. Never `remember`: the main call already saves the choices.
  TasteRequest peersRequest() => TasteRequest(
        window: window,
        pin: _pins.isEmpty ? null : List.of(_pins),
        exclude: _exclude.isEmpty ? null : List.of(_exclude),
        sources: const {TasteSource.peers},
        limit: kDiscoveryPeersLimits,
        newArtistsOnly: false,
      );

  String _cacheKey() =>
      '${jsonEncode(mainRequest().toJson())}|peers=$asksPeers';

  // ── loading ──────────────────────────────────────────────────────────

  /// Fetch both calls in parallel, or restore the cached visit when it is
  /// fresh and asked the same thing. [force] (refresh, a changed seed set)
  /// skips the cache.
  Future<void> load({bool force = false}) async {
    if (_disposed) return;
    if (!available) {
      notifyListeners();
      return;
    }
    final key = _cacheKey();
    final hit = _cache[_slot];
    if (!force &&
        hit != null &&
        hit.key == key &&
        now().difference(hit.at) < kDiscoveryPageTtl) {
      _applyPeers(hit.peers);
      _peersDone = hit.peersDone;
      // The peers call stores the snapshot too, so it can hold no library
      // answer: the visit was left before main landed, or main failed or
      // was refused (a new controller inherits no latch). Restoring that
      // would leave Discover on placeholders nothing is loading — so the
      // cached peers stand and main is asked again.
      final owesMain = hit.seeded == null;
      if (!owesMain) _apply(hit.seeded);
      notifyListeners();
      // A visit left before its peers landed still owes them.
      await Future.wait([
        if (owesMain && !disabled) _loadMain(),
        if (asksPeers && !hit.peersDone && !peersDisabled) _loadPeers(),
      ]);
      if (!_disposed) notifyListeners();
      return;
    }
    _peersDone = false;
    await Future.wait([
      if (!disabled) _loadMain(),
      if (asksPeers && !peersDisabled) _loadPeers(),
    ]);
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() => load(force: true);

  Future<void> _loadMain() async {
    final rid = ++_mainRid;
    loading = true;
    error = false;
    notifyListeners();
    final r = await _fetch(server, mainRequest());
    if (_disposed || rid != _mainRid) return;
    loading = false;
    if (r.disabled) {
      disabled = true;
      notifyListeners();
      await _repingOnce();
      return;
    }
    final data = r.data;
    if (data == null) {
      error = true;
    } else if (filter == null &&
        data.library?.filter == TasteFilter.unplayed) {
      // A filter saved as `unplayed` (the retired never-played-only mode)
      // reads as `fresh`. The client cannot know the saved filter before
      // this first answer, so it asks again with `fresh`, once — without
      // drawing or caching the never-played rows it just got (the listing
      // stays on what it showed: placeholders on a first visit). `filter`
      // is then this visit's choice, so the server remembers `fresh` and
      // later visits ask once.
      filter = TasteFilter.fresh;
      await _loadMain();
      return;
    } else {
      _apply(data);
      _store();
    }
    notifyListeners();
  }

  Future<void> _loadPeers() async {
    final rid = ++_peersRid;
    loadingPeers = true;
    notifyListeners();
    final r = await _fetch(server, peersRequest());
    if (_disposed || rid != _peersRid) return;
    loadingPeers = false;
    if (r.disabled) {
      peersDisabled = true;
      notifyListeners();
      await _repingOnce();
      return;
    }
    // A transient failure keeps the rows already shown.
    if (r.data != null) {
      _applyPeers(r.data!.peers);
      _peersDone = true;
      _store();
    }
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
  }

  static bool _answered(TastePeerGroup g) => g.reachable && !g.mismatched;

  void _store() {
    _cache[_slot] = _Snapshot(_cacheKey(), now(), seeded, peers, _peersDone);
  }

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
  /// the user asking — and fetch fresh.
  Future<void> recheck() async {
    if (rechecking || _disposed) return;
    rechecking = true;
    notifyListeners();
    await _reping(server);
    if (_disposed) return;
    rechecking = false;
    disabled = false;
    peersDisabled = false;
    await load(force: true);
  }

  // ── the user's steering ──────────────────────────────────────────────

  /// The checkbox (in the seeds sheet, applied at once as the webapp's is)
  /// and the library-empty line's button: refetch the library with the
  /// filter (remembered); peers do not depend on it. The filter flips
  /// before the call goes out (the box ticks at once) and goes back if the
  /// call fails.
  Future<void> setFilter(TasteFilter f) async {
    if (f == effectiveFilter) return;
    final before = filter;
    filter = f;
    if (disabled || !available) return;
    await _loadMain();
    // A refetch that failed (or was refused) leaves the old rows up: put
    // the choice back, so the selected chip names the rows actually shown
    // and a later call does not remember a filter that never landed. Not
    // when the user has tapped on since — that call owns `filter` now.
    if ((error || disabled) && filter == f) {
      filter = before;
      notifyListeners();
    }
  }

  /// The window chooser in the configuration bar: refetch every
  /// source with the same seeds, drops and pins over the new window
  /// (remembered, like the filter). The window decides the seeds, so the
  /// peers call — whose centroid must match — is asked again too.
  ///
  /// Under the 403 latch nothing would be asked, so nothing changes: a
  /// window set then would name rows it never produced, and ride out (and
  /// be remembered) on the next "Check again". The bar's chooser is off
  /// then too.
  Future<void> setWindow(int w) async {
    if (w == effectiveWindow || disabled || !available) return;
    final before = window;
    final peersBefore = peers;
    final peersDoneBefore = _peersDone;
    window = w;
    notifyListeners();
    await load(force: true);
    // As [setFilter]: a refetch that failed leaves the old rows up, so the
    // bar goes back to the window those rows came from, and a later call
    // does not remember a window that never landed. The peers call may
    // still have answered over the NEW window's seeds — its rows go back
    // too, so both sections keep one centroid, and the visit is stored
    // again under the window it now shows (the peers answer had stored
    // the new window's key).
    if ((error || disabled) && window == w) {
      window = before;
      ++_peersRid;
      loadingPeers = false;
      _applyPeers(peersBefore);
      _peersDone = peersDoneBefore;
      if (seeded != null) _store();
      notifyListeners();
    }
  }

  /// The seeds sheet's "Use these N".
  ///
  /// [drop] are hashes switched off (sent as `exclude` with `remember`, so
  /// the server keeps them); [restore] are switched back on — dropped from
  /// this visit's list AND from the saved prefs, which otherwise keep
  /// excluding them. [pins] replaces the visit's pins (app paths). The
  /// sheet's checkbox is not part of this: it applies at once ([setFilter]).
  ///
  /// False when a restore could not be saved (the prefs read or write
  /// failed): the server still excludes those songs from every call, so the
  /// refetch leaves them out and the caller must say why.
  Future<bool> applySeeds({
    required int window,
    Set<String> drop = const {},
    Set<String> restore = const {},
    required List<String> pins,
  }) async {
    if (window != effectiveWindow) this.window = window;
    for (final h in drop) {
      if (!_exclude.contains(h)) _exclude.add(h);
    }
    var restored = true;
    if (restore.isNotEmpty) {
      _exclude.removeWhere(restore.contains);
      restored = await _forget(restore);
    }
    _pins
      ..clear()
      ..addAll(pins.map(_appPath).take(kTastePinMax));
    if (_disposed) return restored;
    await load(force: true);
    return restored;
  }

  /// Takes [hashes] out of the saved exclusions. Read-modify-write over the
  /// prefs route: a failed read sends nothing, since a PUT of a guessed
  /// list would wipe the user's other exclusions. False when the read or
  /// the write failed — the hashes are still saved, still excluded.
  Future<bool> _forget(Set<String> hashes) async {
    final got = await _fetchPrefs(server);
    final saved = got.data?.exclude;
    if (got.disabled || got.data == null) return false;
    final next = (saved ?? const <String>[])
        .where((h) => !hashes.contains(h))
        .toList();
    // None of them saved: nothing to take out, and nothing excludes them.
    if (next.length == (saved?.length ?? 0)) return true;
    final put = await _savePrefs(server, TastePrefs(exclude: next));
    return !put.disabled && put.data != null;
  }

  /// Pin one more song ("Choose a song…" on the random card).
  Future<void> pinSong(String path) async {
    final p = _appPath(path);
    if (!_pins.contains(p) && _pins.length < kTastePinMax) _pins.add(p);
    await load(force: true);
  }

  /// "Another pick" on the nothing-finished card. The server's random seed
  /// is deterministic per user per day (plan §2.8), so asking again would
  /// answer the same song: a random library song is pinned instead. False
  /// when none could be picked.
  Future<bool> anotherPick() async {
    final p = await _randomPick(server);
    if (p == null || p.isEmpty || _disposed) return false;
    _pins
      ..clear()
      ..add(_appPath(p));
    await load(force: true);
    return true;
  }

  // ── rows ─────────────────────────────────────────────────────────────

  /// The virtual Server a federated peer's row plays through: the one
  /// ServerManager mirrors from this server's peer list with the same peer
  /// id. Null when the app has not mirrored it (the peer list refreshes with
  /// the server; a brand-new peer may not be there yet).
  Server? peerServerFor(DiscoveryLead lead) {
    final id = lead.peerId;
    if (id == null) return null;
    for (final s in ServerManager().federatedChildren(server)) {
      if (s.federationPeerId == id) return s;
    }
    return null;
  }

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
    // The art file resolves against the peer's virtual Server, so the
    // browser's art tile goes through the parent's federation art proxy
    // (buildAlbumArtUrl), as a browsed peer track's does.
    row.metadata = MusicMetadata(lead.artist.isEmpty ? null : lead.artist,
        lead.album, lead.title, null, null, lead.year, '', null, lead.art,
        durationSeconds: lead.durationSeconds);
    // The lead carries a handful of fields; db/metadata is on the federation
    // allowlist, so the queue fetches the peer's full block before playing.
    row.partialMetadata = true;
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
    super.dispose();
  }
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

/// "Albums from …": [rows] (best first) grouped by server + album + artist
/// — rows without an album tag are left out — so an album ranks by its best
/// row; capped at [kDiscoveryPeerAlbumsMax]. Each card is an album
/// DisplayItem on the peer's virtual Server, so a tap opens it in the album
/// detail through that peer (album-songs is on the federation allowlist),
/// exactly as browsing the peer's Albums does. The rows carry the TRACK
/// artist, which is not always the album's credit, so the card opens by name
/// plus that artist as album-songs' `artist` filter ([DisplayItem.
/// trackArtist], as the webapp's discoveryOpenPeerAlbum does): a peer
/// holding several same-named albums ("Greatest Hits") does not merge them.
List<DisplayItem> discoveryPeerAlbumItems(List<DisplayItem> rows) {
  String fold(String? v) => (v ?? '').trim().toLowerCase();
  final byKey = <(String, String, String), DisplayItem>{};
  for (final r in rows) {
    final album = r.metadata?.album?.trim() ?? '';
    final server = r.server;
    if (album.isEmpty || server == null) continue;
    final artist = r.metadata?.artist?.trim();
    final key = (server.localname, fold(album), fold(artist));
    var card = byKey[key];
    if (card == null) {
      if (byKey.length >= kDiscoveryPeerAlbumsMax) continue;
      card = byKey[key] = DisplayItem(server, album, 'album', album,
          Icon(Icons.album, color: VelvetColors.textSecondary),
          (artist ?? '').isEmpty ? null : artist);
      card.trackArtist = (artist ?? '').isEmpty ? null : artist;
    }
    // The first row that has art lends it to the card.
    card.altAlbumArt ??= r.metadata?.albumArt;
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
