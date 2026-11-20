// The queue's rows: a hold on a row — or a tap on its grip — opens the
// song's options sheet, with the verbs that fit a song already queued (Play
// next moves it right after the song playing); a swipe either way removes
// the row, and Undo puts it back where it was; a tap still plays it; and
// the first time the queue is on screen with songs in it, a hint says so,
// once.

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/singletons/app_route_observer.dart'
    show nowPlayingExpanded;
import 'package:mstream_music/singletons/media.dart';
import 'package:mstream_music/singletons/settings.dart';
import 'package:mstream_music/widgets/queue_item_sheet.dart';
import 'package:mstream_music/widgets/queue_list.dart';

import '../screens/browse_keep_fixtures.dart';
import '../screens/discovery_keep_fixtures.dart' show mockPathProvider;

/// The player, writing down what the queue asks of it and doing it to its
/// queue the way the real handler does.
class RecordingAudioHandler extends FakeAudioHandler {
  final List<String> calls = [];

  /// Set: a removal leaves the queue at once, as the real handler's does,
  /// but the player's part of it finishes only when this completes (the
  /// real player can take seconds).
  Completer<void>? holdRemoval;

  @override
  Future<void> removeQueueItemAt(int index) async {
    calls.add('remove $index');
    queue.add([...queue.value]..removeAt(index));
    final hold = holdRemoval;
    if (hold != null) await hold.future;
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    calls.add('add ${mediaItem.title}');
    queue.add([...queue.value, mediaItem]);
  }

  @override
  Future<dynamic> customAction(String name,
      [Map<String, dynamic>? extras]) async {
    if (name != 'moveQueueItem') return null;
    final from = extras!['from'] as int;
    final to = extras['to'] as int;
    calls.add('move $from→$to');
    final q = [...queue.value];
    q.insert(to, q.removeAt(from));
    queue.add(q);
    return null;
  }

  @override
  Future<void> skipToQueueItem(int index) async => calls.add('skip $index');

  @override
  Future<void> play() async => calls.add('play');
}

/// One player for the whole file: the queue's active-row stream subscribes
/// to the first one it meets.
final RecordingAudioHandler player = RecordingAudioHandler();

