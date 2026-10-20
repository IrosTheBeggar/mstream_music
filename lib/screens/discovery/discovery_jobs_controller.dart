import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../objects/discovery.dart';
import '../../objects/discovery_plugins.dart';
import '../../objects/server.dart';
import '../../util/discover_badges.dart';
import '../../util/discover_copy_gate.dart';
import '../../util/discover_jobs.dart';
import '../../util/discovery_plugins_api.dart';

/// How a timer is made (tests drive time themselves).
typedef JobsTimerFactory = Timer Function(Duration delay, void Function() fire);

/// What a start answered. [job] is set when the server took it (202 with a
/// new job, or 200 with the caller's own live job for the same key);
/// [error] is the server's refusal, verbatim ("Uploading Disabled",
/// "someone else on this server is already getting this — …", "you have 20
/// jobs queued or running — …"), with its [status].
class StartOutcome {
  final DiscoveryJob? job;
  final bool created;

  /// 200 created:false with ANOTHER connected server's live album or artist
  /// copy (the keys carry no server): nothing new was started — the sheet
  /// says "Copying from" that server and offers the button again once that
  /// copy ends.
  final bool fromOtherPeer;
  final String? error;
  final int? status;

  const StartOutcome(DiscoveryJob this.job,
      {required this.created, this.fromOtherPeer = false})
      : error = null,
        status = null,
        ignored = false;
  const StartOutcome.refused(String this.error, {this.status})
      : job = null,
        created = false,
        fromOtherPeer = false,
        ignored = false;

  /// Nothing was sent: the same start is already in flight, or Discover
  /// closed. Nothing to show.
  const StartOutcome.ignored()
      : job = null,
        created = false,
        fromOtherPeer = false,
        error = null,
        status = null,
        ignored = true;

  /// True only for [StartOutcome.ignored].
  final bool ignored;

  bool get ok => job != null;
}

/// What a sheet shows for one scope of a row: the row's job for it, and
/// whether that job is another connected server's copy of the same album
/// or artist ("Copying from Stage Peer C").
class SheetJob {
  final DiscoveryJob job;
  final bool fromOtherPeer;
  const SheetJob(this.job, {this.fromOtherPeer = false});
}

