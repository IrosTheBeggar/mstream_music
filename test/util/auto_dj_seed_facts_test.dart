// What the Seeds page's Add song sheet offers (util/auto_dj_seed_facts.dart):
// a search hit as the facts a seed row keeps (the hit's art file, no hash
// from lite metadata, the server's "Artist - Title" name when an older server
// sends no metadata), the queue's coming rows as Up next (only after the
// playing row, only server songs of the session's servers, nothing the
// target list has, each song once, capped), the playing row by those same
// rules (Less like's Skipped opens with it), and the name a row shows.

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/metadata.dart';
import 'package:mstream_music/objects/play_event.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/util/auto_dj_seed_facts.dart';
import 'package:mstream_music/util/auto_dj_seeds.dart';

final _home = Server('https://home.example.com', 'u', 'p', 'JWT', 'home');

/// A title hit as fetchSongSearch builds it: the '/'-path, the art file
/// beside the lite metadata, partial.
DisplayItem _hit(String path,
    {String? name, Map<String, dynamic>? metadata, String? artFile}) {
  final item = DisplayItem(_home, name ?? path.split('/').last, 'file', path,
      null, null)
    ..altAlbumArt = artFile
    ..partialMetadata = true;
  if (metadata != null) item.metadata = MusicMetadata.fromServerMap(metadata);
  return item;
}

/// A queue row: a server song (a DJ pick's bare vpath or a browsed row's
/// '/'-path), or a local file with no server.
MediaItem _row(String path, {String? server = 'home', String? title}) =>
    MediaItem(
      id: 'https://h/$path',
      title: title ?? path.split('/').last,
      extras: <String, dynamic>{'path': path, 'server': ?server},
    );

List<String> _paths(List<TrackFacts> songs) => [for (final s in songs) s.path];

