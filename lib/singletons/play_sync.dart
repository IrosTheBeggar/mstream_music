import 'dart:async';

import '../objects/play_event.dart';
import 'log_manager.dart';
import 'play_history.dart';

/// What the sync layer needs to know about a server, without depending on
/// the server list directly (tests hand in a table).
class SyncTarget {
  /// The server that receives the event: itself, or the parent of a
  /// federated peer.
  final String localname;

  /// Stats API v2 present (`features.stats >= 2`).
  final bool statsCapable;

  /// Reachable now — false while an iroh tunnel is not serving the server.
  final bool reachable;

  const SyncTarget({required this.localname, required this.statsCapable, this.reachable = true});
}

/// The server's answer to one `POST /api/v1/stats/plays`.
class PostPlaysResult {
  final List<String> accepted;
  final List<String> duplicates;
  final Map<String, String> rejected; // id → reason
  const PostPlaysResult({this.accepted = const [], this.duplicates = const [], this.rejected = const {}});

  Iterable<String> get settled => [...accepted, ...duplicates, ...rejected.keys];

  static PostPlaysResult fromJson(Map<dynamic, dynamic> j) {
    List<String> ids(dynamic v) => v is List ? v.whereType<String>().toList() : const [];
    final rej = <String, String>{};
    if (j['rejected'] is List) {
      for (final r in j['rejected'] as List) {
        if (r is Map && r['id'] is String) rej[r['id'] as String] = r['reason'] is String ? r['reason'] as String : 'rejected';
      }
    }
    return PostPlaysResult(accepted: ids(j['accepted']), duplicates: ids(j['duplicates']), rejected: rej);
  }
}

/// Why a POST did not settle its batch.
enum PostFailure { network, unauthorized, server }

class PostPlaysException implements Exception {
  final PostFailure kind;
  final String message;
  const PostPlaysException(this.kind, this.message);
  @override
  String toString() => 'PostPlaysException(${kind.name}: $message)';
}

/// Per-target retry timing: 1 → 2 → 4 … minutes, capped at 30, reset by a
/// success. Pure; the clock is an input.
class Backoff {
  static const Duration first = Duration(minutes: 1);
  static const Duration cap = Duration(minutes: 30);

  final Map<String, ({int failures, DateTime until})> _state = {};

  bool blocked(String target, DateTime now) {
    final s = _state[target];
    return s != null && now.isBefore(s.until);
  }

  Duration? remaining(String target, DateTime now) {
    final s = _state[target];
    if (s == null || !now.isBefore(s.until)) return null;
    return s.until.difference(now);
  }

  void failed(String target, DateTime now) {
    final failures = (_state[target]?.failures ?? 0) + 1;
    var wait = first * (1 << (failures - 1).clamp(0, 10));
    if (wait > cap) wait = cap;
    _state[target] = (failures: failures, until: now.add(wait));
  }

  void succeeded(String target) => _state.remove(target);

  void clear() => _state.clear();
}

/// Routes closed sessions to the server that owns the user's stats and
/// drains the outbox (PLAY_HISTORY_PLAN.md §6).
///
/// - a server track goes to its server; a federated peer's track goes to
///   the peer's PARENT with `peerId` and the snapshot (the event already
///   carries both); a local-device file goes nowhere.
/// - only a target with Stats API v2 is posted to; no flag, no probing.
/// - a target that is not reachable right now (iroh tunnel down) keeps its
///   events in the outbox; a drain runs on every trigger (a session close,
///   app resume, connectivity, a tunnel coming up, a timer while playing).
/// - per target: oldest first, at most 200 per POST; `accepted`,
///   `duplicates` and `rejected` all settle (a rejection is logged);
///   a network failure backs the target off; 401/403 parks it until its
///   credentials change; any other failure waits for the next trigger.
///
/// The HTTP call and the server table are injected so the whole policy
/// runs under test with fakes.
class PlaySync {
  PlaySync._();
  static final PlaySync _instance = PlaySync._();
  factory PlaySync() => _instance;

  static const int batchSize = 200;
  static const Duration playingTick = Duration(minutes: 5);

  /// Resolve a localname to what the sync needs, or null for an unknown
  /// server. Set by main; replaced under test.
  SyncTarget? Function(String localname) resolveTarget = (_) => null;

  /// The parent's localname for a federated server, or the server itself.
  String Function(String localname) targetFor = (name) => name;

  /// The POST. Throws [PostPlaysException] on failure.
  Future<PostPlaysResult> Function(String target, List<PlayEvent> batch) post =
      (_, _) async => throw const PostPlaysException(PostFailure.network, 'no transport');

