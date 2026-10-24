// The browser bar while browsing a connected server (the phone spec's §4.3
// and decision 3): an artist's page reads the artist's name — every
// server's, from its frame's own label — and Back restores the label of the
// frame it lands on; the album bar's Play is a 44 pt target with its 36 pt
// disc inside.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/metadata.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/widgets/browser_toolbar.dart';

import '../screens/browse_keep_fixtures.dart';
import '../screens/discovery_keep_fixtures.dart' show mockPathProvider;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final h = BrowseHarness();

  setUpAll(mockPathProvider);
  setUp(h.setUp);
  tearDown(() {
    BrowserManager().closeAlbumDetail();
    h.tearDown();
  });

  Widget bar() => const Material(color: Colors.black, child: BrowserToolbar());

  testWidgets("an artist's page names its artist; Back restores the list's label", (tester) async {
    BrowserManager().goToNavScreen();
    await h.pump(tester, bar());
    final bm = BrowserManager();
    bm.setBrowserLabel('Artists');
    bm.addListToStack([DisplayItem(h.peerB, 'Boukmanflow', 'artist', 'Boukmanflow', null, null)], alphabetical: true);
    bm.setBrowserLabel('Boukmanflow');
    bm.addListToStack([DisplayItem(h.peerB, 'Borrowed Tapes', 'album', 'Borrowed Tapes', null, '2019')],
        artist: ArtistContext(server: h.peerB, name: 'Boukmanflow'));
    await tester.pump();
    expect(find.text('Boukmanflow'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    expect(find.text('Artists'), findsOneWidget);
    expect(find.text('Boukmanflow'), findsNothing);
  });

  testWidgets("an artist named as a section (\"Library\") reads as named, never translated as the section", (tester) async {
    BrowserManager().goToNavScreen();
    await h.pump(
        tester,
        Builder(
            builder: (context) => Localizations.override(
                context: context, locale: const Locale('de'), child: bar())));
    final bm = BrowserManager();
    bm.setBrowserLabel('Library');
    bm.addListToStack([DisplayItem(h.peerB, 'Boukmanflow', 'artist', 'Boukmanflow', null, null)], alphabetical: true);
    await tester.pump();
    expect(find.text('Bibliothek'), findsOneWidget, reason: "the section's name, in German");
    bm.setBrowserLabel('Library');
    bm.addListToStack([DisplayItem(h.peerB, 'Night Tapes', 'album', 'Night Tapes', null, '2019')],
        artist: ArtistContext(server: h.peerB, name: 'Library'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Library'), findsOneWidget, reason: "the artist's own name");
    expect(find.text('Bibliothek'), findsNothing);
  });

  testWidgets("the album bar's Play: a 44 pt target, its 36 pt disc inside", (tester) async {
    BrowserManager().goToNavScreen();
    await h.pump(tester, bar());
    final album = DisplayItem(h.peerB, 'Borrowed Tapes', 'album', 'Borrowed Tapes', null, '2019');
    BrowserManager().openAlbumDetail(album);
    BrowserManager().albumDetailSongs = [
      DisplayItem(h.peerB, '01.mp3', 'file', '/music/Boukmanflow/Borrowed Tapes/01.mp3', null, null)
        ..metadata = MusicMetadata.fromServerMap({'title': 'Rooftop Cypher'}),
    ];
    await tester.pump();
    expect(tester.getSize(find.byKey(const ValueKey('album-bar-play'))), const Size(44, 44));
    expect(tester.getSize(find.byTooltip('Play')), const Size(36, 36));
  });
}
