// The queue's empty-queue prompt, with the DJ armed and nothing queued: its
// three ways to give the DJ an opening song store the one-shot seed and then
// ask the handler to start from it ('startAutoDJFromSeed'). A song the user
// chose (Recently played, Choose) is stored with the mark that says so
// (AutoDJManager.sonicSeedChosen), which a Stay close start reads to add the
// song to More like, pinned, as Add song does; Random's song is stored
// without it. The start sheet's flow (toggleAutoDJ) stores its seed through
// the same three helpers.
//
// Built on the queue tests' harness (browse_keep_fixtures.dart), with a fake
// audio handler that has the DJ armed on the home server and records the
// custom actions sent to it. Random's opening pick is answered through the
// harness's routes; Recently played's check that the song is still on the
// server gets no answer in a test, which counts as yes.
//
// The seed's save goes through path_provider to a scratch folder: real file
// IO, which the fake clock doesn't run. And auto_dj.json's write chain keeps
// a future of the zone its last save ran in: a save on one test's fake
// clock would leave every later test's saves waiting on a clock that is
// gone. So each flow's save runs in real time (runAsync), and the start
// that follows it is waited for there.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/main.dart' show CustomEvent;
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/play_event.dart';
import 'package:mstream_music/singletons/auto_dj_manager.dart';
import 'package:mstream_music/singletons/media.dart';
import 'package:mstream_music/singletons/play_history.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/singletons/track_capture.dart';
import 'package:mstream_music/widgets/queue_list.dart';

import '../screens/browse_keep_fixtures.dart';

/// The player as the empty queue sees it, with every custom action sent to
/// it in [actions].
class _DjHandler extends FakeAudioHandler {
  final List<String> actions = [];

  @override
  Future<dynamic> customAction(String name,
      [Map<String, dynamic>? extras]) async {
    actions.add(name);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final h = BrowseHarness();
  final handler = _DjHandler();
  final mgr = AutoDJManager();
  late Directory scratch;

  File savedFile() => File('${scratch.path}/auto_dj.json');
  Map<String, dynamic> saved() =>
      jsonDecode(savedFile().readAsStringSync()) as Map<String, dynamic>;

  setUpAll(() {
    scratch = Directory.systemTemp.createTempSync('mstream-queue-dj-seed-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => scratch.path);
  });
  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
    try {
      scratch.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    // What Recently played offers: one song this phone played to its end on
    // home. Read once here, in the real zone, so the prompt's read of it is
    // pure microtasks.
    PlayHistory.storageDirectory = () async => scratch;
    await PlayHistory().resetForTest();
    await PlayHistory().events();
    final at = DateTime.now().toUtc().subtract(const Duration(hours: 1));
    await PlayHistory().record(PlayEvent(
      id: 'recent',
      startedAt: at,
      endedAt: at.add(const Duration(minutes: 4)),
      track: const TrackFacts(
          server: 'home', path: '/music/recent.mp3', title: 'Recent Song'),
      playedMs: 240000,
      outcome: PlayOutcome.completed,
      source: PlaySource.manual,
      counted: true,
    ));
    await PlayHistory().flush();
    mgr
      ..sonicSeedPath = null
      ..sonicSeedTitle = null
      ..sonicSeedServer = null
      ..sonicSeedChosen = false;
    handler.actions.clear();
    try {
      savedFile().deleteSync();
    } catch (_) {}
  });
  tearDown(() async {
    TrackCapture.cancel();
    h.tearDown();
    await PlayHistory().resetForTest();
  });

  /// The empty queue with the DJ armed on home, which is also the server
  /// being browsed, so Choose opens the library where it already is.
  Future<void> open(WidgetTester tester) async {
    h.setUp();
    ServerManager().currentServer = h.home;
    MediaManager().audioHandler = handler;
    handler.queue.add(const []);
    handler.customState.add(CustomEvent(h.home));
    await h.pump(tester, const QueueList());
    await BrowseHarness.frames(tester);
  }

  bool started() => handler.actions.contains('startAutoDJFromSeed');

  /// Waits in real time, where the save's file IO runs, until the flow has
  /// asked the handler to start.
  Future<void> waitForStart() async {
    for (var i = 0; i < 400 && !started(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  /// Lets the flow reach the start in turns of real time and a pump, for a
  /// flow that also waits on frames.
  Future<void> untilStarted(WidgetTester tester) async {
    for (var i = 0; i < 400 && !started(); i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump();
    }
  }

  testWidgets('Recently played: the song is stored as one the user chose, '
      'then the DJ starts from it', (tester) async {
    await open(tester);
    // Opened in real time: the pick from the menu then runs there, its
    // save included.
    await tester.runAsync(
        () => tester.tap(find.byKey(const ValueKey('queue-empty-dj-recent'))));
    await tester.pumpAndSettle();
    expect(find.text('Recent Song'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('auto-dj-recent-0')));
    await tester.pump();
    await untilStarted(tester);

    expect(handler.actions, ['startAutoDJFromSeed']);
    expect(mgr.sonicSeedPath, 'music/recent.mp3');
    expect(mgr.sonicSeedServer, 'home');
    expect(mgr.sonicSeedChosen, isTrue);
    expect(saved()['sonicSeedChosen'], true,
        reason: 'the mark is saved with the seed');
  });

  testWidgets('Choose: the library pick is stored as one the user chose, '
      'then the DJ starts from it', (tester) async {
    await open(tester);
    await tester.tap(find.text('Choose a song'));
    await tester.pump();
    final armed = TrackCapture.pending;
    expect(armed, isNotNull, reason: 'Choose arms the pick from the library');
    expect(armed!.server, same(h.home));

    // The user taps a song of the DJ's server in the library.
    CaptureResult? captured;
    await tester.runAsync(() async {
      captured = TrackCapture.tryCapture(DisplayItem(
          h.home, 'Chosen.mp3', 'file', '/music/chosen.mp3', null, null));
      await waitForStart();
    });
    await tester.pump();

    expect(captured, CaptureResult.captured);
    expect(handler.actions, ['startAutoDJFromSeed']);
    expect(mgr.sonicSeedPath, 'music/chosen.mp3');
    expect(mgr.sonicSeedServer, 'home');
    expect(mgr.sonicSeedChosen, isTrue);
    expect(saved()['sonicSeedChosen'], true);
  });

  testWidgets('Random: the song the server draws is stored without the mark, '
      'then the DJ starts from it', (tester) async {
    await open(tester);
    h.routes['/api/v1/db/random-songs'] = {
      'songs': [
        {
          'filepath': 'music/drawn.mp3',
          'metadata': {'title': 'Drawn Song', 'artist': 'Someone'},
        }
      ],
    };
    // The pick goes out through the harness's routes.
    await tester.runAsync(() => h.withRoutes(() async {
          await tester.tap(find.text('Pick a random song'));
          await waitForStart();
        }));
    await tester.pump();

    expect(h.browseCalls.map((r) => r.url.path),
        contains('/api/v1/db/random-songs'));
    expect(handler.actions, ['startAutoDJFromSeed']);
    expect(mgr.sonicSeedPath, 'music/drawn.mp3');
    expect(mgr.sonicSeedChosen, isFalse);
    expect(saved()['sonicSeedChosen'], false);
  });
}