const hint = 'Hold a song for its options. Swipe it away to remove it.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final h = BrowseHarness();

  setUpAll(mockPathProvider);
  tearDown(() {
    h.tearDown();
    nowPlayingExpanded.value = false;
  });

  MediaItem song(String title, {String? server = 'home', String artist = 'Color Out', bool downloaded = false}) => MediaItem(
        id: 'http://x/$title',
        title: title,
        artist: artist,
        album: 'Color Out EP',
        duration: const Duration(minutes: 3, seconds: 34),
        extras: {
          'server': ?server,
          // A file on this phone: its own path, local (buildLocalFileMediaItem).
          'path': server == null ? '/phone/$title.m4a' : 'music/$artist/Color Out EP/$title.mp3',
          if (downloaded || server == null) 'localPath': '/phone/$title.m4a',
          'format': 'mp3',
          'bitrate': 233000,
          'musicalKey': 'F major',
          'bpm': 150,
        },
      );

  List<MediaItem> queue() => [
        song('Mercurial'),
        song('Anything But Everything'),
        song('Late Train Verse', server: 'peer-1', artist: 'Boukmanflow'),
        song('Rehearsal take 3', server: null),
        song('Ghosts', downloaded: true),
      ];

  List<String> titles() => [for (final m in player.queue.value) m.title];

  Future<void> openQueue(WidgetTester tester, {int playing = 0, bool accessible = false}) async {
    h.setUp();
    h.home.discoveryAvailable = true;
    await h.openGate();
    MediaManager().audioHandler = player;
    player.calls.clear();
    player.holdRemoval = null;
    player.playbackState.add(PlaybackState(queueIndex: playing, playing: true));
    player.queue.add(queue());
    await h.pump(tester, const QueueList(), accessible: accessible);
    await BrowseHarness.frames(tester);
  }

  Future<void> close(WidgetTester tester) async {
    player.queue.add(const []);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> holdRow(WidgetTester tester, String title) async {
    await tester.longPress(find.text(title));
    await BrowseHarness.frames(tester, 8);
  }

  Future<void> closeSheet(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(QueueItemSheet))).pop();
    await BrowseHarness.frames(tester, 8);
  }

  Finder gripOf(String title) => find.descendant(
      of: find.ancestor(of: find.text(title), matching: find.byType(Dismissible)).first,
      matching: find.byKey(const ValueKey('queue-row-grip')));

  // The sheet's verbs, in order.
  const verbKeys = {
    'queue-sheet-play-next': 'Play next',
    'browse-keep-menu-row': 'Keep a copy',
    'queue-sheet-playlist': 'Add to playlist',
    'queue-sheet-download': 'Download',
    'queue-sheet-similar': 'Find similar',
    'queue-sheet-info': 'Info',
    'queue-sheet-remove': 'Remove from queue',
  };

  Future<List<String>> verbsOf(WidgetTester tester, String title) async {
    await holdRow(tester, title);
    expect(find.descendant(of: find.byType(QueueItemSheet), matching: find.text(title)), findsOneWidget,
        reason: "the sheet is $title's");
    final verbs = [
      for (final e in verbKeys.entries)
        if (find.byKey(ValueKey(e.key)).evaluate().isNotEmpty) e.value,
    ];
    await closeSheet(tester);
    return verbs;
  }

  testWidgets('a hold on a song opens its options, with the verbs that fit it', (tester) async {
    await openQueue(tester);
    // Your server's song: all of them. Already next: no Play next.
    expect(await verbsOf(tester, 'Anything But Everything'),
        ['Add to playlist', 'Download', 'Find similar', 'Info', 'Remove from queue']);
    // A connected server's song: Keep a copy…, no playlist (they live on
    // your own server), no Find similar.
    expect(await verbsOf(tester, 'Late Train Verse'),
        ['Play next', 'Keep a copy', 'Download', 'Info', 'Remove from queue']);
    // A file on this phone: the queue's verbs and Info.
    expect(await verbsOf(tester, 'Rehearsal take 3'), ['Play next', 'Info', 'Remove from queue']);
    // Downloaded already: no Download.
    expect(await verbsOf(tester, 'Ghosts'),
        ['Play next', 'Add to playlist', 'Find similar', 'Info', 'Remove from queue']);
    // The song playing: no Play next.
    expect(await verbsOf(tester, 'Mercurial'),
        ['Add to playlist', 'Download', 'Find similar', 'Info', 'Remove from queue']);
    await close(tester);
  });

  testWidgets("the sheet's header is the song's: title, artist · album, its badges", (tester) async {
    await openQueue(tester);
    await holdRow(tester, 'Late Train Verse');
    final sheet = find.byType(QueueItemSheet);
    expect(find.descendant(of: sheet, matching: find.text('Boukmanflow  ·  Color Out EP')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('F major')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('150 BPM')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await closeSheet(tester);
    await close(tester);
  });

  testWidgets("the grip's tap opens the same menu", (tester) async {
    await openQueue(tester);
    await tester.tap(gripOf('Anything But Everything'));
    await BrowseHarness.frames(tester, 8);
    expect(find.descendant(of: find.byType(QueueItemSheet), matching: find.text('Anything But Everything')), findsOneWidget);
    expect(player.calls, isEmpty, reason: 'the tap does not fall through to the row: nothing plays');
    await closeSheet(tester);
    await close(tester);
  });

  testWidgets('Play next moves a song from later in the queue to right after the one playing', (tester) async {
    await openQueue(tester);
    await holdRow(tester, 'Rehearsal take 3');
    await tester.tap(find.byKey(const ValueKey('queue-sheet-play-next')));
    await BrowseHarness.frames(tester, 8);
    expect(player.calls, ['move 3→1']);
    expect(titles(), ['Mercurial', 'Rehearsal take 3', 'Anything But Everything', 'Late Train Verse', 'Ghosts']);
    expect(find.text('Rehearsal take 3 plays next'), findsOneWidget);
    await close(tester);
  });

  testWidgets('Play next moves a song from before the one playing to right after it', (tester) async {
    await openQueue(tester, playing: 2);
    await holdRow(tester, 'Mercurial');
    await tester.tap(find.byKey(const ValueKey('queue-sheet-play-next')));
    await BrowseHarness.frames(tester, 8);
    expect(player.calls, ['move 0→2']);
    expect(titles(), ['Anything But Everything', 'Late Train Verse', 'Mercurial', 'Rehearsal take 3', 'Ghosts']);
    await close(tester);
  });

  testWidgets('a swipe to the left removes a song, and Undo puts it back where it was', (tester) async {
    await openQueue(tester);
    await tester.fling(find.text('Anything But Everything'), const Offset(-300, 0), 1500);
    // The row slides out and folds up (~0.5 s) before the snackbar rises.
    await BrowseHarness.frames(tester, 24);
    expect(player.calls, ['remove 1']);
    expect(find.text('Anything But Everything'), findsNothing);
    expect(find.text('Removed Anything But Everything'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await BrowseHarness.frames(tester, 8);
    expect(player.calls, ['remove 1', 'add Anything But Everything', 'move 4→1']);
    expect(titles(), ['Mercurial', 'Anything But Everything', 'Late Train Verse', 'Rehearsal take 3', 'Ghosts']);
    expect(find.text('Anything But Everything'), findsOneWidget, reason: 'its row is back');
    await close(tester);
  });

  // Found on the emulator: the player took ~5 s to finish a removal, and the
  // snackbar waited for it, so Undo turned up after the moment had passed.
  testWidgets("Undo shows at once, while the player's removal is still running, and works then", (tester) async {
    await openQueue(tester);
    final hold = player.holdRemoval = Completer<void>();
    await tester.fling(find.text('Anything But Everything'), const Offset(-300, 0), 1500);
    await BrowseHarness.frames(tester, 24);
    expect(hold.isCompleted, isFalse, reason: "the player's part is still running");
    expect(find.text('Removed Anything But Everything'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await BrowseHarness.frames(tester, 8);
    expect(player.calls, ['remove 1', 'add Anything But Everything', 'move 4→1']);
    expect(titles(), ['Mercurial', 'Anything But Everything', 'Late Train Verse', 'Rehearsal take 3', 'Ghosts']);
    hold.complete();
    await BrowseHarness.frames(tester, 2);
    await close(tester);
  });

  testWidgets('a swipe to the right removes a song too', (tester) async {
    await openQueue(tester);
    await tester.fling(find.text('Late Train Verse'), const Offset(300, 0), 1500);
    await BrowseHarness.frames(tester, 12);
    expect(player.calls, ['remove 2']);
    expect(titles(), ['Mercurial', 'Anything But Everything', 'Rehearsal take 3', 'Ghosts']);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets("a short swipe doesn't remove anything", (tester) async {
    await openQueue(tester);
    await tester.drag(find.text('Ghosts'), const Offset(-60, 0));
    await BrowseHarness.frames(tester, 12);
    expect(player.calls, isEmpty);
    expect(find.text('Ghosts'), findsOneWidget);
    await close(tester);
  });

  testWidgets('Remove from queue in the menu removes it, with the same Undo', (tester) async {
    await openQueue(tester);
    await holdRow(tester, 'Ghosts');
    await tester.tap(find.byKey(const ValueKey('queue-sheet-remove')));
    await BrowseHarness.frames(tester, 8);
    expect(player.calls, ['remove 4']);
    expect(find.text('Removed Ghosts'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await BrowseHarness.frames(tester, 8);
    expect(player.calls, ['remove 4', 'add Ghosts']);
    expect(titles().last, 'Ghosts', reason: 'it was last: appended, nothing to move');
    await close(tester);
  });

  testWidgets('a tap on a row still plays it', (tester) async {
    await openQueue(tester);
    await tester.tap(find.text('Late Train Verse'));
    await BrowseHarness.frames(tester, 2);
    expect(player.calls, ['skip 2', 'play']);
    expect(find.byType(QueueItemSheet), findsNothing);
    await close(tester);
  });

  testWidgets('the hint says once how the rows work, the first time the queue is on screen', (tester) async {
    await openQueue(tester);
    SettingsManager().queueHoldHintShown = false;
    // The panel's down: the queue is not on screen yet.
    await BrowseHarness.frames(tester, 4);
    expect(find.text(hint), findsNothing);
    nowPlayingExpanded.value = true;
    await BrowseHarness.frames(tester, 8);
    expect(find.text(hint), findsOneWidget);
    expect(SettingsManager().queueHoldHintShown, isTrue);
    ScaffoldMessenger.of(tester.element(find.byType(QueueList))).removeCurrentSnackBar();
    nowPlayingExpanded.value = false;
    await BrowseHarness.frames(tester, 2);
    nowPlayingExpanded.value = true;
    await BrowseHarness.frames(tester, 8);
    expect(find.text(hint), findsNothing, reason: 'once');
    await close(tester);
  });

  testWidgets('no hint over an empty queue: it waits for songs', (tester) async {
    h.setUp();
    SettingsManager().queueHoldHintShown = false;
    MediaManager().audioHandler = player;
    player.queue.add(const []);
    nowPlayingExpanded.value = true;
    await h.pump(tester, const QueueList());
    await BrowseHarness.frames(tester, 8);
    expect(find.text(hint), findsNothing);
    expect(SettingsManager().queueHoldHintShown, isFalse);
    await close(tester);
  });

  // Found on the emulator: Play next's answer sat behind the first-run hint,
  // whose timer stops while the menu covers it and starts over once the menu
  // closes, so the first thing done from the menu said nothing for 8 s.
  testWidgets("what the menu did shows at once, in the hint's place", (tester) async {
    await openQueue(tester);
    SettingsManager().queueHoldHintShown = false;
    nowPlayingExpanded.value = true;
    await BrowseHarness.frames(tester, 8);
    expect(find.text(hint), findsOneWidget);
    await holdRow(tester, 'Rehearsal take 3');
    await tester.tap(find.byKey(const ValueKey('queue-sheet-play-next')));
    await BrowseHarness.frames(tester, 16);
    expect(find.text('Rehearsal take 3 plays next'), findsOneWidget);
    expect(find.text(hint), findsNothing);
    await close(tester);
  });

  testWidgets("Undo doesn't wait behind other snackbars either", (tester) async {
    await openQueue(tester);
    final messenger = ScaffoldMessenger.of(tester.element(find.byType(QueueList)));
    messenger
      ..showSnackBar(const SnackBar(content: Text('Something said first'), duration: Duration(seconds: 8)))
      ..showSnackBar(const SnackBar(content: Text('Something said next')));
    await BrowseHarness.frames(tester, 8);
    expect(find.text('Something said first'), findsOneWidget);
    await tester.fling(find.text('Ghosts'), const Offset(-300, 0), 1500);
    await BrowseHarness.frames(tester, 24);
    expect(find.text('Removed Ghosts'), findsOneWidget);
    expect(find.text('Something said next'), findsNothing, reason: 'dropped, not shown first');
    await close(tester);
  });

  // Found on the phone: a snackbar with an action persists by default, so
  // "Removed … · Undo" stayed until it was swiped away.
  testWidgets('Undo leaves after a few seconds', (tester) async {
    await openQueue(tester);
    await tester.fling(find.text('Ghosts'), const Offset(-300, 0), 1500);
    await BrowseHarness.frames(tester, 24);
    expect(find.text('Removed Ghosts'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await BrowseHarness.frames(tester, 12);
    expect(find.text('Removed Ghosts'), findsNothing);
    await close(tester);
  });

  testWidgets('the hint leaves after its 8 seconds', (tester) async {
    await openQueue(tester);
    SettingsManager().queueHoldHintShown = false;
    nowPlayingExpanded.value = true;
    await BrowseHarness.frames(tester, 8);
    expect(find.text(hint), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
    await BrowseHarness.frames(tester, 12);
    expect(find.text(hint), findsNothing);
    await close(tester);
  });

  testWidgets('under a screen reader, Undo stays until it is used or dismissed', (tester) async {
    await openQueue(tester, accessible: true);
    await tester.fling(find.text('Ghosts'), const Offset(-300, 0), 1500);
    await BrowseHarness.frames(tester, 24);
    await tester.pump(const Duration(seconds: 10));
    await BrowseHarness.frames(tester, 12);
    expect(find.text('Removed Ghosts'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await BrowseHarness.frames(tester, 8);
    expect(titles().last, 'Ghosts', reason: 'Undo still works after the time is up');
    await close(tester);
  });
}
