import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../objects/play_event.dart';
import '../util/write_chain.dart';
import 'log_manager.dart';

/// The device's own listening record: what THIS phone played, on every
/// server and for local files, kept in three bounded files next to
/// `queue.json` (PLAY_HISTORY_PLAN.md §5):
///
/// - `play_history.jsonl` — the ring: one [PlayEvent] per line, newest last,
///   append-only in the hot path; past [ringCompactAt] lines the newest
///   [ringCap] are rewritten into a fresh file.
/// - `play_stats.json` — the aggregates folded at record time: per-track
///   counters, per-day and per-month rollups. Rewritten whole, debounced.
/// - `play_outbox.json` — events not yet accepted by their target server,
///   grouped by target localname, capped and aged out. Owned by the sync
///   layer's policy ([PlaySync]) but stored here so ring compaction can
///   never strand a pending event.
///
/// Every cap is a constant, not a setting. Loads swallow a corrupt file so
/// startup never blocks; a torn last ring line is skipped by readers.
///
/// Storage location is injectable ([storageDirectory]) so the store runs on
/// a plain temp directory under test.

const int kRingCap = 5000;
const int kRingCompactAt = 6000;
const int kTracksCap = 10000;
const int kTracksEvictTo = 9000;
const int kDaysCap = 730;
const int kOutboxCap = 2000;
const Duration kOutboxMaxAge = Duration(days: 30);

/// Consecutive plays of the same track closer than this collapse into one
/// row in a "recently played" listing (a repeat-one loop is one line).
const Duration kCollapseWindow = Duration(hours: 6);

/// The NUL-joined server + path the handler and the tracker key on.
String trackStatKey(String server, String path) => '$server\u0000$path';

/// Per-track counters, the device's mirror of the server's `user_metadata`
/// row: how often, for how long, first and last, plus what is needed to
/// render the track offline.
class TrackStat {
  final String server;
  final String path;
  int events;
  int plays;
  int skips;
  int listenedMs;
  int? firstAt;
  int? lastAt;
  String? title;
  String? artist;
  String? album;
  String? hash;
  String? artFile;
  int? durationMs;

  TrackStat({
    required this.server,
    required this.path,
    this.events = 0,
    this.plays = 0,
    this.skips = 0,
    this.listenedMs = 0,
    this.firstAt,
    this.lastAt,
    this.title,
    this.artist,
    this.album,
    this.hash,
    this.artFile,
    this.durationMs,
  });

  String get key => trackStatKey(server, path);

  Map<String, dynamic> toJson() => {
        'srv': server,
        'p': path,
        'e': events,
        'n': plays,
        'sk': skips,
        'ms': listenedMs,
        if (firstAt != null) 'f': firstAt,
        if (lastAt != null) 'l': lastAt,
        if (title != null) 'ti': title,
        if (artist != null) 'ar': artist,
        if (album != null) 'al': album,
        if (hash != null) 'h': hash,
        if (artFile != null) 'art': artFile,
        if (durationMs != null) 'dur': durationMs,
      };

  static TrackStat? fromJson(Map<dynamic, dynamic> j) {
    final p = j['p'];
    if (p is! String || p.isEmpty) return null;
    int i(dynamic v) => v is int ? v : 0;
    return TrackStat(
      server: j['srv'] is String ? j['srv'] as String : '',
      path: p,
      events: i(j['e']),
      plays: i(j['n']),
      skips: i(j['sk']),
      listenedMs: i(j['ms']),
      firstAt: j['f'] is int ? j['f'] as int : null,
      lastAt: j['l'] is int ? j['l'] as int : null,
      title: j['ti'] is String ? j['ti'] as String : null,
      artist: j['ar'] is String ? j['ar'] as String : null,
      album: j['al'] is String ? j['al'] as String : null,
      hash: j['h'] is String ? j['h'] as String : null,
      artFile: j['art'] is String ? j['art'] as String : null,
      durationMs: j['dur'] is int ? j['dur'] as int : null,
    );
  }
}

/// A day's or a month's totals.
class PeriodStat {
  int events;
  int plays;
  int skips;
  int listenedMs;
  PeriodStat({this.events = 0, this.plays = 0, this.skips = 0, this.listenedMs = 0});

  Map<String, dynamic> toJson() => {'e': events, 'n': plays, 'sk': skips, 'ms': listenedMs};

  static PeriodStat fromJson(Map<dynamic, dynamic> j) {
    int i(dynamic v) => v is int ? v : 0;
    return PeriodStat(events: i(j['e']), plays: i(j['n']), skips: i(j['sk']), listenedMs: i(j['ms']));
  }

