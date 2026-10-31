import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/art_cache.dart';
import 'package:mstream_music/widgets/album_grid.dart';

// A valid 1x1 transparent PNG, so the cached file decodes like real art.
const _png1x1 = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

/// The provider under the decode-size wrapper the grid adds (cacheWidth).
ImageProvider _inner(Image w) {
  final i = w.image;
  return i is ResizeImage ? i.imageProvider : i;
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('album_grid_'));
  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  testWidgets('a tile shows the mirror-cached cover, else the server art URL',
      (tester) async {
    final root = p.join(tmp.path, 'art');
    Directory(p.join(root, 'home')).createSync(recursive: true);
    final cachedFile = p.join(root, 'home', 'aa.jpeg');
    File(cachedFile).writeAsBytesSync(_png1x1);
    // Real file I/O never completes inside the fake-async test zone.
    await tester.runAsync(() => ArtCache().init(root: root));

    final server = Server('http://h', null, null, null, 'home');
    final cached = DisplayItem(server, 'First', 'album', 'First', null, '2001')
      ..altAlbumArt = 'aa.jpeg';
    final remote = DisplayItem(server, 'Second', 'album', 'Second', null, null)
      ..altAlbumArt = 'zz.jpeg';
    final noArt = DisplayItem(server, 'Third', 'album', 'Third', null, null);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AlbumGrid(items: [cached, remote, noArt], onTap: (_) {}),
      ),
    ));

    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images, hasLength(2), reason: 'the no-art tile paints a placeholder');
    expect(_inner(images[0]),
        isA<FileImage>().having((f) => f.file.path, 'path', cachedFile));
    expect(_inner(images[1]),
        isA<NetworkImage>().having((n) => n.url, 'url', contains('zz.jpeg')));
  });
}
