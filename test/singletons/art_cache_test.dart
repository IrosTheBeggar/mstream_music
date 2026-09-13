import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:mstream_music/singletons/art_cache.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('art_cache_'));
  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('lists what is cached per server, ignores temp files, reloads after a run', () async {
    final root = p.join(tmp.path, 'art');
    Directory(p.join(root, 'home')).createSync(recursive: true);
    File(p.join(root, 'home', 'aa.jpeg')).writeAsStringSync('x');
    File(p.join(root, 'home', '.abc.part')).writeAsStringSync('x');

    final cache = ArtCache();
    await cache.init(root: root);
    expect(cache.dirFor('home'), p.join(root, 'home'));
    expect(cache.pathFor('home', 'aa.jpeg'), p.join(root, 'home', 'aa.jpeg'));
    expect(cache.pathFor('home', '.abc.part'), isNull);
    expect(cache.pathFor('home', 'zz.jpeg'), isNull);
    expect(cache.pathFor('other', 'aa.jpeg'), isNull);
    expect(cache.count('home'), 1);

    File(p.join(root, 'home', 'zz.jpeg')).writeAsStringSync('x');
    expect(cache.pathFor('home', 'zz.jpeg'), isNull, reason: 'not reloaded yet');
    await cache.reload('home');
    expect(cache.pathFor('home', 'zz.jpeg'), isNotNull);
    await cache.reload('missing');
    expect(cache.count('missing'), 0);
  });
}
