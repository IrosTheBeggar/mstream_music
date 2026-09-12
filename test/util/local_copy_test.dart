import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/util/local_copy.dart';

void main() {
  Server server({String? mirrorRoot}) =>
      Server('http://x', null, null, null, 'home')..mirrorRoot = mirrorRoot;

  group('localCopyCandidates', () {
    test('download tree first, then the mirror root', () {
      final c = localCopyCandidates(
          server(mirrorRoot: '/mirror'), Directory('/dl'), '/music/A/x.flac');
      expect(c, [
        '/dl/media/home/music/A/x.flac',
        p.normalize('/mirror/music/A/x.flac'),
      ]);
    });

    test('no download dir (location unavailable) still offers the mirror root',
        () {
      expect(localCopyCandidates(server(mirrorRoot: '/mirror'), null, '/a.mp3'),
          [p.normalize('/mirror/a.mp3')]);
    });

    test('unset or empty mirror root adds nothing', () {
      expect(localCopyCandidates(server(), Directory('/dl'), '/a.mp3'),
          ['/dl/media/home/a.mp3']);
      expect(localCopyCandidates(server(mirrorRoot: ''), null, '/a.mp3'),
          isEmpty);
    });

    test('a Windows root and the server\'s slashes normalise to one native path',
        () {
      final c = localCopyCandidates(
          server(mirrorRoot: r'C:\Music\'), null, '/music/A/x.flac');
      expect(c.single, r'C:\Music\music\A\x.flac');
    }, skip: !Platform.isWindows);
  });

  group('firstExistingSync', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('local_copy_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('returns the first candidate that exists, in order', () {
      final a = File(p.join(tmp.path, 'a'));
      final b = File(p.join(tmp.path, 'b'))..writeAsStringSync('');
      expect(firstExistingSync([a.path, b.path]), b.path);
      a.writeAsStringSync('');
      expect(firstExistingSync([a.path, b.path]), a.path);
    });

    test('null when nothing exists or there are no candidates', () {
      expect(firstExistingSync([p.join(tmp.path, 'nope')]), isNull);
      expect(firstExistingSync(const []), isNull);
    });
  });
}
