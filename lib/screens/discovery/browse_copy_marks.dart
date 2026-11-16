import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../objects/discovery_plugins.dart';
import '../../objects/server.dart';
import '../../util/discover_badges.dart';
import '../../util/discover_jobs.dart';
import 'discovery_jobs_controller.dart';

/// One browse page's copy marks while browsing a connected server (the
/// phone spec's "lookups, poll, and which job"): what the user already did
/// with the things on the page — the pill's state, a card's badge, a song
/// row's or a folder row's second line — from the user's own server's jobs.
///
/// A page holds one (its album page, its artist page, the Albums grid, an
/// explorer folder) and asks its lookups through the own server's
/// [DiscoveryJobsController.lookup] — never Discover's row set
/// ([DiscoveryJobsController.setRows]), so the two never draw over each
/// other's markers. What it asks, in batches the route takes (≤ 100):
///   album page      the album's rec (once its credit is known) and its song
///                   rows' recs
///   artist page     the artist's rec and each credited card's album rec
///   albums grid     the cards on screen and one screen ahead ([askSoon]:
///                   250 ms debounce, each asked once a visit)
///   explorer folder the open folder's rec and the folder rows' recs
/// Asks drop out when the page goes ([dispose]) or the server changes
/// ([reset]). A lookup refused or failed draws no marks — its recs that
/// were never answered are asked again once the back-off has passed (4 s,
/// doubled per failure to 60 s), not each time the page rebuilds; with the
/// own server's plug-ins off nothing is asked at all.
///
/// While a mark of its own is live and the page is in front ([front]) with
/// the app in the foreground, it re-asks only the live recs every 4 s
/// (doubled per failure to 60 s, as the controller backs off) and keeps the
/// controller's job list beating ([DiscoveryJobsController.holdPage]), so
/// the end toasts come from the hub as they always did. A job the
/// controller learns of (a start from a Keep sheet on the page) lands on
/// the rows that know its key at once; [reask] asks the opener's rec again
/// when a Keep sheet closes.
///
/// Which job a mark shows is util/discover_badges.dart's (pagePillJob,
/// pageCardBadge, pageSongMarker, pageFolderMarker): album and artist jobs
/// only when they name THIS server, a song job from any, a folder job by
/// its key.
class BrowseCopyMarks extends ChangeNotifier with WidgetsBindingObserver {
  /// The own server's copies (`CopiesHub().jobsFor(peer)`).
  final DiscoveryJobsController jobs;

  /// The connected server the page is on (its row id on the own server).
  final int? peerId;
  final JobsTimerFactory _timer;

  /// False leaves the app lifecycle to the caller
  /// ([didChangeAppLifecycleState]; tests).
  final bool watchLifecycle;

  /// How long [askSoon] waits for the scroll to settle.
  final Duration debounce;

  static const Duration kBeat = Duration(seconds: 4);

  BrowseCopyMarks({
    required this.jobs,
    required Server? peer,
    JobsTimerFactory? timer,
    this.watchLifecycle = true,
    this.debounce = const Duration(milliseconds: 250),
  })  : peerId = peer?.federationPeerId,
        _timer = timer ?? Timer.new {
    jobs.addListener(_onJobs);
    if (watchLifecycle) {
      try {
        WidgetsBinding.instance.addObserver(this);
        _observing = true;
      } catch (_) {
        // No binding (a plain unit test): the caller drives the lifecycle.
      }
    }
  }

  final Map<String, BadgeRow> _rows = {};
  final Map<String, Map<String, dynamic>> _soon = {};

  /// Recs whose ask failed before they were ever answered: asked again by
  /// [_retry] once the back-off has passed.
  final Map<String, Map<String, dynamic>> _unanswered = {};
  int _gen = 0;
  int _failures = 0;
  bool _front = true;
  bool _foreground = true;
  bool _observing = false;
  bool _disposed = false;
  Timer? _poll;
  Timer? _soonTimer;
  Timer? _retry;
  VoidCallback? _held;

  /// [rec]'s stable key: its JSON with every map's keys sorted, so two recs
  /// built alike are one row.
  static String keyOf(Map<String, dynamic> rec) => jsonEncode(_sorted(rec));

  static Object? _sorted(Object? v) {
    if (v is Map) {
      final keys = [for (final k in v.keys) '$k']..sort();
      return {for (final k in keys) k: _sorted(v[k])};
    }
    if (v is List) return [for (final x in v) _sorted(x)];
    return v;
  }

