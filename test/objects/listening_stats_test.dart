import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/listening_stats.dart';
import 'package:mstream_music/objects/play_event.dart';

PlayEvent ev(String id, DateTime at,
    {String server = 'home',
    String path = '/music/a.mp3',
    int playedMs = 200000,
    int? durationMs = 240000,
    PlayOutcome outcome = PlayOutcome.completed,
    String? title,
    String? artist,
    String? album,
    int? peerId}) {
  return PlayEvent(
    id: id,
    startedAt: at.toUtc(),
    endedAt: at.toUtc().add(Duration(milliseconds: playedMs)),
    track: TrackFacts(server: server, peerId: peerId, path: path, title: title ?? path.split('/').last, artist: artist, album: album, durationMs: durationMs),
    playedMs: playedMs,
    outcome: outcome,
    source: PlaySource.manual,
    counted: countsAsPlay(playedMs: playedMs, durationMs: durationMs),
  );
}

// A Wednesday evening.
final now = DateTime(2026, 9, 9, 21, 30);

void main() {
  group('StatsPeriod.range', () {
    test('week starts Monday, month/quarter/year on the first, all is unbounded', () {
      final w = StatsPeriod.week.range(now);
      expect(w.from, DateTime(2026, 9, 7));
      expect(w.to, DateTime(2026, 9, 14));
      final m = StatsPeriod.month.range(now);
      expect([m.from, m.to], [DateTime(2026, 9), DateTime(2026, 10)]);
      final q = StatsPeriod.quarter.range(now);
      expect([q.from, q.to], [DateTime(2026, 7), DateTime(2026, 10)]);
      final y = StatsPeriod.year.range(now);
      expect([y.from, y.to], [DateTime(2026), DateTime(2027)]);
      final a = StatsPeriod.all.range(now);
      expect([a.from, a.to], [null, null]);
      expect(StatsPeriod.quarter.wire, 'quarter');
    });
  });

  group('DeviceStats.summary', () {
    final events = [
      ev('1', now.subtract(const Duration(days: 2, hours: 1)), artist: 'A'), // Mon 20:30
      ev('2', now.subtract(const Duration(days: 2, minutes: 50)), path: '/b.mp3', artist: 'B'), // Mon 20:40, same sitting
      ev('3', now.subtract(const Duration(days: 1)), path: '/c.mp3', artist: 'A', playedMs: 9000, outcome: PlayOutcome.skipped), // Tue: not counted
      ev('4', now.subtract(const Duration(hours: 1)), path: '/b.mp3', artist: 'B'), // Wed 20:30
      ev('5', now.subtract(const Duration(minutes: 40)), path: '/d.mp3', artist: 'C', peerId: 7), // Wed 20:50, same sitting
      ev('old', now.subtract(const Duration(days: 40)), path: '/z.mp3'),
    ];

    test('counts, uniques, sessions, streak, top day, peaks within the period', () {
      final r = StatsPeriod.week.range(now);
      final s = DeviceStats.summary(events, from: r.from, to: r.to, now: now);
      expect([s.events, s.plays, s.skips, s.listenedMs], [5, 4, 1, 809000]);
      expect(s.uniqueTracks, 4);
      expect(s.uniqueArtists, 3);
      expect(s.sessions, 3, reason: 'Mon evening, Tue, Wed evening: gaps over 30 min start a sitting');
      expect(s.peerPlays, 1);
      expect(s.topDayKey, '2026-09-09');
      expect(s.topDayPlays, 2);
      expect(s.peakHour, 20);
      expect(s.peakWeekday, 1, reason: 'Monday, counted like the server (0 = Sunday)');
      expect(s.streakCurrent, 1, reason: 'Tuesday had no counted play, so today alone is the current run');
      expect(s.streakLongest, 1);
      expect(s.skipRate, closeTo(0.2, 1e-9));
    });

    test('an empty period is empty; all-time includes the old play', () {
      expect(DeviceStats.summary(events, from: DateTime(2020), to: DateTime(2021), now: now).isEmpty, true);
      expect(DeviceStats.summary(events, now: now).events, 6);
    });

    test('streaks: consecutive days, current runs up to today or yesterday', () {
      expect(DeviceStats.streaks(['2026-09-07', '2026-09-08', '2026-09-09'], now), (current: 3, longest: 3));
      expect(DeviceStats.streaks(['2026-09-01', '2026-09-02', '2026-09-08'], now), (current: 1, longest: 2));
      expect(DeviceStats.streaks(['2026-09-01', '2026-09-02'], now), (current: 0, longest: 2));
      expect(DeviceStats.streaks(const [], now), (current: 0, longest: 0));
    });
  });

  group('DeviceStats.top and history', () {
    final events = [
      ev('1', now.subtract(const Duration(hours: 5)), path: '/a.mp3', title: 'Alpha', artist: 'Ann', album: 'One'),
      ev('2', now.subtract(const Duration(hours: 4)), path: '/a.mp3', title: 'Alpha', artist: 'Ann', album: 'One'),
      ev('3', now.subtract(const Duration(hours: 3)), path: '/b.mp3', title: 'Beta', artist: 'Bob', album: 'Two', playedMs: 900000, durationMs: 900000),
      ev('4', now.subtract(const Duration(hours: 2)), path: '/c.mp3', title: 'Gamma', artist: 'Ann', album: 'Three', playedMs: 5000, outcome: PlayOutcome.skipped),
      ev('5', now.subtract(const Duration(hours: 1)), path: '/p.mp3', title: 'Peer Song', artist: 'Pat', album: 'Four', server: 'bobs', peerId: 3),
    ];

    test('top tracks by plays and by time, artists and albums grouped, shares sum to one', () {
      final byPlays = DeviceStats.top(events, entity: 'tracks');
      expect(byPlays.map((t) => [t.rank, t.title, t.plays]).toList(), [
        [1, 'Alpha', 2], [2, 'Peer Song', 1], [3, 'Beta', 1]
      ]);
      expect(byPlays.first.share, closeTo(0.5, 1e-9));
      expect(byPlays[1].fromPeer, true);
      expect(byPlays[1].peerName, null);
      final named = DeviceStats.top(events, entity: 'tracks', peerName: (id) => 'Bob #$id');
      expect(named[1].peerName, 'Bob #3');
      final byTime = DeviceStats.top(events, entity: 'tracks', metric: 'time');
      expect(byTime.first.title, 'Beta');
      final artists = DeviceStats.top(events, entity: 'artists');
      expect(artists.map((t) => [t.title, t.plays, t.tracks]).toList(), [
        ['Ann', 2, 1], ['Pat', 1, 1], ['Bob', 1, 1]
      ]);
      final albums = DeviceStats.top(events, entity: 'albums', limit: 2);
      expect(albums.map((t) => [t.title, t.subtitle]).toList(), [
        ['One', 'Ann'], ['Four', 'Pat']
      ]);
    });

    test('history is newest first and collapses a repeat-one run', () {
      final h = DeviceStats.history(events, limit: 10);
      expect(h.map((i) => i.id).toList(), ['5', '4', '3', '2', '1']);
      expect(h.first.fromPeer, true);
      expect(h[1].counted, false);
      final c = HistoryItem.collapse(h);
      expect(c.map((i) => [i.id, i.repeats]).toList(), [
        ['5', 1], ['4', 1], ['3', 1], ['2', 2]
      ]);
      final farApart = HistoryItem.collapse(h, window: const Duration(minutes: 30));
      expect(farApart.length, 5);
    });

    test('hour-of-day buckets counted plays only', () {
      final buckets = DeviceStats.hourOfDay(events);
      expect(buckets.reduce((a, b) => a + b), 4, reason: 'the skip is not a play');
      expect(buckets[now.subtract(const Duration(hours: 5)).hour], 1);
      expect(buckets[now.subtract(const Duration(hours: 2)).hour], 0, reason: 'the skipped hour is empty');
    });
  });

  group('server parsers', () {
    test('summary', () {
      final s = ListeningSummary.fromServer({
        'period': {'label': 'September 2026'},
        'events': 12, 'plays': 10, 'skips': 2, 'listenedMs': 3600000, 'uniqueTracks': 7, 'uniqueArtists': 4,
        'sessions': {'count': 3, 'avgMs': 1200000}, 'streakDays': {'current': 2, 'longest': 5},
        'topDay': {'date': '2026-09-03', 'plays': 4, 'listenedMs': 900000}, 'peakHour': 20, 'peakWeekday': 3,
        'origins': {'local': {'plays': 9, 'listenedMs': 1}, 'peers': {'plays': 1, 'listenedMs': 2}},
      });
      expect([s.events, s.plays, s.skips, s.listenedMs, s.uniqueTracks, s.uniqueArtists], [12, 10, 2, 3600000, 7, 4]);
      expect([s.sessions, s.sessionAvgMs, s.streakCurrent, s.streakLongest], [3, 1200000, 2, 5]);
      expect([s.topDayKey, s.topDayPlays, s.peakHour, s.peakWeekday, s.peerPlays], ['2026-09-03', 4, 20, 3, 1]);
      expect(ListeningSummary.fromServer({}).isEmpty, true);
    });

    test('top items: tracks carry the metadata object, entities carry a name', () {
      final tracks = TopItem.listFromServer([
        {'rank': 1, 'plays': 4, 'listenedMs': 1000, 'share': 0.4, 'origin': 'local',
          'track': {'filepath': 'music/x.mp3', 'metadata': {'title': 'X', 'artist': 'A', 'hash': 'fh', 'audio-hash': 'ah', 'album-art': 'art.jpg'}}},
        {'rank': 2, 'plays': 1, 'listenedMs': 10, 'share': 0.1, 'origin': 'peer', 'peerName': 'Bob',
          'track': {'filepath': 'music/peer.flac', 'metadata': {'title': 'P'}}},
        'garbage',
      ], 'tracks');
      expect(tracks.length, 2);
      expect([tracks[0].title, tracks[0].subtitle, tracks[0].hash, tracks[0].artFile, tracks[0].path], ['X', 'A', 'ah', 'art.jpg', 'music/x.mp3']);
      expect([tracks[1].fromPeer, tracks[1].peerName], [true, 'Bob']);
      final albums = TopItem.listFromServer([
        {'rank': 1, 'plays': 3, 'listenedMs': 5, 'share': 1, 'name': 'One', 'artist': 'Ann', 'tracks': 2}
      ], 'albums');
      expect([albums.single.title, albums.single.subtitle, albums.single.tracks], ['One', 'Ann', 2]);
      expect(TopItem.listFromServer(null, 'artists'), isEmpty);
    });

    test('history items', () {
      final items = HistoryItem.listFromServer([
        {'id': 'e1', 'startedAt': '2026-09-03T11:00:00.000Z', 'outcome': 'skipped', 'counted': true, 'playedMs': 240000, 'durationMs': 300000,
          'client': 'mstream-webapp/6.27.0', 'origin': 'peer', 'peerName': 'Bob',
          'track': {'filepath': 'music/peer.flac', 'metadata': {'title': 'Peer Song', 'artist': 'Peer Artist', 'album': 'Alb', 'hash': 'pfh', 'audio-hash': 'pah'}}},
        {'id': 'e2', 'startedAt': 'not a date', 'outcome': 'completed'},
        {'startedAt': '2026-09-03T11:00:00.000Z'},
      ]);
      expect(items.length, 1);
      final i = items.single;
      expect([i.id, i.title, i.artist, i.outcome, i.counted, i.playedMs, i.durationMs, i.client, i.peerName, i.fromPeer, i.hash],
          ['e1', 'Peer Song', 'Peer Artist', PlayOutcome.skipped, true, 240000, 300000, 'mstream-webapp/6.27.0', 'Bob', true, 'pah']);
      expect(i.startedAt.toIso8601String(), '2026-09-03T11:00:00.000Z');
    });
  });
}
