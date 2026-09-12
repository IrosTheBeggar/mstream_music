import 'package:library_mirror/library_mirror.dart';
import 'package:test/test.dart';

const t0 = 1700000000000;

RemoteTrack rt(String path, {int? size = 1000, int? modified = t0, String? hash}) =>
    RemoteTrack(id: path.hashCode & 0xffffff, path: path, size: size, modified: modified,
        hash: hash ?? 'h$path');

LocalFile lf(String path,
        {String origin = LocalOrigin.mirror,
        String state = LocalState.ok,
        int? size = 1000,
        int? mtime = t0,
        String? hash,
        String quality = 'original'}) =>
    LocalFile(
        server: 's', path: path, localPath: '/dl/media/s$path', state: state,
        origin: origin, size: size, mtime: mtime, hash: hash ?? 'h$path', quality: quality);

Plan run({List<RemoteTrack> remote = const [], List<LocalFile> local = const [],
        Set<String>? wanted, PlanOptions options = const PlanOptions()}) =>
    plan(remote: remote, local: local,
        wanted: wanted ?? {for (final t in remote) t.path}, options: options);

void main() {
  group('plan', () {
    test('missing → download, present and equal → unchanged', () {
      final p = run(remote: [rt('/m/a'), rt('/m/b')], local: [lf('/m/a')]);
      expect(p.downloads.map((t) => t.path), ['/m/b']);
      expect(p.unchanged, 1);
      expect(p.bytesNeeded, 1000);
      expect(p.replaces, isEmpty);
      expect(p.trashes, isEmpty);
      expect(p.hasWork, isTrue);
    });

    test('a size or mtime difference is a replace, counted with headroom for both copies', () {
      final p = run(
          remote: [rt('/m/a', size: 1500), rt('/m/b', modified: t0 + 60 * 60 * 1000 * 5)],
          local: [lf('/m/a'), lf('/m/b')]);
      expect(p.replaces.map((t) => t.path), unorderedEquals(['/m/a', '/m/b']));
      expect(p.bytesNeeded, 1500 + 1000 + 1000 + 1000);
      expect(p.unchanged, 0);
    });

    test('mtime within 2 s, or exactly one hour off, still agrees (FAT / DST)', () {
      final p = run(remote: [
        rt('/m/a', modified: t0 + 1999),
        rt('/m/b', modified: t0 + 3600 * 1000 + 500),
        rt('/m/c', modified: t0 - 3600 * 1000),
        rt('/m/d', modified: t0 + 2001),
      ], local: [lf('/m/a'), lf('/m/b'), lf('/m/c'), lf('/m/d')]);
      expect(p.unchanged, 3);
      expect(p.replaces.single.path, '/m/d');
    });

    test('unknown sizes or mtimes on either side never force a replace', () {
      final p = run(remote: [rt('/m/a', size: null, modified: null)],
          local: [lf('/m/a', size: null, mtime: 5)]);
      expect(p.unchanged, 1);
    });

    test('a failed or stale local row is fetched again', () {
      final p = run(remote: [rt('/m/a'), rt('/m/b')],
          local: [lf('/m/a', state: LocalState.failed), lf('/m/b', state: LocalState.stale)]);
      expect(p.downloads.map((t) => t.path), unorderedEquals(['/m/a', '/m/b']));
    });

    test('rename: a mirror orphan with the same hash is moved, not downloaded', () {
      final p = run(remote: [rt('/m/new', hash: 'X')], local: [lf('/m/old', hash: 'X')]);
      expect(p.downloads, isEmpty);
      expect(p.renames.single.from.path, '/m/old');
      expect(p.renames.single.to.path, '/m/new');
      expect(p.trashes, isEmpty, reason: 'the orphan was claimed by the rename');
      expect(p.bytesNeeded, 0);
    });

    test('an orphan is claimed once; a second identical file downloads', () {
      final p = run(remote: [rt('/m/n1', hash: 'X'), rt('/m/n2', hash: 'X')],
          local: [lf('/m/old', hash: 'X')]);
      expect(p.renames.length, 1);
      expect(p.downloads.length, 1);
    });

    test('only mirror-owned orphans are renamed; a manual copy stays and the new path downloads', () {
      final p = run(remote: [rt('/m/new', hash: 'X')],
          local: [lf('/m/old', hash: 'X', origin: LocalOrigin.manual)]);
      expect(p.renames, isEmpty);
      expect(p.downloads.single.path, '/m/new');
      expect(p.trashes, isEmpty);
    });

    test('server-dropped mirror rows are trashed; manual, auto and external never', () {
      final p = run(remote: [rt('/m/keep')], local: [
        lf('/m/keep'),
        lf('/m/gone-mirror'),
        lf('/m/gone-manual', origin: LocalOrigin.manual),
        lf('/m/gone-auto', origin: LocalOrigin.auto),
        lf('/m/gone-ext', origin: LocalOrigin.external),
      ]);
      expect(p.trashes.map((f) => f.path), ['/m/gone-mirror']);
      expect(p.unchanged, 1);
    });

    test('mirror rows no rule wants are trashed, unless trashUnwanted is off', () {
      final remote = [rt('/m/a'), rt('/m/b')];
      final local = [lf('/m/a'), lf('/m/b')];
      expect(run(remote: remote, local: local, wanted: {'/m/a'}).trashes.single.path, '/m/b');
      expect(run(remote: remote, local: local, wanted: {'/m/a'},
          options: const PlanOptions(trashUnwanted: false)).trashes, isEmpty);
    });

    test('scanning suppresses trashing but not transfers', () {
      final p = run(remote: [rt('/m/a')], local: [lf('/m/gone')],
          options: const PlanOptions(scanning: true));
      expect(p.trashes, isEmpty);
      expect(p.downloads.single.path, '/m/a');
    });

    test('case-folded duplicates are conflicts and skipped, both of them', () {
      final p = run(remote: [rt('/m/Live.flac'), rt('/m/live.flac'), rt('/m/other')]);
      expect(p.conflicts, ['/m/Live.flac', '/m/live.flac']);
      expect(p.downloads.single.path, '/m/other');
    });

    test('a wanted path the server does not list is ignored', () {
      final p = run(remote: [rt('/m/a')], wanted: {'/m/a', '/m/zzz'});
      expect(p.downloads.single.path, '/m/a');
    });

    test('rows of another quality tier are invisible to the mirror', () {
      final p = run(remote: [rt('/m/a')], local: [lf('/m/a', quality: 'mp3-192')]);
      expect(p.downloads.single.path, '/m/a');
      expect(p.trashes, isEmpty);
    });

    test('empty inputs plan nothing', () {
      final p = run();
      expect(p.hasWork, isFalse);
      expect(p.unchanged, 0);
    });
  });

  test('mtimesAgree', () {
    const o = PlanOptions();
    expect(mtimesAgree(0, o), isTrue);
    expect(mtimesAgree(1999, o), isTrue);
    expect(mtimesAgree(-1999, o), isTrue);
    expect(mtimesAgree(2000, o), isFalse);
    expect(mtimesAgree(3600 * 1000, o), isTrue);
    expect(mtimesAgree(-3600 * 1000 + 1500, o), isTrue);
    expect(mtimesAgree(3600 * 1000 + 2000, o), isFalse);
  });
}