  // ── asking ───────────────────────────────────────────────────────────

  /// Ask the lookups for [recs]: the ones not asked this visit, or every one
  /// with [fresh] (a rec whose failed ask waits on its back-off waits on,
  /// unless [fresh]).
  Future<void> ask(Iterable<Map<String, dynamic>> recs,
      {bool fresh = false}) async {
    if (_disposed) return;
    final want = <String, Map<String, dynamic>>{};
    for (final r in recs) {
      final k = keyOf(r);
      if (fresh) {
        want[k] = r;
      } else if (!_rows.containsKey(k) && !_unanswered.containsKey(k)) {
        want[k] = r;
      }
    }
    if (want.isEmpty) return;
    for (final e in want.entries) {
      _unanswered.remove(e.key);
      _rows.putIfAbsent(e.key, () => BadgeRow.of(e.value, peerId: peerId));
    }
    final gen = _gen;
    final keys = want.keys.toList();
    final results = await jobs.lookup([for (final k in keys) want[k]!]);
    if (_disposed || gen != _gen) return;
    if (results == null) {
      // No answer: the rows it never answered go back to unasked, asked
      // again once the back-off passes (a row answered before keeps its
      // marks). With the plug-ins off nothing is asked again.
      if (!jobs.pluginsOn) return;
      _failures += 1;
      for (final k in keys) {
        if (_rows[k]?.recKeys.isEmpty ?? true) {
          _rows.remove(k);
          _unanswered[k] = want[k]!;
        }
      }
      _retryLater();
      _schedule();
      return;
    }
    _failures = 0;
    final next = jobBadges([for (final k in keys) _rows[k]!], results: results);
    for (var i = 0; i < keys.length; i++) {
      if (i < results.length && results[i] != null) _rows[keys[i]] = next[i];
    }
    notifyListeners();
    _schedule();
  }

  /// The recs a failed ask never answered, asked again after the back-off.
  void _retryLater() {
    if (_disposed || _unanswered.isEmpty || _retry != null) return;
    _retry = _timer(pollDelay(kBeat, _failures), () {
      _retry = null;
      final recs = [..._unanswered.values];
      _unanswered.clear();
      unawaited(ask(recs));
    });
  }

  /// The grid's scroll: ask [recs] once the scroll settles ([debounce]),
  /// each once a visit. Only a rec not already waiting starts the wait
  /// again: a list rebuilt more often than [debounce] (a download's progress)
  /// never holds the ask off.
  void askSoon(Iterable<Map<String, dynamic>> recs) {
    if (_disposed) return;
    var added = false;
    for (final r in recs) {
      final k = keyOf(r);
      if (_rows.containsKey(k) ||
          _unanswered.containsKey(k) ||
          _soon.containsKey(k)) {
        continue;
      }
      _soon[k] = r;
      added = true;
    }
    if (!added && _soonTimer != null) return;
    if (_soon.isEmpty) return;
    _soonTimer?.cancel();
    _soonTimer = _timer(debounce, () {
      _soonTimer = null;
      final recs = [..._soon.values];
      _soon.clear();
      unawaited(ask(recs));
    });
  }

  /// Ask [rec] again now (a Keep sheet closed on it).
  Future<void> reask(Map<String, dynamic> rec) => ask([rec], fresh: true);

  /// The page now shows another server's things: every row and every ask
  /// out is dropped.
  void reset() {
    _gen += 1;
    _rows.clear();
    _soon.clear();
    _soonTimer?.cancel();
    _soonTimer = null;
    _unanswered.clear();
    _retry?.cancel();
    _retry = null;
    _failures = 0;
    _schedule();
    notifyListeners();
  }

  // ── reading ──────────────────────────────────────────────────────────

  /// [rec] was asked and answered.
  bool knows(Map<String, dynamic> rec) =>
      _rows[keyOf(rec)]?.recKeys.isNotEmpty == true;

  /// [rec]'s jobs by slot (the newest per scope under any of its keys).
  Map<String, DiscoveryJob> jobsOf(Map<String, dynamic>? rec) =>
      rec == null ? const {} : (_rows[keyOf(rec)]?.jobs ?? const {});

