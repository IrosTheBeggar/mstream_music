// Instant mix's objects (mStream POST /api/v1/discovery/local/mix): the
// `from` each kind of seed sends, what the banner shows before an answer,
// the answer as the browser's file rows (lite metadata, so partial), the
// empty states' flags and the "beyond the seed" count both clients share,
// and the default playlist name that never lands on a taken one.

import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/instant_mix.dart';
import 'package:mstream_music/objects/metadata.dart';
import 'package:mstream_music/objects/server.dart';

Server _server() => Server('http://music.example', null, null, 'JWT', 'home');

DisplayItem _song(Server s, String path,
    {String? title, String? artist, String? art, int? bpm, String? key}) {
  final row = DisplayItem(s, path, 'file', path, null, null);
  row.metadata = MusicMetadata(artist, 'Stim Pack Volume one', title, null,
      null, 2019, 'h1', null, art,
      bpm: bpm, musicalKey: key);
  return row;
}

/// A mix answer row in the wire shape: lite kebab-case metadata, the path
/// without its leading slash.
Map<String, dynamic> _wireSong(String path, String title, String artist,
        {double similarity = 0.8}) =>
    {
      'filepath': path,
      'similarity': similarity,
      'metadata': {
        'title': title,
        'artist': artist,
        'album': 'Stim Pack Volume one',
        'bpm': 87,
        'musical-key': 'Bb minor',
        'album-art': 'cover.jpeg',
      },
      'genreTags': ['Hip Hop---Instrumental'],
    };

