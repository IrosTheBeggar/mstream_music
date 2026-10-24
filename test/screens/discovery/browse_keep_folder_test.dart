// Keep a copy's folder focus, entered from a connected server's file
// explorer (the phone spec's §6.6, its RecSheets S10–S25 boards): the
// header with its count, Listen waiting on it, "Where it lands" and its
// three bodies — as on the server (the layout's leading folders kept,
// decision 1), Into a folder… (the saved library › the pressed folder's
// name, decision 2; the libraries, Up, the folders, Show all, New folder…,
// a brace refused, the straight-in line) and By your layout (tags read
// once, one folder per album, Change previewing the folder) — the cap line
// in place of all of it, what each start sends, and every state a folder
// copy reads in. And the destination sheet's preview by the folder rule.

import 'dart:async';

import 'package:flutter/rendering.dart' show RenderEditable, RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/metadata.dart';
import 'package:mstream_music/screens/discovery/destination_sheet.dart';
import 'package:mstream_music/screens/discovery/discovery_jobs_controller.dart';
import 'package:mstream_music/screens/discovery/keep_copy_ui.dart';
import 'package:mstream_music/theme/velvet_theme.dart';
import 'package:mstream_music/util/browse_keep_leads.dart';
import 'package:mstream_music/util/discover_jobs.dart';

import 'browse_keep_sheet_fixtures.dart';

const tapesRec = {
  'source': 'federation',
  'peer': peerB,
  'filepath': tapesDir,
  'title': 'Borrowed Tapes',
};

