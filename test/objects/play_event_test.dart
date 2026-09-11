import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/play_event.dart';

void main() {
  group('countsAsPlay — the server rule, mirrored', () {
    test('30 seconds counts, a hair under does not', () {
      expect(countsAsPlay(playedMs: 30000, durationMs: 300000), isTrue);
      expect(countsAsPlay(playedMs: 29999, durationMs: 300000), isFalse);
    });

    test('half of a short track counts before 30 seconds', () {
      expect(countsAsPlay(playedMs: 20000, durationMs: 40000), isTrue);
      expect(countsAsPlay(playedMs: 19999, durationMs: 40000), isFalse);
    });

    test('unknown or zero duration falls back to the 30-second rule only', () {
      expect(countsAsPlay(playedMs: 25000), isFalse);
      expect(countsAsPlay(playedMs: 25000, durationMs: 0), isFalse);
      expect(countsAsPlay(playedMs: 30000), isTrue);
    });
  });

  TrackFacts facts({int? peerId, String server = 'home'}) => TrackFacts(
        server: server,
        peerId: peerId,
        path: '/music/Radiohead/OK Computer/05 Let Down.flac',
        hash: '7c1e',
        title: 'Let Down',
        artist: 'Radiohead',
        album: 'OK Computer',
        artFile: 'art.jpg',
        durationMs: 299000,
      );

  PlayEvent event({TrackFacts? track}) => PlayEvent(
        id: '9f3c',
        startedAt: DateTime.utc(2026, 9, 4, 19, 4, 0, 500),
        endedAt: DateTime.utc(2026, 9, 4, 19, 9, 0),
        track: track ?? facts(),
        playedMs: 240000,
        outcome: PlayOutcome.skipped,
        source: PlaySource.autodj,
        pauseCount: 2,
        counted: true,
      );

  group('PlayEvent JSON', () {
    test('round-trips through a JSON line', () {
      final line = event().toJsonLine();
      final back = PlayEvent.fromJsonLine(line);
      expect(back, isNotNull);
      expect(back!.id, '9f3c');
      expect(back.startedAt, DateTime.utc(2026, 9, 4, 19, 4, 0, 500));
      expect(back.endedAt, DateTime.utc(2026, 9, 4, 19, 9, 0));
      expect(back.track.server, 'home');
      expect(back.track.path, '/music/Radiohead/OK Computer/05 Let Down.flac');
      expect(back.track.hash, '7c1e');
      expect(back.track.title, 'Let Down');
      expect(back.track.artFile, 'art.jpg');
      expect(back.track.durationMs, 299000);
      expect(back.playedMs, 240000);
      expect(back.outcome, PlayOutcome.skipped);
      expect(back.source, PlaySource.autodj);
      expect(back.pauseCount, 2);
      expect(back.counted, isTrue);
    });

    test('a torn or foreign line reads as null; an unknown source degrades', () {
      expect(PlayEvent.fromJsonLine('{"id":"x","t":1'), isNull);
      expect(PlayEvent.fromJsonLine('[]'), isNull);
      expect(PlayEvent.fromJsonLine('{"id":"x","t":1,"pl":1}'), isNull); // no path
      final odd = event().toJson()..['s'] = 'radio';
      expect(PlayEvent.fromJson(odd)!.source, PlaySource.other);
      final badOutcome = event().toJson()..['o'] = 'vanished';
      expect(PlayEvent.fromJson(badOutcome), isNull);
    });

    test('a local-device file has an empty server and no peer', () {
      final e = event(track: facts(server: ''));
      expect(e.track.isLocalFile, isTrue);
      expect(PlayEvent.fromJson(e.toJson())!.track.isLocalFile, isTrue);
    });
  });

  group('PlayEvent.toWire — the Stats API v2 element', () {
    test('strips the leading slash and omits peer fields for a local track', () {
      final w = event().toWire();
      expect(w['filePath'], 'music/Radiohead/OK Computer/05 Let Down.flac');
      expect(w['startedAt'], '2026-09-04T19:04:00.500Z');
      expect(w['endedAt'], '2026-09-04T19:09:00.000Z');
      expect(w['playedMs'], 240000);
      expect(w['durationMs'], 299000);
      expect(w['outcome'], 'skipped');
      expect(w['source'], 'autodj');
      expect(w['pauseCount'], 2);
      expect(w.containsKey('peerId'), isFalse);
      expect(w.containsKey('track'), isFalse);
    });

    test('a federated play carries peerId and the snapshot', () {
      final w = event(track: facts(peerId: 3, server: 'bob')).toWire();
      expect(w['peerId'], 3);
      expect(w['track'], {
        'title': 'Let Down',
        'artist': 'Radiohead',
        'album': 'OK Computer',
        'durationMs': 299000,
        'hash': '7c1e',
        'artFile': 'art.jpg',
      });
    });
  });
}
