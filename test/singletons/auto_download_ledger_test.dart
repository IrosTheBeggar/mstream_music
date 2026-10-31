import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:library_mirror/library_mirror.dart';
import 'package:path/path.dart' as p;

import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/auto_download_ledger.dart';
import 'package:mstream_music/singletons/library_index.dart';

void main() {
  late Directory tmp;
  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('auto_ledger_');
    await LibraryIndexManager().open(path: p.join(tmp.path, 'index.db'));
  });
  tearDown(() {
    LibraryIndexManager().close();
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  File touch(String rel) {
    final f = File(p.join(tmp.path, rel))..createSync(recursive: true);
    f.writeAsStringSync('x');
    return f;
  }

  bool none(String s, String q) => false;

  test('the JSON ledger is folded into the index once, in order, files only; the import never re-labels it', () async {
    final a = touch('dl/media/home/v/a.mp3');
    final b = touch('dl/media/home/v/b.mp3');
    touch('dl/media/home/v/m.mp3'); // a manual download, never in the ledger
    final json = File(p.join(tmp.path, 'auto_downloads.json'))
      ..writeAsStringSync(jsonEncode([
        {'server': 'home', 'path': '/v/a.mp3', 'localPath': a.path},
        {'server': 'home', 'path': '/v/gone.mp3', 'localPath': p.join(tmp.path, 'dl', 'media', 'home', 'v', 'gone.mp3')},
        {'server': 'home', 'path': '/v/b.mp3', 'localPath': b.path},
        {'bogus': true},
      ]));
    final l = AutoDownloadLedger();
    await l.migrateFrom(json);
    expect(json.existsSync(), isFalse);
    expect(l.entries.map((e) => e.path), ['/v/a.mp3', '/v/b.mp3'],
        reason: 'oldest first, the missing file dropped');
    final ix = LibraryIndexManager().index!;
    expect(ix.localFile('home', '/v/a.mp3')!.origin, LocalOrigin.auto);
    expect(ix.localFile('home', '/v/a.mp3')!.size, 1);
    expect(ix.localFile('home', '/v/gone.mp3'), isNull);

    // The one-time import may run before or after: existing rows keep their label.
    final home = Server('http://h', null, null, null, 'home');
    await LibraryIndexManager().importExistingDownloads(
        servers: [home], dirFor: (_) async => Directory(p.join(tmp.path, 'dl')));
    expect(ix.localFile('home', '/v/a.mp3')!.origin, LocalOrigin.auto);
    expect(ix.localFile('home', '/v/m.mp3')!.origin, LocalOrigin.manual);
    expect(l.entries, hasLength(2));

    // Migrated already: nothing to do.
    await l.migrateFrom(json);
    expect(l.entries, hasLength(2));
  });

  test('evictions come off the index oldest first; a manual download takes a track out; a re-download makes it newest', () async {
    final m = LibraryIndexManager();
    final f = <String, File>{};
    for (final n in ['a', 'b', 'c']) {
      f[n] = touch('dl/media/home/v/$n.mp3');
      m.recordDownloaded('home', '/v/$n.mp3', f[n]!.path, auto: true);
      await Future<void>.delayed(const Duration(milliseconds: 2)); // distinct stamps
    }
    final l = AutoDownloadLedger();
    expect(l.evictionsFor(2, none).map((e) => e.path), ['/v/a.mp3']);
    expect(l.evictionsFor(2, (s, q) => q == '/v/a.mp3').map((e) => e.path), ['/v/b.mp3'],
        reason: 'the protected oldest is skipped, the next oldest goes');
    expect(l.evictionsFor(0, none), isEmpty);

    l.forget('home', '/v/a.mp3');
    expect(l.entries.map((e) => e.path), ['/v/b.mp3', '/v/c.mp3']);
    expect(m.index!.localFile('home', '/v/a.mp3')!.origin, LocalOrigin.manual);
    l.forget('home', '/v/a.mp3'); // already manual: a no-op
    expect(m.index!.localFile('home', '/v/a.mp3')!.origin, LocalOrigin.manual);

    await Future<void>.delayed(const Duration(milliseconds: 2));
    m.recordDownloaded('home', '/v/b.mp3', f['b']!.path, auto: true);
    expect(l.entries.map((e) => e.path), ['/v/c.mp3', '/v/b.mp3'], reason: 're-recorded → newest');

    // Eviction removes the row with the file (what DownloadManager does).
    m.forgetLocalPath('home', f['c']!.path);
    expect(l.entries.map((e) => e.path), ['/v/b.mp3']);
  });

  test('without the index there is nothing to evict', () {
    LibraryIndexManager().close();
    expect(AutoDownloadLedger().entries, isEmpty);
    expect(AutoDownloadLedger().evictionsFor(1, none), isEmpty);
    AutoDownloadLedger().forget('home', '/v/a.mp3'); // no-op, no throw
  });
}
