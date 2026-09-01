// Batch add ("Add all") onto an empty queue (PR #121 follow-up).
//
// The regression this pins: addQueueItems onto a fresh IDLE player let
// just_audio's idle stub land the current index on the LAST row, so the
// now-playing surfaces showed the final track and a later play() re-seeded
// there too ("added a folder, and it opened on the last song"). The batch
// add must park the queue on track 1, and playback must start there.

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mstream_music/singletons/media.dart';

import 'helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await MediaManager().start();
  });

  Future<void> waitFor(bool Function() cond, String what,
      {Duration timeout = const Duration(seconds: 20)}) async {
    final deadline = DateTime.now().add(timeout);
    while (!cond()) {
      if (DateTime.now().isAfter(deadline)) fail('timed out waiting for $what');
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  testWidgets('batch add onto an empty queue opens and plays from track 1',
      (WidgetTester tester) async {
    await resetAppState();
    final mock = await MockServer.start(
      const {},
      defaultHandler: (_) => buildSilentWav(seconds: 60),
    );
    addTearDown(mock.close);

    final handler = MediaManager().audioHandler;
    await handler.customAction('clearPlaylist');

    final items = [
      for (var i = 1; i <= 5; i++)
        MediaItem(
          id: '${mock.url}/media/demo/track_$i.wav',
          title: 'Track $i',
          extras: {'server': 'batch-test', 'path': 'demo/track_$i.wav'},
        ),
    ];
    await handler.addQueueItems(items);

    expect(handler.queue.value.length, 5);
    // The parked spot must present TRACK 1 as now-playing, not wherever the
    // idle stub's post-append emission landed (observed: the last row).
    await waitFor(() => handler.mediaItem.valueOrNull?.title == 'Track 1',
        'now-playing to settle on the first track');

    // And play() must start there — the idle re-seed reads the same spot.
    await handler.play();
    // Generous: the iOS simulator's AVPlayer probes each source serially
    // before ready — well over the Android emulator's near-instant start.
    await waitFor(
        () =>
            handler.playbackState.value.processingState ==
                AudioProcessingState.ready &&
            handler.playbackState.value.playing &&
            handler.playbackState.value.queueIndex == 0,
        'playback to start on track 1',
        timeout: const Duration(seconds: 90));
    expect(handler.mediaItem.valueOrNull?.title, 'Track 1');

    await handler.customAction('clearPlaylist');
  });
}
