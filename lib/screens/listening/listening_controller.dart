import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../objects/listening_stats.dart';
import '../../objects/play_event.dart';
import '../../objects/server.dart';
import '../../singletons/log_manager.dart';
import '../../singletons/play_history.dart';
import '../../singletons/play_sync.dart';
import '../../singletons/server_list.dart';
import '../../util/server_tree.dart';
import '../../util/stats_api.dart';

/// What the page is looking at: this phone's own record, or one server's
/// per-user record (the parent's, for a federated peer, narrowed to peers'
/// tracks).
class ListeningScope {
  final bool isDevice;

  /// The server whose Stats API answers (a peer's parent for a peer).
  final Server? server;

  /// The server the user picked — the peer itself when [server] is its parent.
  final Server? picked;

  const ListeningScope.device()
      : isDevice = true,
        server = null,
        picked = null;
  const ListeningScope.server(this.server, {this.picked}) : isDevice = false;

  bool get isPeer => picked != null && picked!.isFederated;
  String get origin => isPeer ? 'peers' : 'all';
  String get key => isDevice ? 'device' : 'server:${(picked ?? server)!.localname}';

  @override
  bool operator ==(Object other) => other is ListeningScope && other.key == key;
  @override
  int get hashCode => key.hashCode;
}

/// The Listening page's data: one scope and one period at a time, the same
/// shapes for both scopes (PLAY_HISTORY_PLAN.md §7, the 2026-09-07 design).
///
/// Device scope reads the ring in memory through [DeviceStats]; server scope
/// asks the server's Stats API v2 through [StatsApi]. A server that does not
/// answer falls back to this phone's plays ON that server, labelled as such
/// ([fellBack]); a server without the capability is [legacy].
class ListeningController extends ChangeNotifier {
  final StatsApi Function(Server) apiFor;
  final DateTime Function() now;

  ListeningController({Server? initial, StatsApi Function(Server)? apiFor, DateTime Function()? now})
      : apiFor = apiFor ?? ((s) => StatsApi(s)),
        now = now ?? DateTime.now {
    scope = initial != null ? ListeningScope.server(initial.statsServer ?? initial, picked: initial) : const ListeningScope.device();
    _historySub = PlayHistory().changes.listen((_) => _onLocalChange());
    _syncSub = PlaySync().changes.listen((_) => _refreshUnsynced());
  }

  late ListeningScope scope;
  StatsPeriod period = StatsPeriod.month;
  String topEntity = 'tracks';
  String topMetric = 'plays';

  bool loading = false;
  String? error;
  bool fellBack = false;
  bool legacy = false;
  ListeningSummary summary = const ListeningSummary();
  List<TopItem> top = const [];
  List<HistoryItem> history = const [];
  List<int> hours = List<int>.filled(24, 0);
  String? _historyNext;
  bool loadingMore = false;
  int unsynced = 0;
  bool historyEnabled = true;
  bool sendEnabled = true;

  StreamSubscription<void>? _historySub;
  StreamSubscription<void>? _syncSub;
  Timer? _localDebounce;
  int _generation = 0;

  bool get hasMore => !scope.isDevice && _historyNext != null;

  /// Servers the page can show: every stats-capable server, peers under
  /// their parents (a peer counts on its parent).
  List<Server> get servers => serversGrouped(ServerManager().serverList).where((s) => s.isSelectable).toList();

  /// Which of [servers] answer the Stats API.
  bool serverHasStats(Server s) => s.statsCapable;

  String? peerNameFor(String? localname) => localname == null ? null : ServerManager().byLocalname(localname)?.displayName;

  void setScope(ListeningScope s) {
    if (s == scope) return;
    scope = s;
    _reset();
    unawaited(load());
  }

  void setPeriod(StatsPeriod p) {
    if (p == period) return;
    period = p;
    unawaited(load());
  }

  void setTop({String? entity, String? metric}) {
    var changed = false;
    if (entity != null && entity != topEntity) {
      topEntity = entity;
      changed = true;
    }
    if (metric != null && metric != topMetric) {
      topMetric = metric;
      changed = true;
    }
    if (changed) unawaited(load(quiet: true));
  }

  void _reset() {
    summary = const ListeningSummary();
    top = const [];
    history = const [];
    hours = List<int>.filled(24, 0);
    _historyNext = null;
    error = null;
    fellBack = false;
    legacy = false;
  }

  void _onLocalChange() {
    _localDebounce?.cancel();
    _localDebounce = Timer(const Duration(milliseconds: 400), () {
      _refreshUnsynced();
      if (scope.isDevice || fellBack) unawaited(load(quiet: true));
    });
  }

