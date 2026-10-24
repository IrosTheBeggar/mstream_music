import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../l10n/app_localizations.dart';
import '../../objects/discovery_plugins.dart';
import '../../objects/server.dart';
import '../../singletons/api.dart';
import '../../singletons/app_messenger.dart';
import '../../singletons/browser_list.dart';
import '../../singletons/server_list.dart';
import '../../util/browse_keep_leads.dart' show isKeepPeer;
import '../../util/discover_copy_gate.dart';
import '../../util/discovery_plugins_api.dart' show ownServerOf;
import 'copy_news.dart';
import 'discovery_jobs_controller.dart';
import 'discovery_listing.dart';
import 'keep_toast.dart';

/// What a connected server's pages know of Keep a copy's gate: not read yet
/// ([unknown]: no way in yet), [open] for at least one scope, or [closed] —
/// plug-ins off, the copy plug-in not listed, jobs not allowed, no upload
/// right, no library, the read failed, or it did not answer in time.
enum KeepGateState { unknown, open, closed }

/// Keep a copy's gate on a user's own server as a connected server's pages
/// read it (CopiesHub.gateFor), immutable: a page snapshots it on its first
/// build and keeps it until a Keep sheet closes on it or navigation builds
/// it again, so a way in never appears or vanishes under the thumb.
class KeepGateSnapshot {
  final KeepGateState state;

  /// The scopes a browse way in may offer: each one's [copyGate] ready
  /// (Folder as from the file explorer — only the explorer offers it).
  final Set<String> scopes;

  /// The most songs one folder copy takes (`jobs.maxFolderSongs`); null
  /// from an older server (no cap line).
  final int? maxFolderSongs;

  /// Where files land, with the libraries the account may write to; null
  /// until read.
  final DestinationView? destination;

  /// Lookups may be asked (the own server's ping says plug-ins): earlier
  /// copies keep their marks whatever the gate says.
  final bool marks;

  const KeepGateSnapshot({
    required this.state,
    this.scopes = const {},
    this.maxFolderSongs,
    this.destination,
    this.marks = false,
  });

  static const KeepGateSnapshot unknown =
      KeepGateSnapshot(state: KeepGateState.unknown);
  static const KeepGateSnapshot closed =
      KeepGateSnapshot(state: KeepGateState.closed);

  /// [jobs]' gate now; [timedOut]: the read did not answer in time, which
  /// counts as closed until it does.
  factory KeepGateSnapshot.of(DiscoveryJobsController jobs,
      {bool timedOut = false}) {
    final gates = {
      for (final scope in kKeepJobScopes)
        scope: jobs.gate(scope, KeepEntry.explorer),
    };
    final ready = {
      for (final e in gates.entries)
        if (e.value.ready) e.key,
    };
    final asking =
        gates.values.any((g) => g.status == CopyGateStatus.unknown);
    return KeepGateSnapshot(
      state: ready.isNotEmpty
          ? KeepGateState.open
          : (asking && !timedOut ? KeepGateState.unknown : KeepGateState.closed),
      scopes: Set.unmodifiable(ready),
      maxFolderSongs: jobs.listing?.maxFolderSongs,
      destination: jobs.destination,
      marks: jobs.pluginsOn,
    );
  }

  bool get open => state == KeepGateState.open;

  /// A way in for [scope] exists.
  bool allows(String scope) => open && scopes.contains(scope);

  CollectionDestination? get place => destination?.destination;
  List<WritableLibrary> get libraries =>
      destination?.libraries ?? const <WritableLibrary>[];
}

/// The app's copies, one [DiscoveryJobsController] per own server, shared
/// by everything that shows them: Discover (its markers, strip and sheets),
/// the home's SERVER "Copies" row, and the Copies sheet from either. One
/// poll, one set of "just finished", one toast per ending.
///
/// The home row shows only when copies are possible (the server's plug-ins
/// on, the account may upload, federation-copy listed, jobs allowed —
/// [DiscoveryJobsController.copiesVisible]): the hub asks the listing when
/// the home is shown and rebuilds the home once the answer changes what it
/// holds. While the home is in front with a copy live, the poll keeps
/// Discover's beat so the row's counts move; elsewhere (Discover aside,
/// which drives its own) it stops.
///
/// It also holds Keep a copy's gate as a connected server's pages read it
/// ([gateFor], [ensureGate]): read on every move onto a connected server
/// (the home holds its taps for it, [holdPeerHome]), retried in the
/// background on each later step there while it failed or timed out, and
/// read again after a start the server answered 403 or 404.
///
/// [install] wires it into the app (main.dart); until then nothing uses it
/// and Discover keeps a controller of its own (tests).
class CopiesHub {
  CopiesHub._();
  static final CopiesHub _instance = CopiesHub._();
  factory CopiesHub() => _instance;

  /// How a server's controller is made (tests wire one to their fakes).
  DiscoveryJobsController Function(Server server) makeJobs = _defaultMakeJobs;

