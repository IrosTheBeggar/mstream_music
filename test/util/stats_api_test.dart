import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mstream_music/objects/listening_stats.dart';
import 'package:mstream_music/objects/play_event.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/play_sync.dart';
import 'package:mstream_music/util/stats_api.dart';

PlayEvent ev(String id, {int? peerId}) => PlayEvent(
      id: id,
      startedAt: DateTime.utc(2026, 9, 10, 20),
      endedAt: DateTime.utc(2026, 9, 10, 20, 3),
      track: TrackFacts(server: 'music', peerId: peerId, path: '/music/a.mp3', title: 'A', artist: 'Ann', hash: 'h1', durationMs: 240000),
      playedMs: 180000,
      outcome: PlayOutcome.completed,
      source: PlaySource.manual,
      counted: true,
    );

void main() {
  final server = Server('http://music.test:3000', 'rig', 'pw', 'jwt-123', 'music');
  StatsApi api(Future<http.Response> Function(http.Request) h) => StatsApi(server, client: MockClient(h));
  http.Response json(Object body, {int status = 200}) => http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

  group('postPlays', () {
    test('sends the client block and the wire events with the token, maps the answer', () async {
      http.Request? seen;
      StatsApi.appVersion = 'v1.2.3';
      final r = await api((req) async {
        seen = req;
        return json({'accepted': ['a'], 'duplicates': ['b'], 'rejected': [{'id': 'c', 'reason': 'unknown-track'}]});
      }).postPlays([ev('a'), ev('b'), ev('c', peerId: 4)]);
      expect(seen!.method, 'POST');
      expect(seen!.url.path, '/api/v1/stats/plays');
      expect(seen!.headers['x-access-token'], 'jwt-123');
      final body = jsonDecode(seen!.body) as Map;
      expect(body['client'], {'name': 'mstream-music', 'version': 'v1.2.3'});
      final plays = body['plays'] as List;
      expect(plays.length, 3);
      expect(plays[0]['filePath'], 'music/a.mp3', reason: 'leading slash stripped');
      expect(plays[0].containsKey('peerId'), false);
      expect(plays[2]['peerId'], 4);
      expect((plays[2]['track'] as Map)['hash'], 'h1', reason: 'a peer play carries its snapshot');
      expect(r.accepted, ['a']);
      expect(r.duplicates, ['b']);
      expect(r.rejected, {'c': 'unknown-track'});
    });

    test('401/403 → unauthorized; 5xx → server; a dead socket → network', () async {
      for (final status in [401, 403]) {
        await expectLater(api((_) async => http.Response('nope', status)).postPlays([ev('a')]),
            throwsA(isA<PostPlaysException>().having((e) => e.kind, 'kind', PostFailure.unauthorized)));
      }
      await expectLater(api((_) async => json({'error': 'boom'}, status: 500)).postPlays([ev('a')]),
          throwsA(isA<PostPlaysException>().having((e) => e.kind, 'kind', PostFailure.server).having((e) => e.message, 'message', 'boom')));
      await expectLater(api((_) async => throw http.ClientException('Connection refused')).postPlays([ev('a')]),
          throwsA(isA<PostPlaysException>().having((e) => e.kind, 'kind', PostFailure.network)));
      await expectLater(api((_) async => http.Response('not json', 200)).postPlays([ev('a')]),
          throwsA(isA<PostPlaysException>().having((e) => e.kind, 'kind', PostFailure.server)));
    });
  });

  group('reads', () {
    test('summary / top / history / hourOfDay send the period and origin and parse the answers', () async {
      final urls = <Uri>[];
      final a = api((req) async {
        urls.add(req.url);
        switch (req.url.path) {
          case '/api/v1/stats/summary':
            return json({'events': 3, 'plays': 2, 'skips': 1, 'listenedMs': 1000, 'uniqueTracks': 2, 'streakDays': {'current': 1, 'longest': 2}});
          case '/api/v1/stats/top':
            return json({'items': [{'rank': 1, 'plays': 2, 'listenedMs': 5, 'share': 1, 'track': {'filepath': 'music/a.mp3', 'metadata': {'title': 'A', 'artist': 'Ann'}}}]});
          case '/api/v1/stats/history':
            return json({'items': [{'id': 'e1', 'startedAt': '2026-09-03T11:00:00.000Z', 'outcome': 'completed', 'counted': true, 'playedMs': 100, 'track': {'filepath': 'music/a.mp3', 'metadata': {'title': 'A'}}}], 'next': 'cursor-1'});
          case '/api/v1/stats/timeseries':
            return json({'items': [{'bucket': '20', 'plays': 4}, {'bucket': '7', 'plays': 1}, {'bucket': 'x', 'plays': 9}]});
        }
        return http.Response('{}', 404);
      });
      final s = await a.summary(period: StatsPeriod.week, offset: -1, origin: 'peers', tz: 'Europe/Berlin');
      expect([s.events, s.plays, s.streakLongest], [3, 2, 2]);
      expect(urls.last.queryParameters, {'period': 'week', 'offset': '-1', 'tz': 'Europe/Berlin', 'origin': 'peers'});
      final top = await a.top(entity: 'tracks', metric: 'time', period: StatsPeriod.all, limit: 5, tz: 'UTC');
      expect(top.single.title, 'A');
      expect(urls.last.queryParameters['period'], 'all');
      expect(urls.last.queryParameters['metric'], 'time');
      expect(urls.last.queryParameters['limit'], '5');
      final h = await a.history(period: StatsPeriod.month, limit: 10, before: 'c0', tz: 'UTC');
      expect(h.items.single.id, 'e1');
      expect(h.next, 'cursor-1');
      expect(urls.last.queryParameters['before'], 'c0');
      final unranged = await a.history(tz: 'UTC');
      expect(unranged.items.length, 1);
      expect(urls.last.queryParameters.containsKey('period'), false, reason: 'no range → the newest plays');
      final hours = await a.hourOfDay(period: StatsPeriod.month, tz: 'UTC');
      expect(hours[20], 4);
      expect(hours[7], 1);
      expect(hours.reduce((x, y) => x + y), 5, reason: 'a malformed bucket is ignored');
      expect(urls.last.queryParameters['bucket'], 'hourOfDay');
    });

    test('tracks strips leading slashes and parses counters; a read error names the status', () async {
      http.Request? seen;
      final a = api((req) async {
        seen = req;
        if (req.url.path == '/api/v1/stats/tracks') {
          return json({'items': [{'hash': 'ah', 'filePath': 'music/a.mp3', 'plays': 3, 'skips': 1, 'listenedMs': 10, 'firstPlayed': '2026-08-01T00:00:00.000Z', 'lastPlayed': '2026-09-01T00:00:00.000Z'}, {'nope': 1}]});
        }
        return http.Response('{"error":"Forbidden"}', 403);
      });
      final c = await a.tracks(filePaths: ['/music/a.mp3'], hashes: ['fh']);
      expect(jsonDecode(seen!.body), {'filePaths': ['music/a.mp3'], 'hashes': ['fh']});
      expect(c.single.plays, 3);
      expect(c.single.lastPlayed, DateTime.utc(2026, 9, 1));
      expect(await a.tracks(), isEmpty, reason: 'nothing asked, nothing sent');
      await expectLater(a.summary(tz: 'UTC'), throwsA(isA<StatsApiException>().having((e) => e.status, 'status', 403).having((e) => e.isAuth, 'isAuth', true)));
    });
  });
}
