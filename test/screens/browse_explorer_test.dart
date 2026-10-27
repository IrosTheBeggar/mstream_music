// A connected server's file explorer, Recent and home while browsing it (the
// phone spec's §4.5, §4.6, §4.1.4, §4.1.5, §5.4 and Q7): the open folder's
// compact header below a library's root — with the gate closed only for an
// earlier copy of the folder — the folder sheet's "Keep a copy…" under Add
// All (never on a library at `/`), a folder row's mark and the extent it
// grows, the letter strip's jump past the header and the scroll held still
// when marks land above the thumb, the path strip cut from its head, the
// file rows' track sheet (with the Folder choice below a library's root),
// the long-press rows' screen-reader actions, the one-time hint, and the
// Copies card on the connected server's home.

import 'dart:async';

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/metadata.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/browser.dart';
import 'package:mstream_music/screens/discovery/copies_hub.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/singletons/settings.dart';
import 'package:mstream_music/singletons/api.dart';
import 'package:mstream_music/util/browse_keep_leads.dart';
import 'package:mstream_music/widgets/browse_keep_entry.dart';
import 'package:mstream_music/widgets/letter_strip.dart';

import 'browse_keep_fixtures.dart';
import 'discovery_keep_fixtures.dart' show mockPathProvider;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final h = BrowseHarness();

  setUpAll(mockPathProvider);
  tearDown(h.tearDown);

  DisplayItem dir(Server s, String path) =>
      DisplayItem(s, path.split('/').last, 'directory', path, Icon(Icons.folder), null);

  DisplayItem file(Server s, String path, {String? title, String artist = 'Boukmanflow', String album = 'Borrowed Tapes'}) {
    final item = DisplayItem(s, path.split('/').last, 'file', path, Icon(Icons.music_note), null);
    if (title != null) {
      item.metadata = MusicMetadata.fromServerMap({'title': title, 'artist': artist, 'album': album, 'year': 2019, 'duration': 8});
    }
    return item;
  }

  Map<String, dynamic> folderRec(String path) =>
      {'source': 'federation', 'peer': browsePeerB, 'filepath': path, 'title': path.split('/').last};

  /// The connected server's home, then [rows] pushed as the explorer's
  /// [path] (the server's form: a slash at each end).
  Future<void> openFolder(WidgetTester tester, List<DisplayItem> rows, String path,
      {double width = 390, double height = 844, double textScale = 1, bool gate = true, Server? on, bool accessible = false}) async {
    ServerManager().currentServer = on ?? h.peerB;
    if (gate) await h.openGate();
    BrowserManager().goToNavScreen();
    await h.pump(tester, const Browser(), width: width, height: height, textScale: textScale, accessible: accessible);
    BrowserManager().setBrowserLabel('File Explorer');
    BrowserManager().addListToStack(rows, alphabetical: true, path: path);
    await BrowseHarness.frames(tester);
    // the rows' marks ask once the scroll settles
    await tester.pump(const Duration(milliseconds: 300));
    await BrowseHarness.frames(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  List<DisplayItem> boukmanflow() => [
        for (final n in ['Borrowed Tapes', 'Harbour Lights', 'Second Shift']) dir(h.peerB, '/music/Boukmanflow/$n'),
      ];

  Finder header() => find.byKey(const ValueKey('browse-folder-header'));
  Finder headLine() => find.byKey(const ValueKey('browse-folder-head-text'));
  Finder pill() => find.byKey(const ValueKey('browse-keep-pill'));
  Finder menuRow() => find.byKey(const ValueKey('browse-keep-menu-row'));
  // A row is its Slidable and the 1 pt rule under it.
  double rowHeight(WidgetTester tester, String name) =>
      tester.getSize(find.ancestor(of: find.text(name), matching: find.byType(Slidable)).first).height + 1;

  group('the open folder', () {
    testWidgets('a library root has no header; its folder rows\' sheet has Add All, then Keep a copy… (2-line title)', (tester) async {
      h.setUp();
      await openFolder(tester, [
        for (final n in ['ALM', 'Boukmanflow', 'Color Out']) dir(h.peerB, '/music/$n'),
      ], '/music/');
      expect(header(), findsNothing);
      await tester.longPress(find.text('Boukmanflow'));
      await tester.pumpAndSettle();
      expect(find.text('Add All'), findsOneWidget);
      expect(menuRow(), findsOneWidget);
      expect(find.text('To your server, from Stage Peer B'), findsOneWidget);
      expect(tester.widget<Text>(find.descendant(of: find.byType(BottomSheet), matching: find.text('Boukmanflow'))).maxLines, 2);
      expect(tester.getTopLeft(menuRow()).dy, greaterThan(tester.getTopLeft(find.text('Add All')).dy));
      await tester.tap(menuRow());
      await tester.pumpAndSettle();
      final r = h.opened.single;
      expect([r.subject, r.variant, r.folder?.path, r.lead], [
        KeepSubject.folder,
        KeepVariant.menu,
        '/music/Boukmanflow',
        folderRec('music/Boukmanflow'),
      ]);
      await close(tester);
    });

    // The test font draws every glyph a full em wide: the row that leaves
    // the text 150 pt beside the pill is wider than a phone's here, and the
    // one with room for the whole line (no server's name cut) wider still.
    testWidgets('below it: "Boukmanflow · Folder on Stage Peer B · 3 folders" and the pill, which opens the folder sheet from the page', (tester) async {
      h.setUp();
      await openFolder(tester, boukmanflow(), '/music/Boukmanflow/', width: 800);
      expect(header(), findsOneWidget);
      final text = find.textContaining('Folder on Stage Peer B · 3\u00A0folders');
      expect(text, findsOneWidget);
      expect(tester.getSize(header()).height, lessThan(80), reason: 'a compact row');
      expect(tester.getTopLeft(pill()).dx, greaterThan(tester.getRect(text).right), reason: 'beside its text');
      await tester.tap(pill());
      await tester.pumpAndSettle();
      final r = h.opened.single;
      expect([r.subject, r.variant, r.folder?.name, r.focusKey],
          [KeepSubject.folder, KeepVariant.page, 'Boukmanflow', '1|folder|/music/Boukmanflow']);
      await close(tester);
    });

    testWidgets("a folder of songs counts them, not its .m3u: \"Folder on Stage Peer B · 3 songs\"", (tester) async {
      h.setUp();
      await openFolder(tester, [
        for (final (i, t) in ['Rooftop Cypher', 'Late Train Verse', 'Corner Store Loop'].indexed)
          file(h.peerB, '/music/Boukmanflow/Borrowed Tapes/0${i + 1} - $t.mp3', title: t),
        file(h.peerB, '/music/Boukmanflow/Borrowed Tapes/tapes.m3u'),
      ], '/music/Boukmanflow/Borrowed Tapes/');
      expect(find.textContaining('Folder on Stage Peer B · 3\u00A0songs'), findsOneWidget);
      await close(tester);
    });

    testWidgets('gate closed: no header and no Keep row — unless the folder has an earlier copy, as plain text', (tester) async {
      h.setUp(noUpload: true);
      h.fake.addJob(folderRec('music/Boukmanflow/Borrowed Tapes'), scope: 'folder', state: 'done', result: {
        'scope': 'folder',
        'folder': {'path': 'music/Boukmanflow/Borrowed Tapes', 'name': 'Borrowed Tapes', 'landed': 'copies/Boukmanflow/Borrowed Tapes'},
        'songs': {'total': 3, 'copied': [{}, {}, {}], 'skipped': [], 'failed': []},
        'counts': {'total': 3, 'copied': 3, 'skipped': 0, 'failed': 0},
        'skippedFiles': 0,
        'stopped': null,
      });
      await openFolder(tester, boukmanflow(), '/music/Boukmanflow/');
      expect(header(), findsNothing, reason: 'no copy of Boukmanflow itself');
      expect(find.text('in your collection'), findsOneWidget, reason: "Borrowed Tapes' row keeps its mark");
      await tester.longPress(find.text('Borrowed Tapes'));
      await tester.pumpAndSettle();
      expect(find.text('Add All'), findsOneWidget);
      expect(menuRow(), findsNothing);
      await close(tester);

      await openFolder(tester, [
        file(h.peerB, '/music/Boukmanflow/Borrowed Tapes/01 - Rooftop Cypher.mp3', title: 'Rooftop Cypher'),
      ], '/music/Boukmanflow/Borrowed Tapes/');
      expect(header(), findsOneWidget);
      expect(pill(), findsNothing);
      expect(find.byKey(const ValueKey('browse-keep-plain')), findsOneWidget);
      await close(tester);
    });

    testWidgets('2.0× on a 360×780 phone: a long-named folder\'s sheet with its Keep row scrolls, never overflows', (tester) async {
      h.setUp();
      await openFolder(tester, [
        dir(h.peerB, '/music/The Boukmanflow Collective & Friends/Free Instrumentals Vol. 9 (Deluxe Remastered Edition)'),
      ], '/music/The Boukmanflow Collective & Friends/', width: 360, height: 780, textScale: 2);
      await tester.longPress(find.textContaining('Free Instrumentals').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('browse-folder-sheet')), findsOneWidget);
      await tester.dragUntilVisible(menuRow(), find.byKey(const ValueKey('browse-folder-sheet')), const Offset(0, -80));
      expect(menuRow(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await close(tester);
    });

    testWidgets("a server's top with several libraries: its library rows get Add All only", (tester) async {
      h.setUp();
      await openFolder(tester, [dir(h.peerC, '/live sets'), dir(h.peerC, '/music')], '/', on: h.peerC);
      expect(header(), findsNothing);
      await tester.longPress(find.text('music'));
      await tester.pumpAndSettle();
      expect(find.text('Add All'), findsOneWidget);
      expect(menuRow(), findsNothing);
      await close(tester);
    });

    testWidgets('the path strip is cut from its head; a screen reader hears it whole', (tester) async {
      h.setUp();
      final handle = tester.ensureSemantics();
      await openFolder(tester, [
        file(h.peerB, '/music/Various Artists/Night Market Sampler/01.mp3', title: 'Lantern Street'),
      ], '/music/Various Artists/Night Market Sampler/', width: 360, height: 780);
      final strip = tester.widget<Text>(find.byKey(const ValueKey('browser-path-strip')));
      expect(strip.data, startsWith('…/'));
      expect(strip.data, endsWith('Night Market Sampler/'));
      // Monospaced on iOS too, which has no 'monospace' family.
      expect(strip.style!.fontFamilyFallback, contains('Menlo'));
      expect(find.bySemanticsLabel('/music/Various Artists/Night Market Sampler/'), findsOneWidget);
      handle.dispose();
      await close(tester);
    });
  });

  group('folder rows carry their folder copies', () {
    testWidgets('"copying 2 of 3" as its subtitle — its row grows to 74, the others stay 58; its sheet says so', (tester) async {
      h.setUp();
      h.fake.addJob(folderRec('music/Boukmanflow/Borrowed Tapes'), scope: 'folder', state: 'running', progress: 0.6, statusText: '2 of 3 songs · 4.1 MB');
      await openFolder(tester, boukmanflow(), '/music/Boukmanflow/');
      expect(find.text('copying 2 of 3'), findsOneWidget);
      expect(rowHeight(tester, 'Borrowed Tapes'), 74);
      expect(rowHeight(tester, 'Harbour Lights'), 58);
      await tester.longPress(find.text('Borrowed Tapes'));
      await tester.pumpAndSettle();
      expect(find.text('Copying 2 of 3'), findsOneWidget);
      await close(tester);
    });

    testWidgets('a folder kept as an album shows nothing', (tester) async {
      h.setUp();
      h.fake.addJob(tapesAlbumRec(), scope: 'album', state: 'done', result: tapesAlbumResult(copied: ['01 - Rooftop Cypher.mp3']));
      await openFolder(tester, boukmanflow(), '/music/Boukmanflow/');
      expect(find.text('in your collection'), findsNothing);
      expect(rowHeight(tester, 'Borrowed Tapes'), 58);
      await close(tester);
    });

    testWidgets("the letter strip's jump lands past the header, counting a marked row's extent", (tester) async {
      h.setUp();
      SettingsManager().letterStripThreshold = 5;
      addTearDown(() => SettingsManager().letterStripThreshold = 25);
      final rows = [for (var i = 0; i < 30; i++) dir(h.peerB, '/music/Boukmanflow/F${i.toString().padLeft(2, '0')}')];
      h.fake.addJob(folderRec('music/Boukmanflow/F01'), scope: 'folder', state: 'running', statusText: '1 of 3 songs');
      await openFolder(tester, rows, '/music/Boukmanflow/');
      expect(find.byType(LetterStrip), findsOneWidget);
      final top = tester.getSize(header()).height;
      tester.widget<LetterStrip>(find.byType(LetterStrip)).onJump(10);
      await tester.pump();
      expect(BrowserManager().sc.offset, closeTo(top + 9 * 58 + 74, 0.5));
      await close(tester);
    });

    testWidgets('marks that land above the first row on screen move the scroll by what they grew: the row under the thumb stays', (tester) async {
      h.setUp();
      final rows = [for (var i = 0; i < 40; i++) dir(h.peerB, '/music/Boukmanflow/F${i.toString().padLeft(2, '0')}')];
      h.fake.addJob(folderRec('music/Boukmanflow/F01'), scope: 'folder', state: 'done', result: {
        'scope': 'folder',
        'songs': {'total': 1, 'copied': [{}], 'skipped': [], 'failed': []},
        'counts': {'total': 1, 'copied': 1, 'skipped': 0, 'failed': 0},
        'stopped': null,
      });
      h.fake.lookupGate = Completer<void>();
      await openFolder(tester, rows, '/music/Boukmanflow/');
      BrowserManager().sc.jumpTo(600);
      await tester.pump();
      final under = tester.getTopLeft(find.text('F12')).dy;
      h.fake.lookupGate!.complete();
      h.fake.lookupGate = null;
      await BrowseHarness.frames(tester);
      expect(find.text('in your collection'), findsNothing, reason: 'F01 is off screen');
      expect(BrowserManager().sc.offset, closeTo(616, 0.5));
      expect(tester.getTopLeft(find.text('F12')).dy, closeTo(under, 0.5));
      await close(tester);
    });

    testWidgets('2.0× on a 360×780 phone: the header\'s pill under its text, rows 116 / 148, nothing overflows', (tester) async {
      h.setUp();
      h.fake.addJob(folderRec('music/Boukmanflow/Borrowed Tapes'), scope: 'folder', state: 'running', statusText: '2 of 3 songs');
      await openFolder(tester, boukmanflow(), '/music/Boukmanflow/', width: 360, height: 780, textScale: 2);
      expect(tester.takeException(), isNull);
      final text = tester.getRect(headLine());
      expect(tester.getTopLeft(pill()).dy, greaterThan(text.bottom));
      // Its count drawn whole, whatever of the rest gave way.
      final line = tester.renderObject<RenderParagraph>(find.descendant(of: headLine(), matching: find.byType(RichText)));
      expect(line.text.toPlainText(), endsWith(' 3\u00A0folders'));
      expect(line.didExceedMaxLines, isFalse);
      expect(rowHeight(tester, 'Harbour Lights'), 116);
      expect(rowHeight(tester, 'Borrowed Tapes'), 148);
      await close(tester);
    });
  });

  group('songs', () {
    testWidgets("a file row's track sheet: Keep a copy… with the folder it sits in; at a library's root, no folder", (tester) async {
      h.setUp();
      await openFolder(tester, [
        file(h.peerB, '/music/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3', title: 'Late Train Verse'),
      ], '/music/Boukmanflow/Borrowed Tapes/');
      await tester.longPress(find.text('Late Train Verse'));
      await tester.pumpAndSettle();
      expect(menuRow(), findsOneWidget);
      await tester.tap(menuRow());
      await tester.pumpAndSettle();
      final r = h.opened.single;
      expect([r.subject, r.variant, r.folder?.path, r.lead['filepath'], r.lead['artist']], [
        KeepSubject.song,
        KeepVariant.menu,
        '/music/Boukmanflow/Borrowed Tapes',
        'music/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3',
        'Boukmanflow',
      ]);
      await close(tester);

      h.opened.clear();
      await openFolder(tester, [file(h.peerB, '/music/loose.mp3', title: 'Loose')], '/music/');
      await tester.longPress(find.text('Loose'));
      await tester.pumpAndSettle();
      await tester.tap(menuRow());
      await tester.pumpAndSettle();
      expect(h.opened.single.folder, isNull);
      await close(tester);
    });

    testWidgets('Recent: the Keep row, never a Folder choice', (tester) async {
      h.setUp();
      await h.openGate();
      BrowserManager().goToNavScreen();
      await h.pump(tester, const Browser());
      BrowserManager().setBrowserLabel('Recent');
      BrowserManager().addListToStack([
        file(h.peerB, '/music/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3', title: 'Late Train Verse'),
      ]);
      await BrowseHarness.frames(tester);
      await tester.longPress(find.text('Late Train Verse'));
      await tester.pumpAndSettle();
      await tester.tap(menuRow());
      await tester.pumpAndSettle();
      expect([h.opened.single.subject, h.opened.single.folder], [KeepSubject.song, null]);
      await close(tester);
    });

    testWidgets("a long-press row's screen-reader actions: More actions for it, and Keep a copy… straight to its sheet", (tester) async {
      h.setUp();
      final handle = tester.ensureSemantics();
      await openFolder(tester, [
        dir(h.peerB, '/music/Boukmanflow/Borrowed Tapes/Bonus'),
        file(h.peerB, '/music/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3', title: 'Late Train Verse'),
      ], '/music/Boukmanflow/Borrowed Tapes/');
      tester.semantics.customAction(find.semantics.byLabel(RegExp('^Late Train Verse')),
          const CustomSemanticsAction(label: 'Keep a copy of Late Train Verse…'));
      await tester.pumpAndSettle();
      expect(h.opened.single.subject, KeepSubject.song);
      tester.semantics.customAction(find.semantics.byLabel(RegExp('^Bonus')),
          const CustomSemanticsAction(label: 'Keep a copy of the folder Bonus…'));
      await tester.pumpAndSettle();
      expect(h.opened.last.subject, KeepSubject.folder);
      tester.semantics.customAction(find.semantics.byLabel(RegExp('^Bonus')),
          const CustomSemanticsAction(label: 'More for the folder Bonus'));
      await tester.pumpAndSettle();
      expect(find.text('Add All'), findsOneWidget);
      handle.dispose();
      await close(tester);
    });

    List<String> actionsOf(WidgetTester tester, Pattern label) => [
          for (final id in tester.getSemantics(find.bySemanticsLabel(label)).getSemanticsData().customSemanticsActionIds ??
              const <int>[])
            CustomSemanticsAction.getAction(id)!.label!,
        ];

    testWidgets('gate closed: a folder row and a file row offer a screen reader their menu only, no Keep a copy…', (tester) async {
      h.setUp(noUpload: true);
      final handle = tester.ensureSemantics();
      await openFolder(tester, [
        dir(h.peerB, '/music/Boukmanflow/Borrowed Tapes/Bonus'),
        file(h.peerB, '/music/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3', title: 'Late Train Verse'),
      ], '/music/Boukmanflow/Borrowed Tapes/');
      expect(actionsOf(tester, RegExp('^Bonus')), ['More for the folder Bonus']);
      expect(actionsOf(tester, RegExp('^Late Train Verse')), ['More actions for Late Train Verse']);
      handle.dispose();
      await close(tester);
    });

    testWidgets("focus comes back to a file row's own node — the one a screen reader hears, with its name and actions", (tester) async {
      h.setUp();
      final handle = tester.ensureSemantics();
      await openFolder(tester, [
        file(h.peerB, '/music/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3', title: 'Late Train Verse'),
      ], '/music/Boukmanflow/Borrowed Tapes/');
      tester.semantics.customAction(find.semantics.byLabel(RegExp('^Late Train Verse')),
          const CustomSemanticsAction(label: 'Keep a copy of Late Train Verse…'));
      await tester.pumpAndSettle();
      expect(tester.getSemantics(find.bySemanticsLabel(RegExp('^Late Train Verse'))), isSemantics(isFocused: true));
      expect(actionsOf(tester, RegExp('^Late Train Verse')), contains('Keep a copy of Late Train Verse…'));
      handle.dispose();
      await close(tester);
    });

    testWidgets('the one-time hint: the first song list with the gate open, once per install; never under a screen reader', (tester) async {
      h.setUp();
      SettingsManager().keepBrowseHintShown = false;
      final songs = [
        file(h.peerB, '/music/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3', title: 'Late Train Verse'),
      ];
      await openFolder(tester, boukmanflow(), '/music/Boukmanflow/');
      expect(h.toasts, isEmpty, reason: 'folders only: no song to long-press');
      BrowserManager().addListToStack(songs, alphabetical: true, path: '/music/Boukmanflow/Borrowed Tapes/');
      await BrowseHarness.frames(tester);
      expect(h.toasts, ['Long-press a song to keep a copy of it on your server.']);
      expect(SettingsManager().keepBrowseHintShown, isTrue);
      BrowserManager().popBrowser();
      await BrowseHarness.frames(tester);
      BrowserManager().addListToStack(songs, alphabetical: true, path: '/music/Boukmanflow/Borrowed Tapes/');
      await BrowseHarness.frames(tester);
      expect(h.toasts, hasLength(1));
      await close(tester);

      SettingsManager().keepBrowseHintShown = false;
      await openFolder(tester, songs, '/music/Boukmanflow/Borrowed Tapes/', accessible: true);
      expect(h.toasts, hasLength(1), reason: "a screen reader hears the rows' own actions");
      expect(SettingsManager().keepBrowseHintShown, isFalse);
      await close(tester);
    });

    testWidgets("a song row's sheet asks its own copy once, and its line says it: \"In your collection\"", (tester) async {
      h.setUp();
      h.fake.addJob(tapesSongRec('02 - Late Train Verse.mp3', 'Late Train Verse', seconds: 8),
          state: 'done', result: {'copied': {'filepath': 'copies/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3'}});
      await openFolder(tester, [
        file(h.peerB, '/music/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3', title: 'Late Train Verse'),
      ], '/music/Boukmanflow/Borrowed Tapes/');
      await tester.longPress(find.text('Late Train Verse'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: menuRow(), matching: find.text('In your collection')), findsOneWidget);
      await close(tester);
    });

    testWidgets("an untagged file row's sheet finds its copy by its tags (as the Keep sheet starts it), never by its file name", (tester) async {
      h.setUp();
      final read = <String>[];
      KeepMenuState.readTags = (peer, filepath) async {
        read.add(filepath);
        return MusicMetadata.fromServerMap({'title': 'Late Train Verse', 'artist': 'Boukmanflow', 'album': 'Borrowed Tapes', 'year': 2019, 'duration': 8});
      };
      addTearDown(() => KeepMenuState.readTags = (peer, filepath) => ApiManager().fetchTrackMetadata(peer, filepath));
      h.fake.addJob(tapesSongRec('02 - Late Train Verse.mp3', 'Late Train Verse', seconds: 8),
          state: 'done', result: {'copied': {'filepath': 'copies/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3'}});
      await openFolder(tester, [
        file(h.peerB, '/music/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3'),
      ], '/music/Boukmanflow/Borrowed Tapes/');
      await tester.longPress(find.text('02 - Late Train Verse.mp3'));
      await tester.pumpAndSettle();
      expect(read, ['music/Boukmanflow/Borrowed Tapes/02 - Late Train Verse.mp3']);
      expect(find.descendant(of: menuRow(), matching: find.text('In your collection')), findsOneWidget);
      await close(tester);
    });
  });

  group("the connected server's home", () {
    testWidgets('a Copies card — the copies on your own server — whose sheet offers no Discover', (tester) async {
      h.setUp();
      BrowserManager.homeCopiesRow = CopiesHub().showsHomeRow;
      await h.openGate();
      BrowserManager().goToNavScreen();
      await h.pump(tester, const Browser());
      await BrowseHarness.frames(tester);
      expect(find.text('Copies'), findsOneWidget);
      await tester.tap(find.text('Copies'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing copying'), findsOneWidget);
      expect(find.text('Open Discover'), findsNothing);
      await close(tester);
    });

    testWidgets('no Copies card where copies are not possible (no upload right)', (tester) async {
      h.setUp(noUpload: true);
      BrowserManager.homeCopiesRow = CopiesHub().showsHomeRow;
      await h.openGate();
      BrowserManager().goToNavScreen();
      await h.pump(tester, const Browser());
      await BrowseHarness.frames(tester);
      expect(find.text('Copies'), findsNothing);
      await close(tester);
    });
  });
}