  void add(PlayEvent e) {
    events += 1;
    if (e.counted) plays += 1;
    if (e.outcome == PlayOutcome.skipped) skips += 1;
    listenedMs += e.playedMs;
  }

  void addAll(PeriodStat o) {
    events += o.events;
    plays += o.plays;
    skips += o.skips;
    listenedMs += o.listenedMs;
  }
}

/// The contents of `play_stats.json`.
class PlayStatsData {
  static const int schemaVersion = 1;

  int ringCount;
  final Map<String, TrackStat> tracks;
  final Map<String, PeriodStat> days;
  final Map<String, PeriodStat> months;

  PlayStatsData({
    this.ringCount = 0,
    Map<String, TrackStat>? tracks,
    Map<String, PeriodStat>? days,
    Map<String, PeriodStat>? months,
  })  : tracks = tracks ?? {},
        days = days ?? {},
        months = months ?? {};

  bool get isEmpty => tracks.isEmpty && days.isEmpty && months.isEmpty;

  Map<String, dynamic> toJson() => {
        'v': schemaVersion,
        'ring': ringCount,
        'tracks': tracks.values.map((t) => t.toJson()).toList(),
        'days': days.map((k, v) => MapEntry(k, v.toJson())),
        'months': months.map((k, v) => MapEntry(k, v.toJson())),
      };

  static PlayStatsData fromJson(Map<dynamic, dynamic> j) {
    final out = PlayStatsData(ringCount: j['ring'] is int ? j['ring'] as int : 0);
    final tracks = j['tracks'];
    if (tracks is List) {
      for (final t in tracks) {
        if (t is Map) {
          final ts = TrackStat.fromJson(t);
          if (ts != null) out.tracks[ts.key] = ts;
        }
      }
    }
    void periods(dynamic src, Map<String, PeriodStat> dst) {
      if (src is Map) {
        src.forEach((k, v) {
          if (k is String && v is Map) dst[k] = PeriodStat.fromJson(v);
        });
      }
    }
    periods(j['days'], out.days);
    periods(j['months'], out.months);
    return out;
  }
}

/// `YYYY-MM-DD` in the device's own zone — what the user sees as a day.
String dayKeyOf(DateTime t) {
  final l = t.toLocal();
  return '${l.year.toString().padLeft(4, '0')}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
}

String monthKeyOf(DateTime t) {
  final l = t.toLocal();
  return '${l.year.toString().padLeft(4, '0')}-${l.month.toString().padLeft(2, '0')}';
}

/// Pure transitions over [PlayStatsData]; unit-tested with hand-built
/// events, applied by [PlayHistory] at record time.
class PlayStatsFold {
  PlayStatsFold._();

  /// Fold one closed session into the counters and rollups.
  static void fold(PlayStatsData s, PlayEvent e) {
    final t = e.track;
    final key = trackStatKey(t.server, t.path);
    final ts = s.tracks.putIfAbsent(key, () => TrackStat(server: t.server, path: t.path));
    ts.events += 1;
    if (e.counted) ts.plays += 1;
    if (e.outcome == PlayOutcome.skipped) ts.skips += 1;
    ts.listenedMs += e.playedMs;
    final at = e.startedAt.millisecondsSinceEpoch;
    if (ts.firstAt == null || at < ts.firstAt!) ts.firstAt = at;
    if (ts.lastAt == null || at > ts.lastAt!) ts.lastAt = at;
    // The latest snapshot wins: a retag on the server shows up here too.
    ts.title = t.title ?? ts.title;
    ts.artist = t.artist ?? ts.artist;
    ts.album = t.album ?? ts.album;
    ts.hash = t.hash ?? ts.hash;
    ts.artFile = t.artFile ?? ts.artFile;
    ts.durationMs = t.durationMs ?? ts.durationMs;

    s.days.putIfAbsent(dayKeyOf(e.startedAt), PeriodStat.new).add(e);
    s.months.putIfAbsent(monthKeyOf(e.startedAt), PeriodStat.new).add(e);
    if (s.tracks.length > kTracksCap) evictTracks(s);
    if (s.days.length > kDaysCap) rollDays(s);
  }

  /// Above the track cap, drop the least-played, longest-unplayed tracks
  /// down to [kTracksEvictTo]. Their plays survive in the day and month
  /// rollups; only the per-track line is lost.
  static void evictTracks(PlayStatsData s, {int to = kTracksEvictTo}) {
    if (s.tracks.length <= to) return;
    final order = s.tracks.values.toList()
      ..sort((a, b) {
        final byPlays = a.plays.compareTo(b.plays);
        if (byPlays != 0) return byPlays;
        return (a.lastAt ?? 0).compareTo(b.lastAt ?? 0);
      });
    for (final t in order.take(s.tracks.length - to)) {
      s.tracks.remove(t.key);
    }
  }

