// The queue's "Keep a copy…" (the phone spec's §4.8, user decisions 5 and
// Q4): a connected server's track — a downloaded one too, it is still that
// server's song — gets the action in its start pane beside Info (the pane
// widening to 0.5), never the user's own server's track, a file on this
// phone, or a server no longer listed, and never with the gate closed; the
// action opens the song sheet on the track's own server; the grip says
// what it does and the row carries the panes' actions for a screen reader;
// above 1.6× text the label drops its glyph. Opening the panel reads the
// gate of each queued track's own server while it was never read.

import 'package:audio_service/audio_service.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction, SemanticsAction;
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/screens/discovery/copies_hub.dart';
import 'package:mstream_music/util/browse_keep_leads.dart';
import 'package:mstream_music/widgets/keep_folder_glyph.dart';
import 'package:mstream_music/widgets/player_panel.dart' show readQueueKeepGates;
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

  Slidable slidableOf(WidgetTester tester, String title) =>
      tester.widget<Slidable>(find.ancestor(of: find.text(title), matching: find.byType(Slidable)).first);

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

  testWidgets("a connected server's track gets Keep a copy… beside Info — a downloaded one too; your own server's, a phone file and a server no longer listed never", (tester) async {
    h.setUp();
    await openQueue(tester);
    double ratio(String t) => slidableOf(tester, t).startActionPane!.extentRatio;
    expect([ratio('Late Train Verse'), ratio('Rooftop Cypher')], [0.5, 0.5]);
    expect([ratio('Glass Hours'), ratio('Host'), ratio('Morning Tape.mp3'), ratio('Lost Song')], everyElement(0.25));
    await close(tester);
  });

  testWidgets('gate closed on its own server: Info only', (tester) async {
    h.setUp(noUpload: true);
    await openQueue(tester);
    expect(slidableOf(tester, 'Late Train Verse').startActionPane!.extentRatio, 0.25);
    await close(tester);
  });

  testWidgets("the grip opens the pane; its action opens the song sheet on the track's own server", (tester) async {
    h.setUp();
    await openQueue(tester);
    final grip = find.descendant(
        of: find.ancestor(of: find.text('Rooftop Cypher'), matching: find.byType(Slidable)).first,
        matching: find.byKey(const ValueKey('queue-row-grip')));
    await tester.tap(grip);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('queue-keep-action')), findsOneWidget);
    expect(find.text('Keep a copy…'), findsOneWidget);
    expect(find.byType(KeepFolderGlyph), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('queue-keep-action')));
    await tester.pumpAndSettle();
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

  // A node holds one set of custom actions, and the reorderable list puts
  // its Move actions on each row's own node: the row keeps its name, its
  // play, its swipe and the list's moves; the panes' actions are the grip's
  // ("Actions for {title}…").
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
    testWidgets('the pane label at $scale× never overflows its row (the glyph only where it fits)', (tester) async {
      h.setUp();
      for (final width in [360.0, 390.0]) {
        await h.openGate();
        fakeAudio.queue.add(queue());
        await h.pump(tester, const QueueList(), textScale: scale, width: width);
        await BrowseHarness.frames(tester);
        await tester.tap(find.descendant(
            of: find.ancestor(of: find.text('Late Train Verse'), matching: find.byType(Slidable)).first,
            matching: find.byKey(const ValueKey('queue-row-grip'))));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('queue-keep-action')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$scale× on $width');
        await close(tester);
      }
    });
  }

  testWidgets("the gate unread as the panel opens: once it answers, the queue offers Keep a copy… without the queue changing", (tester) async {
    h.setUp();
    fakeAudio.queue.add(queue());
    await h.pump(tester, const QueueList());
    await BrowseHarness.frames(tester);
    expect(slidableOf(tester, 'Late Train Verse').startActionPane!.extentRatio, 0.25, reason: 'unread: no way in');
    readQueueKeepGates(queue());
    await BrowseHarness.frames(tester, 4);
    expect(slidableOf(tester, 'Late Train Verse').startActionPane!.extentRatio, 0.5);
    await close(tester);
  });

  testWidgets('above 1.6× text the pane label drops its glyph and keeps two lines', (tester) async {
    h.setUp();
    await openQueue(tester, textScale: 2);
    await tester.tap(find.descendant(
        of: find.ancestor(of: find.text('Late Train Verse'), matching: find.byType(Slidable)).first,
        matching: find.byKey(const ValueKey('queue-row-grip'))));
    await tester.pumpAndSettle();
    expect(find.byType(KeepFolderGlyph), findsNothing);
    expect(tester.widget<Text>(find.text('Keep a copy…')).maxLines, 2);
    expect(tester.takeException(), isNull);
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
