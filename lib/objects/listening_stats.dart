import 'play_event.dart';

/// The shapes the Listening page renders, built two ways: from the device's
/// own events ([DeviceStats]) and from a server's Stats API v2 answers
/// ([ListeningSummary.fromServer] etc.). One scope at a time, the same
/// layout for both, so flipping between "This phone" and a server is a
/// fair comparison (the 2026-09-07 design).

/// A period preset, resolved on the device's own calendar.
enum StatsPeriod { week, month, quarter, year, all }

extension StatsPeriodApi on StatsPeriod {
  /// The server's `period=` value.
  String get wire => name;

  /// `[from, to)` in local time; null bounds for all-time.
  ({DateTime? from, DateTime? to}) range(DateTime now) {
    final l = now.toLocal();
    switch (this) {
      case StatsPeriod.week:
        final monday = DateTime(l.year, l.month, l.day).subtract(Duration(days: l.weekday - 1));
        return (from: monday, to: monday.add(const Duration(days: 7)));
      case StatsPeriod.month:
        return (from: DateTime(l.year, l.month), to: DateTime(l.year, l.month + 1));
      case StatsPeriod.quarter:
        final q0 = ((l.month - 1) ~/ 3) * 3 + 1;
        return (from: DateTime(l.year, q0), to: DateTime(l.year, q0 + 3));
      case StatsPeriod.year:
        return (from: DateTime(l.year), to: DateTime(l.year + 1));
      case StatsPeriod.all:
        return (from: null, to: null);
    }
  }
}

bool _inRange(DateTime t, DateTime? from, DateTime? to) {
  final l = t.toLocal();
  if (from != null && l.isBefore(from)) return false;
  if (to != null && !l.isBefore(to)) return false;
  return true;
}

int _int(dynamic v) => v is int ? v : (v is num ? v.round() : 0);
int? _intOrNull(dynamic v) => v is int ? v : (v is num ? v.round() : null);
double? _double(dynamic v) => v is num ? v.toDouble() : null;
String? _str(dynamic v) => v is String && v.isNotEmpty ? v : null;

/// The tiles and notes at the top of the page.
class ListeningSummary {
  final int events;
  final int plays;
  final int skips;
  final int listenedMs;
  final int uniqueTracks;
  final int uniqueArtists;
  final int sessions;
  final int? sessionAvgMs;
  final int streakCurrent;
  final int streakLongest;

  /// `YYYY-MM-DD`, plays, listened ms of the busiest day; null when empty.
  final String? topDayKey;
  final int topDayPlays;
  final int? peakHour;
  final int? peakWeekday; // 0 = Sunday, as the server counts
  final int peerPlays;

  const ListeningSummary({
    this.events = 0,
    this.plays = 0,
    this.skips = 0,
    this.listenedMs = 0,
    this.uniqueTracks = 0,
    this.uniqueArtists = 0,
    this.sessions = 0,
    this.sessionAvgMs,
    this.streakCurrent = 0,
    this.streakLongest = 0,
    this.topDayKey,
    this.topDayPlays = 0,
    this.peakHour,
    this.peakWeekday,
    this.peerPlays = 0,
  });

  bool get isEmpty => events == 0;
  double? get skipRate => events == 0 ? null : skips / events;

  static ListeningSummary fromServer(Map<dynamic, dynamic> j) {
    final sessions = j['sessions'];
    final streak = j['streakDays'];
    final topDay = j['topDay'];
    final origins = j['origins'];
    return ListeningSummary(
      events: _int(j['events']),
      plays: _int(j['plays']),
      skips: _int(j['skips']),
      listenedMs: _int(j['listenedMs']),
      uniqueTracks: _int(j['uniqueTracks']),
      uniqueArtists: _int(j['uniqueArtists']),
      sessions: sessions is Map ? _int(sessions['count']) : 0,
      sessionAvgMs: sessions is Map ? _intOrNull(sessions['avgMs']) : null,
      streakCurrent: streak is Map ? _int(streak['current']) : 0,
      streakLongest: streak is Map ? _int(streak['longest']) : 0,
      topDayKey: topDay is Map ? _str(topDay['date']) : null,
      topDayPlays: topDay is Map ? _int(topDay['plays']) : 0,
      peakHour: _intOrNull(j['peakHour']),
      peakWeekday: _intOrNull(j['peakWeekday']),
      peerPlays: origins is Map && origins['peers'] is Map ? _int(origins['peers']['plays']) : 0,
    );
  }
}

