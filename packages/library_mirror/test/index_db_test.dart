import 'dart:io' show Platform;

import 'package:library_mirror/library_mirror.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

/// One manifest entry in the shape mStream #984 ships.
Map<String, dynamic> entry(int id, String filepath,
        {String? title, String? artist, String? album, int? track,
        int? disc, List<String> genres = const [], int? rating,
        int size = 1000, int modified = 1700000000000, String? hash,
        String? audioHash, String? art}) =>
    {
      'filepath': filepath,
      'metadata': {
        'title': title ?? 'T$id',
        'artist': artist,
        'album': album,
        'album-art': art,
        'year': 2001,
        'track': track,
        'disk': disc,
        'duration': 200.5,
        'rating': rating,
        'bpm': null,
        'musical-key': null,
        'genres': genres,
        'has-lyrics': false,
        'has-synced-lyrics': false,
        'replaygain-track': null,
      },
      'id': id,
      'file-size': size,
      'modified': modified,
      'hash': hash ?? 'f$id',
      'audio-hash': audioHash ?? 'a$id',
      'hash-v': 2,
      'format': 'flac',
      'album-id': 7,
      'artist-id': 3,
      'created-at': '2024-01-01 00:00:00',
    };

RemoteTrack rt(int id, String filepath, {String? title, String? artist,
        String? album, int? track, int? disc, List<String> genres = const []}) =>
    RemoteTrack.fromManifestEntry(entry(id, filepath,
        title: title, artist: artist, album: album, track: track, disc: disc,
        genres: genres));

LocalFile lf(String path, {String origin = LocalOrigin.manual,
        String state = LocalState.ok, String? localPath, int? verifiedAt}) =>
    LocalFile(
        server: 's', path: path, localPath: localPath ?? '/dl/media/s$path',
        state: state, origin: origin, verifiedAt: verifiedAt);

