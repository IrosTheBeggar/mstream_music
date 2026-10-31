// The explorer's folder sheet (spec §7; the ExplorerSheet,
// ExplorerSubfolders and ExplorerCollision boards) against the scripted
// server: it opens with the keyboard down, "Into Music › Daft Punk", the
// clipboard chip and the limits line, a disabled "Add here"; a found card
// reads SAVES HERE; Add here sends the folder on screen unchanged with no
// mkdir, stays open on "Starting…" until the server answers, closes on
// 200 and shows a refusal inside (the lost library without "Pick another
// library"); "Sort into subfolders…" turns the sheet to its second page —
// the locked folder, the choices, the preview's new folder, Done applying
// (SAVES TO, "Add to library"), back cancelling, Custom's refusals turning
// Done off, the bracket warning's "Edit tags" — and is hidden under
// noMkdir; the name check by tier; a re-ping closing the sheet; 360 dp at
// 200% without overflow.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/ytdl/ytdl_card_parts.dart';
import 'package:mstream_music/screens/ytdl/ytdl_crumbs.dart';
import 'package:mstream_music/screens/ytdl/ytdl_draft.dart';
import 'package:mstream_music/screens/ytdl/ytdl_folder_sheet.dart';
import 'package:mstream_music/screens/ytdl/ytdl_saves_block.dart';
import 'package:mstream_music/util/ytdl_layout.dart';

import '../singletons/ytdl_fakes.dart';
import 'ytdl_ui_fixtures.dart';

const here = '/Music/Daft Punk/';

