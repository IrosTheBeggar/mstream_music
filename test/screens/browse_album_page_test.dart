// A connected server's album page while browsing it (the phone spec's §4.2,
// §5.1, §5.3, §8 and §9): the banner scrolls with the songs on every album
// page; its credit is the album's real one (resolved, never a derived
// "Various Artists"); the slot under its facts holds the pill — its 44 pt
// held empty while the credit resolves (no pop-in), the line why there is
// no album copy when the credits disagree, nothing once nothing is known —
// or, with the gate closed, an earlier copy's state as plain text; the
// rows mark what the user's copies did with each song (nothing while the
// album copy runs); the ⋮ is 44 pt and named for its song, the track sheet
// gains "Keep a copy…" before Download, and the rows offer it to a screen
// reader; at 2.0× text on a small phone nothing overflows.

import 'dart:async';

import 'package:flutter/semantics.dart' show CustomSemanticsAction, SemanticsAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/album_detail_view.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/util/browse_keep_leads.dart';

import 'browse_keep_fixtures.dart';
import 'discovery_keep_fixtures.dart' show mockPathProvider;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final h = BrowseHarness();

  setUpAll(mockPathProvider);
  tearDown(() {
    h.tearDown();
    AlbumDetailView.makeResolver = AlbumCreditResolver.new;
  });

  /// Borrowed Tapes as the Albums grid lists it: its credit known.
  DisplayItem tapes({Server? on}) =>
      DisplayItem(on ?? h.peerB, 'Borrowed Tapes', 'album', 'Borrowed Tapes', null, 'Boukmanflow · 2019')
        ..albumArtist = 'Boukmanflow'
        ..creditState = AlbumCredit.known
        ..year = 2019
        ..artists = const ['Boukmanflow']
        ..compilation = false;

  Finder pill() => find.byKey(const ValueKey('browse-keep-pill'));
  Finder reserved() => find.byKey(const ValueKey('browse-keep-reserved'));
  Finder banner() => find.byType(AlbumDetailView);

  Future<void> open(WidgetTester tester, DisplayItem album,
      {double width = 390, double height = 844, double textScale = 1, bool gate = true}) async {
    h.routes['/api/v1/db/album-songs'] = h.routes['/api/v1/db/album-songs'] ?? borrowedTapes();
    await h.withRoutes(() async {
      if (gate) await h.openGate();
      await h.pump(tester, AlbumDetailView(album: album), width: width, height: height, textScale: textScale);
      await BrowseHarness.frames(tester);
    });
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  group('the banner', () {
    testWidgets('scrolls with the songs; its runtime under ten minutes reads 0:29; its ⋮ are 44 pt and named for their song', (tester) async {
      h.setUp();
      await open(tester, tapes());
      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(find.textContaining('0:29'), findsOneWidget);
      expect(find.textContaining('0 min'), findsNothing);
      final more = find.byTooltip('More actions for Late Train Verse');
      expect(more, findsOneWidget);
      expect(tester.getSize(more), const Size(44, 44));
      // it scrolls away with the list
      final before = tester.getTopLeft(find.text('Borrowed Tapes').first).dy;
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -60));
      await tester.pump();
      expect(tester.getTopLeft(find.text('Borrowed Tapes').first).dy, lessThan(before));
      await close(tester);
    });

    testWidgets("a connected server's credit is the album's own; the songs' artists when they disagree, never a derived Various Artists", (tester) async {
      h.setUp();
      h.routes['/api/v1/db/album-songs'] = [
        peerSong('music/Split/01.mp3', 'One', artist: 'ALM', album: 'Split Series', track: 1),
        peerSong('music/Split/02.mp3', 'Two', artist: 'Night Owl Radio', album: 'Split Series', track: 2),
      ];
      final split = DisplayItem(h.peerB, 'Split Series', 'album', 'Split Series', null, 'ALM, Night Owl Radio')
        ..creditState = AlbumCredit.disagree;
      await open(tester, split);
      expect(tester.widget<Text>(find.byKey(const ValueKey('album-banner-credit'))).data, 'ALM, Night Owl Radio');
      expect(find.text('Various Artists'), findsNothing);
      expect(pill(), findsNothing);
      expect(find.text('Its songs name different album artists, so copies go song by song.'), findsOneWidget);
      await close(tester);
    });

    testWidgets("your own server's album keeps today's line and has no slot", (tester) async {
      h.setUp();
      ServerManager().currentServer = h.home;
      h.routes['/api/v1/db/album-songs'] = [
        peerSong('music/Mix/01.mp3', 'One', artist: 'ALM', album: 'Mix', track: 1),
        peerSong('music/Mix/02.mp3', 'Two', artist: 'Color Out', album: 'Mix', track: 2),
      ];
      final mine = DisplayItem(h.home, 'Mix', 'album', 'Mix', null, '2020');
      await open(tester, mine);
      expect(tester.widget<Text>(find.byKey(const ValueKey('album-banner-credit'))).data, 'Various Artists');
      expect([pill(), reserved()], everyElement(findsNothing));
      expect(tester.getSize(find.byTooltip('More actions for One')), const Size(44, 44));
      await close(tester);
    });
  });

  group('the slot under the facts', () {
    // The test font draws every glyph a full em wide, so the text column
    // that holds the pill's longest words is wider than a phone's here.
    testWidgets('credit known: the pill in the text column beside the cover — no reserved slot first', (tester) async {
      h.setUp();
      await open(tester, tapes(), width: 600, height: 844);
      expect(pill(), findsOneWidget);
      expect(reserved(), findsNothing);
      expect(find.text('Keep a copy…'), findsOneWidget);
      final cover = tester.getRect(find.byType(ClipRRect).first);
      expect(tester.getTopLeft(pill()).dx, greaterThan(cover.right), reason: 'beside the cover');
      await close(tester);
    });

    testWidgets('credit resolving (a search hit): its 44 pt held empty, then the pill in it — nothing below moves', (tester) async {
      h.setUp();
      final answer = Completer<dynamic>();
      AlbumDetailView.makeResolver = () => AlbumCreditResolver(post: (_, _, _) => answer.future);
      final hit = DisplayItem(h.peerB, 'Borrowed Tapes', 'album', 'Borrowed Tapes', null, 'album')
        ..creditHint = 'Boukmanflow'
        ..yearHint = 2019;
      await open(tester, hit);
      expect(reserved(), findsOneWidget);
      expect(pill(), findsNothing);
      final row = tester.getTopLeft(find.text('Rooftop Cypher')).dy;
      answer.complete({
        'albums': [
          {'name': 'Borrowed Tapes', 'year': 2019, 'album_artist': 'Boukmanflow'},
        ],
      });
      await BrowseHarness.frames(tester);
      expect(reserved(), findsNothing);
      expect(pill(), findsOneWidget);
      expect(tester.getTopLeft(find.text('Rooftop Cypher')).dy, row, reason: 'no pop-in');
      expect(hit.creditState, AlbumCredit.known, reason: 'Back reuses it');
      await close(tester);
    });

    testWidgets("credit unknown (the read failed): the held place folds away — no pill, no line", (tester) async {
      h.setUp();
      AlbumDetailView.makeResolver = () => AlbumCreditResolver(post: (_, _, _) async => throw Exception('502'));
      final hit = DisplayItem(h.peerB, 'Borrowed Tapes', 'album', 'Borrowed Tapes', null, 'album');
      await open(tester, hit);
      await tester.pump(const Duration(milliseconds: 300));
      expect([reserved(), pill(), find.byKey(const ValueKey('browse-keep-no-credit'))], everyElement(findsNothing));
      await close(tester);
    });

    testWidgets('the singles bucket is no album: no slot', (tester) async {
      h.setUp();
      final singles = DisplayItem(h.peerB, 'SINGLES', 'album', null, null, '');
      await open(tester, singles);
      expect([reserved(), pill()], everyElement(findsNothing));
      await close(tester);
    });

    testWidgets('gate closed (no upload right): no pill; an earlier album copy as plain text; the rows keep their marks', (tester) async {
      h.setUp(noUpload: true);
      h.fake.addJob(tapesAlbumRec(), scope: 'album', state: 'done', result: tapesAlbumResult(copied: ['01 - Rooftop Cypher.mp3']));
      await open(tester, tapes());
      expect(pill(), findsNothing);
      expect(find.byKey(const ValueKey('browse-keep-plain')), findsOneWidget);
      expect(find.text('In your collection'), findsOneWidget);
      expect(find.text('in your collection'), findsOneWidget, reason: "Rooftop Cypher's row");
      await close(tester);
    });

    testWidgets('gate closed, no copy: nothing at all', (tester) async {
      h.setUp(noUpload: true);
      await open(tester, tapes());
      expect([pill(), reserved(), find.byKey(const ValueKey('browse-keep-plain'))], everyElement(findsNothing));
      await close(tester);
    });

    testWidgets('a tap opens the album sheet (from the page: Open album left out); focus comes back to the pill', (tester) async {
      h.setUp();
      await open(tester, tapes());
      await tester.tap(pill());
      await tester.pump();
      await tester.pump();
      final r = h.opened.single;
      expect([r.subject, r.variant, r.initialScope, r.hidden, r.peerId, identical(r.own, h.home)],
          [KeepSubject.album, KeepVariant.page, 'album', {KeepHiddenLink.openAlbum}, 1, true]);
      expect(r.lead, tapesAlbumRec());
      expect(r.focusKey, '1|album|Borrowed Tapes|Boukmanflow');
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'keep 1|album|Borrowed Tapes|Boukmanflow');
      await close(tester);
    });

    testWidgets("the pill's node is the one focus comes back to, as a screen reader hears it", (tester) async {
      h.setUp();
      final handle = tester.ensureSemantics();
      await open(tester, tapes());
      await tester.tap(pill());
      await tester.pump();
      await tester.pump();
      expect(tester.getSemantics(pill()),
          isSemantics(label: 'Keep a copy of Borrowed Tapes…', isButton: true, isFocusable: true, isFocused: true));
      handle.dispose();
      await close(tester);
    });

    testWidgets("a compilation opened where no listing said so (its songs' artists are not its credit): the pill copies it whole, nobody's artist copy", (tester) async {
      h.setUp();
      h.routes['/api/v1/db/album-songs'] = [
        peerSong('music/Various Artists/Night Market Sampler/01.mp3', 'Lantern Street', artist: 'Color Out', album: 'Night Market Sampler', albumArtist: 'Various Artists', track: 1, year: 2024),
        peerSong('music/Various Artists/Night Market Sampler/02.mp3', 'Night Market Cypher', album: 'Night Market Sampler', albumArtist: 'Various Artists', track: 2, year: 2024),
      ];
      final hit = DisplayItem(h.peerB, 'Night Market Sampler', 'album', 'Night Market Sampler', null, null)..yearHint = 2024;
      await open(tester, hit, width: 600);
      await tester.tap(pill());
      await tester.pump();
      final r = h.opened.single;
      expect([r.lead['albumArtist'], r.lead.containsKey('artist'), r.compilation, r.songs?.length], ['Various Artists', false, true, 2]);
      await close(tester);
    });

    testWidgets("the banner's header node is the facts it reads: the cover beside them is not in it", (tester) async {
      h.setUp();
      final handle = tester.ensureSemantics();
      await open(tester, tapes(), width: 600);
      final node = tester.getSemantics(find.bySemanticsLabel('Borrowed Tapes').first);
      expect(node.getSemanticsData().flagsCollection.isHeader, isTrue);
      expect(node.rect.width, greaterThan(200), reason: 'the facts it reads, not the 86 pt cover');
      handle.dispose();
      await close(tester);
    });
  });

  testWidgets("focus falls back to the banner when the opener is gone once the sheet closes (the gate closed meanwhile)", (tester) async {
    h.setUp();
    await open(tester, tapes());
    h.sheetOpen = Completer<void>();
    await tester.tap(pill());
    await tester.pump();
    h.home.noUpload = true;
    h.sheetOpen!.complete();
    await BrowseHarness.frames(tester, 3);
    expect(pill(), findsNothing, reason: 'the page read the gate again');
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'album banner');
    await close(tester);
  });

  group('the pill and the rows carry the copies', () {
    testWidgets('kept: "In your collection"; each row its own word — failed never reads in your collection', (tester) async {
      h.setUp();
      h.fake.addJob(tapesAlbumRec(), scope: 'album', state: 'done', result: tapesAlbumResult(
        copied: ['01 - Rooftop Cypher.mp3', '02 - Late Train Verse.mp3'],
        failed: ['03 - Corner Store Loop.mp3'],
      ));
      final handle = tester.ensureSemantics();
      await open(tester, tapes());
      expect(find.text('In your collection'), findsOneWidget, reason: 'the pill');
      expect(find.text('in your collection'), findsNWidgets(2));
      expect(find.text('failed'), findsOneWidget);
      expect(find.bySemanticsLabel('02, Late Train Verse, in your collection'), findsOneWidget);
      expect(find.bySemanticsLabel('03, Corner Store Loop, failed'), findsOneWidget);
      handle.dispose();
      await close(tester);
    });

    testWidgets('while the album copy runs: "Copying 2 of 3", the live line and the bar; the rows say nothing', (tester) async {
      h.setUp();
      h.fake.addJob(tapesAlbumRec(), scope: 'album', state: 'running', progress: 0.6, statusText: '2 of 3 songs · 4.1 MB · Corner Store Loop');
      h.fake.addJob(tapesSongRec('02 - Late Train Verse.mp3', 'Late Train Verse', seconds: 8, credit: 'Boukmanflow'),
          state: 'done', result: {'copied': {'filepath': 'copies/x.mp3'}});
      await open(tester, tapes());
      expect(find.text('Copying 2 of 3'), findsOneWidget);
      expect(find.text('Copies keep going if you leave this page or Stage Peer B.'), findsOneWidget);
      expect(find.byKey(const ValueKey('browse-keep-bar')), findsOneWidget);
      expect(find.text('in your collection'), findsNothing, reason: 'rows do not guess while the album copies');
      await close(tester);
    });

    testWidgets("another server's live copy: \"Copying from Stage Peer C\" on the pill only, no live line, no bar", (tester) async {
      h.setUp();
      h.fake.addJob(tapesAlbumRec(peer: browsePeerC), scope: 'album', state: 'running', progress: 0.3, statusText: '1 of 3 songs');
      await open(tester, tapes());
      expect(find.text('Copying from Stage Peer C'), findsOneWidget);
      expect([find.byKey(const ValueKey('browse-keep-live-line')), find.byKey(const ValueKey('browse-keep-bar'))],
          everyElement(findsNothing));
      await close(tester);
    });
  });

  group('the songs', () {
    testWidgets('the ⋮ opens the track sheet: "Keep a copy…" after the queue verbs, before Download; its tap opens the song sheet with the page credit', (tester) async {
      h.setUp();
      await open(tester, tapes());
      await tester.tap(find.byTooltip('More actions for Late Train Verse'));
      await tester.pumpAndSettle();
      expect(find.text('To your server, from Stage Peer B'), findsOneWidget);
      final row = find.byKey(const ValueKey('browse-keep-menu-row'));
      final keepY = tester.getTopLeft(row).dy;
      expect(keepY, greaterThan(tester.getTopLeft(find.text('Play now')).dy));
      expect(keepY, lessThan(tester.getTopLeft(find.text('Download')).dy));
      await tester.tap(row);
      await tester.pumpAndSettle();
      final r = h.opened.single;
      expect([r.subject, r.variant, r.lead['albumArtist'], r.lead['filepath'], r.folder], [
        KeepSubject.song,
        KeepVariant.menu,
        'Boukmanflow',
        'music/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3',
        null,
      ]);
      expect(FocusManager.instance.primaryFocus?.debugLabel,
          'keep 1|song|music/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3',
          reason: 'focus back on the ⋮');
      await close(tester);
    });

    testWidgets("the track sheet's row for a screen reader: \"Keep a copy of {title}…\", its sub-line as the value, and it acts", (tester) async {
      h.setUp();
      final handle = tester.ensureSemantics();
      await open(tester, tapes());
      await tester.tap(find.byTooltip('More actions for Late Train Verse'));
      await tester.pumpAndSettle();
      final row = find.semantics.byLabel('Keep a copy of Late Train Verse…');
      expect(tester.getSemantics(find.byKey(const ValueKey('browse-keep-menu-row'))),
          isSemantics(label: 'Keep a copy of Late Train Verse…', value: 'To your server, from Stage Peer B', isButton: true));
      tester.semantics.tap(row);
      await tester.pumpAndSettle();
      expect(h.opened.single.subject, KeepSubject.song);
      handle.dispose();
      await close(tester);
    });

    testWidgets("during the album copy the track sheet's row says so: \"Copying Borrowed Tapes · 2 of 3\"", (tester) async {
      h.setUp();
      h.fake.addJob(tapesAlbumRec(), scope: 'album', state: 'running', progress: 0.6, statusText: '2 of 3 songs');
      await open(tester, tapes());
      await tester.tap(find.byTooltip('More actions for Late Train Verse'));
      await tester.pumpAndSettle();
      expect(find.text('Copying Borrowed Tapes · 2 of 3'), findsOneWidget);
      await close(tester);
    });

    testWidgets('gate closed: the track sheet has no Keep row', (tester) async {
      h.setUp(noUpload: true);
      await open(tester, tapes());
      await tester.tap(find.byTooltip('More actions for Late Train Verse'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('browse-keep-menu-row')), findsNothing);
      expect(find.text('Download'), findsOneWidget);
      await close(tester);
    });

    testWidgets("a song of a page whose songs disagree: its sheet is told so — no credit, the song's own album-artist not even a candidate", (tester) async {
      h.setUp();
      h.routes['/api/v1/db/album-songs'] = [
        peerSong('music/Split/01.mp3', 'One', artist: 'ALM', album: 'Split Series', albumArtist: 'ALM', track: 1),
        peerSong('music/Split/02.mp3', 'Two', artist: 'Night Owl Radio', album: 'Split Series', albumArtist: 'Night Owl Radio', track: 2),
      ];
      final split = DisplayItem(h.peerB, 'Split Series', 'album', 'Split Series', null, 'ALM, Night Owl Radio')
        ..creditState = AlbumCredit.disagree;
      await open(tester, split);
      await tester.tap(find.byTooltip('More actions for One'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('browse-keep-menu-row')));
      await tester.pumpAndSettle();
      final r = h.opened.single;
      expect([r.lead.containsKey('albumArtist'), r.pageCredit, r.songCredit], [false, AlbumCredit.disagree, null]);
      await close(tester);
    });

    testWidgets('a long-pressed row gets focus back itself — the ⋮ when the ⋮ opened it', (tester) async {
      h.setUp();
      await open(tester, tapes());
      await tester.longPress(find.text('Late Train Verse'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('browse-keep-menu-row')));
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel,
          'keep 1|song|music/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3|row');
      await close(tester);
    });

    testWidgets("a screen reader's Keep action on a row gets focus back on that row, the node it is on", (tester) async {
      h.setUp();
      final handle = tester.ensureSemantics();
      await open(tester, tapes());
      tester.semantics.customAction(find.semantics.byLabel('01, Rooftop Cypher'),
          const CustomSemanticsAction(label: 'Keep a copy of Rooftop Cypher…'));
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel,
          'keep 1|song|music/Boukmanflow/Borrowed Tapes/01 - Rooftop Cypher.mp3|row');
      expect(tester.getSemantics(find.bySemanticsLabel('01, Rooftop Cypher')), isSemantics(isFocused: true));
      handle.dispose();
      await close(tester);
    });

    testWidgets('gate closed: a row offers a screen reader no Keep action', (tester) async {
      h.setUp(noUpload: true);
      final handle = tester.ensureSemantics();
      await open(tester, tapes());
      final data = tester.getSemantics(find.bySemanticsLabel('01, Rooftop Cypher')).getSemanticsData();
      expect([
        for (final id in data.customSemanticsActionIds ?? const <int>[]) CustomSemanticsAction.getAction(id)!.label,
      ], isNot(contains('Keep a copy of Rooftop Cypher…')));
      handle.dispose();
      await close(tester);
    });

    testWidgets('a row offers a screen reader "Keep a copy of {title}…", which opens the song sheet', (tester) async {
      h.setUp();
      final handle = tester.ensureSemantics();
      await open(tester, tapes());
      final data = tester.getSemantics(find.bySemanticsLabel('01, Rooftop Cypher')).getSemanticsData();
      expect([data.hasAction(SemanticsAction.tap), data.hasAction(SemanticsAction.longPress)], [true, true],
          reason: "the row's own play and menu, on the same node");
      tester.semantics.customAction(find.semantics.byLabel('01, Rooftop Cypher'),
          const CustomSemanticsAction(label: 'Keep a copy of Rooftop Cypher…'));
      await tester.pumpAndSettle();
      expect(h.opened.single.lead['title'], 'Rooftop Cypher');
      handle.dispose();
      await close(tester);
    });
  });

  group('large text and small phones', () {
    testWidgets('above 1.3×: the pill under the cover at the full width', (tester) async {
      h.setUp();
      await open(tester, tapes(), width: 1200, textScale: 1.31);
      final cover = tester.getRect(find.byType(ClipRRect).first);
      expect(tester.getTopLeft(pill()).dy, greaterThan(cover.bottom));
      expect(tester.getSize(pill()).width, closeTo(1200 - 16 - 12, 1));
      await close(tester);
    });

    testWidgets('2.0× on a 360×780 phone: nothing overflows; the pill full width and two lines; marked rows grow a line', (tester) async {
      h.setUp();
      h.fake.addJob(tapesAlbumRec(peer: browsePeerC), scope: 'album', state: 'running', statusText: '1 of 3 songs');
      h.fake.addJob(tapesSongRec('01 - Rooftop Cypher.mp3', 'Rooftop Cypher', seconds: 12, credit: 'Boukmanflow'),
          state: 'done', result: {'copied': {'filepath': 'copies/x.mp3'}});
      await open(tester, tapes(), width: 360, height: 780, textScale: 2);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(pill()).width, closeTo(360 - 16 - 12, 1));
      expect(find.text('in your collection'), findsOneWidget);
      // the list is reachable: the banner scrolls away
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Corner Store Loop'), findsOneWidget);
      expect(banner(), findsOneWidget);
      await close(tester);
    });
  });
}
