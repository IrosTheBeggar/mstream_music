// "Choose a folder" (screens/ytdl/ytdl_choose_folder_sheet.dart), for an
// account that can't make folders, over the scripted server's folder tree:
// it opens at the folder it is given, else at the deepest folder on the
// song's path that listed, else at the draft's library; it lists the
// subfolders in name order as 56 px rows, opens one on a tap and goes back
// up by a crumb ("Up to Music"), says "No folders here." in an empty one,
// shows the still rows while a folder lists (read as "Loading folders") and
// a failed listing with Try again; an answer for a folder since left is
// dropped. "Use this folder" returns the folder on screen once it has
// listed ('/Music/Daft Punk/Homework/', which the caller hands to
// useFolder), Cancel and ✕ return nothing, the feature going away closes
// nothing (a pick still comes back); the crumb row keeps one height; and
// 360 dp at 200% text fits, "Use this folder" wrapping rather than cut.

import 'dart:async';

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/ytdl/ytdl_choose_folder_sheet.dart';
import 'package:mstream_music/screens/ytdl/ytdl_draft.dart';

import '../singletons/ytdl_fakes.dart';

void main() {
  late YtdlHarness h;
  late Server s;
  final host = GlobalKey();
  late Future<String?> picked;

  YtdlDraft draft() => h.hub.stateFor(s).screenDraft;

  setUp(() {
    h = YtdlHarness()..wire();
    s = ytdlServer(libraries: const ['Music', 'Mixes'], noMkdir: true);
    for (final f in ['Random Access Memories', 'Homework', 'human after all']) {
      h.fake.folder('/Music/Daft Punk/$f/');
    }
    h.fake.folder('/Music/Gorillaz/', files: ['Feel_Good_Inc.mp3']);
    h.fake.file('/Music/Daft Punk/', 'cover.jpg');
  });
  tearDown(() => h.unwire());

  Future<void> pumps(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  /// Let the fake server answer the listing asked.
  Future<void> answer(WidgetTester tester) async {
    await tester.runAsync(ytdlSettle);
    await pumps(tester);
  }

  Future<void> open(
    WidgetTester tester, {
    String? startAt,
    Size size = const Size(390, 844),
    double textScale = 1,
    bool listed = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(key: host, body: const SizedBox.expand()),
    ));
    picked = showYtdlChooseFolderSheet(host.currentContext!, draft(),
        startAt: startAt);
    await pumps(tester);
    if (listed) await answer(tester);
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  Future<void> tap(WidgetTester tester, String k) async {
    await tester.ensureVisible(key(k));
    await tester.pump();
    await tester.tap(key(k));
    await pumps(tester);
  }

  List<String> listed() => [
        for (final b in h.fake.bodies('POST', '/api/v1/file-explorer'))
          b['directory'] as String,
      ];

  testWidgets('opens at the draft\'s library: the header, the tag, the '
      'subtitle and the folders', (tester) async {
    await open(tester);
    expect(listed(), ['/Music/']);
    expect(find.text(h.l.ytdlChooseTitle), findsOneWidget);
    expect(find.text(h.l.ytdlJustThisSong), findsOneWidget);
    expect(find.text(h.l.ytdlChooseSub), findsOneWidget);
    expect(key('ytdl-choose-folder-Daft Punk'), findsOneWidget);
    expect(key('ytdl-choose-folder-Gorillaz'), findsOneWidget);
    expect(key('ytdl-choose-here'), findsOneWidget);
    expect(find.text('\u2068Music\u2069'), findsOneWidget);
  });

  testWidgets('after a folder that couldn\'t be made, for an account that '
      'may make folders: no "can\'t make folders" line (spec \u00a78 mkdir '
      'failed)', (tester) async {
    s.noMkdir = false;
    await open(tester);
    expect(key('ytdl-choose-sheet'), findsOneWidget);
    expect(key('ytdl-choose-sub'), findsNothing);
    expect(find.text(h.l.ytdlChooseSub), findsNothing);
    expect(key('ytdl-choose-folder-Daft Punk'), findsOneWidget);
  });

  testWidgets('\u2026 and with it once a mkdir was refused this session (a stale '
      'noMkdir)', (tester) async {
    s.noMkdir = false;
    h.fake.mkdirRefusal = (403, 'Create Folder Disabled');
    await tester.runAsync(() async {
      await h.hub.stateFor(s).start(h.request(
          directory: '/Music/New/', mkdir: '/Music/New/', inline: () => true));
      await ytdlSettle();
    });
    expect(h.hub.stateFor(s).mkdirRefused, isTrue);
    await open(tester);
    expect(find.text(h.l.ytdlChooseSub), findsOneWidget);
  });

  testWidgets('called as the card calls it (no folder given), it opens at '
      'the deepest folder that listed', (tester) async {
    // One More Time: Music › Daft Punk lists, Discovery isn't there.
    final d = draft();
    await tester.runAsync(() async {
      d.link.text = kOneMoreTime;
      await h.timers.elapse(YtdlDraft.kLookupDebounce);
      await h.timers.elapse(YtdlDraft.kCheckAfter);
    });
    expect(d.mkdirBlocked, isTrue);
    expect(d.deepestExisting, '/Music/Daft Punk/');
    await open(tester);
    expect(listed().last, '/Music/Daft Punk/');
    expect(find.text('\u2068Daft Punk\u2069'), findsOneWidget);
    // "Music" goes back up; Daft Punk's albums are the rows.
    expect(key('ytdl-choose-up-0'), findsOneWidget);
    expect(key('ytdl-choose-folder-Homework'), findsOneWidget);
    expect(key('ytdl-choose-folder-Gorillaz'), findsNothing);
  });

  testWidgets('the crumb row keeps one height at the library and below it',
      (tester) async {
    await open(tester);
    final atLibrary = tester.getSize(key('ytdl-choose-crumbs')).height;
    // The 48 px hit band of a crumb that goes up, and the 1 px rule.
    expect(atLibrary, 49);
    await tap(tester, 'ytdl-choose-folder-Daft Punk');
    await answer(tester);
    expect(key('ytdl-choose-up-0'), findsOneWidget);
    expect(tester.getSize(key('ytdl-choose-crumbs')).height, atLibrary);
  });

  testWidgets('the feature going away closes nothing (spec §8): the folders '
      'stay, and a pick still comes back', (tester) async {
    await open(tester);
    var done = false;
    unawaited(picked.then((_) => done = true));
    // A re-ping found audio conversion off; the state tells its drafts.
    s.transcodeAvailable = false;
    await tester.runAsync(() => h.hub.stateFor(s).rememberFormat('mp3'));
    await pumps(tester);
    expect(h.hub.stateFor(s).entryAllowed, isFalse);
    expect(key('ytdl-choose-sheet'), findsOneWidget);
    expect(done, isFalse);
    await tap(tester, 'ytdl-choose-folder-Daft Punk');
    await answer(tester);
    await tap(tester, 'ytdl-choose-use');
    expect(await picked, '/Music/Daft Punk/');
  });

  testWidgets('a folder it is given: its subfolders in name order, files '
      'left out', (tester) async {
    final semantics = tester.ensureSemantics();
    await open(tester, startAt: '/Music/Daft Punk/');
    expect(listed(), ['/Music/Daft Punk/']);
    final rows = [
      for (final f in ['Homework', 'human after all', 'Random Access Memories'])
        tester.getTopLeft(key('ytdl-choose-folder-$f')).dy,
    ];
    expect(rows, orderedEquals([...rows]..sort()));
    expect(find.textContaining('cover.jpg'), findsNothing);
    expect(tester.getSize(key('ytdl-choose-folder-Homework')).height, 56);
    expect(
      tester.getSemantics(key('ytdl-choose-folder-Homework')),
      isSemantics(label: 'Homework', isButton: true),
    );
    expect(find.bySemanticsLabel(h.l.ytdlA11yUpTo('Music')), findsOneWidget);
    expect(find.bySemanticsLabel(h.l.ytdlA11yFolderPath), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a tap opens a folder, a crumb goes back up', (tester) async {
    await open(tester);
    await tap(tester, 'ytdl-choose-folder-Daft Punk');
    await answer(tester);
    expect(listed().last, '/Music/Daft Punk/');
    expect(key('ytdl-choose-folder-Homework'), findsOneWidget);
    await tap(tester, 'ytdl-choose-folder-Homework');
    await answer(tester);
    expect(listed().last, '/Music/Daft Punk/Homework/');
    expect(find.text(h.l.ytdlChooseEmpty), findsOneWidget);
    expect(key('ytdl-choose-up-1'), findsOneWidget); // Daft Punk
    await tap(tester, 'ytdl-choose-up-0'); // Music
    await answer(tester);
    expect(listed().last, '/Music/');
    expect(key('ytdl-choose-folder-Gorillaz'), findsOneWidget);
    expect(key('ytdl-choose-up-0'), findsNothing);
  });

  testWidgets('Use this folder returns the folder on screen for useFolder',
      (tester) async {
    await open(tester, startAt: '/Music/Daft Punk/');
    await tap(tester, 'ytdl-choose-folder-Homework');
    await answer(tester);
    await tap(tester, 'ytdl-choose-use');
    final dir = await picked;
    expect(dir, '/Music/Daft Punk/Homework/');
    expect(key('ytdl-choose-sheet'), findsNothing);
    // What the card's caller does with it.
    final d = draft()..useFolder(dir!);
    expect(d.justThisSong?.isFolder, isTrue);
    expect(d.target.directory, '/Music/Daft Punk/Homework/');
  });

  testWidgets('Cancel returns nothing', (tester) async {
    await open(tester);
    await tap(tester, 'ytdl-choose-cancel');
    expect(await picked, isNull);
  });

  testWidgets('✕ returns nothing', (tester) async {
    await open(tester);
    expect(find.byTooltip(h.l.close), findsOneWidget);
    await tap(tester, 'ytdl-choose-close');
    expect(await picked, isNull);
  });

  testWidgets('while a folder lists: still rows, read as loading, and '
      'nothing to use yet', (tester) async {
    final semantics = tester.ensureSemantics();
    h.fake.listGate = Completer<void>();
    await open(tester, listed: false);
    expect(key('ytdl-choose-loading'), findsOneWidget);
    expect(find.bySemanticsLabel(h.l.ytdlChooseLoading), findsOneWidget);
    expect(tester.getSemantics(key('ytdl-choose-use')),
        isSemantics(isButton: true, isEnabled: false));
    await tester.runAsync(() async {
      h.fake.listGate!.complete();
      await ytdlSettle();
    });
    await pumps(tester);
    expect(key('ytdl-choose-loading'), findsNothing);
    expect(tester.getSemantics(key('ytdl-choose-use')),
        isSemantics(isButton: true, isEnabled: true));
    semantics.dispose();
  });

  testWidgets('a listing that fails: the words, Try again, nothing to use',
      (tester) async {
    final semantics = tester.ensureSemantics();
    h.fake.listFails.add('/Music/');
    await open(tester);
    expect(find.text(h.l.ytdlCheckFailed), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(tester.getSemantics(key('ytdl-choose-use')),
        isSemantics(isButton: true, isEnabled: false));
    h.fake.listFails.clear();
    await tap(tester, 'ytdl-choose-retry');
    await answer(tester);
    // The dropped listing went out once more on its own, then Try again.
    expect(listed(), ['/Music/', '/Music/', '/Music/']);
    expect(key('ytdl-choose-folder-Daft Punk'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('an answer for a folder since left is dropped', (tester) async {
    h.fake.listGate = Completer<void>();
    await open(tester, startAt: '/Music/Daft Punk/', listed: false);
    // Up to Music before Daft Punk answered.
    await tap(tester, 'ytdl-choose-up-0');
    await tester.runAsync(() async {
      h.fake.listGate!.complete();
      await ytdlSettle();
    });
    await pumps(tester);
    expect(listed(), ['/Music/Daft Punk/', '/Music/']);
    expect(key('ytdl-choose-folder-Gorillaz'), findsOneWidget);
    expect(key('ytdl-choose-folder-Homework'), findsNothing);
    await tap(tester, 'ytdl-choose-use');
    expect(await picked, '/Music/');
  });

  testWidgets('360 dp at 200% text: no overflow, 48 px targets',
      (tester) async {
    h.fake.folder('/Music/Daft Punk/A Very Long Folder Name For A Live Album/');
    await open(tester,
        startAt: '/Music/Daft Punk/', size: const Size(360, 800), textScale: 2);
    expect(tester.takeException(), isNull);
    // The rows scroll under the fixed header and footer.
    await tester.drag(key('ytdl-choose-list'), const Offset(0, -2000));
    await pumps(tester);
    expect(tester.takeException(), isNull);
    for (final band in [
      find.ancestor(of: key('ytdl-choose-cancel'), matching: find.byType(GestureDetector)),
      find.ancestor(of: key('ytdl-choose-use'), matching: find.byType(GestureDetector)),
      find.ancestor(of: key('ytdl-choose-up-0'), matching: find.byType(GestureDetector)),
    ]) {
      expect(tester.getSize(band.first).height, greaterThanOrEqualTo(48));
    }
    await tap(tester, 'ytdl-choose-up-0');
    await answer(tester);
    expect(key('ytdl-choose-folder-Gorillaz'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('360 dp at 200% text: "Use this folder" too long for the row '
      'wraps, its words never cut', (tester) async {
    // A full em a glyph: as long as "Diesen Ordner verwenden" in a real face.
    await open(tester,
        startAt: '/Music/Daft Punk/', size: const Size(360, 800), textScale: 2);
    final label = tester.renderObject<RenderParagraph>(find.descendant(
        of: key('ytdl-choose-use'), matching: find.byType(RichText)));
    expect(label.didExceedMaxLines, isFalse);
    expect(label.size.height,
        greaterThanOrEqualTo(label.getMaxIntrinsicHeight(label.size.width) - 0.5));
    expect(tester.takeException(), isNull);
  });
}
