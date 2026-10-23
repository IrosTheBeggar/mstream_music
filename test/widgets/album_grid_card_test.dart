// The album grid card's cover — the browser's album grids and Discover's
// album strips draw the same card — asks the server for its 'l' rendition
// (256 px, the webapp's album-card size). mStream caches 's' (92 px) and 'l'
// only; any other value serves the full-size original, which is what the
// card's former 'm' quietly did (2026-10-17). The list thumbnails
// (DisplayItem.getAlbumThumb) stay on 's'.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/widgets/album_grid.dart';

void main() {
  final server = Server('http://music.example', null, null, 'JWT', 'home');

  Widget card(DisplayItem item) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 160,
              height: 240,
              child: AlbumGridCard(item: item, onTap: () {}, cacheWidth: 300),
            ),
          ),
        ),
      );

  String? urlOf(WidgetTester tester) {
    final images = find.byType(Image);
    if (images.evaluate().isEmpty) return null;
    var p = tester.widget<Image>(images.first).image;
    if (p is ResizeImage) p = p.imageProvider;
    return p is NetworkImage ? p.url : null;
  }

  testWidgets("an album card's cover is the server's 'l' rendition",
      (tester) async {
    final item = DisplayItem(server, 'Lanterns', 'album',
        '{"album":"Lanterns"}', null, 'Attic Band')
      ..altAlbumArt = 'abc.jpg';
    await tester.pumpWidget(card(item));
    expect(urlOf(tester),
        'http://music.example/album-art/abc.jpg?compress=l&token=JWT');
  });

  testWidgets("a connected server's card asks the parent's art proxy for 'l'",
      (tester) async {
    final peer = Server('federated://home/7', null, null, null, 'peer-7')
      ..federationParent = 'home'
      ..federationPeerId = 7
      ..parentServer = server;
    final item = DisplayItem(peer, 'Lanterns', 'album',
        '{"album":"Lanterns"}', null, 'Attic Band')
      ..altAlbumArt = 'abc.jpg';
    await tester.pumpWidget(card(item));
    expect(urlOf(tester),
        'http://music.example/api/v1/federation/peers/7/art/abc.jpg'
        '?compress=l&token=JWT');
  });

  testWidgets('no art: the placeholder, no network image', (tester) async {
    final item = DisplayItem(
        server, 'Lanterns', 'album', '{"album":"Lanterns"}', null, 'Attic Band');
    await tester.pumpWidget(card(item));
    expect(urlOf(tester), isNull);
  });
}
