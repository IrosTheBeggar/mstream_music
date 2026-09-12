import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:library_mirror/library_mirror.dart';
import 'package:path/path.dart' as p;

import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/library_index.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('library_index_'));
  tearDown(() {
    LibraryIndexManager().close();
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {
      // Windows can hold the WAL briefly after close; the temp dir is disposable.
    }
  });

  File touch(String rel, [String body = 'x']) {
    final f = File(p.join(tmp.path, rel))..createSync(recursive: true);
    f.writeAsStringSync(body);
    return f;
  }

  group('walkDownloadTree', () {
    test('yields the data path off the tree layout and skips mirror temp/trash',
        () {
      final root = p.join(tmp.path, 'media', 'home');
      touch('media/home/vpath/A/x.mp3', 'abc');
      touch('media/home/vpath/.mstream-trash/2026-01-01/y.mp3');
      touch('media/home/.mstream-tmp-123');
      final found = walkDownloadTree(root);
      expect(found.length, 1);
      final (path, abs, size, mtime) = found.single;
      expect(path, '/vpath/A/x.mp3');
      expect(File(abs).existsSync(), isTrue);
      expect(size, 3);
      expect(mtime, greaterThan(0));
    });

    test('a missing root is just empty', () {
      expect(walkDownloadTree(p.join(tmp.path, 'nope')), isEmpty);
    });
  });

  group('LibraryIndexManager', () {
    test('imports existing downloads once per server, then stays in step', () async {
      final m = LibraryIndexManager();
      await m.open(path: p.join(tmp.path, 'index.db'));
      expect(m.available, isTrue);
      final home = Server('http://h', null, null, null, 'home');
      touch('dl/media/home/vpath/A/x.mp3');
      touch('dl/media/home/vpath/B/y.flac');

      Future<Directory?> dirFor(Server s) async => Directory(p.join(tmp.path, 'dl'));
      await m.importExistingDownloads(servers: [home], dirFor: dirFor);
      final ix = m.index!;
      expect(ix.localCount('home'), 2);
      final x = ix.localFile('home', '/vpath/A/x.mp3')!;
      expect(x.origin, LocalOrigin.manual);
      expect(x.state, LocalState.ok);
      expect(ix.meta('home', 'imported'), '2');

      // A second import is a no-op even though a file appeared meanwhile.
      touch('dl/media/home/vpath/C/z.mp3');
      await m.importExistingDownloads(servers: [home], dirFor: dirFor);
      expect(ix.localCount('home'), 2);

      // Downloads and deletions keep the rows current.
      final z = File(p.join(tmp.path, 'dl', 'media', 'home', 'vpath', 'C', 'z.mp3'));
      m.recordDownloaded('home', '/vpath/C/z.mp3', z.path, auto: true);
      expect(ix.localFile('home', '/vpath/C/z.mp3')!.origin, LocalOrigin.auto);
      m.promoteToManual('home', '/vpath/C/z.mp3');
      expect(ix.localFile('home', '/vpath/C/z.mp3')!.origin, LocalOrigin.manual);
      m.forgetLocalPath('home', z.path);
      expect(ix.localFile('home', '/vpath/C/z.mp3'), isNull);
      m.forgetLocalUnder(null, p.join(tmp.path, 'dl', 'media', 'home', 'vpath', 'A'));
      expect(ix.localFile('home', '/vpath/A/x.mp3'), isNull);
      expect(ix.localCount('home'), 1);

      m.removeServer('home');
      expect(ix.localCount('home'), 0);
      expect(ix.meta('home', 'imported'), isNull);
    });

    test('an unavailable download location is skipped and retried later', () async {
      final m = LibraryIndexManager();
      await m.open(path: p.join(tmp.path, 'index.db'));
      final s = Server('http://h', null, null, null, 'sd');
      await m.importExistingDownloads(servers: [s], dirFor: (_) async => null);
      expect(m.index!.meta('sd', 'imported'), isNull, reason: 'not marked done');
    });
  });
}
