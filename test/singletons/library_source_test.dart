import 'package:flutter_test/flutter_test.dart';
import 'package:library_mirror/library_mirror.dart';
import 'package:material_ui/material_ui.dart' show Icons;

import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/library_source.dart';
import 'package:mstream_music/singletons/settings.dart';

RemoteTrack rt(int id, String path,
        {String? title, String? artist, String? album, int? track, int? disc,
        String? art, List<String> genres = const []}) =>
    RemoteTrack(id: id, path: path, size: 1000 + id, modified: 1, hash: 'h$id',
        audioHash: 'a$id', title: title, artist: artist, album: album, track: track,
        disc: disc, year: 2001, duration: 200.5, format: 'flac', art: art,
        genres: genres, rating: id == 1 ? 8 : null);

void main() {
  late LibraryIndex ix;
  late LocalLibrarySource src;
  final server = Server('http://h', null, null, null, 'home');

  setUp(() {
    ix = LibraryIndex.inMemory();
    src = LocalLibrarySource(ix);
    ix.upsertTracks('home', [
      rt(1, '/music/Alice/First/01.flac', title: 'Opening', artist: 'Alice', album: 'First', track: 1, disc: 1, art: 'aa.jpeg', genres: ['Rock']),
      rt(2, '/music/Alice/First/02.flac', title: 'Second', artist: 'Alice', album: 'First', track: 2, disc: 1, art: 'aa.jpeg'),
      rt(3, '/music/Bob/Other/x.mp3', title: 'X', artist: 'Bob', album: 'Other', track: 1),
      rt(4, '/music/Bob/Other/list.m3u', title: 'L', artist: 'Bob', album: 'Other'),
    ], 'r1');
    ix.replaceAlbums('home', const [
      AlbumRow(name: 'First', albumArtist: 'Alice', year: 2001, art: 'aa.jpeg'),
      AlbumRow(name: 'Other', albumArtist: 'Bob'),
    ]);
    ix.replaceArtists('home', ['Alice', 'Bob']);
  });
  tearDown(() => ix.close());

  test('albums carry the same type / data / subtitle / art as the server rows', () async {
    final rows = await src.albums(server);
    expect(rows.map((r) => r.name), ['First', 'Other']);
    final first = rows.first;
    expect(first.type, 'album');
    expect(first.data, 'First');
    expect(first.subtext, 'Alice · 2001');
    expect(first.altAlbumArt, 'aa.jpeg');
    expect(first.server, same(server));
    expect(rows.last.subtext, 'Bob', reason: 'no year, no separator');
  });

  test('artists and their albums', () async {
    final artists = await src.artists(server);
    expect(artists.map((r) => (r.type, r.data)), [('artist', 'Alice'), ('artist', 'Bob')]);
    final albums = await src.artistAlbums(server, 'Alice');
    expect(albums.single.name, 'First');
    expect(albums.single.subtext, '2001');
    expect((await src.artistAlbums(server, 'Bob')).single.subtext, '');
  });

  test('album songs are file rows with full metadata, in track order', () async {
    final songs = await src.albumSongs(server, 'First');
    expect(songs.map((r) => r.name), ['music/Alice/First/01.flac', 'music/Alice/First/02.flac']);
    final s = songs.first;
    expect(s.type, 'file');
    expect(s.data, '/music/Alice/First/01.flac');
    final m = s.metadata!;
    expect(m.title, 'Opening');
    expect(m.artist, 'Alice');
    expect(m.album, 'First');
    expect(m.track, 1);
    expect(m.albumArt, 'aa.jpeg');
    expect(m.hash, 'h1');
    expect(m.rating, 8);
    expect(m.genres, ['Rock']);
    expect(m.durationSeconds, 200.5);
    expect(await src.albumSongs(server, null), isEmpty);
  });

  test('the file explorer walks the paths: root, folders, files, the m3u icon', () async {
    final root = await src.fileList(server, '~');
    expect(root.path, '/');
    expect(root.items.map((r) => (r.type, r.name, r.data)), [('directory', 'music', '/music')]);

    final alice = await src.fileList(server, '/music/Alice');
    expect(alice.path, '/music/Alice/');
    expect(alice.items.single.data, '/music/Alice/First');

    final other = await src.fileList(server, '/music/Bob/Other/');
    expect(other.items.map((r) => (r.type, r.name)), [('file', 'list.m3u'), ('file', 'x.mp3')]);
    expect(other.items.last.metadata!.title, 'X');
    expect(other.items.first.icon!.icon, Icons.queue_music);
    expect(other.items.last.icon!.icon, Icons.music_note);
    expect((await src.fileList(server, '/nope')).items, isEmpty);
  });

  test('recursive tracks: paths with the slash, metadata keyed without it', () async {
    final (paths, meta) = await src.recursiveTracks(server, '/music/Alice');
    expect(paths, ['/music/Alice/First/01.flac', '/music/Alice/First/02.flac']);
    expect(meta['music/Alice/First/02.flac']!.title, 'Second');
    expect((await src.recursiveTracks(server, '~')).$1.length, 4);
  });

  test('LocalLibrarySource.dirPath normalises the explorer root marker', () {
    expect(LocalLibrarySource.dirPath('~'), '/');
    expect(LocalLibrarySource.dirPath(''), '/');
    expect(LocalLibrarySource.dirPath('/a'), '/a/');
    expect(LocalLibrarySource.dirPath('/a/'), '/a/');
  });

  test("playlists, and a playlist's slots (a gone file keeps its slot)", () async {
    ix.replacePlaylists('home', const [
      PlaylistRow(id: 'Mix', name: 'Mix',
          paths: ['/music/Bob/Other/x.mp3', '/music/gone.mp3']),
    ]);
    final lists = await src.playlists(server);
    expect(lists.single.type, 'playlist');
    expect(lists.single.data, 'Mix');
    expect(lists.single.icon!.icon, Icons.queue_music);
    final rows = await src.playlistContents(server, 'Mix');
    expect(rows.map((r) => (r.type, r.data)),
        [('file', '/music/Bob/Other/x.mp3'), ('file', '/music/gone.mp3')]);
    expect(rows.first.metadata!.title, 'X');
    expect(rows.last.metadata, isNull);
    expect(rows.last.name, 'music/gone.mp3');
    expect(await src.playlistContents(server, 'nope'), isEmpty);
  });

  test('rated rows: best first, artist as the subtitle', () async {
    ix.replaceRated('home',
        {'/music/Alice/First/02.flac': 6, '/music/Bob/Other/x.mp3': 9});
    final rows = await src.rated(server);
    expect(rows.map((r) => r.data),
        ['/music/Bob/Other/x.mp3', '/music/Alice/First/02.flac']);
    expect(rows.first.subtext, 'Bob');
    expect(rows.first.metadata!.rating, 9);
  });

  test('recent lists the newest additions first (id order without dates)',
      () async {
    final rows = await src.recent(server);
    expect(rows.map((r) => r.data).first, '/music/Bob/Other/list.m3u');
    expect(rows, hasLength(4));
    expect(rows.first.metadata!.title, 'L');
  });

  test('search groups artists, albums and tracks per the ticked categories',
      () async {
    final before = SettingsManager().searchCategories;
    try {
      SettingsManager().searchCategories = {
        SearchCategory.artists, SearchCategory.albums, SearchCategory.songs,
      };
      final rows = await src.search(server, 'ali');
      expect(rows.first.type, 'artist');
      expect(rows.first.data, 'Alice');
      expect(rows.skip(1).map((r) => r.data), unorderedEquals(
          ['/music/Alice/First/01.flac', '/music/Alice/First/02.flac']));
      expect(rows.last.metadata!.title, isNotNull, reason: 'full metadata');
      expect(rows.last.partialMetadata, isFalse);

      final byAlbum = await src.search(server, 'fir');
      expect(byAlbum.first.type, 'album');
      expect(byAlbum.first.data, 'First');
      expect(byAlbum.first.altAlbumArt, 'aa.jpeg');

      SettingsManager().searchCategories = {SearchCategory.albums};
      expect(await src.search(server, 'ali'), isEmpty);
    } finally {
      SettingsManager().searchCategories = before;
    }
  });
}