  static DiscoveryJobsController _defaultMakeJobs(Server server) =>
      DiscoveryJobsController(server: server);

  /// Where an ending's toast goes (the root overlay's by default).
  void Function(String message)? toast;

  /// The words a toast reads (the app's navigator context's by default).
  AppLocalizations? Function() l10n = _rootL10n;

  static AppLocalizations? _rootL10n() {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return null;
    try {
      return AppLocalizations.of(ctx);
    } catch (_) {
      return null;
    }
  }

  final Map<Server, DiscoveryJobsController> _jobs = Map.identity();
  final Map<Server, StreamSubscription> _news = Map.identity();
  final Map<Server, VoidCallback> _listeners = Map.identity();

  /// What the home was last built with, per server ([showsHomeRow]).
  final Map<Server, bool> _rowShown = Map.identity();

  StreamSubscription? _stackSub;
  Object? _lastFrame;

  /// When the home last asked a server's copies (a home drawn twice in a
  /// row asks once).
  final Map<Server, DateTime> _asked = Map.identity();

  /// Own servers whose gate read did not answer in time: closed for that
  /// visit, until a later answer lands.
  final Set<Server> _gateTimedOut = Set.identity();
  bool _installed = false;

  bool get installed => _installed;

  /// Wire the hub into the app: the home's row and the browser stack.
  void install() {
    if (_installed) return;
    _installed = true;
    BrowserManager.homeCopiesRow = showsHomeRow;
    BrowserManager.peerHomeGate = holdPeerHome;
    ApiManager.onPeerNotAnswering = _peerNotAnswering;
    _stackSub = BrowserManager().browserListStream.listen((_) => _onStack());
  }

  /// A connected server's browse call got no answer: "Stage Peer B not
  /// answering" — the page stays as it was.
  void _peerNotAnswering(Server peer) {
    final l = l10n();
    if (l == null) return;
    final m =
        l.discoverSheetPeerNotAnswering(peer.federationPeerName ?? peer.displayName);
    final t = toast;
    if (t != null) {
      t(m);
    } else {
      KeepToast.show(null, m);
    }
  }

  /// Undo [install] and let every controller go (tests).
  void reset() {
    unawaited(_stackSub?.cancel());
    _stackSub = null;
    _lastFrame = null;
    _installed = false;
    BrowserManager.homeCopiesRow = BrowserManager.noCopiesRow;
    BrowserManager.peerHomeGate = BrowserManager.noPeerHomeGate;
    ApiManager.onPeerNotAnswering = null;
    _gateTimedOut.clear();
    for (final e in _jobs.entries) {
      final listener = _listeners[e.key];
      if (listener != null) e.value.removeListener(listener);
      unawaited(_news[e.key]?.cancel());
      e.value.dispose();
    }
    _jobs.clear();
    _news.clear();
    _listeners.clear();
    _rowShown.clear();
    _asked.clear();
    makeJobs = _defaultMakeJobs;
    toast = null;
    l10n = _rootL10n;
  }

  /// [server]'s own server's copies (one controller each, kept for the
  /// app's life).
  DiscoveryJobsController jobsFor(Server server) {
    final own = ownServerOf(server) ?? server;
    final have = _jobs[own];
    if (have != null) return have;
    final jobs = makeJobs(own);
    _jobs[own] = jobs;
    void listener() => _onJobs(own);
    _listeners[own] = listener;
    jobs.addListener(listener);
    _news[own] = attachCopyToasts(
      jobs,
      l10n: () => l10n(),
      show: (m) {
        final t = toast;
        if (t != null) {
          t(m);
        } else {
          KeepToast.show(null, m);
        }
      },
    );
    return jobs;
  }

  /// Whether [jobs] is one of the hub's (shared, never disposed by a page).
  bool owns(DiscoveryJobsController jobs) => _jobs.containsValue(jobs);

  // ── the gate a connected server's pages read ──────────────────────────

  /// Keep a copy's gate for [server]'s own server now (a connected server's
  /// parent): unknown until it has been read, closed when there is no own
  /// server, its plug-ins are off, or the read did not answer in time.
  KeepGateSnapshot gateFor(Server? server) {
    final own = ownServerOf(server);
    if (own == null || own.discoveryPluginsAvailable != true) {
      return KeepGateSnapshot.closed;
    }
    return KeepGateSnapshot.of(jobsFor(own),
        timedOut: _gateTimedOut.contains(own));
  }

  /// Read [server]'s own server's gate — what has not answered yet, or with
  /// [fresh] the listing and the destination again — and answer it, waiting
  /// at most [timeout]: past it a gate still unknown counts as closed, and
  /// the answer that lands later applies from the next page build.
  Future<KeepGateSnapshot> ensureGate(Server? server,
      {bool fresh = false,
      Duration timeout = BrowserManager.kPeerGateWait}) async {
    final own = ownServerOf(server);
    if (own == null || own.discoveryPluginsAvailable != true) {
      return gateFor(server);
    }
    final jobs = jobsFor(own);
    final ask = fresh ? jobs.regate() : jobs.activate();
    unawaited(ask.whenComplete(() => _gateTimedOut.remove(own)));
    try {
      await ask.timeout(timeout);
    } on TimeoutException {
      if (KeepGateSnapshot.of(jobs).state == KeepGateState.unknown) {
        _gateTimedOut.add(own);
      }
    }
    return gateFor(own);
  }