/// One row of a top list.
class TopItem {
  final int rank;
  final String title;
  final String? subtitle;
  final int plays;
  final int listenedMs;
  final double share;
  final String? server;
  final String? path;
  final String? hash;
  final String? artFile;
  final String? peerName;
  final bool fromPeer;
  final int tracks;

  const TopItem({
    required this.rank,
    required this.title,
    this.subtitle,
    required this.plays,
    required this.listenedMs,
    required this.share,
    this.server,
    this.path,
    this.hash,
    this.artFile,
    this.peerName,
    this.fromPeer = false,
    this.tracks = 0,
  });

  static List<TopItem> listFromServer(dynamic items, String entity) {
    if (items is! List) return const [];
    final out = <TopItem>[];
    for (final it in items) {
      if (it is! Map) continue;
      final rank = _int(it['rank']);
      final plays = _int(it['plays']);
      final ms = _int(it['listenedMs']);
      final share = _double(it['share']) ?? 0;
      final fromPeer = it['origin'] == 'peer';
      final peerName = _str(it['peerName']);
      if (entity == 'tracks') {
        final track = it['track'];
        final meta = track is Map && track['metadata'] is Map ? track['metadata'] as Map : const {};
        final filepath = track is Map ? _str(track['filepath']) : null;
        out.add(TopItem(
          rank: rank,
          title: _str(meta['title']) ?? (filepath?.split('/').last ?? 'Unknown track'),
          subtitle: _str(meta['artist']),
          plays: plays,
          listenedMs: ms,
          share: share,
          path: filepath,
          hash: _str(meta['audio-hash']) ?? _str(meta['hash']),
          artFile: _str(meta['album-art']),
          peerName: peerName,
          fromPeer: fromPeer,
        ));
      } else {
        final name = _str(it['name']) ?? _str(it[entity == 'artists' ? 'artist' : entity == 'albums' ? 'album' : 'genre']) ?? 'Unknown';
        out.add(TopItem(
          rank: rank,
          title: name,
          subtitle: entity == 'albums' ? _str(it['artist']) : null,
          plays: plays,
          listenedMs: ms,
          share: share,
          tracks: _int(it['tracks']),
          peerName: peerName,
          fromPeer: fromPeer,
        ));
      }
    }
    return out;
  }
}

/// One row of the history list.
class HistoryItem {
  final String id;
  final DateTime startedAt;
  final String title;
  final String? artist;
  final String? album;
  final String? server;
  final String? path;
  final String? hash;
  final String? artFile;
  final PlayOutcome outcome;
  final bool counted;
  final int playedMs;
  final int? durationMs;
  final String? client;
  final String? peerName;
  final bool fromPeer;
  final bool isLocalFile;

  /// How many consecutive plays this row stands for (see [collapse]).
  final int repeats;

  const HistoryItem({
    required this.id,
    required this.startedAt,
    required this.title,
    this.artist,
    this.album,
    this.server,
    this.path,
    this.hash,
    this.artFile,
    required this.outcome,
    required this.counted,
    required this.playedMs,
    this.durationMs,
    this.client,
    this.peerName,
    this.fromPeer = false,
    this.isLocalFile = false,
    this.repeats = 1,
  });