  /// Past [kDaysCap] days, the oldest days fold into their months (which
  /// already hold them) and are dropped; a month is never dropped.
  static void rollDays(PlayStatsData s, {int keep = kDaysCap}) {
    if (s.days.length <= keep) return;
    final keys = s.days.keys.toList()..sort();
    for (final k in keys.take(s.days.length - keep)) {
      s.days.remove(k);
    }
  }

  /// Remove every trace of [server] (a removed server): its tracks. Days and
  /// months are totals of listening, not of servers, and stay.
  static void purgeServer(PlayStatsData s, String server) {
    s.tracks.removeWhere((_, t) => t.server == server);
  }
}

/// Pure policy over the outbox groups ({target localname → events, oldest
/// first}); [PlayHistory] persists the result.
class OutboxFold {
  OutboxFold._();

  static void enqueue(Map<String, List<PlayEvent>> groups, String target, PlayEvent e) {
    final list = groups.putIfAbsent(target, () => []);
    if (list.any((x) => x.id == e.id)) return;
    list.add(e);
    capOldest(groups);
  }

  static int total(Map<String, List<PlayEvent>> groups) =>
      groups.values.fold(0, (n, l) => n + l.length);

  /// Beyond [kOutboxCap] events in all, the oldest go first, whichever
  /// target they were bound for.
  static void capOldest(Map<String, List<PlayEvent>> groups, {int cap = kOutboxCap}) {
    var over = total(groups) - cap;
    while (over > 0) {
      String? oldestKey;
      DateTime? oldestAt;
      groups.forEach((k, l) {
        if (l.isEmpty) return;
        if (oldestAt == null || l.first.startedAt.isBefore(oldestAt!)) {
          oldestAt = l.first.startedAt;
          oldestKey = k;
        }
      });
      if (oldestKey == null) break;
      groups[oldestKey]!.removeAt(0);
      over--;
    }
    groups.removeWhere((_, l) => l.isEmpty);
  }

  /// Drop what a server would reject as too old anyway.
  static int ageOut(Map<String, List<PlayEvent>> groups, DateTime now, {Duration maxAge = kOutboxMaxAge}) {
    final floor = now.subtract(maxAge);
    var dropped = 0;
    for (final l in groups.values) {
      final before = l.length;
      l.removeWhere((e) => e.startedAt.isBefore(floor));
      dropped += before - l.length;
    }
    groups.removeWhere((_, l) => l.isEmpty);
    return dropped;
  }

  /// The server answered for these ids (accepted, duplicate or rejected):
  /// they are done either way.
  static void drop(Map<String, List<PlayEvent>> groups, String target, Iterable<String> ids) {
    final set = ids.toSet();
    groups[target]?.removeWhere((e) => set.contains(e.id));
    if (groups[target]?.isEmpty ?? false) groups.remove(target);
  }
}

/// The store. Read [PlayHistory.init] once after the server list has loaded.
class PlayHistory {
  PlayHistory._();
  static final PlayHistory _instance = PlayHistory._();
  factory PlayHistory() => _instance;

  /// Where the three files live. Tests point this at a temp directory.
  static Future<Directory> Function() storageDirectory = getApplicationDocumentsDirectory;

  static const Duration _statsDebounce = Duration(seconds: 5);

  final WriteChain _ringChain = WriteChain();
  final WriteChain _statsChain = WriteChain();
  final WriteChain _outboxChain = WriteChain();

  PlayStatsData _stats = PlayStatsData();
  final Map<String, List<PlayEvent>> _outbox = {};
  List<PlayEvent>? _ring; // loaded lazily; newest last
  Timer? _statsTimer;
  bool _loaded = false;
  bool _statsDirty = false;

  /// Off = record nothing (Settings "Keep listening history").
  bool enabled = true;

  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Fires after every recorded event, purge or clear — the screens rebuild.
  Stream<void> get changes => _changes.stream;

  PlayStatsData get stats => _stats;
  Map<String, List<PlayEvent>> get outbox => _outbox;
  int get outboxCount => OutboxFold.total(_outbox);
  bool get isLoaded => _loaded;

  Future<File> _file(String name) async {
    final dir = await storageDirectory();
    return File('${dir.path}/$name');
  }

