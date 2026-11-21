// The queue's "Keep a copy…" (the phone spec's §4.8, user decisions 5 and
// Q4): a connected server's track — a downloaded one too, it is still that
// server's song — gets the row in its options sheet (a hold on the row, a
// tap on the grip), never the user's own server's track, a file on this
// phone, or a server no longer listed, and never with the gate closed; the
// row opens the song sheet on the track's own server; the grip says what it
// does and carries the menu's shortcuts for a screen reader; the sheet
// never overflows at a large text size. Opening the panel reads the gate
// of each queued track's own server while it was never read.

import 'package:audio_service/audio_service.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction, SemanticsAction;
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/screens/discovery/copies_hub.dart';
import 'package:mstream_music/util/browse_keep_leads.dart';
import 'package:mstream_music/widgets/keep_folder_glyph.dart';
import 'package:mstream_music/widgets/player_panel.dart' show readQueueKeepGates;
import 'package:mstream_music/widgets/queue_item_sheet.dart';
import 'package:mstream_music/widgets/queue_list.dart';

import '../screens/browse_keep_fixtures.dart';
import '../screens/discovery_keep_fixtures.dart' show mockPathProvider;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final h = BrowseHarness();

  setUpAll(mockPathProvider);
  tearDown(h.tearDown);

  MediaItem track(String title, {String? server, String? path, String artist = 'Boukmanflow', bool downloaded = false, int seconds = 8}) => MediaItem(
        id: 'http://x/$title',
        title: title,
        artist: artist,
        album: 'Borrowed Tapes',
        duration: Duration(seconds: seconds),
        extras: {
          'server': ?server,
          'path': ?(path ?? (server == null ? null : '/music/$artist/Borrowed Tapes/$title.mp3')),
          'artist': artist,
          'year': 2019,
          if (downloaded) 'localPath': '/phone/$title.mp3',
        },
      );

  List<MediaItem> queue() => [
        track('Glass Hours', server: 'home', artist: 'Color Out'),
        track('Late Train Verse', server: 'peer-1'),
        track('Rooftop Cypher', server: 'peer-4', downloaded: true, seconds: 12),
        track('Host', server: 'home', artist: 'Color Out'),
        track('Morning Tape.mp3', downloaded: true),
        track('Lost Song', server: 'peer-9'),
      ];

  final keepRow = find.byKey(const ValueKey('browse-keep-menu-row'));

  Finder gripOf(String title) => find.descendant(
      of: find.ancestor(of: find.text(title), matching: find.byType(Dismissible)).first,
      matching: find.byKey(const ValueKey('queue-row-grip')));

  // A hold on the row opens its options; let the sheet rise.
  Future<void> holdRow(WidgetTester tester, String title) async {
    await tester.longPress(find.text(title));
    await BrowseHarness.frames(tester, 8);
  }

  Future<void> closeSheet(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(QueueItemSheet))).pop();
    await BrowseHarness.frames(tester, 8);
  }

  Future<bool> offersKeep(WidgetTester tester, String title) async {
    await holdRow(tester, title);
    final offered = keepRow.evaluate().isNotEmpty;
    await closeSheet(tester);
    return offered;
  }

  Future<void> openQueue(WidgetTester tester, {bool gate = true, double textScale = 1}) async {
    if (gate) await h.openGate();
    fakeAudio.queue.add(queue());
    await h.pump(tester, const QueueList(), textScale: textScale);
    await BrowseHarness.frames(tester);
  }

  Future<void> close(WidgetTester tester) async {
    fakeAudio.queue.add(const []);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets("a connected server's track offers Keep a copy… in its menu — a downloaded one too; your own server's, a phone file and a server no longer listed never", (tester) async {
    h.setUp();
    await openQueue(tester);
    expect([await offersKeep(tester, 'Late Train Verse'), await offersKeep(tester, 'Rooftop Cypher')], [true, true]);
    expect([
      for (final t in ['Glass Hours', 'Host', 'Morning Tape.mp3', 'Lost Song']) await offersKeep(tester, t),
    ], everyElement(false));
    await close(tester);
  });

  testWidgets('gate closed on its own server: no Keep a copy…', (tester) async {
    h.setUp(noUpload: true);
    await openQueue(tester);
    expect(await offersKeep(tester, 'Late Train Verse'), isFalse);
    await close(tester);
  });

  testWidgets("the grip opens the menu; its Keep a copy… opens the song sheet on the track's own server", (tester) async {
    h.setUp();
    await openQueue(tester);
    await tester.tap(gripOf('Rooftop Cypher'));
    await BrowseHarness.frames(tester, 8);
    expect(find.byType(QueueItemSheet), findsOneWidget);
    expect(keepRow, findsOneWidget);
    expect(find.text('Keep a copy…'), findsOneWidget);
    expect(find.byType(KeepFolderGlyph), findsOneWidget);
    await tester.tap(keepRow);
    await BrowseHarness.frames(tester, 8);
    expect(find.byType(QueueItemSheet), findsNothing, reason: 'the menu closes before the Keep sheet opens');
    final r = h.opened.single;
    expect([r.subject, r.variant, identical(r.peer, h.peerC), identical(r.own, h.home), r.lead['filepath'], r.lead['artist'], r.lead['peer']], [
      KeepSubject.song,
      KeepVariant.menu,
      true,
      true,
      'music/Boukmanflow/Borrowed Tapes/Rooftop Cypher.mp3',
      'Boukmanflow',
      browsePeerC,
    ]);
    await close(tester);
  });

  // The hold menu took over from the swipe pane: its Keep a copy… opens the
  // sheet through the same door as the browse pages' ways in
  // (BrowseKeepEntry.open, whose opener the harness records).
  testWidgets("a hold on the row opens the same menu; its Keep a copy… goes through the browse pages' door", (tester) async {
    h.setUp();
    await openQueue(tester);
    await holdRow(tester, 'Late Train Verse');
    expect(find.byType(QueueItemSheet), findsOneWidget);
    await tester.tap(keepRow);
    await BrowseHarness.frames(tester, 8);
    expect(find.byType(QueueItemSheet), findsNothing);
    final r = h.opened.single;
    expect([r.subject, r.variant, identical(r.peer, h.peerB), identical(r.own, h.home), r.lead['filepath']], [
      KeepSubject.song,
      KeepVariant.menu,
      true,
      true,
      'music/Boukmanflow/Borrowed Tapes/Late Train Verse.mp3',
    ]);
    await close(tester);
  });

  // A node holds one set of custom actions, and the reorderable list puts
  // its Move actions on each row's own node: the row keeps its name, its
  // play, its hold and the list's moves; the menu's shortcuts are the
  // grip's ("Actions for {title}…").
  testWidgets("a screen reader: the row is one node with its name and the list's moves; the grip says what it does and carries Info, Keep a copy… and Remove", (tester) async {
    h.setUp();
    final handle = tester.ensureSemantics();
    await openQueue(tester);
    List<String> actionsOf(String label) => [
          for (final id in tester.getSemantics(find.bySemanticsLabel(label)).getSemanticsData().customSemanticsActionIds ?? const <int>[])
            CustomSemanticsAction.getAction(id)!.label!,
        ];
    // (A platform lists custom actions in the order they were first made.)
    expect(actionsOf('Late Train Verse, Boukmanflow, 0:08'), unorderedEquals(['Move up', 'Move down', 'Move to the start', 'Move to the end']));
    final row = tester.getSemantics(find.bySemanticsLabel('Late Train Verse, Boukmanflow, 0:08')).getSemanticsData();
    expect(row.hasAction(SemanticsAction.tap), isTrue, reason: 'its play, on the same node');
    expect(row.hasAction(SemanticsAction.longPress), isTrue, reason: 'its options, on the same node');
    const grip = 'Actions for Late Train Verse, or hold to reorder';
    expect(actionsOf(grip), unorderedEquals(['Info', 'Keep a copy of Late Train Verse…', 'Remove']));
    expect(actionsOf('Actions for Host, or hold to reorder'), unorderedEquals(['Info', 'Remove']));
    // No node says nothing while it holds actions.
    void silent(SemanticsNode n) {
      final d = n.getSemanticsData();
      if ((d.customSemanticsActionIds ?? const []).isNotEmpty) {
        expect(d.label, isNotEmpty, reason: 'node ${n.id} holds actions and says nothing');
      }
      n.visitChildren((c) {
        silent(c);
        return true;
      });
    }
    var root = tester.getSemantics(find.bySemanticsLabel('Late Train Verse, Boukmanflow, 0:08'));
    while (root.parent != null) {
      root = root.parent!;
    }
    silent(root);
    tester.semantics.customAction(find.semantics.byLabel(grip),
        const CustomSemanticsAction(label: 'Keep a copy of Late Train Verse…'));
    await tester.pumpAndSettle();
    expect(h.opened.single.lead['title'], 'Late Train Verse');
    expect(tester.getSemantics(find.bySemanticsLabel(grip)), isSemantics(isFocused: true),
        reason: 'focus back on the grip, the node a screen reader is on');
    handle.dispose();
    await close(tester);
  });

  for (final scale in [1.15, 1.3, 1.45, 1.6, 2.0]) {
    testWidgets('the menu at $scale× never overflows (Keep a copy… in it)', (tester) async {
      h.setUp();
      for (final width in [360.0, 390.0]) {
        await h.openGate();
        fakeAudio.queue.add(queue());
        await h.pump(tester, const QueueList(), textScale: scale, width: width);
        await BrowseHarness.frames(tester);
        await tester.tap(gripOf('Late Train Verse'));
        await BrowseHarness.frames(tester, 8);
        expect(keepRow, findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$scale× on $width');
        await closeSheet(tester);
        await close(tester);
      }
    });
  }

  testWidgets("the gate unread as the panel opens: once it answers, the menu offers Keep a copy… without the queue changing", (tester) async {
    h.setUp();
    fakeAudio.queue.add(queue());
    await h.pump(tester, const QueueList());
    await BrowseHarness.frames(tester);
    expect(await offersKeep(tester, 'Late Train Verse'), isFalse, reason: 'unread: no way in');
    readQueueKeepGates(queue());
    await BrowseHarness.frames(tester, 4);
    expect(await offersKeep(tester, 'Late Train Verse'), isTrue);
    await close(tester);
  });

  testWidgets('opening the panel reads the gate of a queued track\'s own server once, while it was never read', (tester) async {
    h.setUp();
    expect(CopiesHub().gateFor(h.peerB).state, KeepGateState.unknown);
    readQueueKeepGates(queue());
    await BrowseHarness.frames(tester, 2);
    expect(CopiesHub().gateFor(h.peerB).state, KeepGateState.open);
    expect(h.fake.count('GET', '/api/v1/discovery/plugins'), 1, reason: "one read for both connected servers' parent");
    readQueueKeepGates(queue());
    await BrowseHarness.frames(tester, 2);
    expect(h.fake.count('GET', '/api/v1/discovery/plugins'), 1);
  });
}
