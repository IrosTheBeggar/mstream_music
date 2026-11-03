// The result card (spec §3, §4, §8; the FoundMusic, FoundCleaned,
// ChannelGuess, NoMkdir and LinkStates boards) on the screen, against the
// scripted server: each tier's source line and helpers (YouTube Music; the
// split, cleaned, with its restore chips, Undo all and Swap; YouTube's
// artist with the tags open by themselves and "↶ VEVO"), "Edited" and each
// blank field's line, the year rule, SAVES TO (new folders, the file name
// cut in the middle — measured with the theme's letter spacing — but read
// in full, left-out variables, "Couldn't check this folder", letters
// outside A–Z), the bracket warning's links to the field, the name check
// by tier (Add anyway; blocked with Change format and Change), the noMkdir
// choices (no "Save to … instead" at the library's top), the summary a
// screen reader hears, the restore chips' spoken names, 360 dp at 200%
// without overflow, and its links, tags and year error at 4.5:1 on the
// raised card in every theme and accent.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/discovery/keep_copy_ui.dart';
import 'package:mstream_music/screens/ytdl/ytdl_card_parts.dart';
import 'package:mstream_music/screens/ytdl/ytdl_crumbs.dart';
import 'package:mstream_music/screens/ytdl/ytdl_draft.dart';
import 'package:mstream_music/screens/ytdl/ytdl_saves_block.dart';
import 'package:mstream_music/theme/velvet_theme.dart';
import 'package:mstream_music/util/ytdl_layout.dart';
import 'package:mstream_music/widgets/accent_color_sheet.dart' show kAccentPresets;

import '../singletons/ytdl_fakes.dart';
import 'ytdl_ui_fixtures.dart';