  Future<File> get _ringFile => _file('play_history.jsonl');
  Future<File> get _statsFile => _file('play_stats.json');
  Future<File> get _outboxFile => _file('play_outbox.json');

  /// Load the aggregates and the outbox (the ring stays on disk until a
  /// screen asks for it). Idempotent.
  Future<void> init() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final f = await _statsFile;
      if (await f.exists()) {
        final v = jsonDecode(await f.readAsString());
        if (v is Map) _stats = PlayStatsData.fromJson(v);
      }
    } catch (e) {
      appLog('[history] stats load failed, starting empty: $e');
      _stats = PlayStatsData();
    }
    try {
      final f = await _outboxFile;
      if (await f.exists()) {
        final v = jsonDecode(await f.readAsString());
        if (v is Map) {
          v.forEach((k, l) {
            if (k is String && l is List) {
              final events = l.whereType<Map>().map(PlayEvent.fromJson).whereType<PlayEvent>().toList();
              if (events.isNotEmpty) _outbox[k] = events;
            }
          });
        }
      }
      final dropped = OutboxFold.ageOut(_outbox, DateTime.now().toUtc());
      if (dropped > 0) {
        appLog('[history] outbox: dropped $dropped play(s) older than ${kOutboxMaxAge.inDays} days');
        _saveOutbox();
      }
    } catch (e) {
      appLog('[history] outbox load failed, starting empty: $e');
      _outbox.clear();
    }
  }

  /// Under test: forget everything in memory (the files are the caller's).
  void resetForTest() {
    _statsTimer?.cancel();
    _stats = PlayStatsData();
    _outbox.clear();
    _ring = null;
    _loaded = false;
    _statsDirty = false;
    enabled = true;
  }

  // ── Recording ──

  /// One closed session: append it to the ring, fold it into the counters,
  /// schedule the stats write. Returns false when history is off.
  Future<bool> record(PlayEvent e) async {
    if (!enabled) return false;
    await init();
    PlayStatsFold.fold(_stats, e);
    _stats.ringCount += 1;
    _ring?.add(e);
    _statsDirty = true;
    _scheduleStatsSave();
    final line = '${e.toJsonLine()}\n';
    await _ringChain.run(() async {
      try {
        final f = await _ringFile;
        await f.writeAsString(line, mode: FileMode.append, flush: true);
      } catch (err) {
        appLog('[history] ring append failed: $err');
      }
    });
    if (_stats.ringCount > kRingCompactAt) await _compact();
    _notify();
    return true;
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  void _scheduleStatsSave() {
    _statsTimer?.cancel();
    _statsTimer = Timer(_statsDebounce, () { flush(); });
  }

  /// Write the aggregates now (lifecycle pause / detach).
  Future<void> flush() async {
    _statsTimer?.cancel();
    if (!_statsDirty) return;
    _statsDirty = false;
    final content = jsonEncode(_stats.toJson());
    await _statsChain.run(() async {
      try {
        final f = await _statsFile;
        final tmp = File('${f.path}.tmp');
        await tmp.writeAsString(content, flush: true);
        await tmp.rename(f.path);
      } catch (e) {
        appLog('[history] stats write failed: $e');
        _statsDirty = true;
      }
    });
  }

  Future<void> _saveOutbox() => _outboxChain.run(() async {
        try {
          final f = await _outboxFile;
          if (_outbox.isEmpty) {
            if (await f.exists()) await f.delete();
            return;
          }
          final tmp = File('${f.path}.tmp');
          await tmp.writeAsString(
              jsonEncode(_outbox.map((k, l) => MapEntry(k, l.map((e) => e.toJson()).toList()))),
              flush: true);
          await tmp.rename(f.path);
        } catch (e) {
          appLog('[history] outbox write failed: $e');
        }
      });

  // ── The ring ──

  /// Every event on the device, oldest first. Read from disk once, then
  /// kept in memory; a torn or foreign line is skipped.
  Future<List<PlayEvent>> events() async {
    await init();
    final cached = _ring;
    if (cached != null) return List.unmodifiable(cached);
    final list = <PlayEvent>[];
    try {
      final f = await _ringFile;
      if (await f.exists()) {
        for (final line in await f.readAsLines()) {
          if (line.trim().isEmpty) continue;
          final e = PlayEvent.fromJsonLine(line);
          if (e != null) list.add(e);
        }
      }
    } catch (e) {
      appLog('[history] ring read failed: $e');
    }
    _ring = list;
    return List.unmodifiable(list);
  }

  /// Rewrite the ring with its newest [kRingCap] lines, off the hot path:
  /// a temp file renamed over the old one, on the ring's own chain.
  Future<void> _compact() async {
    await _ringChain.run(() async {
      try {
        final f = await _ringFile;
        if (!await f.exists()) return;
        final lines = (await f.readAsLines()).where((l) => l.trim().isNotEmpty).toList();
        final keep = lines.length > kRingCap ? lines.sublist(lines.length - kRingCap) : lines;
        final tmp = File('${f.path}.tmp');
        await tmp.writeAsString('${keep.join('\n')}\n', flush: true);
        await tmp.rename(f.path);
        _stats.ringCount = keep.length;
        _statsDirty = true;
        if (_ring != null && _ring!.length > kRingCap) {
          _ring = _ring!.sublist(_ring!.length - kRingCap);
        }
        appLog('[history] ring compacted to ${keep.length} events');
      } catch (e) {
        appLog('[history] ring compaction failed: $e');
      }
    });
    _scheduleStatsSave();
  }

  // ── The outbox ──

  Future<void> enqueue(String target, PlayEvent e) async {
    await init();
    OutboxFold.enqueue(_outbox, target, e);
    await _saveOutbox();
  }

  /// Oldest first, at most [limit], for one target.
  List<PlayEvent> pending(String target, {int limit = 200}) {
    final l = _outbox[target];
    if (l == null) return const [];
    return List.unmodifiable(l.take(limit));
  }

  Future<void> settle(String target, Iterable<String> ids) async {
    OutboxFold.drop(_outbox, target, ids);
    await _saveOutbox();
  }

  Future<void> purgeOutbox({String? target}) async {
    if (target == null) {
      _outbox.clear();
    } else {
      _outbox.remove(target);
    }
    await _saveOutbox();
  }

  // ── Cascades ──

  /// A server was removed: its tracks, its ring lines and the outbox group
  /// addressed to it go. [peers] are the localnames of federated servers
  /// that had it as their parent — their entries go too, since they
  /// could only ever have been reported through it.
  Future<void> purgeServer(String localname, {Iterable<String> peers = const []}) async {
    await init();
    final gone = {localname, ...peers};
    for (final s in gone) {
      PlayStatsFold.purgeServer(_stats, s);
    }
    _outbox.remove(localname);
    for (final l in _outbox.values) {
      l.removeWhere((e) => gone.contains(e.track.server));
    }
    _outbox.removeWhere((_, l) => l.isEmpty);
    await _saveOutbox();
    final all = await events();
    final keep = all.where((e) => !gone.contains(e.track.server)).toList();
    if (keep.length != all.length) {
      await _rewriteRing(keep);
    }
    _statsDirty = true;
    await flush();
    _notify();
  }

  Future<void> _rewriteRing(List<PlayEvent> keep) => _ringChain.run(() async {
        try {
          final f = await _ringFile;
          if (keep.isEmpty) {
            if (await f.exists()) await f.delete();
          } else {
            final tmp = File('${f.path}.tmp');
            await tmp.writeAsString('${keep.map((e) => e.toJsonLine()).join('\n')}\n', flush: true);
            await tmp.rename(f.path);
          }
          _ring = keep;
          _stats.ringCount = keep.length;
        } catch (e) {
          appLog('[history] ring rewrite failed: $e');
        }
      });

  /// "Clear listening history": every file and everything in memory.
  Future<void> clear() async {
    _statsTimer?.cancel();
    _statsDirty = false;
    _stats = PlayStatsData();
    _outbox.clear();
    _ring = [];
    for (final chain in [_ringChain, _statsChain, _outboxChain]) {
      await chain.run(() async {});
    }
    for (final name in ['play_history.jsonl', 'play_stats.json', 'play_outbox.json']) {
      try {
        final f = await _file(name);
        if (await f.exists()) await f.delete();
        final tmp = File('${f.path}.tmp');
        if (await tmp.exists()) await tmp.delete();
      } catch (e) {
        appLog('[history] clear failed for $name: $e');
      }
    }
    _notify();
  }

  /// Approximate bytes on disk, for the Settings copy ("about 4 MB").
  Future<int> sizeBytes() async {
    var total = 0;
    for (final name in ['play_history.jsonl', 'play_stats.json', 'play_outbox.json']) {
      try {
        final f = await _file(name);
        if (await f.exists()) total += await f.length();
      } catch (_) {
        // unreadable: counts as nothing
      }
    }
    return total;
  }

  // ── Reads used by Song Info and the lists ──

  TrackStat? statFor(String server, String path) => _stats.tracks[trackStatKey(server, path)];
}
