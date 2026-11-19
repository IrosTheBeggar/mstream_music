// Recently played, the Auto DJ start prompts' third option: the songs this
// phone played last on the DJ's server, newest first, each once — only what
// counted as a play or ran to its end, no local files, no other server's
// songs (a path names a row in one library). And the Add song sheet's, the
// same over every server of the session. And the Less like Add song sheet's
// Skipped: the songs skipped lately, by the same rules, where a skip is a
// play a change of track ended before it counted, a second or more in.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/play_event.dart';
import 'package:mstream_music/util/auto_dj_recent.dart';
import 'package:mstream_music/util/auto_dj_seeds.dart';

var _n = 0;

PlayEvent _play(String server, String path,
    {required int minute,
    PlayOutcome outcome = PlayOutcome.completed,
    bool? counted,
    int playedMs = 180000}) {
  final at = DateTime.utc(2026, 10, 31, 12, minute);
  return PlayEvent(
    id: 'e${_n++}',
    startedAt: at,
    endedAt: at.add(const Duration(minutes: 3)),
    track: TrackFacts(server: server, path: path, title: path, artist: 'A'),
    playedMs: playedMs,
    outcome: outcome,
    source: PlaySource.manual,
    counted: counted ?? outcome != PlayOutcome.skipped,
  );
}

