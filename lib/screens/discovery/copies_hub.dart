import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../l10n/app_localizations.dart';
import '../../objects/server.dart';
import '../../singletons/app_messenger.dart';
import '../../singletons/browser_list.dart';
import '../../singletons/server_list.dart';
import '../../util/discovery_plugins_api.dart' show ownServerOf;
import 'copy_news.dart';
import 'discovery_jobs_controller.dart';
import 'discovery_listing.dart';
import 'keep_toast.dart';

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
  bool _installed = false;

  bool get installed => _installed;

  /// Wire the hub into the app: the home's row and the browser stack.
  void install() {
    if (_installed) return;
    _installed = true;
    BrowserManager.homeCopiesRow = showsHomeRow;
    _stackSub = BrowserManager().browserListStream.listen((_) => _onStack());
  }

  /// Undo [install] and let every controller go (tests).
  void reset() {
    unawaited(_stackSub?.cancel());
    _stackSub = null;
    _lastFrame = null;
    _installed = false;
    BrowserManager.homeCopiesRow = BrowserManager.noCopiesRow;
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

  /// The home's SERVER section shows "Copies" for [server]: the flags say
  /// copies can exist and the listing said so. Read when the home is built.
  bool showsHomeRow(Server server) {
    final shown = _possible(server);
    _rowShown[server] = shown;
    return shown;
  }

  bool _possible(Server server) {
    if (server.isFederated) return false;
    if (server.discoveryPluginsAvailable != true || server.noUpload == true) {
      return false;
    }
    return _jobs[server]?.copiesVisible == true;
  }

  /// A server's copies changed: when the home row's being there changed,
  /// the home is drawn again (only while it is what the user sees).
  void _onJobs(Server server) {
    final before = _rowShown[server];
    if (before == null || before == _possible(server)) return;
    if (!identical(ServerManager().currentServer, server)) return;
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
        current != null &&
        !current.isFederated &&
        current.discoveryPluginsAvailable == true &&
        current.noUpload != true) {
      final jobs = jobsFor(current);
      final last = _asked[current];
      final now = DateTime.now();
      if (jobs.listing == null || jobs.destination == null) {
        _asked[current] = now;
        unawaited(jobs.activate());
      } else if (last == null ||
          now.difference(last) > const Duration(seconds: 3)) {
        _asked[current] = now;
        unawaited(jobs.refreshJobs());
      }
    }
    for (final e in _jobs.entries) {
      if (identical(e.value, discover)) continue;
      e.value.discoverVisible = onHome && identical(e.key, current);
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
