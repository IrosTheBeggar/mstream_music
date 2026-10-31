// YtdlJob as it is persisted with its server (Server.ytdlJobs): every field
// survives toJson → fromJson, in each state; what counts as "open" (polled,
// counted as Adding); a state written by a newer build loads as a "not
// sure" row instead of being dropped or polled forever; and an entry with
// nothing to match it by is refused (tryFromJson → null).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/ytdl_job.dart';

YtdlJob job({YtdlJobState state = YtdlJobState.starting}) => YtdlJob(
      id: 'j-1',
      url: 'https://www.youtube.com/watch?v=FGBhQbmPwH8',
      directory: '/Music/Daft Punk/Discovery/',
      codec: 'mp3',
      tags: const {
        'title': 'One More Time',
        'artist': 'Daft Punk',
        'album': 'Discovery',
        'year': '2001',
      },
      title: 'One More Time',
      cover: 'https://i.ytimg.com/vi/FGBhQbmPwH8/hq.jpg',
      predictedName: 'Daft_Punk_-_One_More_Time_Official_Video.mp3',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1793450000000),
      state: state,
    );

/// Through a real JSON string, as servers.json stores it.
YtdlJob roundTrip(YtdlJob j) =>
    YtdlJob.fromJson(jsonDecode(jsonEncode(j.toJson())) as Map);

void main() {
  test('a fresh job: starting, open, nothing from the server yet', () {
    final j = job();
    expect(j.state, YtdlJobState.starting);
    expect(j.open, isTrue);
    expect([j.pid, j.serverStart, j.endedAt, j.problem, j.filepath], everyElement(isNull));
    expect([j.hidden, j.seen], [false, false]);
  });

  test('every field survives the round trip', () {
    final j = job(state: YtdlJobState.added)
      ..pid = 4711
      ..serverStart = 1793450002000
      ..endedAt = DateTime.fromMillisecondsSinceEpoch(1793450200000)
      ..hidden = true
      ..seen = true
      ..filepath = 'Music/Daft Punk/Discovery/One_More_Time.mp3'
      ..bytes = 8400000
      ..trackId = 991
      ..recordId = 57;
    final back = roundTrip(j);
    expect(back.id, 'j-1');
    expect(back.url, j.url);
    expect(back.directory, '/Music/Daft Punk/Discovery/');
    expect(back.codec, 'mp3');
    expect(back.tags, j.tags);
    expect(back.title, 'One More Time');
    expect(back.cover, j.cover);
    expect(back.predictedName, j.predictedName);
    expect(back.createdAt, j.createdAt);
    expect(back.state, YtdlJobState.added);
    expect(back.pid, 4711);
    expect(back.serverStart, 1793450002000);
    expect(back.endedAt, j.endedAt);
    expect(back.hidden, isTrue);
    expect(back.seen, isTrue);
    expect(back.filepath, j.filepath);
    expect(back.bytes, 8400000);
    expect(back.trackId, 991);
    expect(back.recordId, 57);
  });

  test("a start failure keeps its reason and the server's words", () {
    final j = job(state: YtdlJobState.startFailed)
      ..problem = 'other'
      ..problemDetail = 'Not A Directory';
    final back = roundTrip(j);
    expect(back.state, YtdlJobState.startFailed);
    expect(back.problem, 'other');
    expect(back.problemDetail, 'Not A Directory');
  });

  test('every state round-trips by name', () {
    for (final s in YtdlJobState.values) {
      expect(roundTrip(job(state: s)).state, s);
    }
  });

  test('open: starting, startUnsure and adding — nothing else', () {
    const open = {YtdlJobState.starting, YtdlJobState.startUnsure, YtdlJobState.adding};
    for (final s in YtdlJobState.values) {
      expect(job(state: s).open, open.contains(s), reason: s.name);
      expect(s.open, open.contains(s), reason: s.name);
    }
  });

  group('a state this build does not know', () {
    test('without a claimed entry: not sure it started (Check again asks)',
        () {
      final j = job().toJson()..['state'] = 'queuedOnServer';
      expect(YtdlJob.fromJson(j).state, YtdlJobState.notSureStarted);
      expect(YtdlJob.fromJson(j).open, isFalse, reason: 'never polled forever');
    });

    test('with a claimed entry: it started, so not sure it finished', () {
      final j = job().toJson()
        ..['state'] = 'transcoding'
        ..['pid'] = 4711;
      expect(YtdlJob.fromJson(j).state, YtdlJobState.notSureFinished);
    });

    test('a missing or junk state reads the same way', () {
      expect(YtdlJob.fromJson(job().toJson()..remove('state')).state,
          YtdlJobState.notSureStarted);
      expect(YtdlJob.fromJson(job().toJson()..['state'] = 3).state,
          YtdlJobState.notSureStarted);
      expect(YtdlJobState.parse(null), isNull);
      expect(YtdlJobState.parse('adding'), YtdlJobState.adding);
    });
  });

  group('tolerance', () {
    test('junk optional fields load as absent', () {
      final j = job().toJson()
        ..['cover'] = 7
        ..['pid'] = '4711'
        ..['endedAt'] = 'yesterday'
        ..['hidden'] = 'yes'
        ..['bytes'] = 1.5
        ..['tags'] = {'title': 'One More Time', 'year': 2001, 3: 'x'}
        ..remove('codec')
        ..remove('createdAt');
      final back = YtdlJob.fromJson(j);
      expect(back.cover, isNull);
      expect(back.pid, isNull);
      expect(back.endedAt, isNull);
      expect(back.hidden, isFalse);
      expect(back.bytes, isNull);
      expect(back.tags, {'title': 'One More Time'});
      expect(back.codec, '');
      expect(back.createdAt, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('no id, link or folder: refused', () {
      for (final key in ['id', 'url', 'directory']) {
        final j = job().toJson()..remove(key);
        expect(() => YtdlJob.fromJson(j), throwsFormatException, reason: key);
        expect(YtdlJob.tryFromJson(j), isNull, reason: key);
      }
      expect(YtdlJob.tryFromJson(job().toJson()..['id'] = ''), isNull);
      expect(YtdlJob.tryFromJson('junk'), isNull);
      expect(YtdlJob.tryFromJson(null), isNull);
      expect(YtdlJob.tryFromJson(job().toJson())?.id, 'j-1');
    });
  });
}