void main() {
  group('seedFactsFromItem', () {
    test("a search hit's lite metadata, with its art file and its path as "
        'it came', () {
      final song = seedFactsFromItem(_hit('/Music/SkyWalk.flac',
          name: 'Boukmanflow - SkyWalk',
          artFile: 'ab12.jpg',
          metadata: {
            'title': 'SkyWalk',
            'artist': 'Boukmanflow',
            'artist-display': 'Boukmanflow feat. Ann',
            'album': 'Flow',
            'album-art': 'other.jpg',
            'duration': 241.5,
          }));
      expect(song.server, 'home');
      expect(song.path, '/Music/SkyWalk.flac');
      expect(song.title, 'SkyWalk');
      // The primary artist, as every other seed row and Recently played
      // show it, not the credit.
      expect(song.artist, 'Boukmanflow');
      expect(song.album, 'Flow');
      expect(song.artFile, 'ab12.jpg', reason: "the hit's own art file wins");
      expect(song.durationMs, 241500);
      // Lite metadata carries no hash; MusicMetadata reads that as ''.
      expect(song.hash, isNull);
      expect(song.peerId, isNull);
      // The key drops the slash, so the hit is the same seed as the same
      // song arriving as a DJ pick's bare vpath.
      expect(seedKey(song.server, song.path),
          seedKey('home', 'Music/SkyWalk.flac'));
    });

    test("the metadata's art file when the hit carries none; a real hash is "
        'kept', () {
      final song = seedFactsFromItem(_hit('/a.mp3',
          metadata: {'title': 'A', 'album-art': 'cover.png', 'hash': 'h1'}));
      expect(song.artFile, 'cover.png');
      expect(song.hash, 'h1');
    });

    test("no metadata (an older server): the hit's name is the title", () {
      final song =
          seedFactsFromItem(_hit('/Jazz/so-what.mp3', name: 'Miles - So What'));
      expect(song.title, 'Miles - So What');
      expect(song.artist, isNull);
      expect(song.artFile, isNull);
      expect(song.durationMs, isNull);
    });

    test('blank fields count as missing', () {
      final song = seedFactsFromItem(_hit('/x.mp3',
          name: '  ',
          artFile: '',
          metadata: {'title': ' ', 'artist': '', 'album-art': ''}));
      expect(song.title, isNull);
      expect(song.artist, isNull);
      expect(song.artFile, isNull);
    });

    test('a hit with no server or path is no seed (the model ignores it)', () {
      final song =
          seedFactsFromItem(DisplayItem(null, 'x', 'file', null, null, null));
      expect(song.server, '');
      expect(song.path, '');
      expect(
          AutoDjSeeds.empty
              .addManual(SeedList.moreLike, song, now: DateTime.utc(2026)),
          same(AutoDjSeeds.empty));
    });
  });

  group('upNextFacts', () {
    bool any(String _) => true;

    test('the rows after the playing one, in queue order', () {
      final queue = [_row('a'), _row('b'), _row('/c'), _row('d')];
      expect(_paths(upNextFacts(queue, 1, eligible: any)), ['/c', 'd']);
      expect(upNextFacts(queue, 3, eligible: any), isEmpty,
          reason: 'the last row is playing: nothing is still to come');
      expect(upNextFacts(queue, 9, eligible: any), isEmpty);
    });

    test('with nothing playing, every row is still to come', () {
      final queue = [_row('a'), _row('b')];
      expect(_paths(upNextFacts(queue, null, eligible: any)), ['a', 'b']);
      expect(_paths(upNextFacts(queue, -1, eligible: any)), ['a', 'b']);
    });

    test("facts from the queue item: title, primary artist, the art file "
        'from its art URL', () {
      final pick = MediaItem(
        id: 'https://h/x',
        title: 'Duet',
        artist: 'Ann feat. Bob',
        extras: <String, dynamic>{
          'server': 'home',
          'path': 'Music/duet.mp3',
          'artist': 'Ann',
          'artUrl': 'https://home.example.com/album-art/f00.jpg?compress=l',
        },
      );
      final song = upNextFacts([_row('now'), pick], 0, eligible: any).single;
      expect(song.server, 'home');
      expect(song.path, 'Music/duet.mp3');
      expect(song.title, 'Duet');
      expect(song.artist, 'Ann');
      expect(song.artFile, 'f00.jpg');
    });

    test("only the session's servers; never a local file", () {
      final queue = [
        _row('now'),
        _row('a', server: 'home'),
        _row('b', server: 'office'),
        _row('/sdcard/c.mp3', server: null),
        _row('d', server: 'lab'),
      ];
      expect(
          _paths(upNextFacts(queue, 0,
              eligible: {'home', 'lab', ''}.contains)),
          ['a', 'd'],
          reason: 'a local file has no server to resolve its path, even when '
              "'' slips into the set");
    });

    test('a song the target list has is left out; a song queued twice shows '
        'once', () {
      final queue = [
        _row('now'),
        _row('a'),
        _row('/b'),
        _row('b'),
        _row('c'),
        _row('a', server: 'office'),
      ];
      final songs = upNextFacts(queue, 0,
          eligible: any, taken: {seedKey('home', '/a')});
      expect(_paths(songs), ['/b', 'c', 'a'],
          reason: "'/b' and 'b' are one song; the same vpath on another "
              'server is another song');
      expect(songs.last.server, 'office');
    });

    test('capped at the limit', () {
      final queue = [for (var i = 0; i < 30; i++) _row('$i')];
      expect(upNextFacts(queue, 0, eligible: any), hasLength(20));
      expect(_paths(upNextFacts(queue, 0, eligible: any, limit: 2)),
          ['1', '2']);
    });
  });

  group('playingFacts', () {
    bool any(String _) => true;
    bool home(String server) => server == 'home';

    test('the row at the playing index, with its facts', () {
      final queue = [_row('a'), _row('/b', title: 'Bee'), _row('c')];
      final song = playingFacts(queue, 1, eligible: any)!;
      expect(song.server, 'home');
      expect(song.path, '/b', reason: 'the path as the queue row holds it');
      expect(song.title, 'Bee');
      expect(playingFacts(queue, 2, eligible: any)?.path, 'c',
          reason: 'the last row playing is still a playing row');
    });

    test('nothing playing, or an index off either end: none', () {
      final queue = [_row('a'), _row('b')];
      expect(playingFacts(queue, null, eligible: any), isNull);
      expect(playingFacts(queue, -1, eligible: any), isNull);
      expect(playingFacts(queue, 2, eligible: any), isNull);
      expect(playingFacts(const [], 0, eligible: any), isNull);
    });

    test("Up next's rules for a row: no local file, no other server's song, "
        'nothing the list holds, no row without a path', () {
      final queue = [
        _row('/sdcard/a.mp3', server: null),
        _row('b', server: 'office'),
        _row('/c'),
        _row('/'),
        _row('d'),
      ];
      expect(playingFacts(queue, 0, eligible: {'home', ''}.contains), isNull,
          reason: 'a local file has no server to resolve its path');
      expect(playingFacts(queue, 1, eligible: home), isNull,
          reason: "office isn't a server the list can use");
      expect(playingFacts(queue, 1, eligible: any)?.server, 'office');
      expect(
          playingFacts(queue, 2, eligible: any, taken: {seedKey('home', 'c')}),
          isNull,
          reason: "'/c' and 'c' are one song, and the list holds it");
      expect(playingFacts(queue, 3, eligible: any), isNull,
          reason: 'nothing is left of the path once its slash goes');
      expect(playingFacts(queue, 4, eligible: home)?.path, 'd');
    });
  });

  group('seedTitle', () {
    test("the title, else the file's name", () {
      expect(seedTitle(const TrackFacts(server: 'home', path: '/a/b.mp3',
          title: 'Bee')), 'Bee');
      expect(seedTitle(const TrackFacts(server: 'home', path: '/a/b.mp3')),
          'b.mp3');
      expect(seedTitle(const TrackFacts(server: 'home', path: 'a/b.mp3',
          title: '  ')), 'b.mp3');
    });
  });
}