  void _refreshUnsynced() {
    final h = PlayHistory();
    int n;
    if (scope.isDevice) {
      n = h.outboxCount;
    } else {
      n = h.pending(scope.server!.localname, limit: kOutboxCap).length;
    }
    if (n != unsynced) {
      unsynced = n;
      notifyListeners();
    }
  }

  Future<void> load({bool quiet = false}) async {
    final gen = ++_generation;
    if (!quiet) {
      loading = true;
      error = null;
      notifyListeners();
    }
    historyEnabled = PlayHistory().enabled;
    sendEnabled = PlaySync().enabled;
    try {
      if (scope.isDevice) {
        await _loadDevice(filter: null);
      } else if (!scope.server!.statsCapable) {
        legacy = true;
        fellBack = false;
        await _loadDevice(filter: scope.picked ?? scope.server);
      } else {
        try {
          await _loadServer();
          fellBack = false;
          legacy = false;
        } on StatsApiException catch (e) {
          if (e.isMissing) {
            legacy = true;
            await _loadDevice(filter: scope.picked ?? scope.server);
          } else {
            appLog('[listening] ${scope.server!.localname}: ${e.message}; showing this phone\'s copy');
            fellBack = true;
            await _loadDevice(filter: scope.picked ?? scope.server);
          }
        } catch (e) {
          appLog('[listening] ${scope.server!.localname}: $e; showing this phone\'s copy');
          fellBack = true;
          await _loadDevice(filter: scope.picked ?? scope.server);
        }
      }
      if (gen != _generation) return;
      _refreshUnsynced();
    } catch (e) {
      if (gen != _generation) return;
      error = e.toString();
    } finally {
      if (gen == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadDevice({Server? filter}) async {
    final all = await PlayHistory().events();
    final events = filter == null ? all : all.where((e) => e.track.server == filter.localname).toList();
    final r = period.range(now());
    summary = DeviceStats.summary(events, from: r.from, to: r.to, now: now());
    top = _nameDevicePeers(DeviceStats.top(events, entity: topEntity, metric: topMetric, from: r.from, to: r.to, limit: 10, peerName: (_) => null));
    history = HistoryItem.collapse(DeviceStats.history(events, from: r.from, to: r.to, limit: 60).map(_namePeer).toList());
    hours = DeviceStats.hourOfDay(events, from: r.from, to: r.to);
    _historyNext = null;
  }

  List<TopItem> _nameDevicePeers(List<TopItem> items) =>
      items.map((t) => t.fromPeer ? t.withPeerName(peerNameFor(t.server)) : t).toList();

  HistoryItem _namePeer(HistoryItem i) => i.fromPeer ? i.withPeerName(peerNameFor(i.server)) : i;

  Future<void> _loadServer() async {
    final api = apiFor(scope.server!);
    final origin = scope.origin;
    final results = await Future.wait([
      api.summary(period: period, origin: origin),
      api.top(entity: topEntity, metric: topMetric, period: period, origin: origin, limit: 10),
      api.history(period: period, origin: origin, limit: 30),
      api.hourOfDay(period: period, origin: origin),
    ]);
    summary = results[0] as ListeningSummary;
    top = results[1] as List<TopItem>;
    final h = results[2] as ({List<HistoryItem> items, String? next});
    history = HistoryItem.collapse(h.items);
    _historyNext = h.next;
    hours = results[3] as List<int>;
  }

  Future<void> loadMoreHistory() async {
    if (!hasMore || loadingMore || scope.isDevice) return;
    loadingMore = true;
    notifyListeners();
    try {
      final api = apiFor(scope.server!);
      final h = await api.history(period: period, origin: scope.origin, limit: 30, before: _historyNext);
      history = HistoryItem.collapse([...history, ...h.items]);
      _historyNext = h.next;
    } catch (e) {
      appLog('[listening] more history failed: $e');
      _historyNext = null;
    } finally {
      loadingMore = false;
      notifyListeners();
    }
  }

  /// Events of this phone for a server-scope row's track, for Song Info.
  Future<PlayEvent?> lastDeviceEventFor(String server, String path) async {
    final events = await PlayHistory().events();
    for (var i = events.length - 1; i >= 0; i--) {
      if (events[i].track.server == server && events[i].track.path == path) return events[i];
    }
    return null;
  }

  @override
  void dispose() {
    _historySub?.cancel();
    _syncSub?.cancel();
    _localDebounce?.cancel();
    super.dispose();
  }
}
