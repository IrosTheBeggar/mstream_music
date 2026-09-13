import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:library_mirror/library_mirror.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// A server library: data path → (bytes, mtime ms). The revision is whatever
/// the test says it is, like the real one it only has to change when the
/// library does.
class FakeServer {
  final Map<String, (List<int>, int)> files = {};
  final Map<String, ({String? album, String? artist})> tags = {};
  String revision = 'r1';
  bool scanning = false;
  int nextId = 1;
  final Map<String, int> ids = {};

  void put(String path, String body,
      {int mtime = 1700000000000, String? album, String? artist}) {
    files[path] = (utf8.encode(body), mtime);
    ids.putIfAbsent(path, () => nextId++);
    if (album != null || artist != null) tags[path] = (album: album, artist: artist);
  }

  RemoteTrack entry(String path) {
    final (bytes, mtime) = files[path]!;
    final t = tags[path];
    return RemoteTrack(
        id: ids[path]!, path: path, size: bytes.length, modified: mtime,
        hash: md5.convert(bytes).toString(), hashV: 2, title: p.basename(path),
        album: t?.album, artist: t?.artist);
  }
}

class FakeManifest implements ManifestClient {
  final FakeServer server;
  int calls = 0;
  FakeManifest(this.server);

  @override
  Future<ManifestPage?> fetchPage({int? cursor, int limit = 2000, String? ifNoneMatch}) async {
    calls++;
    if (cursor == null && ifNoneMatch == server.revision) return null;
    final all = (server.files.keys.map(server.entry).toList()..sort((a, b) => a.id.compareTo(b.id)));
    final rows = all.where((t) => t.id > (cursor ?? 0)).take(limit).toList();
    final more = all.any((t) => rows.isNotEmpty && t.id > rows.last.id);
    return ManifestPage(revision: server.revision, scanning: server.scanning,
        next: more ? rows.last.id : null, entries: rows);
  }
}

class FakeDownloader implements Downloader {
  final FakeServer server;
  final List<String> calls = [];
  final Set<String> failFor = {};
  final Set<String> corruptFor = {};
  FakeDownloader(this.server);

  @override
  Future<void> download(String path, String destination, {bool requiresWiFi = false}) async {
    calls.add(path);
    if (failFor.contains(path)) throw const SocketException('boom');
    final (bytes, _) = server.files[path]!;
    await File(destination).writeAsBytes(corruptFor.contains(path) ? [...bytes, 0] : bytes);
  }
}

