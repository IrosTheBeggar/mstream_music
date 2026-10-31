// Add from YouTube end to end, across the slices: the real Browser and
// BrowserToolbar, YtdlScreen with its real lists, the real Where, folder
// and "Choose a folder" sheets and the explorer strip, on YtdlHarness and
// the scripted server — no sheet recorders. It pins the journeys each
// slice's own tests stub out: the home card's summary over a whole add
// (Adding → Added for an hour → gone; a failure until the screen shows it)
// and the rendered gates; the screen through the real Where sheet to
// ADDING and ADDED; the explorer's sheet, Sort into subfolders, the strip
// in the target and its parents, the re-list and its tint, Details landing
// on NEEDS A LOOK; an account that can't make folders reaching a folder
// through the real picker from the card, the folder sheet (stepped aside
// and back) and a row; the feature turned off by a re-ping while a sheet,
// menu or picker is open — nothing closes, the card says why Add is off or
// gone and the lookup goes on, while a stale ⋮ item or the picker coming
// back opens nothing and says why; the
// app paused and resumed, the screen reopened over its kept draft, two
// servers; the Where sheet's listeners across two screens and torn-down
// routes; and the song just added never dropping out of every list while
// ADDED reads its record (spec §6). Every test ends with no exception and
// no FlutterError.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/build_variant.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/objects/ytdl_job.dart';
import 'package:mstream_music/screens/ytdl/ytdl_choose_folder_sheet.dart';
import 'package:mstream_music/screens/ytdl/ytdl_draft.dart';
import 'package:mstream_music/screens/ytdl/ytdl_folder_sheet.dart';
import 'package:mstream_music/screens/ytdl/ytdl_folder_strip.dart';
import 'package:mstream_music/screens/ytdl/ytdl_screen.dart';
import 'package:mstream_music/screens/ytdl/ytdl_where_sheet.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/singletons/ytdl_hub.dart';
import 'package:mstream_music/theme/velvet_theme.dart';
import 'package:mstream_music/util/ytdl_api.dart';
import 'package:mstream_music/util/ytdl_layout.dart';

import 'ytdl_flows_kit.dart';

