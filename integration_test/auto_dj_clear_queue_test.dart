// Auto DJ across a queue clear.
//
// The bug this pins: clearing the queue used to leave the whole DJ session
// standing — the round-tripped ignoreList, the sonic history/locked pin, the
// Camelot anchor, and any in-flight random-songs request, whose response
// would repopulate the queue the user just emptied. The next picks were then
// anchored on the dead session instead of whatever the user queued next.
//
// Contract under test (AudioPlayerHandler._resetAutoDJSession +
// _doClearPlaylist):
//   1. A clear keeps the DJ ARMED but adds nothing itself — no start menu,
//      no surprise pick.
//   2. A pick in flight when the clear lands is discarded (epoch check), so
//      the emptied queue stays empty.
//   3. The next session starts clean: the first request after the clear
//      carries an EMPTY ignoreList (the dead session's cooldown is gone).
//   4. The one-shot sonic seed is consumed by the clear.
//
// Drives the real AudioPlayerHandler against an in-process MockServer whose
// random-songs route records request bodies and can hold a response to
// stage the in-flight race deterministically.

import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/auto_dj_manager.dart';
import 'package:mstream_music/singletons/media.dart';

import 'helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  MockServer? mockServer;

  // Every random-songs body the app sent, oldest first.
  final djBodies = <Map<String, dynamic>>[];
  // When set, the route holds its response this long — the window in which
  // the test fires the clear to stage the race.
  var djDelay = Duration.zero;
  var nextPickId = 0;

  Future<Object?> randomSongs(HttpRequest req) async {
    final body =
        jsonDecode(await utf8.decoder.bind(req).join()) as Map<String, dynamic>;
    djBodies.add(body);
    if (djDelay > Duration.zero) await Future<void>.delayed(djDelay);
    final id = nextPickId++;
    // Echo the server contract: the sent list plus this pick's id.
    final ignore = List<int>.from(
        (body['ignoreList'] as List?)?.cast<int>() ?? const <int>[])
      ..add(id);
    return {
      'songs': [
        {
          'filepath': 'demo/track_$id.mp3',
          'metadata': {'title': 'Track $id', 'artist': 'DJ Pick'},
        }
      ],
      'ignoreList': ignore,
    };
  }

  Future<void> waitFor(bool Function() cond, String what,
      {Duration timeout = const Duration(seconds: 10)}) async {
    final deadline = DateTime.now().add(timeout);
    while (!cond()) {
      if (DateTime.now().isAfter(deadline)) fail('timed out waiting for $what');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  setUpAll(() async {
    await MediaManager().start();
  });

  setUp(() async {
    await resetAppState();
    // A failed earlier run can leave a seed behind (the test consumes it
    // mid-flow); a leftover would reroute the arm phase through the seeded
    // start. In-memory only — no save needed for a test baseline.
    AutoDJManager()
      ..sonicSeedPath = null
      ..sonicSeedTitle = null
      ..sonicSeedServer = null;
    djBodies.clear();
    djDelay = Duration.zero;
    nextPickId = 0;
    mockServer = await MockServer.start(
      {'/api/v1/db/random-songs': randomSongs},
      // Everything else is a stream URL — serve playable audio so play()
      // on a pick doesn't spiral into the error-recovery paths.
      defaultHandler: (_) => buildSilentWav(),
    );
  });

  tearDown(() async {
    final handler = MediaManager().audioHandler;
    // Disarm + clear so the shared singleton handler carries nothing into
    // the next test (both are new-lane resets themselves).
    await handler.customAction('setAutoDJ', {'autoDJServer': null});
    await handler.customAction('clearPlaylist');
    await mockServer?.close();
    mockServer = null;
  });

  testWidgets('clearing the queue starts a new Auto-DJ lane',
      (WidgetTester tester) async {
    final handler = MediaManager().audioHandler;
    final srv = Server(mockServer!.url, null, null, null, 'it-dj-server');

    // ── Arm on an empty queue: the DJ opens the session itself. ──
    await handler.customAction('setAutoDJ', {'autoDJServer': srv});
    await waitFor(() => handler.queue.value.length >= 2, 'the DJ to open');

    // The session accumulated state: a later request carried an earlier
    // pick in its cooldown.
    await waitFor(
        () => djBodies.any((b) => ((b['ignoreList'] as List?) ?? []).isNotEmpty),
        'a request carrying the session ignoreList');

    // A pending one-shot seed, as the empty-queue start flow would leave
    // one moments before arming.
    await AutoDJManager().setSonicSeed(
        path: 'demo/seed.mp3', title: 'Seed', server: 'it-dj-server');

    // ── Stage the race: a pick leaves, the clear lands first. ──
    final sentBefore = djBodies.length;
    djDelay = const Duration(milliseconds: 800);
    final inFlight = handler.autoDJ();
    await waitFor(() => djBodies.length > sentBefore,
        'the in-flight request to reach the mock');

    await handler.customAction('clearPlaylist');

    expect(handler.queue.value, isEmpty);
    expect((handler.customState.valueOrNull as dynamic)?.autoDJState, same(srv),
        reason: 'the clear must leave the DJ armed');
    expect(AutoDJManager().sonicSeedPath, isNull,
        reason: 'the clear consumes the one-shot seed');

    // The held response lands AFTER the clear — and must be discarded.
    await inFlight;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(handler.queue.value, isEmpty,
        reason: 'an in-flight pick must not repopulate a cleared queue');

    // ── The user queues something: the DJ resumes from a clean slate. ──
    djBodies.clear();
    djDelay = Duration.zero;
    await handler.addQueueItem(MediaItem(
      id: '${mockServer!.url}/media/demo/user_pick.mp3',
      title: 'User pick',
      extras: {'server': 'it-dj-server', 'path': 'demo/user_pick.mp3'},
    ));
    await handler.play();

    await waitFor(() => djBodies.isNotEmpty, 'the post-clear top-up');
    expect(djBodies.first['ignoreList'], isEmpty,
        reason: 'the reset must drop the dead session\'s cooldown — a stale '
            'list here is the original bug');
    await waitFor(() => handler.queue.value.length >= 2,
        'the DJ topping up behind the user\'s track');
    expect(handler.queue.value.first.title, 'User pick',
        reason: 'the user\'s track leads the new lane; DJ picks follow it');
  });
}