void main() {
  late Directory tmp;
  late LibraryIndex ix;
  late FakeServer srv;
  late FakeManifest manifest;
  late FakeDownloader dl;
  late MirrorConfig cfg;
  DateTime clock = DateTime(2026, 9, 12, 12);

  MirrorRunner runner({Future<int?> Function(String)? freeSpace}) => MirrorRunner(
      index: ix, manifest: manifest, downloader: dl, freeSpace: freeSpace, now: () => clock);

  String local(String path) => cfg.localPathFor(path);
  String read(String path) => File(local(path)).readAsStringSync();

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('mirror_runner_');
    ix = LibraryIndex.inMemory();
    srv = FakeServer()
      ..put('/music/A/1.mp3', 'one')
      ..put('/music/A/2.mp3', 'two')
      ..put('/music/B/3.mp3', 'three');
    manifest = FakeManifest(srv);
    dl = FakeDownloader(srv);
    cfg = MirrorConfig.under(tmp.path, 's', concurrency: 2, pageSize: 2);
    ix.addSubscription(const Subscription(server: 's', kind: 'library', key: 'music'));
  });
  tearDown(() {
    ix.close();
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('a first run mirrors the library: verified, stamped, indexed, recorded', () async {
    final run = await runner().run(cfg, trigger: 'test');
    expect(run.error, isNull);
    expect(run.downloaded, 3);
    expect(run.failed, 0);
    expect(run.bytes, 3 + 3 + 5);
    expect(read('/music/A/1.mp3'), 'one');
    expect(read('/music/B/3.mp3'), 'three');
    final row = ix.localFile('s', '/music/A/1.mp3')!;
    expect(row.origin, LocalOrigin.mirror);
    expect(row.state, LocalState.ok);
    expect(row.hash, md5.convert(utf8.encode('one')).toString());
    expect(row.size, 3);
    expect(p.equals(row.localPath, local('/music/A/1.mp3')), isTrue);
    final stamped = File(local('/music/A/1.mp3')).lastModifiedSync().millisecondsSinceEpoch;
    expect((stamped - 1700000000000).abs(), lessThan(2000), reason: 'server mtime stamped');
    expect(ix.meta('s', 'revision'), 'r1');
    expect(ix.remoteCount('s'), 3);
    expect(manifest.calls, 2, reason: 'two pages of two');
    expect(ix.lastRun('s')!.trigger, 'test');
    expect(ix.requiredBy('s', '/music/A/1.mp3'), 1);
    expect(Directory(cfg.tmpRoot).existsSync(), isFalse, reason: 'temp tree purged');
  });

  test('an unchanged server is one 304 and no transfers; a new rule still acts on it', () async {
    await runner().run(cfg);
    dl.calls.clear();
    final again = await runner().run(cfg);
    expect(again.downloaded, 0);
    expect(again.unchanged, 3);
    expect(dl.calls, isEmpty);

    // A folder rule for a path the library rule already covers changes nothing;
    // drop the library rule and add a folder rule for /music/A only.
    for (final s in ix.subscriptionsFor('s')) {
      ix.removeSubscription(s.id!);
    }
    ix.addSubscription(const Subscription(server: 's', kind: 'folder', key: '/music/A'));
    final narrowed = await runner().run(cfg);
    expect(narrowed.trashed, 1, reason: '/music/B/3.mp3 is no longer wanted');
    expect(File(local('/music/B/3.mp3')).existsSync(), isFalse);
    expect(ix.localFile('s', '/music/B/3.mp3'), isNull);
    expect(ix.localCount('s'), 2);
  });

  test('a server-side deletion lands in a dated trash bucket; a scan in progress defers it', () async {
    await runner().run(cfg);
    srv.files.remove('/music/A/2.mp3');
    srv.revision = 'r2';
    srv.scanning = true;
    final deferred = await runner().run(cfg);
    expect(deferred.trashed, 0);
    expect(File(local('/music/A/2.mp3')).existsSync(), isTrue);

    srv.scanning = false;
    srv.revision = 'r3';
    final run = await runner().run(cfg);
    expect(run.trashed, 1);
    expect(File(local('/music/A/2.mp3')).existsSync(), isFalse);
    final trashed = File(p.join(cfg.trashRoot, '2026-09-12', 'music', 'A', '2.mp3'));
    expect(trashed.existsSync(), isTrue);
    expect(trashed.readAsStringSync(), 'two');
    expect(ix.localFile('s', '/music/A/2.mp3'), isNull);
    expect(ix.remoteCount('s'), 2);
  });

  test('a changed file is replaced; the old copy goes to the trash first', () async {
    await runner().run(cfg);
    srv.put('/music/A/1.mp3', 'one-v2', mtime: 1700000009000);
    srv.revision = 'r2';
    final run = await runner().run(cfg);
    expect(run.replaced, 1);
    expect(run.downloaded, 0);
    expect(read('/music/A/1.mp3'), 'one-v2');
    expect(File(p.join(cfg.trashRoot, '2026-09-12', 'music', 'A', '1.mp3')).readAsStringSync(), 'one');
    expect(ix.localFile('s', '/music/A/1.mp3')!.size, 6);
  });

  test('a rename on the server is a local move, not a transfer', () async {
    await runner().run(cfg);
    final moved = srv.files.remove('/music/A/2.mp3')!;
    srv.files['/music/C/2.mp3'] = moved;
    srv.ids['/music/C/2.mp3'] = srv.nextId++;
    srv.revision = 'r2';
    dl.calls.clear();
    final run = await runner().run(cfg);
    expect(run.renamed, 1);
    expect(dl.calls, isEmpty);
    expect(read('/music/C/2.mp3'), 'two');
    expect(File(local('/music/A/2.mp3')).existsSync(), isFalse);
    expect(ix.localFile('s', '/music/A/2.mp3'), isNull);
    expect(ix.localFile('s', '/music/C/2.mp3')!.origin, LocalOrigin.mirror);
  });

  test('a manual download is never trashed, and a matching one is not re-fetched', () async {
    final manualPath = local('/music/A/1.mp3');
    File(manualPath).createSync(recursive: true);
    File(manualPath).writeAsStringSync('one');
    ix.upsertLocal(LocalFile(server: 's', path: '/music/A/1.mp3', localPath: manualPath,
        state: LocalState.ok, origin: LocalOrigin.manual, size: 3, mtime: 1700000000000));
    ix.upsertLocal(LocalFile(server: 's', path: '/music/A/user.mp3',
        localPath: local('/music/A/user.mp3'), state: LocalState.ok, origin: LocalOrigin.manual));
    final run = await runner().run(cfg);
    expect(run.downloaded, 2, reason: 'only the two the user did not already have');
    expect(dl.calls, isNot(contains('/music/A/1.mp3')));
    expect(run.trashed, 0);
    expect(ix.localFile('s', '/music/A/user.mp3')!.origin, LocalOrigin.manual);
  });

  test('pre-existing copies are adopted after verification, or replaced when the bytes differ', () async {
    // Two imported rows (no hash, landing-time mtime): one genuine, one a
    // same-size file with other bytes.
    final good = local('/music/A/1.mp3');
    File(good).createSync(recursive: true);
    File(good).writeAsStringSync('one');
    final bad = local('/music/A/2.mp3');
    File(bad).writeAsStringSync('tw0');
    for (final (path, lp) in [('/music/A/1.mp3', good), ('/music/A/2.mp3', bad)]) {
      ix.upsertLocal(LocalFile(server: 's', path: path, localPath: lp, state: LocalState.ok,
          origin: LocalOrigin.manual, size: 3, mtime: 1234567890000));
    }
    final run = await runner().run(cfg);
    expect(run.downloaded, 1, reason: '/music/B/3.mp3 only');
    expect(run.replaced, 1, reason: 'the corrupted one');
    expect(run.unchanged, 1, reason: 'the adopted one');
    expect(dl.calls, isNot(contains('/music/A/1.mp3')));
    final adopted = ix.localFile('s', '/music/A/1.mp3')!;
    expect(adopted.origin, LocalOrigin.manual, reason: 'ownership is kept');
    expect(adopted.hash, md5.convert(utf8.encode('one')).toString());
    expect(adopted.mtime, 1700000000000);
    expect((File(good).lastModifiedSync().millisecondsSinceEpoch - 1700000000000).abs(), lessThan(2000));
    expect(read('/music/A/2.mp3'), 'two');
    expect(ix.localFile('s', '/music/A/2.mp3')!.origin, LocalOrigin.manual,
        reason: 'a replace keeps the row\'s origin too');

    // The next run compares like any other row: nothing to do.
    dl.calls.clear();
    final again = await runner().run(cfg);
    expect(dl.calls, isEmpty);
    expect(again.unchanged, 3);
  });

  test('per-file failures are counted and recorded, never fatal; temp files are cleaned up', () async {
    dl.failFor.add('/music/A/1.mp3');
    dl.corruptFor.add('/music/A/2.mp3');
    final run = await runner().run(cfg);
    expect(run.error, isNull);
    expect(run.failed, 2);
    expect(run.downloaded, 1);
    final f1 = ix.localFile('s', '/music/A/1.mp3')!;
    expect(f1.state, LocalState.failed);
    expect(f1.error, contains('boom'));
    final f2 = ix.localFile('s', '/music/A/2.mp3')!;
    expect(f2.state, LocalState.failed);
    expect(f2.error, contains('size mismatch'));
    expect(File(local('/music/A/2.mp3')).existsSync(), isFalse);
    expect(Directory(cfg.tmpRoot).existsSync(), isFalse);

    // The next run retries them.
    dl.failFor.clear();
    dl.corruptFor.clear();
    final retry = await runner().run(cfg);
    expect(retry.downloaded, 2);
    expect(ix.localFile('s', '/music/A/1.mp3')!.state, LocalState.ok);
  });

  test('a checksum mismatch with the right size is caught', () async {
    // Same length, different bytes: only the MD5 can tell.
    srv.put('/music/A/1.mp3', 'one');
    await runner().run(cfg);
    srv.files['/music/A/1.mp3'] = (utf8.encode('uno'), 1700000000000);
    // The manifest still advertises the OLD hash for this path (the server
    // is lying / a mid-write race); the downloaded bytes will not match.
    final lying = _LyingManifest(srv, '/music/A/1.mp3', md5.convert(utf8.encode('one')).toString());
    srv.revision = 'r2';
    final run = await MirrorRunner(index: ix, manifest: lying, downloader: dl, now: () => clock).run(cfg);
    expect(run.failed, 0, reason: 'size and mtime agree with the row, so nothing is planned');
    // Force a re-fetch by marking the row stale.
    ix.markState('s', '/music/A/1.mp3', LocalState.stale);
    final refetch = await MirrorRunner(index: ix, manifest: lying, downloader: dl, now: () => clock).run(cfg);
    expect(refetch.failed, 1);
    expect(ix.localFile('s', '/music/A/1.mp3')!.error, contains('checksum'));
  });

  test('trash buckets older than the retention are swept; 0 keeps forever', () async {
    final old = Directory(p.join(cfg.trashRoot, '2026-08-01'))..createSync(recursive: true);
    final recent = Directory(p.join(cfg.trashRoot, '2026-09-01'))..createSync(recursive: true);
    final junk = Directory(p.join(cfg.trashRoot, 'not-a-date'))..createSync(recursive: true);
    await runner().run(cfg);
    expect(old.existsSync(), isFalse);
    expect(recent.existsSync(), isTrue);
    expect(junk.existsSync(), isTrue);

    final forever = MirrorConfig.under(tmp.path, 's', retentionDays: 0);
    Directory(p.join(forever.trashRoot, '2020-01-01')).createSync(recursive: true);
    await runner().run(forever);
    expect(Directory(p.join(forever.trashRoot, '2020-01-01')).existsSync(), isTrue);
  });

  test('cancellation stops between files', () async {
    var stop = false;
    final run = await runner().run(cfg, isCancelled: () => stop, onProgress: (pr) {
      if (pr.phase == 'transfer') stop = true;
    });
    expect(run.error, isNull);
    expect(run.downloaded, lessThan(3));
    expect(run.downloaded, greaterThan(0));
  });

  test('preflight refuses a run that will not fit', () async {
    final run = await runner(freeSpace: (_) async => 10).run(cfg);
    expect(run.error, contains('free space'));
    expect(run.downloaded, 0);
    expect(dl.calls, isEmpty);
    final ok = await runner(freeSpace: (_) async => 1 << 30).run(cfg);
    expect(ok.downloaded, 3);
  });

  test('album and artist rules pin by tag; an artist also claims the albums credited to it', () async {
    // Start from no rule at all, then pin one album.
    ix.removeSubscription(ix.subscriptionsFor('s').single.id!);
    srv
      ..put('/music/A/1.mp3', 'one', album: 'Alpha', artist: 'Ann')
      ..put('/music/A/2.mp3', 'two', album: 'Alpha', artist: 'Guest')
      ..put('/music/B/3.mp3', 'three', album: 'Beta', artist: 'Ann')
      ..put('/music/C/4.mp3', 'four', album: 'Gamma', artist: 'Cy');
    ix.replaceAlbums('s', const [
      AlbumRow(name: 'Alpha', albumArtist: 'Ann'),
      AlbumRow(name: 'Beta', albumArtist: 'Various'),
      AlbumRow(name: 'Gamma', albumArtist: 'Cy'),
    ]);
    final album = ix.addSubscription(const Subscription(server: 's', kind: RuleKind.album, key: 'Alpha'));
    var run = await runner().run(cfg);
    expect(run.downloaded, 2);
    expect(dl.calls, unorderedEquals(['/music/A/1.mp3', '/music/A/2.mp3']));
    expect(ix.wantedPaths('s'), {'/music/A/1.mp3', '/music/A/2.mp3'});

    // The artist rule adds Beta's track by Ann; Alpha is already pinned.
    ix.addSubscription(const Subscription(server: 's', kind: RuleKind.artist, key: 'Ann'));
    dl.calls.clear();
    run = await runner().run(cfg);
    expect(run.downloaded, 1);
    expect(dl.calls, ['/music/B/3.mp3']);

    // Dropping the album rule keeps Alpha's Ann track (artist rule, and the
    // album is credited to Ann) but lets the guest track go.
    ix.removeSubscription(album);
    run = await runner().run(cfg);
    expect(run.trashed, 0, reason: 'Alpha is credited to Ann, so the artist rule still pins both');
    ix.replaceAlbums('s', const [AlbumRow(name: 'Alpha', albumArtist: 'Various')]);
    run = await runner().run(cfg);
    expect(run.trashed, 1);
    expect(ix.wantedPaths('s'), {'/music/A/1.mp3', '/music/B/3.mp3'});
  });

  test('expandRule: kinds, prefixes and an unknown kind', () {
    final remote = [
      const RemoteTrack(id: 1, path: '/music/A/1.mp3', album: 'Alpha', artist: 'Ann'),
      const RemoteTrack(id: 2, path: '/music/A/2.mp3', album: 'Alpha', artist: 'Guest'),
      const RemoteTrack(id: 3, path: '/musicals/x.mp3', album: 'Other', artist: 'Ann'),
      const RemoteTrack(id: 4, path: '/music/B/3.mp3'),
    ];
    List<String> ex(String kind, String key,
            {Set<String> credited = const {}, Set<String> members = const {}}) =>
        expandRule(Subscription(server: 's', kind: kind, key: key), remote,
            creditedAlbums: credited, memberPaths: members);
    expect(ex(RuleKind.library, 'music'), ['/music/A/1.mp3', '/music/A/2.mp3', '/music/B/3.mp3']);
    expect(ex(RuleKind.library, '/music/'), ['/music/A/1.mp3', '/music/A/2.mp3', '/music/B/3.mp3']);
    expect(ex(RuleKind.folder, '/music/A'), ['/music/A/1.mp3', '/music/A/2.mp3']);
    expect(ex(RuleKind.album, 'Alpha'), ['/music/A/1.mp3', '/music/A/2.mp3']);
    expect(ex(RuleKind.artist, 'Ann'), ['/music/A/1.mp3', '/musicals/x.mp3']);
    expect(ex(RuleKind.artist, 'Ann', credited: {'Alpha'}), ['/music/A/1.mp3', '/music/A/2.mp3', '/musicals/x.mp3']);
    expect(ex(RuleKind.playlist, 'Mix', members: {'/music/A/2.mp3', '/gone.mp3'}), ['/music/A/2.mp3'],
        reason: 'only what the manifest still lists');
    expect(ex(RuleKind.rated, '8', members: {'/music/B/3.mp3'}), ['/music/B/3.mp3']);
    expect(ex('genre', 'Rock'), isEmpty);
  });

  test('playlist and rated rules pin what the index resolves for them', () async {
    ix.removeSubscription(ix.subscriptionsFor('s').single.id!);
    ix.replacePlaylists('s', const [PlaylistRow(id: 'Mix', name: 'Mix', paths: ['/music/A/2.mp3', '/music/gone.mp3'])]);
    ix.addSubscription(const Subscription(server: 's', kind: RuleKind.playlist, key: 'Mix'));
    var run = await runner().run(cfg);
    expect(run.downloaded, 1);
    expect(dl.calls, ['/music/A/2.mp3']);

    // Rated needs the manifest rows (the first run pulled them) and the
    // rated list; 8 and up leaves the 4 out.
    ix.replaceRated('s', {'/music/B/3.mp3': 8, '/music/A/1.mp3': 4});
    ix.addSubscription(const Subscription(server: 's', kind: RuleKind.rated, key: '8'));
    dl.calls.clear();
    run = await runner().run(cfg);
    expect(run.downloaded, 1);
    expect(dl.calls, ['/music/B/3.mp3']);
    expect(ix.wantedPaths('s'), {'/music/A/2.mp3', '/music/B/3.mp3'});
  });

  test('a disabled rule pins nothing and its edges are cleared', () async {
    await runner().run(cfg);
    final s = ix.subscriptionsFor('s').single;
    ix.removeSubscription(s.id!);
    final run = await runner().run(cfg);
    expect(run.trashed, 3);
    expect(ix.wantedPaths('s'), isEmpty);
  });

  test('lists are refreshed when the manifest moved and art is cached for mirrored tracks', () async {
    final lists = _FakeLists();
    final art = _FakeArt();
    srv.files['/music/A/1.mp3'] = srv.files['/music/A/1.mp3']!; // unchanged
    final withArt = MirrorConfig.under(tmp.path, 's', artRoot: p.join(tmp.path, 'art'), pageSize: 2);
    // Give two tracks art names through a manifest that carries them.
    final artful = _ArtfulManifest(srv, {'/music/A/1.mp3': 'aa.jpeg', '/music/A/2.mp3': 'aa.jpeg', '/music/B/3.mp3': 'bb.jpeg'});
    MirrorRunner r() => MirrorRunner(index: ix, manifest: artful, downloader: dl, lists: lists, art: art, now: () => clock);

    await r().run(withArt);
    expect(lists.calls, 1);
    expect(ix.albums('s').map((a) => a.name), ['Alpha']);
    expect(ix.artists('s'), ['Zed']);
    expect(art.calls, unorderedEquals(['aa.jpeg', 'bb.jpeg']), reason: 'one fetch per distinct file');
    expect(File(p.join(tmp.path, 'art', 'aa.jpeg')).readAsStringSync(), 'art:aa.jpeg');
    expect(Directory(p.join(tmp.path, 'art')).listSync().where((e) => p.basename(e.path).startsWith('.')), isEmpty,
        reason: 'no temp files left');

    // 304: lists untouched, cached art not re-fetched.
    art.calls.clear();
    lists.failPlaylists = true;
    await r().run(withArt);
    expect(lists.calls, 1);
    expect(art.calls, isEmpty);
    // The caller's lists are refreshed on every run, each on its own: the
    // failed playlist fetch left the previous playlists in place.
    expect(lists.userListCalls, 2);
    expect(ix.genres('s').single.name, 'Rock');
    expect(ix.playlists('s').single.name, 'Mix');
    expect(ix.rated('s').single.path, '/music/A/2.mp3');
    lists.failPlaylists = false;

    // A failing art fetch is not a run error and leaves nothing behind.
    art.failFor.add('cc.jpeg');
    artful.artByPath['/music/A/2.mp3'] = 'cc.jpeg';
    srv.revision = 'r2';
    final run = await r().run(withArt);
    expect(run.error, isNull);
    expect(File(p.join(tmp.path, 'art', 'cc.jpeg')).existsSync(), isFalse);
    expect(lists.calls, 2, reason: 'the manifest moved, so the lists were refreshed');
  });

  test('ManifestPage.fromJson reads the shipped shape', () {
    final page = ManifestPage.fromJson({
      'revision': '1:9:9:1:0',
      'scanning': false,
      'next': 5,
      'entries': [
        {'filepath': 'music/a.mp3', 'id': 5, 'file-size': 10, 'modified': 1, 'hash': 'h',
          'metadata': {'title': 'A', 'genres': []}},
      ],
    });
    expect(page.revision, '1:9:9:1:0');
    expect(page.next, 5);
    expect(page.entries.single.path, '/music/a.mp3');
    expect(page.entries.single.title, 'A');
    expect(ManifestPage.fromJson({'revision': 'x', 'next': null}).entries, isEmpty);
  });
}

class _FakeLists implements LibraryListsClient {
  int calls = 0;
  int userListCalls = 0;
  bool failPlaylists = false;
  @override
  Future<List<AlbumRow>> albums() async {
    calls++;
    return const [AlbumRow(name: 'Alpha', albumArtist: 'Zed', year: 2001)];
  }

  @override
  Future<List<String>> artists() async => const ['Zed'];

  @override
  Future<Map<String, int>> genres() async {
    userListCalls++;
    return const {'Rock': 2};
  }

  @override
  Future<List<PlaylistRow>> playlists() async {
    if (failPlaylists) throw const SocketException('no playlists');
    return const [PlaylistRow(id: 'Mix', name: 'Mix', paths: ['/music/A/1.mp3'])];
  }

  @override
  Future<Map<String, int>> rated() async => const {'/music/A/2.mp3': 8};
}

class _FakeArt implements ArtClient {
  final List<String> calls = [];
  final Set<String> failFor = {};
  @override
  Future<void> fetchArt(String artFile, String destination) async {
    calls.add(artFile);
    if (failFor.contains(artFile)) throw const SocketException('no art');
    await File(destination).writeAsString('art:$artFile');
  }
}

/// The fake manifest with album-art names attached to chosen paths.
class _ArtfulManifest extends FakeManifest {
  final Map<String, String> artByPath;
  _ArtfulManifest(super.server, this.artByPath);

  @override
  Future<ManifestPage?> fetchPage({int? cursor, int limit = 2000, String? ifNoneMatch}) async {
    final page = await super.fetchPage(cursor: cursor, limit: limit, ifNoneMatch: ifNoneMatch);
    if (page == null) return null;
    return ManifestPage(revision: page.revision, scanning: page.scanning, next: page.next,
        entries: [
          for (final t in page.entries)
            RemoteTrack(id: t.id, path: t.path, size: t.size, modified: t.modified, hash: t.hash,
                hashV: t.hashV, title: t.title, art: artByPath[t.path]),
        ]);
  }
}

/// Serves the fake server's manifest but keeps advertising [hash] for
/// [path] — the client's checksum check must catch the mismatch.
class _LyingManifest extends FakeManifest {
  final String path;
  final String hash;
  _LyingManifest(super.server, this.path, this.hash);

  @override
  Future<ManifestPage?> fetchPage({int? cursor, int limit = 2000, String? ifNoneMatch}) async {
    final page = await super.fetchPage(cursor: cursor, limit: limit, ifNoneMatch: ifNoneMatch);
    if (page == null) return null;
    return ManifestPage(revision: page.revision, scanning: page.scanning, next: page.next,
        entries: [
          for (final t in page.entries)
            t.path == path
                ? RemoteTrack(id: t.id, path: t.path, size: t.size, modified: t.modified, hash: hash, hashV: t.hashV)
                : t,
        ]);
  }
}
