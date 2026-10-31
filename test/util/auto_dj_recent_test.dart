// Recently played, the Auto DJ start prompts' third option: the songs this
// phone played last on the DJ's server, newest first, each once — only what
// counted as a play or ran to its end, no local files, no other server's
// songs (a path names a row in one library).

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/play_event.dart';
import 'package:mstream_music/util/auto_dj_recent.dart';

var _n = 0;

PlayEvent _play(String server, String path,
    {required int minute,
    PlayOutcome outcome = PlayOutcome.completed,
    bool? counted}) {
  final at = DateTime.utc(2026, 10, 31, 12, minute);
  return PlayEvent(
    id: 'e${_n++}',
    startedAt: at,
    endedAt: at.add(const Duration(minutes: 3)),
    track: TrackFacts(server: server, path: path, title: path, artist: 'A'),
    playedMs: 180000,
    outcome: outcome,
    source: PlaySource.manual,
    counted: counted ?? outcome != PlayOutcome.skipped,
  );
}

List<String> _paths(List<TrackFacts> songs) => [for (final s in songs) s.path];

void main() {
  test('newest first, whatever order the events come in', () {
    final events = [
      _play('home', '/a.mp3', minute: 1),
      _play('home', '/c.mp3', minute: 3),
      _play('home', '/b.mp3', minute: 2),
    ];
    expect(_paths(recentlyPlayedOn(events, 'home')),
        ['/c.mp3', '/b.mp3', '/a.mp3']);
  });

  test('each song once, at its latest play', () {
    final events = [
      _play('home', '/a.mp3', minute: 1),
      _play('home', '/b.mp3', minute: 2),
      _play('home', '/a.mp3', minute: 3),
    ];
    expect(_paths(recentlyPlayedOn(events, 'home')), ['/a.mp3', '/b.mp3']);
  });

  test("only the DJ server's songs; no local files", () {
    final events = [
      _play('home', '/a.mp3', minute: 1),
      _play('office', '/b.mp3', minute: 2),
      _play('', '/storage/c.mp3', minute: 3),
    ];
    expect(_paths(recentlyPlayedOn(events, 'home')), ['/a.mp3']);
    expect(_paths(recentlyPlayedOn(events, 'office')), ['/b.mp3']);
    expect(recentlyPlayedOn(events, 'nowhere'), isEmpty);
  });

  test('what counted as a play, or ran to its end — not seconds-in stops '
      'or skips', () {
    final events = [
      _play('home', '/stopped-counted.mp3',
          minute: 1, outcome: PlayOutcome.stopped, counted: true),
      _play('home', '/stopped-early.mp3',
          minute: 2, outcome: PlayOutcome.stopped, counted: false),
      _play('home', '/skipped-late.mp3',
          minute: 3, outcome: PlayOutcome.skipped, counted: true),
      _play('home', '/skipped-early.mp3',
          minute: 4, outcome: PlayOutcome.skipped, counted: false),
      _play('home', '/completed-short.mp3',
          minute: 5, outcome: PlayOutcome.completed, counted: false),
    ];
    expect(_paths(recentlyPlayedOn(events, 'home')),
        ['/completed-short.mp3', '/skipped-late.mp3', '/stopped-counted.mp3']);
  });

  test("one song is one row, with or without the queue's leading slash", () {
    final events = [
      _play('home', '/Music/x.mp3', minute: 1),
      _play('home', 'Music/x.mp3', minute: 2),
      _play('home', '/Music/y.mp3', minute: 3),
    ];
    expect(_paths(recentlyPlayedOn(events, 'home')),
        ['/Music/y.mp3', 'Music/x.mp3']);
  });

  test('capped at the limit', () {
    final events = [
      for (var i = 0; i < 30; i++) _play('home', '/$i.mp3', minute: i),
    ];
    expect(recentlyPlayedOn(events, 'home'), hasLength(kRecentlyPlayedLimit));
    expect(recentlyPlayedOn(events, 'home').first.path, '/29.mp3');
    expect(recentlyPlayedOn(events, 'home', limit: 3), hasLength(3));
  });
}