/// A skip [heardMs] into the song, which did not count as a play.
PlayEvent _skip(String server, String path,
        {required int minute, int heardMs = 5000}) =>
    _play(server, path,
        minute: minute,
        outcome: PlayOutcome.skipped,
        counted: false,
        playedMs: heardMs);

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

  // The Add song sheet's Recently played: the same rules over every server
  // the Auto DJ session draws from, a song being its seed key (server and
  // path), and the rows the seed list already holds left out.
  group('recentlyPlayedIn', () {
    test('newest first across the servers, from one pass', () {
      final events = [
        _play('home', '/a.mp3', minute: 1),
        _play('office', '/b.mp3', minute: 4),
        _play('lab', '/c.mp3', minute: 3),
        _play('home', '/d.mp3', minute: 2),
      ];
      expect(_paths(recentlyPlayedIn(events, {'home', 'office'})),
          ['/b.mp3', '/d.mp3', '/a.mp3']);
    });

    test('the same path on two servers is two songs', () {
      final events = [
        _play('home', '/Music/x.mp3', minute: 1),
        _play('office', '/Music/x.mp3', minute: 2),
        _play('home', 'Music/x.mp3', minute: 3),
      ];
      final songs = recentlyPlayedIn(events, {'home', 'office'});
      expect([for (final s in songs) '${s.server}:${s.path}'],
          ['home:Music/x.mp3', 'office:/Music/x.mp3'],
          reason: "home's two plays are one song, with or without the slash");
    });

    test('the keys to exclude are left out, in either path form', () {
      final events = [
        _play('home', '/a.mp3', minute: 1),
        _play('home', 'b.mp3', minute: 2),
        _play('office', '/a.mp3', minute: 3),
      ];
      final songs = recentlyPlayedIn(events, {'home', 'office'},
          exclude: {seedKey('home', 'a.mp3'), seedKey('home', '/b.mp3')});
      expect([for (final s in songs) '${s.server}:${s.path}'],
          ['office:/a.mp3']);
    });

    test('no local file, even with its empty server in the set; no empty '
        'path', () {
      final events = [
        _play('', '/storage/c.mp3', minute: 1),
        _play('home', '', minute: 2),
        _play('home', '/', minute: 3),
        _play('home', '/ok.mp3', minute: 4),
      ];
      expect(_paths(recentlyPlayedIn(events, {'', 'home'})), ['/ok.mp3']);
    });

    test('only counted or completed plays; capped at the limit', () {
      final events = [
        _play('home', '/skipped.mp3',
            minute: 40, outcome: PlayOutcome.skipped, counted: false),
        for (var i = 0; i < 30; i++)
          _play(i.isEven ? 'home' : 'office', '/$i.mp3', minute: i),
      ];
      final songs = recentlyPlayedIn(events, {'home', 'office'});
      expect(songs, hasLength(kRecentlyPlayedLimit));
      expect(songs.first.path, '/29.mp3');
      expect(_paths(recentlyPlayedIn(events, {'home', 'office'}, limit: 2)),
          ['/29.mp3', '/28.mp3']);
      expect(recentlyPlayedIn(events, {'home'}, limit: 0), isEmpty);
    });
  });

  // The Less like Add song sheet's Skipped: the songs a change of track
  // ended before they counted, heard for a second or more, newest first,
  // each once, on the servers Add song may offer.
  group('recentlySkippedIn', () {
    String keyed(TrackFacts s) => '${s.server}:${s.path}';

    test('newest first, whatever order the events come in, across the '
        'servers', () {
      final events = [
        _skip('home', '/a.mp3', minute: 1),
        _skip('office', '/c.mp3', minute: 3),
        _skip('home', '/b.mp3', minute: 2),
      ];
      expect(_paths(recentlySkippedIn(events, {'home', 'office'})),
          ['/c.mp3', '/b.mp3', '/a.mp3']);
    });

    test('a skip heard under a second is left out; one at a second is in',
        () {
      final events = [
        // The error walk's advance, or a row tapped past at once.
        _skip('home', '/zero.mp3', minute: 1, heardMs: 0),
        _skip('home', '/almost.mp3', minute: 2, heardMs: 999),
        _skip('home', '/second.mp3', minute: 3, heardMs: 1000),
      ];
      expect(_paths(recentlySkippedIn(events, {'home'})), ['/second.mp3']);
    });

    test('only skips that did not count: not a counted skip, a completed '
        'play or a stop', () {
      final events = [
        _play('home', '/late-skip.mp3',
            minute: 1,
            outcome: PlayOutcome.skipped,
            counted: true,
            playedMs: 40000),
        _play('home', '/completed.mp3', minute: 2),
        _play('home', '/completed-short.mp3',
            minute: 3, counted: false, playedMs: 5000),
        _play('home', '/stopped.mp3',
            minute: 4,
            outcome: PlayOutcome.stopped,
            counted: false,
            playedMs: 5000),
        _skip('home', '/skipped.mp3', minute: 5),
      ];
      expect(_paths(recentlySkippedIn(events, {'home'})), ['/skipped.mp3']);
    });

    test("one song is one row, with or without the queue's leading slash, "
        'at its latest skip', () {
      final events = [
        _skip('home', '/a.mp3', minute: 1),
        _skip('home', '/b.mp3', minute: 2),
        _skip('home', 'a.mp3', minute: 3),
      ];
      expect(_paths(recentlySkippedIn(events, {'home'})), ['a.mp3', '/b.mp3']);
    });

    test('the same path on two servers is two songs', () {
      final events = [
        _skip('home', '/Music/x.mp3', minute: 1),
        _skip('office', '/Music/x.mp3', minute: 2),
      ];
      final songs = recentlySkippedIn(events, {'home', 'office'});
      expect([for (final s in songs) keyed(s)],
          ['office:/Music/x.mp3', 'home:/Music/x.mp3']);
    });

    test("another server's skip, a local file and an empty path are left "
        'out', () {
      final events = [
        _skip('office', '/elsewhere.mp3', minute: 1),
        _skip('', '/storage/local.mp3', minute: 2),
        _skip('home', '', minute: 3),
        _skip('home', '/', minute: 4),
        _skip('home', '/ok.mp3', minute: 5),
      ];
      expect(_paths(recentlySkippedIn(events, {'', 'home'})), ['/ok.mp3']);
    });

    test('the keys to exclude are left out, in either path form', () {
      final events = [
        _skip('home', '/a.mp3', minute: 1),
        _skip('home', 'b.mp3', minute: 2),
        _skip('office', '/a.mp3', minute: 3),
      ];
      final songs = recentlySkippedIn(events, {'home', 'office'},
          exclude: {seedKey('home', 'a.mp3'), seedKey('home', '/b.mp3')});
      expect([for (final s in songs) keyed(s)], ['office:/a.mp3']);
    });

    test('capped at the limit', () {
      final events = [
        for (var i = 0; i < 30; i++) _skip('home', '/$i.mp3', minute: i),
      ];
      final songs = recentlySkippedIn(events, {'home'});
      expect(songs, hasLength(kRecentlyPlayedLimit));
      expect(songs.first.path, '/29.mp3');
      expect(_paths(recentlySkippedIn(events, {'home'}, limit: 2)),
          ['/29.mp3', '/28.mp3']);
      expect(recentlySkippedIn(events, {'home'}, limit: 0), isEmpty);
    });

    test('a skip and a play of one song: each list takes its own event', () {
      final events = [
        _skip('home', '/a.mp3', minute: 1),
        _play('home', '/a.mp3', minute: 2),
      ];
      expect(_paths(recentlySkippedIn(events, {'home'})), ['/a.mp3']);
      expect(_paths(recentlyPlayedIn(events, {'home'})), ['/a.mp3']);
    });
  });
}