void main() {
  setUpAll(flowsSetUpAll);
  tearDownAll(flowsTearDownAll);

  group('the home card and the screen (flows 1, 2)', () {
    final f = Flows();
    setUp(f.setUp);
    tearDown(f.tearDown);

    YtdlServerState st() => f.h.hub.stateFor(f.s);
    final lines = byKey('ytdl-home-lines');

    Future<void> openFromHome(WidgetTester t) async {
      await t.tap(find.text('Add from YouTube'));
      await f.drain(t);
      expect(find.byType(YtdlScreen), findsOneWidget);
    }

    Future<void> back(WidgetTester t) async {
      final nav = t.state<NavigatorState>(find.byType(Navigator).first);
      nav.pop();
      await f.drain(t);
      expect(find.byType(YtdlScreen), findsNothing);
    }

    testWidgets('(1) home summary follows an add made on the screen: Adding 1 → '
        'Added 1 (1 h) → gone; a failure → 1 failed → opening clears it', (t) async {
      f.watchErrors();
      await f.pumpHome(t);
      expect(find.text('Add from YouTube'), findsOneWidget);
      expect(lines, findsNothing);

      await openFromHome(t);
      await f.typeLink(t, kOneMoreTime);
      expect(byKey('ytdl-card'), findsOneWidget);
      await t.tap(byKey('ytdl-add'));
      await f.drain(t);
      expect(f.h.fake.count('POST', '/api/v1/ytdl/'), 1);
      expect(byKey('ytdl-section-adding'), findsOneWidget);
      await back(t);
      expect(find.text('Adding 1'), findsOneWidget);

      // It finishes while the home shows.
      await t.runAsync(() async {
        f.h.fake.finish(f.h.fake.tracker.last['pid'] as int);
      });
      await f.settle(t, YtdlServerState.kPollBeat);
      await f.drain(t);
      expect(f.h.toasts.last.success, isTrue);
      expect(plain(f.h.toasts.last.message), 'Added “One More Time” to Daft Punk › Discovery');
      expect(find.text('Added 1'), findsOneWidget);

      await f.settle(t, const Duration(minutes: 61));
      await t.pump();
      expect(lines, findsNothing, reason: '"Added" lasts an hour');

      // A failure.
      await openFromHome(t);
      await f.typeLink(t, kFeelGood);
      await t.tap(byKey('ytdl-add'));
      await f.drain(t);
      await back(t);
      expect(find.text('Adding 1'), findsOneWidget);
      await t.runAsync(() async => f.h.fake.fail(f.h.fake.tracker.last['pid'] as int));
      await f.settle(t, YtdlServerState.kPollBeat);
      await f.drain(t);
      expect(f.h.toastTexts.last, "Couldn't add “Feel Good Inc.”");
      expect(find.text('1 failed'), findsOneWidget);

      await openFromHome(t);
      expect(byKey('ytdl-section-needs-look'), findsOneWidget);
      await back(t);
      expect(lines, findsNothing, reason: 'the screen showed it');
      expect(t.takeException(), isNull);
      expect(f.errors, isEmpty);
    });

    testWidgets('(2) the screen with the real Where sheet: Change → Use for this '
        'song → SAVES TO follows → Save → toast; Add → ADDING → ADDED', (t) async {
      f.watchErrors();
      f.h.fake.folder('/Music/Gorillaz/');
      await f.pumpHome(t);
      await openFromHome(t);
      final d = st().screenDraft;
      await f.typeLink(t, kFeelGood);
      expect(d.lookup, YtdlLookupState.found);
      expect(d.target.directory, '/Music/Gorillaz/');

      await tapIn(t, byKey('ytdl-edit-tags'));
      await f.drain(t);
      expect(byKey('ytdl-field-title'), findsOneWidget);

      // Change → Artist → Use for this song.
      await tapIn(t, byKey('ytdl-saves-change'));
      await f.drain(t);
      expect(byKey('ytdl-where-sheet'), findsOneWidget);
      await tapIn(t, byKey('ytdl-where-layout-top'));
      await f.drain(t);
      await tapIn(t, byKey('ytdl-where-use'));
      await f.drain(t);
      expect(byKey('ytdl-where-sheet'), findsNothing);
      expect(d.justThisSong, isNotNull);
      expect(d.target.directory, '/Music/');
      expect(find.text(f.h.l.ytdlJustThisSong), findsOneWidget);

      // Change → Artist → Save: remembered, toast, just-this-song dropped.
      await tapIn(t, byKey('ytdl-saves-change'));
      await f.drain(t);
      await tapIn(t, byKey('ytdl-where-layout-artist'));
      await f.drain(t);
      await tapIn(t, byKey('ytdl-where-save'));
      await f.drain(t);
      expect(byKey('ytdl-where-sheet'), findsNothing);
      expect(d.justThisSong, isNull);
      expect(f.s.ytdlLayoutKind, 'artist');
      expect(f.h.toastTexts.last, startsWith('Saved'));
      expect(d.target.directory, '/Music/Gorillaz/');

      // Add → Starting… → 200 → ADDING → complete → ADDED + toast.
      f.h.fake.addGate = Completer<void>();
      await tapIn(t, byKey('ytdl-add'));
      await f.settle(t);
      expect(find.text(f.h.l.discoverJobStarting), findsOneWidget);
      expect(byKey('ytdl-section-adding'), findsNothing);
      // Its own add is no earlier one (spec §3).
      expect(byKey('ytdl-already-adding'), findsNothing);
      f.h.fake.addGate!.complete();
      await f.drain(t);
      expect(byKey('ytdl-card'), findsNothing);
      expect(byKey('ytdl-section-adding'), findsOneWidget);
      expect(st().adding.single.pid, isNotNull, reason: 'the first poll claimed it');
      await t.runAsync(() async => f.h.fake.finish(f.h.fake.tracker.last['pid'] as int));
      await f.settle(t, YtdlServerState.kPollBeat);
      await f.drain(t);
      expect(byKey('ytdl-section-adding'), findsNothing);
      expect(byKey('ytdl-section-added'), findsOneWidget);
      expect(f.h.toasts.last.success, isTrue);
      expect(f.h.toasts.last.message, startsWith('Added “Feel Good Inc.”'));
      expect(st().summary.isEmpty, isTrue, reason: 'seen on the screen');
      expect(t.takeException(), isNull);
      expect(f.errors, isEmpty);
    });

    testWidgets('(2) the bracket link in the real Where sheet closes it and '
        'focuses Album on the card', (t) async {
      f.watchErrors();
      await f.pumpHome(t);
      await openFromHome(t);
      final d = st().screenDraft;
      await f.typeLink(t, kFeelGood);
      await tapIn(t, byKey('ytdl-saves-change'));
      await f.drain(t);
      await tapIn(t, byKey('ytdl-where-layout-custom'));
      await f.drain(t);
      await t.enterText(byKey('ytdl-where-custom'), '{{ALBUM}} ({{YEAR}})');
      await f.drain(t);
      expect(byKey('ytdl-where-trap'), findsOneWidget);
      await tapIn(t, byKey('ytdl-where-trap-link'));
      await f.drain(t);
      expect(byKey('ytdl-where-sheet'), findsNothing);
      expect(d.tagsOpen, isTrue);
      expect(d.choice.layout, '{{ALBUM}} ({{YEAR}})');
      expect(d.focusFor(YtdlField.album).hasFocus, isTrue);
      expect(t.takeException(), isNull);
      expect(f.errors, isEmpty);
    });

    testWidgets('(2) a failure while the screen shows: NEEDS A LOOK row + toast', (t) async {
      f.watchErrors();
      await f.pumpHome(t);
      await openFromHome(t);
      await f.typeLink(t, kOneMoreTime);
      await tapIn(t, byKey('ytdl-add'));
      await f.drain(t);
      await t.runAsync(() async => f.h.fake.fail(f.h.fake.tracker.last['pid'] as int));
      await f.settle(t, YtdlServerState.kPollBeat);
      await f.drain(t);
      expect(byKey('ytdl-section-needs-look'), findsOneWidget);
      expect(f.h.toastTexts.last, "Couldn't add “One More Time”");
      expect(t.takeException(), isNull);
      expect(f.errors, isEmpty);
    });

    testWidgets('(2) screen closed mid-add (still Starting…): home card + toast '
        'still arrive', (t) async {
      f.watchErrors();
      await f.pumpHome(t);
      await openFromHome(t);
      await f.typeLink(t, kOneMoreTime);
      f.h.fake.addGate = Completer<void>();
      await tapIn(t, byKey('ytdl-add'));
      await f.settle(t);
      expect(find.text(f.h.l.discoverJobStarting), findsOneWidget);
      await back(t);
      expect(find.text('Adding 1'), findsOneWidget);
      f.h.fake.addGate!.complete();
      await f.drain(t);
      expect(find.text('Adding 1'), findsOneWidget);
      await t.runAsync(() async => f.h.fake.finish(f.h.fake.tracker.last['pid'] as int));
      await f.settle(t, YtdlServerState.kPollBeat);
      await f.drain(t);
      expect(find.text('Added 1'), findsOneWidget);
      expect(f.h.toasts.last.success, isTrue);
      // The kept draft: reopening shows no stale card.
      await openFromHome(t);
      expect(st().screenDraft.link.text, '');
      expect(byKey('ytdl-card'), findsNothing);
      expect(t.takeException(), isNull);
      expect(f.errors, isEmpty);
    });

    final gates = <String, void Function()>{
      'uploads off': () => f.s.noUpload = true,
      'conversion off': () => f.s.transcodeAvailable = false,
      'no library': () => f.s.autoDJPaths = {},
      'Play build': () => YtdlHub.buildShowsEntry = () => resolveYtdlEntry(
          defined: null, play: true, release: true, platform: TargetPlatform.android),
      'iOS release build': () => YtdlHub.buildShowsEntry = () => resolveYtdlEntry(
          defined: null, play: false, release: true, platform: TargetPlatform.iOS),
    };
    for (final g in gates.entries) {
      testWidgets('(1) the rendered home hides the card: ${g.key}', (t) async {
        g.value();
        await f.pumpHome(t);
        expect(find.text('Add torrent'), findsOneWidget);
        expect(find.text('Add from YouTube'), findsNothing);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('(1) a peer: no SERVER group, no card', (t) async {
      final peer = ytdlPeerOf(f.s);
      ServerManager().serverList.add(peer);
      ServerManager().currentServer = peer;
      f.phone(t);
      BrowserManager().goToNavScreen();
      expect(BrowserManager().browserList.where((e) => e.data == 'ytdl'), isEmpty);
    });
  });

  group('the explorer: sheet, strip, re-list (flow 3)', () {
    final f = Flows();
    setUp(f.setUp);
    tearDown(f.tearDown);

    YtdlServerState st() => f.h.hub.stateFor(f.s);
    final strip = byKey('ytdl-strip');
    final failedStrip = byKey('ytdl-strip-failed');

    ListTile tile(WidgetTester t, String name) => t.widget<ListTile>(
        find.ancestor(of: find.text(name), matching: find.byType(ListTile)));

    testWidgets('(3) folder with songs: ⋮ → sheet → Sort into subfolders… → '
        'Album → Done → Add to library → closes → strip → re-list + tint → gone',
        (t) async {
      f.watchErrors();
      f.h.fake.folder(homework, files: ['Da Funk.mp3']);
      await f.pumpExplorer(t, homework, [f.fileRow(homework, 'Da Funk.mp3')]);
      expect(byKey('ytdl-explorer-button'), findsNothing);
      await t.tap(find.byIcon(Icons.more_vert));
      await f.drain(t, rounds: 1);
      await t.tap(byKey('ytdl-explorer-menu-item'));
      await f.drain(t);
      expect(find.byType(YtdlFolderSheet), findsOneWidget);
      final d = st().folderDraft(homework);
      expect(d.attached, isTrue);

      await f.typeLink(t, kOneMoreTime);
      expect(byKey('ytdl-card'), findsOneWidget);
      await tapIn(t, byKey('ytdl-sort-subfolders'));
      await f.drain(t);
      expect(byKey('ytdl-subfolders'), findsOneWidget);
      await tapIn(t, byKey('ytdl-sub-album'));
      await f.settle(t, YtdlDraft.kCheckAfter);
      await f.drain(t);
      expect(byKey('ytdl-sub-new'), findsOneWidget);
      await tapIn(t, byKey('ytdl-sub-done'));
      await f.drain(t);
      expect(byKey('ytdl-subfolders'), findsNothing);
      expect(d.target.directory, '${homework}Discovery/');
      expect(find.text('Add to library'), findsOneWidget);

      f.h.fake.addGate = Completer<void>();
      await tapIn(t, byKey('ytdl-add'));
      await f.settle(t);
      expect(find.byType(YtdlFolderSheet), findsOneWidget, reason: 'stays while starting');
      expect(byKey('ytdl-already-adding'), findsNothing);
      f.h.fake.addGate!.complete();
      await f.drain(t);
      expect(find.byType(YtdlFolderSheet), findsNothing, reason: 'closes on 200');
      expect(f.h.fake.count('POST', '/file-explorer/mkdir'), 1);
      expect(strip, findsOneWidget);
      expect(find.text('Adding “One More Time”…'), findsOneWidget);

      // Parent folder: strip too; sibling: none.
      await t.runAsync(() async => f.h.fake.finish(f.h.fake.tracker.last['pid'] as int));
      await f.settle(t, YtdlServerState.kPollBeat);
      await f.drain(t);
      expect(strip, findsNothing);
      expect(failedStrip, findsNothing);
      expect(find.text('Discovery'), findsOneWidget, reason: 're-listed');
      expect(tile(t, 'Discovery').tileColor, VelvetColors.primaryDim);
      await f.settle(t, YtdlRowHighlight.kFor);
      await t.pump();
      expect(tile(t, 'Discovery').tileColor, isNull);
      expect(f.h.toasts.last.success, isTrue);
      expect(t.takeException(), isNull);
      expect(f.errors, isEmpty);
    });

    testWidgets('(3) folder without songs: icon → sheet → Add here → strip in '
        'parents only → re-list tints the file', (t) async {
      f.watchErrors();
      for (final n in ['Homework', 'Human After All']) {
        f.h.fake.folder('$daftPunk$n/');
      }
      final rows = [f.folderRow(daftPunk, 'Homework'), f.folderRow(daftPunk, 'Human After All')];
      await f.pumpExplorer(t, daftPunk, rows);
      await t.tap(byKey('ytdl-explorer-button'));
      await f.drain(t);
      expect(find.byType(YtdlFolderSheet), findsOneWidget);
      await f.typeLink(t, kOneMoreTime);
      expect(find.text('Add here'), findsOneWidget);
      await tapIn(t, byKey('ytdl-add'));
      await f.drain(t);
      expect(find.byType(YtdlFolderSheet), findsNothing);
      expect(f.h.fake.bodies('POST', '/api/v1/ytdl/').single['directory'], daftPunk);
      expect(f.h.fake.count('POST', '/file-explorer/mkdir'), 0);
      expect(strip, findsOneWidget);

      // Into a child folder: no strip (only the target and its parents).
      BrowserManager().addListToStack([f.fileRow(homework, 'Da Funk.mp3')], path: homework);
      await f.drain(t);
      expect(strip, findsNothing);
      BrowserManager().popBrowser();
      await f.drain(t);
      expect(strip, findsOneWidget);

      await t.runAsync(() async => f.h.fake.finish(f.h.fake.tracker.last['pid'] as int));
      await f.settle(t, YtdlServerState.kPollBeat);
      await f.drain(t);
      expect(strip, findsNothing);
      expect(find.text('One_More_Time.mp3'), findsOneWidget);
      final lit = find.ancestor(of: find.text('One_More_Time.mp3'), matching: find.byType(Material)).first;
      expect(t.widget<Material>(lit).color, Color.alphaBlend(VelvetColors.primaryDim, VelvetColors.bg));
      expect(t.takeException(), isNull);
      expect(f.errors, isEmpty);
    });

    testWidgets('(3) failure: strip "Couldn\'t add … · Details" → the screen '
        'scrolled to NEEDS A LOOK', (t) async {
      f.watchErrors();
      // Something long in ADDED so NEEDS A LOOK would be off screen.
      for (var i = 0; i < 12; i++) {
        f.h.fake.addRecord(relativePath: 'Old/Song_$i.mp3', origin: 'https://www.youtube.com/watch?v=o$i', title: 'Old $i');
      }
      f.h.fake.folder(homework, files: ['Da Funk.mp3']);
      await f.pumpExplorer(t, homework, [f.fileRow(homework, 'Da Funk.mp3')]);
      await t.tap(find.byIcon(Icons.more_vert));
      await f.drain(t, rounds: 1);
      await t.tap(byKey('ytdl-explorer-menu-item'));
      await f.drain(t);
      await f.typeLink(t, kOneMoreTime);
      await tapIn(t, byKey('ytdl-add'));
      await f.drain(t);
      expect(strip, findsOneWidget);
      await t.runAsync(() async => f.h.fake.fail(f.h.fake.tracker.last['pid'] as int));
      await f.settle(t, YtdlServerState.kPollBeat);
      await f.drain(t);
      expect(failedStrip, findsOneWidget);
      expect(find.text("Couldn't add “One More Time”"), findsOneWidget);
      expect(f.h.toastTexts.last, "Couldn't add “One More Time”");

      await t.tap(byKey('ytdl-strip-details'));
      await f.drain(t);
      expect(find.byType(YtdlScreen), findsOneWidget);
      expect(t.widget<YtdlScreen>(find.byType(YtdlScreen)).openNeedsLook, isTrue);
      final header = byKey('ytdl-section-needs-look');
      expect(header, findsOneWidget);
      final r = t.getRect(header);
      expect(r.top, greaterThanOrEqualTo(0));
      expect(r.bottom, lessThanOrEqualTo(844));
      // Back: the strip is gone (seen).
      t.state<NavigatorState>(find.byType(Navigator).first).pop();
      await f.drain(t);
      expect(failedStrip, findsNothing);
      expect(t.takeException(), isNull);
      expect(f.errors, isEmpty);
    });

    testWidgets('(3) the sheet dragged away while Starting…: the 200 still lands, '
        'the strip shows, the draft is reset for the next open', (t) async {
      f.watchErrors();
      f.h.fake.folder(homework, files: ['Da Funk.mp3']);
      await f.pumpExplorer(t, homework, [f.fileRow(homework, 'Da Funk.mp3')]);
      await t.tap(find.byIcon(Icons.more_vert));
      await f.drain(t, rounds: 1);
      await t.tap(byKey('ytdl-explorer-menu-item'));
      await f.drain(t);
      await f.typeLink(t, kOneMoreTime);
      f.h.fake.addGate = Completer<void>();
      await tapIn(t, byKey('ytdl-add'));
      await f.settle(t);
      await t.drag(find.byType(YtdlFolderSheet), const Offset(0, 600));
      await f.drain(t);
      expect(find.byType(YtdlFolderSheet), findsNothing);
      expect(strip, findsOneWidget, reason: 'a starting job is open: the strip shows');
      f.h.fake.addGate!.complete();
      await f.drain(t);
      expect(strip, findsOneWidget);
      expect(st().adding.single.pid, isNotNull);
      expect(st().folderDraft(homework).link.text, '');
      await t.runAsync(() async => f.h.fake.finish(f.h.fake.tracker.last['pid'] as int));
      await f.settle(t, YtdlServerState.kPollBeat);
      await f.drain(t);
      expect(strip, findsNothing);
      expect(find.text('One_More_Time.mp3'), findsOneWidget);
      expect(t.takeException(), isNull);
      expect(f.errors, isEmpty);
    });
  });

  group('Details under a tall ADDING (flow 3)', () {
    final f = Flows();
    setUp(f.setUp);
    tearDown(f.tearDown);

    testWidgets('Details → NEEDS A LOOK in view under a tall ADDING', (t) async {
      f.watchErrors();
      final now = f.h.clock.current.millisecondsSinceEpoch;
      final jobs = <Map<String, dynamic>>[];
      for (var i = 0; i < 10; i++) {
        final url = 'https://www.youtube.com/watch?v=run$i';
        final e = f.h.fake.addEntry(url: url, directory: '/Music/Other/');
        jobs.add({
          'id': 'a$i',
          'url': url,
          'directory': '/Music/Other/',
          'codec': 'mp3',
          'title': 'Running $i',
          'predictedName': 'Running_$i.mp3',
          'createdAt': now - i * 1000,
          'state': 'adding',
          'pid': e['pid'],
        });
      }
      jobs.add({
        'id': 'f1',
        'url': kFeelGood,
        'directory': homework,
        'codec': 'mp3',
        'title': 'Feel Good Inc.',
        'predictedName': 'Feel_Good_Inc.mp3',
        'createdAt': now - 60000,
        'endedAt': now - 30000,
        'state': 'failed',
      });
      f.s.ytdlJobs = jobs;
      f.h.fake.folder(homework, files: ['Da Funk.mp3']);
      await f.pumpExplorer(t, homework, [f.fileRow(homework, 'Da Funk.mp3')]);
      await f.drain(t);
      expect(byKey('ytdl-strip-failed'), findsOneWidget);
      await t.tap(byKey('ytdl-strip-details'));
      await f.drain(t);
      expect(find.byType(YtdlScreen), findsOneWidget);
      final header = byKey('ytdl-section-needs-look');
      expect(header, findsOneWidget);
      final r = t.getRect(header);
      expect(r.top, greaterThanOrEqualTo(56), reason: '$r');
      expect(r.bottom, lessThanOrEqualTo(844), reason: '$r');
      expect(f.h.hub.stateFor(f.s).summary.failed, 0, reason: 'seen');
      expect(t.takeException(), isNull);
      expect(f.errors, isEmpty);
    });
  });

  group('an account that can\'t make folders (flow 4)', () {
    final f = Flows();
    tearDown(f.tearDown);

    YtdlServerState st() => f.h.hub.stateFor(f.s);
    final chooser = find.byType(YtdlChooseFolderSheet);

    Future<void> openFromHome(WidgetTester t) async {
      await t.tap(find.text('Add from YouTube'));
      await f.drain(t);
      expect(find.byType(YtdlScreen), findsOneWidget);
    }

    testWidgets('(4) screen, noMkdir: a new folder → three choices → Choose a '
        'folder… → real picker → Homework → Add posts there, no mkdir', (t) async {
      f.setUp(server: ytdlServer(noMkdir: true, formats: const ['mp3']));
      f.watchErrors();
      f.h.fake.folder(daftPunk);
      f.h.fake.folder(homework);
      await f.pumpHome(t);
      await openFromHome(t);
      final d = st().screenDraft;
      await f.typeLink(t, kOneMoreTime);
      expect(d.target.directory, discovery);
      expect(d.block, YtdlBlock.mkdirBlocked);
      expect(byKey('ytdl-nomkdir'), findsOneWidget);
      expect(byKey('ytdl-save-deepest'), findsOneWidget);
      expect(byKey('ytdl-use-top'), findsOneWidget);
      await tapIn(t, byKey('ytdl-choose-folder'));
      await f.drain(t);
      expect(chooser, findsOneWidget);
      // Opens at the deepest folder that listed.
      expect(t.widget<YtdlChooseFolderSheet>(chooser).startAt, daftPunk);
      await t.tap(byKey('ytdl-choose-folder-Homework'));
      await f.drain(t);
      await t.tap(byKey('ytdl-choose-use'));
      await f.drain(t);
      expect(chooser, findsNothing);
      expect(d.justThisSong, YtdlChoice.folder(homework));
      expect(d.block, YtdlBlock.none);
      await tapIn(t, byKey('ytdl-add'));
      await f.drain(t);
      expect(f.h.fake.bodies('POST', '/api/v1/ytdl/').single['directory'], homework);
      expect(f.h.fake.count('POST', '/file-explorer/mkdir'), 0);
      expect(t.takeException(), isNull);
      expect(f.errors, isEmpty);
    });

    testWidgets('(4) folder sheet, stale noMkdir (mkdir 403): the panel\'s Choose '
        'a folder… → sheet closes → real picker → sheet back with the pick → Add',
        (t) async {
      f.setUp(server: ytdlServer(formats: const ['mp3']));
      f.watchErrors();
      f.h.hub.reping = (s) async => s.noMkdir = true;
      for (final n in ['Homework', 'Human After All']) {
        f.h.fake.folder('$daftPunk$n/');
      }
      await f.pumpExplorer(t, daftPunk,
          [f.folderRow(daftPunk, 'Homework'), f.folderRow(daftPunk, 'Human After All')]);
      await t.tap(byKey('ytdl-explorer-button'));
      await f.drain(t);
      final d = st().folderDraft(daftPunk);
      await f.typeLink(t, kOneMoreTime);
      await tapIn(t, byKey('ytdl-sort-subfolders'));
      await f.drain(t);
      await tapIn(t, byKey('ytdl-sub-album'));
      await f.drain(t);
      await tapIn(t, byKey('ytdl-sub-done'));
      await f.drain(t);
      f.h.fake.mkdirRefusal = (403, 'Access Denied');
      await tapIn(t, byKey('ytdl-add'));
      await f.drain(t);
      expect(find.byType(YtdlFolderSheet), findsOneWidget, reason: 'refusal shows inside');
      expect(st().mkdirRefused, isTrue);
      expect(st().jobs, isEmpty, reason: 'shown inline, not a row');
      expect(byKey('ytdl-nomkdir'), findsOneWidget);
      await tapIn(t, byKey('ytdl-choose-folder'));
      await f.drain(t);
      expect(find.byType(YtdlFolderSheet), findsNothing, reason: 'never a sheet over a sheet');
      expect(chooser, findsOneWidget);
      await t.tap(byKey('ytdl-choose-folder-Homework'));
      await f.drain(t);
      await t.tap(byKey('ytdl-choose-use'));
      await f.drain(t);
      await f.settle(t, YtdlDraft.kCheckAfter);
      await f.drain(t);
      expect(find.byType(YtdlFolderSheet), findsOneWidget, reason: 'back with the pick');
      expect(d.justThisSong, YtdlChoice.folder(homework));
      expect(d.block, YtdlBlock.none);
      await tapIn(t, byKey('ytdl-add'));
      await f.drain(t);
      expect(find.byType(YtdlFolderSheet), findsNothing);
      expect(f.h.fake.bodies('POST', '/api/v1/ytdl/').single['directory'], homework);
      expect(f.h.fake.count('POST', '/file-explorer/mkdir'), 1, reason: 'only the refused one');
      expect(t.takeException(), isNull);
      expect(f.errors, isEmpty);
    });

    testWidgets('(4) a NEEDS A LOOK row (mkdir 403 after the sheet was dragged '
        'away) → strip Details → row Choose a folder… → picker → added there',
        (t) async {
      f.setUp(server: ytdlServer(formats: const ['mp3']));
      f.watchErrors();
      f.h.hub.reping = (s) async => s.noMkdir = true;
      f.h.fake.folder(homework);
      await f.pumpExplorer(t, daftPunk, [f.folderRow(daftPunk, 'Homework')]);
      await t.tap(byKey('ytdl-explorer-button'));
      await f.drain(t);
      await f.typeLink(t, kOneMoreTime);
      await tapIn(t, byKey('ytdl-sort-subfolders'));
      await f.drain(t);
      await tapIn(t, byKey('ytdl-sub-album'));
      await f.drain(t);
      await tapIn(t, byKey('ytdl-sub-done'));
      await f.drain(t);
      f.h.fake.mkdirRefusal = (403, 'Access Denied');
      f.h.fake.mkdirGate = Completer<void>();
      await tapIn(t, byKey('ytdl-add'));
      await f.settle(t);
      // Dragged away while starting.
      await t.tap(byKey('ytdl-sheet-close'));
      await f.drain(t);
      expect(find.byType(YtdlFolderSheet), findsNothing);
      f.h.fake.mkdirGate!.complete();
      await f.drain(t);
      final row = st().needsLook.single;
      expect(row.state, YtdlJobState.startFailed);
      expect(row.problem, 'mkdirOff');
      expect(f.h.toastTexts.last, "Couldn't add “One More Time”");
      expect(byKey('ytdl-strip-failed'), findsOneWidget);
      await t.tap(byKey('ytdl-strip-details'));
      await f.drain(t);
      expect(find.byType(YtdlScreen), findsOneWidget);
      await tapIn(t, byKey('ytdl-row-choose-folder-${row.id}'));
      await f.drain(t);
      expect(chooser, findsOneWidget);
      await t.tap(byKey('ytdl-choose-folder-Daft Punk'));
      await f.drain(t);
      await t.tap(byKey('ytdl-choose-folder-Homework'));
      await f.drain(t);
      await t.tap(byKey('ytdl-choose-use'));
      await f.drain(t);
      expect(chooser, findsNothing);
      expect(f.h.fake.bodies('POST', '/api/v1/ytdl/').single['directory'], homework);
      expect(f.h.fake.count('POST', '/file-explorer/mkdir'), 1);
      expect(st().needsLook, isEmpty);
      expect(st().adding, hasLength(1));
      expect(t.takeException(), isNull);
      expect(f.errors, isEmpty);
    });
  });

  group('the feature turned off with something open (flow 5)', () {
    final f = Flows();
    setUp(() {
      f.setUp();
      // The re-ping confirms the account may not upload any more.
      f.h.hub.reping = (s) async => s.noUpload = true;
    });
    tearDown(f.tearDown);

    YtdlServerState st() => f.h.hub.stateFor(f.s);
    String upOff() => f.h.l.ytdlErrUploadsOff;

    /// Another add (no surface: e.g. a retry from elsewhere) refused 403 →
    /// re-ping → the feature is off for this account.
    Future<void> refusedElsewhere(WidgetTester t) async {
      f.h.fake.addRefusal = (403, 'Uploading Disabled');
      await t.runAsync(() async {
        unawaited(st().start(f.h.request(url: kSweater, directory: '/Music/Other/')));
        await ytdlSettle();
      });
      await f.frames(t);
      await f.drain(t);
      expect(st().entryAllowed, isFalse);
    }

    Future<void> openFromHome(WidgetTester t) async {
      await t.tap(find.text('Add from YouTube'));
      await f.drain(t);
      expect(find.byType(YtdlScreen), findsOneWidget);
    }

    bool addEnabled(WidgetTester t) =>
        t
            .widget<InkWell>(find.descendant(
                of: byKey('ytdl-add'), matching: find.byType(InkWell)))
            .onTap !=
        null;

    /// Spec §8 "Uploads off": the card stays with Add disabled and the
    /// line saying why; nothing toasted it.
    void uploadsOffShown(WidgetTester t) {
      expect(byKey('ytdl-card'), findsOneWidget);
      expect(addEnabled(t), isFalse);
      expect(shows(t, upOff()), isTrue);
      expect(f.h.toastTexts, isNot(contains(upOff())));
    }

    testWidgets('(5) screen + Where sheet open → both stay; closed, the card '
        'reads uploads off with Add disabled', (t) async {
      f.watchErrors();
      await f.pumpHome(t);
      await openFromHome(t);
      await f.typeLink(t, kOneMoreTime);
      await tapIn(t, byKey('ytdl-saves-change'));
      await f.drain(t);
      expect(find.byType(YtdlWhereSheet), findsOneWidget);
      await refusedElsewhere(t);
      expect(find.byType(YtdlWhereSheet), findsOneWidget);
      expect(find.byType(YtdlScreen), findsOneWidget);
      await t.tap(byKey('ytdl-where-close'));
      await f.drain(t);
      expect(find.byType(YtdlWhereSheet), findsNothing);
      expect(find.byType(YtdlScreen), findsOneWidget);
      uploadsOffShown(t);
      f.clean(t);
    });

    testWidgets('(5) screen + Choose a folder (card) open → both stay; the pick '
        'still lands on the card', (t) async {
      f.setUp(server: ytdlServer(noMkdir: true, formats: const ['mp3']));
      f.h.hub.reping = (s) async => s.noUpload = true;
      f.watchErrors();
      f.h.fake.folder(daftPunk);
      f.h.fake.folder(homework);
      await f.pumpHome(t);
      await openFromHome(t);
      await f.typeLink(t, kOneMoreTime);
      await tapIn(t, byKey('ytdl-choose-folder'));
      await f.drain(t);
      expect(find.byType(YtdlChooseFolderSheet), findsOneWidget);
      await refusedElsewhere(t);
      expect(find.byType(YtdlChooseFolderSheet), findsOneWidget);
      await t.tap(byKey('ytdl-choose-folder-Homework'));
      await f.drain(t);
      await t.tap(byKey('ytdl-choose-use'));
      await f.drain(t);
      expect(find.byType(YtdlChooseFolderSheet), findsNothing);
      expect(find.byType(YtdlScreen), findsOneWidget);
      final d = st().screenDraft;
      expect(d.justThisSong, YtdlChoice.folder(homework));
      expect(d.block, YtdlBlock.uploadsOff);
      uploadsOffShown(t);
      f.clean(t);
    });

    testWidgets('(5) screen + a NEEDS A LOOK row\'s format menu open → it '
        'stays, and so does the screen', (t) async {
      f.watchErrors();
      // A clash row with formats to change to.
      f.s.ytdlJobs = [
        {
          'id': 'c1',
          'url': kOneMoreTime,
          'directory': discovery,
          'codec': 'mp3',
          'title': 'One More Time',
          'predictedName': 'One_More_Time.mp3',
          'createdAt': f.h.clock.current.millisecondsSinceEpoch,
          'endedAt': f.h.clock.current.millisecondsSinceEpoch,
          'state': 'failedClash',
        }
      ];
      await f.pumpHome(t);
      await openFromHome(t);
      await tapIn(t, byKey('ytdl-row-change-format-c1'));
      await f.drain(t, rounds: 1);
      expect(byKey('ytdl-row-format-m4a'), findsOneWidget);
      await refusedElsewhere(t);
      expect(byKey('ytdl-row-format-m4a'), findsOneWidget);
      await t.tapAt(const Offset(380, 60));
      await f.drain(t);
      expect(byKey('ytdl-row-format-m4a'), findsNothing);
      expect(find.byType(YtdlScreen), findsOneWidget);
      expect(byKey('ytdl-row-change-format-c1'), findsOneWidget);
      f.clean(t);
    });

    testWidgets('(5) screen + a NEEDS A LOOK row\'s picker open → it stays; '
        'cancelled, the row is still there', (t) async {
      f.watchErrors();
      f.s.ytdlJobs = [
        {
          'id': 'm1',
          'url': kOneMoreTime,
          'directory': discovery,
          'codec': 'mp3',
          'title': 'One More Time',
          'predictedName': 'One_More_Time.mp3',
          'createdAt': f.h.clock.current.millisecondsSinceEpoch,
          'endedAt': f.h.clock.current.millisecondsSinceEpoch,
          'state': 'startFailed',
          'problem': 'mkdirFailed',
          'problemDetail': 'Discovery',
        }
      ];
      f.h.fake.folder(daftPunk);
      await f.pumpHome(t);
      await openFromHome(t);
      await tapIn(t, byKey('ytdl-row-choose-folder-m1'));
      await f.drain(t);
      expect(find.byType(YtdlChooseFolderSheet), findsOneWidget);
      await refusedElsewhere(t);
      expect(find.byType(YtdlChooseFolderSheet), findsOneWidget);
      await t.tap(byKey('ytdl-choose-cancel'));
      await f.drain(t);
      expect(find.byType(YtdlChooseFolderSheet), findsNothing);
      expect(find.byType(YtdlScreen), findsOneWidget);
      expect(byKey('ytdl-row-choose-folder-m1'), findsOneWidget);
      f.clean(t);
    });

    testWidgets('(5) folder sheet open (first page) → it stays with Add off and '
        'the line, no toast; the toolbar entry goes', (t) async {
      f.watchErrors();
      await f.pumpExplorer(t, daftPunk, [f.folderRow(daftPunk, 'Homework')]);
      await t.tap(byKey('ytdl-explorer-button'));
      await f.drain(t);
      await f.typeLink(t, kOneMoreTime);
      await refusedElsewhere(t);
      expect(find.byType(YtdlFolderSheet), findsOneWidget);
      uploadsOffShown(t);
      expect(byKey('ytdl-explorer-button'), findsNothing);
      f.clean(t);
    });

    testWidgets('(5) folder sheet on its subfolders page → it stays on that page',
        (t) async {
      f.watchErrors();
      await f.pumpExplorer(t, daftPunk, [f.folderRow(daftPunk, 'Homework')]);
      await t.tap(byKey('ytdl-explorer-button'));
      await f.drain(t);
      await f.typeLink(t, kOneMoreTime);
      await tapIn(t, byKey('ytdl-sort-subfolders'));
      await f.drain(t);
      expect(byKey('ytdl-subfolders'), findsOneWidget);
      await refusedElsewhere(t);
      expect(byKey('ytdl-subfolders'), findsOneWidget);
      expect(f.h.toastTexts, isNot(contains(upOff())));
      await tapIn(t, byKey('ytdl-sub-back'));
      await f.drain(t);
      expect(find.byType(YtdlFolderSheet), findsOneWidget);
      uploadsOffShown(t);
      f.clean(t);
    });

    testWidgets('(5) folder sheet + its format menu open → both stay', (t) async {
      f.watchErrors();
      await f.pumpExplorer(t, daftPunk, [f.folderRow(daftPunk, 'Homework')]);
      await t.tap(byKey('ytdl-explorer-button'));
      await f.drain(t);
      await f.typeLink(t, kOneMoreTime);
      await tapIn(t, byKey('ytdl-format'));
      await f.drain(t, rounds: 1);
      expect(byKey('ytdl-format-menu'), findsOneWidget);
      await refusedElsewhere(t);
      expect(byKey('ytdl-format-menu'), findsOneWidget);
      expect(find.byType(YtdlFolderSheet), findsOneWidget);
      await t.tapAt(const Offset(380, 60));
      await f.drain(t);
      expect(byKey('ytdl-format-menu'), findsNothing);
      expect(find.byType(YtdlFolderSheet), findsOneWidget);
      uploadsOffShown(t);
      f.clean(t);
    });

    testWidgets('(5) the folder sheet\'s own add refused 403 → inline, re-ping → '
        'the sheet stays with Add off, no toast, no row, no strip', (t) async {
      f.watchErrors();
      f.h.fake.folder(homework, files: ['Da Funk.mp3']);
      await f.pumpExplorer(t, homework, [f.fileRow(homework, 'Da Funk.mp3')]);
      await t.tap(find.byIcon(Icons.more_vert));
      await f.drain(t, rounds: 1);
      await t.tap(byKey('ytdl-explorer-menu-item'));
      await f.drain(t);
      await f.typeLink(t, kOneMoreTime);
      f.h.fake.addRefusal = (403, 'Uploading Disabled');
      await tapIn(t, byKey('ytdl-add'));
      await f.drain(t);
      expect(st().entryAllowed, isFalse);
      expect(find.byType(YtdlFolderSheet), findsOneWidget);
      uploadsOffShown(t);
      expect(f.h.toastTexts, isEmpty);
      expect(st().jobs, isEmpty);
      expect(byKey('ytdl-strip'), findsNothing);
      expect(byKey('ytdl-strip-failed'), findsNothing);
      f.clean(t);
    });
  });

  group('backgrounded, reopened, two servers (flow 6)', () {
    final f = Flows();
    setUp(f.setUp);
    tearDown(f.tearDown);

    YtdlServerState st([Server? s]) => f.h.hub.stateFor(s ?? f.s);

    Future<void> openFromHome(WidgetTester t) async {
      await t.tap(find.text('Add from YouTube'));
      await f.drain(t);
      expect(find.byType(YtdlScreen), findsOneWidget);
    }

    Future<void> back(WidgetTester t) async {
      t.state<NavigatorState>(find.byType(Navigator).first).pop();
      await f.drain(t);
    }

    testWidgets('(6) backgrounded with a job open: no polls while away; resumed: '
        'one poll at once, the ending settles, toast, home line', (t) async {
      f.watchErrors();
      await f.pumpHome(t);
      await openFromHome(t);
      await f.typeLink(t, kOneMoreTime);
      await tapIn(t, byKey('ytdl-add'));
      await f.drain(t);
      await back(t);
      expect(find.text('Adding 1'), findsOneWidget);
      final polls = f.h.fake.count('GET', '/ytdl/downloads');

      f.h.hub.didChangeAppLifecycleState(AppLifecycleState.inactive);
      f.h.hub.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(st().pollScheduled, isFalse);
      await t.runAsync(() async => f.h.fake.finish(f.h.fake.tracker.last['pid'] as int));
      await f.settle(t, const Duration(seconds: 30));
      await f.drain(t);
      expect(f.h.fake.count('GET', '/ytdl/downloads'), polls, reason: 'paused');
      expect(find.text('Adding 1'), findsOneWidget);

      f.h.hub.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await f.drain(t);
      expect(f.h.fake.count('GET', '/ytdl/downloads'), polls + 1);
      expect(find.text('Added 1'), findsOneWidget);
      expect(f.h.toasts.last.success, isTrue);
      expect(st().pollScheduled, isFalse, reason: 'nothing open any more');
      expect(t.takeException(), isNull);
      expect(f.errors, isEmpty);
    });

    testWidgets('(6) away past the tracker\'s 30 s: the entry is gone; the record '
        'settles it added on resume', (t) async {
      f.watchErrors();
      await f.pumpHome(t);
      await openFromHome(t);
      await f.typeLink(t, kOneMoreTime);
      await tapIn(t, byKey('ytdl-add'));
      await f.drain(t);
      await back(t);
      f.h.hub.didChangeAppLifecycleState(AppLifecycleState.paused);
      await t.runAsync(() async {
        final pid = f.h.fake.tracker.last['pid'] as int;
        f.h.fake.finish(pid);
        f.h.fake.forget(pid);
      });
      await f.settle(t, const Duration(minutes: 5));
      f.h.hub.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await f.drain(t);
      expect(find.text('Added 1'), findsOneWidget);
      expect(st().added, hasLength(1));
      expect(t.takeException(), isNull);
      expect(f.errors, isEmpty);
    });

    testWidgets('(6) the screen reopened: a lookup that landed while away fills '
        'the kept draft; a typed edit stays', (t) async {
      f.watchErrors();
      await f.pumpHome(t);
      await openFromHome(t);
      f.h.fake.holdLookups = true;
      await t.enterText(byKey('ytdl-link'), kOneMoreTime);
      await f.settle(t, YtdlDraft.kLookupDebounce);
      expect(byKey('ytdl-skeleton'), findsOneWidget);
      await back(t);
      expect(find.byType(YtdlScreen), findsNothing);
      f.h.fake.heldLookups.single.complete();
      await f.drain(t);
      final d = st().screenDraft;
      expect(d.lookup, YtdlLookupState.found);
      await openFromHome(t);
      expect(byKey('ytdl-card'), findsOneWidget);
      expect(find.text('One More Time'), findsWidgets);
      await tapIn(t, byKey('ytdl-edit-tags'));
      await f.drain(t);
      await t.enterText(byKey('ytdl-field-title'), 'One More Time (Live)');
      await f.drain(t);
      await back(t);
      await openFromHome(t);
      expect(st().screenDraft.controllerFor(YtdlField.title).text, 'One More Time (Live)');
      expect(find.text('One More Time (Live)'), findsWidgets);
      expect(t.takeException(), isNull);
      expect(f.errors, isEmpty);
    });

    testWidgets('(6) two own servers: state per server; switching the current '
        'server shows the other one\'s card without the first one\'s add', (t) async {
      f.watchErrors();
      final other = Server('http://other.example', null, null, 'JWT', 'office')
        ..autoDJPaths = {'Music': true};
      ServerManager().serverList.add(other);
      await f.pumpHome(t);
      await openFromHome(t);
      expect(byKey('ytdl-server-name'), findsOneWidget);
      await f.typeLink(t, kOneMoreTime);
      await tapIn(t, byKey('ytdl-add'));
      await f.drain(t);
      await back(t);
      expect(find.text('Adding 1'), findsOneWidget);
      expect(identical(st(other), st()), isFalse);
      expect(st(other).adding, isEmpty);

      ServerManager().currentServer = other;
      await f.pumpHome(t);
      await f.drain(t);
      expect(find.text('Add from YouTube'), findsOneWidget);
      expect(find.text('Adding 1'), findsNothing);
      await openFromHome(t);
      expect(t.widget<YtdlScreen>(find.byType(YtdlScreen)).server, same(other));
      expect(byKey('ytdl-section-adding'), findsNothing);
      expect(st(other).screenDraft.link.text, '');
      await back(t);

      // The first server's job still ends (its poll runs), toasting.
      await t.runAsync(() async => f.h.fake.finish(f.h.fake.tracker.last['pid'] as int));
      await f.settle(t, YtdlServerState.kPollBeat);
      await f.drain(t);
      expect(st().added, hasLength(1));
      expect(f.h.toasts.last.success, isTrue);
      expect(find.text('Added 1'), findsNothing, reason: 'the other server\'s home');
      expect(t.takeException(), isNull);
      expect(f.errors, isEmpty);
    });
  });

  group('more screen journeys', () {
    final f = Flows();
    setUp(f.setUp);
    tearDown(f.tearDown);

    YtdlServerState st() => f.h.hub.stateFor(f.s);

    Future<void> openFromHome(WidgetTester t) async {
      await t.tap(find.text('Add from YouTube'));
      await f.drain(t);
      expect(find.byType(YtdlScreen), findsOneWidget);
    }

    testWidgets('"Add a year" in the real Where sheet: closes, Year focused and '
        'visible above the action bar', (t) async {
      f.watchErrors();
      await f.pumpHome(t);
      await openFromHome(t);
      final d = st().screenDraft;
      await f.typeLink(t, kOneMoreTime);
      // No year for this song.
      await tapIn(t, byKey('ytdl-edit-tags'));
      await f.drain(t);
      await t.enterText(byKey('ytdl-field-year'), '');
      await f.drain(t);
      FocusManager.instance.primaryFocus?.unfocus();
      await f.drain(t);
      await tapIn(t, byKey('ytdl-saves-change'));
      await f.drain(t);
      await tapIn(t, byKey('ytdl-where-layout-custom'));
      await f.drain(t);
      await t.enterText(byKey('ytdl-where-custom'), '{{ARTIST}}/{{ALBUM}} ({{YEAR}})');
      await f.drain(t);
      expect(byKey('ytdl-where-trap'), findsOneWidget);
      await tapIn(t, byKey('ytdl-where-trap-link'));
      await f.drain(t);
      expect(byKey('ytdl-where-sheet'), findsNothing);
      expect(d.focusFor(YtdlField.year).hasFocus, isTrue);
      final field = t.getRect(byKey('ytdl-field-year'));
      final bar = t.getRect(byKey('ytdl-add'));
      expect(field.top, greaterThanOrEqualTo(56), reason: 'below the app bar: $field');
      expect(field.bottom, lessThanOrEqualTo(bar.top), reason: 'above the bar: $field vs $bar');
      expect(t.takeException(), isNull);
      expect(f.errors, isEmpty);
    });

    testWidgets('the card\'s own add refused 403: inline line, re-ping → the '
        'screen stays with Add off, no toast, no row; a lookup still runs',
        (t) async {
      f.watchErrors();
      f.h.hub.reping = (s) async => s.noUpload = true;
      await f.pumpHome(t);
      await openFromHome(t);
      await f.typeLink(t, kOneMoreTime);
      f.h.fake.addRefusal = (403, 'Uploading Disabled');
      await tapIn(t, byKey('ytdl-add'));
      await f.drain(t);
      expect(st().entryAllowed, isFalse);
      expect(find.byType(YtdlScreen), findsOneWidget);
      expect(byKey('ytdl-card'), findsOneWidget);
      expect(
          t
              .widget<InkWell>(find.descendant(
                  of: byKey('ytdl-add'), matching: find.byType(InkWell)))
              .onTap,
          isNull);
      expect(shows(t, f.h.l.ytdlErrUploadsOff), isTrue);
      expect(f.h.toastTexts, isEmpty);
      expect(st().jobs, isEmpty);
      await f.typeLink(t, kFeelGood);
      expect(st().screenDraft.lookup, YtdlLookupState.found);
      expect(f.h.fake.count('GET', '/api/v1/ytdl/metadata'), 2);
      f.clean(t);
    });

    testWidgets('the card\'s own add refused "FFmpeg is not available yet", '
        're-ping says not ready → the button goes, the line stays, the '
        'screen and its lookup go on', (t) async {
      f.watchErrors();
      f.h.hub.reping = (s) async => s.transcodeAvailable = false;
      await f.pumpHome(t);
      await openFromHome(t);
      await f.typeLink(t, kOneMoreTime);
      f.h.fake.addRefusal = (500, 'FFmpeg is not available yet');
      await tapIn(t, byKey('ytdl-add'));
      await f.drain(t);
      expect(st().entryAllowed, isFalse);
      expect(find.byType(YtdlScreen), findsOneWidget);
      expect(byKey('ytdl-add'), findsNothing);
      expect(byKey('ytdl-format'), findsOneWidget);
      expect(shows(t, f.h.l.ytdlErrFfmpeg), isTrue);
      expect(f.h.toastTexts, isEmpty);
      await f.typeLink(t, kFeelGood);
      expect(st().screenDraft.lookup, YtdlLookupState.found);
      expect(byKey('ytdl-card'), findsOneWidget);
      expect(shows(t, f.h.l.ytdlErrFfmpeg), isTrue);
      f.clean(t);
    });

    testWidgets('ffmpeg 500, re-ping still says ready: the screen stays, '
        'inline line, Try again posts once more', (t) async {
      f.watchErrors();
      await f.pumpHome(t);
      await openFromHome(t);
      await f.typeLink(t, kOneMoreTime);
      f.h.fake.addRefusal = (500, 'FFmpeg is not available yet');
      await tapIn(t, byKey('ytdl-add'));
      await f.drain(t);
      expect(find.byType(YtdlScreen), findsOneWidget);
      expect(byKey('ytdl-add-error'), findsOneWidget);
      f.h.fake.addRefusal = null;
      await tapIn(t, byKey('ytdl-add'));
      await f.drain(t);
      expect(f.h.fake.count('POST', '/api/v1/ytdl/'), 2);
      expect(byKey('ytdl-section-adding'), findsOneWidget);
      expect(t.takeException(), isNull);
      expect(f.errors, isEmpty);
    });
  });

  group('regressions found in review', () {
    final f = Flows();
    setUp(f.setUp);
    tearDown(f.tearDown);

    YtdlServerState st() => f.h.hub.stateFor(f.s);

    /// The server's client with the record reads past [failFrom] thrown
    /// and past [holdFrom] held on [hold].
    int reads = 0;
    int? failFrom;
    int? holdFrom;
    Completer<void>? hold;
    void watchRecords() {
      reads = 0;
      failFrom = holdFrom = null;
      hold = null;
      f.h.hub.makeApi = (s) => YtdlApi(s,
          client: MockClient((req) async {
            if (req.url.path.endsWith('/api/v1/discovery/downloads')) {
              final n = ++reads;
              if (failFrom != null && n >= failFrom!) {
                throw http.ClientException('Connection reset by peer');
              }
              if (holdFrom != null && n >= holdFrom!) await hold!.future;
            }
            return f.h.fake.handle(req);
          }),
          awaitTunnel: (_) async => true);
    }

    testWidgets('6.30+: the record read after the settle fails → the song '
        'stays under ADDED on the open screen (spec §6)', (t) async {
      f.watchErrors();
      watchRecords();
      await f.pumpHome(t);
      await f.openFromHome(t);
      expect(st().tier, YtdlServerTier.full);
      await f.typeLink(t, kOneMoreTime);
      await tapIn(t, byKey('ytdl-add'));
      await f.drain(t);
      expect(byKey('ytdl-section-adding'), findsOneWidget);
      // Its own record page answers; the refresh after it fails.
      failFrom = reads + 2;
      await t.runAsync(() async =>
          f.h.fake.finish(f.h.fake.tracker.last['pid'] as int));
      await f.settle(t, YtdlServerState.kPollBeat);
      await f.drain(t);
      expect(st().jobs.single.recordId, isNotNull);
      expect(f.h.toasts.last.success, isTrue);
      expect(byKey('ytdl-section-adding'), findsNothing);
      expect(byKey('ytdl-section-added'), findsOneWidget);
      expect(st().added.map((r) => r.title), ['One More Time']);
      f.clean(t);
    });

    testWidgets('… and between the settle and the refresh answering it is '
        'in a list all along', (t) async {
      f.watchErrors();
      watchRecords();
      await f.pumpHome(t);
      await f.openFromHome(t);
      await f.typeLink(t, kOneMoreTime);
      await tapIn(t, byKey('ytdl-add'));
      await f.drain(t);
      hold = Completer<void>();
      holdFrom = reads + 2;
      await t.runAsync(() async =>
          f.h.fake.finish(f.h.fake.tracker.last['pid'] as int));
      await f.settle(t, YtdlServerState.kPollBeat);
      await t.pump();
      expect(st().jobs.single.recordId, isNotNull);
      expect(st().addedLoading, isTrue);
      expect(st().adding, isEmpty);
      expect(st().added.map((r) => r.title), ['One More Time']);
      hold!.complete();
      await f.drain(t);
      expect(st().added.single.recordId, st().jobs.single.recordId);
      f.clean(t);
    });

    testWidgets('the folder sheet stepped aside for Choose a folder…: the '
        'feature going off leaves the picker open; once it answers, the '
        'sheet stays away and says why (spec §7: nothing opens)', (t) async {
      f.setUp(server: ytdlServer(formats: const ['mp3']));
      f.watchErrors();
      f.h.fake.folder(homework);
      await f.pumpExplorer(t, daftPunk, [f.folderRow(daftPunk, 'Homework')]);
      await t.tap(byKey('ytdl-explorer-button'));
      await f.drain(t);
      await f.typeLink(t, kOneMoreTime);
      await tapIn(t, byKey('ytdl-sort-subfolders'));
      await f.drain(t);
      await tapIn(t, byKey('ytdl-sub-album'));
      await f.drain(t);
      await tapIn(t, byKey('ytdl-sub-done'));
      await f.drain(t);
      f.h.fake.mkdirRefusal = (500, 'EACCES');
      await tapIn(t, byKey('ytdl-add'));
      await f.drain(t);
      await tapIn(t, byKey('ytdl-mkdir-choose'));
      await f.drain(t);
      expect(find.byType(YtdlChooseFolderSheet), findsOneWidget);
      // Another add refused 403; the re-ping says uploads are off.
      f.h.hub.reping = (s) async => s.noUpload = true;
      f.h.fake.addRefusal = (403, 'Uploading Disabled');
      await t.runAsync(() async {
        unawaited(st().start(
            f.h.request(url: kSweater, directory: '/Music/Other/')));
        await ytdlSettle();
      });
      await f.drain(t);
      expect(st().entryAllowed, isFalse);
      expect(find.byType(YtdlChooseFolderSheet), findsOneWidget);
      expect(f.h.toastTexts, isNot(contains(f.h.l.ytdlErrUploadsOff)));
      await t.tap(byKey('ytdl-choose-folder-Homework'));
      await f.drain(t);
      await t.tap(byKey('ytdl-choose-use'));
      await f.drain(t);
      expect(find.byType(YtdlChooseFolderSheet), findsNothing);
      expect(find.byType(YtdlFolderSheet), findsNothing);
      expect(byKey('ytdl-explorer-button'), findsNothing);
      expect(
          f.h.toastTexts.where((m) => m == f.h.l.ytdlErrUploadsOff), hasLength(1));
      f.clean(t);
    });

    testWidgets('a ⋮ menu built before the feature went off: its item opens '
        'no sheet, and says why (spec §7: hidden, never greyed)', (t) async {
      f.watchErrors();
      f.h.fake.folder(homework, files: ['Da Funk.mp3']);
      await f.pumpExplorer(t, homework, [f.fileRow(homework, 'Da Funk.mp3')]);
      await t.runAsync(() => st().probeTier());
      await t.tap(find.byIcon(Icons.more_vert));
      await f.drain(t, rounds: 1);
      expect(byKey('ytdl-explorer-menu-item'), findsOneWidget);
      f.h.hub.reping = (s) async => s.noUpload = true;
      f.h.fake.addRefusal = (403, 'Uploading Disabled');
      await t.runAsync(() async {
        unawaited(st().start(
            f.h.request(url: kSweater, directory: '/Music/Other/')));
        await ytdlSettle();
      });
      await f.drain(t, rounds: 1);
      expect(st().entryAllowed, isFalse);
      // The open menu does not rebuild: the item is still there.
      expect(byKey('ytdl-explorer-menu-item'), findsOneWidget);
      f.h.toasts.clear();
      await t.tap(byKey('ytdl-explorer-menu-item'));
      await f.drain(t);
      expect(find.byType(YtdlFolderSheet), findsNothing);
      expect(f.h.toastTexts, [f.h.l.ytdlErrUploadsOff]);
      f.clean(t);
    });

    testWidgets('a reopened folder sheet starts at Right here; the link it '
        'had stays (spec §7: the subfolder choice lasts for one sheet)',
        (t) async {
      f.watchErrors();
      f.h.fake.folder(homework);
      await f.pumpExplorer(t, daftPunk, [f.folderRow(daftPunk, 'Homework')]);
      await t.tap(byKey('ytdl-explorer-button'));
      await f.drain(t);
      await f.typeLink(t, kOneMoreTime);
      await tapIn(t, byKey('ytdl-sort-subfolders'));
      await f.drain(t);
      await tapIn(t, byKey('ytdl-sub-album'));
      await f.drain(t);
      await tapIn(t, byKey('ytdl-sub-done'));
      await f.drain(t);
      expect(find.text(f.h.l.ytdlAddToLibrary), findsOneWidget);
      await t.tap(byKey('ytdl-sheet-close'));
      await f.drain(t);
      expect(find.byType(YtdlFolderSheet), findsNothing);
      await t.tap(byKey('ytdl-explorer-button'));
      await f.drain(t);
      final d = st().folderDraft(daftPunk);
      expect(d.subLayout, kYtdlLayoutTop);
      expect(d.link.text, kOneMoreTime);
      expect(find.text(f.h.l.ytdlAddHere), findsOneWidget);
      expect(find.text(f.h.l.ytdlSavesHere.toUpperCase()), findsOneWidget);
      expect(d.target.directory, daftPunk);
      f.clean(t);
    });

    testWidgets('the explorer sheet through Sort into subfolders to two adds: '
        '"Adding 2 videos…", both settle, Discovery re-listed and tinted',
        (t) async {
      f.watchErrors();
      for (final n in ['Homework', 'Human After All']) {
        f.h.fake.folder('$daftPunk$n/');
      }
      await f.pumpExplorer(t, daftPunk, [
        f.folderRow(daftPunk, 'Homework'),
        f.folderRow(daftPunk, 'Human After All'),
      ]);
      await t.tap(byKey('ytdl-explorer-button'));
      await f.drain(t);
      await f.typeLink(t, kOneMoreTime);
      await tapIn(t, byKey('ytdl-sort-subfolders'));
      await f.drain(t);
      await tapIn(t, byKey('ytdl-sub-album'));
      await f.settle(t, YtdlDraft.kCheckAfter);
      await f.drain(t);
      await tapIn(t, byKey('ytdl-sub-done'));
      await f.drain(t);
      expect(find.text(f.h.l.ytdlSavesTo.toUpperCase()), findsOneWidget);
      expect(find.text(f.h.l.ytdlAddToLibrary), findsOneWidget);
      f.h.fake.addGate = Completer<void>();
      await tapIn(t, byKey('ytdl-add'));
      await f.settle(t);
      expect(find.text(f.h.l.discoverJobStarting), findsOneWidget);
      expect(byKey('ytdl-already-adding'), findsNothing);
      f.h.fake.addGate!.complete();
      f.h.fake.addGate = null;
      await f.drain(t);
      expect(find.byType(YtdlFolderSheet), findsNothing);
      expect(find.text('Adding “One More Time”…'), findsOneWidget);
      await t.runAsync(() async {
        await st().start(f.h.request(
            url: kFeelGood, directory: discovery, title: 'Feel Good Inc.'));
        await ytdlSettle();
      });
      await f.drain(t);
      expect(find.text(f.h.l.ytdlStripAddingCount(2)), findsOneWidget);
      await t.runAsync(() async {
        for (final e in [...f.h.fake.tracker]) {
          f.h.fake.finish(e['pid'] as int);
        }
      });
      await f.settle(t, YtdlServerState.kPollBeat);
      await f.drain(t);
      expect(byKey('ytdl-strip'), findsNothing);
      expect(st().added, hasLength(2));
      final discoveryTile = t.widget<ListTile>(find.ancestor(
          of: find.text('Discovery'), matching: find.byType(ListTile)));
      expect(discoveryTile.tileColor, VelvetColors.primaryDim);
      f.clean(t);
    });

    testWidgets('the real Where sheet, closed with ✕, on two screens over one '
        'kept draft: no listener left behind', (t) async {
      f.watchErrors();
      f.h.fake.folder(daftPunk);
      await f.pumpHome(t);
      for (var round = 0; round < 2; round++) {
        await f.openFromHome(t);
        if (round == 0) await f.typeLink(t, kOneMoreTime);
        expect(byKey('ytdl-card'), findsOneWidget);
        await tapIn(t, byKey('ytdl-saves-change'));
        await f.drain(t);
        expect(find.byType(YtdlWhereSheet), findsOneWidget);
        await t.tap(byKey('ytdl-where-close'));
        await f.drain(t);
        expect(find.byType(YtdlWhereSheet), findsNothing);
        await f.back(t);
        expect(find.byType(YtdlScreen), findsNothing);
      }
      // The kept draft still tells whoever listens now.
      st().screenDraft.link.text = kFeelGood;
      await f.drain(t);
      f.clean(t);
    });

    testWidgets('the Where sheet open as the screen goes in one call '
        '(popUntil, then pop — what a re-ping does)', (t) async {
      f.watchErrors();
      f.h.fake.folder(daftPunk);
      await f.pumpHome(t);
      await f.openFromHome(t);
      await f.typeLink(t, kOneMoreTime);
      await tapIn(t, byKey('ytdl-saves-change'));
      await f.drain(t);
      final ctx = t.element(find.byType(YtdlScreen));
      final route = ModalRoute.of(ctx)!;
      final nav = Navigator.of(ctx);
      nav.popUntil((r) => r == route);
      nav.pop();
      await f.frames(t);
      expect(find.byType(YtdlScreen), findsNothing);
      expect(find.byType(YtdlWhereSheet), findsNothing);
      f.clean(t);
    });
  });
}