/// A folder copy's result ([landed]: where its files went; [ownedAt]: the
/// library files its skipped songs already were).
Map<String, dynamic> folderResult({
  int copied = 3,
  int skipped = 0,
  int failed = 0,
  String? stopped,
  String? landed = 'copies/Boukmanflow/Borrowed Tapes',
  int skippedFiles = 0,
  List<String>? ownedAt,
}) => {
  'scope': 'folder',
  'folder': {'path': tapesDir, 'name': 'Borrowed Tapes', 'landed': landed},
  'songs': {
    'total': copied + skipped + failed,
    'copied': [
      for (var i = 0; i < copied && i < 3; i++)
        {
          'from': tapesFiles[i],
          'filepath':
              'copies/Boukmanflow/Borrowed Tapes/${tapesFiles[i].split('/').last}',
        },
    ],
    'skipped': [
      for (var i = 0; i < skipped && i < 3; i++)
        {
          'from': tapesFiles[i],
          'why': 'owned',
          'at':
              ownedAt?[i] ??
              'music/Boukmanflow/${tapesFiles[i].split('/').last}',
        },
    ],
    'failed': [],
  },
  'counts': {
    'total': copied + skipped + failed,
    'copied': copied,
    'skipped': skipped,
    'failed': failed,
  },
  'skippedFiles': [
    for (var i = 0; i < skippedFiles; i++) {'from': 'x$i.txt', 'why': 'unsupported'},
  ],
  'stopped': stopped,
  'peer': peerB,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final h = BrowseSheetHarness();
  setUp(h.setUp);
  tearDown(h.tearDown);

  Future<void> frames(WidgetTester tester, [int n = 6]) =>
      BrowseSheetHarness.frames(tester, n);

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await frames(tester);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final f = find.text(text);
    await tester.ensureVisible(f.last);
    await tester.pump();
    await tester.tap(f.last);
    await frames(tester);
  }

  /// The pinned Add's pill.
  Finder add() => find.descendant(
    of: find.byKey(const ValueKey('keep-add-bar')),
    matching: find.byKey(const ValueKey('keep-start')),
  );

  bool addEnabled(WidgetTester tester) =>
      tester.widget<KeepPill>(add()).onTap != null;

  group('folder focus · as on Stage Peer B', () {
    testWidgets('from the folder header (V-page): the count, Listen, the '
        'landings, the path, three files, the foot, Add folder · 3 songs', (
      tester,
    ) async {
      await h.pumpHost(tester);
      await h.open(tester, h.folder('/$tapesDir'));
      expect(tester.takeException(), isNull);
      expect(find.text('Borrowed Tapes'), findsOneWidget);
      expect(
        line('Folder · music › Boukmanflow › Borrowed Tapes'),
        findsOneWidget,
        reason: 'the path wraps only between its folders',
      );
      expect(
        find.text('Stage Peer B online · 3 songs · no subfolders'),
        findsOneWidget,
      );
      expect(h.facts.count('recursive /$tapesDir'), 1, reason: 'once');
      expect(find.text('Play folder'), findsOneWidget);
      expect(find.text('Add to queue'), findsOneWidget);
      // Where it lands: the three, as on the server chosen.
      expect(find.text('Where it lands'), findsOneWidget);
      expect(find.text('As on Stage Peer B'), findsOneWidget);
      expect(find.text('Into a folder…'), findsOneWidget);
      expect(find.text('By your layout'), findsOneWidget);
      expect(
        line('Files go to copies › Boukmanflow › Borrowed Tapes'),
        findsOneWidget,
      );
      expect(find.text('01 - Rooftop Cypher.mp3'), findsOneWidget);
      expect(find.text('03 - Corner Store Loop.mp3'), findsOneWidget);
      // Monospaced on iOS too, which has no 'monospace' family.
      final mono = tester.widget<Text>(find.text('01 - Rooftop Cypher.mp3'));
      expect(mono.style!.fontFamily, 'monospace');
      expect(mono.style!.fontFamilyFallback, contains('Menlo'));
      expect(find.text('Its path inside “music” on Stage Peer B'), findsOneWidget);
      expect(find.text('Change'), findsNothing, reason: 'the layout does not apply');
      expect(find.text('Add folder · 3 songs'), findsOneWidget);

      await tapKey(tester, 'keep-start');
      await frames(tester, 8);
      final body = h.lastStart();
      expect(body['scope'], 'folder');
      expect(body['recommendation'], tapesRec);
      expect(body.containsKey('landing'), isFalse, reason: 'mirror: none');
      expect(body['destination'], isNotNull);
    });

    testWidgets('the layout\'s leading folders are kept (decision 1)',
        (tester) async {
      h.fake.destination = {
        ...h.fake.destination,
        'destination': {
          'vpath': 'copies',
          'base': '',
          'layout': 'From friends/{{ALBUMARTIST}}/{{ALBUM}}',
          'source': 'user',
        },
      };
      await h.pumpHost(tester);
      await h.open(tester, h.folder('/$tapesDir'));
      expect(
        line(
          'Files go to copies › From friends › Boukmanflow › Borrowed Tapes',
        ),
        findsOneWidget,
      );
    });

    testWidgets('from a folder row (V-menu), counting: no Listen, "Add '
        'folder" — and Add never waits on the count', (tester) async {
      h.facts.countGate = Completer<void>();
      await h.pumpHost(tester);
      await h.open(tester, h.folder('/$tapesDir', variant: KeepVariant.menu));
      expect(find.text('Stage Peer B online · Counting…'), findsOneWidget);
      expect(find.text('Play folder'), findsNothing);
      expect(find.text('Add folder'), findsOneWidget);
      await tapKey(tester, 'keep-start');
      await frames(tester, 8);
      expect(h.lastStart()['scope'], 'folder');
      h.facts.countGate!.complete();
      await frames(tester);
    });

    testWidgets('a folder of folders: "9 songs · 3 subfolders", each file '
        'its folder first, "and 6 more songs"', (tester) async {
      await h.pumpHost(tester);
      await h.open(tester, h.folder('/music/Boukmanflow'));
      expect(
        find.text('Stage Peer B online · 9 songs · 3 subfolders'),
        findsOneWidget,
      );
      expect(line('Files go to copies › Boukmanflow'), findsOneWidget);
      expect(find.text('Borrowed Tapes/01 - Rooftop Cypher.mp3'), findsOneWidget);
      expect(find.text('and 6 more songs'), findsOneWidget);
      expect(find.text('Add folder · 9 songs'), findsOneWidget);
    });

    testWidgets('Play folder plays the counted songs and closes the sheet',
        (tester) async {
      await h.pumpHost(tester);
      await h.open(tester, h.folder('/$tapesDir'));
      expect(find.byKey(const ValueKey('browse-keep-sheet')), findsOneWidget);
      // (The queue itself is the audio service's; the sheet closes.)
      await tapText(tester, 'Play folder');
      await frames(tester, 8);
      expect(find.byKey(const ValueKey('browse-keep-sheet')), findsNothing);
    });
  });

  group('Into a folder…', () {
    Future<void> into(WidgetTester tester, {String path = '/$tapesDir'}) async {
      await h.pumpHost(tester);
      await h.open(tester, h.folder(path));
      await tapKey(tester, 'keep-landing-folder');
      await frames(tester);
    }

    testWidgets('the default: copies › Borrowed Tapes, its files, not there '
        'yet; the libraries; Up to copies; New folder…; this copy only', (
      tester,
    ) async {
      await into(tester);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('keep-into-library-copies')), findsOneWidget);
      expect(find.byKey(const ValueKey('keep-into-library-music')), findsOneWidget);
      expect(
        line('Files go to copies › Borrowed Tapes'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('keep-into-missing')),
        findsOneWidget,
        reason: 'the folder is not there yet',
      );
      expect(find.byKey(const ValueKey('keep-into-straight')), findsNothing);
      expect(find.text('FOLDERS IN BORROWED TAPES'), findsOneWidget);
      expect(find.text('Up to copies'), findsOneWidget);
      expect(find.text('No subfolders here'), findsOneWidget);
      expect(find.text('New folder…'), findsOneWidget);
      expect(
        find.text('For this copy only · nothing is saved to your account'),
        findsOneWidget,
      );
      await tapKey(tester, 'keep-start');
      await frames(tester, 8);
      expect(h.lastStart()['landing'], {'vpath': 'copies', 'path': 'Borrowed Tapes'});
    });

    testWidgets('an existing default is simply chosen: no missing note',
        (tester) async {
      h.facts.own['/copies/Borrowed Tapes'] = ['Side A'];
      await into(tester);
      expect(find.byKey(const ValueKey('keep-into-missing')), findsNothing);
      expect(find.text('Side A'), findsOneWidget);
    });

    testWidgets('Up to copies: the library root, the straight-in line; From '
        'Sam goes in and is chosen; the start sends it, no 409', (
      tester,
    ) async {
      await into(tester);
      await tapText(tester, 'Up to copies');
      await frames(tester);
      expect(line('Files go to copies'), findsOneWidget);
      expect(
        find.text(
          'Its files go straight into copies, with no “Borrowed Tapes” '
          'folder of their own.',
        ),
        findsOneWidget,
      );
      expect(find.text('FOLDERS IN COPIES'), findsOneWidget);
      expect(find.text('Up to copies'), findsNothing, reason: 'at the root');
      for (final n in ['Boukmanflow', 'Color Out', 'From Sam']) {
        expect(find.text(n), findsWidgets, reason: n);
      }
      await tapKey(tester, 'keep-into-folder-From Sam');
      await frames(tester);
      expect(line('Files go to copies › From Sam'), findsOneWidget);
      expect(
        find.text(
          'Its files go straight into From Sam, with no “Borrowed Tapes” '
          'folder of their own.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('keep-into-missing')), findsNothing);
      expect(find.text('FOLDERS IN FROM SAM'), findsOneWidget);
      expect(find.text('Up to copies'), findsOneWidget);
      // The saved place moved meanwhile: a folder of its own never 409s.
      h.fake.destination = {
        ...h.fake.destination,
        'destination': {
          'vpath': 'music',
          'base': '',
          'layout': '{{ALBUMARTIST}}/{{ALBUM}}',
          'source': 'user',
        },
      };
      await tapKey(tester, 'keep-start');
      await frames(tester, 8);
      expect(h.lastStart()['landing'], {'vpath': 'copies', 'path': 'From Sam'});
      expect(find.text('Waiting for a free slot'), findsOneWidget);
      expect(find.textContaining('Where files land changed'), findsNothing);
    });

    testWidgets('the music library: its place the pressed folder\'s name '
        'there; Up to its root, 8 folders inline, "Show all 14 folders" '
        'expands in place', (tester) async {
      await into(tester);
      await tapKey(tester, 'keep-into-library-music');
      await frames(tester);
      expect(line('Files go to music › Borrowed Tapes'), findsOneWidget);
      await tapText(tester, 'Up to music');
      expect(line('Files go to music'), findsOneWidget);
      expect(find.text('Podcasts'), findsOneWidget);
      expect(find.text('Radio'), findsNothing);
      expect(find.text('Show all 14 folders'), findsOneWidget);
      await tapText(tester, 'Show all 14 folders');
      expect(find.text('Voice Memos'), findsOneWidget);
      expect(find.text('Show all 14 folders'), findsNothing);
      await tapKey(tester, 'keep-start');
      await frames(tester, 8);
      expect(h.lastStart()['landing'], {'vpath': 'music', 'path': ''});
    });

    testWidgets('the lister in flight: "Looking up…", the missing note waits',
        (tester) async {
      h.facts.ownGate = Completer<void>();
      await into(tester);
      expect(find.text('Looking up…'), findsOneWidget);
      expect(find.byKey(const ValueKey('keep-into-missing')), findsNothing);
      h.facts.ownGate!.complete();
      await frames(tester);
      expect(find.text('Looking up…'), findsNothing);
      expect(find.byKey(const ValueKey('keep-into-missing')), findsOneWidget);
    });

    testWidgets('New folder…: the pressed folder\'s name, all selected; a '
        'brace refused with both Adds waiting; a plain name chosen', (
      tester,
    ) async {
      await into(tester);
      await tapText(tester, 'Up to copies');
      await tapKey(tester, 'keep-into-new');
      await frames(tester);
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('keep-into-name')),
      );
      expect(field.controller!.text, 'Borrowed Tapes');
      expect(
        field.controller!.selection,
        const TextSelection(baseOffset: 0, extentOffset: 14),
      );
      expect(find.text('Folder name'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('keep-into-name')),
        'Tapes {2019}',
      );
      await frames(tester);
      expect(
        find.text(
          '“Tapes {2019}” has a brace in its name, which a layout reads as a '
          'variable. Choose or name a folder without one.',
        ),
        findsOneWidget,
      );
      expect(addEnabled(tester), isFalse, reason: "the sheet's Add waits");
      await tester.tap(find.byKey(const ValueKey('keep-into-add')));
      await frames(tester);
      expect(find.byKey(const ValueKey('keep-into-name')), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('keep-into-name')),
        'Tapes 2019',
      );
      await frames(tester);
      expect(find.byKey(const ValueKey('keep-into-braces')), findsNothing);
      expect(addEnabled(tester), isTrue);
      await tapKey(tester, 'keep-into-add');
      expect(line('Files go to copies › Tapes 2019'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('keep-into-missing')),
        findsOneWidget,
        reason: 'named here: not there yet',
      );
      await tapKey(tester, 'keep-start');
      await frames(tester, 8);
      expect(h.lastStart()['landing'], {'vpath': 'copies', 'path': 'Tapes 2019'});
    });

    testWidgets('✕ undoes the naming', (tester) async {
      await into(tester);
      await tapKey(tester, 'keep-into-new');
      await tapKey(tester, 'keep-into-cancel');
      expect(find.byKey(const ValueKey('keep-into-name')), findsNothing);
      expect(find.text('New folder…'), findsOneWidget);
    });

    testWidgets("a listed folder is gone into by its name as listed — \"AC:DC\" "
        'there is that folder, never a new "AC-DC" beside it', (tester) async {
      h.facts.own['/copies'] = ['AC:DC', 'Color Out'];
      h.facts.own['/copies/AC:DC'] = [];
      await into(tester);
      await tapText(tester, 'Up to copies');
      await tapKey(tester, 'keep-into-folder-AC:DC');
      await frames(tester);
      expect(find.byKey(const ValueKey('keep-into-missing')), findsNothing,
          reason: 'it is there');
      await tapKey(tester, 'keep-start');
      await frames(tester, 8);
      expect(h.lastStart()['landing'], {'vpath': 'copies', 'path': 'AC:DC'});
    });

    testWidgets('a screen reader: each group named once (its label drawn '
        'only), the brace line said as it appears', (tester) async {
      final handle = tester.ensureSemantics();
      await into(tester);
      expect(find.bySemanticsLabel('Where it lands'), findsOneWidget);
      expect(find.bySemanticsLabel('Library'), findsOneWidget);
      expect(find.bySemanticsLabel('LIBRARY'), findsNothing);
      await tapKey(tester, 'keep-into-new');
      await tester.enterText(
        find.byKey(const ValueKey('keep-into-name')),
        'Tapes {2019}',
      );
      await frames(tester);
      final braces = tester.getSemantics(
        find.byKey(const ValueKey('keep-into-braces')),
      );
      expect(braces.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });

    testWidgets('2.0× on 360: the name field grows with its text — the name '
        'whole inside it, its label too', (tester) async {
      await h.pumpHost(tester, width: 360, height: 780, textScale: 2);
      await h.open(tester, h.folder('/$tapesDir'));
      await tapKey(tester, 'keep-landing-folder');
      await tapKey(tester, 'keep-into-new');
      await frames(tester);
      final editable =
          tester.allRenderObjects.whereType<RenderEditable>().single;
      expect(editable.size.height, greaterThanOrEqualTo(editable.preferredLineHeight - 0.5));
      final box = tester.getRect(find.byKey(const ValueKey('keep-into-name-box')));
      final label = tester.getRect(find.text('Folder name'));
      expect(label.top, greaterThanOrEqualTo(box.top - 0.5),
          reason: 'the floating label inside the naming row, never over the row above');
    });

    testWidgets('the keyboard up: the sheet sits above it — the name field '
        'and the pinned Add both in view', (tester) async {
      await h.pumpHost(tester, width: 360, height: 780);
      await h.open(tester, h.folder('/$tapesDir'));
      await tapKey(tester, 'keep-landing-folder');
      await tapKey(tester, 'keep-into-new');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
      addTearDown(tester.view.resetViewInsets);
      await frames(tester, 10);
      expect(tester.takeException(), isNull);
      const keyboardTop = 780 - 300.0;
      final bar = tester.getRect(find.byKey(const ValueKey('keep-add-bar')));
      expect(bar.bottom, lessThanOrEqualTo(keyboardTop + 0.5));
      await tester.showKeyboard(find.byKey(const ValueKey('keep-into-name')));
      await frames(tester, 10);
      final field = tester.getRect(find.byKey(const ValueKey('keep-into-name')));
      expect(field.bottom, lessThanOrEqualTo(bar.top + 0.5), reason: 'scrolled into what is left');
    });

    testWidgets('a pressed folder with a brace: its first place refused, Add '
        'waits', (tester) async {
      h.facts.folders['/music/Boukmanflow/Tapes {2019}'] = [
        'music/Boukmanflow/Tapes {2019}/a.mp3',
      ];
      await into(tester, path: '/music/Boukmanflow/Tapes {2019}');
      expect(find.byKey(const ValueKey('keep-into-braces')), findsOneWidget);
      expect(addEnabled(tester), isFalse);
    });
  });

  group('By your layout', () {
    testWidgets('tags read once; the songs agree: the exact path, its files, '
        'Change previewing the folder; the start sends {tags: true}', (
      tester,
    ) async {
      await h.pumpHost(tester);
      await h.open(tester, h.folder('/$tapesDir'));
      expect(h.facts.count('tags'), 0, reason: 'not until chosen');
      await tapKey(tester, 'keep-landing-tags');
      await frames(tester);
      await tapKey(tester, 'keep-landing-mirror');
      await tapKey(tester, 'keep-landing-tags');
      await frames(tester);
      expect(h.facts.count('tags'), 1, reason: 'once');
      expect(
        line('Files go to copies › Boukmanflow › Borrowed Tapes'),
        findsOneWidget,
      );
      expect(find.text('02 - Late Train Verse.mp3'), findsOneWidget);
      await tapText(tester, 'Change');
      expect(h.opened, ['folder destination']);
      final preview = h.folderPreviews.single;
      expect(preview.folder, tapesDir);
      expect(preview.name, 'Borrowed Tapes');
      expect(preview.songs, hasLength(3));
      expect(preview.tags, hasLength(3));
      await tapKey(tester, 'keep-start');
      await frames(tester, 8);
      expect(h.lastStart()['landing'], {'tags': true});
    });

    testWidgets('three albums: one folder per album, no files', (tester) async {
      h.facts.folderTags = {
        for (final p in boukFiles)
          p: MusicMetadata.fromServerMap({
            'title': p.split('/').last,
            'artist': 'Boukmanflow',
            'album': p.split('/')[2],
            'album-artist': 'Boukmanflow',
          }),
      };
      await h.pumpHost(tester);
      await h.open(tester, h.folder('/music/Boukmanflow'));
      await tapKey(tester, 'keep-landing-tags');
      await frames(tester);
      expect(
        line('Files go to copies › Boukmanflow › one folder per album'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('keep-folder-files')), findsNothing);
      expect(find.text('Add folder · 9 songs'), findsOneWidget);
    });

    testWidgets('an older peer, no album artist, artists that differ: the '
        '‹artist› slot and its note', (tester) async {
      const dir = 'music/Various Artists/Night Market Sampler';
      final files = [for (var i = 1; i <= 3; i++) '$dir/0$i.mp3'];
      h.facts.folders['/$dir'] = files;
      h.facts.folderTags = {
        for (final (i, a) in const ['Color Out', 'Boukmanflow', 'ALM'].indexed)
          files[i]: MusicMetadata.fromServerMap({
            'title': 'Track $i',
            'artist': a,
            'album': 'Night Market Sampler',
          }),
      };
      await h.pumpHost(tester);
      await h.open(tester, h.folder('/$dir'));
      await tapKey(tester, 'keep-landing-tags');
      await frames(tester);
      expect(
        line('Files go to copies › ‹artist› › Night Market Sampler'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('keep-slot-note')), findsOneWidget);
      expect(find.byKey(const ValueKey('keep-folder-files')), findsNothing);
    });
  });

  group('the cap', () {
    testWidgets('over maxFolderSongs: the card holds the cap line alone — no '
        'landings, no Add', (tester) async {
      await h.pumpHost(tester);
      await h.open(
        tester,
        h.folder('/music/Night Owl Radio Archive', variant: KeepVariant.menu),
      );
      expect(find.textContaining('1,240 songs · '), findsOneWidget);
      expect(
        find.text(
          '“Night Owl Radio Archive” holds 1,240 songs, more than one copy '
          'takes here (1,000). Keep its folders one at a time.',
        ),
        findsOneWidget,
      );
      expect(find.text('Where it lands'), findsNothing);
      expect(find.byKey(const ValueKey('keep-add-bar')), findsNothing);
    });

    testWidgets('an older server names no cap: no line, Add', (tester) async {
      h.fake.listing = {
        ...h.fake.listing,
        'jobs': {'allowed': true},
      };
      await h.pumpHost(tester);
      await h.open(tester, h.folder('/music/Night Owl Radio Archive'));
      expect(find.byKey(const ValueKey('keep-folder-cap')), findsNothing);
      expect(find.text('Add folder · 1,240 songs'), findsOneWidget);
    });

    testWidgets('a copy an older server failed for its cap: its words, no '
        'verb', (tester) async {
      final j = h.fake.addJob(tapesRec, scope: 'folder', state: 'failed');
      j['error'] =
          '“Borrowed Tapes” on Stage Peer B holds 1240 songs — add its '
          'folders one at a time (the limit is 1000; an admin can raise it '
          'under Discovery › Jobs)';
      await h.pumpHost(tester);
      await h.open(tester, h.folder('/$tapesDir'));
      expect(find.text('Copy failed'), findsOneWidget);
      expect(find.byKey(const ValueKey('keep-retry')), findsNothing);
    });
  });

  group('folder states', () {
    Map<String, dynamic> job(
      String state, {
      Map<String, dynamic>? result,
      Map<String, dynamic>? landing,
      String? statusText,
      double? progress,
      bool cancelRequested = false,
    }) {
      final j = h.fake.addJob(
        tapesRec,
        scope: 'folder',
        state: state,
        result: result,
        statusText: statusText,
        progress: progress,
      );
      j['params'] = {
        'scope': 'folder',
        'landing': ?landing,
        'destination': h.fake.destination['destination'],
      };
      j['cancelRequested'] = cancelRequested;
      return j;
    }

    Future<void> open(WidgetTester tester) async {
      await h.pumpHost(tester);
      await h.open(tester, h.folder('/$tapesDir'));
    }

    testWidgets('waiting: its own landing, Cancel, the landings hidden',
        (tester) async {
      job('queued');
      await open(tester);
      expect(find.text('Waiting for a free slot'), findsOneWidget);
      expect(find.text('Starts on its own'), findsOneWidget);
      expect(
        find.text('Into copies › Boukmanflow › Borrowed Tapes'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Where it lands'), findsNothing);
      expect(find.byKey(const ValueKey('keep-add-bar')), findsNothing);
    });

    testWidgets('copying into a folder of its own: the server\'s line, '
        '"Into copies › From Sam"', (tester) async {
      job(
        'running',
        landing: {'vpath': 'copies', 'path': 'From Sam'},
        statusText: '2 of 3 songs · 4.1 MB',
        progress: 0.6,
      );
      await open(tester);
      expect(find.text('Copying'), findsOneWidget);
      expect(find.text('2 of 3 songs · 4.1 MB'), findsOneWidget);
      expect(find.text('Into copies › From Sam'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('in your collection: the counts, the files left out, where '
        'it is; Play and Show in your library', (tester) async {
      job(
        'done',
        result: folderResult(copied: 2, skipped: 1, skippedFiles: 2),
      );
      await open(tester);
      expect(find.text('In your collection'), findsOneWidget);
      expect(find.text('2 copied · 1 already yours'), findsOneWidget);
      expect(
        find.text('2 files left out: not music this server plays, or hidden'),
        findsOneWidget,
      );
      expect(
        find.text('In copies › Boukmanflow › Borrowed Tapes'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('keep-play-files')), findsOneWidget);
      await tapText(tester, 'Show in your library');
      await frames(tester, 8);
      expect(h.shownInLibrary, ['home /copies/Boukmanflow/Borrowed Tapes']);
      expect(find.byKey(const ValueKey('browse-keep-sheet')), findsNothing);
    });

    testWidgets('with a failure: Play and Retry, which sends its own landing',
        (tester) async {
      job(
        'done',
        result: folderResult(copied: 2, failed: 1),
        landing: {'vpath': 'copies', 'path': 'From Sam'},
      );
      await open(tester);
      expect(find.text('2 copied · 1 failed'), findsOneWidget);
      expect(find.byKey(const ValueKey('keep-play-files')), findsOneWidget);
      expect(find.text('Show in your library'), findsNothing);
      await tapKey(tester, 'keep-retry');
      await frames(tester, 8);
      expect(h.lastStart()['landing'], {'vpath': 'copies', 'path': 'From Sam'});
      expect(h.lastStart()['scope'], 'folder');
    });

    testWidgets('already yours: "You have it all · 3 already yours", in '
        'the folder those songs are — never the landing it never made',
        (tester) async {
      job('done', result: folderResult(copied: 0, skipped: 3));
      await open(tester);
      expect(find.text('Already yours'), findsOneWidget);
      expect(find.text('You have it all · 3 already yours'), findsOneWidget);
      expect(find.text('In music › Boukmanflow'), findsOneWidget);
      expect(
        find.text('In copies › Boukmanflow › Borrowed Tapes'),
        findsNothing,
      );
      await tapText(tester, 'Show in your library');
      await frames(tester, 8);
      expect(h.shownInLibrary, ['home /music/Boukmanflow']);
    });

    // The live walk's job #1: "Into a folder…" copies › Borrowed Tapes,
    // every song already in copies/Boukmanflow/Borrowed Tapes — the server
    // answers `landed: copies/Borrowed Tapes`, a folder never made.
    testWidgets('already yours into a folder of its own: where the songs '
        'are, not the folder it would have made', (tester) async {
      job(
        'done',
        landing: {'vpath': 'copies', 'path': 'Borrowed Tapes'},
        result: folderResult(
          copied: 0,
          skipped: 3,
          landed: 'copies/Borrowed Tapes',
          ownedAt: [
            for (final f in tapesFiles)
              'copies/Boukmanflow/Borrowed Tapes/${f.split('/').last}',
          ],
        ),
      );
      await open(tester);
      expect(
        find.text('In copies › Boukmanflow › Borrowed Tapes'),
        findsOneWidget,
      );
      expect(find.text('In copies › Borrowed Tapes'), findsNothing);
      await tapText(tester, 'Show in your library');
      await frames(tester, 8);
      expect(h.shownInLibrary, ['home /copies/Boukmanflow/Borrowed Tapes']);
    });

    testWidgets('already yours, its songs in two libraries: no "In …" line '
        'and no Show in your library — Play still plays them', (tester) async {
      job(
        'done',
        result: folderResult(
          copied: 0,
          skipped: 2,
          ownedAt: [
            'music/Boukmanflow/01 - Rooftop Cypher.mp3',
            'copies/Boukmanflow/02 - Late Train Verse.mp3',
          ],
        ),
      );
      await open(tester);
      expect(find.text('You have it all · 2 already yours'), findsOneWidget);
      expect(find.textContaining('In copies'), findsNothing);
      expect(find.textContaining('In music'), findsNothing);
      expect(find.text('Show in your library'), findsNothing);
      expect(find.byKey(const ValueKey('keep-play-files')), findsOneWidget);
    });

    testWidgets('Show in your library that does not open there says so',
        (tester) async {
      h.showInLibraryOpens = false;
      job('done', result: folderResult(copied: 2, skipped: 1));
      await open(tester);
      await tapText(tester, 'Show in your library');
      await frames(tester, 8);
      expect(h.shownInLibrary, ['home /copies/Boukmanflow/Borrowed Tapes']);
      expect(h.toasts, ["Couldn't open Borrowed Tapes on your server"]);
    });

    testWidgets('refused: no actions', (tester) async {
      job('done', result: folderResult(copied: 0, stopped: 'refused'));
      await open(tester);
      expect(find.text('Stopped'), findsOneWidget);
      expect(find.byKey(const ValueKey('keep-retry')), findsNothing);
      expect(find.byKey(const ValueKey('keep-play-files')), findsNothing);
    });

    testWidgets('copy failed, nothing copied: Retry', (tester) async {
      job('done', result: folderResult(copied: 0, failed: 3));
      await open(tester);
      expect(find.text('Copy failed'), findsOneWidget);
      expect(find.text('Nothing copied · 3 failed'), findsOneWidget);
      expect(find.byKey(const ValueKey('keep-retry')), findsOneWidget);
    });

    testWidgets('cancelled as on the server, the saved place moved since: '
        'Add again names where it goes now', (tester) async {
      job('cancelled');
      h.fake.destination = {
        ...h.fake.destination,
        'destination': {
          'vpath': 'music',
          'base': '',
          'layout': '{{ALBUMARTIST}}/{{ALBUM}}',
          'source': 'user',
        },
      };
      await open(tester);
      expect(
        lineWith(
          'Add again adds to music › Boukmanflow › Borrowed Tapes, your saved '
          'place now',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a mirror start whose saved place moved: 409, the path '
        'redrawn, today\'s line', (tester) async {
      await open(tester);
      h.fake.destination = {
        ...h.fake.destination,
        'destination': {
          'vpath': 'music',
          'base': '',
          'layout': '{{ALBUMARTIST}}/{{ALBUM}}',
          'source': 'user',
        },
      };
      await tapKey(tester, 'keep-start');
      await frames(tester, 10);
      expect(
        find.text(
          'Where files land changed since this opened. Check the path above '
          'and add again.',
        ),
        findsOneWidget,
      );
      expect(
        line('Files go to music › Boukmanflow › Borrowed Tapes'),
        findsOneWidget,
      );
    });

    testWidgets('cancelled: Add again with its own landing', (tester) async {
      job('cancelled', landing: {'tags': true});
      await open(tester);
      expect(find.text('Stopped · nothing was copied'), findsOneWidget);
      await tapKey(tester, 'keep-add-again');
      await frames(tester, 8);
      expect(h.lastStart()['landing'], {'tags': true});
    });
  });

  group('the server offline', () {
    testWidgets('"not answering", "Couldn\'t count its songs", Listen dimmed '
        'but focusable, the landings shown, Add folder', (tester) async {
      h.facts.peerDown = true;
      final handle = tester.ensureSemantics();
      await h.pumpHost(tester);
      await h.open(tester, h.folder('/$tapesDir'));
      expect(
        find.text("Stage Peer B not answering · Couldn't count its songs"),
        findsOneWidget,
      );
      final play = tester.getSemantics(find.byKey(const ValueKey('browse-keep-play-folder')));
      expect(play, isSemantics(isButton: true, isEnabled: false));
      expect(find.text('Where it lands'), findsOneWidget);
      expect(find.text('Add folder'), findsOneWidget);
      await tapKey(tester, 'keep-landing-tags');
      await frames(tester);
      expect(lineWith('Files go to copies › ‹artist›'), findsOneWidget,
          reason: 'slots');
      handle.dispose();
    });
  });

  group('large text', () {
    testWidgets('2.0× on 360 × 780: the mirror and Into a folder… — nothing '
        'overflows; the field and Add stack; Add pinned', (tester) async {
      await h.pumpHost(tester, width: 360, height: 780, textScale: 2);
      await h.open(tester, h.folder('/$tapesDir'));
      expect(tester.takeException(), isNull);
      await tapKey(tester, 'keep-landing-folder');
      await tapKey(tester, 'keep-into-new');
      await frames(tester);
      expect(tester.takeException(), isNull);
      final field = tester.getRect(find.byKey(const ValueKey('keep-into-name')));
      final addRect = tester.getRect(find.byKey(const ValueKey('keep-into-add')));
      expect(addRect.top, greaterThanOrEqualTo(field.bottom), reason: 'stacked');
      final bar = find.byKey(const ValueKey('keep-add-bar'));
      expect(tester.getBottomLeft(bar).dy, lessThanOrEqualTo(780));
    });

    testWidgets('1.0× on 390: the field and Add share the row', (tester) async {
      await h.pumpHost(tester);
      await h.open(tester, h.folder('/$tapesDir'));
      await tapKey(tester, 'keep-landing-folder');
      await tapKey(tester, 'keep-into-new');
      final field = tester.getRect(find.byKey(const ValueKey('keep-into-name')));
      final addRect = tester.getRect(find.byKey(const ValueKey('keep-into-add')));
      expect(addRect.left, greaterThan(field.right - 1));
    });
  });

  group('themes', () {
    Color colorOf(WidgetTester tester, Finder text) {
      final w = tester.widget(text);
      if (w is Text) return w.style!.color!;
      return ((w as RichText).text.style ?? const TextStyle()).color!;
    }

    for (final theme in AppTheme.values) {
      testWidgets('${theme.name}: the folder card\'s quiet lines read at '
          '4.5:1 on what they sit on — the card, the raised preview box', (
        tester,
      ) async {
        VelvetColors.setActive(paletteFor(theme));
        await h.pumpHost(tester);
        await h.open(tester, h.folder('/$tapesDir'));
        final card = VelvetColors.card;
        final raised = VelvetColors.raised;
        for (final (what, ground) in [
          ('Where it lands', card),
          ('Its own folders, as they are there', card),
          ('Its path inside “music” on Stage Peer B', card),
        ]) {
          expect(_contrast(colorOf(tester, find.text(what)), ground),
              greaterThanOrEqualTo(4.5), reason: what);
        }
        final mono = tester
            .widgetList<Text>(find.descendant(
              of: find.byKey(const ValueKey('keep-folder-files')),
              matching: find.byType(Text),
            ))
            .first;
        expect(_contrast(mono.style!.color!, card), greaterThanOrEqualTo(4.5),
            reason: 'the file list on the card');
        await tapKey(tester, 'keep-landing-folder');
        await frames(tester);
        for (final (what, ground) in [
          ('LIBRARY', card),
          ('This folder does not exist yet — it is created by the first file', raised),
          ('For this copy only · nothing is saved to your account', card),
          ('No subfolders here', card),
        ]) {
          expect(_contrast(colorOf(tester, find.text(what)), ground),
              greaterThanOrEqualTo(4.5), reason: what);
        }
        final inBox = tester
            .widgetList<Text>(find.descendant(
              of: find.byKey(const ValueKey('keep-into-preview')),
              matching: find.byType(Text),
            ))
            .where((t) => t.data != null && t.data!.endsWith('.mp3'))
            .first;
        expect(_contrast(inBox.style!.color!, raised), greaterThanOrEqualTo(4.5),
            reason: 'the file list in the raised preview');
        // The chosen landing's ring: the primary's text colour, not the raw
        // primary (Light's amber on white is under 3:1).
        final chosen = find.byKey(const ValueKey('keep-landing-folder'));
        final ring = tester
            .widgetList<Container>(find.descendant(of: chosen, matching: find.byType(Container)))
            .map((c) => c.decoration)
            .whereType<BoxDecoration>()
            .where((d) => d.shape == BoxShape.circle && d.border != null)
            .first;
        expect((ring.border! as Border).top.color, keepInk());
        expect(_contrast(keepInk(), card), greaterThanOrEqualTo(3));
      });
    }

    testWidgets("2.0× on 360: the pinned Add keeps its count — two lines, "
        'never an ellipsis', (tester) async {
      await h.pumpHost(tester, width: 360, height: 780, textScale: 2);
      await h.open(tester, h.folder('/$tapesDir'));
      await frames(tester);
      final words = find.descendant(
        of: find.byKey(const ValueKey('keep-add-bar')),
        matching: find.text('Add folder · 3 songs'),
      );
      expect(words, findsOneWidget);
      final p = tester.renderObject<RenderParagraph>(words);
      expect(p.didExceedMaxLines, isFalse);
    });
  });

  group('the destination sheet from By your layout', () {
    Future<void> pick(
      WidgetTester tester,
      DestinationPreviewFolder folder,
    ) async {
      await h.pumpHost(tester);
      final DiscoveryJobsController jobs = h.jobs;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: Scaffold(
            body: DestinationSheet(
              jobs: jobs,
              folder: folder,
              peerName: 'Stage Peer B',
            ),
          ),
        ),
      );
      await frames(tester, 8);
    }

    String preview(WidgetTester tester) => tester
        .widget<RichText>(
          find.descendant(
            of: find.byKey(const ValueKey('destination-preview')),
            matching: find.byType(RichText),
          ),
        )
        .text
        .toPlainText()
        .replaceAll('\u00A0', ' ')
        .replaceAll('-\u2060', '-');

    testWidgets('its preview renders the folder by the folder rule, no file',
        (tester) async {
      await pick(
        tester,
        DestinationPreviewFolder(
          folder: tapesDir,
          name: 'Borrowed Tapes',
          tags: [for (final p in tapesFiles) _tags(p, 'Borrowed Tapes')],
        ),
      );
      expect(find.text('Borrowed Tapes lands at'), findsOneWidget);
      expect(preview(tester), 'copies › Boukmanflow › Borrowed Tapes');
    });

    testWidgets('a folder of albums: one folder per album', (tester) async {
      await pick(
        tester,
        DestinationPreviewFolder(
          folder: 'music/Boukmanflow',
          name: 'Boukmanflow',
          tags: [
            _tags(boukFiles[0], 'Borrowed Tapes'),
            _tags(boukFiles[3], 'Harbour Lights'),
          ],
        ),
      );
      expect(preview(tester), 'copies › Boukmanflow › one folder per album');
    });
  });
}

FolderSongTags _tags(String path, String album) => folderSongTags(
  path,
  artist: 'Boukmanflow',
  album: album,
  albumArtist: 'Boukmanflow',
);

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