void main() {
  late Server server;
  setUp(() => server = _server());

  group('from, per kind', () {
    test('a song sends its path without the leading slash', () {
      final seed = MixSeed.song(_song(server, '/demo/Boukmanflow/Dolo.mp3',
          title: 'Dolo', artist: 'Boukmanflow', bpm: 87, key: 'Bb minor'));
      expect(seed.kind, MixSeedKind.song);
      expect(seed.from, {'song': 'demo/Boukmanflow/Dolo.mp3'});
      expect(seed.path, '/demo/Boukmanflow/Dolo.mp3',
          reason: 'the app path, which rows are counted against');
      expect(seed.title, 'Dolo');
      expect(seed.subtitle, 'Boukmanflow');
      expect(seed.bpm, 87);
      expect(seed.musicalKey, 'Bb minor');
    });

    test('a queued track sends the path its extras carry', () {
      final seed = MixSeed.queued(
          server,
          const MediaItem(
            id: 'http://music.example/media/demo/Dolo.mp3',
            title: 'Dolo',
            artist: 'Boukmanflow',
            extras: {
              'server': 'home',
              'path': '/demo/Boukmanflow/Dolo.mp3',
              'artUrl': 'http://music.example/album-art/cover.jpeg?compress=l',
              'bpm': 87,
              'musicalKey': 'Bb minor',
            },
          ));
      expect(seed.from, {'song': 'demo/Boukmanflow/Dolo.mp3'});
      expect(seed.title, 'Dolo');
      expect(seed.subtitle, 'Boukmanflow');
      expect(seed.artUrl,
          'http://music.example/album-art/cover.jpeg?compress=l');
      expect(seed.bpm, 87);
      expect(seed.musicalKey, 'Bb minor');

      // No title tag: the queue names it by its path, the banner by the
      // file's name.
      final untitled = MixSeed.queued(
          server,
          const MediaItem(
            id: 'http://music.example/media/demo/Vorbis Dream.ogg',
            title: 'demo/Vorbis Dream.ogg',
            extras: {'server': 'home', 'path': '/demo/Vorbis Dream.ogg'},
          ));
      expect(untitled.title, 'Vorbis Dream.ogg');
      expect(untitled.subtitle, isNull);
      expect(untitled.artUrl, isNull);
    });

    test("an Auto DJ pick, queued under random-songs' path (no leading "
        'slash), is the same seed', () {
      final seed = MixSeed.queued(
          server,
          const MediaItem(
            id: 'http://music.example/media/demo/Boukmanflow/Dolo.mp3',
            title: 'Dolo',
            extras: {
              'server': 'home',
              'path': 'demo/Boukmanflow/Dolo.mp3',
              'djPick': true,
            },
          ));
      expect(seed.from, {'song': 'demo/Boukmanflow/Dolo.mp3'});
      expect(seed.path, '/demo/Boukmanflow/Dolo.mp3',
          reason: 'the app path, which rows are counted against');
      final leadOnly = MixAnswer.fromServerMap(server, {
        'songs': [_wireSong('demo/Boukmanflow/Dolo.mp3', 'Dolo', 'Boukmanflow')],
      });
      expect(leadOnly.beyond(seed), isFalse,
          reason: 'the seed leading its own mix is no song like it');
    });

    test('an album sends the album-songs identity it was opened with', () {
      final album = DisplayItem(
          server, 'Stim Pack Volume one', 'album', 'Stim Pack Volume one',
          null, 'Boukmanflow · 2019')
        ..albumArtist = 'Boukmanflow'
        ..year = 2019
        ..altAlbumArt = 'cover.jpeg';
      final seed = MixSeed.album(album);
      expect(seed.kind, MixSeedKind.album);
      expect(seed.from, {
        'album': {
          'album': 'Stim Pack Volume one',
          'year': 2019,
          'album_artist': 'Boukmanflow',
        },
      });
      expect(seed.title, 'Stim Pack Volume one');
      expect(seed.subtitle, 'Boukmanflow');
      expect(seed.artUrl, contains('cover.jpeg'));
      expect(seed.bpm, isNull, reason: 'an album has no single tempo');
      expect(seed.musicalKey, isNull);
    });

    test("an album card built from tracks narrows by its track artist, and "
        "without a credit its songs' one artist names it", () {
      final card = DisplayItem(server, 'Blurred', 'album', 'Blurred', null,
          null)
        ..trackArtist = 'Sam';
      expect(MixSeed.album(card).from, {
        'album': {'album': 'Blurred', 'artist': 'Sam'},
      });
      expect(MixSeed.album(card).subtitle, 'Sam');

      final bare = DisplayItem(server, 'Blurred', 'album', 'Blurred', null,
          null);
      final songs = [
        _song(server, '/a.mp3', title: 'A', artist: 'Sam'),
        _song(server, '/b.mp3', title: 'B', artist: 'Sam'),
      ];
      expect(MixSeed.album(bare, songs: songs).subtitle, 'Sam');
      expect(
          MixSeed.album(bare, songs: [
            ...songs,
            _song(server, '/c.mp3', title: 'C', artist: 'Kim'),
          ]).subtitle,
          isNull,
          reason: 'several artists: no second line');
    });

    test('an artist and a playlist send their names, with no second line', () {
      final artist = MixSeed.artist(server, 'Boukmanflow');
      expect(artist.kind, MixSeedKind.artist);
      expect(artist.from, {'artist': 'Boukmanflow'});
      expect(artist.subtitle, isNull);
      expect(artist.artUrl, isNull);
      final playlist = MixSeed.playlist(server, 'Road trip');
      expect(playlist.kind, MixSeedKind.playlist);
      expect(playlist.from, {'playlist': 'Road trip'});
      expect(playlist.subtitle, isNull);
    });
  });

  group('the answer', () {
    test('songs become file rows on the server, in play order, with lite '
        'metadata flagged partial', () {
      final a = MixAnswer.fromServerMap(server, {
        'model': {'id': 'effnet-discogs', 'version': '1'},
        'seed': {'kind': 'song', 'members': 1, 'analyzed': 1},
        'notAnalyzed': false,
        'songs': [
          _wireSong('demo/Boukmanflow/Dolo.mp3', 'Dolo', 'Boukmanflow',
              similarity: 1),
          _wireSong('demo/ALM/Enfance.mp3', 'Enfance', 'ALM'),
          {'filepath': ''}, // dropped
          'junk', // dropped
        ],
        'short': true,
        'capped': false,
        'relaxed': ['artistCap'],
        'floor': 0.23,
        'filteredOut': false,
        'moods': {},
      });
      expect([for (final r in a.rows) r.data],
          ['/demo/Boukmanflow/Dolo.mp3', '/demo/ALM/Enfance.mp3']);
      final row = a.rows.first;
      expect(row.type, 'file');
      expect(row.server, same(server));
      expect(row.subtext, isNull, reason: 'the row draws its artist');
      expect(row.metadata?.title, 'Dolo');
      expect(row.metadata?.artist, 'Boukmanflow');
      expect(row.metadata?.bpm, 87);
      expect(row.metadata?.musicalKey, 'Bb minor');
      expect(row.metadata?.albumArt, 'cover.jpeg');
      expect(row.partialMetadata, isTrue,
          reason: 'the queue fetches the full block first');
      expect(a.notAnalyzed, isFalse);
      expect(a.filteredOut, isFalse);
      expect(a.moods, isEmpty, reason: 'the echo: no mood was asked');
    });

    test('notAnalyzed, filteredOut and a missing echo', () {
      final waiting = MixAnswer.fromServerMap(
          server, {'notAnalyzed': true, 'songs': []});
      expect(waiting.notAnalyzed, isTrue);
      expect(waiting.rows, isEmpty);
      expect(waiting.moods, isNull,
          reason: 'no scores on the server: no mood was applied');

      final emptied = MixAnswer.fromServerMap(server, {
        'notAnalyzed': false,
        'songs': [],
        'filteredOut': true,
        'moods': {'energy': 'relaxed'},
      });
      expect(emptied.filteredOut, isTrue);
      expect(emptied.moods, {'energy': 'relaxed'});

      final junk = MixAnswer.fromServerMap(server, {'songs': 'nope'});
      expect(junk.rows, isEmpty);
      expect(junk.notAnalyzed, isFalse);
      expect(junk.filteredOut, isFalse);
    });

    test('beyond the seed: a row on the seed song\'s own path does not count',
        () {
      final seed = MixSeed.song(
          _song(server, '/demo/Boukmanflow/Dolo.mp3', title: 'Dolo'));
      MixAnswer of(List<Map<String, dynamic>> songs) =>
          MixAnswer.fromServerMap(server, {'songs': songs});
      final dolo =
          _wireSong('demo/Boukmanflow/Dolo.mp3', 'Dolo', 'Boukmanflow');
      final enfance = _wireSong('demo/ALM/Enfance.mp3', 'Enfance', 'ALM');
      expect(of([]).beyond(seed), isFalse);
      expect(of([dolo]).beyond(seed), isFalse,
          reason: 'the seed leading alone is nothing similar');
      expect(of([dolo, enfance]).beyond(seed), isTrue);
      expect(of([enfance]).beyond(seed), isTrue,
          reason: 'the seed left out by a filter, songs still there');
      // Other kinds have no seed row: any row is beyond it.
      expect(of([dolo]).beyond(MixSeed.artist(server, 'Boukmanflow')),
          isTrue);
    });
  });

  group('mixPlaylistName', () {
    test('the base when it is free, else the first free number', () {
      expect(mixPlaylistName('Dolo Mix', const []), 'Dolo Mix');
      expect(mixPlaylistName('Dolo Mix', const ['Road trip']), 'Dolo Mix');
      expect(mixPlaylistName('Dolo Mix', const ['Dolo Mix']), 'Dolo Mix 2');
      expect(
          mixPlaylistName(
              'Dolo Mix', const ['Dolo Mix', 'Dolo Mix 2', 'Dolo Mix 4']),
          'Dolo Mix 3');
    });

    test('names compare exactly: accents, symbols and case are kept', () {
      expect(mixPlaylistName('Téranga Mix', const ['Teranga Mix']),
          'Téranga Mix');
      expect(mixPlaylistName('(Bonus) Bawane Mix', const []),
          '(Bonus) Bawane Mix');
      expect(mixPlaylistName('Dolo Mix', const ['dolo mix']), 'Dolo Mix');
    });
  });
}