  DateTime Function() now = () => DateTime.now().toUtc();

  /// Off = record locally only, and the outbox is emptied.
  bool enabled = true;

  final Backoff backoff = Backoff();
  final Set<String> _parked = {}; // 401/403 until credentials change
  Future<void>? _draining;
  StreamSubscription<PlayEvent>? _sub;
  Timer? _tick;

  /// Counters for the settings copy and the smoke recipe.
  int posted = 0;
  int rejected = 0;
  DateTime? lastPostAt;
  String? lastError;

  final StreamController<void> _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Subscribe to the tracker's closed sessions.
  void start(Stream<PlayEvent> events) {
    _sub?.cancel();
    _sub = events.listen(onEvent);
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _tick?.cancel();
  }

  /// A session closed: queue it for its target and try to drain.
  Future<void> onEvent(PlayEvent e) async {
    if (!enabled) return;
    if (e.track.isLocalFile) return;
    final target = targetFor(e.track.server);
    await PlayHistory().enqueue(target, e);
    _notify();
    unawaited(drain(reason: 'session'));
  }

  /// Credentials changed for a server: it may be posted to again.
  void unpark(String localname) {
    _parked.remove(localname);
    backoff.succeeded(localname);
  }

  void setEnabled(bool on) {
    enabled = on;
    if (!on) {
      unawaited(PlayHistory().purgeOutbox());
      _notify();
    } else {
      unawaited(drain(reason: 'enabled'));
    }
  }

  /// Keep a drain going while the player is running.
  void setPlaying(bool playing) {
    _tick?.cancel();
    _tick = playing ? Timer.periodic(playingTick, (_) => drain(reason: 'tick')) : null;
  }

  /// Drain every target with pending events. One drain at a time; a second
  /// call while one runs is folded into it.
  Future<void> drain({String reason = 'manual'}) {
    final running = _draining;
    if (running != null) return running;
    final f = _drain(reason).catchError((Object e) {
      appLog('[sync] drain failed: $e');
    }).whenComplete(() {
      _draining = null;
    });
    _draining = f;
    return f;
  }

  Future<void> _drain(String reason) async {
    if (!enabled) return;
    final history = PlayHistory();
    await history.init();
    final targets = history.outbox.keys.toList();
    for (final target in targets) {
      await _drainTarget(target);
    }
  }

  Future<void> _drainTarget(String target) async {
    final history = PlayHistory();
    final t = resolveTarget(target);
    if (t == null) {
      // The server is gone: its events can never land. Cascade removal
      // normally purges them first; this is the belt to those braces.
      await history.purgeOutbox(target: target);
      return;
    }
    if (!t.statsCapable || !t.reachable || _parked.contains(target)) return;
    while (true) {
      final at = now();
      if (backoff.blocked(target, at)) return;
      final batch = history.pending(target, limit: batchSize);
      if (batch.isEmpty) return;
      try {
        final r = await post(target, batch);
        await history.settle(target, r.settled);
        backoff.succeeded(target);
        posted += r.accepted.length;
        rejected += r.rejected.length;
        lastPostAt = at;
        lastError = null;
        for (final e in r.rejected.entries) {
          appLog('[sync] $target rejected play ${e.key}: ${e.value}');
        }
        // The server answered nothing we sent: nothing settled, nothing to
        // gain from asking again with the same batch.
        if (r.settled.isEmpty) {
          appLog('[sync] $target answered without settling any of ${batch.length} play(s); waiting for the next trigger');
          return;
        }
        _notify();
      } on PostPlaysException catch (e) {
        lastError = '$target: ${e.message}';
        switch (e.kind) {
          case PostFailure.unauthorized:
            _parked.add(target);
            appLog('[sync] $target refused the plays (${e.message}); parked until its credentials change');
            break;
          case PostFailure.network:
            backoff.failed(target, at);
            appLog('[sync] $target unreachable (${e.message}); retry in ${backoff.remaining(target, at)?.inMinutes ?? 0} min');
            break;
          case PostFailure.server:
            appLog('[sync] $target failed (${e.message}); waiting for the next trigger');
            break;
        }
        _notify();
        return;
      }
    }
  }

  /// Under test: forget parked targets, backoff, counters, subscriptions.
  void resetForTest() {
    dispose();
    _parked.clear();
    backoff.clear();
    enabled = true;
    posted = 0;
    rejected = 0;
    lastPostAt = null;
    lastError = null;
    resolveTarget = (_) => null;
    targetFor = (name) => name;
    now = () => DateTime.now().toUtc();
  }

  bool isParked(String target) => _parked.contains(target);
}
