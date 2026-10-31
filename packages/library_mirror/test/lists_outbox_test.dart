import 'package:library_mirror/library_mirror.dart';
import 'package:library_mirror/src/schema.dart' show upgradeStatements;
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

RemoteTrack rt(int id, String path,
        {String? title,
        String? artist,
        String? album,
        int? rating,
        String? createdAt}) =>
    RemoteTrack(
        id: id,
        path: path,
        size: 1,
        modified: 1,
        hash: 'h$id',
        title: title,
        artist: artist,
        album: album,
        rating: rating,
        createdAt: createdAt);

void main() {
  late LibraryIndex ix;
  setUp(() => ix = LibraryIndex.inMemory());
  tearDown(() => ix.close());

  test('a v1 index gains the outbox on open', () {
    final db = sqlite3.openInMemory();
    for (final s in upgradeStatements(0, to: 1)) {
      db.execute(s);
    }
    db.execute('PRAGMA user_version = 1');
    expect(db.select("SELECT 1 FROM sqlite_master WHERE name = 'outbox'"), isEmpty);
    LibraryIndex.migrate(db);
    expect(db.select('PRAGMA user_version').first.columnAt(0), 2);
    expect(db.select("SELECT 1 FROM sqlite_master WHERE name = 'outbox'"), isNotEmpty);
    db.close();
  });

  group('lists', () {
    setUp(() {
      ix.upsertTracks('s', [
        rt(1, '/m/a.mp3', title: 'A', artist: 'Ann', album: 'One', rating: 4,
            createdAt: '2026-01-01T00:00:00Z'),
        rt(2, '/m/b.mp3', title: 'B', artist: 'Bob', album: 'Two',
            createdAt: '2026-03-01T00:00:00Z'),
        rt(3, '/m/c.mp3', title: 'C', artist: 'Ann', album: 'One',
            createdAt: '2026-02-01T00:00:00Z'),
      ], 'r1');
      ix.replaceArtists('s', ['Ann', 'Bob', 'Annie %']);
      ix.replaceAlbums('s', const [
        AlbumRow(name: 'One'),
        AlbumRow(name: 'Two'),
        AlbumRow(name: 'one_x'),
      ]);
    });

    test('genres, playlists and their slots (an unknown path keeps its slot)',
        () {
      ix.replaceGenres('s', {'Rock': 2, 'Ambient': 1});
      expect(ix.genres('s').map((g) => (g.name, g.trackCount)),
          [('Ambient', 1), ('Rock', 2)]);
      ix.replacePlaylists('s', const [
        PlaylistRow(
            id: 'Mix', name: 'Mix', paths: ['/m/b.mp3', '/m/gone.mp3', '/m/a.mp3']),
        PlaylistRow(id: 'Empty', name: 'Empty'),
      ]);
      expect(ix.playlists('s').map((p) => p.name), ['Empty', 'Mix']);
      final items = ix.playlistItems('s', 'Mix');
      expect(items.map((i) => i.path), ['/m/b.mp3', '/m/gone.mp3', '/m/a.mp3']);
      expect(items[0].track!.title, 'B');
      expect(items[1].track, isNull);
      expect(items[2].pos, 2);
      expect(ix.playlistItems('s', 'Empty'), isEmpty);
    });

    test('rated: best first, the rated list wins over the lite block', () {
      ix.replaceRated('s', {'/m/a.mp3': 8, '/m/c.mp3': 10, '/m/zzz.mp3': 6});
      final rows = ix.rated('s');
      expect(rows.map((t) => t.path), ['/m/c.mp3', '/m/a.mp3']);
      expect(rows.last.rating, 8, reason: "not the manifest's 4");
    });

    test('recent: newest first by created_at then id', () {
      expect(ix.recent('s').map((t) => t.path), ['/m/b.mp3', '/m/c.mp3', '/m/a.mp3']);
      expect(ix.recent('s', limit: 1).single.path, '/m/b.mp3');
    });

    test('artists / albums matching a substring, LIKE wildcards escaped', () {
      expect(ix.artistsMatching('s', 'an'), ['Ann', 'Annie %']);
      expect(ix.artistsMatching('s', '%'), ['Annie %']);
      expect(ix.albumsMatching('s', 'one').map((a) => a.name), ['One', 'one_x']);
      expect(ix.albumsMatching('s', '_x').map((a) => a.name), ['one_x']);
      expect(ix.albumsMatching('s', 't_o'), isEmpty, reason: '_ is literal, so no Two');
    });

    test("the caller's own writes: rating and playlist edits", () {
      ix.setRating('s', '/m/b.mp3', 9);
      expect(ix.rated('s').single.path, '/m/b.mp3');
      expect(ix.remoteTrack('s', '/m/b.mp3')!.rating, 9);
      ix.setRating('s', '/m/b.mp3', 0);
      expect(ix.rated('s'), isEmpty);
      expect(ix.remoteTrack('s', '/m/b.mp3')!.rating, isNull);

      ix.addPlaylistItem('s', 'New', '/m/a.mp3');
      ix.addPlaylistItem('s', 'New', '/m/b.mp3');
      expect(ix.playlists('s').single.name, 'New');
      expect(ix.playlistItems('s', 'New').map((i) => i.path),
          ['/m/a.mp3', '/m/b.mp3']);
      ix.savePlaylist('s', 'New', ['/m/c.mp3']);
      expect(ix.playlistItems('s', 'New').map((i) => i.path), ['/m/c.mp3']);
      ix.renamePlaylist('s', 'New', 'Newer');
      expect(ix.playlists('s').single.id, 'Newer');
      expect(ix.playlistItems('s', 'Newer').single.path, '/m/c.mp3');
      ix.createPlaylist('s', 'Newer'); // already there: no-op
      ix.deletePlaylist('s', 'Newer');
      expect(ix.playlists('s'), isEmpty);
      expect(ix.playlistItems('s', 'Newer'), isEmpty);
    });
  });

  test('outbox: in order, done removes, failed counts, removeServer clears', () {
    final a = ix.enqueue('s', 'rate', {'filepath': 'm/a.mp3', 'rating': 8},
        created: 1);
    final b = ix.enqueue('s', 'playlist-add', {'playlist': 'Mix', 'song': 'm/b.mp3'},
        created: 2);
    ix.enqueue('other', 'rate', {'filepath': 'x', 'rating': 1}, created: 3);
    expect(ix.outboxCount('s'), 2);
    final rows = ix.outbox('s');
    expect(rows.map((e) => e.id), [a, b]);
    expect(rows.first.payload, {'filepath': 'm/a.mp3', 'rating': 8});
    expect(rows.first.created, 1);
    ix.outboxFailed(b, 'boom');
    expect(ix.outbox('s').last.attempts, 1);
    expect(ix.outbox('s').last.lastError, 'boom');
    ix.outboxDone(a);
    expect(ix.outbox('s').map((e) => e.op), ['playlist-add']);
    ix.removeServer('s');
    expect(ix.outboxCount('s'), 0);
    expect(ix.outboxCount('other'), 1);
  });
}