  HistoryItem withRepeats(int n) => HistoryItem(
        id: id, startedAt: startedAt, title: title, artist: artist, album: album, server: server, path: path,
        hash: hash, artFile: artFile, outcome: outcome, counted: counted, playedMs: playedMs, durationMs: durationMs,
        client: client, peerName: peerName, fromPeer: fromPeer, isLocalFile: isLocalFile, repeats: n,
      );

  String get sameTrackKey => '${server ?? ''}\u0000${path ?? id}';

  static HistoryItem fromEvent(PlayEvent e, {String? peerName}) {
    final t = e.track;
    return HistoryItem(
      id: e.id,
      startedAt: e.startedAt,
      title: t.title ?? t.path.split('/').last,
      artist: t.artist,
      album: t.album,
      server: t.server.isEmpty ? null : t.server,
      path: t.path,
      hash: t.hash,
      artFile: t.artFile,
      outcome: e.outcome,
      counted: e.counted,
      playedMs: e.playedMs,
      durationMs: t.durationMs,
      peerName: peerName,
      fromPeer: t.peerId != null,
      isLocalFile: t.isLocalFile,
    );
  }

  static List<HistoryItem> listFromServer(dynamic items) {
    if (items is! List) return const [];
    final out = <HistoryItem>[];
    for (final it in items) {
      if (it is! Map) continue;
      final id = _str(it['id']);
      final started = _str(it['startedAt']);
      if (id == null || started == null) continue;
      final at = DateTime.tryParse(started);
      if (at == null) continue;
      final track = it['track'];
      final meta = track is Map && track['metadata'] is Map ? track['metadata'] as Map : const {};
      final filepath = track is Map ? _str(track['filepath']) : null;
      final outcome = PlayOutcome.values.cast<PlayOutcome?>().firstWhere((o) => o!.name == it['outcome'], orElse: () => null) ??
          PlayOutcome.stopped;
      out.add(HistoryItem(
        id: id,
        startedAt: at.toUtc(),
        title: _str(meta['title']) ?? (filepath?.split('/').last ?? 'Unknown track'),
        artist: _str(meta['artist']),
        album: _str(meta['album']),
        path: filepath,
        hash: _str(meta['audio-hash']) ?? _str(meta['hash']),
        artFile: _str(meta['album-art']),
        outcome: outcome,
        counted: it['counted'] == true,
        playedMs: _int(it['playedMs']),
        durationMs: _intOrNull(it['durationMs']),
        client: _str(it['client']),
        peerName: _str(it['peerName']),
        fromPeer: it['origin'] == 'peer',
      ));
    }
    return out;
  }

  /// Newest-first rows; consecutive plays of the same track within
  /// [window] fold into the newest one with a repeat count.
  static List<HistoryItem> collapse(List<HistoryItem> newestFirst, {Duration window = const Duration(hours: 6)}) {
    final out = <HistoryItem>[];
    for (final it in newestFirst) {
      if (out.isNotEmpty) {
        final last = out.last;
        if (last.sameTrackKey == it.sameTrackKey && last.startedAt.difference(it.startedAt).abs() <= window) {
          out[out.length - 1] = last.withRepeats(last.repeats + 1);
          continue;
        }
      }
      out.add(it);
    }
    return out;
  }
}

/// The device scope: everything computed from the ring in memory.
class DeviceStats {
  DeviceStats._();

  static List<PlayEvent> inPeriod(List<PlayEvent> events, DateTime? from, DateTime? to) =>
      events.where((e) => _inRange(e.startedAt, from, to)).toList();

  static String _dayKey(DateTime t) {
    final l = t.toLocal();
    return '${l.year.toString().padLeft(4, '0')}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
  }

  /// Gaps over 30 minutes between events start a new sitting, as the
  /// server derives them.
  static const Duration sessionGap = Duration(minutes: 30);