  /// Moving onto connected server [peer] (BrowserManager.peerHomeGate): its
  /// own server's gate is read again; the home waits for it only while it is
  /// not known yet — null otherwise.
  Future<void>? holdPeerHome(Server peer) {
    final own = peer.parentServer;
    if (own == null || own.discoveryPluginsAvailable != true) return null;
    final known = gateFor(own).state != KeepGateState.unknown;
    final ask = ensureGate(own, fresh: true).then<void>((_) {});
    return known ? null : ask;
  }

  /// The home's SERVER section shows "Copies" for [server]: the flags say
  /// copies can exist and the listing said so. Read when the home is built.
  /// A connected server's home shows the same card for its own server's
  /// copies.
  bool showsHomeRow(Server server) {
    final shown = _possible(server);
    _rowShown[server] = shown;
    return shown;
  }

  bool _possible(Server server) {
    if (server.isFederated && !isKeepPeer(server)) return false;
    final own = ownServerOf(server);
    if (own == null) return false;
    if (own.discoveryPluginsAvailable != true || own.noUpload == true) {
      return false;
    }
    return _jobs[own]?.copiesVisible == true;
  }

  /// A server's copies changed: when the home row's being there changed,
  /// the home is drawn again (only while it is what the user sees — the
  /// server's own, or a connected server's of it).
  void _onJobs(Server own) {
    final current = ServerManager().currentServer;
    if (current == null || !identical(ownServerOf(current), own)) return;
    final before = _rowShown[current];
    if (before == null || before == _possible(current)) return;
    if (!BrowserManager.isHomeList(BrowserManager().browserList)) return;
    BrowserManager().goToNavScreen();
  }

  /// Every browser-stack change: the home in front asks its server's
  /// copies (once per home shown) and keeps their poll beating; anything
  /// else stops it — except Discover, whose listing drives its own.
  void _onStack() {
    final bm = BrowserManager();
    final frame = bm.browserCache.isEmpty ? null : bm.browserCache.last;
    final fresh = !identical(frame, _lastFrame);
    _lastFrame = frame;
    final top = bm.browserList;
    final current = ServerManager().currentServer;
    final own = current == null ? null : ownServerOf(current);
    final onHome = BrowserManager.isHomeList(top);
    final discover = DiscoveryListing.isListing(top)
        ? DiscoveryListing().controller?.jobs
        : null;
    // Back on a home drawn before the listing answered: draw it again.
    final drawn = current == null ? null : _rowShown[current];
    if (onHome && drawn != null && drawn != _possible(current!)) {
      bm.goToNavScreen();
      return;
    }
    if (onHome &&
        fresh &&
        own != null &&
        own.discoveryPluginsAvailable == true &&
        own.noUpload != true) {
      final jobs = jobsFor(own);
      final last = _asked[own];
      final now = DateTime.now();
      if (current!.isFederated) {
        // Moving onto it read the gate (holdPeerHome): the counts only.
        if (jobs.jobsLoaded &&
            (last == null ||
                now.difference(last) > const Duration(seconds: 3))) {
          _asked[own] = now;
          unawaited(jobs.refreshJobs());
        }
      } else if (jobs.listing == null || jobs.destination == null) {
        _asked[own] = now;
        unawaited(jobs.activate());
      } else if (last == null ||
          now.difference(last) > const Duration(seconds: 3)) {
        _asked[own] = now;
        unawaited(jobs.refreshJobs());
      }
    }
    // A step inside a connected server: a gate that failed or did not
    // answer in time is asked again behind it (it applies from the next
    // page built).
    if (fresh && !onHome && current != null && current.isFederated) {
      _retryGate(current);
    }
    for (final e in _jobs.entries) {
      if (identical(e.value, discover)) continue;
      e.value.discoverVisible = onHome && identical(e.key, own);
    }
  }

  void _retryGate(Server peer) {
    final own = peer.parentServer;
    if (own == null || own.discoveryPluginsAvailable != true) return;
    final gate = gateFor(own);
    if (gate.open) return;
    final jobs = jobsFor(own);
    // Closed for a reason the server gave (no upload right, jobs not
    // allowed…) stays closed; not read yet, failed or too slow is asked.
    if (gate.state == KeepGateState.unknown ||
        jobs.listingFailed ||
        jobs.destinationFailed ||
        _gateTimedOut.contains(own)) {
      unawaited(ensureGate(own));
    }
  }

  /// Discover opened on [server]: its visit reads the listing, the
  /// destination and the job list afresh.
  DiscoveryJobsController visit(Server server) {
    final jobs = jobsFor(server);
    unawaited(jobs.activate(force: true));
    return jobs;
  }
}
