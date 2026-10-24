// A connected server's Albums grid (and list) and an artist's page while
// browsing it (the phone spec's §4.3, §4.4, §4.1.3, §5.2): album cards with
// a known credit carry Keep a copy's ⋯ and long-press (never the singles
// bucket, never credits that disagree), their copy's badge whatever the
// gate — glyph only at large text — and the badge's word in the card's
// accessible label; the artist page names its artist, counts its albums,
// and offers the artist copy with its takes line (or the line why there is
// none); a list row's long-press and screen-reader action do what a card's
// ⋯ does.

import 'dart:async';

import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/browser.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/singletons/settings.dart';
import 'package:mstream_music/util/browse_keep_leads.dart';
import 'package:mstream_music/widgets/album_grid.dart';

import 'browse_keep_fixtures.dart';
import 'discovery_keep_fixtures.dart' show mockPathProvider;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final h = BrowseHarness();

  setUpAll(mockPathProvider);
  tearDown(() {
    h.tearDown();
    SettingsManager().setAlbumGrid(true).catchError((_) {});
  });

  DisplayItem album(String name,
      {String? credit = 'Boukmanflow',
      AlbumCredit state = AlbumCredit.known,
      String? sub,
      bool compilation = false,
      List<String> artists = const ['Boukmanflow'],
      int year = 2019,
      Server? on}) {
    final item = DisplayItem(on ?? h.peerB, name, 'album', name, Icon(Icons.album), sub ?? '${credit ?? artists.join(', ')} · $year')
      ..albumArtist = credit
      ..creditState = state
      ..year = year
      ..artists = artists
      ..compilation = compilation;
    return item;
  }

  List<DisplayItem> albums() => [
        album('Borrowed Tapes'),
        album('Harbour Lights', year: 2021),
        album('Night Market Sampler', credit: 'Various Artists', compilation: true, artists: const ['Color Out', 'Boukmanflow', 'ALM'], year: 2024),
        album('Peer Sessions', credit: 'Color Out', artists: const ['Color Out'], year: 2026),
        album('Split Series', credit: null, state: AlbumCredit.disagree, artists: const ['ALM', 'Night Owl Radio'], sub: 'ALM, Night Owl Radio', year: 2022),
      ];

  Map<String, dynamic> albumRec(String name, String credit, int year, {bool compilation = false, Map<String, Object> peer = browsePeerB}) => {
        'source': 'federation',
        'peer': peer,
        'album': name,
        'albumArtist': credit,
        if (!compilation) 'artist': credit,
        'year': year,
      };

  Map<String, dynamic> many(int copied) => {
        'scope': 'album',
        'songs': {'total': copied, 'copied': [], 'skipped': [], 'failed': []},
        'counts': {'total': copied, 'copied': copied, 'skipped': 0, 'failed': 0},
        'stopped': null,
        'peer': browsePeerB,
      };

  Finder more(String name) => find.byKey(ValueKey('album-card-more-$name'));

  Future<void> openAlbums(WidgetTester tester, List<DisplayItem> items,
      {double width = 390, double textScale = 1, bool gate = true, ArtistContext? artist}) async {
    ServerManager().currentServer = h.peerB;
    if (gate) await h.openGate();
    BrowserManager().goToNavScreen();
    await h.pump(tester, const Browser(), width: width, textScale: textScale);
    BrowserManager().setBrowserLabel(artist?.name ?? 'Albums');
    BrowserManager().addListToStack(items, alphabetical: artist == null, artist: artist);
    await BrowseHarness.frames(tester);
    await tester.pump(const Duration(milliseconds: 300));
    await BrowseHarness.frames(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  group('the Albums grid', () {
    testWidgets('a known credit: the ⋯ ("Keep a copy of {album}…") and long-press open the album sheet; credits that disagree: tap only', (tester) async {
      h.setUp();
      final handle = tester.ensureSemantics();
      await openAlbums(tester, albums());
      expect(more('Borrowed Tapes'), findsOneWidget);
      expect(more('Night Market Sampler'), findsOneWidget);
      expect(more('Split Series'), findsNothing);
      expect(tester.getSemantics(more('Borrowed Tapes')), isSemantics(label: 'Keep a copy of Borrowed Tapes…', isButton: true));
      expect(tester.getSize(more('Borrowed Tapes')).width, 44);
      await tester.tap(more('Borrowed Tapes'));
      await tester.pumpAndSettle();
      var r = h.opened.last;
      expect([r.subject, r.variant, r.hidden, r.lead], [KeepSubject.album, KeepVariant.item, <KeepHiddenLink>{}, {...albumRec('Borrowed Tapes', 'Boukmanflow', 2019), 'compilation': false}]);
      await tester.longPress(find.text('Night Market Sampler'));
      await tester.pumpAndSettle();
      r = h.opened.last;
      expect([r.compilation, r.lead.containsKey('artist'), r.lead['albumArtist']], [true, false, 'Various Artists']);
      // a tap still opens the album
      await tester.tap(find.text('Split Series'));
      await tester.pump();
      expect(BrowserManager().albumDetail?.name, 'Split Series');
      handle.dispose();
      await close(tester);
    });

    // The test font draws every glyph a full em wide: a card that holds
    // the badge's word is a tablet's here.
    testWidgets("its copies' badges, this server's only; the word in the card's accessible label", (tester) async {
      h.setUp();
      final handle = tester.ensureSemantics();
      h.fake.addJob(albumRec('Harbour Lights', 'Boukmanflow', 2021), scope: 'album', state: 'done', result: many(3));
      h.fake.addJob(albumRec('Peer Sessions', 'Color Out', 2026), scope: 'album', state: 'running', progress: 0.3, statusText: '1 of 3 songs · 2 MB');
      h.fake.addJob(albumRec('Borrowed Tapes', 'Boukmanflow', 2019, peer: browsePeerC), scope: 'album', state: 'running', statusText: '1 of 3 songs');
      await openAlbums(tester, albums(), width: 1200);
      expect(find.text('in your collection'), findsOneWidget);
      expect(find.text('copying 1 of 3'), findsOneWidget);
      expect(find.bySemanticsLabel('Harbour Lights, Boukmanflow · 2021, in your collection'), findsOneWidget);
      expect(find.bySemanticsLabel('Borrowed Tapes, Boukmanflow · 2019'), findsOneWidget, reason: "Stage Peer C's copy marks no card here");
      handle.dispose();
      await close(tester);
    });

    testWidgets('gate closed: no ⋯, a long hold is a tap again — the badges stay', (tester) async {
      h.setUp(noUpload: true);
      h.fake.addJob(albumRec('Harbour Lights', 'Boukmanflow', 2021), scope: 'album', state: 'done', result: many(3));
      await openAlbums(tester, albums(), width: 1200);
      expect(more('Borrowed Tapes'), findsNothing);
      expect(find.text('in your collection'), findsOneWidget);
      await tester.longPress(find.text('Borrowed Tapes'));
      await tester.pumpAndSettle();
      expect(h.opened, isEmpty);
      expect(BrowserManager().albumDetail?.name, 'Borrowed Tapes');
      await close(tester);
    });

    testWidgets("a word wider than the card less 16 pt: the glyph alone (the test font's em-wide glyphs on a 184 pt card)", (tester) async {
      h.setUp();
      h.fake.addJob(albumRec('Harbour Lights', 'Boukmanflow', 2021), scope: 'album', state: 'done', result: many(3));
      await openAlbums(tester, albums(), width: 600);
      expect(find.byKey(const ValueKey('discovery-card-badge-glyph-inCollection')), findsOneWidget);
      expect(tester.getSize(find.byKey(const ValueKey('discovery-card-badge-glyph-inCollection'))), const Size(24, 24));
      await close(tester);
    });

    testWidgets('above 1.3× the badge is the glyph alone; the word is still in the label', (tester) async {
      h.setUp();
      final handle = tester.ensureSemantics();
      h.fake.addJob(albumRec('Harbour Lights', 'Boukmanflow', 2021), scope: 'album', state: 'done', result: many(3));
      await openAlbums(tester, albums(), width: 1200, textScale: 1.31);
      expect(find.byKey(const ValueKey('discovery-card-badge-glyph-inCollection')), findsOneWidget);
      expect(find.text('in your collection'), findsNothing);
      expect(find.bySemanticsLabel(RegExp(r'^Harbour Lights, .*, in your collection$')), findsOneWidget);
      handle.dispose();
      await close(tester);
    });

    testWidgets('list mode: a row\'s long-press and its screen-reader action open the album sheet; the badge sits on the thumb, glyph only', (tester) async {
      h.setUp();
      SettingsManager().setAlbumGrid(false).catchError((_) {});
      final handle = tester.ensureSemantics();
      h.fake.addJob(albumRec('Harbour Lights', 'Boukmanflow', 2021), scope: 'album', state: 'done', result: many(3));
      await openAlbums(tester, albums());
      expect(find.byKey(const ValueKey('discovery-card-badge-glyph-inCollection')), findsOneWidget);
      await tester.longPress(find.text('Borrowed Tapes'));
      await tester.pumpAndSettle();
      expect([h.opened.single.subject, h.opened.single.variant], [KeepSubject.album, KeepVariant.item]);
      tester.semantics.customAction(find.semantics.byLabel(RegExp('^Night Market Sampler')),
          const CustomSemanticsAction(label: 'Keep a copy of Night Market Sampler…'));
      await tester.pumpAndSettle();
      expect(h.opened.last.lead['album'], 'Night Market Sampler');
      await tester.longPress(find.text('Split Series'));
      await tester.pumpAndSettle();
      expect(h.opened, hasLength(2), reason: 'credits that disagree: no album copy');
      handle.dispose();
      await close(tester);
    });

    testWidgets("list mode: a marked row's node says its badge's word — the glyph on the thumb is drawn only", (tester) async {
      h.setUp();
      SettingsManager().setAlbumGrid(false).catchError((_) {});
      final handle = tester.ensureSemantics();
      h.fake.addJob(albumRec('Harbour Lights', 'Boukmanflow', 2021), scope: 'album', state: 'done', result: many(3));
      await openAlbums(tester, albums());
      final node = find.bySemanticsLabel('Harbour Lights, Boukmanflow · 2021, in your collection');
      expect(node, findsOneWidget);
      expect(find.bySemanticsLabel('Harbour Lights'), findsNothing, reason: 'its texts are not read twice');
      final data = tester.getSemantics(node).getSemanticsData();
      expect([
        for (final id in data.customSemanticsActionIds ?? const <int>[]) CustomSemanticsAction.getAction(id)!.label,
      ], contains('Keep a copy of Harbour Lights…'));
      handle.dispose();
      await close(tester);
    });

    testWidgets("a card's ⋯ is its own node after the card's — the card is never inside it", (tester) async {
      h.setUp();
      final handle = tester.ensureSemantics();
      await openAlbums(tester, albums());
      final moreNode = tester.getSemantics(find.byKey(const ValueKey('album-card-more-node-Borrowed Tapes')));
      expect(moreNode.label, 'Keep a copy of Borrowed Tapes…');
      expect(moreNode.rect.width, 44);
      var inside = false;
      moreNode.visitChildren((c) {
        inside = true;
        return true;
      });
      expect(inside, isFalse, reason: 'no card inside the ⋯');
      final card = tester.getSemantics(find.bySemanticsLabel(RegExp(r'^Borrowed Tapes, ')));
      expect(identical(card.parent, moreNode.parent), isTrue, reason: 'siblings');
      final order = <int>[];
      moreNode.parent!.visitChildren((c) {
        order.add(c.id);
        return true;
      });
      expect(order.indexOf(card.id), lessThan(order.indexOf(moreNode.id)), reason: 'the card, then its ⋯');
      // Focus comes back to it once its sheet closes — on its own node.
      await tester.tap(more('Borrowed Tapes'));
      await tester.pumpAndSettle();
      expect(tester.getSemantics(find.byKey(const ValueKey('album-card-more-node-Borrowed Tapes'))),
          isSemantics(isFocusable: true, isFocused: true));
      // A long-pressed card gets it back itself.
      await tester.longPress(find.text('Harbour Lights'));
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, endsWith('|card'));
      handle.dispose();
      await close(tester);
    });

    testWidgets("a search's Album hit: no Keep a copy and no badge — even once its album page resolved the credit onto it", (tester) async {
      h.setUp();
      final handle = tester.ensureSemantics();
      final hit = album('Borrowed Tapes');
      ServerManager().currentServer = h.peerB;
      await h.openGate();
      BrowserManager().goToNavScreen();
      await h.pump(tester, const Browser());
      BrowserManager().setBrowserLabel('Search');
      BrowserManager().addListToStack([hit, album('Harbour Lights', year: 2021)], searchTerm: 'tapes');
      await BrowseHarness.frames(tester);
      expect(more('Borrowed Tapes'), findsNothing);
      await tester.longPress(find.text('Borrowed Tapes'));
      await tester.pumpAndSettle();
      expect(h.opened, isEmpty);
      SettingsManager().setAlbumGrid(false).catchError((_) {});
      await BrowseHarness.frames(tester);
      await tester.longPress(find.text('Borrowed Tapes'));
      await tester.pumpAndSettle();
      expect(h.opened, isEmpty, reason: 'nor its list row');
      handle.dispose();
      await close(tester);
    });

    testWidgets("focus a gone opener hands back lands on the page's list when the page has no header", (tester) async {
      h.setUp();
      await openAlbums(tester, albums());
      h.sheetOpen = Completer<void>();
      await tester.tap(more('Borrowed Tapes'));
      await tester.pump();
      h.home.noUpload = true;
      h.sheetOpen!.complete();
      await BrowseHarness.frames(tester, 3);
      expect(more('Borrowed Tapes'), findsNothing, reason: 'the page read the gate again');
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'browse page header');
      expect(find.ancestor(of: find.byType(AlbumGrid), matching: find.byKey(const ValueKey('browse-page-list-focus'))), findsOneWidget);
      await close(tester);
    });
  });

  group("an artist's page", () {
    ArtistContext boukmanflow({bool credits = true}) => ArtistContext(server: h.peerB, name: 'Boukmanflow', albums: [
          for (final (n, y) in [('Borrowed Tapes', 2019), ('Harbour Lights', 2021), ('Second Shift', 2023)])
            {'name': n, 'year': y, if (credits) 'album_artist': 'Boukmanflow', 'artists': ['Boukmanflow'], 'compilation': false, 'track_count': 3},
          {'name': 'Night Market Sampler', 'year': 2024, if (credits) 'album_artist': 'Various Artists', 'artists': ['Color Out', 'Boukmanflow', 'ALM'], 'compilation': true, 'track_count': 3},
          {'name': null, 'year': null, if (credits) 'album_artist': 'Boukmanflow', 'artists': ['Boukmanflow']},
        ]);

    List<DisplayItem> cards() => [
          album('Borrowed Tapes', sub: '2019'),
          album('Harbour Lights', year: 2021, sub: '2021'),
          album('Second Shift', year: 2023, sub: '2023'),
          album('Night Market Sampler', credit: 'Various Artists', compilation: true, artists: const ['Color Out', 'Boukmanflow', 'ALM'], year: 2024, sub: '2024'),
          DisplayItem(h.peerB, 'SINGLES', 'album', null, Icon(Icons.album), ''),
        ];

    Finder header() => find.byKey(const ValueKey('browse-artist-header'));

    testWidgets('its header names it, counts its albums, and offers the artist copy with its takes line', (tester) async {
      h.setUp();
      final handle = tester.ensureSemantics();
      final artist = boukmanflow();
      await openAlbums(tester, cards(), artist: artist, width: 600);
      expect(header(), findsOneWidget);
      expect(find.text('4 albums on Stage Peer B'), findsOneWidget);
      expect(find.text('Takes the 3 albums credited to Boukmanflow'), findsOneWidget);
      expect(
          tester.getSemantics(find.byKey(const ValueKey('browse-keep-pill'))),
          isSemantics(label: 'Keep a copy of albums by Boukmanflow…', hint: 'Takes the 3 albums credited to Boukmanflow', isButton: true));
      expect(find.bySemanticsLabel('Takes the 3 albums credited to Boukmanflow'), findsNothing, reason: "the pill's hint, never its own node");
      expect(more('SINGLES'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('browse-keep-pill')));
      await tester.pumpAndSettle();
      final r = h.opened.single;
      expect([r.subject, r.variant, r.hidden, identical(r.artist, artist), r.lead['artist']],
          [KeepSubject.artist, KeepVariant.page, isEmpty, true, 'Boukmanflow']);
      // a card on it keeps Open album (the sheet draws no Open artist)
      await tester.tap(more('Harbour Lights'));
      await tester.pumpAndSettle();
      expect([h.opened.last.variant, h.opened.last.hidden], [KeepVariant.item, isEmpty]);
      handle.dispose();
      await close(tester);
    });

    testWidgets('an artist who only appears on the albums here: no pill, the line why', (tester) async {
      h.setUp();
      final choir = ArtistContext(server: h.peerB, name: 'Lantern Choir', albums: const [
        {'name': 'Night Market Sampler', 'year': 2024, 'album_artist': 'Various Artists', 'artists': ['Lantern Choir', 'ALM'], 'compilation': true},
      ]);
      await openAlbums(tester, [cards()[3]], artist: choir);
      expect(find.byKey(const ValueKey('browse-keep-pill')), findsNothing);
      expect(find.text('Lantern Choir only appears on albums here, so there is no artist copy. Keep each album from its card.'), findsOneWidget);
      await close(tester);
    });

    testWidgets('Various Artists, or a server too old to name credits: the header, no action row', (tester) async {
      h.setUp();
      await openAlbums(tester, cards(), artist: boukmanflow(credits: false));
      expect(header(), findsOneWidget);
      expect([find.byKey(const ValueKey('browse-keep-pill')), find.byKey(const ValueKey('browse-artist-no-copy'))], everyElement(findsNothing));
      await close(tester);
      await openAlbums(tester, [cards()[3]],
          artist: ArtistContext(server: h.peerB, name: 'Various Artists', albums: const [
            {'name': 'Night Market Sampler', 'year': 2024, 'album_artist': 'Various Artists', 'artists': ['ALM'], 'compilation': true},
          ]));
      expect(find.byKey(const ValueKey('browse-keep-pill')), findsNothing);
      await close(tester);
    });

    testWidgets('gate closed: the header is information — an earlier artist copy as plain text', (tester) async {
      h.setUp(noUpload: true);
      h.fake.addJob({'source': 'federation', 'peer': browsePeerB, 'artist': 'Boukmanflow'}, scope: 'artist', state: 'done', result: {
        ...many(9),
        'scope': 'artist',
        'albums': [
          {'name': 'Borrowed Tapes', 'songs': {'total': 3, 'copied': [], 'skipped': [], 'failed': []}},
        ],
        'skippedAlbums': [],
      });
      await openAlbums(tester, cards(), artist: boukmanflow());
      expect(find.byKey(const ValueKey('browse-keep-pill')), findsNothing);
      expect(find.byKey(const ValueKey('browse-keep-plain')), findsOneWidget);
      expect(find.text('Takes the 3 albums credited to Boukmanflow'), findsNothing);
      await close(tester);
    });

    testWidgets('2.0× on a 360 phone: the takes line under the pill, nothing overflows', (tester) async {
      h.setUp();
      await openAlbums(tester, cards(), artist: boukmanflow(), width: 360, textScale: 2);
      expect(tester.takeException(), isNull);
      final pill = tester.getRect(find.byKey(const ValueKey('browse-keep-pill')));
      expect(tester.getTopLeft(find.byKey(const ValueKey('browse-artist-takes'))).dy, greaterThan(pill.bottom));
      await close(tester);
    });
  });
}