  static ListeningSummary summary(List<PlayEvent> all, {DateTime? from, DateTime? to, DateTime? now}) {
    final events = inPeriod(all, from, to)..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    if (events.isEmpty) return const ListeningSummary();
    var plays = 0, skips = 0, listened = 0, peerPlays = 0;
    final tracks = <String>{};
    final artists = <String>{};
    final days = <String, int>{};
    final hours = List<int>.filled(24, 0);
    final weekdays = List<int>.filled(7, 0);
    var sessions = 0;
    var sessionMs = 0;
    DateTime? sessionStart;
    DateTime? lastEnd;
    for (final e in events) {
      if (e.counted) plays++;
      if (e.outcome == PlayOutcome.skipped) skips++;
      listened += e.playedMs;
      if (e.track.peerId != null && e.counted) peerPlays++;
      tracks.add('${e.track.server}\u0000${e.track.path}');
      if (e.track.artist != null) artists.add(e.track.artist!.toLowerCase());
      if (e.counted) {
        days.update(_dayKey(e.startedAt), (n) => n + 1, ifAbsent: () => 1);
        final l = e.startedAt.toLocal();
        hours[l.hour]++;
        weekdays[l.weekday % 7]++;
      }
      if (lastEnd == null || e.startedAt.difference(lastEnd).compareTo(sessionGap) > 0) {
        if (sessionStart != null && lastEnd != null) sessionMs += lastEnd.difference(sessionStart).inMilliseconds;
        sessions++;
        sessionStart = e.startedAt;
      }
      final end = e.endedAt.isAfter(e.startedAt) ? e.endedAt : e.startedAt.add(Duration(milliseconds: e.playedMs));
      if (lastEnd == null || end.isAfter(lastEnd)) lastEnd = end;
    }
    if (sessionStart != null && lastEnd != null) sessionMs += lastEnd.difference(sessionStart).inMilliseconds;
    String? topDay;
    var topPlays = 0;
    days.forEach((k, n) {
      if (n > topPlays || (n == topPlays && topDay != null && k.compareTo(topDay!) > 0)) {
        topDay = k;
        topPlays = n;
      }
    });
    int? peakHour;
    if (plays > 0) {
      var best = -1;
      for (var h = 0; h < 24; h++) {
        if (hours[h] > best) {
          best = hours[h];
          peakHour = h;
        }
      }
    }
    int? peakWeekday;
    if (plays > 0) {
      var best = -1;
      for (var d = 0; d < 7; d++) {
        if (weekdays[d] > best) {
          best = weekdays[d];
          peakWeekday = d;
        }
      }
    }
    final streak = streaks(days.keys, now ?? DateTime.now());
    return ListeningSummary(
      events: events.length,
      plays: plays,
      skips: skips,
      listenedMs: listened,
      uniqueTracks: tracks.length,
      uniqueArtists: artists.length,
      sessions: sessions,
      sessionAvgMs: sessions == 0 ? null : sessionMs ~/ sessions,
      streakCurrent: streak.current,
      streakLongest: streak.longest,
      topDayKey: topDay,
      topDayPlays: topPlays,
      peakHour: peakHour,
      peakWeekday: peakWeekday,
      peerPlays: peerPlays,
    );
  }

  /// Consecutive local days with a counted play; `current` runs up to
  /// today or yesterday.
  static ({int current, int longest}) streaks(Iterable<String> dayKeys, DateTime now) {
    final keys = dayKeys.toSet().toList()..sort();
    if (keys.isEmpty) return (current: 0, longest: 0);
    DateTime parse(String k) {
      final p = k.split('-').map(int.parse).toList();
      return DateTime(p[0], p[1], p[2]);
    }
    var longest = 1, run = 1;
    for (var i = 1; i < keys.length; i++) {
      final gap = parse(keys[i]).difference(parse(keys[i - 1])).inDays;
      run = gap == 1 ? run + 1 : 1;
      if (run > longest) longest = run;
    }
    final today = DateTime(now.toLocal().year, now.toLocal().month, now.toLocal().day);
    final last = parse(keys.last);
    final tail = today.difference(last).inDays;
    return (current: tail <= 1 ? run : 0, longest: longest);
  }