/// The Discover visit's plug-in jobs (Keep a copy): the plug-in listing,
/// the collection destination, the caller's jobs, and every connected-server
/// row's lookup — the markers on the page, the Copies strip's counts, the
/// sheets' job lines.
///
/// Every call goes to the user's OWN server ([ownServerOf]), never a peer's
/// virtual Server, and sends a row's recommendation exactly as received.
///
/// Polling, only while a job is live: ~1.5 s while a sheet showing a job is
/// open ([holdFast]), ~4 s while Discover is in front ([discoverVisible]),
/// otherwise stopped; doubled per failure up to 60 s; paused while the app is
/// in the background and caught up on resume. A job this controller SAW live
/// and now sees finished is news: it joins [justFinished], goes out on
/// [finished] (the toasts) and the rows are looked up again.
class DiscoveryJobsController extends ChangeNotifier
    with WidgetsBindingObserver {
  /// The user's own server.
  final Server server;
  final DiscoveryPluginsApi api;
  final JobsTimerFactory _timer;

  /// False leaves the app lifecycle to the caller
  /// ([didChangeAppLifecycleState]; tests).
  final bool watchLifecycle;

  static const Duration kFastBeat = Duration(milliseconds: 1500);
  static const Duration kDiscoverBeat = Duration(seconds: 4);

  DiscoveryJobsController({
    required Server server,
    DiscoveryPluginsApi? api,
    JobsTimerFactory? timer,
    this.watchLifecycle = true,
  })  : server = ownServerOf(server) ?? server,
        api = api ?? DiscoveryPluginsApi(server),
        _timer = timer ?? Timer.new;

  // ── state ────────────────────────────────────────────────────────────

  /// `GET /discovery/plugins`; null until it answers.
  PluginListing? listing;
  bool listingFailed = false;

  /// `GET /discovery/collection/destination`; null until it answers.
  DestinationView? destination;
  bool destinationFailed = false;
  bool savingDestination = false;

  /// The server's words for the last failed destination read or save (a
  /// save's 400 names the field: "destination layout: …").
  String? destinationError;

  /// [destinationError] is the server's own `{error}` (not a transport
  /// failure's text): the picker shows only those words verbatim.
  bool destinationErrorFromServer = false;

  /// The caller's jobs, newest first (the last `GET /plugin-jobs`, plus
  /// what this visit started or cancelled since).
  List<DiscoveryJob> jobs = const [];
  bool jobsLoaded = false;
  bool loadingJobs = false;

  /// The server's words for the last failed job list read (the Copies
  /// sheet's error state); null once a read works.
  String? jobsError;

  /// [jobsError] is the server's own `{error}` (shown verbatim under the
  /// Copies sheet's sentence), not a transport failure's text.
  bool jobsErrorFromServer = false;

  /// The last batch lookup failed outright (every chunk): the rows keep what
  /// they had.
  bool lookupFailed = false;
  bool lookingUp = false;

  final List<DiscoveryJob> _finished = [];
  final StreamController<DiscoveryJob> _finishedOut =
      StreamController<DiscoveryJob>.broadcast();

  List<DiscoveryLead> _leads = const [];
  List<BadgeRow> _rows = const [];
  final Map<DiscoveryLead, int> _leadIndex = Map.identity();
  final Set<String> _starting = {};

  int _lookupRid = 0;
  int _failures = 0;
  int _fastHolds = 0;
  bool _discoverVisible = true;
  bool _foreground = true;
  bool _observing = false;
  bool _disposed = false;
  Timer? _poll;
  Future<void>? _refreshing;
  Future<void>? _activating;

  /// The server's plug-ins are on (the ping's / boot's `discoveryPlugins`).
  /// Off: nothing is asked and nothing shows.
  bool get pluginsOn => server.discoveryPluginsAvailable == true;

  /// The rows the lookups cover, in order.
  List<DiscoveryLead> get leads => _leads;
  List<BadgeRow> get rows => _rows;

  /// Jobs this visit saw live that have finished since and settled (landed,
  /// already yours, nothing to copy, cancelled), newest first — the Copies
  /// sheet's "Just finished". One that failed or stopped is in [copies].
  /// Only the phone's copies ([isDiscoverCopy]) are news.
  List<DiscoveryJob> get justFinished =>
      List.unmodifiable(_finished.where((j) => !inTray(j)));

  /// A job this visit saw live, finished (once each).
  Stream<DiscoveryJob> get finished => _finishedOut.stream;

  // ── the gate ─────────────────────────────────────────────────────────

  /// Whether Keep a copy shows for [scope], and if not, why.
  CopyGate gate([String scope = kScopeSong]) => copyGate(
        pluginsAvailable: server.discoveryPluginsAvailable,
        listing: listing,
        listingFailed: listingFailed,
        destination: destination,
        destinationFailed: destinationFailed,
        noUpload: server.noUpload,
        scope: scope,
      );

  /// Whether the Copies list (strip, home row, sheet) can exist at all.
  bool get copiesVisible => copiesListVisible(
        pluginsAvailable: server.discoveryPluginsAvailable,
        listing: listing,
        noUpload: server.noUpload,
      );

  /// The scopes Keep a copy offers for a song row's [lead].
  List<String> scopesForRow(DiscoveryLead lead) =>
      offeredCopyScopes(lead.raw, listing?.copy);

  /// The scopes an album card offers ([cardLeads] best first): its album,
  /// and — unless it is a compilation — its artist's.
  List<String> scopesForCard(List<DiscoveryLead> cardLeads,
          {bool compilation = false}) =>
      cardLeads.isEmpty
          ? const []
          : offeredCopyScopes(cardLeads.first.raw, listing?.copy,
              card: true, compilation: compilation);

  // ── the Copies list ──────────────────────────────────────────────────

  /// The phone's copies among [jobs] ([isDiscoverCopy]): the list answers
  /// every plug-in's jobs, but a YouTube download or the webapp's folder
  /// copy is neither counted, listed, retried nor polled for here.
  Iterable<DiscoveryJob> get _copyJobs => jobs.where(isDiscoverCopy);

  /// "Copying 2 · 1 failed": the strip's and the home row's counts.
  TraySummary get summary => traySummary(_copyJobs);

  /// The live copies, then the failed or stopped ones left.
  List<DiscoveryJob> get copies => trayRows(_copyJobs);

  // ── loading ──────────────────────────────────────────────────────────

  /// Discover opened (every load of it): ask the listing, the destination
  /// and the job list — each once a visit, again only while it has not
  /// answered (a failure is asked again on the next load), or all of them
  /// with [force]. A call while one is out joins it. Nothing while plug-ins
  /// are off.
  Future<void> activate({bool force = false}) {
    if (_disposed || !pluginsOn) return Future.value();
    _attachLifecycle();
    final out = _activating;
    if (out != null && !force) return out;
    final work = Future.wait([
      if (force || listing == null) _loadListing(),
      if (force || destination == null) loadDestination(),
      if (force || !jobsLoaded) refreshJobs(),
    ]).then((_) {}).whenComplete(() => _activating = null);
    _activating = work;
    return work;
  }

  Future<void> _loadListing() async {
    try {
      final l = await api.plugins();
      if (_disposed) return;
      listing = l;
      listingFailed = false;
    } on DiscoveryPluginsException {
      if (_disposed) return;
      listingFailed = true;
    }
    _notify();
  }

  /// Read the destination again (the picker's open, Try again).
  Future<void> loadDestination() async {
    try {
      final d = await api.destination();
      if (_disposed) return;
      destination = d;
      destinationFailed = false;
      destinationError = null;
      destinationErrorFromServer = false;
    } on DiscoveryPluginsException catch (e) {
      if (_disposed) return;
      destinationFailed = destination == null;
      destinationError = e.message;
      destinationErrorFromServer = e.fromServer;
    }
    _notify();
  }

  /// The picker's Save ([value] null = "Use the library default"). True when
  /// the server took it; false with [destinationError] holding its words
  /// (400: the field it refused).
  Future<bool> saveDestination(CollectionDestination? value) async {
    if (_disposed || savingDestination) return false;
    savingDestination = true;
    destinationError = null;
    destinationErrorFromServer = false;
    _notify();
    try {
      final d = await api.saveDestination(value);
      if (_disposed) return false;
      destination = d;
      destinationFailed = false;
      return true;
    } on DiscoveryPluginsException catch (e) {
      if (_disposed) return false;
      destinationError = e.message;
      destinationErrorFromServer = e.fromServer;
      return false;
    } finally {
      savingDestination = false;
      _notify();
    }
  }

  // ── rows and lookups ─────────────────────────────────────────────────

  /// The connected servers answered (or their Try again did): these are the
  /// rows on the page now. Each is looked up (lookup/batch, in chunks of
  /// 100) so its marker is drawn from what the caller already did with it.
  /// An empty list lets go of the old rows (and any lookup still out).
  Future<void> setRows(List<DiscoveryLead> leads) async {
    if (_disposed) return;
    final rid = ++_lookupRid;
    final had = _rows.isNotEmpty;
    _leads = List.unmodifiable(leads);
    _rows = [for (final l in leads) BadgeRow.of(l.raw, peerId: l.peerId)];
    _leadIndex
      ..clear()
      ..addEntries([for (var i = 0; i < leads.length; i++) MapEntry(leads[i], i)]);
    lookupFailed = false;
    if (had || leads.isNotEmpty) _notify();
    if (!pluginsOn || leads.isEmpty) {
      lookingUp = false;
      _schedule();
      return;
    }
    await _lookup(rid);
  }

  /// Ask the lookups again for the rows on the page (a job ended, Clear
  /// finished).
  Future<void> refreshLookups() async {
    if (_disposed || !pluginsOn || _leads.isEmpty) return;
    await _lookup(++_lookupRid);
  }

  Future<void> _lookup(int rid) async {
    lookingUp = true;
    try {
      final results = _copiesOnly(
          await api.lookupBatch([for (final r in _rows) r.raw]));
      if (_disposed || rid != _lookupRid) return;
      final before = [for (final r in _rows) ...r.jobs.values.where(isLive)];
      _rows = jobBadges(_rows, results: results);
      lookupFailed = false;
      // A live job only the lookups follow (the list does not carry it)
      // ends here.
      _news(finishedSince(before, [for (final r in _rows) ...r.jobs.values]));
    } on DiscoveryPluginsException {
      if (_disposed || rid != _lookupRid) return;
      lookupFailed = true;
    }
    lookingUp = false;
    _notify();
    _schedule();
  }

  /// A lookup's answers with only the phone's copies in them: a row's
  /// marker and its sheet speak of Keep a copy alone, and another
  /// plug-in's live job on a row keeps no poll going.
  static List<JobLookup?> _copiesOnly(List<JobLookup?> results) => [
        for (final r in results)
          r == null || r.jobs.every(isDiscoverCopy)
              ? r
              : JobLookup(
                  key: r.key,
                  keys: r.keys,
                  jobs: [...r.jobs.where(isDiscoverCopy)]),
      ];

  BadgeRow? rowOf(DiscoveryLead lead) {
    final i = _leadIndex[lead];
    return i == null || i >= _rows.length ? null : _rows[i];
  }

  /// A song row's badge (null = no marker).
  JobBadge? badgeFor(DiscoveryLead lead) => rowOf(lead)?.badge;

  /// A song row's marker: glyph + word, and the strip's fraction.
  CopyMarker? markerFor(DiscoveryLead lead) =>
      copyMarkerOf(badgeFor(lead), album: lead.album);

  /// An album card's badge, from its rows' album and artist copies of THAT
  /// server ([cardLeads] best first; [album] the card's).
  JobBadge? cardBadge(List<DiscoveryLead> cardLeads, {String? album}) {
    if (cardLeads.isEmpty) return null;
    return peerAlbumBadges([
      BadgeCard(
        peerId: cardLeads.first.peerId,
        album: album ?? cardLeads.first.album,
        raws: [for (final l in cardLeads) l.raw],
      )
    ], _rows)
        .first;
  }

  /// An album card's marker ("copying 2 of 3", "in your collection", …).
  CopyMarker? cardMarker(List<DiscoveryLead> cardLeads, {String? album}) {
    final a = album ?? (cardLeads.isEmpty ? null : cardLeads.first.album);
    return copyMarkerOf(cardBadge(cardLeads, album: a), album: a);
  }

  /// The job a sheet shows for [scope] on [lead]'s row (an album card's:
  /// its best row), or null when there is none.
  SheetJob? sheetJob(DiscoveryLead lead, String scope) {
    final row = rowOf(lead);
    final job = row?.jobFor(kCopyPlugin, scope);
    if (row == null || job == null) return null;
    return SheetJob(job, fromOtherPeer: row.isOtherPeer(kCopyPlugin, scope));
  }

  // ── verbs ────────────────────────────────────────────────────────────

  static String _startKey(Map<String, dynamic> rec, String? scope) {
    String body;
    try {
      body = jsonEncode(rec);
    } catch (_) {
      body = '${identityHashCode(rec)}';
    }
    return '${scope ?? kScopeSong}|$body';
  }

  /// A start for [rec] and [scope] is in flight (the pill is busy).
  bool isStarting(Map<String, dynamic> rec, [String? scope]) =>
      _starting.contains(_startKey(rec, scope));

  /// Keep a copy: `POST /plugins/federation-copy/jobs` with the row's
  /// recommendation UNCHANGED and [scope] (none for the song). A card's
  /// album job sends its best row with scope album — never a song job from
  /// a card.
  Future<StartOutcome> start(Map<String, dynamic> rec, {String? scope}) async {
    final s = scope == null || scope == kScopeSong ? null : scope;
    final key = _startKey(rec, s);
    if (_disposed || _starting.contains(key)) {
      return const StartOutcome.ignored();
    }
    _starting.add(key);
    _notify();
    try {
      final r = await api.startJob(rec, scope: s);
      if (_disposed) return StartOutcome(r.job, created: r.created);
      _note(r.job);
      final peer = rec['peer'];
      final askedPeer = peer is Map && peer['id'] is num
          ? (peer['id'] as num).toInt()
          : null;
      final other = !r.created &&
          s != null &&
          askedPeer != null &&
          r.job.peerId != null &&
          r.job.peerId != askedPeer;
      return StartOutcome(r.job, created: r.created, fromOtherPeer: other);
    } on DiscoveryPluginsException catch (e) {
      return StartOutcome.refused(e.message, status: e.status);
    } finally {
      _starting.remove(key);
      _notify();
      _schedule();
    }
  }

  /// Retry (and Add again): the same recommendation and scope again — a
  /// failed job is never deduped, so it is a new job; the copy skips what
  /// already landed, so it takes only the gaps. Only a phone copy
  /// ([isDiscoverCopy]): another plug-in's job, or a folder copy with its
  /// landing, cannot be started again from here as it was started —
  /// nothing is sent.
  Future<StartOutcome> retry(DiscoveryJob job) async {
    if (!isDiscoverCopy(job)) return const StartOutcome.ignored();
    return start(job.recommendation, scope: job.scope);
  }

  /// Cancel: a queued job goes at once, a running one stops at its next
  /// check ("Stopping…"). A cancel that lost the race (409) reads the list
  /// again so the row turns into its outcome, and says so
  /// ([CancelOutcome.alreadyFinished]).
  Future<CancelResult> cancel(DiscoveryJob job) async {
    if (_disposed) return const CancelResult(CancelOutcome.failed);
    try {
      final r = await api.cancel(job.id);
      if (_disposed) return r;
      if (r.outcome == CancelOutcome.alreadyFinished) {
        await refreshJobs(fresh: true);
        unawaited(refreshLookups());
        return r;
      }
      final next = r.job;
      if (next != null) {
        _note(next);
        // A waiting copy is gone at once: its end is this visit's news too
        // (the Copies sheet's "Just finished", with Add again).
        if (!isLive(next)) _news([next]);
      }
      return r;
    } on DiscoveryPluginsException catch (e) {
      return CancelResult(CancelOutcome.failed, message: e.message);
    } finally {
      _notify();
      _schedule();
    }
  }

  /// Clear finished: the server drops the caller's finished rows; the list
  /// and the lookups are read again. Null with [jobsError] on failure.
  Future<int?> clearFinished() async {
    if (_disposed) return null;
    try {
      final removed = await api.clearFinished();
      if (_disposed) return removed;
      jobs = List.unmodifiable(jobs.where(isLive));
      _finished.clear();
      _notify();
      await refreshJobs();
      unawaited(refreshLookups());
      return removed;
    } on DiscoveryPluginsException catch (e) {
      jobsError = e.message;
      jobsErrorFromServer = e.fromServer;
      _notify();
      return null;
    }
  }

  /// Open elsewhere: the links plug-in's answer for [rec], asked only when
  /// the user taps. Throws [DiscoveryPluginsException] with the server's
  /// words.
  Future<List<PluginLink>> links(Map<String, dynamic> rec) => api.links(rec);

  /// A job the server answered for (a start, a cancel): first in the list,
  /// and onto every row under its key.
  void _note(DiscoveryJob job) {
    jobs = List.unmodifiable([job, ...jobs.where((j) => j.id != job.id)]);
    if (isDiscoverCopy(job)) _rows = jobBadges(_rows, jobs: [job]);
    _notify();
  }

  // ── polling ──────────────────────────────────────────────────────────

  /// Read the job list now (the poll, the Copies sheet's Try again). One at
  /// a time: a read already out is joined — with [fresh], waited out and
  /// then read again (it may predate what the caller needs to see).
  Future<void> refreshJobs({bool fresh = false}) async {
    if (_disposed || !pluginsOn) return;
    final out = _refreshing;
    if (out != null) {
      await out;
      if (!fresh || _disposed) return;
    }
    final next = _refreshing ??=
        _refreshJobs().whenComplete(() => _refreshing = null);
    await next;
  }

  /// What a listener would see change: the jobs, the rows' badges, the
  /// list's error. A poll that changes none of it notifies nobody.
  String _signature() => [
        for (final j in jobs) j.signature,
        '#',
        for (final r in _rows) r.badge?.job.signature ?? '-',
        '#$jobsError#$jobsLoaded',
      ].join(',');

  Future<void> _refreshJobs() async {
    final before = _signature();
    final firstLoad = !jobsLoaded;
    loadingJobs = true;
    // The first read draws the Copies sheet's loading state; a poll is quiet.
    if (firstLoad) _notify();
    try {
      final list = await api.jobs();
      if (_disposed) return;
      _failures = 0;
      jobsError = null;
      jobsErrorFromServer = false;
      jobsLoaded = true;
      _applyJobs(list.jobs);
    } on DiscoveryPluginsException catch (e) {
      if (_disposed) return;
      _failures += 1;
      jobsError = e.message;
      jobsErrorFromServer = e.fromServer;
    } finally {
      if (!_disposed) {
        loadingJobs = false;
        if (firstLoad || _signature() != before) _notify();
        _schedule();
      }
    }
  }

  void _applyJobs(List<DiscoveryJob> next) {
    // Seen live: in the list, or on a row (a lookup's).
    final before = [
      ...jobs,
      for (final r in _rows) ...r.jobs.values.where(isLive),
    ];
    final done = finishedSince(before, next);
    final listed = {for (final j in next) j.id};
    jobs = List.unmodifiable(next);
    _rows = jobBadges(_rows, jobs: [...next.where(isDiscoverCopy)]);
    _news(done);
    // A job ended: what the rows show may have changed beyond that job (a
    // kept song, an album the walk left out) — ask again. So too when a row
    // holds a live job the list does not carry (past its 100 newest): only a
    // lookup can say how it went.
    final unlisted = _rows.any(
        (r) => r.jobs.values.any((j) => isLive(j) && !listed.contains(j.id)));
    if (done.any(isDiscoverCopy) || (unlisted && !lookingUp)) {
      unawaited(refreshLookups());
    }
  }

  /// Jobs seen live and now finished: "Just finished", and the toasts — once
  /// each.
  void _news(List<DiscoveryJob> done) {
    for (final job in done) {
      if (!isDiscoverCopy(job)) continue;
      if (!_told.add(job.id)) continue;
      _finished
        ..removeWhere((j) => j.id == job.id)
        ..insert(0, job);
      _finishedOut.add(job);
    }
  }

  final Set<int> _told = {};

  /// Any of the phone's copies known to be queued or running: the list's,
  /// or a row's (the rows hold only copies).
  bool get anyLive =>
      _copyJobs.any(isLive) || _rows.any((r) => r.jobs.values.any(isLive));

  /// The interval the poll runs at now (null = stopped).
  Duration? get pollBeat {
    if (_disposed || !_foreground || !pluginsOn || !anyLive) return null;
    if (_fastHolds > 0) return kFastBeat;
    if (_discoverVisible) return kDiscoverBeat;
    return null;
  }

  /// The delay until the next poll (null = none scheduled).
  Duration? get pollDelayNow {
    final beat = pollBeat;
    return beat == null ? null : pollDelay(beat, _failures);
  }

  bool get pollScheduled => _poll != null;

  void _schedule() {
    _poll?.cancel();
    _poll = null;
    final delay = pollDelayNow;
    if (delay == null) return;
    _poll = _timer(delay, () {
      _poll = null;
      unawaited(refreshJobs());
    });
  }

  /// A sheet showing a job is open: poll fast while it is. Call the returned
  /// function when it closes (more than once is harmless).
  VoidCallback holdFast() {
    _fastHolds += 1;
    _schedule();
    var released = false;
    return () {
      if (released || _disposed) return;
      released = true;
      _fastHolds -= 1;
      _schedule();
    };
  }

  /// Whether Discover is in front (a screen pushed over it, or Discover
  /// left, stops the 4 s beat). Back in front catches up at once.
  bool get discoverVisible => _discoverVisible;
  set discoverVisible(bool v) {
    if (v == _discoverVisible || _disposed) return;
    _discoverVisible = v;
    if (v && anyLive && _foreground) {
      unawaited(refreshJobs());
    } else {
      _schedule();
    }
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

  /// In the background the poll pauses (the isolate is suspended anyway);
  /// back in front it catches up — what finished while away is news then.
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
        return; // a passing state (a system sheet, the app switcher)
    }
    if (fg == _foreground || _disposed) return;
    _foreground = fg;
    if (!fg) {
      _poll?.cancel();
      _poll = null;
      return;
    }
    if (anyLive) {
      unawaited(refreshJobs());
    } else {
      _schedule();
    }
  }

  // ── plumbing ─────────────────────────────────────────────────────────

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _poll?.cancel();
    _poll = null;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    unawaited(_finishedOut.close());
    super.dispose();
  }
}