  /// The page pill of [scope] ([kScopeAlbum], [kScopeArtist],
  /// [kScopeFolder]) on [rec]: its job, another server's while it runs.
  KeepChoiceJob? pillJob(Map<String, dynamic>? rec, String scope) =>
      pagePillJob(jobsOf(rec), scope, peerId: peerId);

  /// This server's album job on the album page's [albumRec] (null when
  /// none, or the live one is another server's).
  DiscoveryJob? albumJob(Map<String, dynamic>? albumRec) {
    final pick = pillJob(albumRec, kScopeAlbum);
    return pick == null || pick.fromOtherPeer ? null : pick.job;
  }

  /// An album card's badge ([album] its name, else the rec's).
  JobBadge? cardBadge(Map<String, dynamic>? albumRec, {String? album}) =>
      pageCardBadge(jobsOf(albumRec),
          album: album ?? albumRec?['album'] as String?, peerId: peerId);

  /// An album card's marker ("copying 1 of 3", "in your collection", …).
  CopyMarker? cardMarker(Map<String, dynamic>? albumRec, {String? album}) =>
      pageCardMarker(jobsOf(albumRec),
          album: album ?? albumRec?['album'] as String?, peerId: peerId);

  /// An album page's song row: its own job, and the page's album job read
  /// through it ([albumRec]: the page's; nothing while that copy runs).
  CopyMarker? songMarker(Map<String, dynamic> songRec,
          {Map<String, dynamic>? albumRec}) =>
      pageSongMarker(
        song: jobsOf(songRec)[jobSlot(kCopyPlugin, kScopeSong)],
        album: albumJob(albumRec),
        filepath: songRec['filepath'] as String?,
      );

  /// A folder row's marker: its folder copies only.
  CopyMarker? folderMarker(Map<String, dynamic> folderRec) =>
      pageFolderMarker(jobsOf(folderRec));

  /// Any mark of the page is moving.
  bool get anyLive => _rows.values.any(_live);

  static bool _live(BadgeRow r) =>
      r.jobs.values.any((j) => isLive(j) && isKeepCopy(j));

  // ── the poll ─────────────────────────────────────────────────────────

  /// Whether the page is in front (a sheet over it keeps it in front; a
  /// page pushed over it, or Back, does not).
  bool get front => _front;
  set front(bool v) {
    if (v == _front || _disposed) return;
    _front = v;
    if (v && anyLive && _foreground) {
      unawaited(_tick());
    } else {
      _schedule();
    }
  }

  /// The delay until the next re-ask (null = none scheduled).
  Duration? get pollDelayNow =>
      _poll == null ? null : pollDelay(kBeat, _failures);

  bool get _beats => !_disposed && _front && _foreground && anyLive;

  void _schedule() {
    _poll?.cancel();
    _poll = null;
    if (!_beats) {
      _held?.call();
      _held = null;
      return;
    }
    _held ??= jobs.holdPage();
    _poll = _timer(pollDelay(kBeat, _failures), () {
      _poll = null;
      unawaited(_tick());
    });
  }

  Future<void> _tick() async {
    final live = [
      for (final r in _rows.values)
        if (_live(r)) r.raw,
    ];
    if (live.isEmpty) {
      _schedule();
      return;
    }
    await ask(live, fresh: true);
  }

  /// A job the controller knows of now (a start, a cancel, the poll) lands
  /// on the rows that know its key.
  void _onJobs() {
    if (_disposed || _rows.isEmpty) return;
    final mine = [...jobs.jobs.where(isKeepCopy)];
    if (mine.isEmpty) return;
    var changed = false;
    final keys = _rows.keys.toList();
    final next = jobBadges([for (final k in keys) _rows[k]!], jobs: mine);
    for (var i = 0; i < keys.length; i++) {
      final was = _rows[keys[i]]!;
      if (_signature(was) != _signature(next[i])) {
        _rows[keys[i]] = next[i];
        changed = true;
      }
    }
    if (!changed) return;
    notifyListeners();
    _schedule();
  }

  static String _signature(BadgeRow r) =>
      [for (final j in r.jobs.values) j.signature].join(',');

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
    if (fg && anyLive && _front) {
      unawaited(_tick());
    } else {
      _schedule();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _gen += 1;
    _poll?.cancel();
    _poll = null;
    _soonTimer?.cancel();
    _soonTimer = null;
    _retry?.cancel();
    _retry = null;
    _held?.call();
    _held = null;
    jobs.removeListener(_onJobs);
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    super.dispose();
  }
}