  /// Top tracks / artists / albums by plays or by time.
  static List<TopItem> top(List<PlayEvent> all, {required String entity, String metric = 'plays', DateTime? from, DateTime? to, int limit = 10, String Function(int peerId)? peerName}) {
    final events = inPeriod(all, from, to).where((e) => e.counted);
    final groups = <String, _Agg>{};
    for (final e in events) {
      final t = e.track;
      final String key;
      switch (entity) {
        case 'artists':
          if (t.artist == null || t.artist!.isEmpty) continue;
          key = t.artist!.toLowerCase();
          break;
        case 'albums':
          if (t.album == null || t.album!.isEmpty) continue;
          key = '${t.album!.toLowerCase()}\u0000${(t.artist ?? '').toLowerCase()}';
          break;
        default:
          key = '${t.server}\u0000${t.path}';
      }
      final g = groups.putIfAbsent(key, () => _Agg(e));
      g.plays++;
      g.listenedMs += e.playedMs;
      g.tracks.add('${t.server}\u0000${t.path}');
      if (e.startedAt.isAfter(g.latest.startedAt)) g.latest = e;
    }
    final total = metric == 'time' ? groups.values.fold<int>(0, (n, g) => n + g.listenedMs) : groups.values.fold<int>(0, (n, g) => n + g.plays);
    final list = groups.values.toList()
      ..sort((a, b) {
        final c = metric == 'time' ? b.listenedMs.compareTo(a.listenedMs) : b.plays.compareTo(a.plays);
        if (c != 0) return c;
        return b.latest.startedAt.compareTo(a.latest.startedAt);
      });
    final out = <TopItem>[];
    var rank = 0;
    for (final g in list.take(limit)) {
      rank++;
      final t = g.latest.track;
      final value = metric == 'time' ? g.listenedMs : g.plays;
      final share = total == 0 ? 0.0 : value / total;
      switch (entity) {
        case 'artists':
          out.add(TopItem(rank: rank, title: t.artist!, plays: g.plays, listenedMs: g.listenedMs, share: share, tracks: g.tracks.length));
          break;
        case 'albums':
          out.add(TopItem(rank: rank, title: t.album!, subtitle: t.artist, plays: g.plays, listenedMs: g.listenedMs, share: share, tracks: g.tracks.length, artFile: t.artFile));
          break;
        default:
          out.add(TopItem(
            rank: rank,
            title: t.title ?? t.path.split('/').last,
            subtitle: t.artist,
            plays: g.plays,
            listenedMs: g.listenedMs,
            share: share,
            server: t.server.isEmpty ? null : t.server,
            path: t.path,
            hash: t.hash,
            artFile: t.artFile,
            fromPeer: t.peerId != null,
            peerName: t.peerId != null && peerName != null ? peerName(t.peerId!) : null,
          ));
      }
    }
    return out;
  }

  /// Newest first.
  static List<HistoryItem> history(List<PlayEvent> all, {DateTime? from, DateTime? to, int limit = 50, String Function(int peerId)? peerName}) {
    final events = inPeriod(all, from, to)..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return events.take(limit).map((e) => HistoryItem.fromEvent(e, peerName: e.track.peerId != null && peerName != null ? peerName(e.track.peerId!) : null)).toList();
  }

  /// Counted plays per local hour of day, 24 buckets.
  static List<int> hourOfDay(List<PlayEvent> all, {DateTime? from, DateTime? to}) {
    final out = List<int>.filled(24, 0);
    for (final e in inPeriod(all, from, to)) {
      if (e.counted) out[e.startedAt.toLocal().hour]++;
    }
    return out;
  }
}

class _Agg {
  PlayEvent latest;
  int plays = 0;
  int listenedMs = 0;
  final Set<String> tracks = {};
  _Agg(this.latest);
}