void main() {
  late LibraryIndex ix;
  setUp(() => ix = LibraryIndex.inMemory());
  tearDown(() => ix.close());

  group('schema', () {
    test('a fresh index is at kSchemaVersion with FTS5 available', () {
      final db = sqlite3.openInMemory();
      LibraryIndex.migrate(db);
      expect(db.select('PRAGMA user_version').first.columnAt(0), kSchemaVersion);
      expect(db.select("SELECT 1 FROM sqlite_master WHERE name = 'tracks_fts'"),
          isNotEmpty);
      db.close();
    });

    test('an index from a newer app is refused, not guessed at', () {
      final db = sqlite3.openInMemory();
      db.execute('PRAGMA user_version = ${kSchemaVersion + 1}');
      expect(() => LibraryIndex.migrate(db), throwsStateError);
      db.close();
    });
  });

  group('RemoteTrack.fromManifestEntry', () {
    test('reads the lite block and the kebab-cased sync fields', () {
      final t = RemoteTrack.fromManifestEntry(entry(4812, 'music/A/01.flac',
          title: 'One', artist: 'Alice', album: 'First', track: 1, disc: 2,
          genres: ['Rock'], rating: 8, art: 'aa.jpeg'));
      expect(t.id, 4812);
      expect(t.path, '/music/A/01.flac', reason: 'the app\'s leading-slash form');
      expect(t.size, 1000);
      expect(t.modified, 1700000000000);
      expect(t.hash, 'f4812');
      expect(t.audioHash, 'a4812');
      expect(t.hashV, 2);
      expect(t.albumId, 7);
      expect(t.artistId, 3);
      expect(t.art, 'aa.jpeg');
      expect(t.createdAt, '2024-01-01 00:00:00');
      expect(t.title, 'One');
      expect(t.artist, 'Alice');
      expect(t.album, 'First');
      expect(t.track, 1);
      expect(t.disc, 2);
      expect(t.year, 2001);
      expect(t.duration, 200.5);
      expect(t.format, 'flac');
      expect(t.genres, ['Rock']);
      expect(t.rating, 8);
    });

    test('a path that already has the slash is kept; nulls stay null', () {
      final t = RemoteTrack.fromManifestEntry({
        'filepath': '/x/y.mp3', 'id': 1, 'metadata': null,
      });
      expect(t.path, '/x/y.mp3');
      expect(t.title, isNull);
      expect(t.genres, isEmpty);
      expect(t.size, isNull);
    });
  });

  group('remote tracks', () {
    test('upsert is idempotent and round-trips every column', () {
      final rows = [rt(1, 'a/1.flac', genres: ['Rock', 'Pop']), rt(2, 'a/2.flac')];
      ix.upsertTracks('s', rows, 'r1');
      ix.upsertTracks('s', rows, 'r2');
      expect(ix.remoteCount('s'), 2);
      final back = ix.remoteTrack('s', '/a/1.flac')!;
      expect(back.genres, ['Rock', 'Pop']);
      expect(back.hash, 'f1');
      expect(back.duration, 200.5);
      expect(ix.remoteTracks('s').map((t) => t.id), [1, 2]);
    });

    test('the same path under a new id replaces the old row', () {
      ix.upsertTracks('s', [rt(1, 'a/1.flac')], 'r1');
      ix.upsertTracks('s', [rt(9, 'a/1.flac')], 'r2');
      expect(ix.remoteCount('s'), 1);
      expect(ix.remoteTrack('s', '/a/1.flac')!.id, 9);
    });

    test('a moved file (same id, new path) is updated in place', () {
      ix.upsertTracks('s', [rt(1, 'a/1.flac')], 'r1');
      ix.upsertTracks('s', [rt(1, 'b/1.flac')], 'r2');
      expect(ix.remoteTrack('s', '/a/1.flac'), isNull);
      expect(ix.remoteTrack('s', '/b/1.flac')!.id, 1);
    });

    test('pruneUnseen drops what the latest manifest did not list', () {
      ix.upsertTracks('s', [rt(1, 'a/1.flac'), rt(2, 'a/2.flac')], 'r1');
      ix.upsertTracks('s', [rt(1, 'a/1.flac')], 'r2');
      expect(ix.pruneUnseen('s', 'r2'), ['/a/2.flac']);
      expect(ix.remoteCount('s'), 1);
      expect(ix.pruneUnseen('s', 'r2'), isEmpty);
    });

    test('servers are isolated', () {
      ix.upsertTracks('s', [rt(1, 'a/1.flac')], 'r1');
      ix.upsertTracks('t', [rt(1, 'a/1.flac')], 'r1');
      expect(ix.remoteCount('s'), 1);
      expect(ix.pruneUnseen('t', 'zzz'), ['/a/1.flac']);
      expect(ix.remoteCount('s'), 1);
    });
  });

  group('local files', () {
    test('upsert / lookup / state / remove', () {
      ix.upsertLocal(lf('/a/1.flac'));
      expect(ix.localFile('s', '/a/1.flac')!.origin, LocalOrigin.manual);
      ix.markState('s', '/a/1.flac', LocalState.failed, error: 'boom');
      final f = ix.localFile('s', '/a/1.flac')!;
      expect(f.state, LocalState.failed);
      expect(f.error, 'boom');
      ix.removeLocal('s', '/a/1.flac');
      expect(ix.localFile('s', '/a/1.flac'), isNull);
    });

    test('batched lookups survive more paths than one IN() can hold', () {
      ix.upsertLocals([for (var i = 0; i < 1200; i++) lf('/p/$i.mp3')]);
      final all = ix.localFiles('s', [for (var i = 0; i < 1500; i++) '/p/$i.mp3']);
      expect(all.length, 1200);
      expect(all['/p/1199.mp3']!.localPath, p.normalize('/dl/media/s/p/1199.mp3'),
          reason: 'stored in the host\'s native form');
    });

    test('a deleted file or folder is forgotten by its on-disk path', () {
      ix.upsertLocals([
        lf('/a/1.flac', localPath: '/dl/media/s/a/1.flac'),
        lf('/a/2.flac', localPath: '/dl/media/s/a/2.flac'),
        lf('/ab/3.flac', localPath: '/dl/media/s/ab/3.flac'),
      ]);
      ix.removeLocalByLocalPath('s', '/dl/media/s/a/1.flac');
      expect(ix.localCount('s'), 2);
      ix.removeLocalUnder('s', '/dl/media/s/a');
      expect(ix.localCount('s'), 1, reason: '/ab is not under /a');
      expect(ix.localFile('s', '/ab/3.flac'), isNotNull);
      // Mixed separators (how the app builds download paths on Windows) and
      // server-agnostic removal both resolve through normalisation.
      ix.upsertLocal(lf('/w/4.flac', localPath: '/dl/media/s\\w/4.flac'));
      ix.removeLocalUnder(null, '/dl/media/s/w/');
      expect(ix.localFile('s', '/w/4.flac'), Platform.isWindows ? isNull : isNotNull,
          reason: 'a backslash is a separator only on Windows');
      ix.removeLocalByLocalPath(null, '/dl/media/s/ab/3.flac');
      expect(ix.localFile('s', '/ab/3.flac'), isNull);
    });

    test('setOrigin promotes only the origin it is told to', () {
      ix.upsertLocals([lf('/a', origin: LocalOrigin.auto), lf('/m', origin: LocalOrigin.mirror)]);
      ix.setOrigin('s', '/a', LocalOrigin.manual, ifOrigin: LocalOrigin.auto);
      ix.setOrigin('s', '/m', LocalOrigin.manual, ifOrigin: LocalOrigin.auto);
      expect(ix.localFile('s', '/a')!.origin, LocalOrigin.manual);
      expect(ix.localFile('s', '/m')!.origin, LocalOrigin.mirror);
      ix.setOrigin('s', '/m', LocalOrigin.external);
      expect(ix.localFile('s', '/m')!.origin, LocalOrigin.external);
    });

    test('counts and origin ordering', () {
      ix.upsertLocals([
        lf('/x', origin: LocalOrigin.auto, verifiedAt: 30),
        lf('/y', origin: LocalOrigin.auto, verifiedAt: 10),
        lf('/z', origin: LocalOrigin.mirror, verifiedAt: 20),
      ]);
      expect(ix.localCount('s'), 3);
      expect(ix.localCount('s', origin: LocalOrigin.auto), 2);
      expect(ix.localByOrigin('s', LocalOrigin.auto).map((f) => f.path), ['/y', '/x']);
    });
  });

  group('subscriptions', () {
    test('required-by edges count enabled rules and die with their rule', () {
      final album = ix.addSubscription(
          const Subscription(server: 's', kind: 'album', key: 'First'));
      final list = ix.addSubscription(
          const Subscription(server: 's', kind: 'playlist', key: 'p1'));
      ix.setSubscriptionFiles(album, 's', ['/a/1', '/a/2']);
      ix.setSubscriptionFiles(list, 's', ['/a/2', '/b/9']);
      expect(ix.requiredBy('s', '/a/2'), 2);
      expect(ix.requiredBy('s', '/b/9'), 1);
      expect(ix.wantedPaths('s'), {'/a/1', '/a/2', '/b/9'});
      ix.removeSubscription(list);
      expect(ix.requiredBy('s', '/a/2'), 1);
      expect(ix.wantedPaths('s'), {'/a/1', '/a/2'});
      expect(ix.subscriptionsFor('s').single.id, album);
    });

    test('re-adding a rule re-enables it under the same id', () {
      final id = ix.addSubscription(
          const Subscription(server: 's', kind: 'album', key: 'First'));
      expect(ix.addSubscription(
          const Subscription(server: 's', kind: 'album', key: 'First', wifiOnly: true)),
          id);
      expect(ix.subscriptionsFor('s').single.wifiOnly, isTrue);
    });
  });

  group('runs', () {
    test('lastRun is the newest by start time', () {
      ix.recordRun(const SyncRun(server: 's', started: 10, downloaded: 1));
      ix.recordRun(const SyncRun(server: 's', started: 20, trashed: 2, error: 'x'));
      final last = ix.lastRun('s')!;
      expect(last.started, 20);
      expect(last.trashed, 2);
      expect(last.error, 'x');
      expect(ix.lastRun('nobody'), isNull);
    });
  });

  group('offline browse', () {
    setUp(() {
      ix.upsertTracks('s', [
        rt(1, 'A/First/02.flac', title: 'Second song', artist: 'Alice', album: 'First', track: 2, disc: 1),
        rt(2, 'A/First/01.flac', title: 'Opening', artist: 'Alice', album: 'First', track: 1, disc: 1),
        rt(3, 'A/First/d2.flac', title: 'Bonus', artist: 'Alice', album: 'First', track: 1, disc: 2),
        rt(4, 'B/Other/x.mp3', title: 'Élan vital', artist: 'Bob', album: 'Other', track: 1),
      ], 'r1');
      ix.replaceAlbums('s', const [
        AlbumRow(name: 'Other', albumArtist: 'Bob'),
        AlbumRow(name: 'First', albumArtist: 'Alice', year: 2001, art: 'aa.jpeg'),
      ]);
      ix.replaceArtists('s', ['bob', 'Alice']);
    });

    test('albums and artists come back sorted, case-insensitively', () {
      expect(ix.albums('s').map((a) => a.name), ['First', 'Other']);
      expect(ix.albums('s').first.art, 'aa.jpeg');
      expect(ix.artists('s'), ['Alice', 'bob']);
    });

    test('album songs are in disc / track order', () {
      expect(ix.albumSongs('s', 'First').map((t) => t.title),
          ['Opening', 'Second song', 'Bonus']);
      expect(ix.albumSongs('s', 'nope'), isEmpty);
    });

    test('search is a quoted prefix match per term, diacritic-folded', () {
      expect(ix.search('s', 'sec').map((t) => t.id), [1]);
      expect(ix.search('s', 'alice fir').map((t) => t.id), unorderedEquals([1, 2, 3]));
      expect(ix.search('s', 'elan').map((t) => t.id), [4]);
      expect(ix.search('s', 'x.mp3').map((t) => t.id), [4]);
      expect(ix.search('s', '"AND" OR (bad'), isEmpty, reason: 'FTS syntax is inert');
      expect(ix.search('s', '   '), isEmpty);
      expect(ix.search('other-server', 'sec'), isEmpty);
    });

    test('search follows updates and deletes (the FTS triggers)', () {
      ix.upsertTracks('s', [rt(1, 'A/First/02.flac', title: 'Renamed', album: 'First')], 'r2');
      expect(ix.search('s', 'second'), isEmpty);
      expect(ix.search('s', 'renam').map((t) => t.id), [1]);
      ix.pruneUnseen('s', 'r2');
      expect(ix.search('s', 'opening'), isEmpty);
    });
  });

  test('removeServer drops everything, including what search can see', () {
    ix.upsertTracks('s', [rt(1, 'a/1.flac', title: 'Keep me')], 'r1');
    ix.upsertTracks('t', [rt(1, 'a/1.flac', title: 'Keep me')], 'r1');
    ix.upsertLocal(lf('/a/1.flac'));
    ix.setMeta('s', 'revision', 'r1');
    final sub = ix.addSubscription(const Subscription(server: 's', kind: 'library', key: 'a'));
    ix.setSubscriptionFiles(sub, 's', ['/a/1.flac']);
    ix.recordRun(const SyncRun(server: 's', started: 1));
    ix.removeServer('s');
    expect(ix.remoteCount('s'), 0);
    expect(ix.localCount('s'), 0);
    expect(ix.meta('s', 'revision'), isNull);
    expect(ix.subscriptionsFor('s'), isEmpty);
    expect(ix.lastRun('s'), isNull);
    expect(ix.search('s', 'keep'), isEmpty);
    expect(ix.search('t', 'keep').single.id, 1, reason: 'the other server is untouched');
  });

  test('meta is per server and overwrites', () {
    ix.setMeta('s', 'revision', 'r1');
    ix.setMeta('s', 'revision', 'r2');
    expect(ix.meta('s', 'revision'), 'r2');
    expect(ix.meta('t', 'revision'), isNull);
  });
}
