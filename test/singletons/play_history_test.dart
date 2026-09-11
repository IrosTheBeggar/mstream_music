import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/play_event.dart';
import 'package:mstream_music/singletons/play_history.dart';

PlayEvent ev(String id, DateTime at,
    {String server = 'home',
    String path = '/music/a.mp3',
    int playedMs = 200000,
    int? durationMs = 240000,
    PlayOutcome outcome = PlayOutcome.completed,
    bool? counted,
    String? title,
    String? artist,
    String? album,
    int? peerId,
    String? hash}) {
  return PlayEvent(
    id: id,
    startedAt: at.toUtc(),
    endedAt: at.toUtc().add(Duration(milliseconds: playedMs)),
    track: TrackFacts(
        server: server,
        peerId: peerId,
        path: path,
        hash: hash,
        title: title ?? path.split('/').last,
        artist: artist,
        album: album,
        durationMs: durationMs),
    playedMs: playedMs,
    outcome: outcome,
    source: PlaySource.manual,
    counted: counted ?? countsAsPlay(playedMs: playedMs, durationMs: durationMs),
  );
}

final t0 = DateTime(2026, 9, 10, 20, 0);

void main() {
  group('PlayStatsFold', () {
    test('fold: counters, first/last, snapshot strings, day and month rollups', () {
      final s = PlayStatsData();
      PlayStatsFold.fold(s, ev('1', t0, artist: 'A', album: 'X', hash: 'h1'));
      PlayStatsFold.fold(s, ev('2', t0.add(const Duration(minutes: 5)), playedMs: 10000, outcome: PlayOutcome.skipped, artist: 'A2'));
      PlayStatsFold.fold(s, ev('3', t0.subtract(const Duration(days: 40)), title: 'Old Title'));
      final ts = s.tracks[trackStatKey('home', '/music/a.mp3')]!;
      expect([ts.events, ts.plays, ts.skips, ts.listenedMs], [3, 2, 1, 410000]);
      expect(ts.firstAt, t0.subtract(const Duration(days: 40)).toUtc().millisecondsSinceEpoch);
      expect(ts.lastAt, t0.add(const Duration(minutes: 5)).toUtc().millisecondsSinceEpoch);
      expect(ts.artist, 'A2', reason: 'the latest snapshot wins');
      expect(ts.hash, 'h1', reason: 'a missing field keeps the earlier value');
      expect(s.days[dayKeyOf(t0)]!.toJson(), {'e': 2, 'n': 1, 'sk': 1, 'ms': 210000});
      expect(s.months.length, 2);
      expect(s.ringCount, 0, reason: 'the store, not the fold, counts ring lines');
    });

    test('stats JSON round trip', () {
      final s = PlayStatsData(ringCount: 7);
      PlayStatsFold.fold(s, ev('1', t0, artist: 'A', album: 'X', hash: 'h1'));
      final back = PlayStatsData.fromJson(jsonDecode(jsonEncode(s.toJson())));
      expect(back.ringCount, 7);
      expect(back.tracks.keys, s.tracks.keys);
      expect(back.tracks.values.first.toJson(), s.tracks.values.first.toJson());
      expect(back.days[dayKeyOf(t0)]!.plays, 1);
      expect(PlayStatsData.fromJson({'v': 99, 'tracks': 'garbage', 'days': 5}).isEmpty, true);
    });

    test('eviction drops the least played, longest unplayed first', () {
      final s = PlayStatsData();
      for (var i = 0; i < 12; i++) {
        final plays = i % 3; // 0,1,2 plays
        for (var p = 0; p < plays; p++) {
          PlayStatsFold.fold(s, ev('$i-$p', t0.add(Duration(minutes: i)), path: '/t$i.mp3'));
        }
        if (plays == 0) PlayStatsFold.fold(s, ev('$i-x', t0.add(Duration(minutes: i)), path: '/t$i.mp3', playedMs: 5000, durationMs: 300000));
      }
      expect(s.tracks.length, 12);
      PlayStatsFold.evictTracks(s, to: 8);
      expect(s.tracks.length, 8);
      final gone = [0, 3, 6, 9].map((i) => trackStatKey('home', '/t$i.mp3'));
      for (final k in gone) {
        expect(s.tracks.containsKey(k), false, reason: 'zero-play track evicted first');
      }
    });

    test('days roll into months past the cap; months are never dropped', () {
      final s = PlayStatsData();
      for (var d = 0; d < 10; d++) {
        PlayStatsFold.fold(s, ev('d$d', t0.subtract(Duration(days: d))));
      }
      PlayStatsFold.rollDays(s, keep: 4);
      expect(s.days.length, 4);
      final kept = s.days.keys.toList()..sort();
      expect(kept.first, dayKeyOf(t0.subtract(const Duration(days: 3))));
      expect(s.months.values.fold<int>(0, (n, m) => n + m.plays), 10, reason: 'the months keep every play');
    });

    test('purgeServer removes only that server\'s tracks', () {
      final s = PlayStatsData();
      PlayStatsFold.fold(s, ev('1', t0, server: 'home'));
      PlayStatsFold.fold(s, ev('2', t0, server: 'work', path: '/w.mp3'));
      PlayStatsFold.fold(s, ev('3', t0, server: '', path: '/sdcard/local.mp3'));
      PlayStatsFold.purgeServer(s, 'home');
      expect(s.tracks.keys.toList()..sort(), [trackStatKey('', '/sdcard/local.mp3'), trackStatKey('work', '/w.mp3')]);
      expect(s.days[dayKeyOf(t0)]!.plays, 3, reason: 'days are totals, untouched');
    });
  });

  group('OutboxFold', () {
    test('enqueue dedups by id, groups by target, caps the oldest across targets', () {
      final g = <String, List<PlayEvent>>{};
      OutboxFold.enqueue(g, 'home', ev('a', t0));
      OutboxFold.enqueue(g, 'home', ev('a', t0));
      OutboxFold.enqueue(g, 'work', ev('b', t0.subtract(const Duration(hours: 2))));
      OutboxFold.enqueue(g, 'home', ev('c', t0.add(const Duration(hours: 1))));
      expect(OutboxFold.total(g), 3);
      OutboxFold.capOldest(g, cap: 2);
      expect(g.containsKey('work'), false, reason: 'the oldest event was work\'s only one');
      expect(g['home']!.map((e) => e.id), ['a', 'c']);
    });

    test('ageOut drops what a server would refuse anyway', () {
      final g = <String, List<PlayEvent>>{};
      OutboxFold.enqueue(g, 'home', ev('old', t0.subtract(const Duration(days: 31))));
      OutboxFold.enqueue(g, 'home', ev('new', t0));
      expect(OutboxFold.ageOut(g, t0.toUtc()), 1);
      expect(g['home']!.map((e) => e.id), ['new']);
    });

    test('drop settles answered ids and removes an emptied group', () {
      final g = <String, List<PlayEvent>>{};
      OutboxFold.enqueue(g, 'home', ev('a', t0));
      OutboxFold.enqueue(g, 'home', ev('b', t0));
      OutboxFold.drop(g, 'home', ['a', 'zzz']);
      expect(g['home']!.map((e) => e.id), ['b']);
      OutboxFold.drop(g, 'home', ['b']);
      expect(g.isEmpty, true);
    });
  });

  group('PlayHistory store', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('play-history-');
      PlayHistory.storageDirectory = () async => dir;
      PlayHistory().resetForTest();
    });
    tearDown(() async {
      PlayHistory().resetForTest();
      await dir.delete(recursive: true);
    });

    test('record appends a ring line, folds the stats, and persists both', () async {
      final h = PlayHistory();
      await h.init();
      expect(await h.record(ev('1', t0, artist: 'A')), true);
      expect(await h.record(ev('2', t0.add(const Duration(minutes: 4)), playedMs: 9000, outcome: PlayOutcome.skipped)), true);
      await h.flush();
      final lines = await File('${dir.path}/play_history.jsonl').readAsLines();
      expect(lines.length, 2);
      expect(PlayEvent.fromJsonLine(lines[0])!.id, '1');
      final statsOnDisk = jsonDecode(await File('${dir.path}/play_stats.json').readAsString());
      expect(statsOnDisk['ring'], 2);
      expect(h.stats.tracks.values.single.plays, 1);
      expect(h.statFor('home', '/music/a.mp3')!.skips, 1);

      // a fresh process sees the same aggregates without touching the ring
      h.resetForTest();
      await h.init();
      expect(h.stats.ringCount, 2);
      expect(h.stats.tracks.values.single.events, 2);
      final events = await h.events();
      expect(events.map((e) => e.id), ['1', '2']);
    });

    test('history off records nothing', () async {
      final h = PlayHistory();
      await h.init();
      h.enabled = false;
      expect(await h.record(ev('1', t0)), false);
      expect(await File('${dir.path}/play_history.jsonl').exists(), false);
      expect(h.stats.isEmpty, true);
    });

    test('the ring skips a torn last line and foreign lines', () async {
      final f = File('${dir.path}/play_history.jsonl');
      await f.writeAsString('${ev('1', t0).toJsonLine()}\n{"not":"an event"}\nnot json at all\n{"id":"torn","t":1', flush: true);
      final h = PlayHistory();
      final events = await h.events();
      expect(events.map((e) => e.id), ['1']);
    });

    test('compaction keeps the newest lines and the ring count', () async {
      final h = PlayHistory();
      await h.init();
      final f = File('${dir.path}/play_history.jsonl');
      final sink = f.openWrite();
      for (var i = 0; i < kRingCompactAt; i++) {
        sink.writeln(ev('e$i', t0.add(Duration(seconds: i))).toJsonLine());
      }
      await sink.close();
      h.stats.ringCount = kRingCompactAt;
      await h.record(ev('last', t0.add(const Duration(days: 1))));
      await h.flush();
      final lines = await f.readAsLines();
      expect(lines.length, kRingCap);
      expect(PlayEvent.fromJsonLine(lines.last)!.id, 'last');
      expect(PlayEvent.fromJsonLine(lines.first)!.id, 'e${kRingCompactAt - kRingCap + 1}');
      expect(h.stats.ringCount, kRingCap);
    });

    test('outbox: enqueue, pending, settle, persist and reload; age-out on load', () async {
      final h = PlayHistory();
      await h.init();
      await h.enqueue('home', ev('a', t0));
      await h.enqueue('home', ev('b', t0.add(const Duration(minutes: 1))));
      await h.enqueue('work', ev('c', t0, server: 'work'));
      expect(h.outboxCount, 3);
      expect(h.pending('home', limit: 1).map((e) => e.id), ['a']);
      await h.settle('home', ['a']);
      expect(h.pending('home').map((e) => e.id), ['b']);
      h.resetForTest();
      await h.init();
      expect(h.outboxCount, 2);
      expect(h.pending('work').single.id, 'c');
      await h.purgeOutbox(target: 'work');
      await h.purgeOutbox();
      expect(await File('${dir.path}/play_outbox.json').exists(), false);

      await File('${dir.path}/play_outbox.json').writeAsString(jsonEncode({
        'home': [ev('stale', DateTime.now().subtract(const Duration(days: 40))).toJson(), ev('fresh', DateTime.now()).toJson()]
      }));
      h.resetForTest();
      await h.init();
      expect(h.pending('home').map((e) => e.id), ['fresh']);
    });

    test('purgeServer removes the server and its peers from tracks, ring and outbox', () async {
      final h = PlayHistory();
      await h.init();
      await h.record(ev('1', t0, server: 'home'));
      await h.record(ev('2', t0, server: 'home-peer', path: '/p.mp3', peerId: 3));
      await h.record(ev('3', t0, server: 'work', path: '/w.mp3'));
      await h.enqueue('home', ev('2', t0, server: 'home-peer', path: '/p.mp3', peerId: 3));
      await h.enqueue('work', ev('3', t0, server: 'work', path: '/w.mp3'));
      await h.purgeServer('home', peers: ['home-peer']);
      expect(h.stats.tracks.keys.single, trackStatKey('work', '/w.mp3'));
      expect((await h.events()).map((e) => e.id), ['3']);
      expect(h.outbox.keys.single, 'work');
      final lines = await File('${dir.path}/play_history.jsonl').readAsLines();
      expect(lines.length, 1);
    });

    test('clear deletes every file and empties memory', () async {
      final h = PlayHistory();
      await h.init();
      await h.record(ev('1', t0));
      await h.enqueue('home', ev('1', t0));
      await h.flush();
      expect(await h.sizeBytes(), greaterThan(0));
      await h.clear();
      expect(h.stats.isEmpty, true);
      expect(h.outboxCount, 0);
      expect(await h.events(), isEmpty);
      expect(await h.sizeBytes(), 0);
      for (final n in ['play_history.jsonl', 'play_stats.json', 'play_outbox.json']) {
        expect(await File('${dir.path}/$n').exists(), false, reason: n);
      }
    });
  });
}