void main() {
  final ui = YtdlUi();
  late Server s;

  setUp(() {
    ui.setUp();
    s = ytdlServer(formats: const ['mp3', 'm4a', 'opus', 'flac']);
  });
  tearDown(ui.tearDown);

  YtdlHarness h() => ui.h;

  String helper(WidgetTester t, YtdlField f) =>
      t.widget<Text>(find.descendant(
          of: byKey('ytdl-help-${f.name}'), matching: find.byType(Text))).data!;

  YtdlCrumbs savesCrumbs(WidgetTester t) => t.widget<YtdlCrumbs>(find.descendant(
      of: find.byType(YtdlSavesBlock), matching: find.byType(YtdlCrumbs)));

  Future<YtdlDraft> card(WidgetTester t, String link,
      {Size size = const Size(390, 844), double textScale = 1}) async {
    final d = await ui.pumpScreen(t, s, size: size, textScale: textScale);
    await ui.paste(t, d, link);
    return d;
  }

  Future<void> openTags(WidgetTester t) async {
    await tapIn(t, byKey('ytdl-edit-tags'));
    await t.pump();
  }

  group('YouTube Music (FoundMusic)', () {
    testWidgets('the card, its source line and SAVES TO with a new folder',
        (t) async {
      h().fake.folder('/Music/Daft Punk/');
      await card(t, kOneMoreTime);
      final l = h().l;
      expect(find.text('One More Time'), findsOneWidget);
      expect(shows(t, 'Discovery · 2001'), isTrue);
      expect(find.text(l.ytdlSourceMusic), findsOneWidget);
      final crumbs = savesCrumbs(t);
      expect(crumbs.crumbs, ['Music', 'Daft Punk', 'Discovery']);
      expect(crumbs.newAt, {2});
      expect(shows(t, 'about One_More_Time.mp3'), isTrue);
      expect(find.text(l.ytdlSavesTo.toUpperCase()), findsOneWidget);
      // "new" is the one amber mark on the path, in the ink measured on the
      // raised card it sits on.
      final tag = t.widget<Text>(find.descendant(
          of: find.byType(YtdlNewTag), matching: find.byType(Text)));
      expect(tag.style!.color, keepInkOn(VelvetColors.raised));
    });

    testWidgets('Edit tags: each field from YouTube Music; Edited; blank lines',
        (t) async {
      h().fake.folder('/Music/Daft Punk/');
      final d = await card(t, kOneMoreTime);
      final l = h().l;
      await openTags(t);
      for (final f in YtdlField.values) {
        expect(helper(t, f), l.ytdlHelpMusic, reason: f.name);
      }
      await t.enterText(byKey('ytdl-field-artist'), 'Daft Punk & Friends');
      await t.pump();
      expect(helper(t, YtdlField.artist), l.ytdlHelpEdited);
      // An emptied field says what a blank one does.
      await t.enterText(byKey('ytdl-field-album'), '');
      await t.pump();
      expect(helper(t, YtdlField.album), l.ytdlBlankAlbumKeeps);
      await t.enterText(byKey('ytdl-field-artist'), '');
      await t.pump();
      expect(helper(t, YtdlField.artist), l.ytdlBlankArtistMusic);
      expect(d.metadataToSend.containsKey('album'), isFalse);
    });

    testWidgets('blank artist and album: the card shows what the file keeps',
        (t) async {
      final handle = t.ensureSemantics();
      h().fake.folder('/Music/');
      await card(t, kOneMoreTime);
      final l = h().l;
      await openTags(t);
      await t.enterText(byKey('ytdl-field-artist'), '');
      await t.enterText(byKey('ytdl-field-album'), '');
      await t.pump();
      expect(helper(t, YtdlField.artist), l.ytdlBlankArtistMusic);
      expect(helper(t, YtdlField.album), l.ytdlBlankAlbumKeeps);
      expect(find.text('Daft Punk'), findsOneWidget);
      expect(shows(t, 'Discovery · 2001'), isTrue);
      expect(find.text(l.ytdlCardNoAlbum), findsNothing);
      expect(
          find.bySemanticsLabel(RegExp(RegExp.escape(
              '${l.ytdlSummaryBy('One More Time', 'Daft Punk')}, '
              '${l.ytdlSummaryAlbum('Discovery')}, 2001'))),
          findsOneWidget);
      handle.dispose();
    });

    testWidgets('Edit tags opens and closes the fields, focusing none',
        (t) async {
      final d = await card(t, kOneMoreTime);
      bool? expanded() => t
          .widget<Semantics>(find
              .ancestor(of: byKey('ytdl-edit-tags'), matching: find.byType(Semantics))
              .first)
          .properties
          .expanded;
      expect(expanded(), isFalse);
      await openTags(t);
      expect(d.tagsOpen, isTrue);
      expect(byKey('ytdl-field-title'), findsOneWidget);
      expect(d.focusFor(YtdlField.title).hasFocus, isFalse);
      expect(expanded(), isTrue);
      await tapIn(t, byKey('ytdl-edit-tags'));
      await t.pump();
      expect(d.tagsOpen, isFalse);
      expect(byKey('ytdl-field-title'), findsNothing);
      expect(d.focusFor(YtdlField.title).hasFocus, isFalse);
      expect(expanded(), isFalse);
      // What the fields held stays.
      expect(d.controllerFor(YtdlField.title).text, 'One More Time');
    });

    testWidgets('no year from the lookup: the upload-year line', (t) async {
      h().fake.videos[kOneMoreTime] = {
        'title': 'One More Time',
        'artist': 'Daft Punk',
        'album': 'Discovery',
        'year': null,
      };
      await card(t, kOneMoreTime);
      await openTags(t);
      expect(helper(t, YtdlField.year), h().l.ytdlBlankYear);
      expect(find.text('Discovery'), findsWidgets);
    });

    testWidgets('the card is one summary for a screen reader', (t) async {
      final handle = t.ensureSemantics();
      h().fake.folder('/Music/Daft Punk/');
      await card(t, kOneMoreTime);
      final l = h().l;
      final summary = l.ytdlSummary(
        '${l.ytdlSummaryBy('One More Time', 'Daft Punk')}, '
            '${l.ytdlSummaryAlbum('Discovery')}, 2001',
        l.ytdlSourceMusic,
        ytdlSpokenPath(l, ['Music', 'Daft Punk', 'Discovery'], newAt: {2}),
      );
      expect(find.bySemanticsLabel(summary), findsOneWidget);
      // Edit tags and Change stay focusable on their own.
      expect(find.bySemanticsLabel(l.ytdlEditTags), findsOneWidget);
      expect(find.bySemanticsLabel(l.discoverKeepChange), findsWidgets);
      handle.dispose();
    });
  });

  group('the split, cleaned (FoundCleaned)', () {
    testWidgets('source line, Cleaned from · Undo all, the chips and Swap',
        (t) async {
      h().fake.folder('/Music/Gorillaz/');
      final d = await card(t, kFeelGood);
      final l = h().l;
      expect(find.text(l.ytdlSourceSplitAgrees), findsOneWidget);
      expect(
          find.text(l.ytdlCleanedFrom(
              'Gorillaz - Feel Good Inc. (Official Video) [HD]')),
          findsOneWidget);
      expect(find.text(l.ytdlCardNoAlbum), findsOneWidget);
      await openTags(t);
      expect(helper(t, YtdlField.title), l.ytdlHelpVideoTitleCleaned);
      expect(helper(t, YtdlField.artist), l.ytdlHelpVideoTitle);
      expect(helper(t, YtdlField.album), l.ytdlBlankAlbumSingle);
      expect(find.text('(Official Video)'), findsOneWidget);
      expect(find.text('[HD]'), findsOneWidget);
      expect(find.text(l.ytdlRestoreSplit('-')), findsOneWidget);
      // ↶ (Official Video) puts it back and goes.
      final official = d.guess.fragments
          .indexWhere((f) => f.text == '(Official Video)');
      await tapIn(t, byKey('ytdl-restore-$official'));
      await t.pump();
      expect(d.controllerFor(YtdlField.title).text,
          'Feel Good Inc. (Official Video)');
      expect(find.text('(Official Video)'), findsNothing);
      // Swap: the chips go (a piece put back would land in the artist);
      // the artist is the title's half, cleaned of [HD].
      await tapIn(t, byKey('ytdl-swap'));
      await t.pump();
      expect(d.controllerFor(YtdlField.artist).text,
          'Feel Good Inc. (Official Video)');
      expect(d.controllerFor(YtdlField.title).text, 'Gorillaz');
      expect(find.text('[HD]'), findsNothing);
      expect(find.text(l.ytdlRestoreSplit('-')), findsNothing);
      expect(helper(t, YtdlField.title), l.ytdlHelpVideoTitle);
      expect(helper(t, YtdlField.artist), l.ytdlHelpVideoTitleCleaned);
      // Swapped back, they return.
      await tapIn(t, byKey('ytdl-swap'));
      await t.pump();
      expect(find.text('[HD]'), findsOneWidget);
      await tapIn(t, byKey('ytdl-swap'));
      await t.pump();
      // Undo all: the raw title, no chips, no line.
      await tapIn(t, byKey('ytdl-undo-all'));
      await t.pump();
      expect(d.controllerFor(YtdlField.title).text,
          'Gorillaz - Feel Good Inc. (Official Video) [HD]');
      expect(byKey('ytdl-undo-all'), findsNothing);
      expect(byKey('ytdl-swap'), findsNothing);
    });

    testWidgets('SAVES TO: an existing folder, the left-out album, the name',
        (t) async {
      h().fake.folder('/Music/Gorillaz/');
      await card(t, kFeelGood);
      final l = h().l;
      expect(savesCrumbs(t).crumbs, ['Music', 'Gorillaz']);
      expect(savesCrumbs(t).newAt, isEmpty);
      expect(find.text(l.discoverDestMissing('{{ALBUM}}')), findsOneWidget);
      final line = t.widget<YtdlFileLine>(find.byType(YtdlFileLine));
      expect(line.name, 'Gorillaz_-_Feel_Good_Inc._Official_Video_HD.mp3');
    });

    testWidgets('a long file name is cut in the middle but read in full',
        (t) async {
      final handle = t.ensureSemantics();
      h().fake.folder('/Music/Gorillaz/');
      await card(t, kFeelGood, size: const Size(360, 800));
      final full = h().l.ytdlFileAbout(
          'Gorillaz_-_Feel_Good_Inc._Official_Video_HD.mp3');
      expect(find.bySemanticsLabel(full), findsOneWidget);
      final shown = shownTexts(t).firstWhere((s) => s.startsWith('about '));
      expect(shown, contains('…'));
      expect(shown, endsWith('.mp3'));
      handle.dispose();
    });

    testWidgets('the cut is measured in the face it is drawn in: the theme\'s '
        'letter spacing keeps a long name to one middle-cut line', (t) async {
      const name = 'Daft_Punk_-_Harder_Better_Faster_Stronger.mp3';
      // Room for the whole line without the theme's spacing, not with it.
      final bare = TextPainter(
        text: TextSpan(children: [
          const TextSpan(
              text: 'about ', style: TextStyle(fontSize: 12, height: 16 / 12)),
          const TextSpan(
              text: name,
              style: TextStyle(
                  fontFamily: 'monospace', fontSize: 11.5, height: 16 / 12)),
        ]),
        textDirection: TextDirection.ltr,
      )..layout();
      final width = bare.width + 20;
      bare.dispose();
      ui.phone(t);
      await t.pumpWidget(ui.app(Scaffold(
        body: Center(
          child: DefaultTextStyle.merge(
            style: const TextStyle(letterSpacing: 2),
            child: SizedBox(width: width, child: const YtdlFileLine(name: name)),
          ),
        ),
      )));
      final shown = shownTexts(t).firstWhere((s) => s.startsWith('about '));
      expect(shown, contains('…'));
      expect(shown, endsWith('.mp3'));
      final para = t.renderObject<RenderParagraph>(find.descendant(
          of: find.byType(YtdlFileLine), matching: find.byType(RichText)));
      expect(para.size.height, lessThan(24), reason: 'one line, not two');
    });

    testWidgets('the restore chips are read as what they put back', (t) async {
      final handle = t.ensureSemantics();
      await card(t, kFeelGood);
      await openTags(t);
      final l = h().l;
      expect(find.bySemanticsLabel(l.ytdlA11yPutBack('(Official Video)')),
          findsOneWidget);
      expect(find.bySemanticsLabel(l.ytdlA11yPutBack('[HD]')), findsOneWidget);
      expect(find.bySemanticsLabel(l.ytdlA11yUndoSplit), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a year off an ordinary video: from its release date',
        (t) async {
      h().fake.videos[kFeelGood] = {...kFeelGoodVideo, 'year': 2005};
      final d = await card(t, kFeelGood);
      await openTags(t);
      expect(d.controllerFor(YtdlField.year).text, '2005');
      expect(helper(t, YtdlField.year), h().l.ytdlHelpVideoRelease);
    });

    testWidgets('an emptied title says the file gets the video\'s own',
        (t) async {
      await card(t, kFeelGood);
      await openTags(t);
      await t.enterText(byKey('ytdl-field-title'), '');
      await t.pump();
      expect(helper(t, YtdlField.title), h().l.ytdlBlankTitle);
    });
  });

  testWidgets('summarized: Undo all, Just this song and its Undo stay reachable',
      (t) async {
    final handle = t.ensureSemantics();
    h().fake.folder('/Music/Gorillaz/');
    final d = await card(t, kFeelGood);
    final l = h().l;
    expect(find.bySemanticsLabel(RegExp(RegExp.escape(l.ytdlSourceSplitAgrees))),
        findsOneWidget);
    expect(find.bySemanticsLabel(l.ytdlUndoAll), findsOneWidget);
    d.useForThisSong(YtdlChoice.folder('/Music/Gorillaz/'));
    await ui.settle(t, YtdlDraft.kCheckAfter);
    expect(byKey('ytdl-just-undo'), findsOneWidget);
    expect(find.bySemanticsLabel(l.ytdlJustThisSong), findsOneWidget);
    expect(find.bySemanticsLabel(l.ytdlUndo), findsOneWidget);
    await tapIn(t, byKey('ytdl-just-undo'));
    await ui.settle(t, YtdlDraft.kCheckAfter);
    expect(d.justThisSong, isNull);
    handle.dispose();
  });

  group('YouTube\'s artist (ChannelGuess)', () {
    testWidgets('the tags open by themselves; VEVO came off and can go back',
        (t) async {
      final d = await card(t, kSweater);
      final l = h().l;
      expect(find.text(l.ytdlSourceChannel), findsOneWidget);
      expect(d.tagsOpen, isTrue);
      expect(byKey('ytdl-field-title'), findsOneWidget);
      expect(helper(t, YtdlField.artist),
          l.ytdlHelpYoutubeArtistStripped('VEVO'));
      await tapIn(t, byKey('ytdl-restore-strip'));
      await t.pump();
      expect(d.controllerFor(YtdlField.artist).text, 'TheNeighbourhoodVEVO');
      expect(byKey('ytdl-restore-strip'), findsNothing);
    });

    testWidgets('an emptied artist names YouTube\'s raw guess', (t) async {
      await card(t, kSweater);
      await t.enterText(byKey('ytdl-field-artist'), '');
      await t.pump();
      expect(helper(t, YtdlField.artist),
          h().l.ytdlBlankArtistGuess('TheNeighbourhoodVEVO'));
    });
  });

  testWidgets('the year: four digits, else the error and Add waits', (t) async {
    h().fake.folder('/Music/Daft Punk/Discovery/');
    final d = await card(t, kOneMoreTime);
    await openTags(t);
    await t.enterText(byKey('ytdl-field-year'), '20');
    await t.pump();
    expect(byKey('ytdl-year-error'), findsOneWidget);
    expect(find.text(h().l.ytdlYearInvalid), findsOneWidget);
    expect(d.block, YtdlBlock.yearInvalid);
  });

  testWidgets('a file in the way: "Couldn\'t check this folder"', (t) async {
    h().fake.folder('/Music/Daft Punk/');
    h().fake.file('/Music/Daft Punk/', 'Discovery');
    await card(t, kOneMoreTime);
    expect(find.text(h().l.ytdlCheckFailed), findsOneWidget);
    expect(savesCrumbs(t).newAt, isEmpty);
  });

  testWidgets('letters outside A–Z: "about _.mp3 · letters … dropped"',
      (t) async {
    h().fake.video = {
      'title': 'Кино – Группа крови',
      'artist': 'Кино',
      'album': null,
      'year': null,
    };
    await card(t, 'https://youtu.be/kN0gRuPpa01');
    expect(shows(t, h().l.ytdlFileAboutLettersDropped('_.mp3')), isTrue);
    expect(savesCrumbs(t).crumbs, ['Music', 'Кино']);
    // A split alone is no cleaning: no "Cleaned from".
    expect(byKey('ytdl-undo-all'), findsNothing);
  });

  group('the bracket warning', () {
    testWidgets('nothing fills the folder: "Edit tags" opens Album', (t) async {
      final d = await card(t, kFeelGood);
      d.useForThisSong(const YtdlChoice(
          library: 'Music',
          layout: '{{ARTIST}}/{{ALBUM}} ({{YEAR}})',
          kind: 'custom'));
      await ui.settle(t, YtdlDraft.kCheckAfter);
      expect(d.target.trap?.kind, YtdlTrapKind.emptyFolder);
      expect(find.text(h().l.ytdlTrapEmpty('()')), findsOneWidget);
      await tapIn(t, byKey('ytdl-trap-link'));
      await t.pump();
      await t.pump();
      expect(d.focusFor(YtdlField.album).hasFocus, isTrue);
    });

    testWidgets('no year: "Add a year" opens Year', (t) async {
      final d = await card(t, kOneMoreTime);
      d.useForThisSong(const YtdlChoice(
          library: 'Music',
          layout: '{{ARTIST}}/{{ALBUM}} ({{YEAR}})',
          kind: 'custom'));
      d.controllerFor(YtdlField.year).text = '';
      await ui.settle(t, YtdlDraft.kCheckAfter);
      expect(find.text(h().l.ytdlTrapNoYear('Discovery ()')), findsOneWidget);
      await tapIn(t, byKey('ytdl-trap-link'));
      await t.pump();
      await t.pump();
      expect(d.focusFor(YtdlField.year).hasFocus, isTrue);
    });
  });

  group('the name check', () {
    testWidgets('6.30+: "looks to be in this folder", Add anyway, Change format',
        (t) async {
      h().fake.folder('/Music/Daft Punk/Discovery/', files: ['One_More_Time.mp3']);
      final d = await card(t, kOneMoreTime);
      final l = h().l;
      expect(find.text(l.ytdlClash('One_More_Time.mp3')), findsOneWidget);
      expect(find.text(l.ytdlAddAnyway), findsOneWidget);
      expect(d.block, YtdlBlock.none);
      await tapIn(t, byKey('ytdl-clash-format'));
      await t.pumpAndSettle();
      expect(byKey('ytdl-format-menu'), findsOneWidget);
      await t.tap(byKey('ytdl-format-m4a'));
      await t.pumpAndSettle();
      await ui.settle(t, YtdlDraft.kCheckAfter);
      expect(s.ytdlFormat, 'm4a');
      expect(byKey('ytdl-clash'), findsNothing);
    });

    testWidgets('older server: re-tag warning, Change format and Change, Add off',
        (t) async {
      h().fake.hasRecords = false;
      h().fake.folder('/Music/Daft Punk/Discovery/', files: ['One_More_Time.mp3']);
      final d = await card(t, kOneMoreTime);
      final l = h().l;
      expect(find.text(l.ytdlClashOlder('One_More_Time.mp3')), findsOneWidget);
      expect(byKey('ytdl-clash-format'), findsOneWidget);
      expect(d.block, YtdlBlock.clashOlder);
      await tapIn(t, byKey('ytdl-clash-change'));
      await t.pump();
      expect(ui.sheets.where, [d]);
    });

    testWidgets('one format on the server: no Change format', (t) async {
      s = ytdlServer(formats: const ['mp3']);
      h().fake.folder('/Music/Daft Punk/Discovery/', files: ['One_More_Time.mp3']);
      await card(t, kOneMoreTime);
      expect(byKey('ytdl-clash'), findsOneWidget);
      expect(byKey('ytdl-clash-format'), findsNothing);
    });
  });

  group('the account can\'t make folders (NoMkdir)', () {
    setUp(() {
      s = ytdlServer(noMkdir: true);
    });

    testWidgets('a new folder: why, and Save to … instead (just this song)',
        (t) async {
      h().fake.folder('/Music/Daft Punk/');
      final d = await card(t, kOneMoreTime);
      final l = h().l;
      expect(find.text(l.ytdlNoMkdirNew('Discovery')), findsOneWidget);
      expect(shows(t, l.ytdlSaveToInstead('Music › Daft Punk')), isTrue);
      expect(d.block, YtdlBlock.mkdirBlocked);
      await tapIn(t, byKey('ytdl-save-deepest'));
      await ui.settle(t, YtdlDraft.kCheckAfter);
      expect(d.justThisSong, isNotNull);
      expect(savesCrumbs(t).crumbs, ['Music', 'Daft Punk']);
      expect(find.text(l.ytdlJustThisSong), findsOneWidget);
      expect(d.block, YtdlBlock.none);
      await tapIn(t, byKey('ytdl-just-undo'));
      await ui.settle(t, YtdlDraft.kCheckAfter);
      expect(d.justThisSong, isNull);
    });

    testWidgets('only the library\'s top is there: no Save to Music instead, '
        'which Top of the library already offers', (t) async {
      final d = await card(t, kOneMoreTime);
      expect(d.deepestExisting, '/Music/');
      expect(find.text(h().l.ytdlNoMkdirNew('Daft Punk')), findsOneWidget);
      expect(byKey('ytdl-save-deepest'), findsNothing);
      expect(byKey('ytdl-use-top'), findsOneWidget);
      expect(byKey('ytdl-choose-folder'), findsOneWidget);
    });

    testWidgets('unchecked: its own words; Top of the library', (t) async {
      h().fake.folder('/Music/Daft Punk/');
      h().fake.file('/Music/Daft Punk/', 'Discovery');
      final d = await card(t, kOneMoreTime);
      expect(find.text(h().l.ytdlNoMkdirUnchecked), findsOneWidget);
      await tapIn(t, byKey('ytdl-use-top'));
      await ui.settle(t, YtdlDraft.kCheckAfter);
      expect(d.choice.kind, 'top');
      expect(d.target.directory, '/Music/');
    });

    testWidgets('a failed lookup still says why Add is off, with the choices',
        (t) async {
      s
        ..ytdlLibrary = 'Music'
        ..ytdlLayout = 'Singles/{{ARTIST}}'
        ..ytdlLayoutKind = 'custom';
      h().fake.folder('/Music/');
      h().fake.lookupRefusal = (500, 'Server Error');
      final d = await card(t, kOneMoreTime);
      expect(byKey('ytdl-lookup-failed'), findsOneWidget);
      expect(d.block, YtdlBlock.mkdirBlocked);
      expect(find.text(h().l.ytdlNoMkdirNew('Singles')), findsOneWidget);
      expect(byKey('ytdl-use-top'), findsOneWidget);
      expect(byKey('ytdl-choose-folder'), findsOneWidget);
      await tapIn(t, byKey('ytdl-use-top'));
      await ui.settle(t, YtdlDraft.kCheckAfter);
      expect(d.block, YtdlBlock.none);
    });

    testWidgets('Choose a folder… applies the picked folder', (t) async {
      h().fake.folder('/Music/Daft Punk/');
      final d = await card(t, kOneMoreTime);
      ui.sheets.chooseAnswer = '/Music/Daft Punk/Homework/';
      await tapIn(t, byKey('ytdl-choose-folder'));
      await ui.settle(t);
      expect(ui.sheets.choose, [d]);
      expect(d.target.directory, '/Music/Daft Punk/Homework/');
    });
  });

  group('360 dp at 200% text', () {
    testWidgets('YouTube\'s artist with its tags open', (t) async {
      await card(t, kSweater, size: const Size(360, 800), textScale: 2);
      await t.drag(byKey('ytdl-list'), const Offset(0, -3000));
      await t.pump();
      expect(t.takeException(), isNull);
    });

    testWidgets('the noMkdir panel', (t) async {
      s = ytdlServer(noMkdir: true);
      h().fake.folder('/Music/Daft Punk/');
      await card(t, kOneMoreTime, size: const Size(360, 800), textScale: 2);
      expect(byKey('ytdl-nomkdir'), findsOneWidget);
      expect(byKey('ytdl-save-deepest'), findsOneWidget);
      await t.drag(byKey('ytdl-list'), const Offset(0, -3000));
      await t.pump();
      expect(t.takeException(), isNull);
    });

    testWidgets('a clash on an older server', (t) async {
      h().fake.hasRecords = false;
      h().fake.folder('/Music/Daft Punk/Discovery/',
          files: ['One_More_Time.mp3']);
      final d =
          await card(t, kOneMoreTime, size: const Size(360, 800), textScale: 2);
      expect(d.clashBlocks, isTrue);
      expect(byKey('ytdl-clash'), findsOneWidget);
      expect(byKey('ytdl-clash-change'), findsOneWidget);
      await t.drag(byKey('ytdl-list'), const Offset(0, -3000));
      await t.pump();
      expect(t.takeException(), isNull);
    });

    testWidgets('right-to-left names keep the › order (each crumb isolated)',
        (t) async {
      h().fake.videos[kOneMoreTime] = {
        'title': 'نور العين',
        'artist': 'عمرو دياب',
        'album': 'نور العين',
        'year': 1996,
      };
      await card(t, kOneMoreTime, size: const Size(360, 800));
      expect(savesCrumbs(t).crumbs, ['Music', 'عمرو دياب', 'نور العين']);
      expect(t.takeException(), isNull);
    });
  });

  group('small text on the raised card (spec §9: 4.5:1)', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
    }

    Color inkOf(WidgetTester t, Finder of) => t
        .widget<Text>(find.descendant(of: of, matching: find.byType(Text)).first)
        .style!
        .color!;

    testWidgets('links, tags and the year error, in every theme and accent',
        (t) async {
      addTearDown(() => VelvetColors.setActive(paletteFor(AppTheme.dark)));
      h().fake.folder('/Music/Daft Punk/');
      final d = await card(t, kOneMoreTime);
      d.useFolder('/Music/Daft Punk/');
      await openTags(t);
      await t.enterText(byKey('ytdl-field-year'), '01');
      await t.pump();
      expect(byKey('ytdl-year-error'), findsOneWidget);
      for (final theme in AppTheme.values) {
        for (final accent in <Color?>[null, ...kAccentPresets]) {
          final base = paletteFor(theme);
          final p = accent == null ? base : base.withAccent(accent);
          VelvetColors.setActive(p);
          // Every element rebuilt under the new palette, as a theme switch
          // does it.
          unawaited(t.binding.reassembleApplication());
          await t.pump();
          final what = '${theme.name} ${accent ?? 'default'}';
          for (final (name, ink) in [
            ('Edit tags', inkOf(t, byKey('ytdl-edit-tags'))),
            ('Change', inkOf(t, byKey('ytdl-saves-change'))),
            ('Just this song', inkOf(t, find.byType(YtdlTag))),
            ('the year error', inkOf(t, byKey('ytdl-year-error'))),
          ]) {
            expect(contrast(ink, p.raised), greaterThanOrEqualTo(4.5),
                reason: '$name, $what');
          }
        }
      }
    });
  });
}