void main() {
  final ui = YtdlUi();
  late Server s;

  setUp(() {
    ui.setUp();
    s = ytdlServer(formats: const ['mp3', 'm4a', 'opus', 'flac']);
  });
  tearDown(ui.tearDown);

  YtdlHarness h() => ui.h;

  String addLabel(WidgetTester t) => t
      .widget<Text>(
          find.descendant(of: byKey('ytdl-add'), matching: find.byType(Text)))
      .data!;

  bool enabled(WidgetTester t, String key) => t
          .widget<InkWell>(
              find.descendant(of: byKey(key), matching: find.byType(InkWell)))
          .onTap !=
      null;

  YtdlCrumbs crumbsIn(WidgetTester t, Finder of) => t.widget<YtdlCrumbs>(
      find.descendant(of: of, matching: find.byType(YtdlCrumbs)));

  Future<YtdlDraft> filled(WidgetTester t, [String link = kOneMoreTime]) async {
    h().fake.folder(here);
    final d = await ui.pumpSheet(t, s, here);
    await ui.paste(t, d, link);
    return d;
  }

  testWidgets('empty: the header, the chip, the limits line, Add here off; '
      'the keyboard down', (t) async {
    h().clipboard = kOneMoreTime;
    await ui.pumpSheet(t, s, here);
    final l = h().l;
    expect(find.text(l.ytdlTitle), findsOneWidget);
    final into = t.widget<YtdlCrumbLine>(find.byType(YtdlCrumbLine));
    expect(into.crumbs, ['Music', 'Daft Punk']);
    expect(into.prefix, 'Into ');
    expect(byKey('ytdl-paste'), findsOneWidget);
    expect(byKey('ytdl-limits'), findsOneWidget);
    expect(addLabel(t), l.ytdlAddHere);
    expect(enabled(t, 'ytdl-add'), isFalse);
    expect(FocusManager.instance.primaryFocus?.context?.widget,
        isNot(isA<EditableText>()));
    expect(byKey('ytdl-lands-change'), findsNothing);
  });

  testWidgets('filled: SAVES HERE in the folder on screen, Sort into subfolders…',
      (t) async {
    await filled(t);
    final l = h().l;
    expect(find.text(l.ytdlSavesHere.toUpperCase()), findsOneWidget);
    expect(crumbsIn(t, find.byType(YtdlSavesBlock)).crumbs,
        ['Music', 'Daft Punk']);
    expect(byKey('ytdl-saves-change'), findsNothing);
    expect(byKey('ytdl-sort-subfolders'), findsOneWidget);
    expect(addLabel(t), l.ytdlAddHere);
    expect(enabled(t, 'ytdl-add'), isTrue);
  });

  testWidgets('Add here: the folder unchanged, no mkdir; Starting…, then closes',
      (t) async {
    await filled(t);
    h().fake.addGate = Completer<void>();
    await t.tap(byKey('ytdl-add'));
    await ui.settle(t);
    expect(find.byType(YtdlFolderSheet), findsOneWidget);
    expect(addLabel(t), h().l.discoverJobStarting);
    h().fake.addGate!.complete();
    await ui.settle(t);
    await ui.settle(t);
    await t.pumpAndSettle();
    expect(h().fake.bodies('POST', '/api/v1/ytdl/').single['directory'], here);
    expect(h().fake.count('POST', '/file-explorer/mkdir'), 0);
    expect(find.byType(YtdlFolderSheet), findsNothing);
  });

  testWidgets('a 200 closes the sheet under the format menu opened meanwhile',
      (t) async {
    final d = await filled(t);
    h().fake.addGate = Completer<void>();
    await t.tap(byKey('ytdl-add'));
    await ui.settle(t);
    expect(d.addPhase, YtdlAddPhase.starting);
    await t.tap(byKey('ytdl-format'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(byKey('ytdl-format-menu'), findsOneWidget);
    h().fake.addGate!.complete();
    await ui.settle(t);
    await ui.settle(t);
    await t.pumpAndSettle();
    expect(byKey('ytdl-format-menu'), findsNothing);
    expect(find.byType(YtdlFolderSheet), findsNothing);
    expect(h().fake.count('POST', '/api/v1/ytdl/'), 1);
  });

  testWidgets('a failed lookup: the way to subfolders is still there',
      (t) async {
    h().fake.lookupRefusal = (500, 'Server Error');
    await filled(t);
    expect(byKey('ytdl-lookup-failed'), findsOneWidget);
    expect(byKey('ytdl-sort-subfolders'), findsOneWidget);
  });

  group('Choose a folder… (spec §1: never a sheet over a sheet)', () {
    /// Subfolders chosen, and the folder they need couldn't be made.
    Future<YtdlDraft> mkdirFailed(WidgetTester t) async {
      final d = await filled(t);
      h().fake.folder('/Music/Singles/');
      d.setSubLayout(kYtdlLayoutAlbum);
      await ui.settle(t, YtdlDraft.kCheckAfter);
      h().fake.mkdirRefusal = (500, 'EACCES');
      await t.tap(byKey('ytdl-add'));
      await ui.settle(t);
      await ui.settle(t);
      expect(byKey('ytdl-mkdir-choose'), findsOneWidget);
      return d;
    }

    /// The picker, noting whether the folder sheet was still there under
    /// it (its route, or its body sliding away).
    List<bool> picker(WidgetTester t, String? answer) {
      final route = ModalRoute.of(t.element(find.byType(YtdlFolderSheet)))!;
      final sheetUp = <bool>[];
      YtdlSheets.chooseFolder = (context, draft) async {
        sheetUp.add(route.isActive ||
            find.byType(YtdlFolderSheet).evaluate().isNotEmpty);
        return answer;
      };
      return sheetUp;
    }

    testWidgets('the sheet steps aside for the picker, then comes back with it',
        (t) async {
      final d = await mkdirFailed(t);
      final sheetUp = picker(t, '/Music/Singles/');
      await t.tap(byKey('ytdl-mkdir-choose'));
      await t.pumpAndSettle();
      await ui.settle(t, YtdlDraft.kCheckAfter);
      await t.pumpAndSettle();
      expect(sheetUp, [false]);
      expect(find.byType(YtdlFolderSheet), findsOneWidget);
      expect(d.attached, isTrue);
      expect(d.justThisSong, YtdlChoice.folder('/Music/Singles/'));
      expect(crumbsIn(t, find.byType(YtdlSavesBlock)).crumbs,
          ['Music', 'Singles']);
      expect(find.text(h().l.ytdlJustThisSong), findsOneWidget);
      expect(byKey('ytdl-add-error'), findsNothing);
    });

    testWidgets('cancelled: the sheet comes back as it was', (t) async {
      final d = await mkdirFailed(t);
      final sheetUp = picker(t, null);
      await t.tap(byKey('ytdl-mkdir-choose'));
      await t.pumpAndSettle();
      expect(sheetUp, [false]);
      expect(find.byType(YtdlFolderSheet), findsOneWidget);
      expect(d.justThisSong, isNull);
      expect(d.subLayout, kYtdlLayoutAlbum);
    });
  });

  testWidgets('a refusal shows inside; a lost library without "Pick another"',
      (t) async {
    await filled(t);
    h().fake.addRefusal = (404, "Library 'Music' not found");
    await t.tap(byKey('ytdl-add'));
    await ui.settle(t);
    await ui.settle(t);
    expect(find.byType(YtdlFolderSheet), findsOneWidget);
    expect(find.text(h().l.ytdlErrLibraryGoneSheet('Music')), findsOneWidget);
    expect(addLabel(t), h().l.ytdlAddHere);
  });

  testWidgets('✕ closes it; the draft stays for the folder', (t) async {
    final d = await filled(t);
    await t.tap(byKey('ytdl-sheet-close'));
    await t.pumpAndSettle();
    expect(find.byType(YtdlFolderSheet), findsNothing);
    expect(d.link.text, kOneMoreTime);
    expect(d.attached, isFalse);
  });

  group('every sheet starts at Right here (spec §7: not remembered)', () {
    /// Album chosen and applied on the second page.
    Future<YtdlDraft> album(WidgetTester t) async {
      final d = await filled(t);
      await tapIn(t, byKey('ytdl-sort-subfolders'));
      await t.pumpAndSettle();
      await t.tap(byKey('ytdl-sub-album'));
      await t.pump();
      await t.tap(byKey('ytdl-sub-done'));
      await ui.settle(t, YtdlDraft.kCheckAfter);
      expect(addLabel(t), h().l.ytdlAddToLibrary);
      return d;
    }

    /// The sheet for the same folder opened again (frames, not
    /// pumpAndSettle: a "Starting…" ring never settles).
    Future<void> reopen(WidgetTester t) async {
      unawaited(showYtdlFolderSheet(
          t.element(find.byType(Scaffold).first), s, here));
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      await ui.settle(t);
    }

    for (final (how, close) in [
      ('its ✕', (WidgetTester t) => t.tap(byKey('ytdl-sheet-close'))),
      (
        'a drag down',
        (WidgetTester t) =>
            t.drag(find.byType(YtdlFolderSheet), const Offset(0, 700)),
      ),
    ]) {
      testWidgets('closed with $how and opened again: Right here, "Add '
          'here"; the link and the lookup stay', (t) async {
        final d = await album(t);
        await close(t);
        await t.pumpAndSettle();
        expect(find.byType(YtdlFolderSheet), findsNothing);
        await reopen(t);
        expect(d.subLayout, kYtdlLayoutTop);
        expect(d.link.text, kOneMoreTime);
        expect(d.lookup, YtdlLookupState.found);
        expect(addLabel(t), h().l.ytdlAddHere);
        expect(find.text(h().l.ytdlSavesHere.toUpperCase()), findsOneWidget);
        expect(d.target.directory, here);
      });
    }

    testWidgets('closed while its add starts: that add goes where it was '
        'sent', (t) async {
      final d = await album(t);
      h().fake.addGate = Completer<void>();
      await t.tap(byKey('ytdl-add'));
      await ui.settle(t);
      expect(d.addPhase, YtdlAddPhase.starting);
      await t.tap(byKey('ytdl-sheet-close'));
      await t.pumpAndSettle();
      await reopen(t);
      expect(d.subLayout, kYtdlLayoutAlbum);
      h().fake.addGate!.complete();
      await ui.settle(t);
      await ui.settle(t);
      expect(h().fake.bodies('POST', '/api/v1/ytdl/').single['directory'],
          '${here}Discovery/');
      expect(d.subLayout, kYtdlLayoutTop, reason: 'the sent draft resets');
    });
  });

  group('the feature gone (spec §8: closes or opens nothing, saying why)', () {
    testWidgets('opened after a re-ping turned uploads off (a stale menu '
        'item): no sheet, the toast', (t) async {
      s.noUpload = true;
      await ui.pumpSheet(t, s, here);
      expect(find.byType(YtdlFolderSheet), findsNothing);
      expect(h().toastTexts, [h().l.ytdlErrUploadsOff]);
    });

    testWidgets('… conversion off says so', (t) async {
      s.transcodeAvailable = false;
      await ui.pumpSheet(t, s, here);
      expect(find.byType(YtdlFolderSheet), findsNothing);
      expect(h().toastTexts, [h().l.ytdlErrFfmpeg]);
    });

    testWidgets('gone while the picker stood in for the sheet: the sheet '
        'doesn\'t come back, and says why', (t) async {
      final d = await filled(t);
      d.setSubLayout(kYtdlLayoutAlbum);
      await ui.settle(t, YtdlDraft.kCheckAfter);
      h().fake.mkdirRefusal = (500, 'EACCES');
      await t.tap(byKey('ytdl-add'));
      await ui.settle(t);
      await ui.settle(t);
      // The picker: a re-ping lands while it is up, and it closes empty.
      YtdlSheets.chooseFolder = (context, draft) async {
        s.noUpload = true;
        await h().hub.stateFor(s).rememberFormat('mp3');
        return null;
      };
      await t.tap(byKey('ytdl-mkdir-choose'));
      await t.pumpAndSettle();
      await ui.settle(t);
      await t.pumpAndSettle();
      expect(find.byType(YtdlFolderSheet), findsNothing);
      expect(h().toastTexts, [h().l.ytdlErrUploadsOff]);
    });
  });

  group('Sort into subfolders (ExplorerSubfolders)', () {
    Future<YtdlDraft> page(WidgetTester t) async {
      final d = await filled(t);
      await tapIn(t, byKey('ytdl-sort-subfolders'));
      await t.pumpAndSettle();
      return d;
    }

    testWidgets('the locked folder, the choices; Album previews one new folder',
        (t) async {
      final d = await page(t);
      final l = h().l;
      expect(find.text(l.ytdlSubfoldersTitle), findsOneWidget);
      expect(find.text(l.ytdlSubfoldersHere), findsOneWidget);
      expect(byKey('ytdl-sub-here'), findsOneWidget);
      expect(byKey('ytdl-sub-album'), findsOneWidget);
      expect(byKey('ytdl-sub-artistAlbum'), findsOneWidget);
      expect(byKey('ytdl-sub-custom'), findsOneWidget);
      await t.tap(byKey('ytdl-sub-album'));
      await t.pump();
      await ui.settle(t, YtdlDraft.kCheckAfter);
      expect(find.text(l.ytdlSubfoldersNew(1, 'Discovery')), findsOneWidget);
      final preview = crumbsIn(t, byKey('ytdl-sub-preview'));
      expect(preview.crumbs, ['Music', 'Daft Punk', 'Discovery']);
      expect(preview.newAt, {2});
      expect(preview.file, 'One_More_Time.mp3');
      // Not applied until Done.
      expect(d.subLayout, kYtdlLayoutTop);
    });

    testWidgets('Done applies: SAVES TO and "Add to library"', (t) async {
      final d = await page(t);
      await t.tap(byKey('ytdl-sub-album'));
      await t.pump();
      await t.tap(byKey('ytdl-sub-done'));
      await ui.settle(t, YtdlDraft.kCheckAfter);
      expect(d.subLayout, kYtdlLayoutAlbum);
      expect(byKey('ytdl-sheet'), findsOneWidget);
      expect(find.text(h().l.ytdlSavesTo.toUpperCase()), findsOneWidget);
      expect(addLabel(t), h().l.ytdlAddToLibrary);
      expect(crumbsIn(t, find.byType(YtdlSavesBlock)).newAt, {2});
    });

    testWidgets('the preview follows the draft: a late lookup fills Album',
        (t) async {
      h().fake.holdLookups = true;
      h().fake.folder(here);
      final d = await ui.pumpSheet(t, s, here);
      d.link.text = kOneMoreTime;
      await ui.settle(t, YtdlDraft.kLookupDebounce);
      await ui.settle(t, YtdlDraft.kSlowAfter);
      await t.tap(byKey('ytdl-enter-yourself'));
      await t.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pump();
      await tapIn(t, byKey('ytdl-sort-subfolders'));
      await t.pumpAndSettle();
      await t.tap(byKey('ytdl-sub-album'));
      await t.pump();
      await ui.settle(t, YtdlDraft.kCheckAfter);
      expect(crumbsIn(t, byKey('ytdl-sub-preview')).crumbs,
          ['Music', 'Daft Punk']);
      for (final c in h().fake.heldLookups) {
        c.complete();
      }
      await ui.settle(t);
      await ui.settle(t, YtdlDraft.kCheckAfter);
      expect(d.controllerFor(YtdlField.album).text, 'Discovery');
      final preview = crumbsIn(t, byKey('ytdl-sub-preview'));
      expect(preview.crumbs, ['Music', 'Daft Punk', 'Discovery']);
      expect(preview.newAt, {2});
      expect(find.text(h().l.ytdlSubfoldersNew(1, 'Discovery')),
          findsOneWidget);
    });

    testWidgets('Done gives way over a folder chosen for this song', (t) async {
      final d = await filled(t);
      h().fake.folder('/Music/Singles/');
      d.useFolder('/Music/Singles/');
      await ui.settle(t, YtdlDraft.kCheckAfter);
      expect(d.target.directory, '/Music/Singles/');
      await tapIn(t, byKey('ytdl-sort-subfolders'));
      await t.pumpAndSettle();
      await t.tap(byKey('ytdl-sub-album'));
      await t.pump();
      await t.tap(byKey('ytdl-sub-done'));
      await ui.settle(t, YtdlDraft.kCheckAfter);
      expect(d.justThisSong, isNull);
      expect(d.target.directory, '/Music/Daft Punk/Discovery/');
      expect(crumbsIn(t, find.byType(YtdlSavesBlock)).crumbs,
          ['Music', 'Daft Punk', 'Discovery']);
    });

    testWidgets('back cancels: the first page keeps its choice', (t) async {
      final d = await page(t);
      await t.tap(byKey('ytdl-sub-artistAlbum'));
      await t.pump();
      await t.tap(byKey('ytdl-sub-back'));
      await t.pumpAndSettle();
      expect(d.subLayout, kYtdlLayoutTop);
      expect(byKey('ytdl-sheet'), findsOneWidget);
      expect(find.byType(YtdlFolderSheet), findsOneWidget);
    });

    testWidgets('Custom: each refusal turns Done off and the preview to Fix',
        (t) async {
      await page(t);
      final l = h().l;
      await t.tap(byKey('ytdl-sub-custom'));
      await t.pump();
      const vars = 'ARTIST, ALBUMARTIST, ALBUM, YEAR';
      for (final (typed, words) in [
        ('{{ARTIST}}/{{TITLE}}', l.discoverDestErrUnknownVar('{{TITLE}}', vars)),
        ('{{GENRE}}/{{ARTIST}}', l.ytdlErrNeverVar('{{GENRE}}', vars)),
        ('Singles: 2024', l.ytdlErrBadChars),
      ]) {
        await t.enterText(byKey('ytdl-sub-custom-field'), typed);
        await t.pump();
        expect(find.text(words), findsOneWidget, reason: typed);
        expect(find.text(l.discoverDestFixLayout), findsOneWidget);
        expect(enabled(t, 'ytdl-sub-done'), isFalse);
      }
      await t.enterText(byKey('ytdl-sub-custom-field'), '{{ARTIST}}/Singles');
      await t.pump();
      expect(enabled(t, 'ytdl-sub-done'), isTrue);
      expect(byKey('ytdl-sub-custom-error'), findsNothing);
    });

    testWidgets('a variable chip inserts at the caret and ticks', (t) async {
      await page(t);
      await t.tap(byKey('ytdl-sub-custom'));
      await t.pump();
      await tapIn(t, byKey('ytdl-var-ALBUM'));
      await t.pump();
      final field = t.widget<TextField>(byKey('ytdl-sub-custom-field'));
      expect(field.controller!.text, '{{ALBUM}}');
      expect(
          find.descendant(
              of: byKey('ytdl-var-ALBUM'), matching: find.byIcon(Icons.check)),
          findsOneWidget);
    });

    testWidgets('the bracket warning\'s Edit tags applies it and focuses Album',
        (t) async {
      final d = await filled(t, kFeelGood);
      await tapIn(t, byKey('ytdl-sort-subfolders'));
      await t.pumpAndSettle();
      await t.tap(byKey('ytdl-sub-custom'));
      await t.pump();
      await t.enterText(
          byKey('ytdl-sub-custom-field'), '{{ARTIST}} - {{ALBUM}}');
      await t.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pump();
      expect(byKey('ytdl-sub-trap-link'), findsOneWidget);
      await tapIn(t, byKey('ytdl-sub-trap-link'));
      await t.pump();
      await t.pump();
      expect(d.subLayout, '{{ARTIST}} - {{ALBUM}}');
      expect(byKey('ytdl-sheet'), findsOneWidget);
      expect(d.focusFor(YtdlField.album).hasFocus, isTrue);
    });
  });

  testWidgets('noMkdir: no Sort into subfolders…', (t) async {
    s = ytdlServer(noMkdir: true);
    await filled(t);
    expect(byKey('ytdl-sort-subfolders'), findsNothing);
    expect(byKey('ytdl-nomkdir'), findsNothing);
  });

  group('the name check (ExplorerCollision)', () {
    const name = 'Gorillaz_-_Feel_Good_Inc._Official_Video_HD.mp3';

    testWidgets('6.30+: the warning and an outlined Add anyway', (t) async {
      h().fake.folder('/Music/Gorillaz/', files: [name]);
      final d = await ui.pumpSheet(t, s, '/Music/Gorillaz/');
      await ui.paste(t, d, kFeelGood);
      expect(find.text(h().l.ytdlClash(name)), findsOneWidget);
      expect(addLabel(t), h().l.ytdlAddAnyway);
      expect(enabled(t, 'ytdl-add'), isTrue);
      expect(byKey('ytdl-sort-subfolders'), findsOneWidget);
    });

    testWidgets('older: re-tag warning with Change format and Sort…, Add off',
        (t) async {
      h().fake.hasRecords = false;
      h().fake.folder('/Music/Gorillaz/', files: [name]);
      final d = await ui.pumpSheet(t, s, '/Music/Gorillaz/');
      await ui.paste(t, d, kFeelGood);
      expect(find.text(h().l.ytdlClashOlder(name)), findsOneWidget);
      expect(byKey('ytdl-clash-format'), findsOneWidget);
      expect(byKey('ytdl-clash-sort'), findsOneWidget);
      // One way to the second page, inside the panel.
      expect(byKey('ytdl-sort-subfolders'), findsNothing);
      expect(addLabel(t), h().l.ytdlAddHere);
      expect(enabled(t, 'ytdl-add'), isFalse);
      await tapIn(t, byKey('ytdl-clash-sort'));
      await t.pumpAndSettle();
      expect(byKey('ytdl-subfolders'), findsOneWidget);
    });
  });

  testWidgets('a re-ping that turns conversion off closes the sheet', (t) async {
    await filled(t);
    s.transcodeAvailable = false;
    await h().hub.stateFor(s).rememberFormat('mp3');
    await t.pumpAndSettle();
    expect(find.byType(YtdlFolderSheet), findsNothing);
    expect(h().toastTexts, [h().l.ytdlErrFfmpeg]);
  });

  testWidgets('360 dp at 200%: both pages fit', (t) async {
    h().fake.folder(here);
    final d = await ui.pumpSheet(t, s, here,
        size: const Size(360, 800), textScale: 2);
    await ui.paste(t, d, kOneMoreTime);
    expect(t.takeException(), isNull);
    await tapIn(t, byKey('ytdl-sort-subfolders'));
    await t.pumpAndSettle();
    await t.tap(byKey('ytdl-sub-custom'));
    await t.pump();
    expect(t.takeException(), isNull);
  });
}
